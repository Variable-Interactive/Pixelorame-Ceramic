extends Node

# This script acts as a setup for the extension
func _enter_tree() -> void:
	# See https://pixelorama.org/extension_system/extension_api for the API docs.
	pass

func _exit_tree() -> void:  # Extension is being uninstalled or disabled
	# remember to remove things that you added using this extension
	ExtensionsAPI.get_api_version()

class ExtensionsAPI:
	static func get_api_version() -> int:
		return -1

	static func get_main_nodes(extension_name: StringName) -> Array[Node]:
		return []
