class_name VirtualScript
extends RefCounted

const _ceramic_button_header := """
## Ceramic Specific feature:
## Adds a control element in the Inspector tab of the Ceramic editor (when the script is run).
## The added elements are auto removed when the script is stopped.
func add_inspector_item(control: Control) -> void:
"""
const _ceramic_button_code := """
var _inspector_element_holder_node: HFlowContainer
func add_inspector_item(script_name: String, node: Node, button: Control) -> void:
	if not _inspector_element_holder_node:
		var _sections_container := get_tree().get_first_node_in_group("ElementsContainer")
		print(_sections_container)
		var _new_section := VBoxContainer.new()
		node.tree_exiting.connect(_new_section.queue_free)
		var title := Label.new()
		title.text = "Script: %s" % script_name
		_inspector_element_holder_node = HFlowContainer.new()
		_new_section.add_child(title)
		_new_section.add_child(_inspector_element_holder_node)
		_sections_container.add_child(_new_section)
	_inspector_element_holder_node.add_child(button)
"""

var name: String = "New Script"
var was_running: bool = false
var api_errors: PackedStringArray:
	get():
		return API.validate_api_usage(source_code)
var source_code: String = """extends Node

# NOTE: This script is meant to be run through this code editor.
# INFO: You don't have to save the scripts, they are auto saved in a
# configuration file.


func _enter_tree() -> void:
	# INFO: To access api, simply type ExtensionsApi (autocomplete is supported through LSP)
	# See https://pixelorama.org/extension_system/extension_api for the API docs.
	# or https://pixelorama.org/extension_system/extension_examples for Examples.

	print(ExtensionsApi.get_api_version())


func _exit_tree() -> void:  # Extension is being uninstalled or disabled
	# remember to remove things that you added using this extension
	pass
"""


## non serializable variables
var is_registered_to_lsp = false


func serialize() -> Dictionary:
	return {
		"name": name,
		"was_running": was_running,
		"source_code": source_code
	}

func deserialize(data: Dictionary):
	name = data.get("name", name)
	was_running = data.get("was_running", was_running)
	source_code = data.get("source_code", source_code)


func prepare_for_intellisence() -> String:
	return source_code+ "\n" + _ceramic_button_header + "\n" + API.compile_api()


func prepare_for_running() -> String:
	var result := source_code

	# Feature: Ceramic Inspector Elements
	var search := result.find("add_inspector_item")
	while search != -1:
		var func_start := result.find("(", search)
		if func_start == -1:
			return "extends Node"  # Invalid Source code
		result = result.erase(search, func_start - search + 1)
		result = result.insert(
			search, "add_inspector_item(\"%s\", self," % name.replace("\"", "")
		)
		search = result.find("add_inspector_item", search + 1)
	print()
	return result + "\n" + _ceramic_button_code
