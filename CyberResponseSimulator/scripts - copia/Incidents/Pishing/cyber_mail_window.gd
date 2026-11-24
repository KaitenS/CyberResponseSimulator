extends TextureRect


var subject_label: Label
var sender_label: Label
var attachment_label: Label

var controller: PishingIncidentController = null
var selected_email: PhishingEmail = null
var rows: Array[Control] = []
var inbox: VBoxContainer
var detail: VBoxContainer
var message: RichTextLabel
var accept_button: Button
var reject_button: Button
var status_label: Label

func _ready() -> void:
	inbox = $InboxScroll/MailList
	detail = $EmailDetail
	subject_label = $EmailDetail/Subject
	sender_label = $EmailDetail/Sender
	message = $EmailDetail/Body
	attachment_label = $EmailDetail/Attachment
	accept_button = $EmailDetail/Actions/AcceptButton
	reject_button = $EmailDetail/Actions/RejectButton
	status_label = $Status
	for i in range(inbox.get_child_count()):
		var row := inbox.get_child(i) as Control
		rows.append(row)
		row.get_node("OpenButton").pressed.connect(_select_row.bind(i))
	$EmailDetail/Actions/BackButton.pressed.connect(_back_to_inbox)
	accept_button.pressed.connect(_respond.bind(true))
	reject_button.pressed.connect(_respond.bind(false))
	$TitleBar/HBoxContainer/CloseButton.pressed.connect(hide)
	_back_to_inbox()


func set_controller(value: PishingIncidentController) -> void:
	if is_instance_valid(controller):
		controller.email_received.disconnect(_on_email_received)
		controller.email_resolved.disconnect(_on_email_resolved)
		controller.incident_finished.disconnect(_on_finished)
		controller.time_updated.disconnect(_on_time_updated)
	controller = value
	selected_email = null
	if is_instance_valid(controller):
		controller.email_received.connect(_on_email_received)
		controller.email_resolved.connect(_on_email_resolved)
		controller.incident_finished.connect(_on_finished)
		controller.time_updated.connect(_on_time_updated)
	_back_to_inbox()

func _back_to_inbox() -> void:
	detail.hide()
	inbox.get_parent().show()
	_refresh()

func _refresh() -> void:
	var emails: Array[PhishingEmail] = []
	if is_instance_valid(controller):
		emails = controller.get_received_emails()
	for i in range(rows.size()):
		rows[i].visible = i < emails.size()
		if i >= emails.size():
			continue
		var email := emails[i]
		var content := rows[i].get_node("VBoxContainer")
		content.get_node("SenderLabel").text = email.sender_name
		var prefix := "[Respondido] " if controller.is_email_resolved(email) else ""
		content.get_node("SubjectLabel").text = prefix + email.subject
		content.get_node("AttachmentLabel").text = email.attachment_name if email.has_attachment else "Sin archivos adjuntos"
	_update_actions()
	_on_time_updated(controller.time_remaining if is_instance_valid(controller) else 0.0)

func _select_row(index: int) -> void:
	if not is_instance_valid(controller):
		return
	var emails := controller.get_received_emails()
	if index >= emails.size():
		return
	selected_email = emails[index]
	subject_label.text = selected_email.subject
	sender_label.text = "De: %s <%s>\nPara: %s" % [selected_email.sender_name, selected_email.sender_address, selected_email.recipient]
	message.text = selected_email.body
	attachment_label.text = "ADJUNTO  |  " + (selected_email.attachment_name if selected_email.has_attachment else "Sin archivos adjuntos")
	inbox.get_parent().hide()
	detail.show()
	_update_actions()

func _update_actions() -> void:
	var enabled := is_instance_valid(controller) and controller.incident_active and selected_email != null
	if enabled:
		enabled = not controller.is_email_resolved(selected_email)
	accept_button.disabled = not enabled
	reject_button.disabled = not enabled

func _respond(accepted: bool) -> void:
	if is_instance_valid(controller) and selected_email != null:
		controller.resolve_email(selected_email, accepted)
		_refresh()

func _on_email_received(_email: PhishingEmail) -> void:
	_refresh()

func _on_email_resolved(_email: PhishingEmail, _accepted: bool) -> void:
	_refresh()

func _on_finished(_completed: bool) -> void:
	_refresh()

func _on_time_updated(seconds: float) -> void:
	if not is_instance_valid(controller):
		status_label.text = "No hay un incidente de Phishing."
	elif controller.incident_active:
		status_label.text = "Tiempo: %ds | Recibidos: %d | Respondidos: %d" % [ceili(seconds), controller.received_emails.size(), controller.resolved_emails.size()]
	else:
		status_label.text = "Incidente finalizado | Respondidos: %d/%d" % [controller.resolved_emails.size(), controller.selected_emails.size()]
