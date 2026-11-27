class_name Garden
extends Node2D
## Chapter 1 environment: a walled 30x30 m Achaemenid four-part garden.
## Ground, paths, canals and walls are flat Polygon2D; items come from data/garden_layout.json.

const LAYOUT_PATH := "res://data/garden_layout.json"
const TEXTURE_DIR := "res://assets/meta/"

# Draw order layers (z_index).
const Z_GROUND := -4000
const Z_PATH := -3950
const Z_PLAZA := -3900
const Z_CANAL_RIM := -3850
const Z_CANAL := -3800
const Z_BACK_WALL := -3000
const Z_FOG := 3500

const PATH_HALF := 1.3
const CANAL_HALF := 0.35
const CANAL_RIM := 0.2
const FOUNTAIN_PLAZA_RADIUS := 4.4
## Extra plazas as [x0, z0, x1, z1] in meters.
const PLAZAS := [
	[-2.2, 4.8, 2.2, 9.2], # around small_pool_1
	[-2.2, -9.2, 2.2, -4.8], # around small_pool_2
	[-2.9, 11.5, 2.9, 14.5], # in front of the entry gate
	[-4.4, -14.5, 4.4, -11.5], # in front of the palace gate
]

const WALL_THICKNESS := 0.5
const WALL_BAND := 0.35
const WALL_PIECE := 5.0
const ENTRY_GATE_HALF := 2.35
const PALACE_GATE_HALF := 4.2

const FOG_COLOR := Color(0.93, 0.95, 0.97, 0.92)
const FOG_HEIGHT := 2.0
const HUMAN_HEIGHT_PX := 139.0

@export var front_wall_height := 1.2
@export var back_wall_height := 3.0
## Shows a 1.7 m reference figure near the entry gate (scale check).
@export var show_human_ref := false
## Starts with all zones covered by fog.
@export var fog_enabled := false

var _zone_fog: Dictionary = {}


func _ready() -> void:
	_build_ground()
	_build_paths()
	_build_canals()
	_build_walls()
	_build_items()
	_build_fog()
	_build_human_ref()


## Covers or uncovers one zone ("A" to "E") with fog.
func set_zone_fogged(zone: String, fogged: bool, duration := 0.35) -> void:
	for node in _zone_fog.get(zone, []):
		var poly := node as Polygon2D
		if fogged:
			poly.visible = true
		var tween := create_tween()
		tween.tween_property(poly, "modulate:a", 1.0 if fogged else 0.0, duration)
		if not fogged:
			tween.tween_callback(poly.hide)


# --- helpers -----------------------------------------------------------------

func _s(x: float, y: float, z: float) -> Vector2:
	return GardenConfig.world_to_screen(x, y, z)


func _poly(points: PackedVector2Array, color: Color, zi: int) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = points
	poly.color = color
	poly.z_index = zi
	add_child(poly)
	return poly


func _flat_quad(x0: float, z0: float, x1: float, z1: float, color: Color, zi: int) -> Polygon2D:
	return _poly(PackedVector2Array([
		_s(x0, 0.0, z0), _s(x1, 0.0, z0), _s(x1, 0.0, z1), _s(x0, 0.0, z1)]), color, zi)


func _flat_circle(cx: float, cz: float, radius: float, color: Color, zi: int) -> Polygon2D:
	var points := PackedVector2Array()
	for i in 48:
		var a := TAU * float(i) / 48.0
		points.append(_s(cx + cos(a) * radius, 0.0, cz + sin(a) * radius))
	return _poly(points, color, zi)


# --- ground, paths, canals ----------------------------------------------------

func _build_ground() -> void:
	var h := GardenConfig.HALF
	_flat_quad(-h, -h, h, h, GardenConfig.GROUND, Z_GROUND)


func _build_paths() -> void:
	var h := GardenConfig.HALF
	# Main axis (entry gate to palace gate) and cross axis.
	_flat_quad(-PATH_HALF, -h, PATH_HALF, h, GardenConfig.STONE, Z_PATH)
	_flat_quad(-(h - 0.5), -PATH_HALF, h - 0.5, PATH_HALF, GardenConfig.STONE, Z_PATH)
	_flat_circle(0.0, 0.0, FOUNTAIN_PLAZA_RADIUS, GardenConfig.STONE_LIGHT, Z_PLAZA)
	for r in PLAZAS:
		_flat_quad(r[0], r[1], r[2], r[3], GardenConfig.STONE_LIGHT, Z_PLAZA)


func _build_canals() -> void:
	var w := CANAL_HALF
	var r := CANAL_HALF + CANAL_RIM
	var rim := GardenConfig.STONE.darkened(0.12)
	_flat_quad(-r, -13.0, r, 13.0, rim, Z_CANAL_RIM)
	_flat_quad(-14.0, -r, 14.0, r, rim, Z_CANAL_RIM)
	_flat_quad(-w, -13.0, w, 13.0, GardenConfig.TURQUOISE, Z_CANAL)
	_flat_quad(-14.0, -w, 14.0, w, GardenConfig.TURQUOISE, Z_CANAL)


# --- walls --------------------------------------------------------------------

func _build_walls() -> void:
	var h := GardenConfig.HALF
	var t := WALL_THICKNESS
	# Back walls (tall): x = -15 (top-left) and z = -15 (top-right, gap for the palace gate).
	_wall_run(false, -h, -h + t, -h, h, back_wall_height, true)
	_wall_run(true, -h, -h + t, -h, -PALACE_GATE_HALF, back_wall_height, true)
	_wall_run(true, -h, -h + t, PALACE_GATE_HALF, h, back_wall_height, true)
	# Front walls (low): x = +15 (bottom-right) and z = +15 (bottom-left, gap for the entry gate).
	_wall_run(false, h - t, h, -h, h, front_wall_height, false)
	_wall_run(true, h - t, h, -h, -ENTRY_GATE_HALF, front_wall_height, false)
	_wall_run(true, h - t, h, ENTRY_GATE_HALF, h, front_wall_height, false)


## Builds one straight wall run. along_x: the wall runs along x (fixed z), else along z (fixed x).
## v0..v1 is the wall's thickness range, a..b its length range.
func _wall_run(along_x: bool, v0: float, v1: float, a: float, b: float, height: float, back: bool) -> void:
	var count := maxi(1, ceili((b - a) / WALL_PIECE))
	var step := (b - a) / float(count)
	for i in count:
		var p0 := a + step * float(i)
		var p1 := p0 + step
		var zi := Z_BACK_WALL
		if not back:
			var uc := (p0 + p1) * 0.5
			var vc := (v0 + v1) * 0.5
			zi = GardenConfig.z_for(uc, vc) if along_x else GardenConfig.z_for(vc, uc)
		_wall_piece(along_x, v0, v1, p0, p1, height, zi)


func _uv(along_x: bool, u: float, v: float, y: float) -> Vector2:
	return _s(u, y, v) if along_x else _s(v, y, u)


func _wall_piece(along_x: bool, v0: float, v1: float, a: float, b: float, height: float, zi: int) -> void:
	var base := GardenConfig.STONE_LIGHT
	var shade := base.darkened(0.12)
	# Walls along x show a +z face (darker); walls along z show a +x face.
	var face_color := shade if along_x else base
	var end_color := base if along_x else shade
	var band := height - WALL_BAND
	_poly(PackedVector2Array([
		_uv(along_x, b, v0, 0.0), _uv(along_x, b, v1, 0.0),
		_uv(along_x, b, v1, height), _uv(along_x, b, v0, height)]), end_color, zi)
	_poly(PackedVector2Array([
		_uv(along_x, a, v1, 0.0), _uv(along_x, b, v1, 0.0),
		_uv(along_x, b, v1, height), _uv(along_x, a, v1, height)]), face_color, zi)
	_poly(PackedVector2Array([
		_uv(along_x, a, v1, band), _uv(along_x, b, v1, band),
		_uv(along_x, b, v1, height), _uv(along_x, a, v1, height)]), GardenConfig.LAPIS, zi)
	_poly(PackedVector2Array([
		_uv(along_x, a, v0, height), _uv(along_x, b, v0, height),
		_uv(along_x, b, v1, height), _uv(along_x, a, v1, height)]), base.lightened(0.25), zi)


# --- items ----------------------------------------------------------------------

func _load_layout() -> Dictionary:
	var res := load(LAYOUT_PATH) as JSON
	if res == null or not res.data is Dictionary:
		push_error("Garden layout missing or invalid: " + LAYOUT_PATH)
		return {}
	return res.data


func _build_items() -> void:
	var data := _load_layout()
	if data.is_empty():
		return
	var tex_scale := float(data.get("texture_scale", 0.5))
	var defs: Dictionary = data.get("sprites", {})
	var root := Node2D.new()
	root.name = "Items"
	add_child(root)
	for entry in data.get("items", []):
		var item: Dictionary = entry
		var sprite := _make_sprite(item, defs, tex_scale)
		if sprite != null:
			root.add_child(sprite)


## Pivot = center of the item's footprint on the ground, in texture pixels.
func _make_sprite(item: Dictionary, defs: Dictionary, tex_scale: float) -> Sprite2D:
	var sprite_id := String(item.get("sprite", ""))
	var def: Dictionary = defs.get(sprite_id, {})
	var tex := load(TEXTURE_DIR + sprite_id + ".png") as Texture2D
	if tex == null or def.is_empty():
		push_warning("Garden item skipped (missing texture or definition): " + sprite_id)
		return null
	var foot := 0.0
	if String(def.get("kind", "rect")) == "round":
		foot = float(def["diameter"]) * 28.85
	else:
		foot = (float(def["w"]) + float(def["d"])) * 20.41
	var x := float(item["x"])
	var z := float(item["z"])
	var y := float(item.get("y", 0.0))
	var k := tex_scale * float(item.get("scale", 1.0))
	var sprite := Sprite2D.new()
	sprite.name = String(item.get("name", sprite_id))
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = -Vector2(tex.get_width() * 0.5, tex.get_height() - foot / tex_scale)
	sprite.scale = Vector2(k, k)
	sprite.flip_h = bool(item.get("flip", false))
	sprite.position = _s(x, y, z)
	sprite.z_index = GardenConfig.z_for(x, z) + int(item.get("z_bias", 0))
	sprite.set_meta("zone", String(item.get("zone", "")))
	return sprite


# --- fog ----------------------------------------------------------------------------

func _rect_poly(x0: float, z0: float, x1: float, z1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)])


func _circle_poly(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		points.append(Vector2(cos(a), sin(a)) * radius)
	return points


func _subtract(subjects: Array, clip: PackedVector2Array) -> Array:
	var out: Array = []
	for subject in subjects:
		out.append_array(Geometry2D.clip_polygons(subject, clip))
	return out


## Zone polygons in world (x, z) coordinates.
func _zone_polygons(zone: String) -> Array:
	var h := GardenConfig.HALF
	var core := _circle_poly(6.0)
	var entry := _rect_poly(-7.0, 8.0, 7.0, h)
	match zone:
		"A":
			return [entry]
		"B":
			return [core]
		"C":
			return _subtract(_subtract([_rect_poly(-h, 0.0, h, h)], entry), core)
		"D":
			return _subtract([_rect_poly(-h, -h, 0.0, 0.0)], core)
		"E":
			return _subtract([_rect_poly(0.0, -h, h, 0.0)], core)
	return []


func _build_fog() -> void:
	for zone in ["A", "B", "C", "D", "E"]:
		var list: Array = []
		for world_poly in _zone_polygons(zone):
			var points := PackedVector2Array()
			for v in world_poly:
				var p: Vector2 = v
				points.append(_s(p.x, FOG_HEIGHT, p.y))
			var fog := _poly(points, FOG_COLOR, Z_FOG)
			fog.visible = fog_enabled
			fog.modulate.a = 1.0 if fog_enabled else 0.0
			list.append(fog)
		_zone_fog[zone] = list


# --- debug ----------------------------------------------------------------------------

func _build_human_ref() -> void:
	var figure := ColorRect.new()
	figure.name = "HumanRef"
	figure.size = Vector2(60.0, HUMAN_HEIGHT_PX)
	figure.color = Color(0.85, 0.2, 0.2, 0.8)
	figure.position = _s(0.0, 0.0, 12.0) - Vector2(30.0, HUMAN_HEIGHT_PX)
	figure.z_index = GardenConfig.z_for(0.0, 12.0) + 1
	figure.visible = show_human_ref
	add_child(figure)
