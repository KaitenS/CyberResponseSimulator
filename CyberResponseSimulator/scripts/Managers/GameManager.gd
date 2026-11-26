extends Node

var game_active: bool = false
var score: int = 0
var phishing_results: Array[Dictionary] = []
var incidents_completed: int = 0
var incidents_failed: int = 0
var time_remaining: float = GAME_DURATION
var session_id: int = 0
var _incident_reports: Dictionary = {}
var _final_reports: Array[Dictionary] = []
const POINTS_PER_CORRECT: int = 100

const GAME_DURATION: float = 420.0

signal game_ended

func start_game():
	if IncidenteDDoS.activo:
		IncidenteDDoS.abortar()
	IncidentManager.active_incidents.clear()
	game_active = true
	score = 0
	phishing_results.clear()
	_incident_reports.clear()
	_final_reports.clear()
	session_id += 1
	incidents_completed = 0
	incidents_failed = 0
	time_remaining = GAME_DURATION


func _process(delta: float) -> void:
	if not game_active:
		return

	time_remaining -= delta

	if time_remaining <= 0.0:
		time_remaining = 0.0
		end_game()


func end_game():
	if not game_active:
		return
	_collect_live_reports()
	_final_reports = get_session_reports()
	game_active = false
	game_ended.emit()


# Actualiza un informe existente en lugar de sumar otra vez al cerrar o consultar.
func record_incident_report(report: Dictionary) -> void:
	if not game_active and not _final_reports.is_empty():
		return
	if report.is_empty() or str(report.get("report_id", "")).is_empty() or int(report.get("session_id", session_id)) != session_id:
		return
	_incident_reports[str(report.report_id)] = report.duplicate(true)
	score = 0
	for item in _incident_reports.values():
		for decision in item.get("decisions", []):
			if decision.get("scored", true) and decision.get("correct") == true:
				score += POINTS_PER_CORRECT

func _collect_live_reports() -> void:
	for controller in get_tree().get_nodes_in_group("phishing_controllers"):
		if controller.phishing_data != null:
			record_incident_report(controller.get_result())
	for controller in get_tree().get_nodes_in_group("malware_controllers"):
		record_incident_report(controller.get_day_report())
	if IncidenteDDoS.has_method("get_day_report"):
		record_incident_report(IncidenteDDoS.get_day_report())

func get_session_reports() -> Array[Dictionary]:
	if not game_active and not _final_reports.is_empty():
		return _final_reports.duplicate(true)
	_collect_live_reports()
	var reports: Array[Dictionary] = []
	for item in _incident_reports.values():
		reports.append(item.duplicate(true))
	return reports

func summarize_reports(reports: Array[Dictionary]) -> Dictionary:
	var summary := {"points": 0, "possible": 0, "correct": 0, "incorrect": 0, "pending": 0,
		"total": reports.size(), "finished": 0, "active": 0, "perfect": 0, "failed": 0, "not_received": 0}
	for report in reports:
		if report.get("finished", false):
			summary.finished += 1
		else:
			summary.active += 1
		summary.not_received += int(report.get("not_received", 0))
		var flawless: bool = report.get("success", false)
		for decision in report.get("decisions", []):
			if not decision.get("scored", true):
				continue
			summary.possible += POINTS_PER_CORRECT
			if decision.get("correct") != true:
				flawless = false
			if decision.get("correct") == null:
				summary.pending += 1
			elif decision.correct:
				summary.correct += 1
				summary.points += POINTS_PER_CORRECT
			else:
				summary.incorrect += 1
		if report.get("finished", false):
			if flawless:
				summary.perfect += 1
			else:
				summary.failed += 1
	summary["ratio"] = float(summary.points) / summary.possible if summary.possible > 0 else 0.0
	return summary

func grade_for_ratio(ratio: float) -> String:
	var names := ["S+", "S", "A+", "A", "A-", "B+", "B", "B-", "C+", "C", "C-", "D+", "D", "D-", "F+", "F", "F-"]
	var thresholds := [0.98, 0.95, 0.90, 0.85, 0.80, 0.75, 0.70, 0.65, 0.60, 0.55, 0.50, 0.45, 0.40, 0.35, 0.25, 0.10, 0.0]
	for i in thresholds.size():
		if ratio >= thresholds[i]:
			return names[i]
	return "F-"
