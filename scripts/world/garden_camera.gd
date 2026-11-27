class_name GardenCamera
extends Camera2D
## One-finger pan and pinch zoom. Mouse drag and wheel work in the editor (touch emulation).

@export var min_zoom := 0.7
@export var max_zoom := 2.0
@export var start_zoom := 1.5
## Start focus as (x, z) in garden meters. (0, 8) shows the entry area.
@export var start_world := Vector2(0.0, 8.0)
@export var wheel_factor := 1.1

var _touches: Dictionary = {}
var _last_pinch := 0.0
var _tween: Tween


func _ready() -> void:
	limit_left = GardenConfig.LIMIT_LEFT
	limit_right = GardenConfig.LIMIT_RIGHT
	limit_top = GardenConfig.LIMIT_TOP
	limit_bottom = GardenConfig.LIMIT_BOTTOM
	zoom = Vector2.ONE * start_zoom
	position = GardenConfig.world_to_screen(start_world.x, 0.0, start_world.y)


## Smoothly moves the camera to a garden position (x, z in meters).
func focus_on_world(x: float, z: float, duration := 0.6) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", GardenConfig.world_to_screen(x, 0.0, z), duration)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touches[touch.index] = touch.position
		else:
			_touches.erase(touch.index)
		_last_pinch = _pinch_distance()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touches[drag.index] = drag.position
		if _touches.size() == 1:
			_kill_tween()
			position -= drag.relative / zoom.x
		elif _touches.size() >= 2:
			var dist := _pinch_distance()
			if _last_pinch > 0.0 and dist > 0.0:
				_set_zoom(zoom.x * dist / _last_pinch)
			_last_pinch = dist
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x * wheel_factor)
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x / wheel_factor)


func _pinch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var points := _touches.values()
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _set_zoom(value: float) -> void:
	zoom = Vector2.ONE * clampf(value, min_zoom, max_zoom)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
