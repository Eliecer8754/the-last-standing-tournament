extends CharacterBody2D

signal player_defeated

# --- MOVIMIENTO ---
@export var speed: float = 450
@export var jump_speed: float = -1500
@export var gravity: float = 3000

# --- COMBATE ---
@export var attack_duration: float = 0.3
@export var damage: int = 10
@export var health: int = 100
@export var knockback_force: float = 800
@export var knockback_up_force: float = 500
@export var stun_duration: float = 0.5

# --- NODOS ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D_jugador
@onready var area_ataque: Area2D = $Area2D_ataque
@onready var hurtbox_standing: Area2D = $HurtboxStanding
@onready var hurtbox_crouching: Area2D = $HurtboxCrouching
@export var health_bar: ProgressBar

# --- HADOUKEN ---
@export var HadoukenScene: PackedScene

# --- ESTADO ---
var is_attacking: bool = false
var is_stunned: bool = false
var is_crouching: bool = false
var is_blocking: bool = false
var original_speed: float = 0
var was_in_air: bool = false

# --- ENERGÍA HADOUKEN ---
var can_cast_hadouken = null
var current_hadouken_energy: int = 3
var max_hadouken_energy: int = 3
var energy_ui: Array = []
@export var block_break_damage: int = 5
@export var block_stun_duration: float = 0.8

#sonidos
@onready var punchSound: AudioStreamPlayer2D = $punchSound
@onready var hadoukenSound: AudioStreamPlayer2D = $hadoukenSound
@onready var bottleSound: AudioStreamPlayer2D = $bottleSound
@onready var HitPunchShound: AudioStreamPlayer2D = $HitPunchShound
@onready var blockSound: AudioStreamPlayer2D = $blockSound
@onready var takeDamageSound: AudioStreamPlayer2D = $takeDamageSound 

# --- CONFIGURACIONES ---
func set_hadouken_energy_checker(energy_checker):
	can_cast_hadouken = energy_checker

func set_energy_ui(bars: Array):
	energy_ui = bars
	_update_energy_ui()

func can_use_hadouken() -> bool:
	if current_hadouken_energy <= 0:
		return false
	current_hadouken_energy -= 1
	_update_energy_ui()
	return true

func add_hadouken_energy(amount: int = 1):
	bottleSound.play()
	current_hadouken_energy = min(current_hadouken_energy + amount, max_hadouken_energy)
	_update_energy_ui()

func _update_energy_ui():
	for i in range(energy_ui.size()):
		energy_ui[i].visible = i < current_hadouken_energy

# --- READY ---
func _ready():
	sprite.play("idle")
	area_ataque.monitoring = false
	area_ataque.add_to_group("hurtbox_player")
	area_ataque.connect("area_entered", Callable(self, "_on_area_ataque_entered"))
	original_speed = speed
	
	# Configurar hurtboxes - Estado inicial
	if hurtbox_standing:
		hurtbox_standing.add_to_group("hurtbox_player")
		hurtbox_standing.add_to_group("player")
		hurtbox_standing.monitoring = true
		hurtbox_standing.monitorable = true
	if hurtbox_crouching:
		hurtbox_crouching.add_to_group("hurtbox_player")
		hurtbox_crouching.monitoring = false
		hurtbox_crouching.monitorable = false  # Inicialmente no detectable

	if health_bar:
		health_bar.max_value = health
		health_bar.value = health

# --- PHYSICS PROCESS ---
func _physics_process(delta):
	if is_stunned:
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	velocity.x = 0

	# Manejar entrada de agacharse
	var was_crouching = is_crouching
	if Input.is_action_pressed("ui_down") and is_on_floor():
		is_crouching = true
	else:
		is_crouching = false

	# Actualizar hurtboxes solo si cambió el estado de agachado
	if was_crouching != is_crouching:
		_update_hurtboxes()

	# Manejar entrada de bloqueo
	if Input.is_action_pressed("block") and is_on_floor() and not is_crouching and not is_attacking:
		is_blocking = true
	else:
		is_blocking = false

	# Movimiento horizontal solo si no está agachado ni bloqueando
	if not is_crouching and not is_blocking:
		if Input.is_action_pressed("ui_right"):
			velocity.x += speed
			sprite.flip_h = false
		elif Input.is_action_pressed("ui_left"):
			velocity.x -= speed
			sprite.flip_h = true

	# Salto solo si no está agachado ni bloqueando
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and not is_blocking:
		velocity.y = jump_speed

	if not is_on_floor():
		velocity.y += gravity * delta

	# Ataques solo si no está agachado ni bloqueando
	if not is_attacking and not is_crouching and not is_blocking:
		if Input.is_action_just_pressed("punch"):
			punchSound.play()
			attack("punch")
		elif Input.is_action_just_pressed("kick"):
			punchSound.play()
			attack("kick")
		elif Input.is_action_just_pressed("hadouken"):
			await attack_hadouken()

	# ACTUALIZAR ANIMACIÓN
	_update_animation()

	move_and_slide()

	# Detectar cuando aterriza después de estar en el aire
	if was_in_air and is_on_floor():
		_update_animation()
	
	was_in_air = not is_on_floor()

# --- ACTUALIZAR HURTBOXES - CORREGIDO ---
func _update_hurtboxes():
	if hurtbox_standing and hurtbox_crouching:
		if is_crouching:
			# Modo agachado: standing OFF, crouching ON
			hurtbox_standing.monitoring = false
			hurtbox_standing.monitorable = false
			hurtbox_crouching.monitoring = true
			hurtbox_crouching.monitorable = true
		else:
			# Modo parado: standing ON, crouching OFF  
			hurtbox_standing.monitoring = true
			hurtbox_standing.monitorable = true
			hurtbox_crouching.monitoring = false
			hurtbox_crouching.monitorable = false

# --- ACTUALIZAR ANIMACIÓN ---
func _update_animation():
	if is_stunned:
		return

	if is_attacking:
		return

	if is_blocking:
		sprite.play("block")
	elif is_crouching:
		sprite.play("crouch")
	elif not is_on_floor():
		sprite.play("jump")
	elif velocity.x != 0:
		sprite.play("walk")
	else:
		sprite.play("idle")

# --- ATAQUE ---
func attack(anim: String):
	is_attacking = true
	sprite.play(anim)
	area_ataque.monitoring = true
	await get_tree().create_timer(attack_duration).timeout
	area_ataque.monitoring = false
	is_attacking = false
	_update_animation()

func attack_hadouken() -> void:
	if can_cast_hadouken != null and not can_cast_hadouken.call():
		print("No hay energía para Hadouken!")
		return
	hadoukenSound.play()
	is_attacking = true
	sprite.play("hadouken")
	cast_hadouken()
	await get_tree().create_timer(attack_duration).timeout
	is_attacking = false
	_update_animation()

func cast_hadouken():
	if not HadoukenScene:
		print("⚠️ HadoukenScene no está asignado")
		return

	var hadouken = HadoukenScene.instantiate()

	# Offset de spawn
	var spawn_offset = Vector2(60, -40)
	if sprite.flip_h:
		spawn_offset.x *= -1

	hadouken.global_position = global_position + spawn_offset

	# Dirección según flip del sprite
	if sprite.flip_h:
		hadouken.set_direction(Vector2.LEFT)
		if hadouken.has_node("AnimatedSprite2D"):
			hadouken.get_node("AnimatedSprite2D").flip_h = true
	else:
		hadouken.set_direction(Vector2.RIGHT)
		if hadouken.has_node("AnimatedSprite2D"):
			hadouken.get_node("AnimatedSprite2D").flip_h = false

	# Configurar propiedades del Hadouken para más knockback
	if hadouken.has_method("set_knockback"):
		hadouken.set_knockback(400, 800, 0.6)

	get_tree().current_scene.add_child(hadouken)
	print("✅ Hadouken lanzado en:", hadouken.global_position)

# --- AREA ATAQUE ---
func _on_area_ataque_entered(area: Area2D):
	if area.is_in_group("hurtbox_enemy"):
		print("HitPunchShound")
		HitPunchShound.play()
		var enemigo = area.get_parent()
		if enemigo.has_method("take_damage"):
			enemigo.take_damage(damage, global_position)
	else:
		print("punchSound")
		punchSound.play()

# --- DAÑO ---
func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO, is_block_breaker: bool = false):
	var final_damage = amount
	
	# LOS MISILES AÉREOS SON UNBLOCKABLE - siempre pasan el bloqueo
	if is_blocking and not is_block_breaker and not is_unblockable_attack(attacker_position):
		# Bloqueo normal - daño reducido (solo para ataques bloqueables)
		final_damage = ceil(amount / 2.0)
		blockSound.play()

		# Knockback reducido pero consistente
		var knockback_direction = (global_position - attacker_position).normalized()
		velocity.x = knockback_direction.x * (knockback_force * 0.5)
		velocity.y = -knockback_up_force * 0.3

		is_stunned = true
		await get_tree().create_timer(stun_duration * 0.2).timeout
		is_stunned = false

	elif is_blocking and (is_block_breaker or is_unblockable_attack(attacker_position)):
		# Ataque rompe-bloqueo o unblockable - daño completo + stun
		takeDamageSound.play()
		final_damage = amount
		print("🛡️ ¡BLOQUEO ROTO! Ataque no bloqueable")

		# Knockback fuerte y stun prolongado
		var knockback_direction = (global_position - attacker_position).normalized()
		velocity.x = knockback_direction.x * knockback_force
		velocity.y = -knockback_up_force * 0.8

		is_stunned = true
		# Animación especial de bloqueo roto
		if sprite.sprite_frames.has_animation("block_break"):
			sprite.play("block_break")
		else:
			sprite.play("hurt")

		await get_tree().create_timer(block_stun_duration).timeout
		is_stunned = false

	else:
		# Daño normal sin bloqueo
		takeDamageSound.play()
		if attacker_position != Vector2.ZERO:
			apply_knockback(attacker_position)

	health -= final_damage
	health = max(health, 0)

	if health_bar:
		health_bar.value = health

	if health <= 0:
		emit_signal("player_defeated")

# Nueva función para detectar ataques no bloqueables
func is_unblockable_attack(attacker_position: Vector2) -> bool:
	# Detectar misiles aéreos por su posición (vienen desde arriba)
	if attacker_position != Vector2.ZERO:
		var attack_direction = (global_position - attacker_position).normalized()
		# Si el ataque viene principalmente desde arriba, es probablemente un misil aéreo
		if attack_direction.y < -0.7:  # Viene desde arriba
			return true
	return false

func apply_knockback(attacker_position: Vector2):
	var knockback_direction = (global_position - attacker_position).normalized()
	velocity.x = knockback_direction.x * knockback_force
	velocity.y = -knockback_up_force
	is_stunned = true
	speed = original_speed * 0.7

	# Reproducir animación de hurt si existe
	if sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")

	await get_tree().create_timer(stun_duration).timeout

	is_stunned = false
	speed = original_speed
	_update_animation()
