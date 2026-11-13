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
	message.meta_clicked.connect(_on_link_clicked)
	$EmailDetail/OpenAttachment.pressed.connect(_on_attachment_pressed)
	message.meta_hover_started.connect(_on_link_hover)
	message.meta_hover_ended.connect(_on_link_exit)
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
	$EmailDetail/LinkDestination.text = ""
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
		content.get_node("StateLabel").text = controller.get_email_state(email)
		var prefix := ""
		content.get_node("SubjectLabel").text = prefix + email.subject
		content.get_node("AttachmentLabel").text = email.attachment_name if email.has_attachment else "Sin archivos adjuntos"
	if selected_email != null and is_instance_valid(controller):
		$EmailDetail/State.text = "Estado: " + controller.get_email_state(selected_email)
	_update_actions()
	_on_time_updated(controller.time_remaining if is_instance_valid(controller) else 0.0)

func _select_row(index: int) -> void:
	if not is_instance_valid(controller):
		return
	var emails := controller.get_received_emails()
	if index >= emails.size():
		return
	selected_email = emails[index]
	controller.mark_email_read(selected_email)
	_refresh()
	subject_label.text = selected_email.subject
	sender_label.text = "De: %s <%s>\nPara: %s" % [selected_email.sender_name, selected_email.sender_address, selected_email.recipient]
	_render_body(selected_email)
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
	$EmailDetail/OpenAttachment.visible = selected_email != null and selected_email.has_attachment
	$EmailDetail/OpenAttachment.disabled = not enabled

func _respond(accepted: bool) -> void:
	if is_instance_valid(controller) and selected_email != null:
		if accepted:
			controller.accept_email(selected_email)
		else:
			controller.resolve_email(selected_email, false)
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


func _render_body(email: PhishingEmail) -> void:
	message.clear()
	$EmailDetail/LinkDestination.text = ""
	$EmailDetail/Body.get_v_scroll_bar().value = 0
	var regex := RegEx.new()
	regex.compile("(?i)https?://[^\\s<>\\[\\]]+")
	var offset := 0
	for found in regex.search_all(email.body):
		message.add_text(email.body.substr(offset, found.get_start() - offset))
		var url := found.get_string().trim_suffix(".").trim_suffix(",")
		_append_link(url, url)
		message.add_text(found.get_string().substr(url.length()))
		offset = found.get_end()
	message.add_text(email.body.substr(offset))
	if not email.link_url.is_empty():
		message.add_text("\n\n")
		_append_link(email.link_text if not email.link_text.is_empty() else email.link_url, email.link_url)


func _append_link(caption: String, destination: String) -> void:
	message.push_color(Color("175dcc"))
	message.push_meta(destination)
	message.push_underline()
	message.add_text(caption)
	message.pop()
	message.pop()
	message.pop()


func _on_link_hover(destination: Variant) -> void:
	var url := str(destination)
	var host := url.get_slice("://", 1).get_slice("/", 0).get_slice("?", 0).get_slice("#", 0)
	host = host.get_slice("@", host.get_slice_count("@") - 1)
	$EmailDetail/LinkDestination.text = "Dominio: " + host
	$EmailDetail/LinkDestination.tooltip_text = "Destino: " + url


func _on_link_exit(_destination: Variant) -> void:
	$EmailDetail/LinkDestination.text = ""
	$EmailDetail/LinkDestination.tooltip_text = ""


func _on_link_clicked(_destination: Variant) -> void:
	if is_instance_valid(controller) and selected_email != null:
		controller.open_content(selected_email, "link")

func _on_attachment_pressed() -> void:
	if is_instance_valid(controller) and selected_email != null:
		controller.open_content(selected_email, "attachment")
