class_name GDScriptHighlight
extends CodeHighlighter

const ANNOTATION_COLOR := Color("ffb373")
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
	# Variant core types
	"null", "bool", "int", "float", "String", "StringName",
	"Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
	"Rect2", "Rect2i",
	"Transform2D", "Transform3D",
	"Plane", "Quaternion", "AABB", "Basis", "Projection",
	"Color",
	"NodePath", "RID", "Object", "Callable", "Signal",
	"Dictionary", "Array",
	"PackedByteArray", "PackedInt32Array", "PackedInt64Array",
	"PackedFloat32Array", "PackedFloat64Array",
	"PackedStringArray",
	"PackedVector2Array", "PackedVector3Array", "PackedColorArray",

	# Engine base classes
	"Object", "RefCounted", "Resource",
	"Node", "Window", "Viewport",
	"Node2D", "Node3D", "Control",

	# Common node types (2D)
	"Sprite2D", "AnimatedSprite2D", "Camera2D",
	"CollisionObject2D", "CollisionShape2D", "CollisionPolygon2D",
	"CharacterBody2D", "RigidBody2D", "StaticBody2D", "Area2D",
	"TileMap", "TileMapLayer",

	# Common node types (3D)
	"MeshInstance3D", "Camera3D", "Light3D",
	"DirectionalLight3D", "OmniLight3D", "SpotLight3D",
	"CollisionObject3D", "CollisionShape3D",
	"CharacterBody3D", "RigidBody3D", "StaticBody3D", "Area3D",

	# UI
	"Control", "Button", "Label", "Panel", "TextureRect",
	"LineEdit", "TextEdit", "RichTextLabel",
	"VBoxContainer", "HBoxContainer", "GridContainer",

	# Resources
	"Texture2D", "Texture3D", "Material", "Shader", "ShaderMaterial",
	"Mesh", "ArrayMesh", "StandardMaterial3D",
	"Animation", "AnimationPlayer", "AnimationTree",
	"AudioStream", "AudioStreamPlayer",

	# Misc
	"Image", "InputEvent", "SceneTree", "ExtensionsApi"
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
	var err = regex.compile(keyword)
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
	while start_idx != -1:
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

func highlight_func_use(line: String, result: Dictionary):
	var func_def_index := line.find("func")
	var comment_index := line.find("#")

	var r_start := line.length()  # End of the actual string.
	while r_start != -1:
		r_start = line.rfind("(", r_start - 1)
		if comment_index != -1 and r_start > comment_index:
			continue
		if r_start == -1:
			break

		var l_start := r_start  # Start of the actual string.
		# move leftward
		var name_started := false
		while l_start >= 0:
			l_start -= 1
			# reached func keyword instead of getting the name
			if func_def_index != -1 and l_start <= func_def_index + 3:
				break
			if line[l_start] in GDSCRIPT_SYMBOLS + GDSCRIPT_KEYWORDS + GDSCRIPT_TYPES:
				break
			if not name_started and line[l_start].is_valid_ascii_identifier():
				name_started = true
			if name_started:
				var start_indicators := (
					[" ", "	"]
				)
				if line[l_start] in start_indicators:
					break
		result[l_start + 1] = {
			"color": FUNCTION_COLOR,
		}
		result[r_start] = {
			"color": SYMBOL_COLOR,
		}

func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var result := {}  # Order of
	var text := get_text_edit().get_line(line)

	# Keywords etc...
	for keyword in GDSCRIPT_SYMBOLS: # Should be at the top
		result.merge(add_operator(keyword, SYMBOL_COLOR, text), true)
	for keyword in GDSCRIPT_KEYWORDS:
		result.merge(add_keyword("\\b" + keyword + "\\b", KEYWORD_COLOR, text), true)
	for keyword in GDSCRIPT_TYPES:
		result.merge(add_keyword("\\b" + keyword + "\\b", TYPE_COLOR, text), true)

	# Annotations
	result.merge(add_keyword("@[A-Za-z_][A-Za-z0-9_]*", ANNOTATION_COLOR, text), true)

	# Highlight function declaration
	highlight_func_defs(text, result)
	highlight_func_use(text, result)

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
