extends Node
## Pasos según recorrido real; no suenan en el aire ni al empujar una pared.
@export var sfx_enabled: bool = true
@export_range(0.5, 3.0, 0.05) var step_distance: float = 1.8
@export_range(0.05, 1.0, 0.05) var minimum_walk_speed: float = 0.2
var _distance_walked: float = 0.0
var _next_left: bool = true
var _was_using_computer: bool = false
var _rng := RandomNumberGenerator.new()
@onready var player: CharacterBody3D = get_parent() as CharacterBody3D

func _ready() -> void:
	_rng.randomize()

func _physics_process(delta: float) -> void:
	var using_computer: bool = player.camera_locked
	if using_computer and not _was_using_computer and sfx_enabled:
		$ComputerEnter.play()
	_was_using_computer = using_computer
	if not sfx_enabled or using_computer or not player.is_on_floor():
		_distance_walked = 0.0
		$FootstepLeft.stop()
		$FootstepRight.stop()
		return
	var movement := player.get_real_velocity()
	var speed := Vector2(movement.x, movement.z).length()
	if speed < minimum_walk_speed:
		_distance_walked = 0.0
		return
	_distance_walked += speed * delta
	if _distance_walked >= step_distance:
		_distance_walked = fmod(_distance_walked, step_distance)
		var sound: AudioStreamPlayer = $FootstepLeft if _next_left else $FootstepRight
		sound.pitch_scale = _rng.randf_range(0.95, 1.05)
		sound.play()
		_next_left = not _next_left
