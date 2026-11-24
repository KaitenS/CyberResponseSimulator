extends CanvasLayer
class_name HudDDoS
## HUD permanente durante el incidente DDoS.
## Muestra tiempo, disponibilidad, estado de los tres sistemas y avisos.
## Tambien da feedback inmediato (flash de pantalla completa + camara)
## cuando el jugador mitiga bien o mal, y cuando algo cae.
## Se construye por codigo: basta con añadirlo a la escena principal.

const COL_OK := Color(0.35, 1.0, 0.6)
const COL_AVISO := Color(1.0, 0.8, 0.3)
const COL_MAL := Color(1.0, 0.35, 0.3)

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
	_aviso_t = segundos


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
	destello(COL_MAL)
	match id:
		IncidenteDDoS.Servidor.ALERTAS:
			mostrar_aviso("ALERTAS OFFLINE\nNo recibira notificaciones de nuevos incidentes", 4.0)
		IncidenteDDoS.Servidor.CAMARAS:
			mostrar_aviso("CAMARAS OFFLINE\nEficiencia reducida. Velocidad de jornada x1.5", 4.0)
		IncidenteDDoS.Servidor.MONITOREO:
			mostrar_aviso("MONITOREO OFFLINE\nAlgunas acciones no otorgaran puntaje", 4.0)


func _on_mitigacion(exito: bool, _mensaje: String) -> void:
	destello(COL_OK if exito else COL_MAL)


# --------------------------------------------------------- UI

func _construir() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = COL_OK
	_flash.visible = false
	_raiz.add_child(_flash)

	# --- Tarjeta compacta arriba a la izquierda
	var tarjeta := PanelContainer.new()
	tarjeta.position = Vector2(20, 18)
	tarjeta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.1, 0.78)
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	tarjeta.add_theme_stylebox_override("panel", sb)
	_raiz.add_child(tarjeta)

	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(250, 0)
	caja.add_theme_constant_override("separation", 8)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(caja)

	# Fila 1: punto parpadeante + titulo + reloj
	var fila1 := HBoxContainer.new()
	fila1.add_theme_constant_override("separation", 8)
	fila1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(fila1)
	_punto = Indicador.new()
	_punto.custom_minimum_size = Vector2(10, 10)
	_punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila1.add_child(_punto)
	var titulo := Label.new()
	titulo.text = "ATAQUE DDoS"
	titulo.add_theme_font_size_override("font_size", 13)
	titulo.add_theme_color_override("font_color", Color(0.72, 0.78, 0.85))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila1.add_child(titulo)
	_reloj = Label.new()
	_reloj.add_theme_font_size_override("font_size", 18)
	_reloj.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	fila1.add_child(_reloj)

	# Fila 2: barra de disponibilidad fina y redondeada, sin porcentaje
	_barra_fondo = Panel.new()
	_barra_fondo.custom_minimum_size = Vector2(0, 6)
	_barra_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = Color(1, 1, 1, 0.09)
	sbf.set_corner_radius_all(3)
	_barra_fondo.add_theme_stylebox_override("panel", sbf)
	caja.add_child(_barra_fondo)
	_barra_relleno = Panel.new()
	_barra_relleno.position = Vector2.ZERO
	_barra_relleno.size = Vector2(250, 6)
	_barra_relleno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_estilo = StyleBoxFlat.new()
	_barra_estilo.bg_color = COL_OK
	_barra_estilo.set_corner_radius_all(3)
	_barra_relleno.add_theme_stylebox_override("panel", _barra_estilo)
	_barra_fondo.add_child(_barra_relleno)
	_barra_fondo.resized.connect(func(): _barra_relleno.size.y = _barra_fondo.size.y)

	# Fila 3: estado de los 3 sistemas, solo con iconos y nombre corto
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(fila)
	for i in 3:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 5)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(item)
		var ind := Indicador.new()
		ind.custom_minimum_size = Vector2(10, 10)
		ind.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(ind)
		_indicadores.append(ind)
		var l := Label.new()
		l.text = IncidenteDDoS.NOMBRE_SERVIDOR[i].replace("Servidor de ", "").to_upper()
		l.add_theme_font_size_override("font_size", 12)
		item.add_child(l)
		_chips.append(l)

	# --- Aviso central: pastilla translucida
	_aviso_panel = PanelContainer.new()
	_aviso_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_aviso_panel.anchor_left = 0.5
	_aviso_panel.anchor_right = 0.5
	_aviso_panel.offset_left = -320
	_aviso_panel.offset_right = 320
	_aviso_panel.offset_top = 90
	_aviso_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_aviso_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sba := StyleBoxFlat.new()
	sba.bg_color = Color(0.06, 0.07, 0.1, 0.82)
	sba.border_color = Color(COL_MAL, 0.55)
	sba.set_border_width_all(1)
	sba.border_width_left = 4
	sba.set_corner_radius_all(10)
	sba.content_margin_left = 18
	sba.content_margin_right = 18
	sba.content_margin_top = 10
	sba.content_margin_bottom = 10
	_aviso_panel.add_theme_stylebox_override("panel", sba)
	_aviso_panel.visible = false
	_raiz.add_child(_aviso_panel)

	_aviso = Label.new()
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.custom_minimum_size = Vector2(560, 0)
	_aviso.add_theme_font_size_override("font_size", 18)
	_aviso.add_theme_color_override("font_color", Color(0.97, 0.9, 0.9))
	_aviso_panel.add_child(_aviso)


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
