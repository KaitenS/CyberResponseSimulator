extends Control
## Papel y encuadernación editables; el daño nunca cubre la tinta de los resultados.
@export_range(0.0, 1.0, 0.01) var damage: float = 1.0:
	set(value):
		damage = clampf(value, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(9, 14, w, h), Color(0.0, 0.0, 0.0, 0.28))
	draw_rect(Rect2(4, 6, w - 5, h - 4), Color("bfb49a"))
	var edge := PackedVector2Array([Vector2(18, 18)])
	for i in range(1, 29):
		var x := 18.0 + float(i) * (w - 36.0) / 29.0
		edge.append(Vector2(x, 18.0 + damage * absf(sin(i * 3.17)) * 9.0))
	edge.append(Vector2(w - 18, 18))
	for i in range(1, 20):
		var y := 18.0 + float(i) * (h - 36.0) / 20.0
		edge.append(Vector2(w - 18.0 - damage * absf(sin(i * 4.21)) * 16.0, y))
	edge.append(Vector2(w - 18, h - 18))
	for i in range(1, 29):
		var x := w - 18.0 - float(i) * (w - 36.0) / 29.0
		edge.append(Vector2(x, h - 18.0 - damage * absf(sin(i * 2.71)) * 13.0))
	edge.append(Vector2(18, h - 18))
	for i in range(1, 20):
		var y := h - 18.0 - float(i) * (h - 36.0) / 20.0
		edge.append(Vector2(18.0 + damage * absf(sin(i * 3.37)) * 9.0, y))
	draw_colored_polygon(edge, Color("f5efd9").lerp(Color("e9dec2"), damage * 0.5))
	# Renglones tenues, margen rojo y lomo gastado.
	for y in range(176, int(h) - 62, 28):
		draw_line(Vector2(78, y), Vector2(w - 42, y), Color(0.35, 0.48, 0.55, 0.12), 1.0)
	draw_line(Vector2(78, 18), Vector2(78, h - 18), Color(0.65, 0.18, 0.17, 0.35), 1.5)
	draw_rect(Rect2(14, 14, 45, h - 30), Color(0.32, 0.24, 0.16, 0.12 + damage * 0.08))
	for i in 9:
		var y := 47.0 + i * 65.0
		draw_circle(Vector2(51, y), 6.0 + damage * 2.0, Color("706653"))
		var broken := damage > 0.7 and i in [2, 6]
		draw_arc(Vector2(36, y), 17.0, 0.1, 4.4 if broken else 5.8, 24, Color("434640"), 4.0, true)
		draw_arc(Vector2(35, y - 1), 17.0, 0.2, 4.2 if broken else 5.6, 24, Color("b4b6ac"), 1.5, true)
	# Pliegues, esquina doblada y desgarros concentrados en los bordes.
	draw_line(Vector2(w * 0.61, 18), Vector2(w * 0.57, h - 15), Color(0.27, 0.2, 0.12, damage * 0.12), 2.0)
	draw_line(Vector2(w * 0.61 + 3, 18), Vector2(w * 0.57 + 3, h - 15), Color(1, 1, 1, damage * 0.4), 2.0)
	var fold := 14.0 + damage * 54.0
	draw_colored_polygon(PackedVector2Array([Vector2(w - fold - 7, 10), Vector2(w - 15, fold), Vector2(w - fold - 7, fold)]), Color("c6b791"))
	if damage > 0.6:
		for y in [170.0, 435.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(w - 5, y), Vector2(w - 41 * damage, y + 13), Vector2(w - 8, y + 25)]), Color("94826a"))
	# Marca de taza muy ligera: conserva el contraste del texto.
	draw_set_transform(Vector2(w - 80, h - 112), 0.15, Vector2(1.0, 0.65))
	draw_arc(Vector2.ZERO, 34.0, 0.1, 5.9, 64, Color(0.33, 0.18, 0.06, damage * 0.12), 4.0, true)
	draw_set_transform(Vector2.ZERO)
