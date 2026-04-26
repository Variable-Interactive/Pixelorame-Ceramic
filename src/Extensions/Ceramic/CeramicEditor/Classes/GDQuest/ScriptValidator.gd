class_name ScriptValidator
extends RefCounted


const BENIGN_CACHE_ERROR := 'Error while getting cache for script "".'
# Maximum allowed iterations in while loops to prevent infinite loops.
#
# Keep this number low to avoid freezing the app if the student calls print() in
# the loop.
const MAX_WHILE_LOOP_ITERATIONS := 262144  # 512x512

signal message(value: String)

var MessageBus := MessageBusClass.new()
static var REGEX_DIVSION_BY_ZERO := RegEx.create_from_string((r"[/%] *0"))
static var REGEX_CLASS_NAME := RegEx.create_from_string(r"\s*class_name\s")
static var REGEX_TOP_ANNOTATION := RegEx.create_from_string(r"\s*@")


func validate_code(script_text: String, script_name := "") -> int:
	if not MessageBus:
		return -1

	# Prepare everything for testing user code.
	message.emit(tr("Validating Your Code..."))

	# Mixed indentation is an error we cannot catch from the GDScript parser in
	# some situations, so we manually look for it to help students understand the error.
	var mixed_indent_error_line := _check_for_mixed_indentation(script_text)
	if mixed_indent_error_line != -1:
		var error := ScriptError.new()
		error.message = "Parse error: Spaces used before tabs on a line"
		error.severity = 1
		error.code = GDScriptCodes.ErrorCode.SPACES_BEFORE_TABS
		error.error_range.start.line = mixed_indent_error_line
		error.error_range.start.character = 0
		MessageBus.print_script_error(error, script_name)
		return -1

	# Do local sanity checks for the script.
	var tokenizer := MiniGDScriptTokenizer.new(script_text)

	# Check for recursive functions
	var recursive_function := tokenizer.find_any_recursive_function()
	if recursive_function != "":
		var error := ScriptError.new()
		error.message = (
			tr("The function `%s` calls itself, this creates an infinite loop")
			% [recursive_function]
		)
		error.severity = 1
		error.code = GDQuestCodes.ErrorCode.RECURSIVE_FUNCTION
		MessageBus.print_script_error(error, script_name)
		return -1
	# Check for infinite while loops
	if tokenizer.has_infinite_while_loop():
		var error := ScriptError.new()
		error.message = tr(
			"You have a while loop that runs forever (while true) without a break statement. This will freeze the app.",
		)
		error.severity = 1
		error.code = GDQuestCodes.ErrorCode.INFINITE_WHILE_LOOP
		MessageBus.print_script_error(error, script_name)
		return -1

	var verifier_script := script_text
	var script_is_desynced_by_one_line := false

	if not _has_class_name(verifier_script):
		# GDScriptAnalyzer needs a path or class_name. As we're feeding code directly into the parser,
		# we can't really have a path, so we need a class_name to fool it
		var initial_insertion_character := _find_first_non_annotation_entry_point(verifier_script)
		verifier_script = verifier_script.insert(initial_insertion_character, "class_name TEMP_UserScript\n")
		script_is_desynced_by_one_line = true

	var errors := []

	if not errors.is_empty():
		# GDScriptAnalyzer will complain the first time it parses the script from the verifier
		# so we capture it here to ignore
		for i in range(errors.size() - 1, -1, -1):
			var error: ScriptError = errors[i]
			if error.message == BENIGN_CACHE_ERROR:
				errors.remove_at(i)

	if not errors.is_empty():
		if script_is_desynced_by_one_line:
			for error: ScriptError in errors:
				error.error_range.start.line -= 1
				error.error_range.end.line -= 1

		for index in errors.size():
			var error: ScriptError = errors[index]
			MessageBus.print_script_error(error, script_name)

	return OK


func add_guards(script_text, script_name) -> String:
	script_text = MessageBus.replace_print_calls_in_script(script_name, script_text)

	# Guard against infinite while loops
	if "while " in script_text:
		var modified_code := PackedStringArray()
		var guard_counter = 0
		for line in script_text.split("\n"):
			if "while " in line and not line.strip_edges(true, false).begins_with("#"):
				var indent := 0
				while line[indent] == "\t":
					indent += 1

				var tabs := "\t".repeat(indent)
				var guard_counter_varname := "__guard_counter" + str(guard_counter)
				guard_counter += 1
				modified_code.append(tabs + "var " + guard_counter_varname + " := 0")
				modified_code.append(line)
				modified_code.append(tabs + "\t" + guard_counter_varname + " += 1")
				modified_code.append(
					tabs + "\t" + "if " + guard_counter_varname + " > %s:" % MAX_WHILE_LOOP_ITERATIONS,
				)
				modified_code.append(tabs + "\t\t" + "break")
			else:
				modified_code.append(line)
		script_text = "\n".join(modified_code)
	elif REGEX_DIVSION_BY_ZERO.search(script_text):
		var error := ScriptError.new()
		error.message = tr(
			'There is a division by zero in your code. You cannot divide by zero in code. Please ensure you have no "/ 0" or "% 0" in your code.',
		)
		error.severity = 1
		error.code = GDQuestCodes.ErrorCode.INVALID_NO_CATCH
		MessageBus.print_script_error(error, script_name)
		return ""

	script_text += """
var MessageBus: MessageBusClass:
	get():
		return get_parent().get_parent().non_lsp_validator.MessageBus
"""

	return script_text


func _has_class_name(source: String) -> bool:
	return REGEX_CLASS_NAME.search(source) != null


func _find_first_non_annotation_entry_point(source: String) -> int:
	var lines := source.split("\n")
	var character_count := 0
	for i in lines.size():
		if REGEX_TOP_ANNOTATION.search(lines[i]) == null:
			break
		character_count += lines[i].length() + 1
	return character_count


# Checks if the script text has mixed tabs and spaces in indentation.
# Returns the line number of the error or -1 if there's no error
func _check_for_mixed_indentation(text: String) -> int:
	var lines := text.split("\n")
	for line_number in range(lines.size()):
		var line := lines[line_number]
		if line.is_empty() or line.strip_edges() == "":
			continue

		var has_space := false
		var has_tab := false

		for i in range(line.length()):
			var character := line[i]
			if character == ' ':
				has_space = true
			elif character == '\t':
				has_tab = true
			else:
				break

		if has_space and has_tab:
			return line_number
	return -1
