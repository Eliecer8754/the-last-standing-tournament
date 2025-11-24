extends AudioStreamPlayer2D

const LOOP_START = 2.0
const LOOP_END = 4.5

var looping = false
var started = false
var loop_timer : Timer

func start_music():
	started = true
	looping = false
	play()  # Reproduce todo el audio completo

	# Elimina Timer anterior si existía
	if loop_timer:
		loop_timer.queue_free()

	# Crear un Timer para detectar cuando termina la canción
	loop_timer = Timer.new()
	loop_timer.one_shot = true
	loop_timer.wait_time = stream.get_length()
	add_child(loop_timer)
	loop_timer.start()
	loop_timer.connect("timeout", Callable(self, "_start_loop_section"))


func _start_loop_section():
	looping = true
	play(LOOP_START)

	# Timer para el loop exacto
	loop_timer.queue_free()
	loop_timer = Timer.new()
	loop_timer.one_shot = false
	loop_timer.wait_time = LOOP_END - LOOP_START
	add_child(loop_timer)
	loop_timer.start()
	loop_timer.connect("timeout", Callable(self, "_loop_tick"))


func _loop_tick():
	play(LOOP_START)
