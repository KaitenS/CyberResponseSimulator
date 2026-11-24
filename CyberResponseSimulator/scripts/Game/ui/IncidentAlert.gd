extends Panel

@export_range(1.0, 15.0, 0.5) var display_seconds: float = 5.0

func _ready() -> void:
	$DismissTimer.timeout.connect(_dismiss)
	GameManager.game_ended.connect(_dismiss)
	if get_tree().current_scene == self:
		show_alert()
	else:
		hide()


func show_alert() -> void:
	show()
	$DismissTimer.start(display_seconds)
	$AlertSound.play()


func _dismiss() -> void:
	hide()
	$DismissTimer.stop()
	$AlertSound.stop()
