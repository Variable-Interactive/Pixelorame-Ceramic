class_name API
extends RefCounted

const API_APPENDAGE := """
var ExtensionsApi: ExtensionsApiClass = ExtensionsApiClass.new()

{misc_classes}
{project}


class ExtensionsApiClass:
	extends Node

	## The Official ExtensionsAPI for pixelorama.
	##
	## This Api gives you the essentials to develop a working extension for Pixelorama.[br]
	## The Api consists of many smaller Apis, each giving access to different areas of the Software.
	## [br][br]
	## Keep in mind that this API is targeted towards users who are not fully familiar with Pixelorama's
	## source code. If you need to do something more complicated and more low-level, you would need to
	## interact directly with the source code.
	## [br][br]
	## To access this anywhere in the extension use [code]get_node_or_null("/root/ExtensionsApi")[/code]
	##
	## @tutorial(Add Tutorial here):            https://the/tutorial1/url.com

	## Gives access to the general, app related functions of pixelorama
	## such as Autoloads, Software Version, Config file etc...
	var general := GeneralAPI.new()
	var menu := MenuAPI.new()  ## Gives ability to add/remove items from menus in the top bar.
	var dialog := DialogAPI.new()  ## Gives access to Dialog related functions.
	var panel := PanelAPI.new()  ## Gives access to Tabs and Dockable Container related functions.
	var theme := ThemeAPI.new()  ## Gives access to theme related functions.
	var tools := ToolAPI.new()  ## Gives ability to add/remove tools.
	var selection := SelectionAPI.new()  ## Gives access to pixelorama's selection system.
	var project := ProjectAPI.new()  ## Gives access to project manipulation.
	var export := ExportAPI.new()  ## Gives access to adding custom exporters.
	var import := ImportAPI.new()  ## Gives access to adding custom import options.
	var palette := PaletteAPI.new()  ## Gives access to palettes.
	var signals := SignalsAPI.new()  ## Gives access to the basic commonly used signals.

	## Returns the version of the ExtensionsApi.
	func get_api_version() -> int:
		return ProjectSettings.get_setting("application/config/ExtensionsAPI_Version")


	## Returns the initial nodes of an extension named [param extension_name].
	## initial nodes are the nodes whose paths are in the [code]nodes[/code] key of an
	## extension.json file.
	func get_main_nodes(extension_name: StringName) -> Array[Node]:
		return []


	## Gives Access to the general stuff.
	##
	## This part of Api provides stuff like commonly used Autoloads, App's version info etc
	## the most basic (but important) stuff.
	class GeneralAPI:
		## Returns the current version of pixelorama.
		func get_pixelorama_version() -> String:
			return ""

		## Returns the [ConfigFile] contains all the settings (Brushes, sizes, preferences, etc...).
		func get_config_file() -> ConfigFile:
			return

		## Returns the Global autoload used by Pixelorama.[br]
		## Contains references to almost all UI Elements, Variables that indicate different
		## settings etc..., In short it is the most important autoload of Pixelorama.
		func get_global() -> Global:
			return

		## Returns the DrawingAlgos autoload, contains different drawing algorithms used by Pixelorama.
		func get_drawing_algos() -> DrawingAlgos:
			return

		## Gives you a new ShaderImageEffect class. this class can apply shader to an image.[br]
		## It contains method:
		## [code]generate_image(img: Image, shader: Shader, params: Dictionary, size: Vector2)[/code]
		## [br]Whose parameters are identified as:
		## [br][param img] --> image that the shader will be pasted to (Empty Image of size same as
		## project).
		## [br][param shader] --> preload of the shader.
		## [br][param params] --> a dictionary of params used by the shader.
		## [br][param size] --> It is the project's size.
		func get_new_shader_image_effect() -> ShaderImageEffect:
			return

		## Returns parent of the nodes listed in extension.json -> "nodes".
		func get_extensions_node() -> Node:
			return

		## Returns the main [code]Canvas[/code] node,
		## normally used to add a custom preview to the canvas.
		func get_canvas() -> Canvas:
			return

		## Returns a new ValueSlider. Useful for editing floating values
		func create_value_slider() -> ValueSlider:
			return

		## Returns a new ValueSliderV2. Useful for editing 2D vectors.
		func create_value_slider_v2() -> ValueSliderV2:
			return

		## Returns a new ValueSliderV3. Useful for editing 3D vectors.
		func create_value_slider_v3() -> ValueSliderV3:
			return


	## Gives ability to add/remove items from menus in the top bar.
	class MenuAPI:
		enum { FILE, EDIT, SELECT, PROJECT, EFFECTS, VIEW, WINDOW, HELP }

		## Adds a menu item of title [param item_name] to the [param menu_type] defined by
		## [enum @unnamed_enums].
		## [br][param item_metadata] is usually a window node you want to appear when you click the
		## [param item_name]. That window node should also have a [param menu_item_clicked]
		## function inside its script.[br]
		## Index of the added item is returned (which can be used to remove menu item later on).
		func add_menu_item(menu_type: int, item_name: String, item_metadata, item_id := -1) -> int:
			return -1

		## Removes a menu item at index [param item_idx] from the [param menu_type] defined by
		## [enum @unnamed_enums].
		func remove_menu_item(menu_type: int, item_id: int) -> void:
			return


	## Gives access to common dialog related functions.
	class DialogAPI:
		## Shows an alert dialog with the given [param text].
		## Useful for displaying messages like "Incompatible API" etc...
		func show_error(text: String) -> void:
			return

		## Returns the node that is the parent of dialogs used in pixelorama.
		func get_dialogs_parent_node() -> Node:
			return

		## Informs Pixelorama that some dialog is about to open or close.
		func dialog_open(open: bool) -> void:
			return


	## Gives access to Tabs and Dockable Container related functions.
	class PanelAPI:
		## Sets the visibility of dockable tabs.
		var tabs_visible: bool

		## Adds the [param node] as a tab. Initially it's placed on the same panel as the tools tab,
		## but it's position can be changed through editing a layout.
		func add_node_as_tab(node: Node) -> void:
			return

		## Removes the [param node] from the DockableContainer.
		func remove_node_from_tab(node: Node) -> void:
			return


	## Gives access to theme related functions.
	class ThemeAPI:
		## Returns the Themes autoload. Allows interacting with themes on a more deeper level.
		func autoload() -> Themes:
			return

		## Returns the colors used by the given [param theme] as a [Dictionary]. This includes
		## [StyleBox] colors. For use in script use it with JSON.stringify() for more friendly format.
		## [br]To set colors, see [method set_theme_colors].
		func get_theme_colors(theme: Theme) -> Dictionary[String, String]:
			return {}

		## Changes the colors of the given [param theme] according to the given [param data]. Only the
		## colors specified by [param data] are changed and the rest remain the same as original.
		## Make sure you don't set call this method using currently active (otherwise it will be slow).
		## The parameter [param debug_mode] is for debug purpose to let the developer know about the
		## changes that are to be done in order for colors to be properly visible.
		func set_theme_colors(theme: Theme, data: Dictionary[String, String], debug_mode := false):
			return

		## Adds the [param theme] to [code]Edit -> Preferences -> Interface -> Themes[/code].
		func add_theme(theme: Theme) -> void:
			return

		## Returns index of the [param theme] in preferences.
		func find_theme_index(theme: Theme) -> int:
			return -1

		## Returns the current theme resource.
		func get_theme() -> Theme:
			return

		## Sets a theme located at a given [param idx] in preferences. If theme set successfully then
		## return [code]true[/code], else [code]false[/code].
		func set_theme(idx: int) -> bool:
			return false

		## Removes the [param theme] from preferences.
		func remove_theme(theme: Theme) -> void:
			return

		## Adds a new font.
		func add_font(font: Font) -> void:
			return

		## Removes a loaded font.
		## If that font is the current one of the interface, set it back to Roboto.
		func remove_font(font: Font) -> void:
			return

		## Sets a font as the current one for the interface. The font must have been
		## added beforehand by [method add_font].
		func set_font(font: Font) -> void:
			return


	## Gives ability to add/remove tools.
	class ToolAPI:
		const LayerTypes := Global.LayerTypes

		## Returns the Tools autoload. Allows interacting with tools on a more deeper level.
		func autoload() -> Tools:
			return

		## Adds a tool to pixelorama with name [param tool_name] (without spaces),
		## display name [param display_name], tool scene [param scene], layers that the tool works
		## on [param layer_types] defined by [constant LayerTypes],
		## [param extra_hint] (text that appears when mouse havers tool icon), primary shortcut
		## name [param shortcut] and any extra shortcuts [param extra_shortcuts].
		## [br][br]At the moment extensions can't make their own shortcuts so you can leave
		## [param shortcut] and [param extra_shortcuts] as [code][][/code].
		## [br] To determine the position of tool in tool list, use [param insert_point]
		## (if you leave it empty then the added tool will be placed at bottom)
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

		## Removes a tool with name [param tool_name]
		## and assign Pencil as left tool, Eraser as right tool.
		func remove_tool(tool_name: String) -> void:
			return


	## Gives access to pixelorama's selection system.
	class SelectionAPI:
		## Clears the selection.
		func clear_selection() -> void:
			return

		## Select the entire region of current cel.
		func select_all() -> void:
			return

		## Selects a portion defined by [param rect] of the current cel.
		## [param operation] influences it's behaviour with previous selection rects
		## (0 for adding, 1 for subtracting, 2 for intersection).
		func select_rect(rect: Rect2i, operation := 0) -> void:
			return

		## Moves a selection to [param destination],
		## with content if [param with_content] is [code]true[/code].
		## If [param transform_standby] is [code]true[/code] then the transformation will not be
		## applied immediately unless [kbd]Enter[/kbd] is pressed.
		func move_selection(
			destination: Vector2i, with_content := true, transform_standby := false
		) -> void:
			return

		## Resizes the selection to [param new_size],
		## with content if [param with_content] is [code]true[/code].
		## If [param transform_standby] is [code]true[/code] then the transformation will not be
		## applied immediately unless [kbd]Enter[/kbd] is pressed.
		func resize_selection(
			new_size: Vector2i, with_content := true, transform_standby := false
		) -> void:
			return

		## Inverts the selection.
		func invert() -> void:
			return

		## Makes a project brush out of the current selection's content.
		func make_brush() -> void:
			return

		## Returns the portion of current cel's image enclosed by the selection.
		## It's similar to [method make_brush] but it returns the image instead.
		func get_enclosed_image() -> Image:
			return

		## Copies the selection content (works in or between pixelorama instances only).
		func copy() -> void:
			return

		## Pastes the selection content.
		func paste(in_place := false) -> void:
			return

		## Erases the drawing on current cel enclosed within the selection's area.
		func delete_content(selected_cels := true) -> void:
			return


	## Gives access to basic project manipulation functions.
	class ProjectAPI:
		## The project currently in focus.
		var current_project: Project

		## Creates a new project in a new tab with one starting layer and frame,
		## name [param name], size [param size], fill color [param fill_color] and
		## frames [param frames]. The created project also gets returned.[br][br]
		## [param frames] is an [Array] of type [Frame]. Usually it can be left as [code][][/code].
		## If [param is_resource] is [code]true[/code] then a [ResourceProject] is created.
		func new_project(
			frames: Array[Frame] = [],
			name := tr("untitled"),
			size := Vector2(64, 64),
			fill_color := Color.TRANSPARENT,
			is_resource := false
		) -> Project:
			return

		func new_image_extended(
			width: int,
			height: int,
			mipmaps: bool,
			format: Image.Format,
			is_indexed := false,
			from_data := PackedByteArray()
		) -> ImageExtended:
			return

		## Creates and returns a new [Project] in a new tab, with an optional [param name].
		## Unlike [method new_project], no starting frame/layer gets created.
		## Useful if you want to deserialize project data.
		## If [param is_resource] is [code]true[/code] then a [ResourceProject] is created.
		func new_empty_project(name := tr("untitled"), is_resource := false) -> Project:
			return

		## Returns a dictionary containing all the project information.
		func get_project_info(project: Project) -> Dictionary:
			return {}

		## Selects the cels and makes the last entry of [param selected_array] as the current cel.
		## [param selected_array] is an [Array] of [Arrays] of 2 integers (frame & layer respectively).
		## [br]Frames are counted from left to right, layers are counted from bottom to top.
		## Frames/layers start at "0" and end at [param project.frames.size() - 1] and
		## [param project.layers.size() - 1] respectively.
		func select_cels(selected_array := [[0, 0]]) -> void:
			return

		## Returns the current cel.
		## Cel type can be checked using function [method get_class_name] inside the cel
		## type can be GroupCel, PixelCel, Cel3D, CelTileMap, AudioCel or BaseCel.
		func get_current_cel() -> BaseCel:
			return

		## Frames are counted from left to right, layers are counted from bottom to top.
		## Frames/layers start at "0" and end at [param project.frames.size() - 1] and
		## [param project.layers.size() - 1] respectively.
		func get_cel_at(project: Project, frame: int, layer: int) -> BaseCel:
			return

		## Sets an [param image] at [param frame] and [param layer] on the current project.
		## Frames are counted from left to right, layers are counted from bottom to top.
		func set_pixelcel_image(image: Image, frame: int, layer: int) -> void:
			return

		## Adds a new frame in the current project after frame [param after_frame].
		func add_new_frame(after_frame: int) -> void:
			return

		## Adds a new Layer of name [param name] in the current project above layer [param above_layer]
		## ([param above_layer] = 0 is the bottom-most layer and so on).
		## [br][param type] = 0 --> PixelLayer,
		## [br][param type] = 1 --> GroupLayer,
		## [br][param type] = 2 --> 3DLayer
		func add_new_layer(above_layer: int, name := "", type := 0) -> void:
			return


	## Gives access to adding custom exporters.
	class ExportAPI:
		const ExportTab = Export.ExportTab

		## Returns the Export autoload.
		## Allows interacting with the export workflow on a more deeper level.
		func autoload() -> Export:
			return

		## [param format_info] has keys: [code]extension[/code] and [code]description[/code]
		## whose values are of type [String] e.g:[codeblock]
		## format_info = {"extension": ".gif", "description": "GIF Image"}
		## [/codeblock]
		## [param exporter_generator] is a node with a script containing the method
		## [method override_export] which takes 1 argument of type Dictionary which is automatically
		## passed to [method override_export] at time of export and contains
		## keys: [code]processed_images[/code], [code]export_dialog[/code],
		## [code]export_paths[/code], [code]project[/code][br]
		## (Note: [code]processed_images[/code] is an array of ProcessedImage resource which further
		## has parameters [param image] and [param duration])[br]
		## If the value of [param tab] is not in [constant ExportTab] then the format will be added to
		## both tabs.
		## [br]Returns the index of exporter, which can be used to remove exporter later.
		func add_export_option(
			format_info: Dictionary,
			exporter_generator: Object,
			tab := ExportTab.IMAGE,
			is_animated := true
		) -> int:
			return -1

		## Removes the exporter with [param id] from Pixelorama.
		func remove_export_option(id: int) -> void:
			return


	## Gives access to adding custom import options.
	class ImportAPI:
		## Returns the OpenSave autoload. Contains code to handle file loading.
		## It also contains code to handle project saving (.pxo)
		func open_save_autoload() -> OpenSave:
			return

		## Returns the Import autoload. Manages import of brushes and patterns.
		func import_autoload() -> Import:
			return

		## [param import_scene] is a scene preload that will be instanced and added to "import options"
		## section of pixelorama's import dialogs and will appear whenever [param import_name] is
		## chosen from import menu.
		## [br]
		## [param import_scene] must have a script containing:[br]
		## 1. An optional variable named [code]import_preview_dialog[/code] of type [ConfirmationDialog],
		## If present, it will automatically be assigned a reference to the relevant import dialog's
		## [code]ImportPreviewDialog[/code] class so that you can easily access variables and
		## methods of that class. (This variable is meant to be read-only)[br]
		## 2. The method [method initiate_import], which takes 2 arguments: [code]path[/code],
		## [code]image[/code]. Values will automatically be passed to these arguments at the
		## time of import.[br]Returns the id of the importer.
		func add_import_option(import_name: StringName, import_scene_preload: PackedScene) -> int:
			return -1

		## Removes the import option with [param id] from Pixelorama.
		func remove_import_option(id: int) -> void:
			return


	## Gives access to palette related stuff.
	class PaletteAPI:
		## Returns the Palettes autoload. Allows interacting with palettes on a more deeper level.
		func autoload() -> Palettes:
			return

		## Creates and adds a new [Palette] with name [param palette_name] containing [param data].
		## [param data] is a [Dictionary] containing the palette information.
		## An example of [code]data[/code] will be:[codeblock]
		## {
		## "colors": [
		##  {
		##   "color": "(0, 0, 0, 1)",
		##   "index": 0
		##  },
		##  {
		##   "color": "(0.1294, 0.1216, 0.2039, 1)",
		##   "index": 1
		##  },
		##  {
		##   "color": "(0.2667, 0.1569, 0.2314, 1)",
		##   "index": 2
		##  }
		## ],
		## "comment": "Place comment here",
		## "height": 4,
		## "width": 8
		## }
		## [/codeblock]
		func create_palette_from_data(
			palette_name: String, data: Dictionary, is_global := true
		) -> void:
			return


	## Gives access to the basic commonly used signals.
	##
	## Gives access to the basic commonly used signals.
	## Some less common signals are not mentioned in Api but could be accessed through source directly.
	class SignalsAPI:
		# APP RELATED SIGNALS
		## Connects/disconnects a signal to [param callable], that emits
		## when pixelorama is just opened.
		func signal_pixelorama_opened(callable: Callable, is_disconnecting := false) -> void:
			return

		## Connects/disconnects a signal to [param callable], that emits
		## when pixelorama is about to close.
		func signal_pixelorama_about_to_close(callable: Callable, is_disconnecting := false) -> void:
			return

		# PROJECT RELATED SIGNALS
		## Connects/disconnects a signal to [param callable], that emits
		## whenever a new project is created.[br]
		## [b]Binds: [/b]It has one bind of type [code]Project[/code] which is the newly
		## created project.
		func signal_project_created(callable: Callable, is_disconnecting := false) -> void:
			return

		## Connects/disconnects a signal to [param callable], that emits
		## after a project is saved.
		func signal_project_saved(callable: Callable, is_disconnecting := false) -> void:
			return

		## Connects/disconnects a signal to [param callable], that emits
		## whenever you switch to some other project.
		func signal_project_switched(callable: Callable, is_disconnecting := false) -> void:
			return

		## Connects/disconnects a signal to [param callable], that emits
		## whenever you select a different cel.
		func signal_cel_switched(callable: Callable, is_disconnecting := false) -> void:
			return

		## Connects/disconnects a signal to [param callable], that emits
		## whenever the project data are being modified.
		func signal_project_data_changed(callable: Callable, is_disconnecting := false) -> void:
			return

		# TOOL RELATED SIGNALS
		## Connects/disconnects a signal to [param callable], that emits
		## whenever a tool changes color.[br]
		## [b]Binds: [/b] It has two bind of type [Color] (a dictionary with keys "color" and "index")
		## and [int] (Indicating button that tool is assigned to, see [enum @GlobalScope.MouseButton])
		func signal_tool_color_changed(callable: Callable, is_disconnecting := false) -> void:
			return

		# TIMELINE RELATED SIGNALS
		## Connects/disconnects a signal to [param callable], that emits
		## whenever timeline animation starts.[br]
		## [b]Binds: [/b] It has one bind of type [bool] which indicated if animation is in
		## forward direction ([code]true[/code]) or backward direction ([code]false[/code])
		func signal_timeline_animation_started(callable: Callable, is_disconnecting := false) -> void:
			return

		## Connects/disconnects a signal to [param callable], that emits
		## whenever timeline animation stops.
		func signal_timeline_animation_finished(callable: Callable, is_disconnecting := false) -> void:
			return

		# UPDATER SIGNALS
		## Connects/disconnects a signal to [param callable], that emits
		## whenever texture of the currently focused cel changes.
		func signal_current_cel_texture_changed(callable: Callable, is_disconnecting := false) -> void:
			return

		## Connects/disconnects a signal to [param callable], that emits
		## whenever preview is about to be drawn.[br]
		## [b]Binds: [/b]It has one bind of type [Dictionary] with keys: [code]exporter_id[/code],
		## [code]export_tab[/code], [code]preview_images[/code], [code]durations[/code].[br]
		## Use this if you plan on changing preview of export.
		func signal_export_about_to_preview(callable: Callable, is_disconnecting := false) -> void:
			return
"""


const paired_actions := {
	"add_menu_item": "remove_menu_item",
	"add_node_as_tab": "remove_node_from_tab",
	"add_theme": "remove_theme",
	"add_tool": "remove_tool",
	"add_export_option": "remove_export_option",
	"add_import_option": "remove_import_option"
}

static func compile_api() -> String:
	return API_APPENDAGE.format(
		{
			"misc_classes": MiscClass.SOURCE,
			"project": ProjectClass.SOURCE
		}
	)


static func validate_api_usage(script: String) -> PackedStringArray:
	var errors := PackedStringArray()
	for key in paired_actions.keys():
		var initialize_count := script.count(key)
		var deinitialize_count := script.count(paired_actions[key])
		if deinitialize_count < initialize_count:
			errors.append(
				(
					"{initializer} was called {icount} times, but {deinitializer} was called {dcount} times. There is risk of leaving unmanaged nodes when script ends!"
				).format(
					{
						"initializer": key,
						"icount": str(initialize_count),
						"deinitializer": paired_actions[key],
						"dcount": deinitialize_count
					}
				)
			)
	return errors
