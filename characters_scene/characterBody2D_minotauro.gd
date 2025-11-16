extends CharacterBody2D

# --- MOVEMENT PROPERTIES ---
@export var speed: float = 200
@export var attack_range: float = 250
@export var min_distance: float = 100
@export var optimal_distance: float = 250
@export var min_throw_range: float = 250  # Distancia MÍNIMA para lanzar
@export var throw_range: float = 1000      # Distancia MÁXIMA para lanzar
# --- COMBAT PROPERTIES ---
@export var attack_duration: float = 0.3
@export var damage: int = 10
@export var attack_cooldown: float = 2.4
@export var throw_cooldown: float = 3.0
@export var throw_damage: int = 15
# --- HEALTH PROPERTIES ---
@export var health: int = 450
var max_health: int
@export var block_break_damage: int = 5  # Daño que atraviesa el bloqueo
@export var block_stun_duration: float = 0.8  # Tiempo que aturde al jugador al romper bloqueo
# --- PHYSICS PROPERTIES ---
@export var gravity: float = 3000

# --- KNOCKBACK PROPERTIES ---
@export var knockback_force: float = 180
@export var knockback_up_force: float = 180
@export var stun_duration: float = 0.3
@export var knockback_delay: float = 0.1
@export var bounce_effect: float = 0.3

# --- NODES ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area_ataque: Area2D = $Area2D_ataque
@onready var area_dano: Area2D = $Area2D_dano
@onready var throw_point: Node2D = $ThrowPoint
@onready var punchSound: AudioStreamPlayer2D = $punchSound
@onready var throwAxe: AudioStreamPlayer2D = $throwAxe
# --- SCENES ---
@export var axe_scene: PackedScene


# --- VARIABLES ---
var player: CharacterBody2D
var is_attacking: bool = false
var is_throwing: bool = false
var has_hit: bool = false
var can_attack: bool = true
var can_throw: bool = true
var is_stunned: bool = false
var health_bar: ProgressBar = null
var wall_detector: RayCast2D
var wall_detector_retreat: RayCast2D

# --- STATE MACHINE ---
enum State { IDLE, APPROACH, RETREAT, ATTACK, THROW, STUNNED }
var current_state: State = State.IDLE
var state_timer: float = 0.0
var decision_cooldown: float = 0.0
var retreat_timer: float = 0.0
var last_decision_reason: String = ""

# --- NUEVA VARIABLE PARA CONTROLAR REPETICIÓN DE RETROCESO ---
var consecutive_retreats: int = 0

# --- SIGNALS ---
signal enemy_defeated
signal health_changed(new_health: int, max_health: int)

# ===============================
# READY
# ===============================
func _ready():
	max_health = health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

	# Configurar áreas
	area_ataque.monitoring = false
	area_ataque.add_to_group("hitbox_enemy")
	area_ataque.connect("area_entered", Callable(self, "_on_area_ataque_entered"))

	area_dano.add_to_group("hurtbox_enemy")
	area_dano.connect("area_entered", Callable(self, "_on_area_dano_entered"))
	sprite.play("idle")
	# Crear detectores de paredes
	setup_wall_detectors()

func setup_wall_detectors():
	# Detector para movimiento normal
	wall_detector = RayCast2D.new()
	wall_detector.enabled = true
	wall_detector.collision_mask = 1
	wall_detector.collide_with_areas = false
	wall_detector.collide_with_bodies = true
	add_child(wall_detector)
	
	# Detector para retroceso (en dirección opuesta)
	wall_detector_retreat = RayCast2D.new()
	wall_detector_retreat.enabled = true
	wall_detector_retreat.collision_mask = 1
	wall_detector_retreat.collide_with_areas = false
	wall_detector_retreat.collide_with_bodies = true
	add_child(wall_detector_retreat)

# ===============================
# PHYSICS
# ===============================
func _physics_process(delta):
	if player == null:
		find_player()
		return

	if is_stunned:
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	# Actualizar timers
	state_timer -= delta
	decision_cooldown -= delta
	retreat_timer -= delta

	# Actualizar detectores de paredes
	update_wall_detectors()

	# Tomar decisiones cada cierto tiempo
	if decision_cooldown <= 0:
		make_decision()
		decision_cooldown = 0.5

	# Ejecutar estado actual
	execute_state(delta)

	if not is_on_floor():
		velocity.y += gravity * delta

	move_and_slide()

func update_wall_detectors():
	if wall_detector:
		var dir_to_player = player.position - position if player else Vector2.RIGHT
		var player_direction = sign(dir_to_player.x)
		wall_detector.target_position = Vector2(player_direction * 50, -20)
		wall_detector.force_raycast_update()
	
	if wall_detector_retreat:
		var dir_to_player = player.position - position if player else Vector2.RIGHT
		var player_direction = sign(dir_to_player.x)
		wall_detector_retreat.target_position = Vector2(-player_direction * 50, -20)
		wall_detector_retreat.force_raycast_update()

# ===============================
# FIND PLAYER
# ===============================
func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

# ===============================
# DECISION MAKING - SIMPLIFICADO
# ===============================
func make_decision():
	# NO tomar decisiones si está en medio de una animación importante
	if is_attacking or is_throwing or is_stunned:
		return

	var dir_to_player = player.position - position
	var distance = dir_to_player.length()
	var player_direction = sign(dir_to_player.x)

	# Sprite Direction
	if player_direction != 0:
		sprite.flip_h = player_direction < 0
		throw_point.position.x = abs(throw_point.position.x) * player_direction

	# Detectar si hay pared cerca
	var wall_near = wall_detector.is_colliding() if wall_detector else false
	var wall_behind = wall_detector_retreat.is_colliding() if wall_detector_retreat else false

	# NUEVA LÓGICA: Si hay demasiados retrocesos consecutivos, forzar ataque
	if consecutive_retreats >= 3 and can_attack:
		print("DEMASIADOS RETROCESOS - ATAQUE FORZADO CON KNOCKBACK")
		current_state = State.ATTACK
		state_timer = attack_duration + 0.2
		consecutive_retreats = 0
		return

	# Detectar si el jugador está bloqueando
	var player_blocking = player.is_blocking if player else false

	var random_choice = randf()
	
	# PRIORIDAD 1: Si está en rango de ataque cuerpo a cuerpo, atacar
	if can_attack and distance <= attack_range and distance >= min_distance:
		print("DECISIÓN: En rango de ataque cuerpo a cuerpo - ATACAR")
		current_state = State.ATTACK
		state_timer = attack_duration + 0.2
		consecutive_retreats = 0
	
	# PRIORIDAD 2: Si está demasiado cerca, retroceder o atacar
	elif distance < min_distance:
		if not wall_behind and random_choice < 0.7:
			print("DECISIÓN: Demasiado cerca, retrocediendo")
			current_state = State.RETREAT
			state_timer = 1.0
			consecutive_retreats += 1
		else:
			print("DECISIÓN: Demasiado cerca - ATAQUE INMEDIATO")
			current_state = State.ATTACK
			state_timer = attack_duration + 0.2
			consecutive_retreats = 0
	
	# PRIORIDAD 3: En rango de lanzamiento
	elif can_throw and distance >= min_throw_range and distance <= throw_range and random_choice < 0.4:
		print("DECISIÓN: En rango de lanzamiento - LANZAR")
		current_state = State.THROW
		state_timer = 2.0
		consecutive_retreats = 0
	
	# PRIORIDAD 4: Acercarse por defecto
	else:
		print("DECISIÓN: Acercándose al jugador")
		current_state = State.APPROACH
		state_timer = 1.0
		consecutive_retreats = 0

# ===============================
# STATE EXECUTION
# ===============================
func execute_state(delta):
	# Si estamos en medio de un ataque o lanzamiento, no cambiar de estado
	if is_attacking or is_throwing:
		return

	if state_timer <= 0 and current_state not in [State.ATTACK, State.THROW]:
		current_state = State.IDLE

	var dir_to_player = player.position - position
	var player_direction = sign(dir_to_player.x)
	var wall_behind = wall_detector_retreat.is_colliding() if wall_detector_retreat else false

	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, speed * delta)
			if is_on_floor() and not is_attacking and not is_throwing:
				sprite.play("idle")

		State.APPROACH:
			velocity.x = move_toward(velocity.x, player_direction * speed, speed * delta)
			if is_on_floor() and not is_attacking and not is_throwing:
				sprite.play("walk")

		State.RETREAT:
			# Si hay pared detrás, cancelar retroceso
			if wall_behind:
				print("Retroceso cancelado - pared detectada")
				current_state = State.IDLE
				state_timer = 0.5
			else:
				velocity.x = move_toward(velocity.x, -player_direction * speed * 1.2, speed * delta)
				if is_on_floor() and not is_attacking and not is_throwing:
					sprite.play("walk")

		State.ATTACK:
			if not is_attacking and can_attack:
				start_attack()
			else:
				velocity.x = 0

		State.THROW:
			if not is_throwing and can_throw:
				start_throw()
			else:
				velocity.x = 0

		State.STUNNED:
			pass

# ===============================
# ATAQUE CUERPO A CUERPO - CON KNOCKBACK MEJORADO
# ===============================
func start_attack():
	punchSound.play()
	is_attacking = true
	has_hit = false
	can_attack = false

	# ATAQUE CON KNOCKBACK MEJORADO SI HABÍA MUCHOS RETROCESOS
	var knockback_multiplier = 1.5 if consecutive_retreats >= 2 else 1.0
	
	# Detectar si hay pared cerca
	var wall_near = wall_detector.is_colliding() if wall_detector else false
	var is_block_breaker = false

	# Determinar si es un ataque rompe-bloqueo
	if player and player.is_blocking:
		if wall_near and randf() < 0.9:  # 90% si hay pared
			is_block_breaker = true
			damage = block_break_damage
			print("¡Ataque rompe-bloqueo por proximidad a pared!")
		elif randf() < 0.3:  # 30% base
			is_block_breaker = true
			damage = block_break_damage

	sprite.play("attack")
	area_ataque.monitoring = true

	var attack_momentum = 80.0 * knockback_multiplier
	var player_direction = sign((player.position - position).x)
	velocity.x = attack_momentum * player_direction

	# Esperar a que termine la animación de ataque
	await get_tree().create_timer(attack_duration).timeout
	
	# Limpiar después del ataque
	velocity.x = 0
	area_ataque.monitoring = false
	is_attacking = false

	# Cooldown en segundo plano
	start_attack_cooldown()

func start_attack_cooldown():
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# ===============================
# LANZAMIENTO DE HACHA
# ===============================
func start_throw():
	throwAxe.play()
	is_throwing = true
	can_throw = false
	
	velocity.x = 0
	sprite.play("throw")
	
	# Esperar al momento adecuado de la animación
	await get_tree().create_timer(0.3).timeout
	
	# Lanzar el hacha
	throw_axe()
	
	# Esperar a que termine la animación completa
	await get_tree().create_timer(0.7).timeout
	is_throwing = false
	
	# Cooldown en segundo plano
	start_throw_cooldown()

func start_throw_cooldown():
	await get_tree().create_timer(throw_cooldown).timeout
	can_throw = true

func throw_axe():
	if not axe_scene or not player:
		return
	
	var axe = axe_scene.instantiate()
	get_parent().add_child(axe)
	
	# Posicionar el hacha en el punto de lanzamiento
	axe.global_position = throw_point.global_position
	
	# Calcular dirección hacia el jugador
	var throw_direction = (player.global_position - throw_point.global_position).normalized()
	
	# Configurar el hacha
	if axe.has_method("setup"):
		axe.setup(throw_direction, throw_damage)

# ===============================
# DETECCIÓN DE ATAQUE
# ===============================
func _on_area_ataque_entered(area: Area2D):
	if has_hit:
		return
	if area.is_in_group("hurtbox_player"):
		var jugador = area.get_parent()
		if jugador.has_method("take_damage"):
			# Detectar si está cerca de una pared para aumentar probabilidad de rompe-bloqueo
			var wall_near = wall_detector.is_colliding() if wall_detector else false
			var is_block_breaker = false
			var block_breaker_probability = 0.3  # Probabilidad base

			# Si está cerca de una pared, aumentar probabilidad a 90%
			if wall_near and jugador.is_blocking:
				block_breaker_probability = 0.9
				print("¡Cerca de pared en impacto! Probabilidad de rompe-bloqueo aumentada al 90%")

			# Verificar si el jugador está bloqueando para determinar el tipo de ataque
			if jugador.is_blocking and randf() < block_breaker_probability:
				is_block_breaker = true

			jugador.take_damage(damage, global_position, is_block_breaker)
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
# RECIBIR DAÑO
# ===============================
func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO):
	health -= amount
	health = max(health, 0)
	sprite.play("hurt")
	if health_bar:
		health_bar.value = health

	emit_signal("health_changed", health, max_health)

	if attacker_position != Vector2.ZERO:
		apply_knockback(attacker_position)

	if health <= 0:
		emit_signal("enemy_defeated")
		queue_free()

# ===============================
# KNOCKBACK
# ===============================
func apply_knockback(attacker_position: Vector2):
	current_state = State.STUNNED
	is_stunned = true
	
	if sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")

	await get_tree().create_timer(knockback_delay).timeout

	var knockback_direction = (global_position - attacker_position).normalized()
	velocity.x = knockback_direction.x * knockback_force
	velocity.y = -knockback_up_force

	move_and_slide()

	await get_tree().create_timer(stun_duration).timeout
	is_stunned = false
	current_state = State.IDLE
	
	if is_on_floor():
		sprite.play("idle")

# Añade esta función en el script del minotauro (después de la función apply_knockback)
func apply_hadouken_knockback(attack_position: Vector2, force: float, up_force: float, stun_time: float):
	current_state = State.STUNNED
	is_stunned = true
	
	if sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")

	await get_tree().create_timer(knockback_delay).timeout

	var knockback_direction = (global_position - attack_position).normalized()
	velocity.x = knockback_direction.x * force
	velocity.y = -up_force

	move_and_slide()

	await get_tree().create_timer(stun_time).timeout
	is_stunned = false
	current_state = State.IDLE
	
	if is_on_floor():
		sprite.play("idle")
