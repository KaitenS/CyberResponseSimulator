extends Control

var controller: PishingIncidentController = null


func set_controller(value: PishingIncidentController) -> void:
	if is_instance_valid(controller):
		controller.incident_started.disconnect(_started)
		controller.summary_read_changed.disconnect(_refresh)
	controller = value
	if is_instance_valid(controller):
		controller.incident_started.connect(_started)
		controller.summary_read_changed.connect(_refresh)
	_refresh()


func _started(_data: PhishingData) -> void:
	_refresh()


func _refresh() -> void:
	var has_summary := is_instance_valid(controller) and controller.phishing_data != null and controller.phishing_data.daily_summary != null
	$UnreadBadge.visible = has_summary and not controller.summary_read
