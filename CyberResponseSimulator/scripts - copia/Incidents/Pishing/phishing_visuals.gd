extends RefCounted

const INK := Color("#20334e")
const MUTED := Color("#64748b")
const BLUE := Color("#355caa")

static func box(color: Color, border: Color = Color("#d6dfed")) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(1)
	result.set_corner_radius_all(5)
	result.content_margin_left = 12
	result.content_margin_right = 12
	result.content_margin_top = 8
	result.content_margin_bottom = 8
	return result

static func label(text: String, size: int, color: Color = INK) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func button(node: Button, color: Color) -> void:
	node.custom_minimum_size.y = 32
	node.add_theme_font_size_override("font_size", 15)
	node.add_theme_color_override("font_color", Color.WHITE)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color.WHITE)
	node.add_theme_color_override("font_disabled_color", Color("#8a96a8"))
	node.add_theme_stylebox_override("normal", box(color, color.darkened(0.15)))
	node.add_theme_stylebox_override("hover", box(color.lightened(0.12)))
	node.add_theme_stylebox_override("pressed", box(color.darkened(0.15)))
	node.add_theme_stylebox_override("disabled", box(Color("#e3e8ef")))
	node.add_theme_stylebox_override("focus", box(Color(color, 0.15), BLUE))

static func background(window: Control) -> void:
	var bg := Panel.new()
	bg.position = Vector2(5, 42)
	bg.size = Vector2(590, 353)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", box(Color("#edf2f8")))
	window.add_child(bg)
	window.move_child(bg, 0)