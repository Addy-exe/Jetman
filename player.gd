extends CharacterBody2D

signal died
signal energy_changed(value: float, max_value: float)

enum State { FLYING, TUMBLING, STALLED }

@export var speed := 450.0
@export var dash_speed := 1600.0
@export var dash_cost := 100.0          # equal to max_energy: one dash per full bar
@export var max_energy := 100.0
@export var passive_regen := 6.0
@export var tumble_time := 1.4          # how long control is lost
@export var min_rotations := 3
@export var max_rotations := 4
@export var invuln_time := 0.4          # protected only at the start of the dash
@export var tumble_end_speed := 140.0
@export var stall_sink := 250.0         # how fast you drop while the engine is out
@export var relight_threshold := 0.25   # joystick push needed to regain control

var state := State.FLYING
var energy := 100.0
var dead := false
var joystick: Node

var facing := 1.0
var tilt := 0.0
var tilt_vel := 0.0
var thrust := 0.4
var thrust_audio: AudioStreamPlayer

var _tumble_t := 0.0
var _tumble_dir := Vector2.RIGHT
var _tumble_spin := 1.0
var _tumble_turns := 3
var _tumble_start := 0.0

@onready var visual: Node2D = $Visual
@onready var flame: Flame = $Visual/Flame
@onready var legs: Legs = $Visual/Legs

func _ready() -> void:
	add_to_group("player")
	_setup_thrust_audio()

func _setup_thrust_audio() -> void:
	var path := "res://audio/thrust.wav"
	if not ResourceLoader.exists(path):
		return
	thrust_audio = AudioStreamPlayer.new()
	thrust_audio.stream = load(path)
	thrust_audio.volume_db = -20.0
	thrust_audio.finished.connect(func(): thrust_audio.play())
	add_child(thrust_audio)
	thrust_audio.play()

func _physics_process(delta: float) -> void:
	if joystick == null:
		joystick = get_tree().get_first_node_in_group("joystick")

	if dead:
		velocity.y = move_toward(velocity.y, 700.0, 1500.0 * delta)
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		move_and_slide()
		tilt += 5.0 * facing * delta
		visual.rotation = tilt
		legs.flail = 1.0
		return

	var dir := _get_input_dir()
	if Input.is_action_just_pressed("ui_accept"):  # Space bar, for PC testing
		try_dash()

	match state:
		State.FLYING:
			velocity = velocity.lerp(dir * speed, 8.0 * delta)
			add_energy(passive_regen * delta)
		State.TUMBLING:
			_tumble_t += delta
			var u := clampf(_tumble_t / tumble_time, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - u, 2.2)
			velocity = _tumble_dir * lerpf(dash_speed, tumble_end_speed, e)
			if u >= 1.0:
				state = State.STALLED
				tilt = wrapf(tilt, -PI, PI)
				tilt_vel = 0.0
		State.STALLED:
			velocity.x = lerpf(velocity.x, 0.0, 2.0 * delta)
			velocity.y = minf(velocity.y + stall_sink * delta, 500.0)
			add_energy(passive_regen * delta)
			if dir.length() > relight_threshold:
				state = State.FLYING
				thrust = 1.3   # engine relights with a surge

	move_and_slide()
	_update_visual(dir, delta)

func _update_visual(dir: Vector2, delta: float) -> void:
	var flail := 0.0
	var target_thrust := 0.35 + dir.length() * 0.5

	match state:
		State.TUMBLING:
			var u := clampf(_tumble_t / tumble_time, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - u, 2.2)
			tilt = _tumble_start + _tumble_spin * float(_tumble_turns) * TAU * e
			tilt_vel = 0.0
			flail = 1.0 - u
			# a short blast at the start of the dash, then the engine sputters out
			if _tumble_t < 0.15:
				target_thrust = 1.4
			else:
				target_thrust = 0.08 + 0.12 * absf(sin(_tumble_t * 30.0))
		_:
			if state == State.FLYING and absf(dir.x) > 0.2:
				facing = signf(dir.x)
			var target := 0.0
			if state == State.FLYING:
				target = dir.y * 0.45 * facing + absf(dir.x) * 0.12 * facing
			tilt_vel += ((target - tilt) * 40.0 - tilt_vel * 5.0) * delta
			tilt += tilt_vel * delta
			if state == State.STALLED:
				target_thrust = 0.05 + 0.1 * randf()
				flail = 0.35

	visual.scale.x = move_toward(visual.scale.x, facing, 10.0 * delta)
	visual.rotation = tilt

	thrust = lerpf(thrust, target_thrust, 10.0 * delta)
	flame.thrust = thrust

	if thrust_audio:
		var tn := clampf(thrust / 1.4, 0.0, 1.0)
		thrust_audio.volume_db = lerpf(-26.0, -8.0, tn)
		thrust_audio.pitch_scale = lerpf(0.85, 1.35, tn)

	legs.speed_factor = clampf(velocity.length() / speed, 0.0, 1.0)
	legs.flail = flail
	legs.sway = clampf(-tilt_vel * 0.04, -0.7, 0.7)

func _get_input_dir() -> Vector2:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if joystick and joystick.output != Vector2.ZERO:
		dir = joystick.output
	return dir

func try_dash() -> void:
	if state != State.FLYING or dead or energy < dash_cost:
		return
	energy -= dash_cost
	energy_changed.emit(energy, max_energy)
	var d := _get_input_dir()
	if d.length() < 0.1:
		d = Vector2(facing, 0.0)
	_tumble_dir = d.normalized()
	if absf(_tumble_dir.x) > 0.1:
		_tumble_spin = signf(_tumble_dir.x)
	else:
		_tumble_spin = facing
	facing = _tumble_spin
	_tumble_turns = randi_range(min_rotations, max_rotations)
	_tumble_start = wrapf(tilt, -PI, PI)
	_tumble_t = 0.0
	state = State.TUMBLING
	Sfx.play("dash")

func add_energy(amount: float) -> void:
	energy = minf(energy + amount, max_energy)
	energy_changed.emit(energy, max_energy)

func die() -> void:
	if dead:
		return
	if state == State.TUMBLING and _tumble_t < invuln_time:
		return   # protected at the very start of the dash
	dead = true
	velocity = Vector2.ZERO
	flame.stop()
	if thrust_audio:
		thrust_audio.stop()
	died.emit()
