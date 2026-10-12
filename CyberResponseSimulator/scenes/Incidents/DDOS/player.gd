extends CharacterBody3D

# --- Configuración de movimiento ---
const SPEED = 5.0
const SENSITIVITY = 0.003

# Gravedad tomada de la configuración del proyecto
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var rayo: RayCast3D = $Head/Camera3D/RayCast3D

## Arrastra aquí el CanvasLayer que tiene el script terminal_mitigacion.gd
@export var terminal: TerminalMitigacion
## Arrastra aquí el CanvasLayer que tiene el script pantalla_resultado.gd
@export var resultado: PantallaResultado

var _rack_actual: ServidorFisico = null
var _prompt: Label

# --- Vibracion de camara (feedback fisico al fallar o al caer un servidor) ---
var _shake_fuerza := 0.0
var _shake_offset := Vector3.ZERO
const SHAKE_DECAIMIENTO := 4.5  ## que tan rapido se apaga la sacudida
const SHAKE_ESCALA := 0.06      ## que tan fuerte se ve, en metros


func _ready() -> void:
	# Captura el mouse para poder mirar alrededor (lo esconde y lo centra)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_crear_prompt()

	if terminal:
		terminal.pantalla_abierta.connect(func(): set_physics_process(false))
		terminal.pantalla_cerrada.connect(func():
			set_physics_process(true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		)

	if resultado:
		resultado.pantalla_abierta.connect(func(): set_physics_process(false))
		resultado.pantalla_cerrada.connect(func():
			set_physics_process(true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		)

	IncidenteDDoS.impacto_camara.connect(_on_impacto_camara)


func _on_impacto_camara(intensidad: float) -> void:
	# Suma en vez de reemplazar: si llegan dos golpes seguidos, se nota mas.
	_shake_fuerza = minf(1.0, _shake_fuerza + intensidad)


func _unhandled_input(event: InputEvent) -> void:
	# Si la terminal o la pantalla de resultados están abiertas, el jugador
	# no rota la cámara ni mueve el mouse
	if (terminal and terminal.abierta) or (resultado and resultado.abierta):
		return

	# Rotación de cámara con el mouse
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSITIVITY)
		head.rotate_x(-event.relative.y * SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# Presiona ESC para liberar el mouse (útil para probar/depurar)
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Aplica gravedad si no está en el suelo
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Lee el input de movimiento (WASD) como un vector 2D
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_procesar_interaccion(delta)
	_procesar_shake(delta)


func _procesar_interaccion(delta: float) -> void:
	if (terminal and terminal.abierta) or (resultado and resultado.abierta):
		_prompt.visible = false
		return

	var objetivo = rayo.get_collider() if rayo.is_colliding() else null

	# --- Racks de servidor: mantener E ---
	if objetivo is ServidorFisico:
		_prompt.text = objetivo.texto_prompt()
		_prompt.visible = true
		if Input.is_action_pressed("interactuar"):
			objetivo.mantener_interaccion(delta)
			_rack_actual = objetivo
		else:
			if _rack_actual != null:
				_rack_actual.soltar_interaccion()
				_rack_actual = null
		return

	# Si dejamos de mirar un rack que estaba en proceso, cancelar
	if _rack_actual != null:
		_rack_actual.soltar_interaccion()
		_rack_actual = null

	# --- Terminal de mitigación: pulsar E (una sola vez) ---
	if objetivo != null and objetivo.is_in_group("terminal_ddos"):
		_prompt.text = "[E] Abrir consola de mitigación"
		_prompt.visible = true
		if Input.is_action_just_pressed("interactuar") and terminal:
			terminal.abrir()
		return

	_prompt.visible = false


func _procesar_shake(delta: float) -> void:
	# Deshace el offset del frame anterior antes de calcular el nuevo,
	# para no ir acumulando desplazamiento permanente en la camara.
	camera.position -= _shake_offset

	_shake_fuerza = maxf(0.0, _shake_fuerza - SHAKE_DECAIMIENTO * delta)
	if _shake_fuerza <= 0.001:
		_shake_offset = Vector3.ZERO
		return

	_shake_offset = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		0.0
	) * _shake_fuerza * SHAKE_ESCALA

	camera.position += _shake_offset


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
	_prompt.offset_bottom = -80
	_prompt.offset_top = -120
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color(1, 1, 1))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.visible = false
	capa.add_child(_prompt)
