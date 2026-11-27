extends CanvasLayer
## Una hoja de resumen y una por ejecución de incidente, con decisiones auditables.
@export_enum("F-", "Intermedio", "S+") var preview_grade: int = 0
const KIND_NAMES := {"phishing": "Phishing", "malware": "Malware", "ddos": "DDoS"}
var _reports: Array[Dictionary] = []
var _pages: Array[Dictionary] = []
var _page: int = 0
var _played_seconds: float = 0.0
var _page_tween: Tween
@onready var notebook: Control = $PageRoot/Notebook
@onready var art: Control = $PageRoot/Notebook/Art
@onready var summary_page: Control = $PageRoot/Notebook/Summary
@onready var details_page: Control = $PageRoot/Notebook/Details
@onready var incident_selector: OptionButton = $PageRoot/Notebook/Details/IncidentSelector
@onready var stamp: Panel = $PageRoot/Notebook/GradeStamp

func _ready() -> void:
	visible = false
	incident_selector.item_selected.connect(_select_incident)
	GameManager.game_ended.connect(show_results)
	$PageRoot/Notebook/Previous.pressed.connect(_turn_page.bind(-1))
	$PageRoot/Notebook/Next.pressed.connect(_turn_page.bind(1))
	$PageRoot/Notebook/Menu.pressed.connect(_return_to_menu)
	$PageRoot/Notebook/Restart.pressed.connect(_restart)
	for pair in [["SummaryTab", "summary"], ["PhishingTab", "phishing"], ["MalwareTab", "malware"], ["DDoSTab", "ddos"]]:
		notebook.get_node("Tabs/" + pair[0]).pressed.connect(_jump_to_kind.bind(pair[1]))
	get_viewport().size_changed.connect(_fit_notebook)
	_fit_notebook()
	if get_tree().current_scene == self:
		build_from_reports(_preview_reports(), 600.0)
		$PageRoot/Notebook/Subtitle.text = "Demostración visual (F6) · No corresponde a una partida real"
		visible = true

func _fit_notebook() -> void:
	var available := get_viewport().get_visible_rect().size
	var factor := minf(1.1, minf((available.x - 48.0) / 1060.0, (available.y - 48.0) / 620.0))
	factor = maxf(0.1, factor)
	notebook.scale = Vector2.ONE * factor
	notebook.position = (available - Vector2(1060, 620) * factor) * 0.5

func build_from_reports(reports: Array[Dictionary], played_seconds: float) -> void:
	_reports = reports.duplicate(true)
	_played_seconds = played_seconds
	_pages.clear()
	_pages.append({"kind": "summary"})
	for kind in ["phishing", "malware", "ddos"]:
		var found := false
		var number := 0
		for report in _reports:
			if report.get("kind", "") == kind:
				found = true
				number += 1
				_pages.append({"kind": kind, "number": number, "report": report})
		if not found:
			_pages.append({"kind": kind})
	_refresh_summary()
	_set_page(0)

# Compatibilidad con llamadas anteriores: los contadores ya no deciden la nota.
func build(_completed: int, _failed: int, _active: int, played_seconds: float) -> void:
	build_from_reports(GameManager.get_session_reports(), played_seconds)

func _refresh_summary() -> void:
	var stats := GameManager.summarize_reports(_reports)
	var ratio: float = stats.ratio
	var graded: bool = stats.possible > 0
	var grade := GameManager.grade_for_ratio(ratio) if graded else "—"
	summary_page.get_node("ScoreValue").text = "%d / %d puntos" % [stats.points, stats.possible]
	summary_page.get_node("DecisionStats").text = "Aciertos: %d · Errores: %d · Pendientes: %d" % [stats.correct, stats.incorrect, stats.pending]
	summary_page.get_node("IncidentStats").text = "%d incidentes registrados\n%d finalizados · %d en curso al cierre\n%d sin fallos · %d finalizados con errores" % [stats.total, stats.finished, stats.active, stats.perfect, stats.failed]
	var module_lines := PackedStringArray()
	for kind in ["phishing", "malware", "ddos"]:
		var selected: Array[Dictionary] = []
		for report in _reports:
			if report.get("kind", "") == kind:
				selected.append(report)
		var module := GameManager.summarize_reports(selected)
		module_lines.append("%s: %d/%d puntos · %d incidente(s)" % [KIND_NAMES[kind], module.points, module.possible, module.total] if not selected.is_empty() else KIND_NAMES[kind] + ": sin incidentes")
	summary_page.get_node("Modules").text = "\n".join(module_lines)
	stamp.get_node("Grade").text = grade
	stamp.get_node("Accuracy").text = "%.1f %%" % (ratio * 100.0) if graded else "Sin evaluar"
	stamp.get_node("Grade").add_theme_color_override("font_color", Color("2f6249") if ratio >= 0.7 and graded else Color("aa3029") if graded else Color("66665b"))
	art.damage = 1.0 - ratio if graded else 0.2
	$PageRoot/Notebook/Subtitle.text = "Registro de decisiones · Jornada de %02d:%02d · Nota según aciertos" % [floori(_played_seconds / 60.0), int(_played_seconds) % 60]

func _set_page(index: int) -> void:
	_page = clampi(index, 0, maxi(0, _pages.size() - 1))
	var page := _pages[_page]
	var is_summary: bool = page.kind == "summary"
	summary_page.visible = is_summary
	stamp.visible = is_summary
	details_page.visible = not is_summary
	_refresh_incident_selector(page.kind)
	if not is_summary:
		_render_report(page)
	$PageRoot/Notebook/Previous.disabled = _page == 0
	$PageRoot/Notebook/Next.disabled = _page == _pages.size() - 1
	$PageRoot/Notebook/PageNumber.text = "HOJA %02d / %02d" % [_page + 1, _pages.size()]
	for pair in [["SummaryTab", "summary"], ["PhishingTab", "phishing"], ["MalwareTab", "malware"], ["DDoSTab", "ddos"]]:
		notebook.get_node("Tabs/" + pair[0]).set_pressed_no_signal(page.kind == pair[1])
	var content := summary_page if is_summary else details_page
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	content.modulate.a = 0.3
	_page_tween = create_tween()
	_page_tween.tween_property(content, "modulate:a", 1.0, 0.12)

func _render_report(page: Dictionary) -> void:
	var text: RichTextLabel = details_page.get_node("Decisions")
	if not page.has("report"):
		details_page.get_node("Heading").text = KIND_NAMES[page.kind]
		details_page.get_node("Status").text = "No se registraron incidentes de este tipo en esta jornada."
		text.text = "Esta sección solo muestra situaciones que ocurrieron en la partida."
		return
	var report: Dictionary = page.report
	var selected: Array[Dictionary] = [report]
	var stats := GameManager.summarize_reports(selected)
	var total := 0
	for entry in _pages:
		if entry.kind == page.kind and entry.has("report"):
			total += 1
	details_page.get_node("Heading").text = "%s · Incidente %d de %d" % [KIND_NAMES[page.kind], page.number, total]
	details_page.get_node("Status").text = "%s · %d/%d puntos\n%d aciertos · %d errores · %d pendientes" % [report.get("status", ""), stats.points, stats.possible, stats.correct, stats.incorrect, stats.pending]
	var blocks := PackedStringArray()
	for decision in report.get("decisions", []):
		var informational: bool = not decision.get("scored", true)
		var pending: bool = decision.get("correct") == null
		var ok: bool = decision.get("correct") == true
		var state := "INFORMACIÓN · Sin puntaje" if informational else "PENDIENTE · 0/100" if pending else "ACIERTO · +100" if ok else "ERROR · 0/100"
		var color := "555b57" if informational or pending else "286046" if ok else "9d3029"
		blocks.append("[color=#%s][b]%s[/b][/color]\n[b]%s[/b]\nTu decisión: %s\nEsperado: %s\n%s" % [color, state,
			_safe(decision.get("title", decision.get("subject", "Decisión"))), _safe(decision.get("action", "Sin responder")),
			_safe(decision.get("expected", "")), _safe(decision.get("explanation", ""))])
	if int(report.get("not_received", 0)) > 0:
		blocks.append("[b]%d correos no habían llegado.[/b] No se cuentan como errores ni forman parte del puntaje posible." % report.not_received)
	if blocks.is_empty():
		blocks.append("No hubo decisiones registradas para este incidente.")
	text.text = "\n\n".join(blocks)
	text.scroll_to_line(0)

func _refresh_incident_selector(kind: String) -> void:
	incident_selector.clear()
	var indices: Array[int] = []
	for i in range(_pages.size()):
		if _pages[i].kind == kind and _pages[i].has("report"):
			indices.append(i)
	for i in range(indices.size()):
		incident_selector.add_item("Incidente %d de %d" % [i + 1, indices.size()], indices[i])
		if indices[i] == _page:
			incident_selector.select(i)
	incident_selector.visible = indices.size() > 1

func _select_incident(index: int) -> void:
	if index >= 0 and index < incident_selector.item_count:
		_set_page(incident_selector.get_item_id(index))

func _safe(value: Variant) -> String:
	return str(value).replace("[", "[lb]")

func _turn_page(direction: int) -> void:
	_set_page(_page + direction)

func _jump_to_kind(kind: String) -> void:
	for i in _pages.size():
		if _pages[i].kind == kind:
			_set_page(i)
			return

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_LEFT:
		_turn_page(-1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_RIGHT:
		_turn_page(1)
		get_viewport().set_input_as_handled()

func show_results() -> void:
	build_from_reports(GameManager.get_session_reports(), GameManager.GAME_DURATION - GameManager.time_remaining)
	visible = true
	_fit_notebook()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_results() -> void:
	visible = false
	get_tree().paused = false

func _restart() -> void:
	close_results()
	GameManager.start_game()
	get_tree().change_scene_to_file("res://scenes/Game/Game.tscn")

func _return_to_menu() -> void:
	GameManager.game_active = false
	IncidentManager.active_incidents.clear()
	close_results()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/Menu/MainMenu.tscn")

func _preview_reports() -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for kind in ["phishing", "malware", "ddos"]:
		var entries: Array[Dictionary] = []
		for i in 3:
			var ok := preview_grade == 2 or (preview_grade == 1 and i < 2)
			entries.append({"id": str(i), "title": {"phishing": "Correo de ejemplo", "malware": "Elemento investigado", "ddos": "Flujo de red"}[kind] + " %d" % (i + 1),
				"correct": ok, "action": "Acción de ejemplo", "expected": "Respuesta indicada por las pistas", "explanation": "Datos de demostración para revisar el diseño desde F6."})
		reports.append({"report_id": "preview:" + kind, "kind": kind, "incident_name": KIND_NAMES[kind], "finished": true,
			"success": preview_grade == 2, "status": "Ejemplo visual", "decisions": entries})
	return reports
