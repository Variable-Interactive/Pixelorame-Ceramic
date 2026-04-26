class_name GodotLSP
extends Node

## This is the default values for godot editor settings.
const HOST := "127.0.0.1"
## This is the default values for godot editor settings.
const PORT: int = 6005
const PACKET_SCAN_INTERVAL := 0.3
const GODOT_STARTUP_TIMEOUT := 0.5
const CONNECTION_MAX_ATTEMPTS: int = 50

enum {
	INITIALIZATION,
	FILE_REGISTERED,
	FILE_CHANGED,
	COMPLETION_REQUESTED,
	SIGNATURE_REQUESTED,
	UNKNOWN
}

signal connected()
signal initialized()
signal packet_received(packet:PackedByteArray)
signal message(value: String)

var _temp_path := OS.get_temp_dir().path_join("ceramic_temp")
var _stream: StreamPeerTCP
var _is_stream_connected := false  # Having a stream doesn't mean it's connected
var _json_rpc := JSONRPC.new()
var _lsp_process: int = -1
var _godot_connect_attempt: int = 0
var _godot_startup_timer := Timer.new()  # Used by LSP to wait for godot to open.
var _packet_scan_timer := Timer.new()  # Used by LSP to scan for packets regularly.

class DummyProject:
	const PROJECT_FILE := """; Engine configuration file.
	; It's best edited using the editor UI and not directly,
	; since the parameters that go here are not all obvious.
	;
	; Format:
	;   [section] ; section goes between []
	;   param=value ; assign values to parameters

	config_version=5

	[application]

	config/name="CeramicTempProject"
	config/features=PackedStringArray("4.6", "GL Compatibility")
	config/icon=""

	[rendering]

	rendering_device/driver.windows="d3d12"
	renderer/rendering_method="gl_compatibility"
	renderer/rendering_method.mobile="gl_compatibility"
	"""

	static func create_project(directory_path: String) -> String:
		DirAccess.make_dir_recursive_absolute(directory_path)
		var project_file := FileAccess.open(directory_path.path_join("project.godot"), FileAccess.WRITE)
		project_file.store_string(PROJECT_FILE)
		project_file.close()
		return directory_path.path_join("project.godot")


## Checks if a valid Godot executable is placed on your path. LSP can only work with a valid
## Godot executable present.
static func is_godot_present(at_path: String) -> bool:
	if at_path.is_empty():
		return false
	var out := []
	var godot_executed := OS.execute(at_path, ["-h"], out)
	if godot_executed == 0 or godot_executed == 1:
		if out.size() > 0:
			for result: String in out:
				if "Godot" in result:
					return true
	return false


## Use this to check if the LSP is active or not (Usually used before connecting or disconnecting)
## the LSP.
func is_active() -> bool:
	return _stream or _is_stream_connected


func try_connect_lsp(godot_path: String) -> void:
	_is_stream_connected = false
	if _stream:
		disconnect_lsp_stream()
	_packet_scan_timer.start()
	connected.connect(_on_connected_to_lsp_server.bind(godot_path))
	packet_received.connect(_on_packet_recieved)

	# Connect to LSP server
	if is_godot_present(godot_path):
		var args = OS.get_cmdline_user_args()
		if "--child" in args:
			return  # This is the headless/LSP instance so don't spawn again
		_lsp_process = OS.create_process(
			godot_path, [
				"--headless",
				DummyProject.create_project(_temp_path),
				"++",
				"--child"
			]
		)
		if _lsp_process != -1:
			message.emit("Godot starting, process id: %s" % str(_lsp_process))
			_stream = StreamPeerTCP.new()
			message.emit("Connecting to Host: %s, Port: %s" % [HOST, str(PORT)])
			_godot_startup_timer.start()
		else:
			message.emit("Could not create TCP server...")
	else:
		message.emit("Godot not found at path, code suggestions can not be performed")
		disconnect_lsp_stream()


func send_autocomplete_request(script: VirtualScript, editor: CodeEdit) -> void:
	if not DirAccess.dir_exists_absolute(_temp_path):
		return
	var file_uid := str(script.get_instance_id())
	var source := script.prepare_for_intellisence()
	if _is_stream_connected:
		if not script.is_registered_to_lsp: # register a file.
			_register_lsp_file(file_uid, source)
			script.is_registered_to_lsp = true
		else: # Make changes to file.
			_announce_file_changes(file_uid, source)

		if not editor:  # Sanity check (Should always be true)
			return

		# Request Completion
		_request_file_completion(file_uid, editor.get_caret_line(), editor.get_caret_column())
		_request_function_signature(file_uid, editor.get_caret_line(), editor.get_caret_column())


func disconnect_lsp_stream() -> void:
	_packet_scan_timer.stop()
	if _stream:
		_stream.disconnect_from_host()
		_stream = null
		_is_stream_connected = false
		message.emit("stream_disconnected")

	connected.disconnect(_on_connected_to_lsp_server)
	packet_received.disconnect(_on_packet_recieved)
	if _lsp_process != -1 and _lsp_process != 0:
		message.emit("Killing stream at PID: %s" % str(_lsp_process))
		OS.kill(_lsp_process)
		_lsp_process = -1
	_godot_connect_attempt = 0


func _enter_tree() -> void:
	_godot_startup_timer.wait_time = GODOT_STARTUP_TIMEOUT
	_godot_startup_timer.one_shot = true
	_godot_startup_timer.timeout.connect(_on_godot_startup_timer_timeout)
	add_child(_godot_startup_timer)

	_packet_scan_timer.wait_time = PACKET_SCAN_INTERVAL
	_packet_scan_timer.timeout.connect(_scan_for_packets)
	add_child(_packet_scan_timer)


func _scan_for_packets() -> void:
	if not _stream:
		return
	var status = _stream.get_status()
	match status:
		StreamPeerTCP.STATUS_NONE:
			return
		StreamPeerTCP.STATUS_ERROR:
			if _godot_connect_attempt < CONNECTION_MAX_ATTEMPTS:
				if _godot_startup_timer.is_stopped():
					_godot_startup_timer.start()
			else:
				message.emit("Server stream error!")
				disconnect_lsp_stream()
		_: # (STATUS_CONNECTING or STATUS_CONNECTED)
			# update our connection status (called only once)
			if status == StreamPeerTCP.STATUS_CONNECTED and not _is_stream_connected:
				_is_stream_connected = true
				connected.emit()

			if _stream.poll() == OK:  # We have reseaved something from LSP server
				var available_bytes = _stream.get_available_bytes()
				if available_bytes > 0:
					var data = _stream.get_data(available_bytes)
					if data[0] == OK:
						# A valid packet detected, send it to packet manager.
						packet_received.emit(data[1])
					else:
						message.emit("Error when getting data: %s" % error_string(data[0]))
			else:
				if _godot_connect_attempt < CONNECTION_MAX_ATTEMPTS:
					if _godot_startup_timer.is_stopped():
						_godot_startup_timer.start()
				else:
					message.emit("Failed to poll()")


func _on_godot_startup_timer_timeout() -> void:
	_godot_connect_attempt += 1
	message.emit("Attempt --- %s" % str(_godot_connect_attempt))
	_stream.disconnect_from_host()
	_stream.connect_to_host(HOST, PORT)


func _on_connected_to_lsp_server(godot_path: String):
	var request = _json_rpc.make_request(
		"initialize", {
			"processId": null,
			"rootUri": "file:///%s" % godot_path,
			"capabilities": {}
		},
		INITIALIZATION
	)
	message.emit("CONNECTED to Server Initializing LSP...")
	_send_request(request)


func _on_packet_recieved(packet: PackedByteArray):
	var packet_text := packet.get_string_from_utf8()
	packet_text = packet_text.replace("Content-Length", "\nContent-Length")
	var packet_test_arr = packet_text.split("\n", false)
	for entry in packet_test_arr:
		if not entry.strip_edges().is_empty():
			var converted = str_to_var(entry.strip_edges())
			if typeof(converted) == TYPE_DICTIONARY:
				match converted.get("id", UNKNOWN):
					INITIALIZATION:
						initialized.emit()


func _register_lsp_file(f_name: String, f_text: String):
	var request_new_file = _json_rpc.make_request(
		"textDocument/didOpen", {
				"textDocument": {
					"uri": "file:///virtual/%s" % f_name,
					"languageId": "gdscript",
					"text": f_text
				}
			},
		FILE_REGISTERED
	)
	_send_request(request_new_file)


func _announce_file_changes(f_name: String, f_text: String):
	var request_change = _json_rpc.make_request(
		"textDocument/didChange", {
				"textDocument": {
					"uri": "file:///virtual/%s" % f_name,
				},
				"contentChanges": [
					{ "text": f_text }
				]
			},
		FILE_CHANGED
	)
	_send_request(request_change)


func _request_file_completion(f_name: String, line: int, column: int):
	var request_completion = _json_rpc.make_request(
		"textDocument/completion", {
				"textDocument": {
					"uri": "file:///virtual/%s" % f_name,
				},
				"position": {
					"line": line, "character": column
				}
			},
		COMPLETION_REQUESTED
	)
	_send_request(request_completion)


func _request_function_signature(f_name: String, line: int, column: int):
	var req_signature = _json_rpc.make_request(
		"textDocument/signatureHelp", {
				"textDocument": {
					"uri": "file:///virtual/%s" % f_name,
				},
				"position": {
					"line": line, "character": column
				}
			},
		SIGNATURE_REQUESTED
	)
	_send_request(req_signature)


func _send_request(request: Dictionary) -> void:
	if not _stream:
		return
	var json = JSON.stringify(request)
	var length = json.to_utf8_buffer().size()
	var content = """Content-Length: {length}\r\n\r\n{json}""".format({
		length = length,
		json = json
	})
	var packet = content.to_utf8_buffer()
	_stream.put_data(packet)
