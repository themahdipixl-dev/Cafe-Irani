class_name CafeWorld
extends Node3D
## Root of the 3D world: the city chunks + cafe glb, an orthographic isometric camera, light and traffic.
##
## The glb files themselves are never modified at runtime. The city is city_fixed.glb:
## 4 merged chunks (`City_Chunk_NW/NE/SW/SE`), each with 2 surfaces (opaque + alpha scissor),
## so the whole city is at most 8 draw calls. Lamps are already baked into the chunks; the
## `Lamp_*` nodes are empty anchors. Shop-sign text is added by CityLabels on the `TextAnchor_*` nodes.
## The cafe (cafe_v2.glb) is never batched: its stages (`Sec_*/S01..S05`) are shown/hidden by
## unlock(). Its `Cafe_Flat` / `Cafe_Glass` materials are shaders reading vertex data (see
## CafeMaterials); its textured materials (plants, asphalt, turf) are used as imported.
## Cafe texts (menus, boards, signs) are added by CafeLabels on the text anchors of the cafe glb.

## Nodes inside the city glb that are removed at start. Empty: the chunk glb has no built-in cars
## (the real cars come from assets/Cars/ via Traffic).
@export var remove_nodes: PackedStringArray = []

## Nodes inside the cafe glb (cafe_v2.glb) that are removed at start. Empty: the parked cars
## and the entrance cypress ellipsoids are already gone from the cafe glb.
## Parked cars are spawned from assets/Cars/ by Traffic.
@export var remove_cafe_nodes: PackedStringArray = []

@export_group("Cafe materials")
## Shader for the glb material `Cafe_Flat` (albedo/roughness/metallic/emission from vertex data).
@export var flat_shader: Shader = preload("res://assets/cafe/shaders/cafe_flat.gdshader")
## Shader for the glb material `Cafe_Glass` (tint + alpha from vertex color).
@export var glass_shader: Shader = preload("res://assets/cafe/shaders/cafe_glass.gdshader")
## Emission palette: index -> linear rgb (TEXCOORD_1.u * 32 in the glb).
@export_file("*.json") var emission_palette_path := "res://assets/cafe/cafe_emission_palette.json"
## Multiplier for every emissive surface in the cafe.
@export var emission_energy := 1.0

@export_group("Cafe stages")
## Stage every section starts at: stages S01..S<n> are visible, the rest are hidden (0 = none).
## 5 shows the whole cafe. Base (walls, floor) is always visible.
@export_range(0, 5) var start_stage := 1

@export_group("City chunks")
## Name prefix of the merged city chunk meshes in the city glb.
@export var chunk_prefix := "City_Chunk"
## Chunks never cast shadows (the sun has shadows off anyway).
@export var chunk_cast_shadow := false

@export_group("Batching")
## Draw repeated city meshes with one MultiMesh per group (see InstanceBatcher).
## Off: the chunk glb is already merged, there is nothing left to batch.
@export var batch_repeated_meshes := false
## Name prefixes that are never batched. "Cafe" keeps the whole cafe (node `Cafe`) untouched.
@export var batch_exclude_prefixes: PackedStringArray = ["Car_", "ParkedCar_", "Cafe"]
## Smallest group of identical meshes that is batched.
@export var batch_min_instances := 2
## Grid cell size (m) used to split a group so culling still works. 0 = one MultiMesh per group.
@export var batch_chunk_size := 40.0

@export_group("Debug")
## Print the frame's draw calls and objects once per second. Turn off for release builds.
@export var log_draw_calls := true

@onready var _city: Node3D = $City
@onready var _cafe: Node3D = $City/Cafe
@onready var _labels: CityLabels = $CityLabels
@onready var _cafe_labels: CafeLabels = $CafeLabels

const MAX_STAGE := 5

var _log_timer := 0.0
## Section name (e.g. "Roastery") -> unlocked stage.
var _stages: Dictionary = {}


func _ready() -> void:
	_remove_named(_city, remove_nodes, "city")
	_remove_named(_cafe, remove_cafe_nodes, "cafe")
	_setup_cafe_materials()
	_init_stages()
	_setup_chunks()
	_labels.build(_city)
	_cafe_labels.build(_cafe)
	if batch_repeated_meshes:
		var stats := InstanceBatcher.batch(_city, batch_exclude_prefixes,
				batch_min_instances, batch_chunk_size)
		print("CafeWorld: batched %d nodes into %d MultiMeshes" % [stats.removed, stats.batches])
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


## Unlocks [param stage] (1..5) of a cafe section, e.g. unlock("Roastery", 2) shows S01 and S02.
## Never locks a section again (a lower stage than the current one is ignored).
## Section names: Roastery, Entrance, DriveThru, Kitchen, Marketing, Parking, Salon, Storage,
## Terrace, WC (a leading "Sec_" is accepted too).
func unlock(section: String, stage: int) -> void:
	var key := section.trim_prefix("Sec_")
	if not _stages.has(key):
		push_warning("CafeWorld: unknown cafe section '%s'" % section)
		return
	var target := clampi(stage, 0, MAX_STAGE)
	if target <= int(_stages[key]):
		return
	_set_stage(key, target)


## Returns the unlocked stage (0..5) of a cafe section, or -1 if the section does not exist.
func get_stage(section: String) -> int:
	return int(_stages.get(section.trim_prefix("Sec_"), -1))


## Finds every `Sec_*` node in the cafe and shows only its first [member start_stage] stages.
func _init_stages() -> void:
	for node in _cafe.find_children("Sec_*", "Node3D", true, false):
		var key := String(node.name).trim_prefix("Sec_")
		_stages[key] = start_stage
		_set_stage(key, start_stage)
	if _stages.is_empty():
		push_warning("CafeWorld: no 'Sec_*' nodes in the cafe glb")
	else:
		print("CafeWorld: %d cafe sections at stage %d" % [_stages.size(), start_stage])


## The children of `Sec_<section>` are the stages S01..S05 in order. They are matched by order,
## not by name: Godot makes glb node names unique, so only the first section keeps "S01".
## Stages above [param stage] are hidden.
func _set_stage(section: String, stage: int) -> void:
	_stages[section] = stage
	var sec := _cafe.find_child("Sec_" + section, true, false)
	if sec == null:
		return
	var index := 0
	for child in sec.get_children():
		var stage_node := child as Node3D
		if stage_node == null:
			continue
		index += 1
		stage_node.visible = index <= stage
	if index != MAX_STAGE:
		push_warning("CafeWorld: section '%s' has %d stage nodes, expected %d" % [section, index, MAX_STAGE])


## Replaces the glb's Cafe_Flat / Cafe_Glass materials with the vertex-data shaders.
func _setup_cafe_materials() -> void:
	var stats := CafeMaterials.apply(_cafe, emission_palette_path, flat_shader,
			glass_shader, emission_energy)
	print("CafeWorld: cafe shaders on %d flat + %d glass surfaces" % [stats.flat, stats.glass])
	if stats.flat == 0:
		push_warning("CafeWorld: no 'Cafe_Flat' surfaces found (is cafe_v2.glb imported?)")


## Prepares the merged city chunks: no shadows, and logs how many chunks/surfaces were found.
func _setup_chunks() -> void:
	var chunks := 0
	var surfaces := 0
	for node in _city.find_children(chunk_prefix + "*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not chunk_cast_shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunks += 1
		if mi.mesh != null:
			surfaces += mi.mesh.get_surface_count()
	if chunks == 0:
		push_warning("CafeWorld: no '%s*' meshes in the city glb" % chunk_prefix)
		return
	print("CafeWorld: %d city chunks, %d surfaces (max draw calls for the city)" % [chunks, surfaces])


## Frees every node in [param names] found below [param root]; warns about missing ones.
func _remove_named(root: Node, names: PackedStringArray, glb_label: String) -> void:
	for node_name in names:
		var node := root.find_child(node_name, true, false)
		if node == null:
			push_warning("CafeWorld: '%s' not found in the %s glb" % [node_name, glb_label])
			continue
		node.queue_free()
