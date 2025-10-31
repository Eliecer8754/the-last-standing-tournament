extends Area2D

@export var pickup_amount: int = 1
var player: Node = null

func _ready():
	connect("area_entered", Callable(self, "_on_area_entered"))

func set_player(p):
	player = p

func _on_area_entered(area: Area2D):
	if area.is_in_group("player"):
		if player and player.has_method("add_hadouken_energy"):
			player.add_hadouken_energy(pickup_amount)
			print("entro")
		else:
			print("no lo encontro")
		queue_free()
