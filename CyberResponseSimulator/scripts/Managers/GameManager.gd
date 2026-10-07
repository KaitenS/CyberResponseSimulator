extends Node

var game_active: bool = false
var score: int = 0
var incidents_completed: int = 0
var incidents_failed: int = 0
var time_remaining: float = 60.0


func start_game():
	game_active = true
	score = 0
	incidents_completed = 0
	incidents_failed = 0
	time_remaining = 60.0


func _process(delta: float) -> void:
	if not game_active:
		return

	time_remaining -= delta

	if time_remaining <= 0.0:
		time_remaining = 0.0
		end_game()


func end_game():
	game_active = false
