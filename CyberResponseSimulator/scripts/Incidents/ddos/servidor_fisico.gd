extends StaticBody3D
class_name ServidorFisico
## Rack fisico dentro de la sala de servidores.
## El jugador se para frente a el y MANTIENE la tecla de interaccion
## durante 5 segundos para reiniciarlo. Si se suelta, se cancela.
##
## Estructura sugerida de la escena:
##   ServidorFisico (StaticBody3D)  <- este script
##     |- CollisionShape3D
##     |- MeshInstance3D            (el rack)
##     |- Label3D "Pantalla"        (texto de estado)
##     |- OmniLight3D "Luz"         (verde/rojo segun estado)

@export var id_servidor: IncidenteDDoS.Servidor = IncidenteDDoS.Servidor.ALERTAS

@export var pantalla: Label3D
@export var luz: OmniLight3D
@export var malla: MeshInstance3D

@export var color_ok := Color(0.25, 1.0, 0.45)
@export var color_alerta := Color(1.0, 0.75, 0.15)
@export var color_caido := Color(1.0, 0.2, 0.2)

var _manteniendo := false
var _progreso := 0.0
var _parpadeo := 0.0


func _ready() -> void:
	add_to_group("interactuable")
	IncidenteDDoS.servidor_estado_cambiado.connect(_on_estado_cambiado)
	_refrescar_pantalla()


# ------------------------------------------------- API que llama el jugador

func texto_prompt() -> String:
	if not IncidenteDDoS.activo:
		return "%s - operativo" % IncidenteDDoS.NOMBRE_SERVIDOR[id_servidor]
	if IncidenteDDoS.apagon_restante > 0.0:
		return "Reinicio general en curso..."
	if IncidenteDDoS.esta_online(id_servidor):
		return "[MANTENER E] Reiniciar %s  (carga %d%%)" % [
			IncidenteDDoS.NOMBRE_SERVIDOR[id_servidor],
			int(IncidenteDDoS.carga_de(id_servidor))
		]
	return "[MANTENER E] RESTAURAR %s" % IncidenteDDoS.NOMBRE_SERVIDOR[id_servidor]


## Llamalo cada frame mientras el jugador mira el rack y mantiene la tecla.
func mantener_interaccion(delta: float) -> void:
	if not IncidenteDDoS.activo or IncidenteDDoS.apagon_restante > 0.0:
		return
	if not _manteniendo:
		if not IncidenteDDoS.iniciar_reinicio(id_servidor):
			return
		_manteniendo = true
	_progreso = IncidenteDDoS.avanzar_reinicio(id_servidor, delta)
	if _progreso >= 1.0:
		_manteniendo = false
		_progreso = 0.0


## Llamalo cuando el jugador suelta la tecla o deja de mirar el rack.
func soltar_interaccion() -> void:
	if not _manteniendo:
		return
	_manteniendo = false
	_progreso = 0.0
	IncidenteDDoS.cancelar_reinicio(id_servidor)


# ------------------------------------------------------------- VISUAL

func _process(delta: float) -> void:
	_parpadeo += delta
	_refrescar_pantalla()
	_refrescar_luz()


func _refrescar_pantalla() -> void:
	if pantalla == null:
		return

	var nombre: String = IncidenteDDoS.NOMBRE_SERVIDOR[id_servidor]

	if _manteniendo:
		var barras := int(_progreso * 12.0)
		pantalla.text = "%s\nREINICIANDO\n[%s%s] %d%%" % [
			nombre,
			"#".repeat(barras),
			".".repeat(12 - barras),
			int(_progreso * 100.0)
		]
		pantalla.modulate = color_alerta
		return

	if not IncidenteDDoS.activo:
		pantalla.text = "%s\nOPERATIVO" % nombre
		pantalla.modulate = color_ok
		return

	if not IncidenteDDoS.esta_online(id_servidor):
		var visible_ahora := fmod(_parpadeo, 0.8) < 0.5
		pantalla.text = "%s\n%s" % [nombre, "FUERA DE SERVICIO" if visible_ahora else ""]
		pantalla.modulate = color_caido
		return

	var carga := IncidenteDDoS.carga_de(id_servidor)
	pantalla.text = "%s\nCARGA %d%%\n%s" % [nombre, int(carga), _barra(carga)]
	pantalla.modulate = color_ok if carga < 60.0 else color_alerta


func _barra(valor: float) -> String:
	var n := int(valor / 100.0 * 10.0)
	return "[%s%s]" % ["|".repeat(n), " ".repeat(10 - n)]


func _refrescar_luz() -> void:
	if luz == null:
		return
	if not IncidenteDDoS.activo:
		luz.light_color = color_ok
		luz.light_energy = 1.0
		return
	if not IncidenteDDoS.esta_online(id_servidor):
		luz.light_color = color_caido
		luz.light_energy = 1.0 + sin(_parpadeo * 12.0) * 0.8
	elif IncidenteDDoS.carga_de(id_servidor) > 60.0:
		luz.light_color = color_alerta
		luz.light_energy = 1.0 + sin(_parpadeo * 6.0) * 0.4
	else:
		luz.light_color = color_ok
		luz.light_energy = 1.0


func _on_estado_cambiado(id: int, _online: bool) -> void:
	if id == id_servidor:
		_refrescar_pantalla()
