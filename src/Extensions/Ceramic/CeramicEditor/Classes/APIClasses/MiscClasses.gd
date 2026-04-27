class_name MiscClass
extends RefCounted

## These are classes which aren't properly organized yet

const SOURCE := """
class Global:
	extends Node
	enum LayerTypes { PIXEL, GROUP, THREE_D, TILEMAP, AUDIO }
class DrawingAlgos:
	extends Node
class Themes:
	extends Node
class Tools:
	extends Node
class Export:
	extends Node
	enum ExportTab { IMAGE, SPRITESHEET }
class OpenSave:
	extends Node
class Import:
	extends Node
class Palettes:
	extends Node
class ShaderImageEffect:
	extends RefCounted
class Canvas:
	extends Node2D
class ValueSlider:
	extends TextureProgressBar
class ValueSliderV2:
	extends HBoxContainer
class ValueSliderV3:
	extends HBoxContainer
class DockableContainer:
	extends Container
class Frame:
	extends RefCounted
class AnimationTag:
	extends RefCounted
class Tiles:
	extends RefCounted
class TileSetPanel:
	extends PanelContainer
	enum TileEditingMode { MANUAL, AUTO, STACK }
	static var tile_editing_mode := TileEditingMode.AUTO
class BaseLayer:
	extends RefCounted
class AudioLayer:
	extends RefCounted
class BaseCel:
	extends RefCounted
class PixelCel:
	extends RefCounted
class Guide:
	extends Line2D
class SymmetryGuide:
	extends Guide
class Palette:
	extends RefCounted
class ReferenceImage:
	extends Sprite2D
class SelectionMap:
	extends Image
class TileSetCustom:
	extends RefCounted
class ImageExtended:
	extends Image
"""
