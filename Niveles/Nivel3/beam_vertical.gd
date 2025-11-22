# StaticVerticalBeam.gd
extends Area2D

var damage: int = 20
var active_duration: float = 2.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	monitoring = true
	connect("area_entered", Callable(self, "_on_area_entered"))
	
	# Destruir después del tiempo activo
	await get_tree().create_timer(active_duration).timeout
	queue_free()

func setup(dmg: int):
	damage = dmg
	# NO hay configuración de dirección o movimiento


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox_player"):
		var jugador = area.get_parent()
		if jugador and jugador.has_method("take_damage"):
			jugador.take_damage(damage, global_position)
			print("💥 Beam vertical golpea al jugador - Daño: ", damage)
