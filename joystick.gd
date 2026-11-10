extends Control

signal double_tapped

const RADIUS := 120.0
const TAP_MAX_TIME := 0.25    # a tap must be shorter than this (seconds)
const TAP_MAX_MOVE := 30.0    # and move less than this (pixels)
const DOUBLE_TAP_GAP := 0.35  # max time between the two taps

var output := Vector2.ZERO
var _touch_index := -1
var _origin := Vector2.ZERO
var _press_time := 0.0
var _last_tap_time := -10.0
var _moved := 0.0

func _ready() -> void:
	add_to_group("joystick")
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_origin = event.position
			_press_time = _now()
			_moved = 0.0
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			output = Vector2.ZERO
			var t := _now()
			if t - _press_time < TAP_MAX_TIME and _moved < TAP_MAX_MOVE:
				if t - _last_tap_time < DOUBLE_TAP_GAP:
					double_tapped.emit()
					_last_tap_time = -10.0
				else:
					_last_tap_time = t
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		output = (event.position - _origin).limit_length(RADIUS) / RADIUS
		_moved = maxf(_moved, event.position.distance_to(_origin))
		queue_redraw()

func _draw() -> void:
	if _touch_index == -1:
		return
	draw_arc(_origin, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 4.0)
	draw_circle(_origin + output * RADIUS, 40.0, Color(1, 1, 1, 0.6))
