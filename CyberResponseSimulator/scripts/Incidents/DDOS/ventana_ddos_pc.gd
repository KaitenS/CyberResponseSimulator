extends Control
class_name VentanaDDoSPC
## Ventana "Servidores" que vive DENTRO de la pantalla del PC (CyberDesk).
##
## - Se abre con UN clic en el icono "Servidores", haya ataque o no.
## - Sin ataque: muestra los 3 servidores operativos y el manual del analista.
## - Con ataque: flujos detectados, telemetria, contramedidas, reinicio general
##   y registro, igual que la consola del incidente.
##
## Los clics NO usan los botones de Godot: el PC virtual envia clics sueltos
## (sin movimiento de mouse), asi que CyberDesk.gd le pasa cada clic a
## procesar_click() y aqui se decide que se toco. Es el mismo metodo que ya
## usan las demas ventanas del escritorio.

const POS := Vector2(20.0, 112.0)
const TAM := Vector2(600.0, 430.0)

## El cursor del PC dibuja la flecha con la punta arriba-izquierda, pero el
## clic se registra en el centro del sprite. Se prueban las dos posiciones
## para que "donde apunta la flecha" sea donde cae el clic.
const OFFSET_PUNTA := Vector2(12.0, 12.0)

const FUENTE_RUTA := "res://assets/Fonts/VCR_OSD_MONO_1.001.ttf"

const COL_MARCO := Color(0.90, 0.90, 0.93)
const COL_TITULO := Color(0.27, 0.40, 0.78)
const COL_FONDO := Color(0.03, 0.05, 0.07)
const COL_BORDE := Color(0.15, 0.85, 0.55)
const COL_TEXTO := Color(0.75, 1.0, 0.85)
const COL_TENUE := Color(0.45, 0.62, 0.55)
const COL_OK := Color(0.25, 1.0, 0.45)
const COL_AVISO := Color(1.0, 0.8, 0.3)
const COL_ALERTA := Color(1.0, 0.4, 0.35)

const MAX_FLUJOS := 4
const LINEAS_LOG := 5
const CARACTERES_LOG := 76

signal ventana_cerrada()

var _abierta_en_frame := -1

var _cerrar: Control
var _barra_disp_fondo: ColorRect
var _barra_disp: ColorRect
var _lbl_disp: Label
var _lbl_estado: Label

var _tarjetas: Array[Dictionary] = []      # {panel, nombre, estado, fondo, barra}
var _botones_flujo: Array[Button] = []
var _indices_flujo: Array[int] = []        # indice de oleada de cada boton
var _botones_mit: Array[Button] = []
var _mit_ids: Array[int] = []
var _boton_general: Button
var _telemetria: RichTextLabel
var _registro: RichTextLabel

# --- Verificacion de reinicio (secuencias de flechas, estilo Helldivers)
const QTE_LARGO_MIN := 4
const QTE_LARGO_MAX := 6
const QTE_TIEMPO := 8.0          ## Segundos para completar cada secuencia
const DIR_ARRIBA := 0
const DIR_ABAJO := 1
const DIR_IZQ := 2
const DIR_DER := 3

var _qte_panel: Panel
var _qte_titulo: Label
var _qte_sub: Label
var _qte_flechas: FlechasQte
var _qte_barra_fondo: ColorRect
var _qte_barra: ColorRect
var _qte_id := -1
var _qte_total := 0
var _qte_patron: Array[int] = []
var _qte_pos := 0
var _qte_tiempo := 0.0
var _qte_flash := 0.0
var _qte_flash_ok := false
var _qte_pausa := 0.0
var _rng := RandomNumberGenerator.new()

var _flujo_sel := -1
var _acumulador := 0.0
var _parpadeo := 0.0
var _fuente: Font


func _ready() -> void:
	position = POS
	size = TAM
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	visible = false

	if ResourceLoader.exists(FUENTE_RUTA):
		_fuente = load(FUENTE_RUTA)
	var tema := Theme.new()
	if _fuente != null:
		tema.default_font = _fuente
	tema.default_font_size = 12
	theme = tema

	_rng.randomize()
	_construir()


# ================================================================ API

func abrir() -> void:
	# Un clic sobre "Servidores" siempre la muestra (idempotente: si ya
	# estaba abierta, solo se refresca).
	visible = true
	_abierta_en_frame = Engine.get_process_frames()
	_refrescar()


func cerrar() -> void:
	if not visible:
		return
	visible = false
	ventana_cerrada.emit()


## Rect global que ocupa la ventana (para que CyberDesk ignore los iconos
## que quedan detras).
func rect_global() -> Rect2:
	return Rect2(global_position, size)


## CyberDesk.gd le pasa cada clic izquierdo (posicion en el viewport del PC).
## Devuelve true si el clic cayo sobre la ventana (CyberDesk no debe hacer
## nada mas con ese clic).
func procesar_click(pos: Vector2) -> bool:
	if not visible:
		return false
	# El clic que abre la ventana no debe activar nada dentro de ella.
	if Engine.get_process_frames() == _abierta_en_frame:
		return false

	var puntos: Array[Vector2] = [pos - OFFSET_PUNTA, pos]
	var rect := rect_global()

	var dentro := false
	for p in puntos:
		if rect.has_point(p):
			dentro = true
	if not dentro:
		return false

	# Primero la punta de la flecha, despues el centro.
	for p in puntos:
		if _tocar(p):
			break
	return true


func _tocar(p: Vector2) -> bool:
	if _cerrar.get_global_rect().grow(2.0).has_point(p):
		cerrar()
		return true

	for i in _botones_flujo.size():
		var b := _botones_flujo[i]
		if b.visible and not _qte_panel.visible and b.get_global_rect().has_point(p):
			if i < _indices_flujo.size():
				_flujo_sel = _indices_flujo[i]
				_refrescar()
			return true

	for i in _botones_mit.size():
		var b := _botones_mit[i]
		if b.get_global_rect().has_point(p):
			if not b.disabled:
				IncidenteDDoS.aplicar_mitigacion(_mit_ids[i])
				_refrescar()
			return true

	if _boton_general.get_global_rect().has_point(p):
		if not _boton_general.disabled:
			IncidenteDDoS.reinicio_general()
			_refrescar()
		return true

	return false


# ================================================================ LOOP

func _process(delta: float) -> void:
	if not visible:
		return
	_parpadeo += delta
	_acumulador += delta
	_procesar_qte(delta)
	_actualizar_hover()
	if _acumulador >= 0.15:
		_acumulador = 0.0
		_refrescar()


func _actualizar_hover() -> void:
	var cursor := get_parent().get_node_or_null("CustomCursor") as Control
	var punta := Vector2(-1000.0, -1000.0)
	if cursor != null:
		punta = cursor.get_global_rect().position

	for b in _botones_flujo:
		b.modulate = _brillo(b, punta)
	for b in _botones_mit:
		b.modulate = _brillo(b, punta)
	_boton_general.modulate = _brillo(_boton_general, punta)

	var sobre_cerrar := _cerrar.get_global_rect().grow(2.0).has_point(punta)
	_cerrar.modulate = Color(1.3, 1.3, 1.3) if sobre_cerrar else Color.WHITE


func _brillo(b: Button, punta: Vector2) -> Color:
	if b.visible and not b.disabled and b.get_global_rect().has_point(punta):
		return Color(1.35, 1.35, 1.35)
	return Color.WHITE


# ============================================================ REFRESCO

func _refrescar() -> void:
	if _cerrar == null:
		return
	_qte_panel.visible = IncidenteDDoS.siguiente_verificacion() != -1
	_refrescar_estado()
	_refrescar_servidores()
	_refrescar_flujos()
	_refrescar_telemetria()
	_refrescar_botones()
	_refrescar_registro()


func _refrescar_estado() -> void:
	var disp: float = IncidenteDDoS.disponibilidad
	_barra_disp.size.x = _barra_disp_fondo.size.x * clampf(disp / 100.0, 0.0, 1.0)
	var col := COL_OK
	if disp < 35.0:
		col = COL_ALERTA
	elif disp < 70.0:
		col = COL_AVISO
	_barra_disp.color = col
	_lbl_disp.text = "%d%%" % int(disp)
	_lbl_disp.add_theme_color_override("font_color", col)

	if not IncidenteDDoS.activo:
		_lbl_estado.text = "SIN ATAQUE ACTIVO"
		_lbl_estado.add_theme_color_override("font_color", COL_OK)
		return

	var t: float = IncidenteDDoS.tiempo_restante
	var txt := "ATAQUE  %02d:%02d" % [int(t / 60.0), int(fmod(t, 60.0))]
	if IncidenteDDoS.cooldown_restante > 0.0:
		txt = "OCUPADO %.1fs" % IncidenteDDoS.cooldown_restante
	if _qte_panel.visible:
		txt = "VERIFICACION"
	_lbl_estado.text = txt
	_lbl_estado.add_theme_color_override("font_color", COL_AVISO if disp >= 35.0 else COL_ALERTA)


func _refrescar_servidores() -> void:
	for id in _tarjetas.size():
		var t: Dictionary = _tarjetas[id]
		var s: Dictionary = IncidenteDDoS.servidores[id]
		var carga: float = s.carga
		var texto := "EN LINEA"
		var col := COL_OK

		if not IncidenteDDoS.activo:
			texto = "OPERATIVO"
			carga = 0.0
		elif IncidenteDDoS.apagon_restante > 0.0:
			texto = "REINICIO GENERAL"
			col = COL_AVISO
		elif s.reiniciando:
			texto = "REINICIANDO RACK..."
			col = COL_AVISO
		elif IncidenteDDoS.verificaciones_pendientes[id] > 0:
			texto = "REQUIERE VERIFICACION (%d)" % IncidenteDDoS.verificaciones_pendientes[id]
			col = COL_ALERTA
		elif IncidenteDDoS.autorizado[id]:
			texto = "AUTORIZADO: reinicia el rack"
			col = COL_AVISO
		elif not s.online:
			var visible_ahora := fmod(_parpadeo, 0.8) < 0.5
			texto = "FUERA DE SERVICIO" if visible_ahora else ""
			col = COL_ALERTA
		else:
			texto = "EN LINEA  CARGA %d%%" % int(carga)
			if carga >= 60.0:
				col = COL_AVISO

		var lbl_estado: Label = t.estado
		lbl_estado.text = texto
		lbl_estado.add_theme_color_override("font_color", col)

		var fondo: ColorRect = t.fondo
		var barra: ColorRect = t.barra
		barra.size.x = fondo.size.x * clampf(carga / 100.0, 0.0, 1.0)
		barra.color = col


func _refrescar_flujos() -> void:
	var lista: Array = []
	if IncidenteDDoS.activo:
		lista = IncidenteDDoS.oleadas

	_indices_flujo.clear()
	for ol in lista:
		_indices_flujo.append(ol.indice)

	if _flujo_sel not in _indices_flujo:
		_flujo_sel = _indices_flujo[0] if not _indices_flujo.is_empty() else -1

	for i in _botones_flujo.size():
		var b := _botones_flujo[i]
		if i < lista.size():
			var ol: Dictionary = lista[i]
			b.visible = true
			b.text = _etiqueta_flujo(ol)
			b.add_theme_stylebox_override(
				"normal", _caja_boton(ol.indice == _flujo_sel, ol))
		else:
			b.visible = false


func _etiqueta_flujo(ol: Dictionary) -> String:
	var destinos: Array[String] = []
	for o in ol.objetivos:
		destinos.append(IncidenteDDoS.NOMBRE_SERVIDOR[o].replace("Servidor de ", ""))

	var marca := ""
	if ol.vector == IncidenteDDoS.Vector.LEGITIMO:
		marca = "  ?"
	elif ol.vector_extra != -1:
		var hechos := int(ol.mitigada) + int(ol.mitigada_extra)
		marca = "  [OK]" if hechos == 2 else "  (%d/2)" % hechos
	elif ol.mitigada:
		marca = "  [OK]"

	return "FLUJO #%d%s\n%s" % [ol.indice + 1, marca, ", ".join(destinos)]


func _refrescar_telemetria() -> void:
	if not IncidenteDDoS.activo:
		_telemetria.text = _texto_manual()
		return

	var ol := _buscar_flujo(_flujo_sel)
	if ol.is_empty():
		_telemetria.text = "[color=#5a7a6a]Sin flujos anomalos por ahora.\nAtento a nuevas alertas.[/color]\n\n" + _texto_manual()
		return

	var l := PackedStringArray()
	if ol.vector_extra == -1:
		l.append("[b]FLUJO #%d[/b]" % (ol.indice + 1))

	if ol.vector == IncidenteDDoS.Vector.LEGITIMO:
		l.append("[color=#ffcc55]Podria ser trafico legitimo. Analice antes de actuar.[/color]")
		_bloque(l, ol.telemetria)
		l.append("[color=#3fe08a]Si nada parece un ataque real, NO aplique contramedida.[/color]")
		_telemetria.text = "\n".join(l)
		return

	_bloque(l, ol.telemetria)

	if ol.vector_extra != -1:
		l.append("[b]-- 2 firmas superpuestas --[/b]")
		_bloque(l, ol.telemetria_extra)

	var completo: bool = ol.mitigada and (ol.vector_extra == -1 or ol.mitigada_extra)
	if completo:
		l.append("[color=#3fe08a]>> Flujo neutralizado.[/color]")
	elif ol.mitigada or ol.mitigada_extra:
		l.append("[color=#ffcc55]>> Parcial: falta la otra firma.[/color]")

	_telemetria.text = "\n".join(l)


func _bloque(l: PackedStringArray, t: Dictionary) -> void:
	l.append("Pkts/s %s  Tam %s  SYN %s  Handshakes %s" % [
		_miles(t.paquetes_seg), t.tamano_medio,
		t.porcentaje_syn, t.handshakes_completados])
	l.append("Origen: %s" % t.ips_origen)
	l.append("Destino: %s" % t.puerto_destino)
	l.append("[color=#ffcc55]>[/color] %s" % t.nota)


func _refrescar_botones() -> void:
	var libre: bool = IncidenteDDoS.activo and IncidenteDDoS.cooldown_restante <= 0.0
	for b in _botones_mit:
		b.disabled = not libre
	_boton_general.disabled = not IncidenteDDoS.activo or IncidenteDDoS.apagon_restante > 0.0


func _refrescar_registro() -> void:
	var h: Array = IncidenteDDoS.historial_log
	if h.is_empty():
		_registro.text = "[color=#5a7a6a]> Sistema en espera. Sin incidentes registrados.[/color]"
		return

	var l := PackedStringArray()
	var desde := maxi(0, h.size() - LINEAS_LOG)
	for i in range(desde, h.size()):
		var linea: String = h[i]
		if linea.length() > CARACTERES_LOG:
			linea = linea.substr(0, CARACTERES_LOG - 3) + "..."
		linea = linea.replace("[", "(").replace("]", ")")
		var col := "#9fd8bd"
		if linea.begins_with("(ERROR)") or linea.begins_with("(CRITICO)"):
			col = "#ff6b55"
		elif linea.begins_with("(OK)"):
			col = "#3fe08a"
		elif linea.begins_with("(ALERTA") or linea.begins_with("(AVISO)") or linea.begins_with("(TRAFICO)"):
			col = "#ffcc55"
		l.append("[color=%s]> %s[/color]" % [col, linea])
	_registro.text = "\n".join(l)


func _buscar_flujo(indice: int) -> Dictionary:
	for ol in IncidenteDDoS.oleadas:
		if ol.indice == indice:
			return ol
	return {}


func _miles(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out


func _texto_manual() -> String:
	return """[color=#9fd8bd][b]MANUAL DEL ANALISTA[/b]
[color=#3fe08a]SYN Flood[/color]: ~60 B, >90% SYN, sin handshakes -> SYN Cookies
[color=#3fe08a]UDP[/color]: >2 KB, origen 53/UDP -> Filtro UDP
[color=#3fe08a]HTTP Flood[/color]: GET validos repetidos -> Rate limit
[color=#3fe08a]Botnet[/color]: miles de IPs reales, un AS -> Blackhole
[color=#ff8a5c]Legitimo[/color]: pocas IPs conocidas -> NO actuar
Combinado: una contramedida por firma.
[color=#ffcc55]Rack que no arranca[/color]: autoriza aqui con las flechas y vuelve al rack.[/color]"""


# ============================================================ CONSTRUCCION

func _construir() -> void:
	# Marco de la ventana
	var marco := Panel.new()
	marco.position = Vector2.ZERO
	marco.size = TAM
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_theme_stylebox_override("panel", _caja(COL_MARCO, Color.BLACK, 2))
	add_child(marco)

	# Barra de titulo
	var titulo := ColorRect.new()
	titulo.color = COL_TITULO
	titulo.position = Vector2(2, 2)
	titulo.size = Vector2(TAM.x - 4, 24)
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(titulo)

	_etiqueta(titulo, "Servidores - Monitor de red", Vector2(8, 3), Vector2(400, 18), 14, Color.WHITE)

	_cerrar = Panel.new()
	_cerrar.position = Vector2(TAM.x - 32, 4)
	_cerrar.size = Vector2(26, 20)
	_cerrar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cerrar.add_theme_stylebox_override("panel", _caja(Color(0.8, 0.15, 0.2), Color.WHITE, 1))
	add_child(_cerrar)
	var x := _etiqueta(_cerrar, "X", Vector2(0, 1), Vector2(26, 18), 14, Color.WHITE)
	x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Cuerpo oscuro
	var cuerpo := Panel.new()
	cuerpo.position = Vector2(6, 30)
	cuerpo.size = Vector2(TAM.x - 12, TAM.y - 36)
	cuerpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cuerpo.add_theme_stylebox_override("panel", _caja(COL_FONDO, COL_BORDE.darkened(0.4), 1))
	add_child(cuerpo)

	# ---- Fila de estado
	_etiqueta(cuerpo, "DISPONIBILIDAD", Vector2(6, 5), Vector2(130, 16), 12, COL_TEXTO)
	_barra_disp_fondo = ColorRect.new()
	_barra_disp_fondo.color = Color(0.1, 0.15, 0.16)
	_barra_disp_fondo.position = Vector2(140, 7)
	_barra_disp_fondo.size = Vector2(230, 12)
	_barra_disp_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cuerpo.add_child(_barra_disp_fondo)
	_barra_disp = ColorRect.new()
	_barra_disp.color = COL_OK
	_barra_disp.size = _barra_disp_fondo.size
	_barra_disp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra_disp_fondo.add_child(_barra_disp)
	_lbl_disp = _etiqueta(cuerpo, "100%", Vector2(376, 5), Vector2(44, 16), 12, COL_OK)
	_lbl_estado = _etiqueta(cuerpo, "SIN ATAQUE ACTIVO", Vector2(424, 5), Vector2(156, 16), 12, COL_OK)
	_lbl_estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# ---- Tarjetas de servidores
	var nombres := ["Alertas", "Camaras", "Monitoreo"]
	for i in 3:
		var p := Panel.new()
		p.position = Vector2(4 + i * 195, 28)
		p.size = Vector2(188, 46)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", _caja(Color(0.05, 0.09, 0.1), COL_BORDE.darkened(0.55), 1))
		cuerpo.add_child(p)

		_etiqueta(p, "Srv. " + nombres[i], Vector2(6, 2), Vector2(176, 15), 12, COL_TEXTO)
		var est := _etiqueta(p, "OPERATIVO", Vector2(6, 16), Vector2(176, 14), 12, COL_OK)

		var fondo := ColorRect.new()
		fondo.color = Color(0.1, 0.15, 0.16)
		fondo.position = Vector2(6, 34)
		fondo.size = Vector2(176, 7)
		fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(fondo)
		var barra := ColorRect.new()
		barra.color = COL_OK
		barra.size = Vector2(0, 7)
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fondo.add_child(barra)

		_tarjetas.append({"panel": p, "estado": est, "fondo": fondo, "barra": barra})

	# ---- Flujos (izquierda) y telemetria (derecha)
	for i in MAX_FLUJOS:
		var b := _boton(cuerpo, "", Vector2(4, 80 + i * 47), Vector2(186, 44), 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.visible = false
		_botones_flujo.append(b)

	_telemetria = RichTextLabel.new()
	_telemetria.bbcode_enabled = true
	_telemetria.scroll_active = false
	_telemetria.position = Vector2(196, 80)
	_telemetria.size = Vector2(388, 190)
	_telemetria.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_telemetria.add_theme_font_size_override("normal_font_size", 12)
	_telemetria.add_theme_font_size_override("bold_font_size", 12)
	_telemetria.add_theme_stylebox_override("normal", _caja(Color(0.02, 0.04, 0.05), COL_BORDE.darkened(0.5), 1, 5))
	cuerpo.add_child(_telemetria)

	# ---- Contramedidas
	var mits := [
		[IncidenteDDoS.Mitigacion.SYN_COOKIES, "SYN Cookies"],
		[IncidenteDDoS.Mitigacion.FILTRO_UDP, "Filtro UDP"],
		[IncidenteDDoS.Mitigacion.RATE_LIMIT, "Rate limit"],
		[IncidenteDDoS.Mitigacion.BLACKHOLE, "Blackhole"],
	]
	for i in mits.size():
		var b := _boton(cuerpo, mits[i][1], Vector2(4 + i * 108, 276), Vector2(104, 26), 12)
		_botones_mit.append(b)
		_mit_ids.append(mits[i][0])

	_boton_general = _boton(cuerpo, "REINICIO GENERAL", Vector2(436, 276), Vector2(146, 26), 12)
	_boton_general.add_theme_color_override("font_color", COL_ALERTA)
	_boton_general.add_theme_color_override("font_disabled_color", COL_ALERTA.darkened(0.55))

	_construir_qte(cuerpo)

	# ---- Registro
	_registro = RichTextLabel.new()
	_registro.bbcode_enabled = true
	_registro.scroll_active = false
	_registro.position = Vector2(4, 308)
	_registro.size = Vector2(580, 80)
	_registro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_registro.add_theme_font_size_override("normal_font_size", 12)
	_registro.add_theme_stylebox_override("normal", _caja(Color(0.02, 0.04, 0.05), COL_BORDE.darkened(0.5), 1, 5))
	cuerpo.add_child(_registro)


func _etiqueta(padre: Control, texto: String, pos: Vector2, tam: Vector2, fuente: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.position = pos
	l.size = tam
	l.clip_text = true
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", fuente)
	l.add_theme_color_override("font_color", color)
	padre.add_child(l)
	return l


func _boton(padre: Control, texto: String, pos: Vector2, tam: Vector2, fuente: int) -> Button:
	var b := Button.new()
	b.text = texto
	b.position = pos
	b.size = tam
	b.focus_mode = Control.FOCUS_NONE
	# Los clics los resuelve procesar_click(), el boton es solo visual.
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_font_size_override("font_size", fuente)
	b.add_theme_color_override("font_color", COL_TEXTO)
	b.add_theme_color_override("font_disabled_color", COL_TENUE.darkened(0.2))
	b.add_theme_stylebox_override("normal", _caja_boton(false, {}))
	b.add_theme_stylebox_override("disabled", _caja(Color(0.06, 0.09, 0.1), COL_BORDE.darkened(0.7), 1, 4))
	padre.add_child(b)
	return b


func _caja_boton(seleccionado: bool, ol: Dictionary) -> StyleBoxFlat:
	var fondo := Color(0.08, 0.17, 0.16)
	var borde := COL_BORDE.darkened(0.3)
	if seleccionado:
		fondo = Color(0.10, 0.30, 0.26)
		borde = COL_BORDE.lightened(0.2)
	if not ol.is_empty() and ol.vector == IncidenteDDoS.Vector.LEGITIMO and not seleccionado:
		borde = COL_AVISO.darkened(0.3)
	return _caja(fondo, borde, 1, 4)


func _caja(fondo: Color, borde: Color, grosor: int, margen: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = borde
	sb.set_border_width_all(grosor)
	sb.set_content_margin_all(margen)
	return sb


# ============================================================ VERIFICACION (QTE)

## Dibuja la fila de flechas. Verde = ya acertada, blanca = la que toca,
## apagada = pendiente. Flash rojo si te equivocas.
class FlechasQte extends Control:
	var patron: Array[int] = []
	var pos := 0
	var flash := 0.0
	var flash_ok := false

	const ARROW := [Vector2(0, -20), Vector2(17, 1), Vector2(7, 1), Vector2(7, 20),
		Vector2(-7, 20), Vector2(-7, 1), Vector2(-17, 1)]

	func _draw() -> void:
		var n := patron.size()
		if n == 0:
			return
		var paso := 56.0
		var x0 := size.x / 2.0 - paso * (n - 1) / 2.0
		for i in n:
			var c := Vector2(x0 + i * paso, size.y / 2.0)
			var col := Color(0.35, 0.45, 0.42)
			var k := 1.0
			if i < pos:
				col = Color(0.25, 1.0, 0.45)
			elif i == pos:
				col = Color(1, 1, 1)
				k = 1.15
			if flash > 0.0:
				col = Color(0.3, 1.0, 0.5) if flash_ok else Color(1.0, 0.3, 0.25)
			var ang := 0.0
			match patron[i]:
				1: ang = PI
				2: ang = -PI / 2.0
				3: ang = PI / 2.0
			var pts := PackedVector2Array()
			for v in ARROW:
				pts.append(c + (v * k).rotated(ang))
			draw_colored_polygon(pts, col)


func _construir_qte(cuerpo: Control) -> void:
	_qte_panel = Panel.new()
	_qte_panel.position = Vector2(4, 80)
	_qte_panel.size = Vector2(580, 190)
	_qte_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qte_panel.add_theme_stylebox_override("panel", _caja(Color(0.07, 0.05, 0.03), COL_AVISO, 2))
	_qte_panel.visible = false
	cuerpo.add_child(_qte_panel)

	_qte_titulo = _etiqueta(_qte_panel, "AUTORIZAR REINICIO", Vector2(10, 8), Vector2(560, 18), 14, COL_AVISO)
	_qte_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qte_sub = _etiqueta(_qte_panel, "", Vector2(10, 28), Vector2(560, 16), 12, COL_TEXTO)
	_qte_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_qte_flechas = FlechasQte.new()
	_qte_flechas.position = Vector2(10, 56)
	_qte_flechas.size = Vector2(560, 70)
	_qte_flechas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qte_panel.add_child(_qte_flechas)

	_qte_barra_fondo = ColorRect.new()
	_qte_barra_fondo.color = Color(0.15, 0.12, 0.06)
	_qte_barra_fondo.position = Vector2(40, 140)
	_qte_barra_fondo.size = Vector2(500, 10)
	_qte_barra_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qte_panel.add_child(_qte_barra_fondo)
	_qte_barra = ColorRect.new()
	_qte_barra.color = COL_AVISO
	_qte_barra.size = _qte_barra_fondo.size
	_qte_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_qte_barra_fondo.add_child(_qte_barra)

	var ayuda := _etiqueta(_qte_panel, "Usa las flechas direccionales.  Un error reinicia la secuencia.",
		Vector2(10, 160), Vector2(560, 16), 12, COL_TENUE)
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _nuevo_patron() -> void:
	_qte_patron.clear()
	var largo := _rng.randi_range(QTE_LARGO_MIN, QTE_LARGO_MAX)
	for i in largo:
		var d := _rng.randi_range(0, 3)
		# Evita 3 iguales seguidas para que no sea trivial.
		while i >= 2 and _qte_patron[i - 1] == d and _qte_patron[i - 2] == d:
			d = _rng.randi_range(0, 3)
		_qte_patron.append(d)
	_qte_pos = 0
	_qte_tiempo = QTE_TIEMPO


func _procesar_qte(delta: float) -> void:
	var id: int = IncidenteDDoS.siguiente_verificacion()
	if id == -1:
		_qte_panel.visible = false
		_qte_id = -1
		return
	_qte_panel.visible = true

	var pendientes: int = IncidenteDDoS.verificaciones_pendientes[id]
	if id != _qte_id or pendientes > _qte_total:
		_qte_id = id
		_qte_total = pendientes
		_nuevo_patron()

	var hecha := _qte_total - pendientes + 1
	_qte_titulo.text = "AUTORIZAR REINICIO: %s" % IncidenteDDoS.NOMBRE_SERVIDOR[id].replace("Servidor de ", "Srv. ")
	_qte_sub.text = "Secuencia %d de %d" % [hecha, _qte_total]

	# Destello tras acertar/fallar
	if _qte_flash > 0.0:
		_qte_flash -= delta
	_qte_flechas.patron = _qte_patron
	_qte_flechas.pos = _qte_pos
	_qte_flechas.flash = _qte_flash
	_qte_flechas.flash_ok = _qte_flash_ok
	_qte_flechas.queue_redraw()

	_qte_barra.size.x = _qte_barra_fondo.size.x * clampf(_qte_tiempo / QTE_TIEMPO, 0.0, 1.0)
	_qte_barra.color = COL_AVISO if _qte_tiempo > 2.5 else COL_ALERTA

	# Pausa corta tras completar una secuencia (se ve el verde).
	if _qte_pausa > 0.0:
		_qte_pausa -= delta
		if _qte_pausa <= 0.0:
			IncidenteDDoS.completar_secuencia(id)
			if IncidenteDDoS.verificaciones_pendientes[id] > 0:
				_nuevo_patron()
		return

	_qte_tiempo -= delta
	if _qte_tiempo <= 0.0:
		_qte_flash = 0.25
		_qte_flash_ok = false
		_nuevo_patron()
		return

	var tecla := _leer_direccion()
	if tecla == -1:
		return

	if tecla == _qte_patron[_qte_pos]:
		_qte_pos += 1
		if _qte_pos >= _qte_patron.size():
			_qte_flash = 0.35
			_qte_flash_ok = true
			_qte_pausa = 0.35
	else:
		_qte_pos = 0
		_qte_flash = 0.2
		_qte_flash_ok = false


func _leer_direccion() -> int:
	if _accion("ui_up"):
		return DIR_ARRIBA
	if _accion("ui_down"):
		return DIR_ABAJO
	if _accion("ui_left"):
		return DIR_IZQ
	if _accion("ui_right"):
		return DIR_DER
	return -1


func _accion(a: StringName, b: StringName = &"", c: StringName = &"") -> bool:
	for n in [a, b, c]:
		if n != &"" and InputMap.has_action(n) and Input.is_action_just_pressed(n):
			return true
	return false
