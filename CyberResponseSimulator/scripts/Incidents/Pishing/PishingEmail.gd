class_name PhishingEmail
extends Resource


@export var email_id: String = ""

@export var sender_name: String = ""
@export var sender_address: String = ""

@export var recipient: String = ""

@export var subject: String = ""

@export_multiline var body: String = ""

@export var attachment_name: String = ""
@export var has_attachment: bool = false

@export var is_phishing: bool = false


# Explicación pedagógica que se revela al terminar el día.
@export_multiline var explanation: String = ""
## Texto mostrado y destino real del enlace de práctica.
@export var link_text: String = ""
@export var link_url: String = ""

## Abrir esta actualización legítima consume tiempo del incidente.
@export var simulates_update: bool = false
@export_range(1.0, 60.0, 1.0) var update_duration: float = 10.0
