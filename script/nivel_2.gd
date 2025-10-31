extends Node2D

@export var PrincipalScene: PackedScene
@export var MagoScene: PackedScene

# Posiciones iniciales
@export var player_start_pos: Vector2 = Vector2(200, 0)
@export var rival_start_pos: Vector2 = Vector2(600, 0)

var player: CharacterBody2D
var rival: CharacterBody2D

# Referencias a HUD dentro de CanvasLayer
@onready var winner_panel: Panel = $CanvasLayer/WinnerPanel
@onready var winner_label: Label = $CanvasLayer/WinnerPanel/WinnerLabel
@onready var health_bar: ProgressBar = $CanvasLayer/PlayerHealthBar

# Duración que se mostrará la pantalla de ganador
@export var winner_display_time: float = 4.0

func _ready():
	AudioPlayer.stop_music()
	winner_panel.visible = false

	# --- Instanciar jugador ---
	if PrincipalScene:
		player = PrincipalScene.instantiate()
		add_child(player)
		var player_y = get_floor_y(player_start_pos.x)
		player.position = Vector2(player_start_pos.x, player_y)
		print("Jugador posición inicial:", player.position)

		if "health_bar" in player:
			player.health_bar = health_bar

		if player.has_signal("player_defeated"):
			player.connect("player_defeated", Callable(self, "_on_player_defeated"))

	# --- Instanciar rival ---
		# --- Instanciar rival ---
		if MagoScene:
			rival = MagoScene.instantiate()
			add_child(rival)
			var rival_y = get_floor_y(rival_start_pos.x)
			rival.position = Vector2(rival_start_pos.x, rival_y)
			print("Rival posición inicial:", rival.position)

			# 🔹 Asignar objetivo al mago (el jugador)
			if "objetivo" in rival:
				rival.objetivo = player

			if "health_bar" in rival:
				rival.health_bar = $CanvasLayer/RivalHealth

			if rival.has_signal("enemy_defeated"):
				rival.connect("enemy_defeated", Callable(self, "_on_enemy_defeated"))



# Calcula la Y del piso según posición X
func get_floor_y(x_pos: float) -> float:
	var piso = $Node2D_mundo/StaticBody2D_piso
	var shape = piso.get_node("CollisionShape2D_piso").shape
	if shape is RectangleShape2D:
		var y = piso.position.y - shape.extents.y
		print("Piso Y en X =", x_pos, "=>", y)
		return y
	return 0

func _show_winner(text: String):
	winner_label.text = text
	winner_panel.visible = true
	get_tree().paused = true  # Pausar escena

	# Mostrar 4 segundos y luego cambiar de escena automáticamente
	var t = get_tree().create_timer(winner_display_time)
	t.timeout.connect(_return_to_levels)

func _on_player_defeated():
	_show_winner("🏆 Mago GANA!")

func _on_enemy_defeated():
	_show_winner("🏆 JUGADOR GANA!")

func _return_to_levels():
	var tree = get_tree()
	if tree != null:
		tree.paused = false
		tree.change_scene_to_file("res://scenes/niveles.tscn")
		# Si tree es null, no hace nada y evita el error
