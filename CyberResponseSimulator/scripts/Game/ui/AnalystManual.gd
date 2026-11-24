extends CanvasLayer

var _is_open := false
var _was_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _hidden_cursors: Array[Dictionary] = []
var _chapter := 0
var _pages: Array[Control] = []

func _ready() -> void:
	_pages = [$Overlay/Center/Book/ChapterScroll/Pages/PhishingPage, $Overlay/Center/Book/ChapterScroll/Pages/MalwarePage, $Overlay/Center/Book/ChapterScroll/Pages/DDoSPage]
	$ManualButton.pressed.connect(open_manual)
	$Overlay/Center/Book/CloseButton.pressed.connect(close_manual)
	$Overlay/Center/Book/PreviousButton.pressed.connect(_previous)
	$Overlay/Center/Book/NextButton.pressed.connect(_next)
	var buttons := $Overlay/Center/Book/Index/Chapters.get_children()
	for i in range(buttons.size()):
		buttons[i].pressed.connect(_show_chapter.bind(i))
	$Overlay.hide()
	_show_chapter(0)
	if get_tree().current_scene == self:
		open_manual()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("analyst_manual") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if _is_open:
			close_manual()
		else:
			open_manual()
	elif _is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_manual()


func open_manual() -> void:
	if _is_open:
		return
	_is_open = true
	_was_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	_hidden_cursors.clear()
	for computer in get_tree().get_nodes_in_group("computers"):
		var cursor = computer.get("custom_cursor")
		if is_instance_valid(cursor):
			_hidden_cursors.append({"node": weakref(cursor), "visible": cursor.visible})
			cursor.hide()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Overlay.show()
	$ManualButton.hide()


func close_manual() -> void:
	if not _is_open:
		return
	_is_open = false
	$Overlay.hide()
	$ManualButton.show()
	for saved in _hidden_cursors:
		var cursor = saved["node"].get_ref()
		if is_instance_valid(cursor):
			cursor.visible = saved["visible"]
	_hidden_cursors.clear()
	get_tree().paused = _was_paused
	Input.mouse_mode = _previous_mouse_mode


func _show_chapter(index: int) -> void:
	_chapter = clampi(index, 0, _pages.size() - 1)
	for i in range(_pages.size()):
		_pages[i].visible = i == _chapter
		var button := $Overlay/Center/Book/Index/Chapters.get_child(i) as Button
		button.set_pressed_no_signal(i == _chapter)
	$Overlay/Center/Book/ChapterScroll.scroll_vertical = 0
	$Overlay/Center/Book/PageNumber.text = "%d / %d" % [_chapter + 1, _pages.size()]
	$Overlay/Center/Book/PreviousButton.disabled = _chapter == 0
	$Overlay/Center/Book/NextButton.disabled = _chapter == _pages.size() - 1


func _previous() -> void:
	_show_chapter(_chapter - 1)


func _next() -> void:
	_show_chapter(_chapter + 1)
