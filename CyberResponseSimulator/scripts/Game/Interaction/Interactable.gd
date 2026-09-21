class_name Interactable
extends Node3D


@export var interaction_text: String = "[E] Interactuar"


func interact():
	print("INTERACCIÓN: ", name)
