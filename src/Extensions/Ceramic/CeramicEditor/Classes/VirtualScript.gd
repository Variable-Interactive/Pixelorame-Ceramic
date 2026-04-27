class_name VirtualScript
extends RefCounted

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
	return source_code + "\n" + API.API_APPENDAGE
