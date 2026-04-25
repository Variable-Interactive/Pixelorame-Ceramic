extends CodeEdit


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var code_highlight := GDScriptHighlight.new()
	syntax_highlighter = code_highlight


class GDScriptHighlight:
	extends CodeHighlighter

	const COMMENT_COLOR := Color("ffffff80")
	const FUNCTION_COLOR := Color("57b3ff")
	const FUNCTION_DEFINE_COLOR := Color("66e6ff")
	const KEYWORD_COLOR := Color("ff7085")
	const STRING_COLOR := Color("ffeda1")
	const SYMBOL_COLOR := Color("abc9ff")
	const TEXT_COLOR := Color("ffffffbf")
	const TYPE_COLOR := Color("c7ffed")

	const GDSCRIPT_KEYWORDS := [
		"if", "elif", "else",
		"for", "while", "break", "continue", "pass",
		"func", "class", "class_name", "extends",
		"is", "in", "as",
		"return", "await", "yield",
		"var", "const", "static",
		"enum", "signal",
		"match",
		"and", "or", "not",
		"true", "false", "null",
		"self", "super",
		"breakpoint",
	]

	const GDSCRIPT_SYMBOLS := [
		":", ",", ".", ";",
		"(", ")", "[", "]", "{", "}",
		"->",
		"+", "-", "*", "/", "%", "**",
		"=", "+=", "-=", "*=", "/=", "%=",
		"==", "!=", "<", ">", "<=", ">=",
		"&", "|", "^", "~", "<<", ">>"
	]

	const GDSCRIPT_TYPES := [
		"int", "float", "bool", "void", "String",
		"Vector2", "Vector3", "Vector4",
		"Color", "Array", "Dictionary",
		"Node", "Node2D", "Node3D",
		"Resource", "Object",
		"ExtensionsApi"
	]

	func add_range(
		start: String, end: String, color: Color, line: String, formatter_dict: Dictionary
	) -> void:
		var comment_index := line.find("#")
		var regex := RegEx.new()
		var old_keys = formatter_dict.keys()
		var starts = PackedInt32Array()
		var ends = PackedInt32Array()
		var i: int = 0
		var err_start = regex.compile(start)
		if err_start != OK:
			return
		for m in regex.search_all(line):
			if is_same(end, start) and i % 2 != 0:
				i += 1
				continue
			var start_index = m.get_start()
			if comment_index != -1 and start_index > comment_index:
				break
			if start_index == -1:
				break
			starts.append(start_index)
			formatter_dict[start_index] = {
				"color": color,
			}
			i += 1

		var err_end = regex.compile(end)
		if err_end != OK:
			return
		for m in regex.search_all(line):
			if is_same(end, start) and i % 2 == 0:
				i += 1
				continue
			var end_index = m.get_end()
			if comment_index != -1 and end_index > comment_index:
				break
			if end_index == -1:
				break
			ends.append(end_index)
			formatter_dict[end_index] = {
				"color": TEXT_COLOR,
			}
			for key in old_keys.duplicate():
				if starts.size() >= ends.size():
					if key in range(starts[ends.size() - 1] + 1, ends[ends.size() - 1]):
						formatter_dict.erase(key)
						old_keys.erase(key)
			i += 1
		return

	func add_keyword(keyword: String, color: Color, line: String) -> Dictionary:
		var result: Dictionary = {}
		var comment_index := line.find("#")
		var regex := RegEx.new()
		var err = regex.compile("\\b" + keyword + "\\b")
		if err != OK:
			return result
		for m in regex.search_all(line):
			var start_index = m.get_start()
			if comment_index != -1 and start_index > comment_index:
				break
			if start_index == -1:
				break
			result[start_index] = {
				"color": color,
			}
			result[m.get_end()] = {
				"color": TEXT_COLOR,
			}
		return result


	func add_operator(operator: String, color: Color, line: String) -> Dictionary:
		var result: Dictionary = {}
		var comment_index := line.find("#")
		var start_idx: int = 0
		while true:
			start_idx = line.find(operator, start_idx)
			if comment_index != -1 and start_idx > comment_index:
				break
			if start_idx == -1:
				break
			result[start_idx] = {
				"color": color,
				"symbol": operator
			}
			start_idx += operator.length()
			result[start_idx] = {
				"color": TEXT_COLOR,
				"symbol": "(space)"
			}
		return result


	func highlight_func_defs(line: String, result: Dictionary):
		var func_def_index := line.find("func")
		if func_def_index != -1:
			var name_start := func_def_index + 5
			var name_end := name_start
			while name_end < line.length() and line[name_end].is_valid_ascii_identifier():
				name_end += 1
			result[name_start] = {
				"color": FUNCTION_DEFINE_COLOR,
			}

	func _get_line_syntax_highlighting(line: int) -> Dictionary:
		var result := {}  # Order of
		var text := get_text_edit().get_line(line)

		# Keywords etc...
		for keyword in GDSCRIPT_SYMBOLS: # Should be at the top
			result.merge(add_operator(keyword, SYMBOL_COLOR, text), true)
		for keyword in GDSCRIPT_KEYWORDS:
			result.merge(add_keyword(keyword, KEYWORD_COLOR, text), true)
		for keyword in GDSCRIPT_TYPES:
			result.merge(add_keyword(keyword, TYPE_COLOR, text), true)
		# Highlight function declaration
		highlight_func_defs(text, result)

		## Comments
		var comment_index := text.find("#")
		if comment_index != -1:
			result[comment_index] = {
				"color": COMMENT_COLOR,
			}

		## Ranges
		add_range("\"", "\"", STRING_COLOR, text, result)
		add_range("'", "'", STRING_COLOR, text, result)
		result.sort()
		return result
