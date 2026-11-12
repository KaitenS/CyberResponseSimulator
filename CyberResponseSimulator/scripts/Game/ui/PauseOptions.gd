extends Panel
signal back_requested

@onready var volume_slider: HSlider = $OptionsContainer/VolumeSlider
@onready var fullscreen_check: CheckBox = $OptionsContainer/FullScreenRow/FullScreenCheck

func _ready() -> void:
	volume_slider.value_changed.connect(_set_volume)
	fullscreen_check.toggled.connect(_set_fullscreen)
	$OptionsContainer/BackButton.pressed.connect(_back)
	sync_settings()


func sync_settings() -> void:
	var master := AudioServer.get_bus_index("Master")
	volume_slider.set_value_no_signal(0.0 if AudioServer.is_bus_mute(master) else db_to_linear(AudioServer.get_bus_volume_db(master)) * 100.0)
	var mode := DisplayServer.window_get_mode()
	fullscreen_check.set_pressed_no_signal(mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


func _set_volume(value: float) -> void:
	var master := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(value / 100.0, 0.0001)))


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)


func _back() -> void:
	back_requested.emit()
