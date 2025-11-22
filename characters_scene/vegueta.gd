extends CharacterBody2D

# --- MOVEMENT PROPERTIES ---
@export var flight_speed: float = 300
@export var acceleration: float = 25
@export var x_limits: Vector2 = Vector2(150, 1200)
@export var y_limits: Vector2 = Vector2(-50, 200)

# --- COMBAT PROPERTIES ---
@export var attack_duration: float = 0.3
@export var damage: int = 10
@export var health: int = 2000
var max_health: int
@export var fixed_beam_positions: Array[Vector2] = [
	Vector2(338, 198),
	Vector2(945, 197),  
	Vector2(1400, 189)
]

# --- HENKIDAMA PROPERTIES ---
@export var henki_dama_scene: PackedScene
@export var henki_dama_damage: int = 30
@export var henki_dama_speed: float = 650
@export var henki_charge_duration: float = 0.7

# --- BEAM ATTACK PROPERTIES ---
@export var beam_scene: PackedScene
@export var beam_damage: int = 25
@export var beam_charge_duration: float = 1.0
@export var beam_active_duration: float = 0.3

# --- VERTICAL BEAM PROPERTIES ---
@export var vertical_beam_scene: PackedScene
@export var vertical_beam_damage: int = 20
@export var vertical_beam_active_duration: float = 1.5

# --- KNOCKBACK PROPERTIES ---
@export var knockback_force: float = 80
@export var knockback_up_force: float = 60
@export var stun_duration: float = 0.3
@export var knockback_delay: float = 0.1

# --- NODES ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtboxIdle: Area2D = $hurtboxIdle
@onready var hurtboxFlying: Area2D = $hurtboxFlying
@onready var henki_spawn_point: Node2D = $HenkiSpawnPoint
@onready var left_beam_spawn: Node2D = $LeftBeamSpawn
@onready var right_beam_spawn: Node2D = $RightBeamSpawn

# --- VARIABLES ---
var player: CharacterBody2D
var target_position: Vector2
var is_stunned: bool = false
var current_health: int
var health_bar: ProgressBar = null
var gravity: float = 0
var current_henki_dama: Node2D = null
var left_beam: Node2D = null
var right_beam: Node2D = null
var vertical_beams: Array = []

# --- STATE MACHINE ---
enum State { 
	POSITIONING, 
	ATTACK_PREP, 
	HENKI_CHARGE, 
	ATTACKING, 
	BEAM_CHARGE, 
	BEAM_ACTIVE, 
	VERTICAL_BEAM_CHARGE,
	VERTICAL_BEAM_ACTIVE,
	COOLDOWN, 
	STUNNED 
}

var current_state: State = State.POSITIONING
var previous_state: State = State.POSITIONING
var state_timer: float = 0.0
var attack_choice: int = 0

# --- SIGNALS ---
signal enemy_defeated
signal health_changed(new_health: int, max_health: int)

func _ready():
	max_health = health
	current_health = health
	print("BOSS INICIALIZADO - Posición inicial: ", global_position)
	
	setup_hurtboxes()
	find_player()
	transition_to_state(State.POSITIONING)

func set_health_bar(bar: ProgressBar):
	health_bar = bar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		print("Barra de salud del boss asignada correctamente")

func setup_hurtboxes():
	hurtboxIdle.add_to_group("hurtbox_enemy")
	hurtboxIdle.connect("area_entered", Callable(self, "_on_hurtbox_area_entered"))
	
	hurtboxFlying.add_to_group("hurtbox_enemy") 
	hurtboxFlying.connect("area_entered", Callable(self, "_on_hurtbox_area_entered"))
	
	update_hurtboxes()

func update_hurtboxes():
	match current_state:
		State.POSITIONING, State.ATTACKING:
			hurtboxFlying.monitoring = true
			hurtboxIdle.monitoring = false
		State.ATTACK_PREP, State.HENKI_CHARGE, State.BEAM_CHARGE, State.BEAM_ACTIVE, State.VERTICAL_BEAM_CHARGE, State.VERTICAL_BEAM_ACTIVE, State.COOLDOWN, State.STUNNED:
			hurtboxFlying.monitoring = false
			hurtboxIdle.monitoring = true

func _physics_process(delta):
	if player == null:
		find_player()
	
	velocity.y = 0
	
	if is_stunned:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 3)
		move_and_slide()
		clamp_to_limits()
			
		state_timer -= delta
		if state_timer <= 0:
			is_stunned = false
			print("STUN finalizado - Volviendo al estado: ", State.keys()[previous_state])
			transition_to_state(previous_state)
		return
	
	state_timer -= delta
	
	match current_state:
		State.POSITIONING:
			execute_positioning(delta)
		State.ATTACK_PREP:
			execute_attack_prep(delta)
		State.HENKI_CHARGE:
			execute_henki_charge(delta)
		State.ATTACKING:
			execute_attacking(delta)
		State.BEAM_CHARGE:
			execute_beam_charge(delta)
		State.BEAM_ACTIVE:
			execute_beam_active(delta)
		State.VERTICAL_BEAM_CHARGE:
			execute_vertical_beam_charge(delta)
		State.VERTICAL_BEAM_ACTIVE:
			execute_vertical_beam_active(delta)
		State.COOLDOWN:
			execute_cooldown(delta)
	
	move_and_slide()
	clamp_to_limits()

func clamp_to_limits():
	var clamped_position = global_position
	clamped_position.x = clamp(clamped_position.x, x_limits.x, x_limits.y)
	clamped_position.y = clamp(clamped_position.y, y_limits.x, y_limits.y)
	global_position = clamped_position

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("Jugador encontrado: ", player.global_position)
	else:
		print("ERROR: No se encontró jugador")

func transition_to_state(new_state: State):
	# Si estamos saliendo de STUNNED, asegurarnos de limpiar el flag
	if current_state == State.STUNNED and new_state != State.STUNNED:
		is_stunned = false
		print("Saliendo del estado STUNNED")
	
	# Limpiar henkidama si estamos en STUNNED o POSITIONING
	if (new_state == State.STUNNED or new_state == State.POSITIONING) and current_henki_dama and is_instance_valid(current_henki_dama):
		print("Limpiando henkidama al cambiar a estado: ", State.keys()[new_state])
		current_henki_dama.queue_free()
		current_henki_dama = null
	
	# Limpiar beams si estamos en STUNNED o POSITIONING
	if (new_state == State.STUNNED or new_state == State.POSITIONING):
		cleanup_all_attacks()
	
	current_state = new_state
	print("CAMBIO DE ESTADO: ", State.keys()[current_state])
	update_hurtboxes()
	
	match new_state:
		State.POSITIONING:
			state_timer = 1.0
			generate_new_position()
			sprite.play("desplazarseAire")
		State.ATTACK_PREP:
			state_timer = 0.5
			velocity = Vector2.ZERO
			look_at_player()
			# Elegir aleatoriamente entre los tres tipos de ataque
			attack_choice = randi() % 3
			print("Elegido ataque: ", ["HENKI_DAMA", "BEAM_HORIZONTAL", "BEAM_VERTICAL"][attack_choice])
		State.HENKI_CHARGE:
			state_timer = henki_charge_duration
			velocity = Vector2.ZERO
			sprite.play("henki_charge")
			look_at_player()
			create_henki_dama()
			print("INICIANDO CARGA DE HENKIDAMA")
		State.ATTACKING:
			state_timer = 0.7
			start_attack()
		State.BEAM_CHARGE:
			state_timer = beam_charge_duration
			velocity = Vector2.ZERO
			sprite.play("beam_charge")
			look_at_player()
			print("INICIANDO CARGA DE BEAM")
		State.BEAM_ACTIVE:
			state_timer = beam_active_duration
			velocity = Vector2.ZERO
			create_beams()
			print("BEAMS ACTIVOS")
		State.VERTICAL_BEAM_CHARGE:
			state_timer = beam_charge_duration
			velocity = Vector2.ZERO
			sprite.play("beam_v")
			print("INICIANDO CARGA DE BEAM VERTICAL")
		State.VERTICAL_BEAM_ACTIVE:
			state_timer = vertical_beam_active_duration
			velocity = Vector2.ZERO
			create_vertical_beams()
			print("BEAMS VERTICALES ACTIVOS EN 3 PUNTOS")
		State.COOLDOWN:
			state_timer = 2.5
			sprite.play("idle")
			cleanup_all_attacks()
		State.STUNNED:
			state_timer = stun_duration
			sprite.play("hurt")
			cleanup_all_attacks()
			print("INICIANDO STUN - Duración: ", stun_duration)

func execute_positioning(delta):
	var direction = (target_position - global_position).normalized()
	velocity = velocity.move_toward(direction * flight_speed, acceleration)
	
	if direction.x != 0:
		sprite.flip_h = direction.x < 0
	
	# Transición más rápida si está cerca del objetivo o se acaba el tiempo
	if global_position.distance_to(target_position) < 30 or state_timer <= 0:
		transition_to_state(State.ATTACK_PREP)

func execute_attack_prep(delta):
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2)
	look_at_player()
	
	if state_timer <= 0:
		match attack_choice:
			0:
				transition_to_state(State.HENKI_CHARGE)
			1:
				transition_to_state(State.BEAM_CHARGE)
			2:
				transition_to_state(State.VERTICAL_BEAM_CHARGE)

func execute_henki_charge(delta):
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2)
	look_at_player()
	
	if current_henki_dama and is_instance_valid(current_henki_dama):
		current_henki_dama.global_position = henki_spawn_point.global_position
	
	if state_timer <= 0:
		transition_to_state(State.ATTACKING)

func execute_attacking(delta):
	look_at_player()
	
	if state_timer <= 0:
		transition_to_state(State.COOLDOWN)

func execute_beam_charge(delta):
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2)
	look_at_player()
	
	if state_timer <= 0:
		transition_to_state(State.BEAM_ACTIVE)

func execute_beam_active(delta):
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2)
	look_at_player()
	
	# Actualizar posición de los beams si existen
	if left_beam and is_instance_valid(left_beam):
		left_beam.global_position = left_beam_spawn.global_position
	if right_beam and is_instance_valid(right_beam):
		right_beam.global_position = right_beam_spawn.global_position
	
	if state_timer <= 0:
		transition_to_state(State.COOLDOWN)

func execute_vertical_beam_charge(delta):
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2)
	
	if state_timer <= 0:
		transition_to_state(State.VERTICAL_BEAM_ACTIVE)

func execute_vertical_beam_active(delta):
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2)
	
	# LOS BEAMS VERTICALES YA NO SE MUEVEN - SON ESTÁTICOS
	# No actualizamos su posición
	
	if state_timer <= 0:
		transition_to_state(State.COOLDOWN)

func execute_cooldown(delta):
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2)
	look_at_player()
	
	if state_timer <= 0:
		transition_to_state(State.POSITIONING)

func generate_new_position():
	# Si el jugador existe, generar posición cerca del jugador para más interacción
	if player:
		var player_pos = player.global_position
		# Generar posición en un radio alrededor del jugador
		var angle = randf() * 2 * PI
		var distance = randf_range(150, 300)  # Distancia media del jugador
		target_position = player_pos + Vector2(cos(angle), sin(angle)) * distance
	else:
		# Fallback a posición aleatoria si no hay jugador
		var random_x = randf_range(x_limits.x, x_limits.y)
		var random_y = randf_range(y_limits.x, y_limits.y)
		target_position = Vector2(random_x, random_y)
	
	# Asegurar que esté dentro de los límites
	var margin = 20
	target_position.x = clamp(target_position.x, x_limits.x + margin, x_limits.y - margin)
	target_position.y = clamp(target_position.y, y_limits.x + margin, y_limits.y - margin)

func look_at_player():
	if player:
		var player_direction = sign(player.global_position.x - global_position.x)
		if player_direction != 0:
			sprite.flip_h = player_direction < 0
			# Actualizar dirección del punto de spawn de henkidama 
			henki_spawn_point.position.x = abs(henki_spawn_point.position.x) * player_direction

func create_henki_dama():
	print("CREANDO HENKIDAMA DE CARGA")
	if henki_dama_scene:
		current_henki_dama = henki_dama_scene.instantiate()
		get_parent().add_child(current_henki_dama)
		
		current_henki_dama.global_position = henki_spawn_point.global_position
		print("Henkidama creada en: ", current_henki_dama.global_position)
		
		if current_henki_dama.has_method("setup_charge"):
			current_henki_dama.setup_charge()
			print("Henkidama configurada en modo carga")
		else:
			print("ADVERTENCIA: La henkidama no tiene método setup_charge")
	else:
		print("ERROR: No se asignó henki_dama_scene")

func create_beams():
	print("CREANDO BEAMS")
	if beam_scene:
		# Crear beam izquierdo
		left_beam = beam_scene.instantiate()
		get_parent().add_child(left_beam)
		left_beam.global_position = left_beam_spawn.global_position
		
		# Crear beam derecho  
		right_beam = beam_scene.instantiate()
		get_parent().add_child(right_beam)
		right_beam.global_position = right_beam_spawn.global_position
		
		# Configurar los beams
		if left_beam.has_method("setup"):
			left_beam.setup(-1, beam_damage)
		if right_beam.has_method("setup"):
			right_beam.setup(1, beam_damage)
		
		print("Beams creados - Izquierda: ", left_beam_spawn.global_position, " Derecha: ", right_beam_spawn.global_position)
	else:
		print("ERROR: No se asignó beam_scene")

func create_vertical_beams():
	print("CREANDO BEAMS VERTICALES EN POSICIONES FIJAS")
	if vertical_beam_scene:
		# Limpiar beams anteriores
		cleanup_vertical_beams()
		
		# Crear beams en las posiciones fijas
		for position in fixed_beam_positions:
			var vertical_beam = vertical_beam_scene.instantiate()
			get_parent().add_child(vertical_beam)
			vertical_beam.global_position = position
			
			# Configurar el beam
			if vertical_beam.has_method("setup"):
				vertical_beam.setup(vertical_beam_damage)
			
			# Añadir al array de control
			vertical_beams.append(vertical_beam)
			
			print("Beam vertical estático creado en posición fija: ", position)
		
		print("Total beams verticales creados: ", vertical_beams.size())
	else:
		print("ERROR: No se asignó vertical_beam_scene")

func cleanup_beams():
	if left_beam and is_instance_valid(left_beam):
		left_beam.queue_free()
		left_beam = null
	if right_beam and is_instance_valid(right_beam):
		right_beam.queue_free()
		right_beam = null

func cleanup_vertical_beams():
	# Limpiar todos los beams del array
	for beam in vertical_beams:
		if beam and is_instance_valid(beam):
			beam.queue_free()
	
	# Limpiar el array
	vertical_beams.clear()

func cleanup_all_attacks():
	cleanup_beams()
	cleanup_vertical_beams()
	
	if current_henki_dama and is_instance_valid(current_henki_dama):
		current_henki_dama.queue_free()
		current_henki_dama = null

func start_attack():
	print("LANZANDO HENKIDAMA HACIA EL JUGADOR")
	look_at_player()
	sprite.play("henki_finish_frame")
	
	if current_henki_dama and is_instance_valid(current_henki_dama):
		print("Henkidama encontrada, lanzando...")
		
		if current_henki_dama.has_method("launch"):
			var target_pos = player.global_position if player else Vector2(global_position.x + 100, global_position.y)
			var direction = (target_pos - current_henki_dama.global_position).normalized()
			print("Dirección de lanzamiento: ", direction)
			current_henki_dama.launch(direction, henki_dama_speed, henki_dama_damage)
		elif current_henki_dama.has_method("setup"):
			var target_pos = player.global_position if player else Vector2(global_position.x + 100, global_position.y)
			var direction = (target_pos - current_henki_dama.global_position).normalized()
			print("Dirección de lanzamiento: ", direction)
			current_henki_dama.setup(direction, henki_dama_speed, henki_dama_damage)
		else:
			print("ERROR: La henkidama no tiene métodos launch ni setup")
		
		current_henki_dama = null
	else:
		print("ERROR: No hay henkidama para lanzar")

func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("hitbox_player"):
		var jugador = area.get_parent()
		if jugador.has_method("get_attack_damage"):
			var damage_received = jugador.get_attack_damage()
			take_damage(damage_received, jugador.global_position)

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO):
	print("BOSS RECIBIÓ DAÑO: ", amount)
	current_health -= amount
	current_health = max(current_health, 0)
	
	if health_bar:
		health_bar.value = current_health
	
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		die()
		return

	# NO interrumpir estos estados (ataques importantes)
	if current_state in [State.ATTACK_PREP, State.HENKI_CHARGE, State.ATTACKING, State.BEAM_CHARGE, State.BEAM_ACTIVE, State.VERTICAL_BEAM_CHARGE, State.VERTICAL_BEAM_ACTIVE]:
		print("Ataque en progreso - ignorando stun")
		return

	# Si ya está stuneado, no aplicar otro stun
	if current_state == State.STUNNED:
		print("Ya está stuneado - ignorando stun adicional")
		return

	# NO stun por golpes débiles
	if amount < 15:
		print("Daño muy bajo - ignorando stun")
		return

	# Stun SOLO si golpe fuerte
	if attacker_position != Vector2.ZERO:
		apply_knockback(attacker_position)
	
	is_stunned = true
	previous_state = current_state
	transition_to_state(State.STUNNED)

func die():
	print("BOSS DERROTADO - EJECUTANDO die()")
	hurtboxFlying.monitoring = false
	hurtboxIdle.monitoring = false
	
	cleanup_all_attacks()
	
	if sprite.sprite_frames.has_animation("die"):
		sprite.play("die")
	else:
		sprite.play("hurt")
	
	emit_signal("enemy_defeated")
	set_physics_process(false)
	
	await sprite.animation_finished
	await get_tree().create_timer(0.5).timeout
	queue_free()

func apply_knockback(attacker_position: Vector2):
	print("APLICANDO KNOCKBACK SUAVE al boss")
	
	if sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")

	await get_tree().create_timer(knockback_delay).timeout

	var knockback_direction = (global_position - attacker_position).normalized()
	velocity.x = knockback_direction.x * knockback_force * 0.7
	velocity.y = -knockback_up_force * 0.1
	move_and_slide()
