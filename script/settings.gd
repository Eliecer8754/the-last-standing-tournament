extends Control

# ==============================
# Nodos
# ==============================
@onready var option_button = $sliders/VBoxContainer5/OptionButton         # idioma
@onready var titulo = $CanvasLayer/Label
@onready var background_music = $sliders/VBoxContainer2/Label2
@onready var screen_resolution = $sliders/VBoxContainer4/Label3
@onready var language_label = $sliders/VBoxContainer5/Label3
@onready var optionButtonWindow = $sliders/VBoxContainer4/OptionButton   # ventana
@onready var backButton = $VBoxContainer3/back
@onready var music_slider = $sliders/VBoxContainer2/HSlider           # slider volumen

# ==============================
# Traducciones
# ==============================
var translations = {
	0: {"titulo":"Config","game_music":"Musica del Juego","background_music":"Musica de Fondo","sound_effect":"Efectos de Sonido","screen_resolution":"Ventana","language":"Idioma","window_options":["Pantalla Completa","Ventana"],"back":"Volver"},
	1: {"titulo":"Settings","game_music":"Game Music","background_music":"Background Music","sound_effect":"Sound Effects","screen_resolution":"Screen Resolution","language":"Language","window_options":["Fullscreen","Windowed"],"back":"Back"},
	2: {"titulo":"Einstell","game_music":"Spielmusik","background_music":"Hintergrundmusik","sound_effect":"Soundeffekte","screen_resolution":"Fenstermodus","language":"Sprache","window_options":["Vollbild","Fenster"],"back":"Zuruck"},
	3: {"titulo":"Настройки","game_music":"Музыка игры","background_music":"Фоновая музыка","sound_effect":"Звуковые эффекты","screen_resolution":"Разрешение экрана","language":"Язык","window_options":["Полный экран","Окно"],"back":"Назад"},
	4: {"titulo":"设置","game_music":"游戏音乐","background_music":"背景音乐","sound_effect":"音效","screen_resolution":"窗口模式","language":"语言","window_options":["全屏","窗口"],"back":"返回"}
}

# ==============================
# Ready
# ==============================
func _ready():
	# --------------------------
	# Configurar OptionButton Idioma
	# --------------------------
	option_button.clear()
	option_button.add_item("Espanol")	
	option_button.add_item("English")	
	option_button.add_item("Deutsch")	
	option_button.add_item("Русский")	
	option_button.add_item("中文")
	if not option_button.is_connected("item_selected", Callable(self, "_on_option_button_item_selected")):
		option_button.connect("item_selected", Callable(self, "_on_option_button_item_selected"))

	# --------------------------
	# Configurar OptionButton Ventana
	# --------------------------
	if not optionButtonWindow.is_connected("item_selected", Callable(self, "_on_option_button_item_selected_window")):
		optionButtonWindow.connect("item_selected", Callable(self, "_on_option_button_item_selected_window"))

	# --------------------------
	# Configurar slider música
	# --------------------------
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.step = 1
	music_slider.value = Global.music_volume * 100
	music_slider.connect("value_changed", Callable(self, "_on_music_slider_value_changed"))

	# --------------------------
	# Aplicar idioma y ventana guardados
	# --------------------------
	option_button.select(Global.language)
	optionButtonWindow.select(Global.pantalla)
	change_language()
	apply_window_mode(Global.pantalla)

	# Ajustar volumen actual
	AudioPlayer.volume_db = linear_to_db(Global.music_volume)

# ==============================
# Funciones de OptionButton
# ==============================
func _on_option_button_item_selected(index: int):
	Global.language = index
	Global.value_changed.emit(index)
	change_language()

func _on_option_button_item_selected_window(index: int) -> void:
	Global.pantalla = index
	apply_window_mode(index)

# ==============================
# Función para aplicar idioma
# ==============================
func change_language():
	var lang_index = Global.language
	if lang_index == null or lang_index < 0 or lang_index >= translations.size():
		lang_index = 0	# fallback a Español

	titulo.text = translations[lang_index]["titulo"]
	background_music.text = translations[lang_index]["background_music"]
	screen_resolution.text = translations[lang_index]["screen_resolution"]
	language_label.text = translations[lang_index]["language"]
	backButton.text = translations[lang_index]["back"]

	# Actualizar OptionButton de ventana según idioma
	optionButtonWindow.clear()
	for text in translations[lang_index]["window_options"]:
		optionButtonWindow.add_item(text)
	optionButtonWindow.select(Global.pantalla)

# ==============================
# Función para aplicar modo de ventana
# ==============================
func apply_window_mode(index: int):
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_FULLSCREEN)
		1:
			DisplayServer.window_set_mode(DisplayServer.WindowMode.WINDOW_MODE_WINDOWED)

# ==============================
# Función para cambiar volumen de música
# ==============================
func _on_music_slider_value_changed(value):
	var volume = value / 100.0
	Global.music_volume = volume
	AudioPlayer.volume_db = linear_to_db(volume)

# ==============================
# Botón volver
# ==============================
func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/menu_de_juego.tscn")
