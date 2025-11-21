extends Area2D

var direction: Vector2
var speed: float
var damage: int
var is_launched: bool = false

func _ready():
	# Conectar señales automáticamente
	connect_signals()

func connect_signals():
	# Conectar señales si no están ya conectadas
	if not body_entered.is_connected(_on_body_entered):
		var error = body_entered.connect(_on_body_entered)
		if error != OK:
			print("Error conectando body_entered: ", error)
	
	if not area_entered.is_connected(_on_area_entered):
		var error = area_entered.connect(_on_area_entered)
		if error != OK:
			print("Error conectando area_entered: ", error)

func setup_charge():
	# Desactivar movimiento durante la carga
	set_physics_process(false)
	# Efecto visual de carga
	modulate = Color(1, 1, 1, 0.7)
	# Asegurar que esté monitoreando
	monitoring = true
	monitorable = true

func launch(new_direction: Vector2, new_speed: float, new_damage: int):
	# Reactivar movimiento y configurar para lanzamiento
	direction = new_direction
	speed = new_speed
	damage = new_damage
	is_launched = true
	set_physics_process(true)
	modulate = Color(1, 1, 1, 1)  # Restaurar color normal
	monitoring = true
	monitorable = true
	print("HenkiDama lanzada con dirección: ", direction)

func _physics_process(delta):
	if is_launched:
		# Moverse en la dirección asignada
		global_position += direction * speed * delta
		
		# Rotar la henkidama para efecto visual
		rotation += 5 * delta
		
		# Auto-destrucción si sale de la pantalla
		if global_position.y > 1000 or global_position.x < -100 or global_position.x > 2000:
			queue_free()

func setup(new_direction: Vector2, new_speed: float, new_damage: int):
	# Método alternativo
	launch(new_direction, new_speed, new_damage)

# Para detectar colisiones con cuerpos (paredes, jugador, etc.)
func _on_body_entered(body):
	if is_launched:
		print("HenkiDama golpeó cuerpo: ", body.name)
		
		# Verificar si es el jugador
		if body.is_in_group("player"):
			print("¡Golpeó al jugador!")
			if body.has_method("take_damage"):
				# LLAMAR CORRECTAMENTE A take_damage CON TODOS LOS PARÁMETROS
				body.take_damage(damage, global_position)
			queue_free()
		
		# También verificar si es una pared o suelo
		elif body.is_in_group("ground") or body.is_in_group("wall"):
			print("Golpeó pared o suelo")
			queue_free()

# También detectar colisiones con áreas (como el hurtbox del jugador)
func _on_area_entered(area):
	if is_launched:
		print("HenkiDama golpeó área: ", area.name, " - Grupo: ", area.get_groups())
		
		# Verificar si es el hurtbox del jugador
		if area.is_in_group("player_hurtbox"):
			print("¡Golpeó el hurtbox del jugador!")
			var player = area.get_parent()
			if player and player.has_method("take_damage"):
				# LLAMAR CORRECTAMENTE A take_damage CON TODOS LOS PARÁMETROS
				player.take_damage(damage, global_position)
			queue_free()
		
		# Verificar si es una plataforma u obstáculo
		elif area.is_in_group("platform") or area.is_in_group("obstacle"):
			print("Golpeó plataforma u obstáculo")
			queue_free()
