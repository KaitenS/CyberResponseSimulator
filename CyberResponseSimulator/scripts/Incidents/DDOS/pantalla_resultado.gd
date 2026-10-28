extends CanvasLayer
class_name PantallaResultado
## Pantalla de evaluacion que aparece automaticamente cuando el incidente
## DDoS termina (por exito o por caida total del servicio).
##
## Uso: agrega este nodo (CanvasLayer) a tu escena principal, una sola vez.
## Se abre solo, no hace falta llamarla manualmente.
## Igual que la Terminal, expone abierta/pantalla_abierta/pantalla_cerrada
## para que el player.gd bloquee movimiento mientras esta en pantalla.

signal pantalla_abierta()
signal pantalla_cerrada()
## Modo integrado: el jugador pide volver a intentar el incidente / la partida.
signal reintento_solicitado()
signal reinicio_partida_solicitado()

const COL_FONDO := Color(0.03, 0.05, 0.06, 0.98)
const COL_BORDE_EXITO := Color(0.2, 0.85, 0.5)
const COL_BORDE_FALLO := Color(0.9, 0.25, 0.25)
const COL_TEXTO := Color(0.85, 0.9, 0.9)
const COL_DATO := Color(1.0, 1.0, 1.0)

var abierta := false
var _raiz: Control
var _marco: PanelContainer
var _titulo: Label
var _puntaje_label: Label
var _detalle: RichTextLabel
var _btn_reintentar: Button
var _btn_cerrar: Button
var _btn_reiniciar: Button
var _integrado := false


func _ready() -> void:
	layer = 12
	_construir_ui()
	_raiz.visible = false

	IncidenteDDoS.incidente_terminado.connect(_on_incidente_terminado)


## Lo llama DDoSEnMapa cuando el DDoS se juega dentro del flujo del juego:
## no se puede reintentar y el boton de cierre pasa a ser "Continuar".
func configurar_modo_integrado() -> void:
	_integrado = true
	_btn_reintentar.visible = false   # solo se muestra al perder
	_btn_reiniciar.visible = true
	_btn_cerrar.text = "Continuar"


func abrir() -> void:
	abierta = true
	_raiz.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	emit_signal("pantalla_abierta")


func cerrar() -> void:
	abierta = false
	_raiz.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	emit_signal("pantalla_cerrada")


func _on_incidente_terminado(exito: bool, resumen: Dictionary) -> void:
	var abandonado: bool = resumen.get("abandonado", false)
	var titulo := "INCIDENTE CONTENIDO" if exito else "SERVICIO CAIDO"
	if abandonado:
		titulo = "ATAQUE SIN ATENDER"
	_titulo.text = titulo
	_btn_reintentar.visible = (not _integrado) or (not exito)
	_btn_reintentar.text = "Reintentar incidente"
	_titulo.add_theme_color_override("font_color", COL_BORDE_EXITO if exito else COL_BORDE_FALLO)
	_marco.add_theme_stylebox_override("panel", _estilo_panel(exito))

	var puntaje: int = int(resumen.get("puntaje", 0))
	var mejor: int = int(resumen.get("mejor_anterior", 0))
	var extra := ""
	if puntaje > mejor and puntaje > 0:
		extra = "   [NUEVO RECORD]"
	_puntaje_label.text = "Calificacion %s   |   Puntaje %d%s   |   %s" % [
		_nota(exito, resumen), puntaje, extra, resumen.get("dificultad", "Normal")]

	var totales: int = resumen.get("oleadas_totales", 0)
	var mitigadas: int = resumen.get("oleadas_mitigadas", 0)
	var falsos: int = resumen.get("falsos_positivos", 0)
	var reinicios: int = resumen.get("reinicios_generales", 0)
	var alertas: int = resumen.get("alertas_perdidas", 0)
	var disponibilidad: float = resumen.get("disponibilidad_final", 0.0)
	var fallidos: int = resumen.get("reinicios_fallidos", 0)
	var secuencias: int = resumen.get("secuencias_ok", 0)
	var codigos: int = resumen.get("codigos_ok", 0)
	var racha: int = resumen.get("racha_max", 0)
	var legitimas: int = resumen.get("oleadas_legitimas", 0)
	var infecciones: int = resumen.get("infecciones", 0)
	var aislados: int = resumen.get("aislados", 0)
	var cortes: int = resumen.get("cortes_luz", 0)

	var l := PackedStringArray()
	l.append("[b]Disponibilidad final:[/b] %.0f %%     [b]Flujos:[/b] %d     [b]Neutralizados:[/b] %d" % [disponibilidad, totales, mitigadas])
	l.append("[b]Falsos positivos:[/b] %d     [b]Reinicios generales:[/b] %d     [b]Alertas perdidas:[/b] %d" % [falsos, reinicios, alertas])
	l.append("[b]Reinicios de rack fallidos:[/b] %d     [b]Verificaciones:[/b] %d     [b]Mejor racha:[/b] %d" % [fallidos, secuencias, racha])
	l.append("")

	# ---- Lo que hiciste bien
	var bien := PackedStringArray()
	if totales > 0 and mitigadas == totales:
		bien.append("Identificaste cada vector de ataque correctamente.")
	if falsos == 0 and totales > 0:
		bien.append("No bloqueaste trafico legitimo.")
	if legitimas > 0 and falsos == 0:
		bien.append("Reconociste las falsas alarmas y no actuaste sobre ellas.")
	if secuencias > 0:
		bien.append("Autorizaste %d verificacion%s en el PC." % [secuencias, "" if secuencias == 1 else "es"])
	if racha >= 3:
		bien.append("Racha de %d secuencias sin error." % racha)
	if disponibilidad >= 70.0 and exito:
		bien.append("Mantuviste el servicio sobre el 70 %.")
	if aislados > 0:
		bien.append("Aislaste %d servidor%s infectado%s antes de que se propagara." % [aislados, "" if aislados == 1 else "es", "" if aislados == 1 else "s"])
	if cortes > 0 and exito:
		bien.append("Superaste un corte de energia trabajando desde los racks.")

	# ---- Que mejorar
	var mal := PackedStringArray()
	if abandonado:
		mal.append("Nadie atendio el ataque. Abre Servidores en el PC en cuanto suene la alerta.")
	if falsos > 0:
		mal.append("Aplicaste %d contramedida%s equivocada%s. Compara handshakes, tamano de paquete y origen con el manual." % [falsos, "" if falsos == 1 else "s", "" if falsos == 1 else "s"])
	if reinicios > 0:
		mal.append("El reinicio general deja los 3 sistemas caidos 8 s. Es mejor reiniciar solo el rack afectado.")
	if alertas > 0:
		mal.append("Cayo el servidor de Alertas y se perdieron %d aviso%s. Restauralo primero." % [alertas, "" if alertas == 1 else "s"])
	if fallidos > secuencias + codigos and fallidos > 0:
		mal.append("Dejaste reinicios fallidos sin autorizar. Despues de un fallo hay que verificar en el PC y volver al rack.")
	if infecciones > aislados:
		mal.append("No aislaste el ransomware: un servidor infectado sube su carga y drena la disponibilidad. Usa AISLAR en el PC.")
	if disponibilidad < 50.0 and not abandonado:
		mal.append("La disponibilidad bajo mucho. Prioriza los servidores caidos antes de analizar nuevos flujos.")

	l.append("[color=#3fe08a][b]Bien hecho[/b][/color]")
	if bien.is_empty():
		l.append("  - Sobreviviste lo suficiente para aprender del turno.")
	for t in bien:
		l.append("  - " + t)
	l.append("")
	l.append("[color=#ffcc55][b]A mejorar[/b][/color]")
	if mal.is_empty():
		l.append("  - Nada grave. Prueba un turno mas largo o mas rapido.")
	for t in mal:
		l.append("  - " + t)

	# ---- Historial
	var historial: Array = resumen.get("historial", [])
	l.append("")
	l.append("[b]Mejor puntaje anterior:[/b] %d" % mejor)
	if not historial.is_empty():
		var partes := PackedStringArray()
		for r in historial:
			partes.append("%d (%s)" % [int(r.get("puntaje", 0)), "gano" if r.get("exito", false) else "perdio"])
		l.append("[b]Ultimas partidas:[/b] " + ",  ".join(partes))

	_detalle.text = "\n".join(l)
	abrir()


## Calificacion S/A/B/C/D segun el resultado.
func _nota(exito: bool, r: Dictionary) -> String:
	if not exito:
		return "D" if r.get("disponibilidad_final", 0.0) > 0.0 else "E"
	var puntos := 0
	var disp: float = r.get("disponibilidad_final", 0.0)
	if disp >= 85.0:
		puntos += 3
	elif disp >= 60.0:
		puntos += 2
	elif disp >= 35.0:
		puntos += 1
	var falsos: int = r.get("falsos_positivos", 0)
	puntos += 2 if falsos == 0 else (1 if falsos <= 2 else 0)
	if r.get("reinicios_generales", 0) == 0:
		puntos += 1
	if r.get("racha_max", 0) >= 3:
		puntos += 1
	if puntos >= 7:
		return "S"
	if puntos >= 5:
		return "A"
	if puntos >= 3:
		return "B"
	return "C"


func _reintentar() -> void:
	cerrar()
	if _integrado:
		reintento_solicitado.emit()
	else:
		IncidenteDDoS.iniciar()


func _reiniciar_partida() -> void:
	cerrar()
	reinicio_partida_solicitado.emit()


func _estilo_panel(exito: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COL_FONDO
	sb.border_color = COL_BORDE_EXITO if exito else COL_BORDE_FALLO
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(28)
	return sb


func _construir_ui() -> void:
	_raiz = Control.new()
	_raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)

	var fondo := ColorRect.new()
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0, 0, 0, 0.65)
	_raiz.add_child(fondo)

	_marco = PanelContainer.new()
	_marco.anchor_left = 0.5
	_marco.anchor_top = 0.5
	_marco.anchor_right = 0.5
	_marco.anchor_bottom = 0.5
	_marco.offset_left = -380
	_marco.offset_top = -320
	_marco.offset_right = 380
	_marco.offset_bottom = 320
	_marco.add_theme_stylebox_override("panel", _estilo_panel(true))
	_raiz.add_child(_marco)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_marco.add_child(col)

	_titulo = Label.new()
	_titulo.text = "RESULTADO DEL INCIDENTE"
	_titulo.add_theme_font_size_override("font_size", 26)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_titulo)

	_puntaje_label = Label.new()
	_puntaje_label.text = "Puntaje final: 0"
	_puntaje_label.add_theme_font_size_override("font_size", 20)
	_puntaje_label.add_theme_color_override("font_color", COL_DATO)
	_puntaje_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_puntaje_label)

	col.add_child(HSeparator.new())

	_detalle = RichTextLabel.new()
	_detalle.bbcode_enabled = true
	_detalle.fit_content = false
	_detalle.custom_minimum_size = Vector2(0, 400)
	_detalle.add_theme_font_size_override("normal_font_size", 15)
	_detalle.add_theme_font_size_override("bold_font_size", 15)
	_detalle.add_theme_color_override("default_color", COL_TEXTO)
	col.add_child(_detalle)

	col.add_child(HSeparator.new())

	var fila_botones := HBoxContainer.new()
	fila_botones.add_theme_constant_override("separation", 10)
	fila_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(fila_botones)

	_btn_reintentar = Button.new()
	_btn_reintentar.text = "Reintentar incidente"
	_btn_reintentar.custom_minimum_size = Vector2(200, 40)
	_btn_reintentar.pressed.connect(_reintentar)
	fila_botones.add_child(_btn_reintentar)

	_btn_reiniciar = Button.new()
	_btn_reiniciar.text = "Reiniciar partida"
	_btn_reiniciar.custom_minimum_size = Vector2(180, 40)
	_btn_reiniciar.pressed.connect(_reiniciar_partida)
	_btn_reiniciar.visible = false
	fila_botones.add_child(_btn_reiniciar)

	_btn_cerrar = Button.new()
	_btn_cerrar.text = "Cerrar"
	_btn_cerrar.custom_minimum_size = Vector2(120, 40)
	_btn_cerrar.pressed.connect(cerrar)
	fila_botones.add_child(_btn_cerrar)
