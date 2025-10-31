extends Node

var niveles_completados = []

func guardar_progreso():
	var config = ConfigFile.new()
	config.set_value("progreso", "niveles_completados", niveles_completados)
	config.save("user://progreso.cfg")

func cargar_progreso():
	var config = ConfigFile.new()
	var err = config.load("user://progreso.cfg")
	if err == OK:
		niveles_completados = config.get_value("progreso", "niveles_completados", [])
	else:
		niveles_completados = []
