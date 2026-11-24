extends TextureRect

func _ready() -> void:
	$TitleBar/HBoxContainer/CloseButton.pressed.connect(hide)