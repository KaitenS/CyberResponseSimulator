extends Node
class_name DisparadorDDoS
## Dispara el incidente DDoS, ya sea automaticamente tras un retardo
## (simulando que el ataque interrumpe la jornada del jugador en un
## momento inesperado) o manualmente llamando a forzar_inicio().
##
## Uso:
##   1. Agrega este nodo (tipo Node) en cualquier parte de tu escena principal.
##   2. Ajusta "retardo_segundos" al tiempo que quieres que pase antes
##      de que llegue el ataque.
##   3. Si prefieres disparar el incidente desde otro evento del juego
##      (una llamada telefonica, un dialogo, una hora especifica del
##      reloj laboral), desactiva "iniciar_automatico" y llama a
##      forzar_inicio() desde el script que corresponda.

signal disparado()

@export var retardo_segundos: float = 20.0
@export var iniciar_automatico: bool = true
## Si es true, avisa por el log de la terminal unos segundos antes de que
## llegue el ataque (le da al jugador una pista de que algo se acerca).
@export var avisar_antes: bool = true
@export var segundos_de_aviso: float = 6.0

var _ya_disparado := false


func _ready() -> void:
	if not iniciar_automatico:
		return

	if avisar_antes and retardo_segundos > segundos_de_aviso:
		get_tree().create_timer(retardo_segundos - segundos_de_aviso).timeout.connect(_avisar)

	get_tree().create_timer(retardo_segundos).timeout.connect(_disparar)


func _avisar() -> void:
	# Aviso silencioso: no depende de que el incidente ya este activo,
	# asi que usamos print + una señal propia por si quieres conectar
	# un sonido o un mensaje en pantalla desde otro sistema del juego.
	print("[DisparadorDDoS] Trafico sospechoso detectandose en segundo plano...")


func _disparar() -> void:
	forzar_inicio()


## Llamalo desde donde quieras iniciar el ataque manualmente
## (un dialogo, una llamada, un boton de debug, etc).
func forzar_inicio() -> void:
	if _ya_disparado or IncidenteDDoS.activo:
		return
	_ya_disparado = true
	IncidenteDDoS.iniciar()
	emit_signal("disparado")


## Permite volver a armar el disparador para una siguiente ronda
## (util si tu jornada tiene mas de un incidente por partida).
func rearmar(nuevo_retardo: float = -1.0) -> void:
	_ya_disparado = false
	if nuevo_retardo > 0.0:
		retardo_segundos = nuevo_retardo
	if iniciar_automatico:
		if avisar_antes and retardo_segundos > segundos_de_aviso:
			get_tree().create_timer(retardo_segundos - segundos_de_aviso).timeout.connect(_avisar)
		get_tree().create_timer(retardo_segundos).timeout.connect(_disparar)
