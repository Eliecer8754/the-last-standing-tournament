extends Label

@export var min_scale: float = 1.0
@export var max_scale: float = 1.1
@export var grow_speed: float = 0.25
@export var pause_time: float = 3

var growing: bool = true
var paused: bool = false

func _process(delta: float) -> void:
	if paused:
		return

	if growing:
		scale += Vector2.ONE * grow_speed * delta
		if scale.x >= max_scale:
			scale = Vector2.ONE * max_scale
			growing = false
	else:
		scale -= Vector2.ONE * grow_speed * delta
		if scale.x <= min_scale:
			scale = Vector2.ONE * min_scale
			paused = true
			_start_pause()

func _start_pause():
	var t = Timer.new()
	t.wait_time = pause_time
	t.one_shot = true
	t.connect("timeout", Callable(self, "_on_pause_timeout"))
	add_child(t)
	t.start()

func _on_pause_timeout():
	paused = false
	growing = true
