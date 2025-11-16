extends Area2D

@export var speed: float = 1000.0
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	monitoring = true
	$CollisionShape2D.disabled = false
	connect("area_entered", Callable(self, "_on_area_entered"))

	# Opcional: destruir la bolita después de 3 segundos por seguridad
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	if direction != Vector2.ZERO:
		position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hitbox_jugador"):
		var jugador = area.get_parent()
		if jugador.has_method("take_damage"):
			jugador.take_damage(10, global_position)
			print("💥 Bolita golpea al jugador")
		queue_free()
	else:
		print("No golpeó a nadie")
