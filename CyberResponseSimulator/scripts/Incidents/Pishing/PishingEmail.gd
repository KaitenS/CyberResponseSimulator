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
