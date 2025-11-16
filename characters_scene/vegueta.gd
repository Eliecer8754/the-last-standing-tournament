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

# --- KNOCKBACK PROPERTIES ---
@export var knockback_force: float = 80  # Reducido
@export var knockback_up_force: float = 60  # Reducido
@export var stun_duration: float = 0.3
@export var knockback_delay: float = 0.1

# --- NODES ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtboxIdle: Area2D = $hurtboxIdle
@onready var hurtboxFlying: Area2D = $hurtboxFlying

# --- VARIABLES ---
var player: CharacterBody2D
var target_position: Vector2
var is_stunned: bool = false
var current_health: int
var health_bar: ProgressBar = null
var gravity: float = 0  # SIN GRAVEDAD - Boss aéreo

# --- STATE MACHINE ---
enum State { POSITIONING, ATTACK_PREP, ATTACKING, COOLDOWN, STUNNED }
var current_state: State = State.POSITIONING
var state_timer: float = 0.0

# --- SIGNALS ---
signal boss_defeated
signal health_changed(new_health: int, max_health: int)

func _ready():
	max_health = health
	current_health = health
	print("BOSS INICIALIZADO - Posición inicial: ", global_position)
	
	# Configurar hurtboxes como el minotauro
	setup_hurtboxes()
	
	# Buscar jugador
	find_player()
	
	# Iniciar en estado de posicionamiento
	transition_to_state(State.POSITIONING)

# AGREGADO: Función para asignar la barra de vida desde el nivel
func set_health_bar(bar: ProgressBar):
	health_bar = bar
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		print("Barra de salud del boss asignada correctamente")

func setup_hurtboxes():
	# Configurar hurtboxes igual que el minotauro
	hurtboxIdle.add_to_group("hurtbox_enemy")
	hurtboxIdle.connect("area_entered", Callable(self, "_on_hurtbox_area_entered"))
	
	hurtboxFlying.add_to_group("hurtbox_enemy") 
	hurtboxFlying.connect("area_entered", Callable(self, "_on_hurtbox_area_entered"))
	
	# Inicialmente, solo la hurtbox de flying está activa
	update_hurtboxes()

func update_hurtboxes():
	match current_state:
		State.POSITIONING, State.ATTACKING:
			hurtboxFlying.monitoring = true
			hurtboxIdle.monitoring = false
		State.ATTACK_PREP, State.COOLDOWN, State.STUNNED:
			hurtboxFlying.monitoring = false
			hurtboxIdle.monitoring = true

func _physics_process(delta):
	if player == null:
		find_player()
	
	# NUNCA aplicar gravedad - es un boss aéreo
	velocity.y = 0
	
	if is_stunned:
		# Durante el stun, reducir velocidad gradualmente SIN GRAVEDAD
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 3)
		move_and_slide()
		clamp_to_limits()
		
		# Actualizar temporizador del stun
		state_timer -= delta
		if state_timer <= 0:
			is_stunned = false
			transition_to_state(State.POSITIONING)
		return
	
	# Actualizar temporizador de estado
	state_timer -= delta
	
	# Ejecutar estado actual
	match current_state:
		State.POSITIONING:
			execute_positioning(delta)
		State.ATTACK_PREP:
			execute_attack_prep(delta)
		State.ATTACKING:
			execute_attacking(delta)
		State.COOLDOWN:
			execute_cooldown(delta)
	
	# Aplicar movimiento
	move_and_slide()
	
	# Asegurar que no salga de los límites
	clamp_to_limits()

func clamp_to_limits():
	# Asegurar que la posición esté dentro de los límites definidos
	var clamped_position = global_position
	
	clamped_position.x = clamp(clamped_position.x, x_limits.x, x_limits.y)
	clamped_position.y = clamp(clamped_position.y, y_limits.x, y_limits.y)
	
	global_position = clamped_position

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func transition_to_state(new_state: State):
	current_state = new_state
	
	print("CAMBIO DE ESTADO: ", State.keys()[current_state])
	
	# Actualizar hurtboxes según el nuevo estado
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
		
		State.ATTACKING:
			state_timer = 1.0
			start_attack()
		
		State.COOLDOWN:
			state_timer = 1.2
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

# --- ATAQUES ---
func start_attack():
	print("INICIANDO ATAQUE desde posición: ", global_position)
	look_at_player()
	sprite.play("attack")
	
	var attack_type = randi() % 3
	match attack_type:
		0:
			dash_attack()
		1:
			projectile_attack()
		2:
			area_attack()

func dash_attack():
	if player:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * flight_speed * 2.5

func projectile_attack():
	velocity = Vector2.ZERO

func area_attack():
	velocity = Vector2.ZERO

# ===============================
# DETECCIÓN DE DAÑO - COMO EL MINOTAURO
# ===============================
func _on_hurtbox_area_entered(area: Area2D):
	if area.is_in_group("hitbox_player"):
		var jugador = area.get_parent()
		if jugador.has_method("get_attack_damage"):
			var damage_received = jugador.get_attack_damage()
			take_damage(damage_received, jugador.global_position)

# ===============================
# RECIBIR DAÑO - COMO EL MINOTAURO
# ===============================
func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO):
	print("BOSS RECIBIÓ DAÑO: ", amount)
	
	current_health -= amount
	current_health = max(current_health, 0)
	
	# AGREGADO: Actualizar barra de vida si existe
	if health_bar:
		health_bar.value = current_health
		print("Barra de salud actualizada: ", current_health)
	
	emit_signal("health_changed", current_health, max_health)
	
	if attacker_position != Vector2.ZERO:
		apply_knockback(attacker_position)
	
	if current_health <= 0:
		defeat()
	else:
		# Cambiar a estado de stun
		is_stunned = true
		transition_to_state(State.STUNNED)

# ===============================
# KNOCKBACK SUAVE - SIN CAÍDA
# ===============================
func apply_knockback(attacker_position: Vector2):
	print("APLICANDO KNOCKBACK SUAVE al boss")
	
	if sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")

	await get_tree().create_timer(knockback_delay).timeout

	var knockback_direction = (global_position - attacker_position).normalized()
	# Knockback mucho más suave y controlado - SIN COMPONENTE VERTICAL FUERTE
	velocity.x = knockback_direction.x * knockback_force * 0.7
	velocity.y = -knockback_up_force * 0.1  # Muy poco movimiento vertical

	move_and_slide()

func defeat():
	print("BOSS DERROTADO!")
	sprite.play("defeat")
	emit_signal("boss_defeated")
	
	# Desactivar todas las hurtboxes
	hurtboxFlying.monitoring = false
	hurtboxIdle.monitoring = false
	
	# Desactivar el movimiento
	set_physics_process(false)
	
	await get_tree().create_timer(2.0).timeout
	queue_free()

# Funciones para actualizar los límites
func set_x_limits(new_limits: Vector2):
	x_limits = new_limits
	generate_new_position()

func set_y_limits(new_limits: Vector2):
	y_limits = new_limits
	generate_new_position()

# --- SEÑALES DE ANIMACIÓN ---
func _on_animated_sprite_2d_animation_finished():
	if sprite.animation == "attack":
		print("ANIMACIÓN DE ATAQUE TERMINADA")
	elif sprite.animation == "hurt" and current_health > 0:
		print("ANIMACIÓN DE HURT TERMINADA")
		# El estado ya debería haber cambiado por el temporizador
