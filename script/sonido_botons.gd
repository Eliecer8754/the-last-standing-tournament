extends Node

@onready var click_sound = preload("res://music/heavy-whoosh-06-414584.mp3");

func _ready():
	# Conecta la señal "pressed" de TODOS los botones del árbol
	get_tree().connect("node_added", Callable(self, "_on_node_added"))

func _on_node_added(node):
	if node is Button:
		node.connect("pressed", Callable(self, "_play_click_sound"))

func _play_click_sound():
	print("hola")
	var audio = AudioStreamPlayer.new()
	audio.stream = click_sound
	get_tree().root.add_child(audio)
	audio.play()
	audio.connect("finished", Callable(audio, "queue_free"))
