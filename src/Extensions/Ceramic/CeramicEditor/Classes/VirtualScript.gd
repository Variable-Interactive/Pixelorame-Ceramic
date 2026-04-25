class_name VirtualScript
extends RefCounted

var name: String = "New Script"
var was_running: bool = false
var source_code: String = """extends Node

# NOTE: This script is meant to be run through this code editor.
# INFO: You don't have to save the scripts, they are saved in Pixelorama's
# configuration file.


func _enter_tree() -> void:
	# INFO: To access api, simply type ExtensionsApi (autocomplete is supported through LSP)
	# See https://pixelorama.org/extension_system/extension_api for the API docs.
	# or https://pixelorama.org/extension_system/extension_examples for Examples.
	ExtensionsApi.general.get_pixelorama_version(sdad)
	print(ExtensionsApi.get_api_version())


func _exit_tree() -> void:  # Extension is being uninstalled or disabled
	# remember to remove things that you added using this extension
	pass
"""

const API_APPENDAGE := """
var ExtensionsApi: ExtensionsApiClass = ExtensionsApiClass.new()

class ExtensionsApiClass:
	var general: GeneralAPI
	var menu: MenuAPI  ## Gives ability to add/remove items from menus in the top bar.
	var dialog: DialogAPI  ## Gives access to Dialog related functions.
	var panel: PanelAPI  ## Gives access to Tabs and Dockable Container related functions.
	var theme: ThemeAPI  ## Gives access to theme related functions.
	var tools: ToolAPI  ## Gives ability to add/remove tools.
	var selection: SelectionAPI  ## Gives access to pixelorama's selection system.
	var project: ProjectAPI  ## Gives access to project manipulation.
	var export: ExportAPI  ## Gives access to adding custom exporters.
	var import: ImportAPI  ## Gives access to adding custom import options.
	var palette: PaletteAPI  ## Gives access to palettes.
	var signals: SignalsAPI  ## Gives access to the basic commonly used signals.

	func get_api_version() -> int:
		return ProjectSettings.get_setting("application/config/ExtensionsAPI_Version")

	func get_main_nodes(extension_name: StringName) -> Array[Node]:
		return []

	class GeneralAPI:
		func get_pixelorama_version() -> String:
			return ""

		func get_config_file() -> ConfigFile:
			return null

		func get_global() -> Node:
			return null

		func get_drawing_algos() -> Node:
			return null

		func get_new_shader_image_effect() -> RefCounted:
			return RefCounted

		func get_extensions_node() -> Node:
			return null

		func get_canvas() -> Node:
			return null

		func create_value_slider() -> Node:
			return null

		func create_value_slider_v2() -> Node:
			return null

		func create_value_slider_v3() -> Node:
			return null

	class MenuAPI:
		enum { FILE, EDIT, SELECT, PROJECT, EFFECTS, VIEW, WINDOW, HELP }

		func add_menu_item(menu_type: int, item_name: String, item_metadata, item_id := -1) -> int:
			return -1

		func remove_menu_item(menu_type: int, item_id: int) -> void:
			return

	class DialogAPI:
		func show_error(text: String) -> void:
			return

		func get_dialogs_parent_node() -> Node:
			return null

		func dialog_open(open: bool) -> void:
			return

	class PanelAPI:
		var tabs_visible: bool

		func add_node_as_tab(node: Node) -> void:
			return

		func remove_node_from_tab(node: Node) -> void:
			return

	class ThemeAPI:
		func autoload() -> Node:
			return null

		func get_theme_colors(theme: Theme) -> Dictionary[String, String]:
			return {}

		func set_theme_colors(theme: Theme, data: Dictionary[String, String], debug_mode := false):
			return

		func add_theme(theme: Theme) -> void:
			return

		func find_theme_index(theme: Theme) -> int:
			return -1

		func get_theme() -> Theme:
			return null

		func set_theme(idx: int) -> bool:
			return false

		func remove_theme(theme: Theme) -> void:
			return

		func add_font(font: Font) -> void:
			return

		func remove_font(font: Font) -> void:
			return

		func set_font(font: Font) -> void:
			return

	class ToolAPI:
		enum LayerTypes { PIXEL, GROUP, THREE_D, TILEMAP, AUDIO }

		func autoload() -> Node:
			return null

		func add_tool(
			tool_name: String,
			display_name: String,
			scene: String,
			layer_types: PackedInt32Array = [],
			extra_hint := "",
			shortcut: String = "",
			extra_shortcuts: PackedStringArray = [],
			insert_point := -1
		) -> void:
			return

		func remove_tool(tool_name: String) -> void:
			# Re-assigning the tools in case the tool to be removed is also active
			return

	class SelectionAPI:
		func clear_selection() -> void:
			return

		func select_all() -> void:
			return

		func select_rect(rect: Rect2i, operation := 0) -> void:
			return

		func move_selection(
			destination: Vector2i, with_content := true, transform_standby := false
		) -> void:
			return

		func resize_selection(
			new_size: Vector2i, with_content := true, transform_standby := false
		) -> void:
			return

		func invert() -> void:
			return

		func make_brush() -> void:
			return

		func get_enclosed_image() -> Image:
			return

		func copy() -> void:
			return

		func paste(in_place := false) -> void:
			return

		func delete_content(selected_cels := true) -> void:
			return

	class ProjectAPI:
		var current_project: RefCounted

		func new_project(
			frames: Array[RefCounted] = [],
			name := "untitled",
			size := Vector2(64, 64),
			fill_color := Color.TRANSPARENT,
			is_resource := false
		) -> RefCounted:
			return null

		func new_image_extended(
			width: int,
			height: int,
			mipmaps: bool,
			format: Image.Format,
			is_indexed := false,
			from_data := PackedByteArray()
		) -> RefCounted:
			return null

		func new_empty_project(name := "untitled", is_resource := false) -> RefCounted:
			return null

		func get_project_info(project: RefCounted) -> Dictionary:
			return {}

		func select_cels(selected_array := [[0, 0]]) -> void:
			return

		func get_current_cel() -> RefCounted:
			return null

		func get_cel_at(project: RefCounted, frame: int, layer: int) -> RefCounted:
			return null

		func set_pixelcel_image(image: Image, frame: int, layer: int) -> void:
			return

		func add_new_frame(after_frame: int) -> void:
			return

		func add_new_layer(above_layer: int, name := "", type := 0) -> void:
			return

	class ExportAPI:
		# gdlint: ignore=constant-name
		enum ExportTab { IMAGE, SPRITESHEET }

		func autoload() -> Node:
			return null

		func add_export_option(
			format_info: Dictionary,
			exporter_generator: Object,
			tab := ExportTab.IMAGE,
			is_animated := true
		) -> int:
			return -1

		func remove_export_option(id: int) -> void:
			return

	class ImportAPI:
		func open_save_autoload() -> Node:
			return null

		func import_autoload() -> Node:
			return null

		func add_import_option(import_name: StringName, import_scene_preload: PackedScene) -> int:
			return -1

		func remove_import_option(id: int) -> void:
			return

	class PaletteAPI:
		func autoload() -> Node:
			return null

		func create_palette_from_data(
			palette_name: String, data: Dictionary, is_global := true
		) -> void:
			return

	class SignalsAPI:
		func signal_pixelorama_opened(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_pixelorama_about_to_close(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_project_created(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_project_saved(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_project_switched(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_cel_switched(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_project_data_changed(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_tool_color_changed(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_timeline_animation_started(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_timeline_animation_finished(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_current_cel_texture_changed(callable: Callable, is_disconnecting := false) -> void:
			return
		func signal_export_about_to_preview(callable: Callable, is_disconnecting := false) -> void:
			return
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
	return source_code + "\n" + API_APPENDAGE
