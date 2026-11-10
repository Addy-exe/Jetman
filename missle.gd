class_name Missile
extends Area2D

@export var speed := 260.0
@export var homing := true
@export var lateral_accel := 480.0   # sideways grip: turn rate = lateral_accel / speed
@export var max_turn := 2.4
@export var min_turn := 0.6
@export var approach_range := 700.0  # speed-up starts inside this distance
@export var approach_boost := 0.7    # +70% speed when right on top of the player
@export var graze_distance := 110.0
@export var graze_energy := 15.0
@export var whoosh_distance := 520.0
@export var life := 9.0

var target: Node2D
var dir := Vector2.DOWN
var current_speed := 0.0
var age := 0.0
var grazed := false
var whooshed := false
var exploded := false
var _whoosh: AudioStreamPlayer2D

func _ready() -> void:
	add_to_group("missile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	current_speed = speed
	_make_trail()
	_make_flame()
	_make_audio()
	if not homing:
		_setup_straight()

func _setup_straight() -> void:
	# straight missiles are tinted and fly a fixed line toward where you're heading
	var sp := get_node_or_null("Sprite2D") as Sprite2D
	if sp:
		sp.modulate = Color(1.0, 0.8, 0.35)
	if is_instance_valid(target):
		var aim: Vector2 = target.global_position + target.velocity * 0.45
		dir = global_position.direction_to(aim)

func _make_audio() -> void:
	var w := Sfx.get_stream("whoosh")
	if w:
		_whoosh = AudioStreamPlayer2D.new()
		_whoosh.stream = w
		_whoosh.max_distance = 800.0
		_whoosh.volume_db = -3.0
		add_child(_whoosh)
	var l := Sfx.get_stream("launch")
	if l:
		var lp := AudioStreamPlayer2D.new()
		lp.stream = l
		lp.max_distance = 1600.0
		lp.volume_db = -12.0
		lp.pitch_scale = randf_range(0.9, 1.1)
		add_child(lp)
		lp.play()

func _make_flame() -> void:
	var f := Flame.new()
	f.size_scale = 0.4
	f.emit_smoke = false
	f.draw_puffs = false
	f.thrust = 0.7
	f.rotation = PI / 2.0
	f.position = Vector2(-32, 0)
	f.z_index = -1
	add_child(f)

func _make_trail() -> void:
	var t := CPUParticles2D.new()
	t.amount = 20
	t.lifetime = 0.8
	t.local_coords = false
	t.direction = Vector2(-1, 0)
	t.spread = 10.0
	t.gravity = Vector2.ZERO
	t.initial_velocity_min = 20.0
	t.initial_velocity_max = 40.0
	t.scale_amount_min = 5.0
	t.scale_amount_max = 9.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	t.color_ramp = g
	t.position = Vector2(-40, 0)
	t.z_index = -2
	add_child(t)

func _physics_process(delta: float) -> void:
	age += delta
	life -= delta
	if life <= 0.0:
		_explode(false)
		return

	var has_target := is_instance_valid(target)
	var dist := INF
	if has_target:
		dist = global_position.distance_to(target.global_position)

	# homing missiles accelerate as they close in on the player
	var wanted := speed
	if homing and has_target:
		var closeness := 1.0 - clampf(dist / approach_range, 0.0, 1.0)
		wanted = speed * (1.0 + approach_boost * closeness)
	current_speed = lerpf(current_speed, wanted, 2.5 * delta)

	# limited grip: the faster it goes, the wider it turns
	if homing and has_target:
		var turn := clampf(lateral_accel / current_speed, min_turn, max_turn)
		var desired := global_position.direction_to(target.global_position)
		var angle := dir.angle_to(desired)
		dir = dir.rotated(clampf(angle, -turn * delta, turn * delta))

	if has_target:
		if not grazed and dist < graze_distance:
			grazed = true
			target.add_energy(graze_energy)
			Sfx.play("graze", -6.0)
		if not whooshed and _whoosh and dist < whoosh_distance:
			whooshed = true
			_whoosh.pitch_scale = randf_range(0.9, 1.15)
			_whoosh.play()

	global_position += dir * current_speed * delta
	rotation = dir.angle()

func _on_body_entered(body: Node) -> void:
	if exploded:
		return
	if body.is_in_group("player"):
		body.die()
		_explode(true)

func _on_area_entered(other: Area2D) -> void:
	# two missiles colliding blast each other (short grace period after spawning)
	if exploded or age < 0.5:
		return
	var o := other as Missile
	if o == null or o.exploded or o.age < 0.5:
		return
	o._explode(false)
	_explode(true)

func _explode(with_sound: bool) -> void:
	if exploded:
		return
	exploded = true
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 28
	p.lifetime = 0.6
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 150.0
	p.initial_velocity_max = 380.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 14.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([
		Color(1, 0.9, 0.3, 1), Color(1, 0.4, 0.1, 0.9), Color(0.3, 0.3, 0.3, 0)])
	p.color_ramp = g
	p.global_position = global_position
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	if with_sound:
		Sfx.play("explosion")
	queue_free()
