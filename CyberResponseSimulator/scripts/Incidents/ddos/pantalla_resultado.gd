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


func _ready() -> void:
	layer = 12
	_construir_ui()
	_raiz.visible = false

	IncidenteDDoS.incidente_terminado.connect(_on_incidente_terminado)


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
	_titulo.text = "INCIDENTE CONTENIDO" if exito else "SERVICIO CAIDO"
	_titulo.add_theme_color_override("font_color", COL_BORDE_EXITO if exito else COL_BORDE_FALLO)
	_marco.add_theme_stylebox_override("panel", _estilo_panel(exito))

	_puntaje_label.text = "Puntaje final: %d" % int(resumen.get("puntaje", 0))

	var totales: int = resumen.get("oleadas_totales", 0)
	var mitigadas: int = resumen.get("oleadas_mitigadas", 0)
	var falsos: int = resumen.get("falsos_positivos", 0)
	var reinicios: int = resumen.get("reinicios_generales", 0)
	var alertas: int = resumen.get("alertas_perdidas", 0)
	var legitimas: int = resumen.get("oleadas_legitimas", 0)
	var combinadas: int = resumen.get("oleadas_combinadas", 0)
	var disponibilidad: float = resumen.get("disponibilidad_final", 0.0)

	var lineas := PackedStringArray()
	lineas.append("[b]Disponibilidad final del servicio:[/b] %.0f %%" % disponibilidad)
	lineas.append("")
	lineas.append("[b]Flujos detectados:[/b] %d" % totales)
	lineas.append("[b]Flujos neutralizados correctamente:[/b] %d" % mitigadas)
	lineas.append("[b]Falsos positivos (trafico legitimo bloqueado):[/b] %d" % falsos)

	if legitimas > 0:
		lineas.append("[b]Oleadas de trafico legitimo (trampa):[/b] %d" % legitimas)
	if combinadas > 0:
		lineas.append("[b]Ataques combinados enfrentados:[/b] %d" % combinadas)

	lineas.append("[b]Reinicios generales usados:[/b] %d" % reinicios)
	if alertas > 0:
		lineas.append("[b]Alertas perdidas por caida del sistema:[/b] %d" % alertas)

	lineas.append("")
	if exito:
		if falsos == 0 and mitigadas == totales:
			lineas.append("[color=#3fe08a]Turno impecable: identificaste cada vector correctamente y no bloqueaste trafico legitimo.[/color]")
		elif falsos > 2:
			lineas.append("[color=#ffcc55]Sobreviviste el turno, pero varios falsos positivos afectaron a usuarios reales. Revisa el manual del analista antes de actuar.[/color]")
		else:
			lineas.append("[color=#3fe08a]Buen trabajo. El servicio se mantuvo en pie durante todo el incidente.[/color]")
	else:
		lineas.append("[color=#ff6b55]La disponibilidad llego a cero. Revisa que reinicios y contramedidas coincidan con la telemetria antes de actuar.[/color]")

	_detalle.text = "\n".join(lineas)
	abrir()


func _reintentar() -> void:
	cerrar()
	IncidenteDDoS.iniciar()


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
	_marco.offset_left = -320
	_marco.offset_top = -260
	_marco.offset_right = 320
	_marco.offset_bottom = 260
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
	_detalle.fit_content = true
	_detalle.custom_minimum_size = Vector2(0, 260)
	_detalle.add_theme_color_override("default_color", COL_TEXTO)
	col.add_child(_detalle)

	col.add_child(HSeparator.new())

	var fila_botones := HBoxContainer.new()
	fila_botones.add_theme_constant_override("separation", 10)
	fila_botones.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(fila_botones)

	var btn_reintentar := Button.new()
	btn_reintentar.text = "Reintentar incidente"
	btn_reintentar.custom_minimum_size = Vector2(200, 40)
	btn_reintentar.pressed.connect(_reintentar)
	fila_botones.add_child(btn_reintentar)

	var btn_cerrar := Button.new()
	btn_cerrar.text = "Cerrar"
	btn_cerrar.custom_minimum_size = Vector2(120, 40)
	btn_cerrar.pressed.connect(cerrar)
	fila_botones.add_child(btn_cerrar)
