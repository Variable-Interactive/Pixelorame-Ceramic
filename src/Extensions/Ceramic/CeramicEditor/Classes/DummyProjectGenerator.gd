class_name DummyProject
extends RefCounted

const PROJECT_FILE := """; Engine configuration file.
; It's best edited using the editor UI and not directly,
; since the parameters that go here are not all obvious.
;
; Format:
;   [section] ; section goes between []
;   param=value ; assign values to parameters

config_version=5

[application]

config/name="CeramicTempProject"
config/features=PackedStringArray("4.6", "GL Compatibility")
config/icon=""

[rendering]

rendering_device/driver.windows="d3d12"
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
"""


static func create_project(directory_path: String) -> String:
	DirAccess.make_dir_recursive_absolute(directory_path)
	var project_file := FileAccess.open(directory_path.path_join("project.godot"), FileAccess.WRITE)
	project_file.store_string(PROJECT_FILE)
	project_file.close()
	return directory_path.path_join("project.godot")
