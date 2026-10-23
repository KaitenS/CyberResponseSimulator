extends Control

signal close_requested

var malware_controller: MalwareIncidentController = null

# Ventana "Servidores" (DDoS). Se crea por codigo, vive dentro de esta pantalla.
var ddos_window: VentanaDDoSPC = null

## El cursor del PC dibuja la flecha con la punta arriba-izquierda, pero el
## clic cae en el centro del sprite (24x24). Se acepta el clic si CUALQUIERA
## de los dos puntos toca el icono.
const CURSOR_PUNTA := Vector2(12.0, 12.0)


func set_malware_controller(controller: MalwareIncidentController) -> void:
	malware_controller = controller


func _ready() -> void:
	print("===== CYBERDESK.GD CARGADO =====")
	print("NODO: ", self)
	print("SCRIPT: ", get_script())
	print("================================")

	ddos_window = VentanaDDoSPC.new()
	ddos_window.name = "DDoSWindow"
	add_child(ddos_window)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			# Si la ventana de Servidores esta abierta y el click cae sobre
			# ella, la ventana lo atiende y nada de lo que hay detras reacciona.
			if ddos_window != null and ddos_window.procesar_click(event.position):
				return

			# Si el click cae sobre la ventana de Malware, los íconos
			# del escritorio que quedan detrás no deben reaccionar.
			var malware_window_ref: Control = get_node_or_null(
				"Windows/MalwareWindow"
			)

			var click_on_malware: bool = (
				malware_window_ref != null
				and malware_window_ref.visible
				and malware_window_ref.get_global_rect().has_point(event.position)
			)

			# ==========================================
			# DAILY SUMMARY
			# ==========================================

			var daily_summary_button: Button = get_node_or_null(
				"DesktopIcons/GridContainer/DailySummary Button"
			)

			if daily_summary_button != null and not click_on_malware:
				var daily_summary_rect: Rect2 = (
					daily_summary_button.get_global_rect()
				)

				if daily_summary_rect.has_point(event.position):
					print("===== DAILY SUMMARY DETECTADO =====")
					_on_daily_summary_button_pressed()


			# ==========================================
			# CYBERMAIL
			# ==========================================

			var email_button: Button = get_node_or_null(
				"DesktopIcons/GridContainer/Email Button"
			)

			if email_button != null and not click_on_malware:
				var email_rect: Rect2 = (
					email_button.get_global_rect()
				)

				if email_rect.has_point(event.position):
					print("===== CYBERMAIL DETECTADO =====")
					_on_email_button_pressed()


			# ==========================================
			# ARCHIVOS (MALWARE)
			# ==========================================

			var files_button: Button = get_node_or_null(
				"DesktopIcons/GridContainer/Files Button"
			)

			if files_button != null and not click_on_malware:
				var files_rect: Rect2 = files_button.get_global_rect()

				if files_rect.has_point(event.position):
					print("===== ARCHIVOS DETECTADO =====")
					_on_files_button_pressed()


			# ==========================================
			# SERVIDORES (DDOS)
			# ==========================================

			var server_button: Button = get_node_or_null(
				"DesktopIcons/GridContainer/Server Button"
			)

			if server_button != null and not click_on_malware:
				var server_rect: Rect2 = server_button.get_global_rect()

				if server_rect.has_point(event.position) \
				or server_rect.has_point(event.position - CURSOR_PUNTA):
					print("===== SERVIDORES DETECTADO =====")
					_on_server_button_pressed()

			# ==========================================
			# CERRAR MALWARE
			# ==========================================

			var malware_window: Control = get_node_or_null(
				"Windows/MalwareWindow"
			)

			if malware_window != null and malware_window.visible:
				var malware_close_zone := Rect2(
					560.0,
					118.0,
					80.0,
					60.0
				)

				if malware_close_zone.has_point(event.position):
					print("===== CERRAR MALWARE =====")
					close_window(malware_window)


			# ==========================================
			# CERRAR CYBERMAIL
			# ==========================================

			var cybermail_window: TextureRect = get_node_or_null(
				"Windows/CyberMailWindow"
			)

			if cybermail_window != null and cybermail_window.visible and not click_on_malware:

				var cybermail_close_zone := Rect2(
					560.0,
					118.0,
					80.0,
					60.0
				)

				if cybermail_close_zone.has_point(event.position):
					print("===== CERRAR CYBERMAIL =====")

					close_window(cybermail_window)


			# ==========================================
			# CERRAR DAILY SUMMARY
			# ==========================================

			var daily_summary_window: TextureRect = get_node_or_null(
				"Windows/DailySummaryWindow"
			)

			if daily_summary_window != null and daily_summary_window.visible and not click_on_malware:

				# Daily Summary se encuentra aproximadamente
				# en X = 22
				# Y = 118
				# Ancho = 600
				# Alto = 400
				#
				# La X está en la esquina superior derecha.

				var daily_summary_close_zone := Rect2(
					560.0,
					118.0,
					80.0,
					60.0
				)

				if daily_summary_close_zone.has_point(event.position):
					print("===== CERRAR DAILY SUMMARY =====")

					close_window(daily_summary_window)


# ==========================================
# DAILY SUMMARY
# ==========================================

func _on_daily_summary_button_pressed() -> void:
	if ddos_window != null:
		ddos_window.cerrar()

	print("===== DAILY SUMMARY BUTTON PRESSED =====")

	var daily_summary_window: TextureRect = get_node_or_null(
		"Windows/DailySummaryWindow"
	)

	if daily_summary_window == null:
		print("ERROR: No se encontró DailySummaryWindow")
		return

	daily_summary_window.visible = true

	print("DAILY SUMMARY VISIBLE")
	print("POSITION: ", daily_summary_window.position)
	print("SIZE: ", daily_summary_window.size)


# ==========================================
# CYBERMAIL
# ==========================================

func _on_email_button_pressed() -> void:
	if ddos_window != null:
		ddos_window.cerrar()

	print("===== CYBERMAIL BUTTON PRESSED =====")

	var cybermail_window: TextureRect = get_node_or_null(
		"Windows/CyberMailWindow"
	)

	if cybermail_window == null:
		print("ERROR: No se encontró CyberMailWindow")
		return

	cybermail_window.position = Vector2(20.0, 118.0)
	cybermail_window.visible = true

	print("CYBERMAIL VISIBLE")
	print("POSITION: ", cybermail_window.position)
	print("SIZE: ", cybermail_window.size)


# ==========================================
# ARCHIVOS (MALWARE)
# ==========================================

func _on_files_button_pressed() -> void:
	if ddos_window != null:
		ddos_window.cerrar()

	var malware_window: Control = get_node_or_null(
		"Windows/MalwareWindow"
	)

	if malware_window == null:
		print("ERROR: No se encontró MalwareWindow")
		return

	malware_window.position = Vector2(22.0, 118.0)

	if malware_controller == null:
		malware_window.show_empty()
	else:
		malware_window.open_investigation(malware_controller)


# ==========================================
# CERRAR UNA VENTANA
# ==========================================

func close_window(window: Control) -> void:
	if window == null:
		print("ERROR: No se recibió ninguna ventana.")
		return

	window.visible = false

	print("VENTANA CERRADA: ", window.name)


# ==========================================
# CERRAR CYBERDESK COMPLETO
# ==========================================

func _on_close_button_pressed() -> void:
	print("===== METODO CLOSE PRESSED EJECUTADO =====")
	print("NODO QUE EJECUTA EL METODO: ", self)
	print("==========================================")

	close_requested.emit()

	print("===== SIGNAL close_requested EMITIDO =====")


# ==========================================
# SERVIDORES (DDOS)
# ==========================================

func _on_server_button_pressed() -> void:
	if ddos_window == null:
		print("ERROR: no existe la ventana de Servidores")
		return

	# Un solo clic: abre la ventana siempre, haya o no un ataque en curso.
	# Se esconden las otras ventanas para que no se amontonen.
	for nombre in ["DailySummaryWindow", "CyberMailWindow", "MalwareWindow"]:
		var w: Control = get_node_or_null("Windows/" + nombre)
		if w != null:
			w.visible = false

	ddos_window.abrir()
