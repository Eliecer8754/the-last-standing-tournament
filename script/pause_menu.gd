extends Control

@onready var resume_button = $VBoxContainer/resume
@onready var exit_button = $VBoxContainer/exit

func _ready():
	# Ajustar volumen al cargar
	if AudioPlayer:
		AudioPlayer.volume_db = linear_to_db(Global.music_volume)

func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/niveles.tscn")
