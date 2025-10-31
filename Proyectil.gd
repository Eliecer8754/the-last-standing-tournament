extends Node2D

@export var speed: float = 500
var direction: Vector2 = Vector2.ZERO

func _physics_process(delta):
	position += direction * speed * delta

	# Eliminar si sale de la pantalla
	var viewport = get_viewport_rect()
	if position.x < 0 or position.x > viewport.size.x or position.y < 0 or position.y > viewport.size.y:
		queue_free()
