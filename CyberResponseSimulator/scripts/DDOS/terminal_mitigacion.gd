extends CanvasLayer
class_name TerminalMitigacion
## Consola de mitigacion DDoS.
## Construye toda su interfaz por codigo, asi no necesitas armar la escena a mano.
##
## Uso:
##   1. Añade este nodo a tu escena principal (una sola instancia).
##   2. Desde el objeto "terminal" de la oficina llama a abrir().
##
## Emite pantalla_abierta / pantalla_cerrada para que el player bloquee el
## movimiento y libere el mouse.

signal pantalla_abierta()
signal pantalla_cerrada()

const COL_FONDO := Color(0.04, 0.06, 0.07, 0.97)
const COL_BORDE := Color(0.15, 0.85, 0.55)
const COL_TEXTO := Color(0.75, 1.0, 0.85)
const COL_ALERTA := Color(1.0, 0.45, 0.35)
const COL_AVISO := Color(1.0, 0.8, 0.3)

var _raiz: Control
var _lista_flujos: VBoxContainer
var _telemetria: RichTextLabel
var _consola: RichTextLabel
var _estado: Label
var _manual: RichTextLabel
var _botones_mitigacion: Array[Button] = []
var _boton_general: Button

var _flujo_seleccionado: int = -1
var _indices_visibles: Array[int] = []
var _acumulador := 0.0

var abierta := false


func _ready() -> void:
	layer = 10
	_construir_ui()
	_raiz.visible = false
	set_process(false)

	IncidenteDDoS.log_terminal.connect(_escribir)
	IncidenteDDoS.mitigacion_resultado.connect(_on_mitigacion)
	IncidenteDDoS.incidente_terminado.connect(_on_terminado)


# ============================================================ API

func abrir() -> void:
	if abierta:
		return
	abierta = true
	_raiz.visible = true
	set_process(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refrescar()
	emit_signal("pantalla_abierta")


func cerrar() -> void:
	if not abierta:
		return
	abierta = false
	_raiz.visible = false
	set_process(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("pantalla_cerrada")


func _unhandled_input(event: InputEvent) -> void:
	if abierta and event.is_action_pressed("ui_cancel"):
		cerrar()
		get_viewport().set_input_as_handled()


# ============================================================ LOOP

func _process(delta: float) -> void:
	_acumulador += delta
	if _acumulador >= 0.2:
		_acumulador = 0.0
		_refrescar()


func _refrescar() -> void:
	_refrescar_estado()
	_refrescar_lista_flujos()
	_refrescar_telemetria()
	_refrescar_botones()


func _refrescar_estado() -> void:
	var t: float = IncidenteDDoS.tiempo_restante
	var txt := "TIEMPO %02d:%02d    DISPONIBILIDAD %d%%    " % [
		int(t / 60.0), int(fmod(t, 60.0)), int(IncidenteDDoS.disponibilidad)
	]
	var partes: Array[String] = []
	for id in 3:
		var nombre: String = IncidenteDDoS.NOMBRE_SERVIDOR[id].replace("Servidor de ", "")
		var estado := "OK" if IncidenteDDoS.esta_online(id) else "CAIDO"
		partes.append("%s:%s(%d%%)" % [nombre, estado, int(IncidenteDDoS.carga_de(id))])
	_estado.text = txt + "  |  ".join(partes)

	if IncidenteDDoS.disponibilidad < 35.0:
		_estado.add_theme_color_override("font_color", COL_ALERTA)
	elif IncidenteDDoS.disponibilidad < 70.0:
		_estado.add_theme_color_override("font_color", COL_AVISO)
	else:
		_estado.add_theme_color_override("font_color", COL_TEXTO)


func _refrescar_lista_flujos() -> void:
	var actuales: Array[int] = []
	for ol in IncidenteDDoS.oleadas:
		actuales.append(ol.indice)

	if actuales == _indices_visibles:
		# Solo actualizar etiquetas (estado mitigado)
		for i in _lista_flujos.get_child_count():
			var b := _lista_flujos.get_child(i) as Button
			if i < IncidenteDDoS.oleadas.size():
				b.text = _etiqueta_flujo(IncidenteDDoS.oleadas[i])
		return

	_indices_visibles = actuales
	for c in _lista_flujos.get_children():
		c.queue_free()

	if IncidenteDDoS.oleadas.is_empty():
		var l := Label.new()
		l.text = "Sin flujos anomalos activos."
		l.add_theme_color_override("font_color", COL_TEXTO.darkened(0.3))
		_lista_flujos.add_child(l)
		_flujo_seleccionado = -1
		return

	for ol in IncidenteDDoS.oleadas:
		var b := Button.new()
		b.text = _etiqueta_flujo(ol)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx: int = ol.indice
		b.pressed.connect(func(): _flujo_seleccionado = idx; _refrescar_telemetria())
		_lista_flujos.add_child(b)

	if _flujo_seleccionado not in actuales:
		_flujo_seleccionado = actuales[0]


func _etiqueta_flujo(ol: Dictionary) -> String:
	var destinos: Array[String] = []
	for o in ol.objetivos:
		destinos.append(IncidenteDDoS.NOMBRE_SERVIDOR[o].replace("Servidor de ", ""))
	var marca := "[MITIGADO] " if ol.mitigada else ""
	return "%sFLUJO #%d  ->  %s" % [marca, ol.indice + 1, ", ".join(destinos)]


func _refrescar_telemetria() -> void:
	var ol := _buscar_flujo(_flujo_seleccionado)
	if ol.is_empty():
		_telemetria.text = "[color=#5a7a6a]Seleccione un flujo para analizar su telemetria.[/color]"
		return

	var t: Dictionary = ol.telemetria
	var lineas := PackedStringArray()
	lineas.append("[b]CAPTURA DE TRAFICO - FLUJO #%d[/b]" % (ol.indice + 1))
	lineas.append("")
	lineas.append("Paquetes/s .............. %s" % _fmt_miles(t.paquetes_seg))
	lineas.append("Tamano medio de paquete . %s" % t.tamano_medio)
	lineas.append("Paquetes SYN ............ %s" % t.porcentaje_syn)
	lineas.append("Handshakes completados .. %s" % t.handshakes_completados)
	lineas.append("IPs de origen ........... %s" % t.ips_origen)
	lineas.append("Puerto destino .......... %s" % t.puerto_destino)
	lineas.append("")
	lineas.append("[color=#ffcc55]OBSERVACION:[/color] %s" % t.nota)
	if ol.mitigada:
		lineas.append("")
		lineas.append("[color=#3fe08a]>> Contramedida activa. Flujo bajo control.[/color]")
	_telemetria.text = "\n".join(lineas)


func _refrescar_botones() -> void:
	var bloqueado := IncidenteDDoS.cooldown_restante > 0.0 or not IncidenteDDoS.activo
	for b in _botones_mitigacion:
		b.disabled = bloqueado
	if IncidenteDDoS.cooldown_restante > 0.0:
		_botones_mitigacion[0].get_parent().tooltip_text = "Consola ocupada: %.1f s" % IncidenteDDoS.cooldown_restante
	_boton_general.disabled = not IncidenteDDoS.activo or IncidenteDDoS.apagon_restante > 0.0


func _buscar_flujo(indice: int) -> Dictionary:
	for ol in IncidenteDDoS.oleadas:
		if ol.indice == indice:
			return ol
	return {}


func _fmt_miles(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out


# ============================================================ CALLBACKS

func _on_mitigar(m: int) -> void:
	IncidenteDDoS.aplicar_mitigacion(m)
	_refrescar()


func _on_reinicio_general() -> void:
	IncidenteDDoS.reinicio_general()
	_refrescar()


func _on_mitigacion(exito: bool, mensaje: String) -> void:
	var color := "#3fe08a" if exito else "#ff6b55"
	_consola.append_text("[color=%s]%s[/color]\n" % [color, mensaje])


func _on_terminado(exito: bool, resumen: Dictionary) -> void:
	var titulo := "INCIDENTE CONTENIDO" if exito else "SERVICIO CAIDO"
	_escribir("========================================")
	_escribir(titulo)
	_escribir("Oleadas mitigadas: %d / %d" % [resumen.oleadas_mitigadas, resumen.oleadas_totales])
	_escribir("Falsos positivos: %d" % resumen.falsos_positivos)
	_escribir("Reinicios generales: %d" % resumen.reinicios_generales)
	_escribir("Puntaje: %d" % resumen.puntaje)


func _escribir(texto: String) -> void:
	if _consola:
		_consola.append_text(texto + "\n")


# ============================================================ UI

func _construir_ui() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0, 0, 0, 0.55)
	_raiz.add_child(fondo)

	var marco := PanelContainer.new()
	marco.set_anchors_preset(Control.PRESET_CENTER)
	marco.custom_minimum_size = Vector2(960, 620)
	marco.anchor_left = 0.5
	marco.anchor_top = 0.5
	marco.anchor_right = 0.5
	marco.anchor_bottom = 0.5
	marco.offset_left = -480
	marco.offset_top = -310
	marco.offset_right = 480
	marco.offset_bottom = 310
	marco.add_theme_stylebox_override("panel", _estilo_panel())
	_raiz.add_child(marco)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	marco.add_child(col)

	# --- Cabecera
	var titulo := Label.new()
	titulo.text = "CONSOLA DE MITIGACION  //  SOC - RED CORPORATIVA"
	titulo.add_theme_color_override("font_color", COL_BORDE)
	titulo.add_theme_font_size_override("font_size", 20)
	col.add_child(titulo)

	_estado = Label.new()
	_estado.text = "-"
	_estado.add_theme_color_override("font_color", COL_TEXTO)
	col.add_child(_estado)

	col.add_child(HSeparator.new())

	# --- Cuerpo: flujos | telemetria
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	fila.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fila)

	var izq := VBoxContainer.new()
	izq.custom_minimum_size = Vector2(300, 0)
	fila.add_child(izq)

	var lbl_flujos := Label.new()
	lbl_flujos.text = "FLUJOS DETECTADOS"
	lbl_flujos.add_theme_color_override("font_color", COL_BORDE)
	izq.add_child(lbl_flujos)

	_lista_flujos = VBoxContainer.new()
	_lista_flujos.add_theme_constant_override("separation", 4)
	izq.add_child(_lista_flujos)

	izq.add_child(HSeparator.new())

	var lbl_manual := Label.new()
	lbl_manual.text = "MANUAL DEL ANALISTA"
	lbl_manual.add_theme_color_override("font_color", COL_BORDE)
	izq.add_child(lbl_manual)

	_manual = RichTextLabel.new()
	_manual.bbcode_enabled = true
	_manual.fit_content = false
	_manual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_manual.custom_minimum_size = Vector2(0, 200)
	_manual.text = _texto_manual()
	izq.add_child(_manual)

	var der := VBoxContainer.new()
	der.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(der)

	_telemetria = RichTextLabel.new()
	_telemetria.bbcode_enabled = true
	_telemetria.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_telemetria.custom_minimum_size = Vector2(0, 230)
	_telemetria.add_theme_stylebox_override("normal", _estilo_caja())
	der.add_child(_telemetria)

	var lbl_acc := Label.new()
	lbl_acc.text = "CONTRAMEDIDAS"
	lbl_acc.add_theme_color_override("font_color", COL_BORDE)
	der.add_child(lbl_acc)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	der.add_child(grid)

	for m in [
		IncidenteDDoS.Mitigacion.SYN_COOKIES,
		IncidenteDDoS.Mitigacion.FILTRO_UDP,
		IncidenteDDoS.Mitigacion.RATE_LIMIT,
		IncidenteDDoS.Mitigacion.BLACKHOLE,
	]:
		var b := Button.new()
		b.text = IncidenteDDoS.NOMBRE_MITIGACION[m]
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_mitigar.bind(m))
		grid.add_child(b)
		_botones_mitigacion.append(b)

	_boton_general = Button.new()
	_boton_general.text = "REINICIO GENERAL  (los 3 sistemas caen %d s)" % int(IncidenteDDoS.APAGON_REINICIO_GENERAL)
	_boton_general.custom_minimum_size = Vector2(0, 38)
	_boton_general.add_theme_color_override("font_color", COL_ALERTA)
	_boton_general.pressed.connect(_on_reinicio_general)
	der.add_child(_boton_general)

	_consola = RichTextLabel.new()
	_consola.bbcode_enabled = true
	_consola.scroll_following = true
	_consola.custom_minimum_size = Vector2(0, 110)
	_consola.add_theme_stylebox_override("normal", _estilo_caja())
	der.add_child(_consola)

	var salir := Button.new()
	salir.text = "CERRAR TERMINAL  [ESC]"
	salir.pressed.connect(cerrar)
	col.add_child(salir)


func _texto_manual() -> String:
	return """[color=#9fd8bd]
[b]SYN Flood[/b]
Paquetes minimos (~60 B), 90-99 % SYN, casi ningun handshake completo, IPs falsificadas.
-> [color=#3fe08a]SYN Cookies[/color]

[b]Amplificacion UDP[/b]
Paquetes enormes (>2 KB), origen puerto 53, pocas IPs y son resolutores reales.
-> [color=#3fe08a]Filtro UDP[/color]

[b]HTTP Flood[/b]
Pocos paquetes/s pero handshakes completos, peticiones GET validas repetidas.
-> [color=#3fe08a]Rate limiting[/color]

[b]Botnet distribuida[/b]
Decenas de miles de IPs residenciales reales, trafico mixto, un unico rango AS.
-> [color=#3fe08a]Blackhole[/color]
[/color]"""


func _estilo_panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_FONDO
	sb.border_color = COL_BORDE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(18)
	return sb


func _estilo_caja() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.04, 0.05, 1.0)
	sb.border_color = COL_BORDE.darkened(0.5)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	return sb
