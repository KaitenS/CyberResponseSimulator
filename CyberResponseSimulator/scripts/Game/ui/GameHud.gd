extends CanvasLayer

@onready var time_label: Label = $TimeLabel


func _process(_delta: float) -> void:
	if not GameManager.game_active:
		return

	var total_seconds := int(ceil(GameManager.time_remaining))

	var minutes := total_seconds / 60.0
	var seconds := total_seconds % 60

	time_label.text = "TIEMPO RESTANTE: %02d:%02d" % [minutes, seconds]
