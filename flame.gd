class_name Flame
extends Node2D

@export var size_scale := 1.0      # shrinks/grows everything in this flame
@export var emit_smoke := true     # smoke trail that stays in the world
@export var draw_puffs := true     # small dark puffs drawn on the flame itself

var thrust := 0.4
var _t := 0.0
var _smoke: CPUParticles2D

func _ready() -> void:
	if emit_smoke:
		_make_smoke()

func stop() -> void:
	thrust = 0.0
	if _smoke:
		_smoke.emitting = false

func _make_smoke() -> void:
	_smoke = CPUParticles2D.new()
	_smoke.amount = 36
	_smoke.lifetime = 1.2
	_smoke.local_coords = false
	_smoke.direction = Vector2(0, 1)
	_smoke.spread = 22.0
	_smoke.gravity = Vector2.ZERO
	_smoke.initial_velocity_min = 25.0 * size_scale
	_smoke.initial_velocity_max = 90.0 * size_scale
	_smoke.scale_amount_min = 0.2 * size_scale
	_smoke.scale_amount_max = 0.35 * size_scale
	_smoke.position = Vector2(0, 20.0 * size_scale)

	# round puff texture
	var puff := Gradient.new()
	puff.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	puff.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = puff
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	_smoke.texture = tex

	# puffs grow as they age
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.8))
	_smoke.scale_amount_curve = grow

	# ember at the nozzle -> thick black -> dirty grey -> gone
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(0.55, 0.16, 0.05, 0.75),
		Color(0.06, 0.05, 0.05, 0.85),
		Color(0.16, 0.14, 0.13, 0.45),
		Color(0.2, 0.19, 0.18, 0.0)])
	_smoke.color_ramp = g
	add_child(_smoke)

func _process(delta: float) -> void:
	_t += delta
	if _smoke:
		_smoke.speed_scale = lerpf(0.7, 1.6, clampf(thrust, 0.0, 1.0))
	queue_redraw()

func _draw() -> void:
	var power := clampf(thrust, 0.0, 1.0)
	if power <= 0.01:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * size_scale)

	var a := lerpf(0.6, 1.0, power)
	var flicker := 0.85 + 0.15 * sin(_t * 25.0) + 0.08 * sin(_t * 43.0)
	var length := (25.0 + 75.0 * power) * flicker
	var width := 12.0 + 12.0 * power

	# dark red outer flame
	draw_colored_polygon(PackedVector2Array([
		Vector2(-width, 0),
		Vector2(-width * 0.85, length * 0.25),
		Vector2(-width * 0.5, length * 0.55),
		Vector2(0, length * 0.85),
		Vector2(width * 0.5, length * 0.55),
		Vector2(width * 0.85, length * 0.25),
		Vector2(width, 0)]), Color(0.65, 0.12, 0.025, 0.7 * a))

	# orange inner flame
	draw_colored_polygon(PackedVector2Array([
		Vector2(-width * 0.65, 0),
		Vector2(-width * 0.45, length * 0.25),
		Vector2(0, length * 0.55),
		Vector2(width * 0.45, length * 0.25),
		Vector2(width * 0.65, 0)]), Color(1.0, 0.28, 0.035, 0.85 * a))

	# hot yellow core, only when dashing
	var hot := clampf(thrust - 0.8, 0.0, 1.0)
	if hot > 0.0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-width * 0.3, 0), Vector2(0, length * 0.35), Vector2(width * 0.3, 0)]),
			Color(1.0, 0.8, 0.25, hot))

	# glowing ember
	draw_circle(Vector2(0, length * 0.12), width * 0.35, Color(1.0, 0.5, 0.08, 0.5 * a))

	# dark smoke puffs mixed into the flame
	if draw_puffs:
		for i in range(5):
			var progress := float(i) / 5.0
			var sway := sin(_t * 7.0 + float(i) * 2.5) * 7.0
			var pos := Vector2(sway, length * (0.2 + progress * 0.65))
			var puff_size := (5.0 + progress * 6.0) * lerpf(0.6, 1.0, power)
			draw_circle(pos, puff_size, Color(0.035, 0.03, 0.03, 0.75))
			draw_circle(pos + Vector2(-2.0, -2.0), puff_size * 0.45, Color(0.16, 0.14, 0.13, 0.35))
