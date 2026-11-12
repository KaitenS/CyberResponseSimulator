extends PanelContainer

@export var clock_sound_enabled: bool = true

var _running := false
var _alternate_tick := false

func _ready() -> void:
	$TickTimer.timeout.connect(_tick)


func update_time(duration: float, remaining: float, active: bool) -> void:
	var total := maxf(duration, 0.001)
	var left := clampf(remaining, 0.0, total)
	var elapsed := total - left
	$Layout/Readout/Progress.value = 100.0 * elapsed / total
	var seconds := ceili(left)
	$Layout/Readout/TimeLabel.text = "TIEMPO RESTANTE  %02d:%02d" % [seconds / 60, seconds % 60]
	$Layout/Clock/Hands/Second.rotation = TAU * fposmod(elapsed, 60.0) / 60.0
	$Layout/Clock/Hands/Minute.rotation = TAU * fposmod(elapsed, 3600.0) / 3600.0
	$Layout/Clock/Hands/Hour.rotation = TAU * fposmod(elapsed, 43200.0) / 43200.0
	var should_tick := active and left > 0.0 and clock_sound_enabled
	if should_tick and not _running:
		_running = true
		$TickTimer.start()
		_tick()
	elif not should_tick:
		_running = false
		$TickTimer.stop()
		$TickSound.stop()


func _tick() -> void:
	if not _running:
		return
	_alternate_tick = not _alternate_tick
	$TickSound.pitch_scale = 1.0 if _alternate_tick else 0.82
	$TickSound.play()
