extends CanvasLayer
class_name HudDDoS
## HUD permanente durante el incidente DDoS.
## Muestra tiempo, disponibilidad, estado de los tres sistemas y avisos.
## Tambien da feedback inmediato (flash de pantalla completa + camara)
## cuando el jugador mitiga bien o mal, y cuando algo cae.
## Diseño editable en scenes/Incidents/DDOS/DDoSHudLayout.tscn.

const HUD_LAYOUT := preload("res://scenes/Incidents/DDOS/DDoSHudLayout.tscn")
const COL_OK := Color(0.5, 0.78, 0.6)
const COL_AVISO := Color(1.0, 0.8, 0.3)
const COL_MAL := Color(1.0, 0.35, 0.3)

var _tutorial_card: PanelContainer
var _tarjeta: PanelContainer
var _raiz: Control
var _reloj: Label
var _punto: Indicador
var _barra_fondo: Panel
var _barra_relleno: Panel
var _barra_estilo: StyleBoxFlat
var _disp_visual := 100.0
var _indicadores: Array[Indicador] = []
var _chips: Array[Label] = []
var _aviso_panel: PanelContainer
var _aviso: Label
var _aviso_t := 0.0
var _aviso_id := 0      # para que un aviso viejo no apague uno nuevo
var _sesion := 0        # idem para ocultar el HUD al terminar
var _parpadeo := 0.0

var _flash: ColorRect
var _flash_t := 0.0
var _flash_duracion := 0.35


func _ready() -> void:
	layer = 5
	_construir()
	_raiz.visible = false
	set_process(false)

	IncidenteDDoS.incidente_iniciado.connect(_on_iniciado)
	IncidenteDDoS.incidente_terminado.connect(_on_terminado)
	IncidenteDDoS.oleada_iniciada.connect(_on_oleada)
	IncidenteDDoS.servidor_estado_cambiado.connect(_on_servidor)
	IncidenteDDoS.mitigacion_resultado.connect(_on_mitigacion)
	# Si la partida termina con el ataque en curso, nada del DDoS debe quedar
	# flotando sobre la pantalla de resultados ni en la partida siguiente.
	GameManager.game_ended.connect(_ocultar_todo)


func _process(delta: float) -> void:
	_parpadeo += delta

	var t: float = IncidenteDDoS.tiempo_restante
	_reloj.text = "%02d:%02d" % [int(t / 60.0), int(fmod(t, 60.0))]
	_punto.visible = true
	_punto.color = COL_MAL if fmod(_parpadeo, 1.2) < 0.7 or DDoSEnMapa.reducir_efectos else COL_MAL.darkened(0.6)
	_punto.queue_redraw()

	# Barra fina que se desliza suavemente hacia el valor real (sin numero).
	_disp_visual = lerpf(_disp_visual, IncidenteDDoS.disponibilidad, clampf(delta * 6.0, 0.0, 1.0))
	var c := COL_OK
	if IncidenteDDoS.disponibilidad < 35.0:
		c = COL_MAL
	elif IncidenteDDoS.disponibilidad < 70.0:
		c = COL_AVISO
	_barra_estilo.bg_color = c
	_barra_relleno.size.x = maxf(6.0, _barra_fondo.size.x * clampf(_disp_visual / 100.0, 0.0, 1.0))

	# Cada sistema: forma + color (circulo OK, triangulo carga alta, cruz caido).
	for id in 3:
		var ind := _indicadores[id]
		if IncidenteDDoS.esta_online(id):
			var alta: bool = IncidenteDDoS.carga_de(id) >= 60.0
			ind.forma = Indicador.Forma.TRIANGULO if alta else Indicador.Forma.CIRCULO
			ind.color = COL_AVISO if alta else COL_OK
			_chips[id].modulate = Color(0.9, 0.93, 0.97)
		else:
			ind.forma = Indicador.Forma.CRUZ
			var vivo := fmod(_parpadeo, 0.7) < 0.45 or DDoSEnMapa.reducir_efectos
			ind.color = COL_MAL if vivo else COL_MAL.darkened(0.6)
			_chips[id].modulate = COL_MAL
		ind.queue_redraw()

	if _aviso_t > 0.0:
		_aviso_t -= delta
		_aviso_panel.visible = true
	else:
		_aviso_panel.visible = false

	if _flash_t > 0.0:
		_flash_t -= delta
		_flash.visible = true
		_flash.modulate.a = clampf(_flash_t / _flash_duracion, 0.0, 1.0) * 0.35
	else:
		_flash.visible = false


func mostrar_aviso(texto: String, segundos := 4.0) -> void:
	_aviso.text = texto
	_aviso_panel.reset_size()
	_layout_cards()
	_aviso_t = segundos
	_aviso_panel.visible = true
	# Respaldo: el aviso se apaga por su propio reloj aunque _process este
	# detenido (pausa, manual abierto, HUD sin procesar).
	_aviso_id += 1
	var mi_id := _aviso_id
	await get_tree().create_timer(segundos + 0.2, true, false, true).timeout
	if mi_id == _aviso_id:
		_aviso_t = 0.0
		_aviso_panel.visible = false


func _ocultar_todo() -> void:
	_aviso_id += 1
	_sesion += 1
	_aviso_t = 0.0
	_flash_t = 0.0
	_aviso_panel.visible = false
	_flash.visible = false
	_raiz.visible = false
	set_process(false)


## Destello breve de pantalla completa. color=verde para exito, rojo para fallo.
func destello(color: Color) -> void:
	if DDoSEnMapa.reducir_efectos:
		return
	_flash.color = color
	_flash_t = _flash_duracion
	_flash.visible = true
	_flash.modulate.a = 0.35


# --------------------------------------------------------- SEÑALES

func _on_iniciado() -> void:
	_sesion += 1
	_raiz.visible = true
	set_process(true)
	mostrar_aviso("ATAQUE DDoS DETECTADO\nDirijase a la sala de servidores", 5.0)


func _on_terminado(exito: bool, _r: Dictionary) -> void:
	mostrar_aviso("INCIDENTE CONTENIDO" if exito else "SERVICIO CAIDO", 6.0)
	var sesion := _sesion
	await get_tree().create_timer(6.0, true, false, true).timeout
	if sesion != _sesion:
		return   # empezo otro ataque (o se oculto todo) mientras tanto
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
	destello(COL_MAL)
	match id:
		IncidenteDDoS.Servidor.ALERTAS:
			mostrar_aviso("ALERTAS OFFLINE\nNo recibira notificaciones de nuevos incidentes", 4.0)
		IncidenteDDoS.Servidor.CAMARAS:
			mostrar_aviso("CAMARAS OFFLINE\nEficiencia reducida. Velocidad de jornada x1.5", 4.0)
		IncidenteDDoS.Servidor.MONITOREO:
			mostrar_aviso("MONITOREO OFFLINE\nSin bono de red. Los aciertos siguen en el cuaderno.", 4.0)


func _on_mitigacion(exito: bool, _mensaje: String) -> void:
	destello(COL_OK if exito else COL_MAL)


# --------------------------------------------------------- UI

func _construir() -> void:
	_raiz = HUD_LAYOUT.instantiate() as Control
	add_child(_raiz)
	_flash = _raiz.get_node("Flash")
	_tarjeta = _raiz.get_node("StatusCard")
	_tutorial_card = _raiz.get_node("TutorialCard")
	_tutorial_card.minimum_size_changed.connect(_fit_tutorial)
	_reloj = _tarjeta.get_node("Body/Header/Clock")
	_punto = _attach_indicator(_tarjeta.get_node("Body/Header/Light"))
	_barra_fondo = _tarjeta.get_node("Body/Availability")
	_barra_relleno = _barra_fondo.get_node("Fill")
	_barra_estilo = _barra_relleno.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_barra_relleno.add_theme_stylebox_override("panel", _barra_estilo)
	_barra_fondo.resized.connect(func(): _barra_relleno.size.y = _barra_fondo.size.y)
	for name in ["Alerts", "Cameras", "Monitoring"]:
		var item := _tarjeta.get_node("Body/Systems/" + name)
		_indicadores.append(_attach_indicator(item.get_node("Light")))
		_chips.append(item.get_node("Text"))
	_aviso_panel = _raiz.get_node("NoticeCard")
	_aviso = _aviso_panel.get_node("Body/Message")
	_aviso_panel.visible = false
	get_viewport().size_changed.connect(_layout_cards)
	_layout_cards()


func _attach_indicator(holder: Control) -> Indicador:
	holder.get_node("PreviewMark").hide()
	var indicator := Indicador.new()
	indicator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(indicator)
	return indicator


func _layout_cards() -> void:
	if _tarjeta == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	# Dos columnas en pantalla normal; una columna en ventanas estrechas.
	_tarjeta.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tarjeta.size.x = 320.0
	_tarjeta.position = Vector2(maxf(24.0, viewport_width - 344.0), 80.0) if viewport_width >= 820.0 else Vector2(24, 230)
	_aviso_panel.position = Vector2(24, 230) if viewport_width >= 820.0 else Vector2(24, 230 + maxf(_tarjeta.size.y, 120.0) + 16)
	_tutorial_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tutorial_card.position = Vector2(maxf(24.0, viewport_width - 344.0), 80 + maxf(_tarjeta.size.y, 120.0) + 16) if viewport_width >= 820.0 else Vector2(24, _aviso_panel.position.y + maxf(_aviso_panel.size.y, 100.0) + 16)


func _fit_tutorial() -> void:
	_tutorial_card.reset_size()


func get_tutorial_card() -> PanelContainer:
	return _tutorial_card


## Icono pequeno dibujado por codigo (no depende de la fuente).
## Circulo = OK, triangulo = carga alta, cruz = caido: se distinguen sin color.
class Indicador extends Control:
	enum Forma { CIRCULO, TRIANGULO, CRUZ }
	var forma := Forma.CIRCULO
	var color := Color(0.35, 1.0, 0.6)

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) / 2.0
		match forma:
			Forma.CIRCULO:
				draw_circle(c, r, color)
			Forma.TRIANGULO:
				draw_colored_polygon(PackedVector2Array([
					Vector2(c.x, c.y - r), Vector2(c.x + r, c.y + r), Vector2(c.x - r, c.y + r)]), color)
			Forma.CRUZ:
				draw_line(c + Vector2(-r, -r), c + Vector2(r, r), color, 2.5)
				draw_line(c + Vector2(-r, r), c + Vector2(r, -r), color, 2.5)
