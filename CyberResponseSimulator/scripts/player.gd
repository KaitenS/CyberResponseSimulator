extends CharacterBody3D

const SPEED = 5.0
const SENSITIVITY = 0.003

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/RayCast3D  # NUEVO

var current_interactable: Interactable = null  # NUEVO: lo que el rayo está mirando ahora

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENSITIVITY)
		head.rotate_x(-event.relative.y * SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# NUEVO: si presiona interactuar y hay algo interactuable enfrente, lo ejecuta
	if event.is_action_pressed("interact") and current_interactable:
		current_interactable.interact()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	_check_interaction()  # NUEVO

# NUEVO: revisa cada frame si el rayo está mirando un objeto interactuable
func _check_interaction() -> void:
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider is Interactable:
			if current_interactable != collider:
				current_interactable = collider
				print("Mirando: ", current_interactable.name, " -> ", current_interactable.interaction_prompt)
			return

	# Si llegó aquí, no hay nada interactuable enfrente
	if current_interactable != null:
		current_interactable = null
