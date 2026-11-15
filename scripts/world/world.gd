class_name CafeWorld
extends Node3D
## Root of the 3D world: the city + cafe glb, an orthographic isometric camera, light and traffic.
##
## The glb file itself is never modified. Things we don't want from it (its built-in cars)
## are removed here when the scene starts.

## Nodes inside the city glb that are removed at start (the glb's own cars;
## the real cars come from assets/Cars/ via Traffic).
@export var remove_nodes: PackedStringArray = [
	"Car_E_1", "Car_N_1", "Car_S_1", "Car_S_2", "Car_W_1",
	"ParkedCar_1", "ParkedCar_2",
]

@onready var _city: Node3D = $City


func _ready() -> void:
	for node_name in remove_nodes:
		var node := _city.find_child(node_name, true, false)
		if node == null:
			push_warning("CafeWorld: '%s' not found in the city glb" % node_name)
			continue
		node.queue_free()
