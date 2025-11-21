extends CharacterBody2D

# --- MOVEMENT PROPERTIES ---
@export var flight_speed: float = 200
@export var acceleration: float = 15
@export var x_limits: Vector2 = Vector2(150, 1200)
@export var y_limits: Vector2 = Vector2(-50, 200)

# --- COMBAT PROPERTIES ---
@export var attack_duration: float = 0.3
@export var damage: int = 10
@export var health: int = 450
var max_health: int

# --- HENKIDAMA PROPERTIES ---
@export var henki_dama_scene: PackedScene
@export var henki_dama_damage: int = 30
@export var henki_dama_speed: float = 350
@export var henki_charge_duration: float = 3.0  # Duración de la carga

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

# --- VARIABLES ---
var player: CharacterBody2D
var target_position: Vector2
var is_stunned: bool = false
var current_health: int
var health_bar: ProgressBar = null
var gravity: float = 0
var current_henki_dama: Node2D = null  # Para guardar referencia a la henkidama

# --- STATE MACHINE ---
enum State { POSITIONING, ATTACK_PREP, HENKI_CHARGE, ATTACKING, COOLDOWN, STUNNED }
var current_state: State = State.POSITIONING
var previous_state: State = State.POSITIONING   # <--- AGREGA ESTA
var state_timer: float = 0.0

# --- SIGNALS ---
signal enemy_defeated
signal health_changed(new_health: int, max_health: int)

func _ready():
	max_health = health
	current_health = health
	print("BOSS INICIALIZADO - Posición inicial: ", global_position)
	
	# Verificar que el nodo de spawn point existe
	if not henki_spawn_point:
		print("ERROR: No se encontró el nodo HenkiSpawnPoint")
		return
	
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
		State.ATTACK_PREP, State.HENKI_CHARGE, State.COOLDOWN, State.STUNNED:
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
			# --- Volver al estado previo ---
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
	# SOLO limpiar henkidama si estamos en STUNNED o POSITIONING
	# NO limpiar cuando pasamos a COOLDOWN
	if (new_state == State.STUNNED or new_state == State.POSITIONING) and current_henki_dama and is_instance_valid(current_henki_dama):
		print("Limpiando henkidama al cambiar a estado: ", State.keys()[new_state])
		current_henki_dama.queue_free()
		current_henki_dama = null
	
	current_state = new_state
	print("CAMBIO DE ESTADO: ", State.keys()[current_state])
	update_hurtboxes()
	
	match new_state:
		State.POSITIONING:
			state_timer = 1.5
			generate_new_position()
			sprite.play("desplazarseAire")
		State.ATTACK_PREP:
			state_timer = 0.8
			velocity = Vector2.ZERO
			sprite.play("charge")
			look_at_player()
		State.HENKI_CHARGE:
			state_timer = henki_charge_duration  # 3 segundos de carga
			velocity = Vector2.ZERO
			sprite.play("henki_charge")
			sprite.play("henki_finish")
			look_at_player()
			create_henki_dama()  # Crear la pelota inmediatamente
			print("INICIANDO CARGA DE HENKIDAMA")
		State.ATTACKING:
			state_timer = 1.0
			start_attack()
		State.COOLDOWN:
			state_timer = 6.0
			sprite.play("idle")
		State.STUNNED:
			state_timer = stun_duration
			sprite.play("hurt")

func execute_positioning(delta):
	var direction = (target_position - global_position).normalized()
	velocity = velocity.move_toward(direction * flight_speed, acceleration)
	
	if direction.x != 0:
		sprite.flip_h = direction.x < 0
	
	if global_position.distance_to(target_position) < 20 or state_timer <= 0:
		transition_to_state(State.ATTACK_PREP)

func execute_attack_prep(delta):
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2)
	look_at_player()
	
	if state_timer <= 0:
		transition_to_state(State.HENKI_CHARGE)

func execute_henki_charge(delta):
	# Durante la carga, el boss se mantiene quieto mirando al jugador
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2)
	look_at_player()
	
	# Mantener el último frame de la animación de carga
	
	# Actualizar posición de la henkidama para que siga al boss
	if current_henki_dama and is_instance_valid(current_henki_dama):
		current_henki_dama.global_position = henki_spawn_point.global_position
		print("Henkidama en posición: ", current_henki_dama.global_position)
	
	if state_timer <= 0:
		transition_to_state(State.ATTACKING)

func execute_attacking(delta):
	look_at_player()
	
	if state_timer <= 0:
		transition_to_state(State.COOLDOWN)

func execute_cooldown(delta):
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * 2)
	look_at_player()
	
	if state_timer <= 0:
		transition_to_state(State.POSITIONING)

func generate_new_position():
	var random_x = randf_range(x_limits.x, x_limits.y)
	var random_y = randf_range(y_limits.x, y_limits.y)
	target_position = Vector2(random_x, random_y)
	
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
		
		# Posicionar la henkidama en el punto de spawn
		current_henki_dama.global_position = henki_spawn_point.global_position
		print("Henkidama creada en: ", current_henki_dama.global_position)
		
		# Configurar la henkidama en modo carga
		if current_henki_dama.has_method("setup_charge"):
			current_henki_dama.setup_charge()
			print("Henkidama configurada en modo carga")
		else:
			print("ADVERTENCIA: La henkidama no tiene método setup_charge")
	else:
		print("ERROR: No se asignó henki_dama_scene")

func start_attack():
	print("LANZANDO HENKIDAMA HACIA EL JUGADOR")
	look_at_player()
	sprite.play("henki_finish_frame")
	
	# Lanzar la henkidama que estaba cargando DIRECTAMENTE HACIA EL JUGADOR
	if current_henki_dama and is_instance_valid(current_henki_dama):
		print("Henkidama encontrada, lanzando...")
		
		if current_henki_dama.has_method("launch"):
			# Calcular dirección DIRECTAMENTE HACIA EL JUGADOR
			var target_pos = player.global_position if player else Vector2(global_position.x + 100, global_position.y)
			var direction = (target_pos - current_henki_dama.global_position).normalized()
			print("Dirección de lanzamiento: ", direction)
			current_henki_dama.launch(direction, henki_dama_speed, henki_dama_damage)
		elif current_henki_dama.has_method("setup"):
			# Método alternativo - dirección hacia el jugador
			var target_pos = player.global_position if player else Vector2(global_position.x + 100, global_position.y)
			var direction = (target_pos - current_henki_dama.global_position).normalized()
			print("Dirección de lanzamiento: ", direction)
			current_henki_dama.setup(direction, henki_dama_speed, henki_dama_damage)
		else:
			print("ERROR: La henkidama no tiene métodos launch ni setup")
		
		# NO limpiar la referencia aquí - la henkidama se manejará por sí misma
		# Solo quitamos la referencia para que no la sigamos actualizando
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
	if current_state in [State.ATTACK_PREP, State.HENKI_CHARGE, State.ATTACKING]:
		return

	# NO stun por golpes débiles
	if amount < 15:  # cambia según tu daño
		return

	# Stun SOLO si golpe fuerte
	if attacker_position != Vector2.ZERO:
		apply_knockback(attacker_position)
	
	is_stunned = true
	transition_to_state(State.STUNNED)



func die():
	print("BOSS DERROTADO - EJECUTANDO die()")
	hurtboxFlying.monitoring = false
	hurtboxIdle.monitoring = false
	
	# Limpiar henkidama si existe
	if current_henki_dama and is_instance_valid(current_henki_dama):
		current_henki_dama.queue_free()
		current_henki_dama = null
	
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
