extends CharacterBody3D

const SPEED := 5.0
const GRAVITY := 9.8
const MOUSE_SENSITIVITY := 0.002

var camera_pitch := 0.0

var current_interactable: Interactable = null

@onready var interaction_ray: RayCast3D = $Camera3D/InteractionRay
@onready var interaction_label: Label = $"../InteractionUI/InteractionLabel"

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var direction := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		direction.z += 1

	if Input.is_key_pressed(KEY_S):
		direction.z -= 1

	if Input.is_key_pressed(KEY_A):
		direction.x += 1

	if Input.is_key_pressed(KEY_D):
		direction.x -= 1

	if direction.length() > 0:
		direction = direction.normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	move_and_slide()

	check_interaction()


func check_interaction():
	if interaction_ray.is_colliding():
		var object = interaction_ray.get_collider()

		if object is Interactable:
			if current_interactable != object:
				current_interactable = object
				print("OBJETO INTERACTUABLE: ", object.name)

			interaction_label.visible = true
			return

	if current_interactable != null:
		current_interactable = null

	interaction_label.visible = false


func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

		camera_pitch -= event.relative.y * MOUSE_SENSITIVITY
		camera_pitch = clamp(camera_pitch, -1.5, 1.5)

		$Camera3D.rotation.x = camera_pitch

	if event.is_action_pressed("interact") and current_interactable:
		current_interactable.interact()
