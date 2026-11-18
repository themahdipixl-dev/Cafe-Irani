class_name CameraZoom
extends Camera3D
## Zoom + pan for the orthographic camera.
##
## Zoom: mouse wheel (desktop) or two-finger pinch (touch). Changes `size` only.
## Smaller size = zoomed in, bigger size = zoomed out.
## Pan: one-finger drag (touch) or left/middle mouse drag (desktop). Moves the camera
## along the ground, keeping its angle and height.
## Pinch uses `_input` so UI controls can't swallow it; pan uses `_unhandled_input`
## so dragging on a UI panel doesn't move the world.

## Closest zoom (smallest orthographic size, in meters). Must stay above 0.
@export var min_size: float = 8.0
## Farthest zoom (biggest orthographic size, in meters). The city is 100 m wide.
@export var max_size: float = 60.0
## Mouse wheel: size change per notch (0.1 = 10 %).
@export var wheel_step: float = 0.1
## Pinch strength: 1.0 = size follows the finger distance exactly.
@export var pinch_sensitivity: float = 1.0
## How fast the camera catches up with the target zoom (higher = snappier).
@export var smoothing: float = 12.0
## Pan strength: 1.0 = the world follows the finger exactly.
@export var pan_speed: float = 1.0
## The point on the ground the camera looks at may not leave this box (meters).
## Centre of the box (the cafe is at the origin) and half-extent on x / z.
@export var pan_center: Vector2 = Vector2.ZERO
@export var pan_half_extent: Vector2 = Vector2(30.0, 30.0)

var _target_size: float = 36.0
var _touches: Dictionary = {}  # finger index -> Vector2 position
var _last_pinch_distance: float = 0.0


func _ready() -> void:
	_target_size = clampf(size, min_size, max_size)


func _process(delta: float) -> void:
	if is_equal_approx(size, _target_size):
		return
	size = lerpf(size, _target_size, 1.0 - exp(-smoothing * delta))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.0 - wheel_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 + wheel_step)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_last_pinch_distance = _pinch_distance()
	elif event is InputEventScreenDrag:
		if not _touches.has(event.index):
			return
		_touches[event.index] = event.position
		var distance := _pinch_distance()
		if distance > 0.0 and _last_pinch_distance > 0.0:
			# Fingers apart (distance grows) -> zoom in -> smaller size.
			_zoom_by(pow(_last_pinch_distance / distance, pinch_sensitivity))
		_last_pinch_distance = distance


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		# Exactly one finger down = pan (two fingers = pinch zoom).
		if _touches.size() == 1:
			_pan_by(event.relative)
	elif event is InputEventMouseMotion:
		# Skip the mouse events Godot emulates from touches (they'd pan twice).
		if not _touches.is_empty():
			return
		var held: int = event.button_mask
		if held & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE):
			_pan_by(event.relative)


## Distance between the two fingers, or 0 when there are not exactly two.
func _pinch_distance() -> float:
	if _touches.size() != 2:
		return 0.0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _zoom_by(factor: float) -> void:
	_target_size = clampf(_target_size * factor, min_size, max_size)


## Moves the camera along the ground so the world follows the finger.
## `pixels` is the drag distance on screen.
func _pan_by(pixels: Vector2) -> void:
	var units_per_pixel := size / get_viewport().get_visible_rect().size.x
	var basis_now := global_transform.basis
	var right := Vector3(basis_now.x.x, 0.0, basis_now.x.z).normalized()
	var forward := -basis_now.z
	var ahead := Vector3(forward.x, 0.0, forward.z).normalized()
	# Screen-up covers more ground than its view-plane length (camera looks down at an angle).
	var sin_elevation := maxf(-forward.y, 0.1)
	var move := -pixels.x * right + (pixels.y / sin_elevation) * ahead
	global_position += move * units_per_pixel * pan_speed
	_clamp_pan()


## Keeps the ground point under the screen centre inside the pan box.
func _clamp_pan() -> void:
	var forward := -global_transform.basis.z
	if forward.y > -0.01:
		return  # looking at the horizon: no ground point
	var focus := global_position + forward * (-global_position.y / forward.y)
	var clamped_x := clampf(focus.x, pan_center.x - pan_half_extent.x, pan_center.x + pan_half_extent.x)
	var clamped_z := clampf(focus.z, pan_center.y - pan_half_extent.y, pan_center.y + pan_half_extent.y)
	global_position += Vector3(clamped_x - focus.x, 0.0, clamped_z - focus.z)
