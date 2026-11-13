extends Interactable
## Puerta con colisión móvil. No toca la lógica de los incidentes.
@export_range(45.0, 110.0, 1.0) var opening_degrees: float = 90.0
@export_range(0.1, 2.0, 0.05) var animation_seconds: float = 0.45
var is_open: bool = false
var moving: bool = false

func interact() -> void:
	if moving:
		return
	if is_open:
		# No cerrar sobre el jugador si está cruzando el umbral.
		for body in get_parent().get_node("Clearance").get_overlapping_bodies():
			if body is CharacterBody3D:
				return
	var target := 0.0
	if not is_open:
		var player = get_tree().current_scene.get_node_or_null("Player")
		var side := 1.0
		if player != null:
			side = 1.0 if get_parent().to_local(player.global_position).z >= 0.0 else -1.0
		target = deg_to_rad(opening_degrees) * side
	moving = true
	is_open = not is_open
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", target, animation_seconds)
	await tween.finished
	moving = false
