extends Control
class_name TouchJoystick

signal stick_moved(stick: Vector2)

const RADIUS := 52.0

var _touch_id := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_base = size * 0.5
		queue_redraw()

func _draw() -> void:
	if size == Vector2.ZERO:
		return
	draw_circle(_base, RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(_base, RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(_base + _knob, 22, Color(1, 1, 1, 0.5))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and _touch_id == -1:
			_touch_id = touch.index
			_set_knob(_base)
		elif not touch.pressed and touch.index == _touch_id:
			_touch_id = -1
			_set_knob(Vector2.ZERO)
			stick_moved.emit(Vector2.ZERO)
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == _touch_id:
			var dir := drag.position - _base
			if dir.length() > RADIUS:
				dir = dir.normalized() * RADIUS
			_set_knob(dir)
			stick_moved.emit(dir / RADIUS)

func _set_knob(knob: Vector2) -> void:
	_knob = knob
	queue_redraw()