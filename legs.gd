class_name Legs
extends Node2D

@export var thigh_len := 20.0
@export var shin_len := 20.0
@export var thickness := 9.0
@export var outline := 3.0
@export var pants_color := Color("8a5a44")
@export var boot_color := Color("3b2418")
@export var outline_color := Color("3b2418")
@export var back_shade := 0.72   # the far leg is drawn darker

var speed_factor := 0.0   # 0..1, how fast the player flies
var flail := 0.0          # 0..1, legs go wild (tumble / engine out)
var sway := 0.0           # legs lag behind the body's rotation
var _phase := 0.0

func _process(delta: float) -> void:
	_phase += delta * (3.0 + speed_factor * 6.0 + flail * 12.0)
	queue_redraw()

func _draw() -> void:
	_draw_leg(_phase + PI, back_shade)
	_draw_leg(_phase, 1.0)

func _draw_leg(ph: float, shade: float) -> void:
	var swing := 0.3 + 0.25 * speed_factor + 0.8 * flail
	var a := -0.25 * speed_factor + sin(ph) * swing + sway   # thigh angle: 0 = straight down, + = forward
	var bend := 0.3 + maxf(0.0, sin(ph + 1.2)) * (0.5 + 0.7 * flail)
	var b := a - bend                                        # shin angle
	var knee := Vector2(sin(a), cos(a)) * thigh_len
	var foot := knee + Vector2(sin(b), cos(b)) * shin_len
	var fill := pants_color * Color(shade, shade, shade, 1.0)
	var w := thickness
	var ow := w + outline * 2.0
	var toe := Vector2(w * 1.1, 0.0)

	# outlines
	draw_line(Vector2.ZERO, knee, outline_color, ow, true)
	draw_line(knee, foot, outline_color, ow, true)
	draw_circle(Vector2.ZERO, ow / 2.0, outline_color)
	draw_circle(knee, ow / 2.0, outline_color)
	draw_line(foot, foot + toe, outline_color, ow * 1.25, true)
	# fills
	draw_line(Vector2.ZERO, knee, fill, w, true)
	draw_line(knee, foot, fill, w, true)
	draw_circle(Vector2.ZERO, w / 2.0, fill)
	draw_circle(knee, w / 2.0, fill)
	draw_line(foot, foot + toe, boot_color, w * 1.25, true)
