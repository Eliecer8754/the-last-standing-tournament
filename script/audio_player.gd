extends AudioStreamPlayer

const level_music = preload("res://music/epic-background-music-for-short-vlog-video-hot-game-dramatic-music-160297.mp3")

func _play_music(music: AudioStream, volume: float = 1.0):
	if stream == music:
		return
	
	stream = music
	volume_db = linear_to_db(volume)
	play()

func play_music_level():
	_play_music(level_music, Global.music_volume)

# Nueva función para detener la música
func stop_music():
	stop()
