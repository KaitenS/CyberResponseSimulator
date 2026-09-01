extends Control

@onready var mascot: TextureRect = $Mascot

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:

	rng.randomize()

	# Comenzar invisible
	mascot.modulate.a = 0.0

	# Comenzar el ciclo
	start_mascot_loop()


# =====================================================
# CICLO PRINCIPAL
# =====================================================

func start_mascot_loop() -> void:

	while true:

		# Esperar entre 4 y 9 segundos antes de aparecer
		var wait_time: float = rng.randf_range(4.0, 9.0)

		await get_tree().create_timer(wait_time).timeout

		await show_mascot()

		await glitch_mascot()

		await hide_mascot()


# =====================================================
# APARECER Y FLOTAR
# =====================================================

func show_mascot() -> void:

	var viewport_size: Vector2 = get_viewport_rect().size
	var margin: float = 120.0


	# =================================================
	# POSICIÓN INICIAL ALEATORIA
	# =================================================

	var x: float = rng.randf_range(
		margin,
		max(
			margin,
			viewport_size.x - margin - mascot.size.x
		)
	)

	var y: float = rng.randf_range(
		margin,
		max(
			margin,
			viewport_size.y - margin - mascot.size.y
		)
	)

	var start_position: Vector2 = Vector2(x, y)

	mascot.position = start_position


	# =================================================
	# DIRECCIÓN ALEATORIA
	# =================================================

	var direction: Vector2 = Vector2(
		rng.randf_range(-1.0, 1.0),
		rng.randf_range(-1.0, 1.0)
	)

	# Evitar una dirección demasiado pequeña
	if direction.length() < 0.1:
		direction = Vector2(1.0, 0.0)

	direction = direction.normalized()


	# =================================================
	# ROTACIÓN HACIA LA DIRECCIÓN
	# =================================================

	var target_angle: float = atan2(
		direction.y,
		direction.x
	)

	# La mascota apunta hacia donde se mueve
	mascot.rotation = target_angle


	# =================================================
	# ESCALA ALEATORIA
	# =================================================

	var random_scale: float = rng.randf_range(
		0.80,
		1.15
	)

	mascot.scale = Vector2(
		random_scale,
		random_scale
	)


	# =================================================
	# DISTANCIA DE MOVIMIENTO
	# =================================================

	var distance: float = rng.randf_range(
		80.0,
		180.0
	)

	var end_position: Vector2 = (
		start_position +
		direction * distance
	)


	# =================================================
	# APARICIÓN
	# =================================================

	mascot.modulate.a = 0.0

	# Comienza ligeramente desplazada
	mascot.position.y += 10.0


	var fade_tween: Tween = create_tween()

	fade_tween.set_parallel(true)


	# Fade in
	fade_tween.tween_property(
		mascot,
		"modulate:a",
		0.75,
		0.6
	)


	# Pequeño movimiento inicial
	fade_tween.tween_property(
		mascot,
		"position",
		start_position,
		0.6
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)


	await fade_tween.finished


	# =================================================
	# FLOTACIÓN
	# =================================================

	var float_duration: float = rng.randf_range(
		3.0,
		5.0
	)


	var float_tween: Tween = create_tween()

	float_tween.set_trans(
		Tween.TRANS_SINE
	)

	float_tween.set_ease(
		Tween.EASE_IN_OUT
	)

	float_tween.tween_property(
		mascot,
		"position",
		end_position,
		float_duration
	)


	await float_tween.finished


# =====================================================
# GLITCH
# =====================================================

func glitch_mascot() -> void:

	# Permanecer visible un momento
	await get_tree().create_timer(
		rng.randf_range(1.2, 2.5)
	).timeout


	# =================================================
	# PEQUEÑOS DESPLAZAMIENTOS
	# =================================================

	for i in range(4):

		var offset: float = rng.randf_range(
			-12.0,
			12.0
		)

		mascot.position.x += offset

		await get_tree().create_timer(
			0.035
		).timeout

		mascot.position.x -= offset

		await get_tree().create_timer(
			0.035
		).timeout


	# =================================================
	# PARPADEO / GLITCH
	# =================================================

	mascot.modulate.a = 0.15

	await get_tree().create_timer(
		0.04
	).timeout

	mascot.modulate.a = 0.8

	await get_tree().create_timer(
		0.04
	).timeout

	mascot.modulate.a = 0.25

	await get_tree().create_timer(
		0.04
	).timeout

	mascot.modulate.a = 0.75


# =====================================================
# DESAPARECER
# =====================================================

func hide_mascot() -> void:

	var tween: Tween = create_tween()

	tween.tween_property(
		mascot,
		"modulate:a",
		0.0,
		0.25
	)

	await tween.finished
