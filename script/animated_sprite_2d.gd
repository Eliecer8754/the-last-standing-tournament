extends AnimatedSprite2D

# --- Movimiento ---
var speed: float = 450
var direction: int = 0

# --- Salto ---
var gravity: float = 3000
var jump_speed: float = -1200
var velocity_y: float = 0
var on_ground: bool = true

# --- Ataques ---
var is_attacking: bool = false
var attack_type: String = ""  # "punch", "kick", "hadouken"
var attack_timer: float = 0.0
var attack_duration := {
	"punch": 0.3,
	"kick": 0.3,
	"hadouken": 0.6
}

@export var hadouken_scene: PackedScene  # Arrastra aquí tu ball.tscn

# --- Suelo ---
var ground_y: float = 0

func _ready() -> void:
	play("idle")
	position.y = ground_y

func _process(delta: float) -> void:
	# --- Manejar temporizador de ataque ---
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			attack_type = ""
			attack_timer = 0.0

	# --- Movimiento horizontal ---
	direction = 0
	if Input.is_action_pressed("ui_right"):
		direction = 1
	elif Input.is_action_pressed("ui_left"):
		direction = -1

	position.x += speed * direction * delta

	# --- Salto ---
	if on_ground and Input.is_action_just_pressed("ui_accept"):
		velocity_y = jump_speed
		on_ground = false

	# --- Aplicar gravedad ---
	if not on_ground:
		velocity_y += gravity * delta
		position.y += velocity_y * delta

		if position.y >= ground_y:
			position.y = ground_y
			velocity_y = 0
			on_ground = true

	# --- Detectar input para ataques ---
	if on_ground and not is_attacking:
		if Input.is_action_just_pressed("punch"):
			start_attack("punch")
		elif Input.is_action_just_pressed("kick"):
			start_attack("kick")
		elif Input.is_action_just_pressed("hadouken"):
			start_attack("hadouken")
			shoot_hadouken()  # Instanciar la bola

	# --- Animaciones ---
	if is_attacking:
		if animation != attack_type:
			play(attack_type)
	elif not on_ground:
		if animation != "jump":
			play("jump")
	elif direction != 0:
		if animation != "walk":
			play("walk")
	else:
		if animation != "idle":
			play("idle")

	# --- Voltear sprite ---
	if direction != 0:
		flip_h = direction < 0

# --- Función para iniciar ataque ---
func start_attack(tipo: String) -> void:
	is_attacking = true
	attack_type = tipo
	attack_timer = attack_duration.get(tipo, 0.3)
	play(tipo)

# --- Función para disparar la bola ---
func shoot_hadouken() -> void:
	if hadouken_scene:
		# Castea el nodo instanciado para evitar errores de tipo
		var projectile = hadouken_scene.instantiate() as AnimatedSprite2D
		projectile.position = position + Vector2(-50 if flip_h else 50, -40)
		projectile.direction = -1 if flip_h else 1
		projectile.scale.x = -1 if flip_h else 1
		get_parent().add_child(projectile)
