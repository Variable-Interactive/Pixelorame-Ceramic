extends Node

@onready var extension_api: Node  ## A variable for easy reference to the Api

# some references to nodes that will be created later
var tab_reference

# This script acts as a setup for the extension
func _enter_tree() -> void:
	extension_api = get_node_or_null("/root/ExtensionsApi")  # Accessing the Api

	tab_reference = preload("res://src/Extensions/Ceramic/CeramicEditor/Ceramic.tscn").instantiate()
	tab_reference.name = "Ceramic"
	extension_api.panel.add_node_as_tab(tab_reference)


func _exit_tree() -> void:  # Extension is being uninstalled or disabled
	# remember to remove things that you added using this extension
	extension_api.panel.remove_node_from_tab(tab_reference)
