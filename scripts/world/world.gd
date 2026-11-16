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

@export_group("Batching")
## Draw repeated city meshes with one MultiMesh per group (see InstanceBatcher).
@export var batch_repeated_meshes := true
## Name prefixes that are never batched. "Cafe" keeps the whole cafe (node `Cafe`) untouched.
@export var batch_exclude_prefixes: PackedStringArray = ["Car_", "ParkedCar_", "Cafe"]
## Smallest group of identical meshes that is batched.
@export var batch_min_instances := 2
## Grid cell size (m) used to split a group so culling still works. 0 = one MultiMesh per group.
@export var batch_chunk_size := 40.0

## TEMP (draw call test, remove afterwards): hides the cafe and all cars so only the city is drawn.
@export var temp_hide_cafe_and_cars := true

@onready var _city: Node3D = $City
@onready var _cafe: Node3D = $City/Cafe


func _ready() -> void:
	_remove_named(_city, remove_nodes, "city")
	_remove_named(_cafe, remove_cafe_nodes, "cafe")
	if batch_repeated_meshes:
		var stats := InstanceBatcher.batch(_city, batch_exclude_prefixes,
				batch_min_instances, batch_chunk_size)
		print("CafeWorld: batched %d nodes into %d MultiMeshes" % [stats.removed, stats.batches])
	if temp_hide_cafe_and_cars: # TEMP
		_temp_hide_cafe_and_cars()


## TEMP (draw call test, remove afterwards): hides the cafe and the Traffic node (all cars).
func _temp_hide_cafe_and_cars() -> void:
	_cafe.visible = false
	var traffic := get_node_or_null("Traffic")
	if traffic == null:
		traffic = find_child("Traffic", true, false)
	if traffic is Node3D:
		traffic.visible = false
	else:
		push_warning("CafeWorld TEMP: Traffic node not found, cars are still visible")
	print("CafeWorld TEMP: cafe and cars hidden (draw call test)")


## Frees every node in [param names] found below [param root]; warns about missing ones.
func _remove_named(root: Node, names: PackedStringArray, glb_label: String) -> void:
	for node_name in names:
		var node := root.find_child(node_name, true, false)
		if node == null:
			push_warning("CafeWorld: '%s' not found in the %s glb" % [node_name, glb_label])
			continue
		node.queue_free()
