# axe.gd
extends Area2D

var speed: float = 400
var direction: Vector2 = Vector2.RIGHT
var damage: int = 15
var lifetime: float = 3.0
var rotation_speed: float = 10.0  # Velocidad de rotación
var has_hit: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready():
	# Conectar señales automáticamente
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func setup(throw_direction: Vector2, throw_damage: int):
	direction = throw_direction
	damage = throw_damage
	
	# Programar autodestrucción
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_end)

func _physics_process(delta):
	position += direction * speed * delta
	
	# Aplicar rotación continua
	sprite.rotation += rotation_speed * delta

func _on_body_entered(body):
	if has_hit:
		return
		
	# Verificar si golpeó al jugador
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		has_hit = true
		queue_free()
	
	# Verificar si golpeó paredes o suelo
	elif body is TileMap or body is StaticBody2D:
		has_hit = true
		queue_free()

func _on_area_entered(area):
	if has_hit:
		return
		
	# Verificar si golpeó el hurtbox del jugador
	if area.is_in_group("hurtbox_player"):
		var player = area.get_parent()
		if player.has_method("take_damage"):
			player.take_damage(damage, global_position)
		has_hit = true
		queue_free()

func _on_lifetime_end():
	queue_free()
