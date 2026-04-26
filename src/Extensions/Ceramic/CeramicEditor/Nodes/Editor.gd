extends CodeEdit

@onready var signature_popup: Popup = %SignaturePopup
@onready var signature_label: RichTextLabel = %SignatureLabel
@onready var description_field: RichTextLabel = %Description

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var code_highlight := GDScriptHighlight.new()
	syntax_highlighter = code_highlight
	signature_popup.gui_disable_input = true
	signature_popup.unfocusable = true
	# (See: https://github.com/godotengine/godot/issues/47005)
	signature_popup.popup_centered()
	await get_tree().process_frame
	signature_popup.hide()  # otherwise the popup opens too tall.


func show_signature(label: String = "", description: String = "") -> void:
	signature_label.text = label
	description_field.text = "[color=%s]%s[/color]" % [
		GDScriptHighlight.TEXT_COLOR, description.replace(label, "").strip_edges()
	]
	signature_popup.size = signature_popup.min_size
	#var pos = get_caret_draw_pos() - Vector2(signature_popup.size.x / 2.0, signature_popup.size.y + 10)
	#pos += global_position
	signature_popup.popup(Rect2i(get_global_mouse_position(), signature_popup.min_size))
	if label.is_empty():
		signature_popup.hide()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		signature_popup.hide()
