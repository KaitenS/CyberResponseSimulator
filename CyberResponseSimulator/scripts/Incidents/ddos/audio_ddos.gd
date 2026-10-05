extends Node
## AUTOLOAD -> Nombre sugerido: "AudioDDoS"
##
## Genera por codigo todo el audio del incidente DDoS: no usa ningun
## archivo .wav/.ogg externo. Usa AudioStreamGenerator para sintetizar
## tonos simples en tiempo real:
##   - Un zumbido de fondo (hum) que sube de tono con la carga maxima
##     de los tres servidores.
##   - Un pitido corto cada vez que llega una oleada nueva.
##   - Un tono de confirmacion al mitigar bien, y un tono grave al fallar.
##   - Una alarma tipo sirena mientras algun servidor este caido.
##   - Silencio total mientras dura el apagon del reinicio general
##     (el silencio ahi es intencional: genera tension, igual que en FNAF).
##
## No requiere ningun nodo en la escena: todo se crea solo en _ready().

const MIX_RATE := 22050.0

var _hum_player: AudioStreamPlayer
var _hum_playback: AudioStreamGeneratorPlayback
var _hum_activo := false
var _hum_fase := 0.0
var _hum_frecuencia := 80.0

var _beep_player: AudioStreamPlayer
var _beep_playback: AudioStreamGeneratorPlayback
var _beep_cola: Array = []

var _alarma_player: AudioStreamPlayer
var _alarma_playback: AudioStreamGeneratorPlayback
var _alarma_activa := false
var _alarma_fase := 0.0
var _alarma_lfo_fase := 0.0


func _ready() -> void:
	_hum_player = _crear_player(-20.0)
	_beep_player = _crear_player(-6.0)
	_alarma_player = _crear_player(-10.0)

	IncidenteDDoS.incidente_iniciado.connect(_on_iniciado)
	IncidenteDDoS.incidente_terminado.connect(_on_terminado)
	IncidenteDDoS.oleada_iniciada.connect(_on_oleada)
	IncidenteDDoS.servidor_estado_cambiado.connect(_on_servidor_estado)
	IncidenteDDoS.mitigacion_resultado.connect(_on_mitigacion)

	set_process(false)


func _crear_player(volumen_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.25
	p.stream = gen
	p.volume_db = volumen_db
	p.bus = "Master"
	add_child(p)
	return p


# ================================================================ EVENTOS

func _on_iniciado() -> void:
	_hum_activo = true
	_hum_frecuencia = 80.0
	_hum_fase = 0.0
	_hum_player.play()
	_hum_playback = _hum_player.get_stream_playback()
	set_process(true)


func _on_terminado(_exito: bool, _resumen: Dictionary) -> void:
	_hum_activo = false
	_alarma_activa = false
	_hum_player.stop()
	_alarma_player.stop()
	_beep_cola.clear()
	set_process(false)


func _on_oleada(_indice: int, _vector: int, _objetivos: Array, _telemetria: Dictionary) -> void:
	# Dos pitidos cortos de alerta, con un silencio breve en medio.
	_encolar_beep(880.0, 0.09)
	_encolar_beep(0.0, 0.06)
	_encolar_beep(880.0, 0.09)


func _on_servidor_estado(_id: int, _online: bool) -> void:
	var alguno_caido := false
	for s in IncidenteDDoS.servidores:
		if not s.online:
			alguno_caido = true
			break

	_alarma_activa = alguno_caido
	if _alarma_activa and not _alarma_player.playing:
		_alarma_player.play()
		_alarma_playback = _alarma_player.get_stream_playback()
	elif not _alarma_activa:
		_alarma_player.stop()


func _on_mitigacion(exito: bool, _mensaje: String) -> void:
	if exito:
		_encolar_beep(660.0, 0.08)
	else:
		_encolar_beep(150.0, 0.28) # tono grave: contramedida equivocada


func _encolar_beep(frecuencia: float, duracion_seg: float) -> void:
	if not _beep_player.playing:
		_beep_player.play()
		_beep_playback = _beep_player.get_stream_playback()
	_beep_cola.append({
		"freq": frecuencia,
		"restante": int(duracion_seg * MIX_RATE),
		"fase": 0.0,
	})


# ================================================================ SINTESIS

func _process(_delta: float) -> void:
	var silencio_total := IncidenteDDoS.activo and IncidenteDDoS.apagon_restante > 0.0

	if _hum_activo and _hum_playback:
		_rellenar_hum(silencio_total)

	if _beep_playback:
		_rellenar_beep()

	if _alarma_playback:
		if _alarma_activa and not silencio_total:
			_rellenar_alarma()
		elif _alarma_player.playing:
			_rellenar_silencio(_alarma_playback)


func _rellenar_hum(silencio: bool) -> void:
	var carga_max := 0.0
	for s in IncidenteDDoS.servidores:
		carga_max = maxf(carga_max, s.carga)

	var objetivo_freq := lerpf(70.0, 240.0, clampf(carga_max / 100.0, 0.0, 1.0))
	_hum_frecuencia = lerpf(_hum_frecuencia, objetivo_freq, 0.04)

	var amplitud := 0.0 if silencio else lerpf(0.025, 0.11, clampf(carga_max / 100.0, 0.0, 1.0))

	var frames: int = _hum_playback.get_frames_available()
	for i in frames:
		var muestra := sin(_hum_fase) * amplitud
		_hum_playback.push_frame(Vector2(muestra, muestra))
		_hum_fase += TAU * _hum_frecuencia / MIX_RATE
		if _hum_fase > TAU:
			_hum_fase -= TAU


func _rellenar_beep() -> void:
	var frames: int = _beep_playback.get_frames_available()
	for i in frames:
		if _beep_cola.is_empty():
			_beep_playback.push_frame(Vector2.ZERO)
			continue

		var actual: Dictionary = _beep_cola[0]
		var muestra := 0.0
		if actual.freq > 0.0:
			muestra = sin(actual.fase) * 0.35
			actual.fase += TAU * actual.freq / MIX_RATE
			if actual.fase > TAU:
				actual.fase -= TAU

		actual.restante -= 1
		_beep_playback.push_frame(Vector2(muestra, muestra))

		if actual.restante <= 0:
			_beep_cola.pop_front()
		else:
			_beep_cola[0] = actual


func _rellenar_alarma() -> void:
	var frames: int = _alarma_playback.get_frames_available()
	for i in frames:
		var lfo := sin(_alarma_lfo_fase)
		var freq := 480.0 + 220.0 * lfo
		var muestra := sin(_alarma_fase) * 0.2

		_alarma_playback.push_frame(Vector2(muestra, muestra))

		_alarma_fase += TAU * freq / MIX_RATE
		if _alarma_fase > TAU:
			_alarma_fase -= TAU

		_alarma_lfo_fase += TAU * 1.4 / MIX_RATE
		if _alarma_lfo_fase > TAU:
			_alarma_lfo_fase -= TAU


func _rellenar_silencio(playback: AudioStreamGeneratorPlayback) -> void:
	var frames: int = playback.get_frames_available()
	for i in frames:
		playback.push_frame(Vector2.ZERO)
