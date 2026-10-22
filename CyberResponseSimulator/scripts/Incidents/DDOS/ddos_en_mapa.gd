extends Node
class_name DDoSEnMapa
## Lleva el incidente DDoS al mapa principal (Game.tscn), sin cambiar de escena.
##
## Lo crea solo el IncidentFlowManager cuando el flujo del juego elige "DDoS"
## (no hace falta agregarlo a mano en el editor). Se encarga de:
##  - crear la consola de mitigacion, el HUD y la pantalla de resultado
##  - abrir la consola cuando el jugador hace clic en "Servidores" del PC
##  - dejar reiniciar los racks (3 ServidorFisico en el mapa) manteniendo E
##  - bloquear al jugador mientras la consola o el resultado estan abiertos
##  - sacudir la camara con los impactos
##  - avisar al GameManager / IncidentManager cuando el incidente termina

const SHAKE_DECAIMIENTO := 4.5
const SHAKE_ESCALA := 0.08
## Tiempo que se espera para abrir la consola despues de cerrar la vista del
## PC (la camara tarda 0.6 s en volver a su sitio).
const RETARDO_DESDE_PC := 0.8

var _incidente: IncidentData = null
var _terminal: TerminalMitigacion
var _hud: HudDDoS
var _resultado: PantallaResultado
var _prompt: Label
var _rack_actual: ServidorFisico = null
var _bloqueado := false
var _shake := 0.0
var _shake_activo := false


## Punto de entrada para el IncidentFlowManager.
static func iniciar_en_escena(escena: Node, incidente: IncidentData) -> void:
	var nodo := escena.get_tree().get_first_node_in_group("ddos_mapa") as DDoSEnMapa
	if nodo == null:
		nodo = DDoSEnMapa.new()
		nodo.name = "DDoSEnMapa"
		escena.add_child(nodo)
	nodo.empezar(incidente)


func _ready() -> void:
	add_to_group("ddos_mapa")

	# Se conectan ANTES de crear los hijos para correr primero cuando
	# el incidente termina (cerramos la consola antes de que la pantalla
	# de resultado libere el mouse).
	IncidenteDDoS.incidente_terminado.connect(_on_terminado)
	IncidenteDDoS.impacto_camara.connect(_on_impacto_camara)

	_terminal = TerminalMitigacion.new()
	add_child(_terminal)

	_hud = HudDDoS.new()
	add_child(_hud)

	_resultado = PantallaResultado.new()
	add_child(_resultado)
	_resultado.configurar_modo_integrado()

	_terminal.pantalla_abierta.connect(_actualizar_bloqueo)
	_terminal.pantalla_cerrada.connect(_actualizar_bloqueo)
	_resultado.pantalla_abierta.connect(_actualizar_bloqueo)
	_resultado.pantalla_cerrada.connect(_actualizar_bloqueo)

	_crear_prompt()


func empezar(incidente: IncidentData) -> void:
	_incidente = incidente
	IncidenteDDoS.iniciar()
	_hud.mostrar_aviso(
		"ATAQUE DDoS: usa el PC > Servidores y corre a los racks", 6.0
	)


## La llama CyberDesk.gd cuando el jugador hace clic en "Servidores".
func abrir_consola(retardo: float = 0.0) -> void:
	if retardo > 0.0:
		await get_tree().create_timer(retardo).timeout

	if _terminal.abierta or _resultado.abierta:
		return

	_terminal.abrir()


# ================================================================ LOOP

func _physics_process(delta: float) -> void:
	_procesar_racks(delta)


func _process(delta: float) -> void:
	_procesar_shake(delta)


func _procesar_racks(delta: float) -> void:
	var jugador = _jugador()

	if jugador == null or _bloqueado or not IncidenteDDoS.activo:
		_soltar_rack()
		_prompt.visible = false
		return

	var rayo = jugador.interaction_ray
	var objetivo = null
	if rayo != null and rayo.is_colliding():
		objetivo = rayo.get_collider()

	if objetivo is ServidorFisico:
		if _rack_actual != null and _rack_actual != objetivo:
			_soltar_rack()

		_prompt.text = objetivo.texto_prompt()
		_prompt.visible = true

		if Input.is_action_pressed(_accion()):
			objetivo.mantener_interaccion(delta)
			_rack_actual = objetivo
		else:
			_soltar_rack()
		return

	_soltar_rack()
	_prompt.visible = false


func _soltar_rack() -> void:
	if _rack_actual != null:
		_rack_actual.soltar_interaccion()
		_rack_actual = null


func _accion() -> StringName:
	if InputMap.has_action("interact"):
		return &"interact"
	return &"interactuar"


# ============================================================ BLOQUEO

func _actualizar_bloqueo() -> void:
	var bloquear: bool = _terminal.abierta or _resultado.abierta
	if bloquear == _bloqueado:
		return
	_bloqueado = bloquear

	var jugador = _jugador()
	if jugador == null:
		return

	# Sin esto, WASD movería al jugador y un clic en la consola
	# volvería a capturar el mouse (Player.gd lo hace en _input).
	jugador.set_physics_process(not bloquear)
	jugador.set_process_input(not bloquear)

	if bloquear:
		_soltar_rack()
		_prompt.visible = false


# ============================================================ RESULTADO

func _on_terminado(exito: bool, _resumen: Dictionary) -> void:
	if _terminal.abierta:
		_terminal.cerrar()

	_soltar_rack()
	_prompt.visible = false

	if exito:
		GameManager.score += 100
		GameManager.incidents_completed += 1
	else:
		GameManager.incidents_failed += 1

	if _incidente != null:
		IncidentManager.finish_incident(_incidente)
		_incidente = null


# ================================================================ SHAKE

func _on_impacto_camara(intensidad: float) -> void:
	_shake = maxf(_shake, intensidad)


func _procesar_shake(delta: float) -> void:
	var jugador = _jugador()
	if jugador == null:
		return
	var cam: Camera3D = jugador.camera

	if _shake > 0.001:
		_shake_activo = true
		cam.h_offset = randf_range(-1.0, 1.0) * _shake * SHAKE_ESCALA
		cam.v_offset = randf_range(-1.0, 1.0) * _shake * SHAKE_ESCALA
		_shake = lerpf(_shake, 0.0, 1.0 - exp(-SHAKE_DECAIMIENTO * delta))
	elif _shake_activo:
		_shake_activo = false
		_shake = 0.0
		cam.h_offset = 0.0
		cam.v_offset = 0.0


# ================================================================ UTIL

func _jugador() -> Node:
	var escena := get_tree().current_scene
	if escena == null:
		return null
	return escena.get_node_or_null("Player")


func _crear_prompt() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 3
	add_child(capa)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_bottom = -110
	_prompt.offset_top = -150
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color(1, 1, 1))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.visible = false
	capa.add_child(_prompt)
