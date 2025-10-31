extends CharacterBody2D

# --- MOVEMENT PROPERTIES ---
@export var speed: float = 200
@export var attack_range: float = 250
@export var min_distance: float = 100
@export var optimal_distance: float = 250
@export var min_throw_range: float = 250  # Distancia MÍNIMA para lanzar
@export var throw_range: float = 500      # Distancia MÁXIMA para lanzar
# --- COMBAT PROPERTIES ---
@export var attack_duration: float = 0.3
@export var damage: int = 10
@export var attack_cooldown: float = 2.4
@export var throw_cooldown: float = 3.0
@export var throw_damage: int = 15

# --- HEALTH PROPERTIES ---
@export var health: int = 450
var max_health: int

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
		wall_detector.target_position = Vector2(player_direction * 50, 0)
		wall_detector.force_raycast_update()
	
	if wall_detector_retreat:
		var dir_to_player = player.position - position if player else Vector2.RIGHT
		var player_direction = sign(dir_to_player.x)
		wall_detector_retreat.target_position = Vector2(-player_direction * 50, 0)
		wall_detector_retreat.force_raycast_update()

# ===============================
# FIND PLAYER
# ===============================
func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

# ===============================
# DECISION MAKING - COMPLETAMENTE REVISADA
# ===============================
func make_decision():
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

	# DEBUG PRINTS
	print("=== DECISIÓN ENEMIGO ===")
	print("Distancia al jugador: ", distance)
	print("Min distance: ", min_distance)
	print("Throw range: ", throw_range)
	print("Min throw range: ", min_throw_range)
	print("Pared cerca: ", wall_near)
	print("Pared detrás: ", wall_behind)
	
	# NUEVA LÓGICA SIMPLIFICADA Y EFECTIVA
	if distance < min_distance and not wall_behind:
		# Demasiado cerca - retroceder
		print("DECISIÓN: Demasiado cerca, retrocediendo")
		current_state = State.RETREAT
		state_timer = 1.0
	elif can_throw and distance >= min_throw_range and distance <= throw_range:
		# En rango perfecto para lanzar
		print("DECISIÓN: En rango de lanzamiento")
		current_state = State.THROW
		state_timer = 2.0
	elif distance > throw_range:
		# Demasiado lejos - acercarse
		print("DECISIÓN: Demasiado lejos, acercándose")
		current_state = State.APPROACH
		state_timer = 1.0
	elif can_attack and distance <= attack_range and distance >= min_distance:
		# En rango de ataque cuerpo a cuerpo
		print("DECISIÓN: Ataque cuerpo a cuerpo")
		current_state = State.ATTACK
		state_timer = attack_duration
	else:
		# Si está entre min_distance y min_throw_range, mantener distancia
		if distance < min_throw_range and not wall_behind:
			print("DECISIÓN: Muy cerca para lanzar, retrocediendo")
			current_state = State.RETREAT
			state_timer = 1.0
		else:
			print("DECISIÓN: Manteniendo posición")
			current_state = State.IDLE
			state_timer = 0.5
	
	print("Nuevo estado: ", State.keys()[current_state])
	print("=========================")

# ===============================
# STATE EXECUTION - ACTUALIZADO
# ===============================
func execute_state(delta):
	if state_timer <= 0 and current_state not in [State.ATTACK, State.THROW]:
		current_state = State.IDLE

	var dir_to_player = player.position - position
	var player_direction = sign(dir_to_player.x)

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
			# Retroceder más rápido y con más determinación
			velocity.x = move_toward(velocity.x, -player_direction * speed * 1.2, speed * delta)
			if is_on_floor() and not is_attacking and not is_throwing:
				sprite.play("walk")
				print("RETROCESO ACTIVO - Velocidad: ", velocity.x)

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
# ATAQUE CUERPO A CUERPO
# ===============================
func start_attack():
	punchSound.play()
	is_attacking = true
	has_hit = false
	can_attack = false
	sprite.play("attack")
	area_ataque.monitoring = true

	var attack_momentum = 50.0
	var player_direction = sign((player.position - position).x)
	velocity.x = attack_momentum * player_direction

	await get_tree().create_timer(attack_duration).timeout
	velocity.x = 0
	area_ataque.monitoring = false
	is_attacking = false

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	current_state = State.IDLE

# ===============================
# LANZAMIENTO DE HACHA
# ===============================
func start_throw():
	throwAxe.play()
	is_throwing = true
	can_throw = false
	
	# Detener el movimiento durante el lanzamiento
	velocity.x = 0
	
	# Reproducir animación de lanzamiento
	sprite.play("throw")
	
	# Esperar a que la animación esté en el punto correcto para lanzar
	await get_tree().create_timer(0.3).timeout
	
	# Lanzar el hacha
	throw_axe()
	
	# Esperar a que termine la animación completa
	await get_tree().create_timer(0.7).timeout
	is_throwing = false
	
	# Cooldown del lanzamiento (en segundo plano)
	start_throw_cooldown()
	
	# Volver a estado IDLE después de lanzar
	current_state = State.IDLE

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
