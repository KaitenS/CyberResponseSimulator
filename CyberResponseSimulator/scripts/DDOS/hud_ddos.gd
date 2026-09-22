extends CanvasLayer
class_name HudDDoS
## HUD permanente durante el incidente DDoS.
## Muestra tiempo, disponibilidad, estado de los tres sistemas y avisos.
## Se construye por codigo: basta con añadirlo a la escena principal.

const COL_OK := Color(0.35, 1.0, 0.6)
const COL_AVISO := Color(1.0, 0.8, 0.3)
const COL_MAL := Color(1.0, 0.35, 0.3)

var _raiz: Control
var _reloj: Label
var _barra: ProgressBar
var _chips: Array[Label] = []
var _aviso: Label
var _aviso_t := 0.0
var _parpadeo := 0.0


func _ready() -> void:
	layer = 5
	_construir()
	_raiz.visible = false
	set_process(false)

	IncidenteDDoS.incidente_iniciado.connect(_on_iniciado)
	IncidenteDDoS.incidente_terminado.connect(_on_terminado)
	IncidenteDDoS.oleada_iniciada.connect(_on_oleada)
	IncidenteDDoS.servidor_estado_cambiado.connect(_on_servidor)


func _process(delta: float) -> void:
	_parpadeo += delta

	var t: float = IncidenteDDoS.tiempo_restante
	_reloj.text = "ATAQUE EN CURSO   %02d:%02d" % [int(t / 60.0), int(fmod(t, 60.0))]

	_barra.value = IncidenteDDoS.disponibilidad
	var c := COL_OK
	if IncidenteDDoS.disponibilidad < 35.0:
		c = COL_MAL
	elif IncidenteDDoS.disponibilidad < 70.0:
		c = COL_AVISO
	_barra.modulate = c

	for id in 3:
		var nombre: String = IncidenteDDoS.NOMBRE_SERVIDOR[id].replace("Servidor de ", "").to_upper()
		if IncidenteDDoS.esta_online(id):
			var carga := IncidenteDDoS.carga_de(id)
			_chips[id].text = "%s  %d%%" % [nombre, int(carga)]
			_chips[id].modulate = COL_OK if carga < 60.0 else COL_AVISO
		else:
			_chips[id].text = "%s  OFFLINE" % nombre
			_chips[id].modulate = COL_MAL if fmod(_parpadeo, 0.7) < 0.45 else COL_MAL.darkened(0.6)

	if _aviso_t > 0.0:
		_aviso_t -= delta
		_aviso.visible = true
	else:
		_aviso.visible = false


func mostrar_aviso(texto: String, segundos := 4.0) -> void:
	_aviso.text = texto
	_aviso_t = segundos


# --------------------------------------------------------- SEÑALES

func _on_iniciado() -> void:
	_raiz.visible = true
	set_process(true)
	mostrar_aviso("ATAQUE DDoS DETECTADO\nDirijase a la sala de servidores", 5.0)


func _on_terminado(exito: bool, _r: Dictionary) -> void:
	mostrar_aviso("INCIDENTE CONTENIDO" if exito else "SERVICIO CAIDO", 6.0)
	await get_tree().create_timer(6.0).timeout
	_raiz.visible = false
	set_process(false)


func _on_oleada(_i: int, _vector: int, objetivos: Array, _t: Dictionary) -> void:
	var destinos: Array[String] = []
	for o in objetivos:
		destinos.append(IncidenteDDoS.NOMBRE_SERVIDOR[o].replace("Servidor de ", ""))
	mostrar_aviso("NUEVO PICO DE TRAFICO -> %s" % ", ".join(destinos), 3.5)


func _on_servidor(id: int, online: bool) -> void:
	if online:
		return
	match id:
		IncidenteDDoS.Servidor.ALERTAS:
			mostrar_aviso("ALERTAS OFFLINE\nNo recibira notificaciones de nuevos incidentes", 4.0)
		IncidenteDDoS.Servidor.CAMARAS:
			mostrar_aviso("CAMARAS OFFLINE\nEficiencia reducida. Velocidad de jornada x1.5", 4.0)
		IncidenteDDoS.Servidor.MONITOREO:
			mostrar_aviso("MONITOREO OFFLINE\nAlgunas acciones no otorgaran puntaje", 4.0)


# --------------------------------------------------------- UI

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	var caja := VBoxContainer.new()
	caja.position = Vector2(24, 20)
	caja.custom_minimum_size = Vector2(320, 0)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(caja)

	_reloj = Label.new()
	_reloj.add_theme_font_size_override("font_size", 22)
	_reloj.add_theme_color_override("font_color", COL_MAL)
	caja.add_child(_reloj)

	var sub := Label.new()
	sub.text = "DISPONIBILIDAD DEL SERVICIO"
	sub.add_theme_font_size_override("font_size", 12)
	caja.add_child(sub)

	_barra = ProgressBar.new()
	_barra.min_value = 0
	_barra.max_value = 100
	_barra.value = 100
	_barra.show_percentage = true
	_barra.custom_minimum_size = Vector2(300, 20)
	caja.add_child(_barra)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	caja.add_child(fila)
	for i in 3:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 13)
		fila.add_child(l)
		_chips.append(l)

	_aviso = Label.new()
	_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_aviso.anchor_left = 0.5
	_aviso.anchor_right = 0.5
	_aviso.offset_left = -400
	_aviso.offset_right = 400
	_aviso.offset_top = 120
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_size_override("font_size", 26)
	_aviso.add_theme_color_override("font_color", COL_MAL)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 6)
	_aviso.visible = false
	_raiz.add_child(_aviso)
