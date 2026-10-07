extends CharacterBody3D

const SPEED := 5.0
const GRAVITY := 9.8
const MOUSE_SENSITIVITY := 0.002

var camera_pitch := 0.0
var current_interactable: Interactable = null

@onready var camera: Camera3D = $Camera3D
@onready var interaction_ray: RayCast3D = $Camera3D/InteractionRay
@onready var interaction_label: Label = get_tree().current_scene.get_node_or_null("InteractionUI/InteractionLabel")


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta):
	# ==========================================
	# GRAVEDAD
	# ==========================================

	if not is_on_floor():
		velocity.y -= GRAVITY * delta


	# ==========================================
	# INPUT WASD
	# ==========================================

	var input_vector := Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		input_vector.y += 1.0

	if Input.is_key_pressed(KEY_S):
		input_vector.y -= 1.0

	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0

	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0

	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()


	# ==========================================
	# DIRECCIÓN REAL DE LA CÁMARA
	# ==========================================

	var forward := -camera.global_transform.basis.z
	var right := camera.global_transform.basis.x

	# Ignorar la inclinación vertical de la cámara
	forward.y = 0.0
	right.y = 0.0

	forward = forward.normalized()
	right = right.normalized()


	# ==========================================
	# MOVIMIENTO
	# ==========================================

	var direction := Vector3.ZERO

	direction += forward * input_vector.y
	direction += right * input_vector.x

	if direction.length() > 0.0:
		direction = direction.normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	move_and_slide()


	# ==========================================
	# INTERACCIÓN
	# ==========================================

	check_interaction()


func check_interaction():
	if interaction_ray.is_colliding():
		var object = interaction_ray.get_collider()

		print("RAYCAST GOLPEA: ", object.name)
		print("TIPO: ", object.get_class())

		if object is Interactable:
			if current_interactable != object:
				current_interactable = object
				print("OBJETO INTERACTUABLE: ", object.name)

			if interaction_label:
				interaction_label.visible = true

			return

	if current_interactable != null:
		current_interactable = null

	if interaction_label:
		interaction_label.visible = false


func _input(event):
	# ==========================================
	# CÁMARA
	# ==========================================

	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:

			rotate_y(
				-event.relative.x * MOUSE_SENSITIVITY
			)

			camera_pitch -= (
				event.relative.y * MOUSE_SENSITIVITY
			)

			camera_pitch = clamp(
				camera_pitch,
				-1.5,
				1.5
			)

			camera.rotation.x = camera_pitch


	# ==========================================
	# INTERACCIÓN
	# ==========================================

	if event.is_action_pressed("interact"):
		if current_interactable:
			current_interactable.interact()


	# ==========================================
	# LIBERAR MOUSE
	# ==========================================

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(
			Input.MOUSE_MODE_VISIBLE
		)


	# ==========================================
	# VOLVER A CAPTURAR MOUSE
	# ==========================================

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				Input.set_mouse_mode(
					Input.MOUSE_MODE_CAPTURED
				)
