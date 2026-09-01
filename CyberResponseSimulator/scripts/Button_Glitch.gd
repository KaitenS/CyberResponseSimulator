extends Button


# =====================================================
# CONFIGURACIÓN
# =====================================================

# Opacidad normal
@export_range(0.0, 1.0) var normal_alpha: float = 1.0

# Opacidad al hacer hover
@export_range(0.0, 1.0) var hover_alpha: float = 0.82

# Opacidad durante click
@export_range(0.0, 1.0) var click_alpha: float = 0.65

# Duración de la transición del hover
@export var hover_duration: float = 0.12

# Duración del efecto de click
@export var click_duration: float = 0.16


var hovering: bool = false
var clicking: bool = false


func _ready() -> void:

	# Estado inicial
	modulate.a = normal_alpha

	# Eventos
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)


# =====================================================
# MOUSE ENTER
# =====================================================

func _on_mouse_entered() -> void:

	hovering = true

	var tween: Tween = create_tween()

	tween.set_trans(
		Tween.TRANS_SINE
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		self,
		"modulate:a",
		hover_alpha,
		hover_duration
	)


	# Pequeño glitch visual
	await tiny_glitch()


# =====================================================
# MOUSE EXIT
# =====================================================

func _on_mouse_exited() -> void:

	hovering = false

	var tween: Tween = create_tween()

	tween.set_trans(
		Tween.TRANS_SINE
	)

	tween.set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		self,
		"modulate:a",
		normal_alpha,
		hover_duration
	)


# =====================================================
# CLICK
# =====================================================

func _on_pressed() -> void:

	if clicking:
		return

	clicking = true


	# -----------------------------------------------
	# BAJAR OPACIDAD
	# -----------------------------------------------

	var tween_down: Tween = create_tween()

	tween_down.set_trans(
		Tween.TRANS_SINE
	)

	tween_down.set_ease(
		Tween.EASE_OUT
	)

	tween_down.tween_property(
		self,
		"modulate:a",
		click_alpha,
		0.05
	)

	await tween_down.finished


	# -----------------------------------------------
	# PEQUEÑO FLASH
	# -----------------------------------------------

	modulate = Color(
		1.15,
		1.05,
		1.2,
		click_alpha
	)

	await get_tree().create_timer(
		0.035
	).timeout


	# -----------------------------------------------
	# VOLVER
	# -----------------------------------------------

	var target_alpha: float = normal_alpha

	if hovering:
		target_alpha = hover_alpha


	var tween_up: Tween = create_tween()

	tween_up.set_trans(
		Tween.TRANS_SINE
	)

	tween_up.set_ease(
		Tween.EASE_OUT
	)

	tween_up.tween_property(
		self,
		"modulate",
		Color(
			1.0,
			1.0,
			1.0,
			target_alpha
		),
		click_duration
	)

	await tween_up.finished


	clicking = false


# =====================================================
# GLITCH MUY PEQUEÑO
# =====================================================

func tiny_glitch() -> void:

	# No queremos que el glitch sea exagerado

	await get_tree().create_timer(
		0.03
	).timeout


	if not hovering:
		return


	# Pequeño cambio de brillo

	modulate = Color(
		1.08,
		1.02,
		1.12,
		hover_alpha
	)


	await get_tree().create_timer(
		0.035
	).timeout


	if not hovering:
		return


	# Volver al estado normal del hover

	modulate = Color(
		1.0,
		1.0,
		1.0,
		hover_alpha
	)
