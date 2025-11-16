extends CharacterBody2D

# --- MOVEMENT PROPERTIES ---
@export var speed: float = 180
@export var attack_range: float = 250
@export var min_distance: float = 60

# --- COMBAT PROPERTIES ---
@export var attack_duration: float = 1
@export var damage: int = 8
@export var attack_cooldown: float = 3.0
@export var block_break_damage: int = 6
@export var block_stun_duration: float = 1.0
@export var block_break_knockback_force: float = 100
@export var block_break_knockback_up_force: float = 250

# --- PROJECTILE PROPERTIES ---
@export var throw_cooldown: float = 4.0
@export var throw_damage: int = 10
@export var min_throw_range: float = 200
@export var max_throw_range: float = 600
@export var projectile_speed: float = 600.0
@export var fly_horizontal_offset: float = 300.0  # DESPLAZAMIENTO HORIZONTAL desde el jugador

# --- FLYING ATTACK PROPERTIES ---
@export var fly_probability: float = 1
@export var fly_fixed_height: float = -500.0  # Altura fija de vuelo
@export var fly_duration: float = 5.0
@export var missile_interval: float = 0.8
@export var MisilAereoScene: PackedScene
@export var landing_cooldown: float = 2.0  # Tiempo de espera después de aterrizar
@export var post_missile_delay: float = 3.0  # Tiempo extra después del último misil antes de aterrizar

# --- HEALTH PROPERTIES ---
@export var health: int = 450
var max_health: int

# --- PHYSICS PROPERTIES ---
@export var gravity: float = 3000

# --- KNOCKBACK PROPERTIES ---
# AUMENTAR LA FUERZA DE KNOCKBACK PARA QUE SEA SIMILAR AL MINOTAURO
@export var knockback_force: float = 200  # Aumentado de 180 a 600
@export var knockback_up_force: float = 400  # Aumentado de 180 a 400
@export var stun_duration: float = 0.4
@export var knockback_delay: float = 0.1

# --- NODES ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_ataque: Area2D = $ataqueMagico
@onready var area_dano: Area2D = $HurtboxStanding
@onready var throw_point: Node2D = $ThrowPoint
@onready var wall_detector: RayCast2D

# --- SCENES ---
@export var poder_mago_scene: PackedScene

# --- VARIABLES ---
var player: CharacterBody2D
var is_attacking: bool = false
var is_throwing: bool = false
var has_hit: bool = false
var can_attack: bool = true
var can_throw: bool = true
var is_stunned: bool = false
var health_bar: ProgressBar = null
var current_attack_is_block_breaker: bool = false

# --- FLYING ATTACK VARIABLES ---
var is_flying: bool = false
var fly_timer: float = 0.0
var missile_timer: float = 0.0
var original_collision_mask: int = 0
var original_collision_layer: int = 0
var fly_cooldown_timer: float = 0.0
var fly_cooldown_duration: float = 15.0
var is_landing: bool = false
var original_gravity: float = 0.0
var waiting_for_missiles: bool = false  # Nuevo estado: esperando que caigan misiles
var post_missile_timer: float = 0.0     # Timer para el delay post-misiles

# --- STATE MACHINE ---
enum State { IDLE, APPROACH, RETREAT, ATTACK, THROW, STUNNED, FLY, LANDING, WAITING_FOR_MISSILES }
var current_state: State = State.IDLE
var state_timer: float = 0.0
var decision_cooldown: float = 0.0

# --- SIGNALS ---
signal enemy_defeated
signal health_changed(new_health: int, max_health: int)

# ===============================
# READY
# ===============================
func _ready():
	max_health = health
	original_gravity = gravity
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

	# Configurar áreas
	area_ataque.monitoring = false
	area_ataque.add_to_group("hitbox_enemy")
	area_ataque.connect("area_entered", Callable(self, "_on_area_ataque_entered"))

	area_dano.add_to_group("hurtbox_enemy")
	area_dano.connect("area_entered", Callable(self, "_on_area_dano_entered"))
	
	# Crear detectores de paredes
	setup_wall_detector()
	
	# Crear punto de lanzamiento si no existe
	if not has_node("ThrowPoint"):
		throw_point = Node2D.new()
		throw_point.name = "ThrowPoint"
		throw_point.position = Vector2(40, -20)
		add_child(throw_point)
	
	sprite.play("idle")

func setup_wall_detector():
	wall_detector = RayCast2D.new()
	wall_detector.enabled = true
	wall_detector.collision_mask = 1
	wall_detector.collide_with_areas = false
	wall_detector.collide_with_bodies = true
	wall_detector.target_position = Vector2(50, 0)
	add_child(wall_detector)

# ===============================
# PHYSICS
# ===============================
func _physics_process(delta):
	if player == null:
		find_player()
		return

	# Actualizar cooldown del vuelo
	if fly_cooldown_timer > 0:
		fly_cooldown_timer -= delta

	if is_stunned:
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	# Actualizar detector de paredes
	update_wall_detector()

	# Si está volando, aterrizando o esperando misiles
	if is_flying or is_landing or waiting_for_missiles:
		update_fly_attack(delta)
		move_and_slide()
		return

	# Actualizar timers
	state_timer -= delta
	decision_cooldown -= delta

	# Tomar decisiones cada cierto tiempo
	if decision_cooldown <= 0 and not is_attacking and not is_throwing and not is_landing:
		make_decision()
		decision_cooldown = 0.3

	# Ejecutar estado actual
	if not is_attacking and not is_throwing and not is_landing:
		execute_state(delta)

	if not is_on_floor() and not is_flying and not is_landing and not waiting_for_missiles:
		velocity.y += gravity * delta

	move_and_slide()

func update_wall_detector():
	if wall_detector and player:
		var dir_to_player = player.position - position
		var player_direction = sign(dir_to_player.x)
		wall_detector.target_position = Vector2(player_direction * 50, 0)
		wall_detector.force_raycast_update()
		
		if throw_point:
			throw_point.position.x = abs(throw_point.position.x) * player_direction

# ===============================
# FIND PLAYER
# ===============================
func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

# ===============================
# DECISION MAKING - MEJORADA
# ===============================
func make_decision():
	if is_attacking or is_stunned or is_throwing or is_flying or is_landing or waiting_for_missiles:
		return

	var dir_to_player = player.position - position
	var distance = dir_to_player.length()
	var player_direction = sign(dir_to_player.x)

	# Sprite Direction
	if player_direction != 0:
		sprite.flip_h = player_direction < 0

	# Detección de paredes
	var wall_near = false
	if wall_detector and wall_detector.is_colliding():
		var collider = wall_detector.get_collider()
		if collider and (collider is StaticBody2D or collider.is_in_group("terrain")):
			wall_near = true

	# DECISIÓN DE ATAQUE ESPECIAL (VOLAR)
	if (randf() < fly_probability and not is_flying and can_attack and is_on_floor() 
		and fly_cooldown_timer <= 0):
		print("MAGO: ¡ACTIVANDO ATAQUE ESPECIAL - VOLANDO!")
		start_fly_attack()
		return

	# LÓGICA MEJORADA - CON ATAQUE ROMPE-BLOQUEO Y PROYECTILES
	if distance < min_distance:
		print("MAGO: Demasiado cerca, retrocediendo - Distancia: ", distance)
		current_state = State.RETREAT
		state_timer = 0.8
	elif can_attack and distance <= attack_range:
		if player and player.is_blocking:
			var block_breaker_probability = 0.3
			if wall_near:
				block_breaker_probability = 0.9

			if randf() < block_breaker_probability:
				print("MAGO: ¡ATAQUE ROMPE-BLOQUEO! - Jugador bloqueando")
				current_state = State.ATTACK
				current_attack_is_block_breaker = true
			else:
				print("MAGO: Ataque normal contra bloqueo")
				current_state = State.ATTACK
				current_attack_is_block_breaker = false
		else:
			print("MAGO: Ataque normal - Distancia: ", distance)
			current_state = State.ATTACK
			current_attack_is_block_breaker = false
		state_timer = attack_duration + 0.5
	elif can_throw and distance >= min_throw_range and distance <= max_throw_range:
		print("MAGO: En rango de lanzamiento - Lanzando proyectiles")
		current_state = State.THROW
		state_timer = 1.5
	elif distance > max_throw_range:
		print("MAGO: Demasiado lejos, acercándose")
		current_state = State.APPROACH
		state_timer = 1.0
	else:
		print("MAGO: Manteniendo posición - Distancia: ", distance)
		current_state = State.IDLE
		state_timer = 0.5

# ===============================
# STATE EXECUTION
# ===============================
func execute_state(delta):
	if state_timer <= 0 and current_state not in [State.ATTACK, State.THROW, State.FLY, State.LANDING, State.WAITING_FOR_MISSILES]:
		current_state = State.IDLE

	var dir_to_player = player.position - position
	var player_direction = sign(dir_to_player.x)

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed * delta)
			if is_on_floor() and not is_attacking and not is_throwing and not is_landing and not waiting_for_missiles:
				sprite.play("idle")

		State.APPROACH:
			velocity.x = player_direction * speed
			if is_on_floor() and not is_attacking and not is_throwing and not is_landing and not waiting_for_missiles:
				sprite.play("walk")

		State.RETREAT:
			velocity.x = -player_direction * speed * 0.8
			if is_on_floor() and not is_attacking and not is_throwing and not is_landing and not waiting_for_missiles:
				sprite.play("walk")

		State.ATTACK:
			if not is_attacking and can_attack and not is_landing and not waiting_for_missiles:
				start_attack()
			else:
				velocity.x = 0

		State.THROW:
			if not is_throwing and can_throw and not is_landing and not waiting_for_missiles:
				start_throw()
			else:
				velocity.x = 0

		State.STUNNED:
			pass

		State.FLY:
			pass

		State.LANDING:
			pass

		State.WAITING_FOR_MISSILES:
			pass

# ===============================
# ATAQUE VOLADOR - MEJORADO
# ===============================
func start_fly_attack():
	is_flying = true
	current_state = State.FLY
	fly_timer = fly_duration
	missile_timer = 0.0
	waiting_for_missiles = false
	
	# Iniciar cooldown para evitar vuelos seguidos
	fly_cooldown_timer = fly_cooldown_duration
	
	# Guardar configuraciones originales
	original_collision_mask = collision_mask
	original_collision_layer = collision_layer
	
	# Desactivar colisiones con el suelo y gravedad
	collision_mask = collision_mask & ~(1 << 0)
	collision_layer = collision_layer & ~(1 << 0)
	gravity = 0
	velocity.y = 0
	
	# CALCULAR POSICIÓN DE VUELO CON DESPLAZAMIENTO LATERAL
	var player_direction = sign((player.position - position).x)
	var random_side = 1 if randf() > 0.5 else -1  # Lado aleatorio (izquierda o derecha)
	
	# Posicionar al mago a la altura de vuelo pero DESPLAZADO HORIZONTALMENTE del jugador
	var target_x = player.position.x + (fly_horizontal_offset * random_side)
	var target_y = fly_fixed_height
	
	# Asegurar que no se salga demasiado de los límites de la pantalla
	var camera = get_viewport().get_camera_2d()
	if camera:
		var camera_center = camera.global_position
		var screen_size = get_viewport_rect().size
		var left_limit = camera_center.x - screen_size.x / 2 + 100
		var right_limit = camera_center.x + screen_size.x / 2 - 100
		
		target_x = clamp(target_x, left_limit, right_limit)
	
	# Teletransportar al mago a la nueva posición
	position = Vector2(target_x, target_y)
	
	# Animación de vuelo
	if sprite.sprite_frames.has_animation("fly"):
		sprite.play("fly")
	else:
		sprite.play("idle")
	
	print("MAGO: Iniciando ataque volador - Posición: ", position, " - Lado: ", "derecha" if random_side > 0 else "izquierda")
	
	# Lanzar primer misil inmediatamente
	launch_aerial_missile()

# En update_fly_attack(), mantener la posición fija pero ajustada:
func update_fly_attack(delta):
	if is_flying:
		# Actualizar timers
		fly_timer -= delta
		missile_timer -= delta
		
		# MANTENER POSICIÓN FIJA (no seguir al jugador)
		velocity.x = 0
		velocity.y = 0
		
		# Lanzar misiles en intervalos
		if missile_timer <= 0:
			launch_aerial_missile()
			missile_timer = missile_interval
		
		# Terminar la fase de lanzamiento y esperar que caigan misiles
		if fly_timer <= 0 and not waiting_for_missiles:
			start_waiting_for_missiles()
	
	elif waiting_for_missiles:
		# Esperar que los misiles caigan antes de aterrizar
		post_missile_timer -= delta
		
		# Mantener posición fija en el aire
		velocity.x = 0
		velocity.y = 0
		
		# Cuando termine el tiempo de espera, iniciar aterrizaje
		if post_missile_timer <= 0:
			start_landing()
	
	elif is_landing:
		# Durante el aterrizaje, aplicar gravedad normal
		velocity.y += original_gravity * delta
		
		# Permitir un pequeño movimiento horizontal durante aterrizaje para aterrizar cerca
		var dir_to_player = (player.position - position).normalized()
		velocity.x = dir_to_player.x * speed * 0.5  # Movimiento más lento
		
		# Verificar si llegó al suelo
		if is_on_floor():
			finish_landing()


	
	elif waiting_for_missiles:
		# Esperar que los misiles caigan antes de aterrizar
		post_missile_timer -= delta
		
		# Mantener posición fija en el aire
		velocity.x = 0
		velocity.y = 0
		position.y = fly_fixed_height
		
		# Cuando termine el tiempo de espera, iniciar aterrizaje
		if post_missile_timer <= 0:
			start_landing()
	
	elif is_landing:
		# Durante el aterrizaje, aplicar gravedad normal
		velocity.y += original_gravity * delta
		
		# No movimiento horizontal durante aterrizaje
		velocity.x = 0
		
		# Verificar si llegó al suelo
		if is_on_floor():
			finish_landing()

func start_waiting_for_missiles():
	is_flying = false
	waiting_for_missiles = true
	current_state = State.WAITING_FOR_MISSILES
	post_missile_timer = post_missile_delay
	
	print("MAGO: Esperando ", post_missile_delay, " segundos para que caigan los misiles")

func start_landing():
	waiting_for_missiles = false
	is_landing = true
	current_state = State.LANDING
	
	# Restaurar colisiones y gravedad
	collision_mask = original_collision_mask
	collision_layer = original_collision_layer
	gravity = original_gravity
	
	print("MAGO: Iniciando aterrizaje - Cayendo naturalmente")

func finish_landing():
	is_landing = false
	current_state = State.IDLE
	
	print("MAGO: Aterrizó, iniciando cooldown")
	
	# Animación de idle
	if is_on_floor():
		sprite.play("idle")
	
	# Iniciar cooldown de aterrizaje
	start_landing_cooldown()

func start_landing_cooldown():
	# Esperar el tiempo de cooldown antes de poder atacar de nuevo
	await get_tree().create_timer(landing_cooldown).timeout
	
	print("MAGO: Cooldown de aterrizaje terminado, puede atacar de nuevo")

@export var manual_camera_center: Vector2 = Vector2(1100, 0)
@export var manual_camera_width: float = 2000.0

func launch_aerial_missile():
	if not MisilAereoScene:
		return

	# Usar configuración manual
	var screen_left = manual_camera_center.x - manual_camera_width / 2
	var screen_right = manual_camera_center.x + manual_camera_width / 2
	var screen_width = manual_camera_width

	# REDUCIR LA CANTIDAD DE MISILES Y AUMENTAR LA SEPARACIÓN
	var missile_count = 3  # Mantener 2 misiles pero mejor distribuidos
	var segment_width = screen_width / missile_count

	for i in range(missile_count):
		if not is_flying and not waiting_for_missiles:
			return

		# Calcular posición X con MUCHA MÁS SEPARACIÓN
		var spawn_x = screen_left + segment_width * i + segment_width / 2

		# AUMENTAR SIGNIFICATIVAMENTE la aleatoriedad para que caigan más separados
		var random_offset = randf_range(-segment_width * 0.3, segment_width * 0.3)
		spawn_x += random_offset

		# Asegurar que está dentro de los límites con más margen
		spawn_x = clamp(spawn_x, screen_left + 100, screen_right - 100)

		var spawn_position = Vector2(
			spawn_x,
			manual_camera_center.y - 500
		)

		# AUMENTAR EL DELAY ENTRE MISILES para dar tiempo a esquivar
		var delay = randf_range(0.5, 1.2)  # Aumentado el rango de delay
		await get_tree().create_timer(delay).timeout

		if not is_flying and not waiting_for_missiles:
			return

		var missile = MisilAereoScene.instantiate()
		get_parent().add_child(missile)
		missile.global_position = spawn_position
		missile.direction = Vector2.DOWN

		print("MAGO: Misil ", i + 1, " de ", missile_count, " en X:", spawn_x)

# ===============================
# ATAQUE CUERPO A CUERPO
# ===============================
func start_attack():
	print("MAGO: INICIANDO ATAQUE - Tipo: ", "ROMPE-BLOQUEO" if current_attack_is_block_breaker else "NORMAL")
	is_attacking = true
	has_hit = false
	can_attack = false

	velocity.x = 0
	sprite.play("attack")
	
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	area_ataque.monitoring = true

	var player_direction = sign((player.position - position).x)
	velocity.x = 40.0 * player_direction

	var backup_timer = get_tree().create_timer(attack_duration)
	await backup_timer.timeout
	
	velocity.x = 0
	area_ataque.monitoring = false
	is_attacking = false
	current_state = State.IDLE

	if is_on_floor():
		sprite.play("idle")
	print("MAGO: Ataque completado")

	start_attack_cooldown()

func start_attack_cooldown():
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	print("MAGO: Cooldown terminado, puede atacar de nuevo")

# ===============================
# LANZAMIENTO DE PROYECTILES
# ===============================
func start_throw():
	print("MAGO: INICIANDO LANZAMIENTO DE PROYECTILES")
	is_throwing = true
	can_throw = false
	velocity.x = 0
	sprite.play("throw")
	
	await get_tree().create_timer(0.3).timeout
	throw_single_projectile()  # Cambiado a lanzamiento simple
	await get_tree().create_timer(0.7).timeout
	is_throwing = false
	current_state = State.IDLE
	
	if is_on_floor():
		sprite.play("idle")
	print("MAGO: Lanzamiento completado")

	start_throw_cooldown()

func throw_single_projectile():
	if not poder_mago_scene or not player:
		return
	
	var projectile = poder_mago_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = throw_point.global_position
	
	# Dirección directa al jugador sin ángulos
	var throw_direction = (player.global_position - throw_point.global_position).normalized()
	projectile.direction = throw_direction
	
	if "speed" in projectile:
		projectile.speed = projectile_speed
	
	print("MAGO: Proyectil lanzado directamente hacia el jugador")

func start_throw_cooldown():
	await get_tree().create_timer(throw_cooldown).timeout
	can_throw = true
	print("MAGO: Cooldown de lanzamiento terminado")

# ===============================
# DETECCIÓN DE ATAQUE
# ===============================
func _on_area_ataque_entered(area: Area2D):
	if has_hit:
		return
	if area.is_in_group("hurtbox_player"):
		var jugador = area.get_parent()
		if jugador.has_method("take_damage"):
			print("MAGO: ¡GOLPE EXITOSO! - Tipo: ", "ROMPE-BLOQUEO" if current_attack_is_block_breaker else "NORMAL")
			
			if current_attack_is_block_breaker:
				jugador.take_damage(block_break_damage, global_position, true)
			else:
				jugador.take_damage(damage, global_position)
			
			has_hit = true

# ===============================
# DETECCIÓN DE DAÑO
# ===============================
func _on_area_dano_entered(area: Area2D):
	if area.is_in_group("hitbox_player"):
		var jugador = area.get_parent()
		if jugador.has_method("get_attack_damage"):
			var damage_received = jugador.get_attack_damage()
			take_damage(damage_received, jugador.global_position)

# ===============================
# RECIBIR DAÑO - CORREGIDO PARA APLICAR KNOCKBACK CONSISTENTE
# ===============================
func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO):
	if is_flying or is_landing or waiting_for_missiles:
		print("MAGO: Invulnerable durante ataque volador o aterrizaje")
		return
		
	if is_attacking or is_throwing:
		# PERMITIR DAÑO PERO INTERRUMPIR EL ATAQUE
		is_attacking = false
		is_throwing = false
		area_ataque.monitoring = false
		
	health -= amount
	health = max(health, 0)
	
	if sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
	
	if health_bar:
		health_bar.value = health

	emit_signal("health_changed", health, max_health)

	# SIEMPRE APLICAR KNOCKBACK CUANDO SE RECIBA DAÑO
	if attacker_position != Vector2.ZERO:
		apply_knockback(attacker_position)

	if health <= 0:
		sprite.play("die")
		emit_signal("enemy_defeated")
		queue_free()

func die():
	if sprite.sprite_frames.has_animation("die"):
		sprite.play("die")
		await sprite.animation_finished
	emit_signal("enemy_defeated")
	queue_free()

# ===============================
# KNOCKBACK - MEJORADO
# ===============================
func apply_knockback(attacker_position: Vector2):
	# INTERRUMPIR CUALQUIER ATAQUE EN CURSO
	if is_attacking or is_throwing:
		is_attacking = false
		is_throwing = false
		area_ataque.monitoring = false
	
	current_state = State.STUNNED
	is_stunned = true
	
	if sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")

	await get_tree().create_timer(knockback_delay).timeout

	# CALCULAR DIRECCIÓN DEL KNOCKBACK
	var knockback_direction = (global_position - attacker_position).normalized()
	
	# APLICAR FUERZA DE KNOCKBACK (AUMENTADA)
	velocity.x = knockback_direction.x * knockback_force
	velocity.y = -knockback_up_force

	# MOVER AL PERSONAJE
	move_and_slide()

	# MANTENER EL STUN POR LA DURACIÓN
	await get_tree().create_timer(stun_duration).timeout
	
	# RESTAURAR ESTADO NORMAL
	is_stunned = false
	current_state = State.IDLE
	
	if is_on_floor():
		sprite.play("idle")

# Función para activar/desactivar la IA
func set_active(active: bool):
	set_physics_process(active)
