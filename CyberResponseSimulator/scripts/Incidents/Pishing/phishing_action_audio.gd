extends Node
## Sigue la pantalla visual; no modifica decisiones, tiempos ni consecuencias.
@export var sfx_enabled: bool = true
var _state: StringName = &"idle"

func _ready() -> void:
	$UpdateWork.finished.connect(_repeat_work)
	$FraudAlert.finished.connect(_repeat_alert)

func _process(_delta: float) -> void:
	var next_state := _screen_state()
	if next_state == _state:
		return
	_state = next_state
	$UpdateStart.stop()
	$UpdateWork.stop()
	$FraudAlert.stop()
	if _state == &"updating":
		$UpdateStart.play()
		$UpdateWork.play()
	elif _state == &"breached":
		$FraudAlert.play()

func _screen_state() -> StringName:
	if not sfx_enabled:
		return &"idle"
	var controller = get_parent().controller
	if not is_instance_valid(controller):
		return &"idle"
	if controller.compromised:
		return &"breached"
	if controller.update_remaining > 0.0:
		return &"updating"
	return &"idle"

func _repeat_work() -> void:
	if _screen_state() == &"updating":
		$UpdateWork.play()

func _repeat_alert() -> void:
	if _screen_state() == &"breached":
		$FraudAlert.play()
