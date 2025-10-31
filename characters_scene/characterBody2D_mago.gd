extends CharacterBody2D

# --- NODOS Y ESCENAS ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var BolitaScene: PackedScene
@export var objetivo: CharacterBody2D

# --- PROPIEDADES ---
@export var speed: float = 200
@export var retreat_speed: float = 150
@export var distancia_segura: float = 300
@export var close_attack_range: float = 100
@export var gravity: float = 3000
@export var limite_izquierda: float = 0
@export var limite_derecha: float = 1080

# --- ATAQUES ---
@export var attack_cooldown: float = 1.5
var puede_atacar := true
var is_attacking := false

# --- IA ESTADOS ---
enum Estado { MANTENER_DISTANCIA, ACERCARSE }
var estado_actual: Estado = Estado.MANTENER_DISTANCIA

func _ready():
	sprite.play("idle")
	_iniciar_ia()

func _physics_process(delta: float) -> void:
	if not objetivo:
		return

	var dir_to_player = objetivo.global_position - global_position
	var distancia = dir_to_player.length()
	var dir_x = sign(dir_to_player.x)

	# --- FLIP DEL SPRITE ---
	sprite.flip_h = dir_x < 0

	# --- MOVIMIENTO SEGÚN ESTADO ---
	if not is_attacking:
		match estado_actual:
			Estado.MANTENER_DISTANCIA:
				if distancia < distancia_segura:
					var target_x = global_position.x - dir_x * retreat_speed * delta
					if target_x > limite_izquierda and target_x < limite_derecha:
						velocity.x = -dir_x * retreat_speed
						if is_on_floor():
							sprite.play("walk")
					else:
						velocity.x = 0
						if is_on_floor():
							sprite.play("idle")
				else:
					velocity.x = 0
					if is_on_floor():
						sprite.play("idle")
			Estado.ACERCARSE:
				if distancia > close_attack_range:
					var target_x = global_position.x + dir_x * speed * delta
					if target_x > limite_izquierda and target_x < limite_derecha:
						velocity.x = dir_x * speed
						if is_on_floor():
							sprite.play("walk")
					else:
						velocity.x = 0
				else:
					velocity.x = 0
					# Ataque cuerpo a cuerpo
					if puede_atacar and not is_attacking:
						start_melee_attack()

	# --- GRAVEDAD ---
	if not is_on_floor():
		velocity.y += gravity * delta

	move_and_slide()

# --- IA PRINCIPAL ---
func _iniciar_ia():
	while true:
		await get_tree().create_timer(randf_range(1.0, 3.0)).timeout
		# Cambiar estado aleatorio
		if randi() % 2 == 0:
			estado_actual = Estado.MANTENER_DISTANCIA
		else:
			estado_actual = Estado.ACERCARSE
		# Intentar ataque a distancia si no está atacando
		if puede_atacar and not is_attacking:
			disparar_bolitas()

# --- ATAQUE DE BOLITAS ---
func disparar_bolitas():
	if objetivo == null or BolitaScene == null:
		return

	is_attacking = true
	puede_atacar = false
	sprite.play("attack")

	var cantidad = 3
	var separacion = deg_to_rad(15)
	var direccion_base = (objetivo.global_position - global_position).normalized()
	var angulo_inicial = -separacion

	for i in range(cantidad):
		var bolita = BolitaScene.instantiate()
		get_parent().add_child(bolita)
		bolita.global_position = global_position
		var dir = direccion_base.rotated(angulo_inicial + (i * separacion))
		bolita.direction = dir
		if bolita.has_node("Sprite2D"):
			bolita.get_node("Sprite2D").flip_h = dir.x < 0

	await get_tree().create_timer(attack_cooldown).timeout
	puede_atacar = true
	is_attacking = false

# --- ATAQUE DE CERCA (Cuerpo a cuerpo) ---
func start_melee_attack():
	is_attacking = true
	puede_atacar = false
	sprite.play("attack_melee")

	# Aquí puedes activar un Area2D o detectar colisión con el jugador
	# Ejemplo simple de daño al jugador:
	if objetivo.has_method("take_damage"):
		objetivo.take_damage(10)

	await get_tree().create_timer(0.5).timeout  # duración del ataque cuerpo a cuerpo
	puede_atacar = true
	is_attacking = false
