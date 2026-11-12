extends CanvasLayer

@onready var time_display: Control = $TimeDisplay


func _process(_delta: float) -> void:
	time_display.update_time(GameManager.GAME_DURATION, GameManager.time_remaining, GameManager.game_active)