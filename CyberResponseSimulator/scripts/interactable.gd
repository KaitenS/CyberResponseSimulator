# interactable.gd
# Clase base que deben extender todos los objetos con los que el jugador
# pueda interactuar (computadores, puertas, servidores, documentos, etc).
class_name Interactable
extends Node3D

# Texto que se mostrará como prompt de interacción (ej. "Presiona E para revisar el correo")
@export var interaction_prompt: String = "Presiona E para interactuar"

# Método que cada objeto interactuable debe sobrescribir con su propia lógica.
func interact() -> void:
	print("Interact() no implementado en: ", name)
