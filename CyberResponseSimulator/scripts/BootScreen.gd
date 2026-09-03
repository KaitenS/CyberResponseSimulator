extends Control

@onready var boot_text: RichTextLabel = $Background/BootText
@onready var glitch_overlay: ColorRect = $GlitchOverlay
@onready var glitch_material: ShaderMaterial = glitch_overlay.material

@onready var logo1: TextureRect = $GodotLogo
@onready var logo2: TextureRect = $DuocUcLogo
@onready var logo3: TextureRect = $CybugLogo


var boot_lines = [
	"> CYBER RESPONSE SYSTEM",
	"> INITIALIZING...",
	"> MEMORY CHECK ............ [ OK ]",
	"> CPU CHECK ............... [ OK ]",
	"> NETWORK INTERFACE ....... [ OK ]",
	"> SECURITY MODULE ......... [ OK ]",
	"> FIREWALL ................ [ ACTIVE ]",
	"> THREAT DATABASE ......... [ LOADED ]",
	"> SYSTEM STATUS: ONLINE",
	"> NETWORK: SECURE",
	"> THREAT LEVEL: LOW",
	"> ACCESS GRANTED"
]


var displayed_text := ""


func _ready():
	
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	# Limpiar BootText
	boot_text.text = ""

	# Ocultar logos
	logo1.modulate.a = 0.0
	logo2.modulate.a = 0.0
	logo3.modulate.a = 0.0

	# Glitch apagado
	glitch_material.set_shader_parameter(
		"glitch_amount",
		1
	)

	# Pequeña espera inicial
	await get_tree().create_timer(0.7).timeout

	# Comenzar boot
	await type_boot_sequence()


func type_boot_sequence():

	for line in boot_lines:

		await type_line(line)

		# Pausa entre líneas
		await get_tree().create_timer(0.05).timeout

	# Esperar después de ACCESS GRANTED
	await get_tree().create_timer(0.5).timeout

	# Comenzar secuencia de logos
	await logo_sequence()


func type_line(line: String):

	var current_text := ""

	for character in line:

		current_text += character

		# Texto anterior + texto actual + cursor
		boot_text.text = displayed_text + current_text + "_"

		await get_tree().create_timer(0.001).timeout

	# Guardar la línea terminada
	displayed_text += current_text + "\n"

	boot_text.text = displayed_text


func logo_sequence():

	# Ocultar BootText
	var boot_fade := create_tween()

	boot_fade.tween_property(
		boot_text,
		"modulate:a",
		0.0,
		0.2
	)

	await boot_fade.finished


	# =====================================================
	# LOGO 1
	# =====================================================

	await show_logo(logo1, 0.30)

	await get_tree().create_timer(0.05).timeout


	# =====================================================
	# LOGO 2
	# =====================================================

	await show_logo(logo2, 0.30)

	await get_tree().create_timer(0.05).timeout


	# =====================================================
	# LOGO 3
	# =====================================================

	await show_logo_final(logo3)


	# =====================================================
	# TRANSICIÓN INMEDIATA
	# =====================================================

	await glitch_transition()


func show_logo(logo: TextureRect, duration: float):

	# Asegurar que empieza invisible
	logo.modulate.a = 0.0

	# Fade IN
	var fade_in := create_tween()

	fade_in.tween_property(
		logo,
		"modulate:a",
		1.0,
		duration
	)

	await fade_in.finished

	# Mantener visible
	await get_tree().create_timer(0.7).timeout

	# Fade OUT
	var fade_out := create_tween()

	fade_out.tween_property(
		logo,
		"modulate:a",
		0.0,
		duration
	)

	await fade_out.finished

func show_logo_final(logo: TextureRect):

	# Comienza invisible
	logo.modulate.a = 0.0

	# Aparece rápidamente
	var fade_in := create_tween()

	fade_in.tween_property(
		logo,
		"modulate:a",
		1.0,
		0.35
	)

	await fade_in.finished

	# Pequeño momento para que podamos verlo
	await get_tree().create_timer(0.25).timeout

	# NO hacemos fade out.
	# El glitch se encargará de destruir visualmente el logo.

func glitch_transition():

	# =====================================================
	# FASE 1 - GLITCH PEQUEÑO
	# =====================================================

	glitch_material.set_shader_parameter(
		"crt_shutdown",
		0.0
	)

	glitch_material.set_shader_parameter(
		"glitch_amount",
		0.25
	)

	await get_tree().create_timer(0.10).timeout


	# =====================================================
	# FASE 2 - FLICKER
	# =====================================================

	glitch_material.set_shader_parameter(
		"glitch_amount",
		0.0
	)

	await get_tree().create_timer(0.06).timeout


	glitch_material.set_shader_parameter(
		"glitch_amount",
		0.55
	)

	await get_tree().create_timer(0.12).timeout


	# =====================================================
	# FASE 3 - GLITCH FUERTE
	# =====================================================

	glitch_material.set_shader_parameter(
		"glitch_amount",
		1.0
	)

	await get_tree().create_timer(0.20).timeout


	# =====================================================
	# FASE 4 - VHS
	# =====================================================

	var vhs_duration := 0.60
	var elapsed := 0.0

	while elapsed < vhs_duration:

		elapsed += get_process_delta_time()

		var progress := elapsed / vhs_duration

		# Mantener el glitch fuerte
		glitch_material.set_shader_parameter(
			"glitch_amount",
			1.0
		)

		# Aumentar CRT
		glitch_material.set_shader_parameter(
			"crt_shutdown",
			progress * 0.35
		)

		await get_tree().process_frame


	# =====================================================
	# FASE 5 - APAGADO CRT
	# =====================================================

	var shutdown_duration := 1.10
	elapsed = 0.0

	while elapsed < shutdown_duration:

		elapsed += get_process_delta_time()

		var progress := elapsed / shutdown_duration

		# Suavizar la transición
		progress = smoothstep(
			0.0,
			1.0,
			progress
		)

		# Reducir gradualmente el glitch
		var current_glitch := 1.0 - progress

		glitch_material.set_shader_parameter(
			"glitch_amount",
			current_glitch
		)

		# Apagar CRT
		glitch_material.set_shader_parameter(
			"crt_shutdown",
			0.35 + progress * 0.65
		)

		await get_tree().process_frame


	# =====================================================
	# FASE 6 - PUNTO MORADO
	# =====================================================

	glitch_material.set_shader_parameter(
		"glitch_amount",
		0.0
	)

	glitch_material.set_shader_parameter(
		"crt_shutdown",
		1.0
	)

	# Mantener el punto un instante
	await get_tree().create_timer(0.12).timeout


	# =====================================================
	# FASE 7 - NEGRO
	# =====================================================

	glitch_material.set_shader_parameter(
		"crt_shutdown",
		1.0
	)

	await get_tree().create_timer(0.18).timeout


	# =====================================================
	# CAMBIAR AL MENÚ
	# =====================================================

	get_tree().change_scene_to_file(
		"res://scenes/Menu/MainMenu.tscn"
	)
