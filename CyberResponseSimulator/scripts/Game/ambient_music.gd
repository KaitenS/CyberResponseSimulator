extends AudioStreamPlayer
## Música ambiental de la partida; la pausa del árbol también pausa el audio.
@export var music_enabled: bool = true
@export_range(0.0, 8.0, 0.1) var fade_in_seconds: float = 2.5

func _ready() -> void:
	if not music_enabled or stream == null:
		return
	# Copia local: el bucle no modifica el recurso importado ni otros reproductores.
	if stream is AudioStreamWAV:
		stream = stream.duplicate()
		var music := stream as AudioStreamWAV
		music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music.loop_begin = 0
		music.loop_end = roundi(music.get_length() * music.mix_rate)
	var target_volume := volume_db
	if fade_in_seconds > 0.0:
		volume_db = -60.0
	play()
	if fade_in_seconds > 0.0:
		create_tween().tween_property(self, "volume_db", target_volume, fade_in_seconds)
