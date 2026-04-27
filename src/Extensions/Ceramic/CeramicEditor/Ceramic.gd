extends PanelContainer


const CERAMIC_CONFIG_PATH := "user://ceramic_data.ini"
const ACTIVATOR_GROUP := "Activators"
const EDITOR_SCENE := preload("res://src/Extensions/Ceramic/CeramicEditor/Nodes/Editor.tscn")

const ERROR_COLOR := Color.RED
const WARN_COLOR := Color.YELLOW

enum Diagnostic { NONE, WARN, ERROR }

var ceramic_data := ConfigFile.new()

var godot_lsp := GodotLSP.new()
var non_lsp_validator := ScriptValidator.new()

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
			godot_lsp.send_autocomplete_request(value, editor)
		if script_info_bar:
			script_info_bar.visible = (value != null)

var lsp_enabled := false:
	set(value):
		for script in virtual_scripts:  # Reset script registeration
			script.is_registered_to_lsp = false
		lsp_enabled = value
		if value and not godot_lsp.is_active():
			godot_lsp.try_connect_lsp()
		else:
			godot_lsp.disconnect_lsp_stream()

var has_api_errors := false

@onready var lsp_checkbox: CheckButton = %LSPEnabled  # LSP toggle
@onready var activators: Node = %Activators  # parent thar hosts nodes for the scripts
@onready var script_list: ItemList = %ScriptList  # ItemList of stript files
@onready var log_viewer: RichTextLabel = %LogViewer  # The Output console.
@onready var diagnostics_label: RichTextLabel = %Diagnostics  # Label that displays errors in scripts
@onready var script_name_edit: LineEdit = %ScriptNameEdit   # The Script name field
@onready var godot_path_edit: LineEdit = %GodotPath  # Godot path field
@onready var editor_container: VBoxContainer = %EditorContainer  # Host container of the editor CodeEdit nodes.
@onready var output_container: HBoxContainer = %Output  # Container of the output console.
@onready var status_info: Label = %StatusInfo  # Shows current starus of script (Running/stopped)
@onready var diagnostic_timer: Timer = %DiagnosticTimer  # Used to wait for text to stop for displaying diagnostic.
@onready var executable_chooser: FileDialog = %ExecutableChooser
@onready var extension_api: Node  ## A variable for easy reference to the Api
@onready var script_info_bar: HBoxContainer = %ScriptInfoBar  # Container for name and status of script.
@onready var path_container: HBoxContainer = %PathContainer  # Container to godot path field

func _ready() -> void:
	# LSP signals
	add_child(godot_lsp)
	non_lsp_validator.MessageBus.print_requested.connect(print_bus_message)
	non_lsp_validator.message.connect(log_output)
	godot_lsp.packet_received.connect(_on_packet_recieved)
	godot_lsp.initialized.connect(_lsp_initialized)
	godot_lsp.message.connect(log_output)

	extension_api = get_node_or_null("/root/ExtensionsApi")  # Accessing the Api
	if extension_api:
		extension_api.general.get_global().pixelorama_about_to_close.connect(_exit_tree)
		extension_api.general.get_global().pixelorama_about_to_close.connect(
			godot_lsp.disconnect_lsp_stream
		)

	var err := ceramic_data.load(CERAMIC_CONFIG_PATH)
	if err == OK:
		#var config: ConfigFile = extension_api.general.get_config_file()
		var data: Dictionary = ceramic_data.get_value("Ceramic", "data", {})
		var godot_path: String = ceramic_data.get_value("Ceramic", "godot", "")
		lsp_enabled = ceramic_data.get_value("Ceramic", "lsp_enabled", lsp_enabled)
		lsp_checkbox.set_pressed_no_signal(lsp_enabled)
		if not godot_path.is_empty() and GodotLSP.is_godot_present(godot_path):
			godot_lsp.godot_path = godot_path
			godot_path_edit.text = godot_path
		if data.is_empty():
			create_virtual_script()
		else:
			deserialize(data)
	else:
		create_virtual_script()


func save_data() -> void:
	ceramic_data.set_value("Ceramic", "data", serialize())
	ceramic_data.set_value("Ceramic", "godot", godot_path_edit.text)
	ceramic_data.set_value("Ceramic", "lsp_enabled", lsp_enabled)
	ceramic_data.save(CERAMIC_CONFIG_PATH)


func serialize():
	var scripts := []
	for script in virtual_scripts:
		scripts.append(script.serialize())
	return {"scripts": scripts}


func deserialize(data: Dictionary):
	var scripts = data.get("scripts", [])
	for script_data in scripts:
		create_virtual_script(script_data)


func _exit_tree() -> void:
	if extension_api:
		save_data()


## LSP Handler


func _on_lsp_enabled_toggled(toggled_on: bool) -> void:
	if lsp_enabled != toggled_on:
		lsp_enabled = toggled_on
	path_container.visible = toggled_on


func _lsp_initialized() -> void:
	log_output("Initialization Successful, LSP is ready.")
	godot_lsp.send_autocomplete_request(
		current_virtual_script, editors.get(current_virtual_script)
	)


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
					match converted.get("id", GodotLSP.UNKNOWN):
						GodotLSP.COMPLETION_REQUESTED:
							last_completion_list = converted
						GodotLSP.SIGNATURE_REQUESTED:
							if converted.get("result"):
								handle_signature(converted.get("result"))
							else:
								handle_signature({})
						GodotLSP.UNKNOWN:
							if converted.has("method"):
								match converted["method"]:
									"textDocument/publishDiagnostics":
										handle_diagnostic(converted.get("params"))
					results.append(converted)
	if not last_completion_list.is_empty():
		populate_completion_list(last_completion_list)


func handle_signature(data: Dictionary):
	var signatures: Array = data.get("signatures", [])
	if not current_virtual_script:
		return
	var editor = editors[current_virtual_script]
	if not editor:
		return
	for signature: Dictionary in signatures:
		for key in signature.keys():
			editor.show_signature(signature["label"], signature["documentation"]["value"])


func handle_diagnostic(data: Dictionary):
	# Give API errors priority
	var api_errors := current_virtual_script.api_errors
	if not api_errors.is_empty():
		for error in api_errors:
			throw_error(error, 0)
		return

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
					if w_line >= editor.get_line_count():
						# Ignore warnings related to api
						continue
					last_warn = diag.get("message", 0)
					warn_line = warn_line

		if not last_err.strip_edges().is_empty():
			throw_error(last_err, err_line)

		elif not last_warn.strip_edges().is_empty():
			throw_warn(last_warn, warn_line)


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
				17:
					editor.add_code_completion_option(CodeEdit.KIND_FILE_PATH, label, add_text)
				21:
					editor.add_code_completion_option(CodeEdit.KIND_CONSTANT, label, add_text)
				23:
					editor.add_code_completion_option(CodeEdit.KIND_SIGNAL, label, add_text)
				_:
					editor.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, label, add_text)
					log_output("This type was uncategorized: %s %s" % [str(type), add_text])

	editor.update_code_completion_options(true)


## Script Handler


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
	if not non_lsp_validator.validate_code(virtual_script.source_code, str(script_id)) == OK:
		return
	new_script.source_code = non_lsp_validator.add_guards(
		virtual_script.source_code, str(script_id)
	)

	var error_code := new_script.reload()
	if not new_script.can_instantiate() or error_code != OK:
		log_output("Script errored out (code %s); stopping" % [error_code])
		var label = "[color=red]There are errors in your script. Fix them first![/color]"
		log_output(label)
		return

	var instance: Node = ClassDB.instantiate(new_script.get_instance_base_type())
	instance.name = str(script_id)
	instance.set_script(new_script)
	instance.add_to_group(ACTIVATOR_GROUP)
	activators.add_child(instance)
	update_script_status(virtual_script)


func throw_error(message: String, line: int, show_in_log := false):
	diagnostics_label.set_meta("type", Diagnostic.ERROR)
	var label = "[color=red](Line %s) ERROR: %s[/color]" % [str(line + 1), message]
	if show_in_log:
		log_output(label)
	for connection in diagnostic_timer.timeout.get_connections():
		diagnostic_timer.timeout.disconnect(connection.callable)
	diagnostic_timer.timeout.connect(_on_diagnostic_timer_timeout.bind(label, line))
	diagnostic_timer.start()


func throw_warn(message: String, line: int, show_in_log := false):
	diagnostics_label.set_meta("type", Diagnostic.WARN)
	var label = "[color=yellow](Line %s) WARN: %s[/color]" % [str(line + 1), message]
	if show_in_log:
		log_output(label)
	for connection in diagnostic_timer.timeout.get_connections():
		diagnostic_timer.timeout.disconnect(connection.callable)
	diagnostic_timer.timeout.connect(_on_diagnostic_timer_timeout.bind(label, line))
	diagnostic_timer.start()


# Adds a message related to a specific line in a specific file
func print_bus_message(
		type: int,
		text: String,
		_file_name: String,
		line: int,
		_character: int,
		_code: int,
) -> void:
	if not is_inside_tree():
		return

	if type in [
		non_lsp_validator.MessageBus.MESSAGE_TYPE.ASSERT,
		non_lsp_validator.MessageBus.MESSAGE_TYPE.ERROR,
	]:
		throw_error(text, line, true)
		return
	elif type == non_lsp_validator.MessageBus.MESSAGE_TYPE.WARNING:
		throw_warn(text, line, true)

	print_output([text])


# Prints plain text output. Use this when you want to display the output of a
# print statement.
func print_output(values: Array) -> void:
	if not is_inside_tree():
		return
	var output := ""
	for value in values:
		output += var_to_str(value)
	log_output(output)


func log_output(text: String):
	%LogViewer.text += text + "\n"
	print(text)  # Print to terminal as well


####### Signals
func _on_godot_path_text_changed(file_path: String) -> void:
	if lsp_enabled and GodotLSP.is_godot_present(file_path.strip_edges()):
		godot_lsp.godot_path = file_path.strip_edges()
		godot_path_edit.text = file_path.strip_edges()
		lsp_enabled = true  # re-call setter


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


func _text_changed() -> void:
	var editor: CodeEdit = editors.get(current_virtual_script)
	if editor:
		if diagnostics_label.visible:
			diagnostics_label.visible = false
			diagnostics_label.set_meta("type", Diagnostic.NONE)
			for line in editor.get_line_count():
				editor.set_line_background_color(line, Color(0, 0, 0, 0))
			editor.show_signature("")

		if current_virtual_script.source_code != editor.text:
			current_virtual_script.source_code = editor.text
			if lsp_enabled:
				if not godot_lsp.is_active():
					lsp_enabled = true  # re-call the setter
					return
				godot_lsp.send_autocomplete_request(current_virtual_script, editor)
			else:
				for error in current_virtual_script.api_errors:
					throw_error(error, 0)


func _on_diagnostic_timer_timeout(message: String, line: int) -> void:
	# Clear last highlight
	var editor: CodeEdit = editors.get(current_virtual_script)
	if not editor:
		return
	for l in editor.get_line_count():
		editor.set_line_background_color(l, Color(0, 0, 0, 0))
	if line < 0 or line >= editor.get_line_count():
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


func _on_script_list_item_selected(index: int) -> void:
	if index < virtual_scripts.size():
		current_virtual_script = virtual_scripts[index]


func _on_new_script_button_pressed() -> void:
	create_virtual_script()


func _on_delete_script_pressed() -> void:
	remove_virtual_script(current_virtual_script)


func _on_run_script_pressed() -> void:
	run_code(current_virtual_script)
	save_data()  # Save AFTER making sure the script runs


func _on_stop_script_pressed() -> void:
	# Save first (we don't know if it will crash on close or not)
	current_virtual_script.was_running = false
	save_data()
	stop_script(current_virtual_script)


func _on_file_browse_pressed() -> void:
	if not godot_path_edit.text.strip_edges().is_empty():
		if FileAccess.file_exists(godot_path_edit.text.strip_edges()):
			var old_path = godot_path_edit.text.strip_edges()
			executable_chooser.current_file = old_path
			executable_chooser.current_dir = old_path.get_base_dir()
	executable_chooser.popup_centered()


func _on_executable_chooser_file_selected(path: String) -> void:
	if GodotLSP.is_godot_present(path):
		godot_path_edit.text = path
		if not godot_lsp.is_active() and lsp_enabled:
			lsp_enabled = true  # re-call setter


func _on_log_button_toggled(toggled_on: bool) -> void:
	output_container.visible = toggled_on


func _on_clear_log_pressed() -> void:
	log_viewer.text = ""


func _on_copy_log_pressed() -> void:
	DisplayServer.clipboard_set(log_viewer.text)
