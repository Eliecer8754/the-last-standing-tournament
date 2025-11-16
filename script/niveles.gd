extends Control

# ======================
# Variables de niveles
# ======================
var niveles_completados = [0, 1]  # Nivel 1 desbloqueado por defecto
var nivel_seleccionado: int = 0

@onready var botones_niveles = [
	$VBoxContainer/BotonNivel1,
	$VBoxContainer/BotonNivel2,
	$VBoxContainer/BotonNivel3
]

@onready var botones_extra = [
	$VBoxContainer2/BotonNivel4,
	$VBoxContainer2/BotonNivel5,
	$VBoxContainer2/BotonNivel6
]

@onready var back_button = $VBoxContainer3/back
@onready var fight_button = $VBoxContainer3/fight

# Pre-carga de enemigos
@onready var minotauro = preload("res://characters_scene/minotauro.tscn")
@onready var mago = preload("res://characters_scene/mago.tscn")
@onready var vegueta = preload("res://characters_scene/vegueta.tscn")

# Rival instanciado
var rival: Node2D = null

# ======================
# Traducciones
# ======================
var translations = {
	0: { # Español
		"niveles": ["Nivel 1", "Nivel 2", "Nivel 3", "Nivel 4", "Nivel 5", "Nivel 6"],
		"back": "Atras",
		"fight": "Luchar"
	},
	1: { # Inglés
		"niveles": ["Level 1", "Level 2", "Level 3", "Level 4", "Level 5", "Level 6"],
		"back": "Back",
		"fight": "Fight"
	},
	2: { # Alemán
		"niveles": ["Stufe 1", "Stufe 2", "Stufe 3", "Stufe 4", "Stufe 5", "Stufe 6"],
		"back": "Zurück",
		"fight": "Kämpfen"
	},
	3: { # Ruso
		"niveles": ["Уровень 1", "Уровень 2", "Уровень 3", "Уровень 4", "Уровень 5", "Уровень 6"],
		"back": "Назад",
		"fight": "Бой"
	},
	4: { # Chino
		"niveles": ["第1关", "第2关", "第3关", "第4关", "第5关", "第6关"],
		"back": "返回",
		"fight": "战斗"
	}
}

# ======================
# Funciones principales
# ======================
func _ready():
	cargar_progreso()
	actualizar_botones()
	change_language_settings()
	rival = null

	# Escucha cambios de idioma
	if not Global.value_changed.is_connected(_on_language_changed):
		Global.value_changed.connect(_on_language_changed)

	# ======================
	# Control de música
	# ======================
	  # Ajusta según el path real
	if AudioPlayer:
		# Verifica si ya está reproduciendo
		if not AudioPlayer.is_playing():
			# Ajusta volumen según Global
			AudioPlayer.volume_db = linear_to_db(Global.music_volume)
			AudioPlayer.play()


# ======================
# Idioma
# ======================
func change_language_settings():
	var lang_index = Global.language
	if lang_index == null or lang_index < 0 or lang_index >= translations.size():
		lang_index = 0  # Español por defecto

	var t = translations[lang_index]

	# Actualizar botones de nivel
	var todos_los_botones = botones_niveles + botones_extra
	for i in range(todos_los_botones.size()):
		var boton = todos_los_botones[i]
		if boton:
			boton.text = t["niveles"][i]

	# Actualizar botones generales
	if back_button:
		back_button.text = t["back"]
	if fight_button:
		fight_button.text = t["fight"]

func _on_language_changed(_index):
	change_language_settings()

# ======================
# Progreso
# ======================
func cargar_progreso():
	var config = ConfigFile.new()
	var err = config.load("user://progreso.cfg")
	if err == OK:
		niveles_completados = config.get_value("progreso", "niveles_completados", [0, 1])
	else:
		niveles_completados = [0, 1]

func guardar_progreso():
	var config = ConfigFile.new()
	config.set_value("progreso", "niveles_completados", niveles_completados)
	config.save("user://progreso.cfg")

func actualizar_botones():
	var todos_los_botones = botones_niveles + botones_extra
	for i in range(todos_los_botones.size()):
		var boton = todos_los_botones[i]
		if boton == null:
			continue
		if i == 0:
			boton.disabled = false
			boton.modulate = Color(1, 1, 1)
		else:
			if (i - 1) in niveles_completados:
				boton.disabled = false
				boton.modulate = Color(1, 1, 1)
			else:
				boton.disabled = true
				boton.modulate = Color(0.5, 0.5, 0.5)

func completar_nivel(nivel):
	if nivel not in niveles_completados:
		niveles_completados.append(nivel)
		guardar_progreso()
		actualizar_botones()

# ======================
# Rival
# ======================
func seleccionar_rival(rival_scene: PackedScene, nombre: String, pos: Vector2 = Vector2(0, 0), anim_path: String = ""):
	if rival != null:
		rival.queue_free()
		rival = null

	rival = rival_scene.instantiate()
	rival.name = nombre
	add_child(rival)
	rival.position = pos

	if anim_path != "":
		var anim_sprite = rival.get_node_or_null(anim_path)
		if anim_sprite:
			anim_sprite.play("idle")

# ======================
# Botones
# ======================
func _on_BotonNivel1_pressed():
	nivel_seleccionado = 1
	seleccionar_rival(minotauro, "minotauro", Vector2(520, 350), "AnimatedSprite2D")

func _on_BotonNivel2_pressed():
	nivel_seleccionado = 2
	seleccionar_rival(mago, "mago", Vector2(520, 350), "nivel2Mago/AnimatedSprite2D")

func _on_BotonNivel3_pressed():
	nivel_seleccionado = 3
	seleccionar_rival(vegueta, "vegueta", Vector2(560, 400), "nivel3Vegueta/AnimatedSprite2D")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu_de_juego.tscn")

func _on_fight_pressed():
	match nivel_seleccionado:
		1:
			get_tree().change_scene_to_file("res://niveles/nivel1/nivel1.tscn")
		2:
			get_tree().change_scene_to_file("res://niveles/nivel2/nivel2.tscn")
		3:
			get_tree().change_scene_to_file("res://niveles/nivel3/nivel3.tscn")
