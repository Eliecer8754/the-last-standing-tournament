extends Node2D

@export var PrincipalScene: PackedScene
@export var MinotauroScene: PackedScene
@export var HadoukenBottleScene: PackedScene

# --- ENERGÍA HADOUKEN ---
@onready var energy_hbox: HBoxContainer = $CanvasLayer/HSlider
var max_hadouken_energy: int = 3

# Posiciones iniciales
@export var player_start_pos: Vector2 = Vector2(200, 0)
@export var rival_start_pos: Vector2 = Vector2(600, 0)

var player: CharacterBody2D
var rival: CharacterBody2D

# Referencias a HUD dentro de CanvasLayer
@onready var winner_panel: Panel = $CanvasLayer/WinnerPanel
@onready var winner_label: Label = $CanvasLayer/WinnerPanel/WinnerLabel
@onready var health_bar: ProgressBar = $CanvasLayer/PlayerHealthBar

@export var winner_display_time: float = 4.0

# --- BOTELLITAS DINÁMICAS ---
var minotauro_health_thresholds: Array = [70, 40, 10] # % vida donde aparece cada botellita
var bottles_spawned_for_thresholds: Array = [false, false, false]

func _ready():
	AudioPlayer.stop_music()
	winner_panel.visible = false

	# --- Instanciar jugador ---
	if PrincipalScene:
		player = PrincipalScene.instantiate()
		add_child(player)
		var player_y = get_floor_y(player_start_pos.x)
		player.position = Vector2(player_start_pos.x, player_y)

		if "health_bar" in player:
			player.health_bar = health_bar

		if player.has_signal("player_defeated"):
			player.connect("player_defeated", Callable(self, "_on_player_defeated"))

		if player.has_method("set_hadouken_energy_checker"):
			player.set_hadouken_energy_checker(Callable(player, "can_use_hadouken"))

		if player.has_method("set_energy_ui"):
			var bars = []
			for bar in energy_hbox.get_children():
				if bar is ColorRect:
					bars.append(bar)
			player.set_energy_ui(bars)

	# --- Instanciar Minotauro ---
	if MinotauroScene:
		rival = MinotauroScene.instantiate()
		add_child(rival)
		var rival_y = get_floor_y(rival_start_pos.x)
		rival.position = Vector2(rival_start_pos.x, rival_y)

		if "player" in rival:
			rival.player = player

		if "health_bar" in rival:
			rival.health_bar = $CanvasLayer/RivalHealth

		if rival.has_signal("enemy_defeated"):
			rival.connect("enemy_defeated", Callable(self, "_on_enemy_defeated"))

		# Conectar señal de vida para botellitas
		if rival.has_signal("health_changed"):
			rival.connect("health_changed", Callable(self, "_on_rival_health_changed"))

# --- CALCULO PISO ---
func get_floor_y(_x_pos: float) -> float:
	var piso = $Node2D_mundo/StaticBody2D_piso
	var shape = piso.get_node("CollisionShape2D_piso").shape
	if shape is RectangleShape2D:
		var y = piso.position.y - shape.extents.y
		return y
	return 0

# --- BOTELLITAS DINÁMICAS ---
func _on_rival_health_changed(new_health: int, max_health: int):
	var health_percent = (new_health * 100) / max_health
	for i in range(minotauro_health_thresholds.size()):
		if health_percent <= minotauro_health_thresholds[i] and not bottles_spawned_for_thresholds[i]:
			call_deferred("_spawn_bottle_near_rival")
			bottles_spawned_for_thresholds[i] = true


func _spawn_bottle_near_rival():
	if not HadoukenBottleScene or not rival:
		return
	var offset = Vector2(randi_range(-100, 100), -300)  # Botellita alrededor del rival
	var bottle = HadoukenBottleScene.instantiate()
	bottle.position = rival.global_position + offset
	add_child(bottle)
	if bottle.has_method("set_player"):
		bottle.set_player(player)

# --- GANADOR ---
func _show_winner(text: String):
	winner_label.text = text
	winner_panel.visible = true
	get_tree().paused = true
	var t = get_tree().create_timer(winner_display_time)
	t.timeout.connect(Callable(self, "_return_to_levels"))

func _on_player_defeated():
	_show_winner("🏆 MINOTAURO GANA!")

func _on_enemy_defeated():
	_show_winner("🏆 JUGADOR GANA!")

func _return_to_levels():
	get_tree().paused = false
	var success = get_tree().change_scene_to_file("res://scenes/niveles.tscn")
	if not success:
		print("Error al cargar la escena")
