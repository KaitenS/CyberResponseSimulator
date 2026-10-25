extends Node
class_name DDoSEnMapa
## Lleva el incidente DDoS al mapa principal (Game.tscn), sin cambiar de escena.
##
## Lo crea solo el IncidentFlowManager cuando el flujo del juego elige "DDoS"
## (no hace falta agregarlo a mano en el editor). Se encarga de:
##  - crear el HUD y la pantalla de resultado
##    (la consola de mitigacion vive dentro del PC: ventana_ddos_pc.gd)
##  - dejar reiniciar los racks (3 ServidorFisico en el mapa) manteniendo E
##  - bloquear al jugador mientras el resultado esta abierto
##  - sacudir la camara con los impactos
##  - avisar al GameManager / IncidentManager cuando el incidente termina

## Para el menu / IncidentFlowManager: forzar que el proximo incidente sea este
## ("ddos"). Se consume una sola vez. Sirve para el modo practica.
static var forzar_siguiente: String = ""
## True cuando la partida es de practica (duracion completa, sin reloj de juego).
static var modo_practica: bool = false

const ARCHIVO_AJUSTES := "user://ddos_ajustes.cfg"
const COL_LUZ_ALARMA := Color(1.0, 0.18, 0.12)

const SHAKE_DECAIMIENTO := 4.5
const SHAKE_ESCALA := 0.08

var _incidente: IncidentData = null
var _ultimo_incidente: IncidentData = null   ## para poder reintentar
var _hud: HudDDoS
var _resultado: PantallaResultado
var _prompt: Label
var _rack_actual: ServidorFisico = null
var _bloqueado := false
var _shake := 0.0
var _shake_activo := false

# --- Tutorial (checklist de 3 pasos, solo la primera vez o en practica)
var _tutorial: CanvasLayer
var _tutorial_lineas: Array[Label] = []
var _tutorial_hecho := [false, false, false]
var _tutorial_activo := false

# --- Luces de alarma
var _luz: DirectionalLight3D
var _luz_color_base := Color.WHITE
var _luz_energia_base := 1.0
var _luz_t := 0.0


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

	IncidenteDDoS.incidente_terminado.connect(_on_terminado)
	IncidenteDDoS.impacto_camara.connect(_on_impacto_camara)
	IncidenteDDoS.reinicio_fallido.connect(_on_reinicio_fallido)
	IncidenteDDoS.reinicio_autorizado.connect(_on_reinicio_autorizado)
	IncidenteDDoS.aviso_abandono.connect(_on_aviso_abandono)
	IncidenteDDoS.consola_abierta.connect(func(): _marcar_tutorial(0))
	IncidenteDDoS.mitigacion_resultado.connect(_on_mitigacion_tutorial)
	IncidenteDDoS.reinicio_iniciado.connect(func(_id): _marcar_tutorial(2))

	_hud = HudDDoS.new()
	add_child(_hud)

	_resultado = PantallaResultado.new()
	add_child(_resultado)
	_resultado.configurar_modo_integrado()
	_resultado.reintento_solicitado.connect(reintentar)
	_resultado.reinicio_partida_solicitado.connect(reiniciar_partida)

	_resultado.pantalla_abierta.connect(_actualizar_bloqueo)
	_resultado.pantalla_cerrada.connect(_actualizar_bloqueo)

	_crear_prompt()


func empezar(incidente: IncidentData) -> void:
	_incidente = incidente
	_ultimo_incidente = incidente

	# La duracion se adapta al reloj del juego: el ataque nunca dura mas que
	# la partida. En practica se alarga el reloj para jugarlo completo.
	var duracion := IncidenteDDoS.DURACION_INCIDENTE
	if modo_practica:
		GameManager.time_remaining = maxf(GameManager.time_remaining, duracion + 10.0)
	elif GameManager.game_active:
		duracion = clampf(GameManager.time_remaining - 2.0, 30.0, duracion)
	IncidenteDDoS.iniciar(duracion)

	_hud.mostrar_aviso(
		"ATAQUE DDoS: abre Servidores en el PC y corre a los racks", 6.0
	)
	_preparar_luz()
	_iniciar_tutorial()


# ================================================================ LOOP

func _physics_process(delta: float) -> void:
	_procesar_racks(delta)


func _process(delta: float) -> void:
	_procesar_shake(delta)
	_procesar_luz(delta)


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
	var bloquear: bool = _resultado.abierta
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
	_soltar_rack()
	_prompt.visible = false

	if exito:
		GameManager.score += 100
		GameManager.incidents_completed += 1
	else:
		GameManager.incidents_failed += 1

	_restaurar_luz()
	_cerrar_tutorial(true)

	if _incidente != null:
		IncidentManager.finish_incident(_incidente)
		_incidente = null


func _on_reinicio_fallido(id: int, secuencias: int) -> void:
	_hud.mostrar_aviso("REINICIO FALLIDO: %s\nVe al PC > Servidores (%d secuencia%s)" % [
		IncidenteDDoS.NOMBRE_SERVIDOR[id], secuencias, "" if secuencias == 1 else "s"], 5.0)
	_hud.destello(Color(1.0, 0.3, 0.2))


func _on_reinicio_autorizado(id: int) -> void:
	_hud.mostrar_aviso("AUTORIZADO: vuelve a %s y mantén E" % IncidenteDDoS.NOMBRE_SERVIDOR[id], 4.0)
	_hud.destello(Color(0.3, 1.0, 0.5))


## Vuelve a intentar el incidente despues de perder (sin recargar la escena).
func reintentar() -> void:
	if _ultimo_incidente == null or IncidenteDDoS.activo:
		return
	# Si el reloj de la partida casi se acabo, se da una ventana nueva.
	if not modo_practica and GameManager.time_remaining < 45.0:
		GameManager.game_active = true
		GameManager.time_remaining = 60.0
	if not IncidentManager.start_incident(_ultimo_incidente):
		IncidentManager.active_incidents.clear()
		IncidentManager.start_incident(_ultimo_incidente)
	_soltar_rack()
	empezar(_ultimo_incidente)


## Reinicia toda la partida (recarga el mapa con el reloj en cero).
func reiniciar_partida() -> void:
	if IncidenteDDoS.activo:
		IncidenteDDoS.abortar()
	IncidentManager.active_incidents.clear()
	GameManager.start_game()
	if modo_practica:
		forzar_siguiente = "ddos"   # que la practica vuelva a lanzar el DDoS
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


func _on_mitigacion_tutorial(exito: bool, _mensaje: String) -> void:
	if exito:
		_marcar_tutorial(1)


func _on_aviso_abandono(segundos: float) -> void:
	_hud.mostrar_aviso("NADIE ATIENDE EL ATAQUE\nAbre Servidores en el PC (%d s)" % int(segundos), 4.0)
	_hud.destello(Color(1.0, 0.7, 0.2))


# ================================================================ TUTORIAL

func _tutorial_ya_visto() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_AJUSTES) != OK:
		return false
	return bool(cfg.get_value("ddos", "tutorial_visto", false))


func _guardar_tutorial_visto() -> void:
	var cfg := ConfigFile.new()
	cfg.load(ARCHIVO_AJUSTES)
	cfg.set_value("ddos", "tutorial_visto", true)
	cfg.save(ARCHIVO_AJUSTES)


func _iniciar_tutorial() -> void:
	_tutorial_hecho = [false, false, false]
	if not modo_practica and _tutorial_ya_visto():
		return
	_tutorial_activo = true

	if _tutorial == null:
		var capa := CanvasLayer.new()
		capa.layer = 4
		add_child(capa)

		var panel := PanelContainer.new()
		panel.position = Vector2(16, 70)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.06, 0.07, 0.88)
		sb.border_color = Color(0.15, 0.85, 0.55)
		sb.set_border_width_all(2)
		sb.set_content_margin_all(10)
		panel.add_theme_stylebox_override("panel", sb)
		capa.add_child(panel)
		_tutorial = capa

		var col := VBoxContainer.new()
		panel.add_child(col)
		var titulo := Label.new()
		titulo.text = "COMO RESPONDER"
		titulo.add_theme_color_override("font_color", Color(0.15, 0.85, 0.55))
		col.add_child(titulo)
		for i in 3:
			var l := Label.new()
			l.add_theme_font_size_override("font_size", 15)
			col.add_child(l)
			_tutorial_lineas.append(l)
	_tutorial.visible = true
	_refrescar_tutorial()


func _refrescar_tutorial() -> void:
	var textos := [
		"Abre «Servidores» en el PC",
		"Lee el flujo y aplica la contramedida",
		"Si un rack cae: mira al rack y mantén E",
	]
	for i in 3:
		var hecho: bool = _tutorial_hecho[i]
		_tutorial_lineas[i].text = ("[x] " if hecho else "[ ] ") + textos[i]
		_tutorial_lineas[i].add_theme_color_override(
			"font_color", Color(0.4, 1.0, 0.6) if hecho else Color(0.9, 0.95, 0.95))


func _marcar_tutorial(i: int) -> void:
	if not _tutorial_activo or _tutorial_hecho[i]:
		return
	_tutorial_hecho[i] = true
	_refrescar_tutorial()
	if not _tutorial_hecho.has(false):
		await get_tree().create_timer(2.5).timeout
		_cerrar_tutorial(true)


func _cerrar_tutorial(visto: bool) -> void:
	if _tutorial != null:
		_tutorial.visible = false
	if _tutorial_activo and visto and not modo_practica:
		_guardar_tutorial_visto()
	_tutorial_activo = false


# ================================================================ LUCES

func _preparar_luz() -> void:
	var escena := get_tree().current_scene
	if escena == null or _luz != null:
		return
	_luz = escena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if _luz != null:
		_luz_color_base = _luz.light_color
		_luz_energia_base = _luz.light_energy


## La luz de la oficina se pone roja y pulsa cuando la cosa va mal.
func _procesar_luz(delta: float) -> void:
	if _luz == null or not is_instance_valid(_luz):
		return
	var intensidad := 0.0
	if IncidenteDDoS.activo:
		if IncidenteDDoS.disponibilidad < 35.0:
			intensidad = 0.75
		else:
			for s in IncidenteDDoS.servidores:
				if not s.online:
					intensidad = 0.3
					break
	if intensidad <= 0.0 and _luz_t <= 0.0:
		return
	_luz_t = move_toward(_luz_t, intensidad, delta * 1.5)
	var pulso := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	var k := _luz_t * (0.5 + 0.5 * pulso)
	_luz.light_color = _luz_color_base.lerp(COL_LUZ_ALARMA, k)
	_luz.light_energy = _luz_energia_base * (1.0 - 0.35 * k)


func _restaurar_luz() -> void:
	_luz_t = 0.0
	if _luz != null and is_instance_valid(_luz):
		_luz.light_color = _luz_color_base
		_luz.light_energy = _luz_energia_base


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
