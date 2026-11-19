class_name Traffic
extends Node3D
## Animated cars around the cafe: two ring-road loops plus a few parked cars.
##
## Car models are the glb files in assets/Cars/ (length = 1 unit along +X, front = +X,
## body + 4 separate wheel nodes). Each car is scaled to `car_length` meters, snapped to the
## road using its wheel bottoms, and its wheels spin based on the distance driven.
## Every model in CAR_PATHS is used (random order each run, no repeats until all are used).
## Everything tunable is an exported var (edit in the inspector, no code change needed).

const CAR_PATHS: Array[String] = [
	"res://assets/Cars/pars.glb",
	"res://assets/Cars/dena.glb",
	"res://assets/Cars/nissanabi.glb",
	"res://assets/Cars/pride.glb",
	"res://assets/Cars/shahin.glb",
	"res://assets/Cars/tara.glb",
]
## How far ahead (m) a car looks to decide its heading. Smooths the turns.
const LOOK_AHEAD := 1.5
## Shape fallback for finding wheels (model units, a car is 1 unit long): a wheel mesh is
## round (x ~ y), flat (z smaller) and has a diameter between these two sizes.
const WHEEL_MIN_DIAMETER := 0.1
const WHEEL_MAX_DIAMETER := 0.35
## Name parts that mark a wheel node (compared after lowercasing and removing `_`, `-`, `.`, spaces).
const WHEEL_KEYWORDS: Array[String] = ["wheel", "tire", "tyre"]
## Name parts that look like a wheel but are not one (wheel arch, wheel well, ...).
const WHEEL_EXCLUDED: Array[String] = ["arch", "well", "house", "cover", "guard", "fender"]

@export_group("Cars")
## Final car length in meters (the glb models are 1 unit long).
@export var car_length := 3.6
## Height of the asphalt surface.
@export var road_y := -0.05
## Extra height (m) added to every car so the wheels sit on the road instead of sinking into it.
## Raise it if the wheels are still inside the ground, lower it if the cars float.
@export var ground_lift := 0.1
## 0 = a new random car order every run. Any other number = the same order every run.
@export var random_seed := 0

@export_group("Outer loop (counter-clockwise, right-hand lane)")
## Half size (x, z) of the loop rectangle = lane centerlines.
@export var outer_half_size := Vector2(20.5, 18.5)
@export var outer_cars := 3
## Meters per second (slowed down for inspecting the cars).
@export var outer_speed := 3.0

@export_group("Inner loop (clockwise)")
@export var inner_half_size := Vector2(17.5, 15.5)
@export var inner_cars := 2
## Meters per second (slowed down for inspecting the cars).
@export var inner_speed := 2.0

@export_group("Shape")
@export var corner_radius := 3.0

@export_group("Parked cars")
## Spots in world space: x, ground height, z.
@export var parked_spots: Array[Vector3] = [Vector3(8.6, 0.01, 8.75), Vector3(8.6, 0.01, 4.55)]
## 0 = nose towards +X, 180 = nose towards -X (towards the cafe building).
@export var parked_yaw_deg := 180.0

var _runners: Array[Runner] = []


## A closed rounded-rectangle road line in the XZ plane (points are Vector2(x, z)).
class Loop:
	const STEPS := 8
	var pts := PackedVector2Array()
	var cum := PackedFloat32Array()
	var length := 0.0

	func build(half: Vector2, r: float, counter_clockwise: bool) -> void:
		var hx := half.x
		var hz := half.y
		var p := PackedVector2Array()
		# Counter-clockwise order (north lane heads -X, west lane +Z, south lane +X, east lane -Z).
		_arc(p, Vector2(hx - r, -hz + r), r, 0.0, -90.0)     # NE corner
		_arc(p, Vector2(-hx + r, -hz + r), r, -90.0, -180.0) # NW corner
		_arc(p, Vector2(-hx + r, hz - r), r, 180.0, 90.0)    # SW corner
		_arc(p, Vector2(hx - r, hz - r), r, 90.0, 0.0)       # SE corner
		if not counter_clockwise:
			p.reverse()
		pts = p
		cum = PackedFloat32Array([0.0])
		for i in range(pts.size()):
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			cum.append(cum[i] + a.distance_to(b))
		length = cum[cum.size() - 1]

	func _arc(p: PackedVector2Array, c: Vector2, r: float, a0: float, a1: float) -> void:
		for i in range(STEPS + 1):
			var a := deg_to_rad(lerpf(a0, a1, float(i) / STEPS))
			p.append(c + Vector2(cos(a), sin(a)) * r)

	func sample(s: float) -> Vector2:
		s = fposmod(s, length)
		var n := pts.size()
		var i := 0
		while i < n - 1 and cum[i + 1] < s:
			i += 1
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var seg := cum[i + 1] - cum[i]
		var t := 0.0 if seg < 0.0001 else (s - cum[i]) / seg
		return a.lerp(b, t)


## One car: its root node, wheel pivots and (optionally) the loop it drives on.
class Runner:
	var node: Node3D
	var wheels: Array[Node3D] = []
	var wheel_radius := 0.17  # in meters (already scaled)
	var loop: Loop
	var speed := 0.0
	var s := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	var models := CAR_PATHS.duplicate()
	_shuffle(models, rng)
	var next_model := 0

	var outer := Loop.new()
	outer.build(outer_half_size, corner_radius, true)
	var inner := Loop.new()
	inner.build(inner_half_size, corner_radius, false)

	for entry in [[outer, outer_cars, outer_speed], [inner, inner_cars, inner_speed]]:
		var loop: Loop = entry[0]
		var count: int = entry[1]
		for i in range(count):
			var runner := _make_car(models[next_model % models.size()])
			next_model += 1
			if runner == null:
				continue
			runner.loop = loop
			runner.speed = entry[2]
			runner.s = loop.length * float(i) / float(count) + rng.randf_range(-2.0, 2.0)
			_runners.append(runner)
			_update(runner, 0.0, 1.0)

	for spot in parked_spots:
		var parked := _make_car(models[next_model % models.size()])
		next_model += 1
		if parked == null:
			continue
		parked.node.position = spot + Vector3(0.0, ground_lift, 0.0)
		parked.node.rotation.y = deg_to_rad(parked_yaw_deg)


func _process(delta: float) -> void:
	for runner in _runners:
		_update(runner, runner.speed * delta, clampf(delta * 10.0, 0.0, 1.0))


## Moves a car along its loop by `dist` meters. `turn_smooth` (0..1) blends the heading.
func _update(r: Runner, dist: float, turn_smooth: float) -> void:
	r.s += dist
	var p := r.loop.sample(r.s)
	var ahead := r.loop.sample(r.s + LOOK_AHEAD)
	var d := ahead - p
	r.node.position = Vector3(p.x, road_y + ground_lift, p.y)
	if d.length_squared() > 0.0001:
		# Model front is +X: rotating +X by yaw gives (cos, 0, -sin).
		var target := atan2(-d.y, d.x)
		r.node.rotation.y = lerp_angle(r.node.rotation.y, target, turn_smooth)
	if dist != 0.0:
		var spin := dist / r.wheel_radius
		for w in r.wheels:
			# Negative Z rotation = top of the wheel moves towards +X (forward).
			w.rotation.z = wrapf(w.rotation.z - spin, -PI, PI)


## Loads a car glb, scales it, gives every wheel a pivot at its center and sits it on the ground.
func _make_car(path: String) -> Runner:
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Traffic: cannot load %s" % path)
		return null
	var model := scene.instantiate() as Node3D
	var holder := Node3D.new()
	holder.name = path.get_file().get_basename()
	holder.scale = Vector3.ONE * car_length
	holder.add_child(model)
	add_child(holder)

	var runner := Runner.new()
	runner.node = holder
	var ground := INF
	var radius_sum := 0.0
	for wheel in _find_wheels(model):
		var box := wheel.get_aabb()
		# Some models bake the wheel offset into the mesh, so pivot at the mesh center.
		var center: Vector3 = wheel.transform * box.get_center()
		var radius := (box.size.x + box.size.y) * 0.25
		ground = minf(ground, center.y - radius)
		radius_sum += radius
		var parent := wheel.get_parent()
		var pivot := Node3D.new()
		pivot.name = "%sPivot" % wheel.name
		parent.add_child(pivot)
		pivot.position = center
		parent.remove_child(wheel)
		pivot.add_child(wheel)
		wheel.position -= center
		runner.wheels.append(pivot)

	if runner.wheels.is_empty():
		var names: PackedStringArray = []
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			names.append(String(mi.name))
		push_warning("Traffic: no wheels found in %s (meshes: %s)" % [path, ", ".join(names)])
		ground = -0.17
	else:
		runner.wheel_radius = radius_sum / float(runner.wheels.size()) * car_length
	model.position.y = -ground
	return runner


## Lowercases a node name and removes `_`, `-`, `.` and spaces, so `Wheel_FL`, `wheel-fl`,
## `Left_Back_Wheel` and `wheel.001` are all compared in the same plain form.
func _name_key(node_name: String) -> String:
	return node_name.to_lower().replace("_", "").replace("-", "").replace(".", "").replace(" ", "")


## True if a node name (as `_name_key`) marks a wheel / tire (and is not a wheel arch or similar).
func _is_wheel_key(key: String) -> bool:
	for bad in WHEEL_EXCLUDED:
		if key.contains(bad):
			return false
	for word in WHEEL_KEYWORDS:
		if key.contains(word):
			return true
	return false


## True if the mesh itself, or one of its parents inside the model, is named like a wheel.
func _is_wheel_mesh(mi: MeshInstance3D, model: Node) -> bool:
	var node: Node = mi
	while node != null and node != model:
		if _is_wheel_key(_name_key(String(node.name))):
			return true
		node = node.get_parent()
	return false


## Finds the wheel meshes of a car model. First by name (see `_name_key`: works with `_` in the
## names), then by shape (round, flat, small) for models whose wheel nodes have other names.
## A wheel mesh sitting inside another wheel mesh is skipped (it moves with its parent).
func _find_wheels(model: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh != null and _is_wheel_mesh(mi, model):
			found.append(mi)
	if not found.is_empty():
		var top: Array[MeshInstance3D] = []
		for mi in found:
			var nested := false
			var p: Node = mi.get_parent()
			while p != null and p != model:
				if p in found:
					nested = true
					break
				p = p.get_parent()
			if not nested:
				top.append(mi)
		return top
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var size := mi.get_aabb().size
		var widest := maxf(size.x, size.y)
		var is_round := absf(size.x - size.y) <= 0.2 * widest
		var is_flat := size.z < 0.8 * widest
		if is_round and is_flat and widest >= WHEEL_MIN_DIAMETER and widest <= WHEEL_MAX_DIAMETER:
			found.append(mi)
	return found


func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
