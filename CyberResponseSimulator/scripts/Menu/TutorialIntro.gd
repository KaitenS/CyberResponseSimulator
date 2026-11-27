extends Control
## Los textos y las imágenes se editan en los nodos de TutorialIntro.tscn.

const GAME_SCENE := "res://scenes/Game/Game.tscn"
const DESIGN_SIZE := Vector2(1280, 720)
var page_index := 0
var _starting := false
@onready var pages: Array[Node] = $Design/Panel/Pages.get_children()
@onready var next_button: Button = $Design/Panel/NextButton
@onready var back_button: Button = $Design/Panel/BackButton

func _ready() -> void:
	# El tiempo de la jornada comienza únicamente al salir del tutorial.
	GameManager.game_active = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	back_button.pressed.connect(_previous_page)
	next_button.pressed.connect(_next_page)
	$Design/Panel/SkipButton.pressed.connect(_start_day)
	get_viewport().size_changed.connect(_fit_layout)
	_fit_layout()
	_show_page(0)
	next_button.grab_focus()

func _fit_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var fit := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	$Design.scale = Vector2.ONE * fit
	$Design.position = (viewport_size - DESIGN_SIZE * fit) * 0.5

func _show_page(index: int) -> void:
	page_index = clampi(index, 0, pages.size() - 1)
	for i in range(pages.size()):
		pages[i].visible = i == page_index
	back_button.disabled = page_index == 0
	next_button.text = "Entrar a la oficina" if page_index == pages.size() - 1 else "Siguiente >"
	$Design/Panel/PageNumber.text = "%02d / %02d" % [page_index + 1, pages.size()]
	$Design/Panel/Progress.value = 100.0 * float(page_index + 1) / pages.size()
	if back_button.disabled and back_button.has_focus():
		next_button.grab_focus()

func _previous_page() -> void:
	_show_page(page_index - 1)

func _next_page() -> void:
	if page_index == pages.size() - 1:
		_start_day()
	else:
		_show_page(page_index + 1)

func _start_day() -> void:
	if _starting:
		return
	_starting = true
	next_button.disabled = true
	$Design/Panel/SkipButton.disabled = true
	GameManager.start_game()
	var error := get_tree().change_scene_to_file(GAME_SCENE)
	if error != OK:
		GameManager.game_active = false
		_starting = false
		next_button.disabled = false
		$Design/Panel/SkipButton.disabled = false
		$Design/Panel/Safety.text = "No se pudo abrir la oficina. Vuelve a intentarlo."
		push_error("Tutorial: no se pudo abrir Game.tscn (%s)." % error)
