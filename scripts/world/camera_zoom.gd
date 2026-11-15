class_name CameraZoom
extends Camera3D
## Zoom for the orthographic camera: mouse wheel (desktop) and two-finger pinch (touch).
##
## Zooming only changes `size`; the camera position and angle stay fixed.
## Smaller size = zoomed in, bigger size = zoomed out.
## Uses `_input` (not `_unhandled_input`) so UI controls can't swallow the touches.

## Closest zoom (smallest orthographic size, in meters).
@export var min_size: float = 16.0
## Farthest zoom (biggest orthographic size, in meters).
@export var max_size: float = 60.0
## Mouse wheel: size change per notch (0.1 = 10 %).
@export var wheel_step: float = 0.1
## Pinch strength: 1.0 = size follows the finger distance exactly.
@export var pinch_sensitivity: float = 1.0
## How fast the camera catches up with the target zoom (higher = snappier).
@export var smoothing: float = 12.0

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


## Distance between the two fingers, or 0 when there are not exactly two.
func _pinch_distance() -> float:
	if _touches.size() != 2:
		return 0.0
	var points: Array = _touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _zoom_by(factor: float) -> void:
	_target_size = clampf(_target_size * factor, min_size, max_size)
