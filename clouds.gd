extends Node2D

const TILE := Vector2(2000, 3200)
const CLOUD_FILES := ["cloud1", "cloud2", "cloud3", "cloud4"]
const COUNT := 20

var _clouds: Array = []

func _ready() -> void:
	z_index = -10
	var textures: Array[Texture2D] = []
	for n in CLOUD_FILES:
		var path := "res://art/%s.png" % n
		if ResourceLoader.exists(path):
			textures.append(load(path))
	if textures.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in COUNT:
		var depth := rng.randf_range(0.45, 0.95)   # lower = farther away
		var tex: Texture2D = textures[rng.randi() % textures.size()]
		var target_width := remap(depth, 0.45, 0.95, 220.0, 420.0)
		_clouds.append({
			"pos": Vector2(rng.randf() * TILE.x, rng.randf() * TILE.y),
			"tex": tex,
			"depth": depth,
			"scale": target_width / tex.get_width(),
			"alpha": remap(depth, 0.45, 0.95, 0.35, 0.8),
		})
	_clouds.sort_custom(func(a, b): return a.depth < b.depth)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := Vector2.ZERO
	var player := get_tree().get_first_node_in_group("player")
	if player:
		c = player.global_position
	for cl in _clouds:
		var tex: Texture2D = cl.tex
		var k: float = cl.depth
		var p: Vector2 = cl.pos
		var w := Vector2(
			fposmod(p.x - k * c.x + TILE.x / 2.0, TILE.x) - TILE.x / 2.0 + c.x,
			fposmod(p.y - k * c.y + TILE.y / 2.0, TILE.y) - TILE.y / 2.0 + c.y)
		var sz := tex.get_size() * float(cl.scale)
		draw_texture_rect(tex, Rect2(w - sz / 2.0, sz), false, Color(1, 1, 1, cl.alpha))
