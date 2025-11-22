extends Area2D

@export var speed: float = 500.0
var damage: int = 25

func _ready() -> void:
	monitoring = true
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = false
	connect("area_entered", Callable(self, "_on_area_entered"))
	
	# Destruir después de 3 segundos por seguridad
	await get_tree().create_timer(3.0).timeout
	queue_free()


func setup(dir: int, dmg: int):
	damage = dmg

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox_player"):
		var jugador = area.get_parent()
		if jugador and jugador.has_method("take_damage"):
			jugador.take_damage(damage, global_position)
			print("💥 Beam golpea al jugador - Daño: ", damage)
		queue_free()
