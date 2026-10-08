extends Control

signal close_requested


func _ready() -> void:
	print("===== CYBERDESK.GD CARGADO =====")
	print("NODO: ", self)
	print("SCRIPT: ", get_script())
	print("================================")


func _on_close_button_pressed() -> void:
	print("===== METODO CLOSE PRESSED EJECUTADO =====")
	print("NODO QUE EJECUTA EL METODO: ", self)
	print("==========================================")

	close_requested.emit()

	print("===== SIGNAL close_requested EMITIDO =====")
