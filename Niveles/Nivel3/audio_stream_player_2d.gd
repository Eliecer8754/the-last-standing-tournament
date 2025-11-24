extends AudioStreamPlayer2D

func _ready() -> void:
	stream.loop = true
	play()
