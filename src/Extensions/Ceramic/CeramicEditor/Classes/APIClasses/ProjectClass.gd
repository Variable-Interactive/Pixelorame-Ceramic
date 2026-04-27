class_name ProjectClass
extends RefCounted

const SOURCE := """
class Project:
	## A class for project properties.
	signal removed
	signal serialized(dict: Dictionary)
	signal about_to_deserialize(dict: Dictionary)
	signal resized
	signal fps_changed
	signal layers_updated
	signal frames_updated
	signal tags_changed

	const INDEXED_MODE := -1

	var name := ""
	var size: Vector2i
	var undo_redo := UndoRedo.new()
	var tiles: Tiles
	var can_undo := true
	var color_mode: int = Image.FORMAT_RGBA8
	var fill_color := Color(0)
	var has_changed := false
	# frames and layers Arrays should generally only be modified directly when
	# opening/creating a project. When modifying the current project, use
	# the add/remove/move/swap_frames/layers methods
	var frames: Array[Frame] = []
	var layers: Array[BaseLayer] = []
	var current_frame := 0
	var current_layer := 0
	var selected_cels := [[0, 0]]  ## Array of Arrays of 2 integers (frame & layer)
	## Array that contains the order of the [BaseLayer] indices that are being drawn.
	## Takes into account each [BaseCel]'s invidiual z-index. If all z-indexes are 0, then the
	## array just contains the indices of the layers in increasing order.
	## See [method order_layers].
	var ordered_layers: Array[int] = [0]
	var animation_tags: Array[AnimationTag] = []
	var guides: Array[Guide] = []
	var brushes: Array[Image] = []
	var palettes: Dictionary[String, Palette] = {}
	## Name of selected palette (for "project" palettes only)
	var project_current_palette_name: String = ""
	var reference_images: Array[ReferenceImage] = []
	var reference_index: int = -1  ## The currently selected index ReferenceImage
	var vanishing_points := []  ## Array of Vanishing Points
	var fps := 6.0
	var license := ""  ## The license of the project, set in the project properties.
	var user_data := ""  ## User defined data, set in the project properties.
	var author_display_name := ""  ## The displayed name of the project author.
	var author_real_name := ""  ## The real name of the project author.
	var author_contact := ""  ## The contact info of the project author.
	var author_company := ""  ## The company name of the project author.

	var x_symmetry_point: float
	var y_symmetry_point: float
	var xy_symmetry_point: Vector2
	var x_minus_y_symmetry_point: Vector2
	var x_symmetry_axis: SymmetryGuide
	var y_symmetry_axis: SymmetryGuide
	var diagonal_xy_symmetry_axis: SymmetryGuide
	var diagonal_x_minus_y_symmetry_axis: SymmetryGuide

	var selection_map: SelectionMap
	## This is useful for when the selection is outside of the canvas boundaries,
	## on the left and/or above (negative coords)
	var selection_offset := Vector2i.ZERO
	var has_selection := false
	var tilesets: Array[TileSetCustom]

	## For every camera (currently there are 3)
	var cameras_rotation: PackedFloat32Array = [0.0, 0.0, 0.0]
	var cameras_zoom: PackedVector2Array = [
		Vector2(0.15, 0.15), Vector2(0.15, 0.15), Vector2(0.15, 0.15)
	]
	var cameras_offset: PackedVector2Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]

	# Export directory path and export file name
	var save_path := ""
	var export_directory_path := ""
	var file_name := "untitled"
	var file_format := Export.FileFormat.PNG
	var was_exported := false
	var export_overwrite := false
	var backup_path := ""

	func _init(_frames: Array[Frame] = [], _name := tr("untitled"), _size := Vector2i(64, 64)) -> void:
		return

	func remove() -> void:
		return

	func commit_undo() -> void:
		return

	func commit_redo() -> void:
		return

	func new_empty_frame() -> Frame:
		return

	## Returns a new [Image] of size [member size] and format [method get_image_format].
	func new_empty_image() -> Image:
		return

	## Returns the currently selected [BaseCel].
	func get_current_cel() -> BaseCel:
		return

	func get_image_format() -> Image.Format:
		return (0 as Image.Format)

	func is_indexed() -> bool:
		return false

	func selection_map_changed() -> void:
		return

	func change_project() -> void:
		return

	func serialize() -> Dictionary:
		return {}

	func deserialize(dict: Dictionary, zip_reader: ZIPReader = null, file: FileAccess = null) -> void:
		return

	func change_cel(new_frame: int, new_layer := -1) -> void:
		return

	func is_empty() -> bool:
		return false

	func can_pixel_get_drawn(pixel: Vector2i, image := selection_map) -> bool:
		return false

	## Loops through all of the cels until it finds a drawable (non-[GroupCel]) [BaseCel]
	## in the specified [param frame] and returns it. If no drawable cel is found,
	## meaning that all of the cels are [GroupCel]s, the method returns null.
	## If no [param frame] is specified, the method will use the current frame.
	func find_first_drawable_cel(frame := frames[current_frame]) -> BaseCel:
		return

	## Returns an [Array] of type [PixelCel] containing all of the pixel cels of the project.
	func get_all_pixel_cels() -> Array[PixelCel]:
		return []

	func get_all_audio_layers(only_valid_streams := true) -> Array[AudioLayer]:
		return []

	## Returns all [BaseCel]s in [param cels], and for every [CelTileMap],
	## this methods finds all other [CelTileMap]s that share the same [TileSetCustom],
	## and appends them in the array that is being returned by this method.
	func find_same_tileset_tilemap_cels(cels: Array[BaseCel]) -> Array[BaseCel]:
		return []

	## Re-order layers to take each cel's z-index into account. If all z-indexes are 0,
	## then the order of drawing is the same as the order of the layers itself.
	func order_layers(frame_index := current_frame) -> void:
		return

	## indices should be in ascending order
	func add_frames(new_frames: Array, indices: PackedInt32Array) -> void:
		return

	## indices should be in ascending order
	func remove_frames(indices: PackedInt32Array) -> void:
		return

	## from_indices and to_indicies should be in ascending order
	func move_frames(from_indices: PackedInt32Array, to_indices: PackedInt32Array) -> void:
		return

	func swap_frame(a_index: int, b_index: int) -> void:
		return

	func reverse_frames(frame_indices: PackedInt32Array) -> void:
		return

	## [param cels] is 2d Array of [BaseCel]s
	func add_layers(new_layers: Array, indices: PackedInt32Array, cels: Array) -> void:
		return

	func remove_layers(indices: PackedInt32Array) -> void:
		return

	## from_indices and to_indicies should be in ascending order
	func move_layers(
		from_indices: PackedInt32Array, to_indices: PackedInt32Array, to_parents: Array
	) -> void:
		return

	## "a" and "b" should both contain "from", "to", and "to_parents" arrays.
	## (Using dictionaries because there seems to be a limit of 5 arguments for do/undo method calls)
	func swap_layers(a: Dictionary, b: Dictionary) -> void:
		return

	## Moves multiple cels between different frames, but on the same layer.
	## TODO: Perhaps figure out a way to optimize this. Right now it copies all of the cels of
	## a layer into a temporary array, sorts it and then copies it into each frame's `cels` array
	## on that layer. This was done in order to replicate the code from [method move_frames].
	## TODO: Make a method like this, but for moving cels between different layers, on the same frame.
	func move_cels_same_layer(
		from_indices: PackedInt32Array, to_indices: PackedInt32Array, layer: int
	) -> void:
		return

	func swap_cel(a_frame: int, a_layer: int, b_frame: int, b_layer: int) -> void:
		return

	## Change the current reference image
	func set_reference_image_index(new_index: int) -> void:
		return

	## Returns the reference image based on reference_index
	func get_current_reference_image() -> ReferenceImage:
		return
	## Returns the reference image based on the index or null if index < 0
	func get_reference_image(index: int) -> ReferenceImage:
		return
	## Reorders the position of the reference image in the tree / reference_images array
	func reorder_reference_image(from: int, to: int) -> void:
		return

	## Adds a new [param tileset] to [member tilesets].
	func add_tileset(tileset: TileSetCustom) -> void:
		return

	## Loops through all cels in [param cel_dictionary], and for [CelTileMap]s,
	## it calls [method CelTileMap.update_tilemap]. Returns an array of used tilesets that can be used
	## as reference to update layers during undo/redo.
	func update_tilemaps(
		cel_dictionary: Dictionary, tile_editing_mode := TileSetPanel.tile_editing_mode
	) -> Array[TileSetCustom]:
		return []
	func initialize_author_data() -> void:
		return

	func clear_author_data() -> void:
		return
"""
