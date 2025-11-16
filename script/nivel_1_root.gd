extends Node2D

@export var PrincipalScene: PackedScene
@export var RivalScene: PackedScene  # Cambiado a genérico para cualquier rival
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
@onready var countdown_label: Label = $CanvasLayer/CountdownLabel
@export var winner_display_time: float = 4.0

# --- BOTELLITAS DINÁMICAS ---
var rival_health_thresholds: Array = [70, 40, 10] # % vida donde aparece cada botellita
var bottles_spawned_for_thresholds: Array = [false, false, false]

# --- CONTROL DE INICIO ---
var fight_started: bool = false

# Variable para controlar el estado del juego
var game_ended: bool = false

func _ready():
	AudioPlayer.stop_music()
	winner_panel.visible = false
	countdown_label.visible = false

	# --- Instanciar jugador ---
	if PrincipalScene:
		player = PrincipalScene.instantiate()
		add_child(player)
		player.position = Vector2(150, 480)

		# Desactivar controles del jugador inicialmente
		player.set_physics_process(false)

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

	# --- Instanciar Rival (Mago) ---
	if RivalScene:
		rival = RivalScene.instantiate()
		add_child(rival)
		rival.position = Vector2(1300, 415)

		# Desactivar IA del rival inicialmente
		rival.set_physics_process(false)
		if rival.has_method("set_active"):
			rival.set_active(false)

		# Asignar el jugador como objetivo del rival
		if "player" in rival:
			rival.player = player

		# Configurar barra de salud del rival
		if "health_bar" in rival:
			rival.health_bar = $CanvasLayer/RivalHealth

		# Conectar señales del rival
		if rival.has_signal("enemy_defeated"):
			rival.connect("enemy_defeated", Callable(self, "_on_enemy_defeated"))

		# Conectar señal de vida para botellitas
		if rival.has_signal("health_changed"):
			rival.connect("health_changed", Callable(self, "_on_rival_health_changed"))

	# Iniciar conteo regresivo
	start_countdown()

func start_countdown():
	countdown_label.visible = true
	
	# Conteo 3
	countdown_label.text = "3"
	await get_tree().create_timer(1.0).timeout
	
	# Conteo 2
	countdown_label.text = "2"
	await get_tree().create_timer(1.0).timeout
	
	# Conteo 1
	countdown_label.text = "1"
	await get_tree().create_timer(1.0).timeout
	
	# ¡PELEA!
	countdown_label.text = "¡PELEA!"
	await get_tree().create_timer(0.5).timeout
	
	countdown_label.visible = false
	
	# Activar controles e IA
	fight_started = true
	if player:
		player.set_physics_process(true)
	if rival:
		rival.set_physics_process(true)
		if rival.has_method("set_active"):
			rival.set_active(true)

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
	if not fight_started or game_ended:
		return
		
	var health_percent = (new_health * 100) / max_health
	for i in range(rival_health_thresholds.size()):
		if health_percent <= rival_health_thresholds[i] and not bottles_spawned_for_thresholds[i]:
			call_deferred("_spawn_bottle_near_rival")
			bottles_spawned_for_thresholds[i] = true

func _spawn_bottle_near_rival():
	if not HadoukenBottleScene or not rival or game_ended:
		return
	var offset = Vector2(randi_range(-100, 100), -100)
	var bottle = HadoukenBottleScene.instantiate()
	bottle.position = rival.global_position + offset
	add_child(bottle)
	if bottle.has_method("set_player"):
		bottle.set_player(player)

# --- GANADOR ---
func _show_winner(text: String):
	if game_ended:
		return
		
	game_ended = true
	winner_label.text = text
	winner_panel.visible = true
	
	# Desactivar controles al terminar la pelea
	fight_started = false
	if player:
		player.set_physics_process(false)
	if rival:
		rival.set_physics_process(false)
		if rival.has_method("set_active"):
			rival.set_active(false)
	
	# Usar call_deferred para evitar problemas con el árbol de escenas
	call_deferred("_start_winner_timer")

func _start_winner_timer():
	# Crear el temporizador de manera segura
	var timer = get_tree().create_timer(winner_display_time)
	if timer:
		timer.timeout.connect(Callable(self, "_return_to_levels"), CONNECT_ONE_SHOT)

func _on_player_defeated():
	_show_winner("🏆 " + rival.name + " GANA!")

func _on_enemy_defeated():
	_show_winner("🏆 JUGADOR GANA!")

func _return_to_levels():
	# Verificar que todavía estamos en el árbol de escenas
	if not is_inside_tree():
		return
	
	# Cambiar a la escena de niveles de manera segura
	var tree = get_tree()
	if tree and not tree.paused:
		var success = tree.change_scene_to_file("res://scenes/niveles.tscn")
		if not success:
			print("Error al cargar la escena de niveles")
