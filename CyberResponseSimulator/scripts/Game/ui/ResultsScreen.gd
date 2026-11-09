# ResultsScreen.gd
# Pantalla "Resultados del día": calcula los datos de la partida y la nota.
extends CanvasLayer

# 17 notas, de la más baja a la más alta.
const GRADES: Array[String] = [
	"F-", "F", "F+", "D-", "D", "D+", "C-", "C", "C+",
	"B-", "B", "B+", "A-", "A", "A+", "S", "S+",
]

@onready var total_label: Label = $Center/Notebook/Stats/TotalLabel
@onready var duration_label: Label = $Center/Notebook/Stats/DurationLabel
@onready var resolved_label: Label = $Center/Notebook/Stats/ResolvedLabel
@onready var unresolved_label: Label = $Center/Notebook/Stats/UnresolvedLabel
@onready var grade_label: Label = $Center/Notebook/GradeLabel
@onready var dirt: ColorRect = $Center/Notebook/Dirt

func build(completed: int, failed: int, active: int, played_seconds: float) -> void:
	# Un incidente que sigue activo al terminar el tiempo cuenta como sin resolver.
	var unresolved := failed + active
	var total := completed + unresolved

	total_label.text = "Incidentes totales: %d" % total
	resolved_label.text = "Incidentes resueltos: %d" % completed
	unresolved_label.text = "Incidentes sin resolver: %d" % unresolved
	duration_label.text = "Duración de la partida: %02d:%02d" % [
		floori(played_seconds / 60.0),
		int(played_seconds) % 60,
	]

	# La nota depende del porcentaje de incidentes resueltos.
	var ratio := 0.0
	if total > 0:
		ratio = float(completed) / float(total)
	var grade_index := clampi(int(ratio * GRADES.size()), 0, GRADES.size() - 1)
	grade_label.text = GRADES[grade_index]

	# Mejor nota = libreta más limpia (0). Peor nota = más sucia (1).
	var dirtiness := 1.0 - float(grade_index) / float(GRADES.size() - 1)
	(dirt.material as ShaderMaterial).set_shader_parameter("dirtiness", dirtiness)
	
func _ready() -> void:
	visible = false
	GameManager.game_ended.connect(show_results)

	# Si corres esta escena sola (F6), muestra datos de ejemplo para revisar el diseño.
	if get_tree().current_scene == self:
		build(3, 1, 0, 60.0)
		visible = true
		
func show_results() -> void:
	build(
		GameManager.incidents_completed,
		GameManager.incidents_failed,
		IncidentManager.active_incidents.size(),
		GameManager.GAME_DURATION - GameManager.time_remaining,
	)
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
# Para que quien muestre la pantalla siguiente (o reinicie la partida) pueda cerrar esta.
func close_results() -> void:
	visible = false
	get_tree().paused = false
