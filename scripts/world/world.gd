class_name CafeWorld
extends Node3D
## Root of the 3D world: the cafe sections, an orthographic isometric camera and the sun.
##
## The cafe is split into one glb per section. Each one is instanced under the `Cafe` node of
## world.tscn and moved there by that instance's transform (floor at y = 0, +Z = south):
##   Hall (center) | Delivery (north) | Kitchen (north-west) | Storage (west)
##   Marketing (south of Storage, no glb yet) | Terrace (east)
## The glb files are never modified. Their own lights (`DirectionalLight*`, `HemisphereLight*`)
## are removed at start, the `Sun` + environment of world.tscn light everything.
##
## Parts inside a section glb are named `<section>_<part>_L<1..5>`; the number is the upgrade
## level of that part. A section at stage N shows the parts with level <= N (see unlock()).

const MAX_STAGE := 5

@export_group("Cafe stages")
## Stage every section starts at: parts with level <= stage are visible, the rest are hidden.
## 0 hides the whole section, 5 shows everything.
@export_range(0, 5) var start_stage := 5

@export_group("Debug")
## Print the frame's draw calls and objects once per second. Turn off for release builds.
@export var log_draw_calls := true

@onready var _cafe: Node3D = $Cafe

var _log_timer := 0.0
## Section name (node name under `Cafe`, e.g. "Kitchen") -> unlocked stage.
var _stages: Dictionary = {}
var _level_regex := RegEx.new()


func _ready() -> void:
	_level_regex.compile("_L([1-5])$")
	for child in _cafe.get_children():
		var section := child as Node3D
		if section == null:
			continue
		if section.get_child_count() == 0:
			push_warning("CafeWorld: section '%s' has no model yet" % section.name)
		_remove_embedded_lights(section)
		_stages[String(section.name)] = start_stage
		_apply_stage(section, start_stage)
	set_process(log_draw_calls)


func _process(delta: float) -> void:
	_log_timer += delta
	if _log_timer < 1.0:
		return
	_log_timer = 0.0
	var cam := get_viewport().get_camera_3d()
	print("CafeWorld: draw calls %d, objects %d, zoom size %.1f" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			cam.size if cam != null else 0.0])


## Unlocks [param stage] (1..5) of a cafe section, e.g. unlock("Kitchen", 2) shows the parts
## of level 1 and 2. Never locks a section again (a lower stage than the current one is ignored).
## Section names: Hall, Kitchen, Storage, Delivery, Marketing, Terrace (case-insensitive).
func unlock(section: String, stage: int) -> void:
	var key := section.capitalize()
	if not _stages.has(key):
		push_warning("CafeWorld: unknown cafe section '%s'" % section)
		return
	var target := clampi(stage, 0, MAX_STAGE)
	if target <= int(_stages[key]):
		return
	_stages[key] = target
	_apply_stage(_cafe.get_node(key) as Node3D, target)


## Returns the unlocked stage (0..5) of a cafe section, or -1 if the section does not exist.
func get_stage(section: String) -> int:
	return int(_stages.get(section.capitalize(), -1))


## Shows the parts of [param section] whose level is <= [param stage]. A part without an
## `_L<n>` suffix is visible as soon as the section is unlocked (stage >= 1).
func _apply_stage(section: Node3D, stage: int) -> void:
	for child in section.get_children():
		var part := child as Node3D
		if part == null:
			continue
		var found := _level_regex.search(String(part.name))
		if found == null:
			part.visible = stage >= 1
		else:
			part.visible = found.get_string(1).to_int() <= stage


## Frees the lights that were exported inside the section glb, so only the `Sun` lights the world.
func _remove_embedded_lights(section: Node3D) -> void:
	for light in section.find_children("*", "Light3D", true, false):
		light.queue_free()
	for hemisphere in section.find_children("HemisphereLight*", "Node3D", true, false):
		hemisphere.queue_free()
