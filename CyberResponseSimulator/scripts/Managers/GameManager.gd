extends Node

var game_active: bool = false
var score: int = 0
var phishing_results: Array[Dictionary] = []
var incidents_completed: int = 0
var incidents_failed: int = 0
var time_remaining: float = GAME_DURATION

const GAME_DURATION: float = 60.0

signal game_ended

func start_game():
	game_active = true
	score = 0
	phishing_results.clear()
	incidents_completed = 0
	incidents_failed = 0
	time_remaining = 600.0  # SOLO PARA PROBAR: volver a 60.0 antes del commit


func _process(delta: float) -> void:
	if not game_active:
		return

	time_remaining -= delta

	if time_remaining <= 0.0:
		time_remaining = 0.0
		end_game()


func end_game():
	game_active = false
	game_ended.emit()
