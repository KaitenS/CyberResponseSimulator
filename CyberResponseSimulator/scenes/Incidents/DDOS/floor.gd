extends StaticBody3D
## Escena de la sala de servidores del incidente DDoS.
##
## Dos modos:
##  - Integrado: el IncidentFlowManager del equipo eligio "ddos" y trajo al
##    jugador aqui. El incidente arranca de inmediato, al terminar se
##    actualizan los contadores del GameManager y el jugador vuelve a Game.tscn.
##  - Independiente (F6 sobre esta escena): el nodo "Disparador" arranca el
##    ataque tras su retardo, como siempre, para poder probar la mecanica sola.

const ESCENA_JUEGO := "res://scenes/Game/Game.tscn"

var _incidente_flujo: IncidentData = null


func _ready() -> void:
	$Player.terminal = $Terminal
	$Player.resultado = $Resultado

	_incidente_flujo = _buscar_incidente_en_flujo()
	if _incidente_flujo == null:
		return  # modo independiente

	$Resultado.configurar_modo_integrado()
	IncidenteDDoS.incidente_terminado.connect(_on_incidente_terminado)
	$Resultado.pantalla_cerrada.connect(_volver_al_juego)
	$Disparador.forzar_inicio()


## El IncidentFlowManager registra el incidente en IncidentManager antes de
## cambiar de escena; si esta ahi, venimos desde el flujo del juego.
func _buscar_incidente_en_flujo() -> IncidentData:
	for incidente in IncidentManager.active_incidents:
		if incidente.incident_id == "ddos":
			return incidente
	return null


func _on_incidente_terminado(exito: bool, _resumen: Dictionary) -> void:
	if exito:
		GameManager.incidents_completed += 1
	else:
		GameManager.incidents_failed += 1
	IncidentManager.finish_incident(_incidente_flujo)


func _volver_al_juego() -> void:
	get_tree().change_scene_to_file(ESCENA_JUEGO)
