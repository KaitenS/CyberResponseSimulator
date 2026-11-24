extends StaticBody3D

func _ready() -> void:
	$Player.terminal = $Terminal
	$Player.resultado = $Resultado
	# El ataque ya no arranca aqui directamente: lo dispara el nodo
	# "Disparador" (script disparador_ddos.gd) despues de un retardo,
	# simulando que el DDoS interrumpe la jornada del jugador.
