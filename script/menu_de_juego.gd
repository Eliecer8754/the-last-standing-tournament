extends Control

# ======================
# Labels del menú
# ======================
@onready var play_label = $VBoxContainer/play
@onready var settings_label = $VBoxContainer/settings
@onready var exit_label = $VBoxContainer/exit
@onready var titulo = $CanvasLayer/Label

# ======================
# Traducciones
# ======================
var translations = {
	0: { "titulo": "Torneo del Ultimo\nEn Pie", "play": "Jugar", "settings": "Configuraciones", "exit": "Salir" },
	1: { "titulo": "The Last Standing\nTournament", "play": "Play", "settings": "Settings", "exit": "Exit" },
	2: { "titulo": "Turnier der Letzten\nStehenden", "play": "Spielen", "settings": "Einstellungen", "exit": "Beenden" },
	3: { "titulo": "Турнир Последних\nВыживших", "play": "Играть", "settings": "Настройки", "exit": "Выход" },
	4: { "titulo": "最后的站立\n锦标赛", "play": "玩", "settings": "设置", "exit": "退出" }
}
var language_codes = [0, 1, 2, 3, 4]

# ======================
# Funciones de menú
# ======================
func _ready():
	change_language()
	AudioPlayer.play_music_level()

func change_language():
	var lang_index = Global.language
	if lang_index == null or lang_index < 0 or lang_index >= language_codes.size():
		lang_index = 0
	if titulo != null:
		titulo.text = translations[lang_index]["titulo"]
	if play_label != null:
		play_label.text = translations[lang_index]["play"]
	if settings_label != null:
		settings_label.text = translations[lang_index]["settings"]
	if exit_label != null:
		exit_label.text = translations[lang_index]["exit"]

func _on_play_pressed():
	# Aquí solo cambiamos a la escena de selección de niveles
	get_tree().change_scene_to_file("res://scenes/niveles.tscn")

func _on_settings_pressed():
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_exit_pressed():
	get_tree().quit()
