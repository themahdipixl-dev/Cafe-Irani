class_name CafeWorld
extends Node3D
## Root of the 3D world: the city chunks + cafe glb, an orthographic isometric camera, light and traffic.
##
## The glb files themselves are never modified at runtime. The city is city_chunks_2x2.glb:
## 4 merged chunks (`City_Chunk_NW/NE/SW/SE`), each with 2 surfaces (opaque + alpha scissor),
## so the whole city is at most 8 draw calls. Lamps are already baked into the chunks; the
## `Lamp_*` nodes are empty anchors. Shop-sign text is added by CityLabels on the `TextAnchor_*` nodes.
## The cafe is never batched: its objects must stay separate so each can be shown/hidden by upgrades.

## Nodes inside the city glb that are removed at start. Empty: the chunk glb has no built-in cars
## (the real cars come from assets/Cars/ via Traffic).
@export var remove_nodes: PackedStringArray = []

## Nodes inside the cafe glb (cafe_only_opt5.glb) that are removed at start: the two parked cars
## in the parking lot (red in bay S02, blue in bay S03), each made of body + glass + wheels.
## Parked cars are spawned from assets/Cars/ by Traffic instead.
## "EntranceS04Mat_ff083ad7" is the solid green ellipsoid mesh of the two entrance cypresses
## (x = -1.8 and +1.8, z = 5.5). It hides the leaf-card trees (EntranceS04CF_PlantAtlas) under it.
## The node holds only those two ellipsoids (no children, mesh not shared), so nothing else goes.
@export var remove_cafe_nodes: PackedStringArray = [
	"ParkingS02CarRed", "ParkingS02CarGlass", "ParkingS02Wheel",
	"ParkingS03CarBlue", "ParkingS03CarGlass", "ParkingS03Wheel",
	"EntranceS04Mat_ff083ad7",
]

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

var _log_timer := 0.0


func _ready() -> void:
	_remove_named(_city, remove_nodes, "city")
	_remove_named(_cafe, remove_cafe_nodes, "cafe")
	_setup_chunks()
	_labels.build(_city)
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
