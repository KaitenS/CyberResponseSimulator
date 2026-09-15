extends Node

var game_active: bool = false

var score: int = 0

var incidents_completed: int = 0
var incidents_failed: int = 0

var time_remaining: float = 600.0


func start_game():
	game_active = true

	score = 0
	incidents_completed = 0
	incidents_failed = 0
	time_remaining = 600.0

#Solamente estan para verificar si Funciona al darle al botron [Iniciar simulacion] del Menu
	print("GAME STARTED")
	print("Tiempo: ", time_remaining)

func end_game():
	game_active = false
