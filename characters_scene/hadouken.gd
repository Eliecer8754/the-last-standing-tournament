extends Area2D

@export var speed: float = 800
@export var damage: int = 20
@export var knockback_force: float = 1500  # Aumentado de ~800 a 1500
@export var knockback_up_force: float = 800  # Aumentado de ~500 a 800
@export var stun_duration: float = 0.6  # Stun más prolongado
var direction: Vector2 = Vector2.RIGHT

# Definir área de juego donde el Hadouken puede existir
@export var play_area: Rect2 = Rect2(Vector2(0, 0), Vector2(2000, 1000))

# --- READY ---
func _ready():
	print("Hadouken ready")

	connect("area_entered", Callable(self, "_on_area_entered"))

	# Ignorar colisión el primer frame
	if has_node("CollisionShape2D"):
		var shape = get_node("CollisionShape2D")
		shape.disabled = true
		await get_tree().process_frame
		shape.disabled = false

	# Asegurar que siempre procese física
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(true)

# --- PHYSICS PROCESS ---
func _physics_process(delta):
	# Mover en la dirección establecida
	position += direction * speed * delta

	# Destruir si sale del área jugable
	if not play_area.has_point(global_position):
		queue_free()

# --- COLISIONES ---
func _on_area_entered(area: Area2D):
	# Solo dañar enemigos
	if area.is_in_group("hurtbox_enemy"):
		var enemigo = area.get_parent()
		if enemigo.has_method("take_damage"):
			enemigo.take_damage(damage, global_position)
			# Aplicar knockback especial del Hadouken
			if enemigo.has_method("apply_hadouken_knockback"):
				enemigo.apply_hadouken_knockback(global_position, knockback_force, knockback_up_force, stun_duration)
		queue_free()  # destruir al impactar

# --- OPCIONAL: cambiar dirección ---
func set_direction(new_dir: Vector2):
	direction = new_dir.normalized()

# --- CONFIGURAR PROPIEDADES DE KNOCKBACK ---
func set_knockback(force: float, up_force: float, stun_time: float):
	knockback_force = force
	knockback_up_force = up_force
	stun_duration = stun_time
