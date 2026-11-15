class_name CafeWorld
extends Node3D
## Root of the 3D world: the city + cafe glb, an orthographic isometric camera, light and traffic.
##
## The glb files themselves are never modified at runtime. Things we don't want from them
## (their built-in cars) are removed here when the scene starts, and repeated city meshes
## (trees, lamp posts, props...) are drawn with MultiMesh to cut draw calls.
## The cafe is never batched: its objects must stay separate so each can be shown/hidden by upgrades.

## Nodes inside the city glb that are removed at start (the glb's own cars;
## the real cars come from assets/Cars/ via Traffic).
@export var remove_nodes: PackedStringArray = [
	"Car_E_1", "Car_N_1", "Car_S_1", "Car_S_2", "Car_W_1",
	"ParkedCar_1", "ParkedCar_2",
]

@export_group("Batching")
## Draw repeated city meshes with one MultiMesh per group (see InstanceBatcher).
@export var batch_repeated_meshes := true
## Name prefixes that are never batched. "Cafe" keeps the whole cafe (node `Cafe`) untouched.
@export var batch_exclude_prefixes: PackedStringArray = ["Car_", "ParkedCar_", "Cafe"]
## Smallest group of identical meshes that is batched.
@export var batch_min_instances := 2
## Grid cell size (m) used to split a group so culling still works. 0 = one MultiMesh per group.
@export var batch_chunk_size := 40.0

@export_group("Debug")
## TEMP: hides the whole cafe to measure draw calls without it. Set to false (or remove) when done.
@export var debug_hide_cafe := true

@onready var _city: Node3D = $City


func _ready() -> void:
	for node_name in remove_nodes:
		var node := _city.find_child(node_name, true, false)
		if node == null:
			push_warning("CafeWorld: '%s' not found in the city glb" % node_name)
			continue
		node.queue_free()
	if batch_repeated_meshes:
		var stats := InstanceBatcher.batch(_city, batch_exclude_prefixes,
				batch_min_instances, batch_chunk_size)
		print("CafeWorld: batched %d nodes into %d MultiMeshes" % [stats.removed, stats.batches])
	if debug_hide_cafe:
		var cafe := _city.get_node_or_null("Cafe") as Node3D
		if cafe != null:
			cafe.visible = false
			print("CafeWorld: DEBUG cafe hidden")
