extends CharacterBody2D

# --- MOVEMENT PROPERTIES ---
@export var speed: float = 200
@export var attack_range: float = 250
@export var min_distance: float = 100
@export var optimal_distance: float = 250

# --- COMBAT PROPERTIES ---
@export var attack_duration: float = 0.3
@export var damage: int = 10
@export var attack_cooldown: float = 2.4

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

# --- VARIABLES ---
var player: CharacterBody2D
var is_attacking: bool = false
var has_hit: bool = false
var can_attack: bool = true
var is_stunned: bool = false
var health_bar: ProgressBar = null

# --- STATE MACHINE ---
enum State { IDLE, APPROACH, RETREAT, ATTACK, STUNNED }
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
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

	# Configurar áreas
	area_ataque.monitoring = false
	area_ataque.add_to_group("hitbox_enemy")
	area_ataque.connect("area_entered", Callable(self, "_on_area_ataque_entered"))

	area_dano.add_to_group("hurtbox_enemy")
	area_dano.connect("area_entered", Callable(self, "_on_area_dano_entered"))

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

	# Tomar decisiones cada cierto tiempo, no cada frame
	if decision_cooldown <= 0:
		make_decision()
		decision_cooldown = 0.5  # Reducir frecuencia de decisiones

	# Ejecutar estado actual
	execute_state(delta)

	if not is_on_floor():
		velocity.y += gravity * delta

	move_and_slide()

# ===============================
# FIND PLAYER
# ===============================
func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

# ===============================
# DECISION MAKING
# ===============================
func make_decision():
	if is_attacking or is_stunned:
		return

	var dir_to_player = player.position - position
	var distance = dir_to_player.length()
	var player_direction = sign(dir_to_player.x)

	# Sprite Direction
	if player_direction != 0:
		sprite.flip_h = player_direction < 0

	# Lógica de decisión mejorada
	if distance > attack_range:
		# Demasiado lejos - acercarse
		current_state = State.APPROACH
		state_timer = 1.0
	elif distance < min_distance:
		# Demasiado cerca - retroceder
		current_state = State.RETREAT
		state_timer = 0.8
	elif can_attack and distance <= attack_range and distance >= min_distance:
		# Distancia buena - atacar
		current_state = State.ATTACK
		state_timer = attack_duration
	else:
		# Mantener posición
		current_state = State.IDLE
		state_timer = 0.5

# ===============================
# STATE EXECUTION
# ===============================
func execute_state(delta):
	if state_timer <= 0 and current_state != State.ATTACK:
		current_state = State.IDLE

	var dir_to_player = player.position - position
	var player_direction = sign(dir_to_player.x)

	match current_state:
		State.IDLE:
			velocity.x = 0
			if is_on_floor():
				sprite.play("idle")

		State.APPROACH:
			velocity.x = player_direction * speed
			if is_on_floor():
				sprite.play("walk")

		State.RETREAT:
			velocity.x = -player_direction * speed * 0.8
			if is_on_floor():
				sprite.play("walk")

		State.ATTACK:
			if not is_attacking and can_attack:
				start_attack()
			else:
				velocity.x = 0
				if is_on_floor() and not is_attacking:
					sprite.play("idle")

		State.STUNNED:
			# La lógica de stun se maneja por separado
			pass

# ===============================
# ATTACK
# ===============================
func start_attack():
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
