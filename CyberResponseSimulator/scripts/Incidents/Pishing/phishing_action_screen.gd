extends Control

var controller: PishingIncidentController = null

func set_controller(value: PishingIncidentController) -> void:
	controller = value
	_process(0.0)

func is_blocking() -> bool:
	return is_instance_valid(controller) and (controller.compromised or controller.update_remaining > 0.0)

func _process(_delta: float) -> void:
	visible = is_blocking()
	if not visible:
		return
	var breached := controller.compromised
	$Background.color = Color("660c18") if breached else Color("092d62")
	$Content/Logo.visible = not breached
	$Content/Cybug.visible = breached
	$Content/Title.text = "EQUIPO COMPROMETIDO" if breached else ("APLICANDO ACTUALIZACIÓN" if controller.action_is_update else "ABRIENDO CONTENIDO")
	$Content/Description.text = "Se abrió contenido fraudulento.\nEl incidente de Phishing ha fallado." if breached else ("Instalando componentes...\n" if controller.action_is_update else "Abriendo contenido verificado...\n") + controller.action_description + "\nEl tiempo sigue avanzando."
	$Content/Progress.visible = not breached
	$Content/Progress.value = 100.0 * (1.0 - controller.update_remaining / maxf(1.0, controller.update_total))
	$Content/Status.text = "ALERTA CRS | Acceso no autorizado detectado" if breached else "%d segundos restantes" % ceili(controller.update_remaining)
