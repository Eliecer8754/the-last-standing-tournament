extends Area2D

@export var speed: float = 300.0
@export var damage: int = 15
@export var is_unblockable: bool = true  # Nueva propiedad
var direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	monitoring = true
	connect("area_entered", Callable(self, "_on_area_entered"))
	
	# Rotar el misil según la dirección
	rotation = direction.angle()
	
	# Auto-destrucción después de 5 segundos por seguridad
	await get_tree().create_timer(5.0).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("hurtbox_player"):
		var jugador = area.get_parent()
		if jugador.has_method("take_damage"):
			# Pasar true como tercer parámetro para indicar que es unblockable
			jugador.take_damage(damage, global_position, true)
			print("💥 Misil aéreo golpea al jugador - NO BLOQUEABLE")
		queue_free()
	
	# Destruirse al tocar el suelo
	if area.is_in_group("suelo") or area.is_in_group("piso"):
		queue_free()
