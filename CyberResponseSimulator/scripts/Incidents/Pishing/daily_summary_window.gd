extends TextureRect

var controller: PishingIncidentController = null

func _ready() -> void:
	$TitleBar/HBoxContainer/CloseButton.pressed.connect(hide)
	visibility_changed.connect(_mark_if_visible)


func set_controller(value: PishingIncidentController) -> void:
	if is_instance_valid(controller):
		controller.incident_started.disconnect(_show_data)
	controller = value
	if is_instance_valid(controller):
		controller.incident_started.connect(_show_data)
	_show_data(controller.phishing_data if is_instance_valid(controller) else null)


func _show_data(data: PhishingData) -> void:
	var clues := PackedStringArray()
	if data != null and data.daily_summary != null:
		$Heading.text = data.daily_summary.title
		var parts := data.daily_summary.content.split("•")
		for i in range(1, parts.size()):
			clues.append(parts[i].strip_edges())
	else:
		$Heading.text = "Sin novedades por ahora"
		clues.append("Cuando se asigne un incidente, aquí aparecerá el contexto de la jornada.")
	var cards := $SummaryScroll/Cards.get_children()
	for i in range(cards.size()):
		cards[i].visible = i < clues.size()
		if i < clues.size():
			cards[i].get_node("Content/Text").text = clues[i]
	$SummaryScroll.scroll_vertical = 0
	_mark_if_visible()

func _mark_if_visible() -> void:
	if is_visible_in_tree() and is_instance_valid(controller):
		controller.mark_summary_read()
