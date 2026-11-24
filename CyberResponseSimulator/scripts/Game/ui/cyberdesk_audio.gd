extends Node
## Un clic por evento enviado al escritorio virtual, sin cambiar sus controles.
@export var sfx_enabled: bool = true
@export_range(0.01, 0.25, 0.01) var minimum_click_interval: float = 0.045
var _last_click_msec: int = -1000

func _input(event: InputEvent) -> void:
	if not sfx_enabled or not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var desktop := get_parent() as Control
	if not desktop.is_visible_in_tree() or not desktop.get_global_rect().has_point(event.position):
		return
	if desktop.get_node("PhishingActionScreen").is_blocking():
		return
	var now := Time.get_ticks_msec()
	if now - _last_click_msec < minimum_click_interval * 1000.0:
		return
	_last_click_msec = now
	$Click.play()
