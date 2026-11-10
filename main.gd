extends Node2D

const SAVE_PATH := "user://save.cfg"

@export var missile_scene: PackedScene
@export var fuel_scene: PackedScene

var elapsed := 0.0
var spawn_timer := 1.0
var fuel_timer := 4.0
var alive := true
var best := 0.0

func _ready() -> void:
	best = _load_best()
	$Player.position = Vector2.ZERO
	$Player.died.connect(_on_player_died)
	$Player.energy_changed.connect(_on_energy_changed)
	$HUD/Joystick.double_tapped.connect($Player.try_dash)
	$HUD/GameOver.visible = false
	$HUD/GameOver/Box/RestartButton.pressed.connect(
		func(): get_tree().reload_current_scene())
	Sfx.play_music()

func _process(delta: float) -> void:
	if not alive:
		return
	elapsed += delta

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_missile()
		spawn_timer = maxf(0.6, 2.5 - elapsed * 0.03)

	fuel_timer -= delta
	if fuel_timer <= 0.0:
		_spawn_fuel()
		fuel_timer = 7.0

	$HUD/TimeLabel.text = _fmt(elapsed)

func _spawn_missile() -> void:
	var radius := get_viewport_rect().size.length() / 2.0 + 80.0
	var pos: Vector2 = $Player.global_position + Vector2.from_angle(randf() * TAU) * radius
	var ramp := minf(elapsed * 0.004, 0.6)                        # everything gets faster over time
	var homing_chance := clampf(0.3 + elapsed * 0.01, 0.3, 0.9)   # more homing missiles over time
	var m := missile_scene.instantiate() as Missile
	m.global_position = pos
	m.target = $Player
	m.dir = pos.direction_to($Player.global_position)
	m.homing = randf() < homing_chance
	if m.homing:
		m.speed = 260.0 * (1.0 + ramp)
	else:
		m.speed = 420.0 * (1.0 + ramp)
		m.life = 6.0
	add_child(m)

func _spawn_fuel() -> void:
	if get_tree().get_nodes_in_group("fuel").size() >= 3:
		return
	var f := fuel_scene.instantiate()
	f.global_position = $Player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(350.0, 800.0)
	add_child(f)

func _on_energy_changed(value: float, max_value: float) -> void:
	$HUD/EnergyBar.max_value = max_value
	$HUD/EnergyBar.value = value

func _on_player_died() -> void:
	alive = false
	var new_best := elapsed > best
	if new_best:
		best = elapsed
		_save_best(best)
	await get_tree().create_timer(0.6).timeout
	$HUD/GameOver/Box/TitleLabel.text = "NEW BEST!" if new_best else "GAME OVER"
	$HUD/GameOver/Box/ScoreLabel.text = "Time  " + _fmt(elapsed)
	$HUD/GameOver/Box/BestLabel.text = "Best  " + _fmt(best)
	$HUD/GameOver.visible = true

func _fmt(t: float) -> String:
	return "%d:%02d" % [floori(t / 60.0), int(t) % 60]

func _load_best() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return float(cfg.get_value("score", "best", 0.0))
	return 0.0

func _save_best(value: float) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", value)
	cfg.save(SAVE_PATH)
