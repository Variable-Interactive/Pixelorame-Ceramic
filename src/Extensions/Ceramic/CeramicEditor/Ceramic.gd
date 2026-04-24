extends PanelContainer

## This is the default values for godot editor settings.
const HOST := "127.0.0.1"
## This is the default values for godot editor settings.
const PORT: int = 6005

const CONNECTION_MAX_ATTEMPTS: int = 50
const ACTIVATOR_GROUP := "Activators"
const EDITOR_SCENE := preload("res://src/Extensions/Ceramic/CeramicEditor/Nodes/Editor.tscn")

const ERROR_COLOR := Color.RED
const WARN_COLOR := Color.YELLOW

enum Diagnostic { NONE, WARN, ERROR }
enum {
	INITIALIZATION,
	FILE_REGISTERED,
	FILE_CHANGED,
	COMPLETION_REQUESTED,
	DIAGNOSTICS_REQUESTED,
	UNKNOWN
}

signal connected()
signal packet_received(packet:PackedByteArray)

var temp_path := OS.get_temp_dir().path_join("ceramic_temp")
var virtual_scripts: Array[VirtualScript] = []
var editors: Dictionary[VirtualScript, CodeEdit] = {}
var current_virtual_script: VirtualScript:
	set(value):
		status_info.text = ""
		current_virtual_script = value
		var editor: CodeEdit = editors.get(value)
		if editor and value:
			editor.text = value.source_code
			script_name_edit.text = value.name
			update_script_status(value, false)
			for other_editor: CodeEdit in editors.values():
				other_editor.visible = (other_editor == editor)
			diagnostics_label.visible = false
			diagnostics_label.set_meta("type", Diagnostic.NONE)
			send_autocomplete_request()
		if script_info_bar:
			script_info_bar.visible = (value != null)

var godot_connect_attempt: int = 0
var stream: StreamPeerTCP
var is_stream_connected := false
var json_rpc := JSONRPC.new()
var lsp_process: int = -1
var was_connected := false
var was_closed_by_notification := false


@onready var activators: Node = %Activators
@onready var script_list: ItemList = %ScriptList
@onready var log_viewer: RichTextLabel = %LogViewer
@onready var diagnostics_label: RichTextLabel = %Diagnostics
@onready var script_name_edit: LineEdit = %ScriptNameEdit
@onready var godot_path_edit: LineEdit = %GodotPath
@onready var editor_container: VBoxContainer = %EditorContainer
@onready var output: HBoxContainer = %Output
@onready var status_info: Label = %StatusInfo
@onready var godot_startup_timer: Timer = %GodotStartupTimer
@onready var diagnostic_timer: Timer = %DiagnosticTimer
@onready var executable_chooser: FileDialog = %ExecutableChooser
@onready var extension_api: Node  ## A variable for easy reference to the Api
@onready var script_info_bar: HBoxContainer = %ScriptInfoBar

func _ready() -> void:
	extension_api = get_node_or_null("/root/ExtensionsApi")  # Accessing the Api
	if extension_api:
		extension_api.general.get_global().pixelorama_about_to_close.connect(_exit_tree)
		var config: ConfigFile = extension_api.general.get_config_file()
		var data: Dictionary = config.get_value("Ceramic", "data", {})
		var godot_path: String = config.get_value("Ceramic", "godot", "")
		if not godot_path.is_empty() and is_godot_present(godot_path):
			godot_path_edit.text = godot_path
		try_connect_lsp()
		if data.is_empty():
			create_virtual_script()
		else:
			deserialize(data)
	else:
		create_virtual_script()


func serialize():
	var scripts := []
	for script in virtual_scripts:
		scripts.append(script.serialize())
	return {"scripts": scripts}


func deserialize(data: Dictionary):
	var scripts = data.get("scripts", [])
	for script_data in scripts:
		create_virtual_script(script_data)


func _notification(what):
	match what:
		NOTIFICATION_CRASH:
			disconnect_lsp_stream()
			was_closed_by_notification = true
		NOTIFICATION_WM_CLOSE_REQUEST:
			was_closed_by_notification = true
			disconnect_lsp_stream()


func _exit_tree() -> void:
	if extension_api:
		var config: ConfigFile = extension_api.general.get_config_file()
		config.set_value("Ceramic", "data", serialize())
		config.set_value("Ceramic", "godot", godot_path_edit.text)
	disconnect_lsp_stream()


####### Signals
func _on_new_script_button_pressed() -> void:
	create_virtual_script()


func _on_script_name_edit_text_changed(new_text: String) -> void:
	new_text = new_text.strip_edges()
	if new_text.is_empty():
		new_text = "Untitled"
	if current_virtual_script.name == new_text:
		return
	if new_text.is_valid_filename():
		current_virtual_script.name = new_text
		var idx = virtual_scripts.find(current_virtual_script)
		if script_list.get_item_metadata(idx) != current_virtual_script.get_instance_id():
			refresh_script_list()
		else:
			script_list.set_item_text(
				idx,
				current_virtual_script.name + "(%s)" % get_script_status(current_virtual_script)
			)


func _on_script_list_item_selected(index: int) -> void:
	if index < virtual_scripts.size():
		current_virtual_script = virtual_scripts[index]


func _ping_timer_timeout() -> void:
	if not current_virtual_script:
		return
	scan_for_packets()


func _text_changed() -> void:
	var editor: CodeEdit = editors.get(current_virtual_script)
	if editor:
		if diagnostics_label.visible:
			diagnostics_label.visible = false
			diagnostics_label.set_meta("type", Diagnostic.NONE)
			for line in editor.get_line_count():
				editor.set_line_background_color(line, Color(0, 0, 0, 0))

		if current_virtual_script.source_code != editor.text:
			current_virtual_script.source_code = editor.text
			if not stream:
				if was_connected and was_closed_by_notification:
					was_connected = false
					was_closed_by_notification = false
					try_connect_lsp()
					return
			send_autocomplete_request()


func _on_run_script_pressed() -> void:
	run_code(current_virtual_script)


func _on_godot_path_text_changed(file_path: String) -> void:
	if not is_stream_connected and is_godot_present(file_path.strip_edges()):
		godot_path_edit.text = file_path.strip_edges()
		try_connect_lsp()


func _on_packet_recieved(packet: PackedByteArray):
	var packet_text := packet.get_string_from_utf8()
	packet_text = packet_text.replace("Content-Length", "\nContent-Length")
	var packet_test_arr = packet_text.split("\n", false)
	var results := []  # it's not used for now
	var last_completion_list: Dictionary = {}
	for entry in packet_test_arr:
		if not entry.strip_edges().is_empty():
			var converted = str_to_var(entry.strip_edges())
			if typeof(converted) == TYPE_DICTIONARY:
				if not converted in results:
					match converted.get("id", UNKNOWN):
						INITIALIZATION:
							was_connected = true
							log_output("Initialization Successful, LSP is ready.")
						COMPLETION_REQUESTED:
							last_completion_list = converted
						UNKNOWN:
							if converted.has("method"):
								match converted["method"]:
									"textDocument/publishDiagnostics":
										handle_diagnostic(converted.get("params"))
					results.append(converted)
	if not last_completion_list.is_empty():
		populate_completion_list(last_completion_list)


func _on_stop_script_pressed() -> void:
	stop_script(current_virtual_script)


func _on_clear_log_pressed() -> void:
	log_viewer.text = ""


func _on_copy_log_pressed() -> void:
	DisplayServer.clipboard_set(log_viewer.text)


func _on_log_button_toggled(toggled_on: bool) -> void:
	output.visible = toggled_on


func _on_delete_script_pressed() -> void:
	remove_virtual_script(current_virtual_script)


func _on_diagnostic_timer_timeout(message: String, line: int) -> void:
	# Clear last highlight
	var editor: CodeEdit = editors.get(current_virtual_script)
	if not editor:
		return
	for l in editor.get_line_count():
		editor.set_line_background_color(l, Color(0, 0, 0, 0))
	if line > editor.get_line_count():
		return
	diagnostics_label.text = message
	diagnostics_label.visible = true
	var highlight := Color(0, 0, 0, 0)
	match diagnostics_label.get_meta("type", Diagnostic.NONE):
		Diagnostic.ERROR:
			highlight = ERROR_COLOR
			highlight.a = 0.1
		Diagnostic.WARN:
			highlight = WARN_COLOR
			highlight.a = 0.1
	editor.set_line_background_color(line, highlight)


####### Actions
func get_script_status(virtual_script: VirtualScript):
	var activator: Node = %Activators.find_child(
		str(virtual_script.get_instance_id()), false, false
	)
	if activator and activator.is_in_group(ACTIVATOR_GROUP):
		return "Running"
	else:
		return "Stopped"


func update_script_status(virtual_script: VirtualScript, update_name := true):
	if virtual_script == current_virtual_script:
		status_info.text = get_script_status(virtual_script)
	match status_info.text:
		"Running":
			virtual_script.was_running = true
			status_info.self_modulate = Color.GREEN
		"Stopped":
			virtual_script.was_running = false
			status_info.self_modulate = Color.ORANGE
	if update_name:
		var idx = virtual_scripts.find(current_virtual_script)
		if script_list.get_item_metadata(idx) != virtual_script.get_instance_id():
			refresh_script_list()
		else:
			script_list.set_item_text(
				idx,
				virtual_script.name + " (%s)" % get_script_status(virtual_script)
			)


func create_virtual_script(data: Dictionary = {}):
	var virtual_script := VirtualScript.new()
	virtual_scripts.append(virtual_script)
	ensure_editor_exists(virtual_script)
	var should_run := false
	if not data.is_empty():
		virtual_script.deserialize(data)
		if virtual_script.was_running:
			should_run = true
	current_virtual_script = virtual_script
	refresh_script_list()
	if should_run:
		run_code(virtual_script)


func ensure_editor_exists(virtual_script: VirtualScript):
	if not editors.get(virtual_script, null):  # If no editor created yet
		var editor: CodeEdit = EDITOR_SCENE.instantiate()
		editor.text_changed.connect(_text_changed)
		editor.highlight_current_line = true
		editor.code_completion_enabled = true
		editors.set(virtual_script, editor)
		editor_container.add_child(editor)
		editor.visible = (virtual_script == current_virtual_script)


func remove_virtual_script(virtual_script: VirtualScript):
	stop_script(virtual_script)
	var old_idx = virtual_scripts.find(virtual_script)
	virtual_scripts.erase(virtual_script)
	var editor: CodeEdit = editors.get(virtual_script, null)
	if editor:
		editors.erase(virtual_script)
		editor.queue_free()
	old_idx = min(old_idx, 0, virtual_scripts.size() - 1)
	if old_idx >= 0:
		current_virtual_script = virtual_scripts[old_idx]
	else:
		current_virtual_script = null
	refresh_script_list()


func reselect_script():
	if not current_virtual_script:
		script_list.deselect_all()

	for idx in script_list.item_count:
		if script_list.get_item_metadata(idx) == current_virtual_script.get_instance_id():
			script_list.select(idx)


func refresh_script_list():
	script_list.clear()
	for script in virtual_scripts:
		var script_idx := script_list.add_item(script.name + "(%s)" % get_script_status(script))
		script_list.set_item_metadata(script_idx, script.get_instance_id())
		if (
			current_virtual_script
			and script.get_instance_id() == current_virtual_script.get_instance_id()
		):
			script_list.select(script_idx)


func stop_script(virtual_script: VirtualScript) -> bool:
	var script_id := virtual_script.get_instance_id()
	var old_executor: Node = activators.find_child(str(script_id), false, false)
	var had_previous_instance := false
	if old_executor:
		had_previous_instance = true
		old_executor.remove_from_group(ACTIVATOR_GROUP)
		old_executor.queue_free()
	update_script_status(virtual_script)
	return had_previous_instance


func run_code(virtual_script: VirtualScript) -> void:
	var had_previous_instance = stop_script(virtual_script)

	if had_previous_instance:
		# Wait for the previous script to be unloaded
		await get_tree().process_frame
		await get_tree().process_frame

	if (
		diagnostics_label.visible
		and diagnostics_label.get_meta("type", Diagnostic.ERROR)
	):
		var label = "[color=red]There are errors in your script. Fix them first![/color]"
		log_output(label)
		return


	var script_id := virtual_script.get_instance_id()
	var new_script := GDScript.new()
	new_script.source_code = virtual_script.source_code
	new_script.reload()
	var instance: Node = ClassDB.instantiate(new_script.get_instance_base_type())
	instance.name = str(script_id)
	instance.set_script(new_script)
	instance.add_to_group(ACTIVATOR_GROUP)
	activators.add_child(instance)
	update_script_status(virtual_script)


func is_godot_present(at_path: String) -> bool:
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


func handle_diagnostic(data: Dictionary):
	if data and not data.is_empty():
		var uid := (data.get("uri") as String).get_file()
		if str(current_virtual_script.get_instance_id()) != uid:
			return
		var diagnostics: Array = data.get("diagnostics", [])
		var last_warn := ""
		var warn_line := -1
		var last_err := ""
		var err_line := -1
		var editor = editors[current_virtual_script]
		for diag: Dictionary in diagnostics:
			match diag.get("code", 0):
				-1: # Error
					var err: String = diag.get("message", 0)
					if "Error while getting cache for script" in err:
						# Ignore this error
						continue
					last_err = diag.get("message", 0)
					err_line = diag.get("range", {}).get("start", {}).get("line", -1)
				_: # Warning
					var w_line: int = diag.get("range", {}).get("start", {}).get("line", -1)
					if w_line > editor.get_line_count():
						# Ignore warnings related to api
						continue
					last_warn = diag.get("message", 0)
					warn_line = warn_line

		if not last_err.strip_edges().is_empty():
			throw_error(last_err, err_line)

		elif not last_warn.strip_edges().is_empty():
			throw_warn(last_warn, warn_line)


func throw_error(message: String, line: int):
	diagnostics_label.set_meta("type", Diagnostic.ERROR)
	var label = "[color=red](Line %s) ERROR: %s[/color]" % [str(line + 1), message]
	for connection in diagnostic_timer.timeout.get_connections():
		diagnostic_timer.timeout.disconnect(connection.callable)
	diagnostic_timer.timeout.connect(_on_diagnostic_timer_timeout.bind(label, line))
	diagnostic_timer.start()


func throw_warn(message: String, line: int):
	diagnostics_label.set_meta("type", Diagnostic.WARN)
	var label = "[color=yellow](Line %s) WARN: %s[/color]" % [str(line + 1), message]
	for connection in diagnostic_timer.timeout.get_connections():
		diagnostic_timer.timeout.disconnect(connection.callable)
	diagnostic_timer.timeout.connect(_on_diagnostic_timer_timeout.bind(label, line))
	diagnostic_timer.start()


func log_output(text: String):
	%LogViewer.text += text + "\n"
	print(text)  # Print to terminal as well


####### LSP SYSTEM
func try_connect_lsp() -> void:
	if stream:
		disconnect_lsp_stream()
	connected.connect(_on_connected_to_lsp_server)
	packet_received.connect(_on_packet_recieved)
	is_stream_connected = false

	# Connect to LSP server
	if is_godot_present(godot_path_edit.text):
		var args = OS.get_cmdline_user_args()
		if "--child" in args:
			return  # This is the headless/LSP instance so don't spawn again

		lsp_process = OS.create_process(
			godot_path_edit.text, [
				"--headless",
				DummyProject.create_project(temp_path),
				"++",
				"--child"
			]
		)
		if lsp_process != -1:
			log_output("Godot starting, process id: %s" % str(lsp_process))
			stream = StreamPeerTCP.new()
			log_output("Connecting to Host: %s, Port: %s" % [HOST, str(PORT)])
			godot_startup_timer.start()
		else:
			log_output("Could not create TCP server...")
	else:
		godot_path_edit.text = ""
		log_output("Godot not found, code suggestions can not be performed")
		disconnect_lsp_stream()


func _on_godot_startup_timer_timeout() -> void:
	godot_connect_attempt += 1
	log_output("Attempt --- %s" % str(godot_connect_attempt))
	stream.disconnect_from_host()
	stream.connect_to_host(HOST, PORT)


func disconnect_lsp_stream() -> void:
	if stream:
		stream.disconnect_from_host()
		stream = null
		is_stream_connected = false
		log_output("stream_disconnected")

	for connection in connected.get_connections():
		connected.disconnect(connection.callable)
	for connection in packet_received.get_connections():
		packet_received.disconnect(connection.callable)
	if lsp_process != -1 and lsp_process != 0:
		log_output("Killing stream at PID: %s" % str(lsp_process))
		OS.kill(lsp_process)
		lsp_process = -1
	godot_connect_attempt = 0


func make_request(request: Dictionary) -> void:
	if not stream:
		return
	var json = JSON.stringify(request)
	var length = json.to_utf8_buffer().size()
	var content = """Content-Length: {length}\r\n\r\n{json}""".format({
		length = length,
		json = json
	})
	var packet = content.to_utf8_buffer()
	stream.put_data(packet)


func scan_for_packets() -> void:
	if not stream:
		return
	var status = stream.get_status()
	match status:
		StreamPeerTCP.STATUS_NONE:
			return
		StreamPeerTCP.STATUS_ERROR:
			if godot_connect_attempt < CONNECTION_MAX_ATTEMPTS:
				if godot_startup_timer.is_stopped():
					godot_startup_timer.start()
			else:
				log_output("Server stream error!")
				disconnect_lsp_stream()
		_: # (STATUS_CONNECTING or STATUS_CONNECTED)
			# update our connection status (called only once)
			if status == StreamPeerTCP.STATUS_CONNECTED and not is_stream_connected:
				is_stream_connected = true
				connected.emit()

			if stream.poll() == OK:  # We have reseaved something from LSP server
				var available_bytes = stream.get_available_bytes()
				if available_bytes > 0:
					var data = stream.get_data(available_bytes)
					if data[0] == OK:
						# A valid packet detected, send it to packet manager.
						packet_received.emit(data[1])
					else:
						log_output("Error when getting data: %s" % error_string(data[0]))
			else:
				if godot_connect_attempt < CONNECTION_MAX_ATTEMPTS:
					if godot_startup_timer.is_stopped():
						godot_startup_timer.start()
				else:
					log_output("Failed to poll()")


func _on_connected_to_lsp_server():
	var request = json_rpc.make_request(
		"initialize", {
			"processId": null,
			"rootUri": "file:///%s" % godot_path_edit.text,
			"capabilities": {}
		},
		INITIALIZATION
	)
	log_output("CONNECTED to Server Initializing LSP...")
	make_request(request)


func populate_completion_list(lsp_auto_comp_data: Dictionary):
	var editor: CodeEdit = editors.get(current_virtual_script)
	for entry in lsp_auto_comp_data.get("result", []):
		if typeof(entry) == TYPE_DICTIONARY:
			var add_text = entry.get("insertText", "")
			var label = entry.get("label", "")
			var type = entry.get("kind", 0)
			match type:
				1: # (Keywords e.g var, int etc.)
					editor.add_code_completion_option(CodeEdit.KIND_MEMBER, label, add_text)
				2:
					editor.add_code_completion_option(CodeEdit.KIND_FUNCTION, label, add_text)
				6:
					editor.add_code_completion_option(CodeEdit.KIND_VARIABLE, label, add_text)
				7:
					editor.add_code_completion_option(CodeEdit.KIND_CLASS, label, add_text)
				10:
					editor.add_code_completion_option(CodeEdit.KIND_MEMBER, label, add_text)
				13:
					editor.add_code_completion_option(CodeEdit.KIND_ENUM, label, add_text)
				21:
					editor.add_code_completion_option(CodeEdit.KIND_CONSTANT, label, add_text)
				23:
					editor.add_code_completion_option(CodeEdit.KIND_SIGNAL, label, add_text)
				_:
					editor.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, label, add_text)
					log_output("This type was uncategorized: %s %s" % [str(type), add_text])

	editor.update_code_completion_options(true)


func test_reg():
	var file_uid := str(current_virtual_script.get_instance_id())
	#var source := current_virtual_script.prepare_for_intellisence()
	var source := current_virtual_script.source_code
	var request_new_file = json_rpc.make_request(
		"textDocument/didOpen", {
				"textDocument": {
					"uri": "file:///virtual/%s" % file_uid,
					"languageId": "gdscript",
					"version": 1,
					"text": source
				}
			},
		FILE_REGISTERED
	)
	make_request(request_new_file)

func send_autocomplete_request() -> void:
	if not DirAccess.dir_exists_absolute(temp_path):
		return
	var file_uid := str(current_virtual_script.get_instance_id())
	var source := current_virtual_script.prepare_for_intellisence()

	if is_stream_connected:
		if not current_virtual_script.is_registered_to_lsp: # register a file.
			var request_new_file = json_rpc.make_request(
				"textDocument/didOpen", {
						"textDocument": {
							"uri": "file:///virtual/%s" % file_uid,
							"languageId": "gdscript",
							"version": 2,
							"text": source
						}
					},
				FILE_REGISTERED
			)
			make_request(request_new_file)
			current_virtual_script.is_registered_to_lsp = true
		else: # Make changes to file.
			var request_change = json_rpc.make_request(
				"textDocument/didChange", {
						"textDocument": {
							"uri": "file:///virtual/%s" % file_uid,
							"version": 2,
						},
						"contentChanges": [
							{ "text": source }
						]
					},
				FILE_CHANGED
			)
			make_request(request_change)

		# Request Completion
		var editor: CodeEdit = editors.get(current_virtual_script)
		var request_completion = json_rpc.make_request(
			"textDocument/completion", {
					"textDocument": {
						"uri": "file:///virtual/%s" % file_uid,
						"version": 2,
					},
					"position": {
						"line": editor.get_caret_line(), "character": editor.get_caret_column()
					}
				},
			COMPLETION_REQUESTED
		)
		make_request(request_completion)


func _on_file_browse_pressed() -> void:
	if not godot_path_edit.text.strip_edges().is_empty():
		if FileAccess.file_exists(godot_path_edit.text.strip_edges()):
			var old_path = godot_path_edit.text.strip_edges()
			executable_chooser.current_file = old_path
			executable_chooser.current_dir = old_path.get_base_dir()
	executable_chooser.popup_centered()


func _on_executable_chooser_file_selected(path: String) -> void:
	if is_godot_present(path):
		godot_path_edit.text = path
		if not is_stream_connected:
			try_connect_lsp()
