extends Area2D

@export var energy_amount := 35.0
var life := 20.0

func _ready() -> void:
	add_to_group("fuel")
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.add_energy(energy_amount)
		Sfx.play("pickup")
		queue_free()
