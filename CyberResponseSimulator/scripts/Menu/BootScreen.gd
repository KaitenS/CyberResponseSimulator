extends Control
@export var sfx_enabled: bool = true
var _leaving := false
var _typing := false

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
	$SFX/Typing.finished.connect(_loop_typing)
	_play_sfx("PowerOn")
	
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
	if _leaving:
		return

	# Comenzar boot
	await type_boot_sequence()
	if _leaving:
		return


func type_boot_sequence():

	for line in boot_lines:

		await type_line(line)
		if _leaving:
			return

		# Pausa entre líneas
		await get_tree().create_timer(0.05).timeout
		if _leaving:
			return

	_play_sfx("AccessGranted")
	# Esperar después de ACCESS GRANTED
	await get_tree().create_timer(0.5).timeout
	if _leaving:
		return

	# Comenzar secuencia de logos
	await logo_sequence()
	if _leaving:
		return


func type_line(line: String):
	_typing = true
	_play_sfx("Typing")

	var current_text := ""

	for character in line:

		current_text += character

		# Texto anterior + texto actual + cursor
		boot_text.text = displayed_text + current_text + "_"

		await get_tree().create_timer(0.001).timeout
		if _leaving:
			return

	_typing = false
	$SFX/Typing.stop()
	_play_sfx("LineBeep")
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
	if _leaving:
		return


	# =====================================================
	# LOGO 1
	# =====================================================

	await show_logo(logo1, 0.30)
	if _leaving:
		return

	await get_tree().create_timer(0.05).timeout
	if _leaving:
		return


	# =====================================================
	# LOGO 2
	# =====================================================

	await show_logo(logo2, 0.30)
	if _leaving:
		return

	await get_tree().create_timer(0.05).timeout
	if _leaving:
		return


	# =====================================================
	# LOGO 3
	# =====================================================

	await show_logo_final(logo3)
	if _leaving:
		return


	# =====================================================
	# TRANSICIÓN INMEDIATA
	# =====================================================

	await glitch_transition()
	if _leaving:
		return


func show_logo(logo: TextureRect, duration: float):
	_play_sfx("LogoSweep")

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
	if _leaving:
		return

	# Mantener visible
	await get_tree().create_timer(0.7).timeout
	if _leaving:
		return

	# Fade OUT
	var fade_out := create_tween()

	fade_out.tween_property(
		logo,
		"modulate:a",
		0.0,
		duration
	)

	await fade_out.finished
	if _leaving:
		return

func show_logo_final(logo: TextureRect):
	_play_sfx("LogoSweep")

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
	if _leaving:
		return

	# Pequeño momento para que podamos verlo
	await get_tree().create_timer(0.25).timeout
	if _leaving:
		return

	# NO hacemos fade out.
	# El glitch se encargará de destruir visualmente el logo.

func glitch_transition():
	_play_sfx("Glitch")

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
	if _leaving:
		return


	# =====================================================
	# FASE 2 - FLICKER
	# =====================================================

	glitch_material.set_shader_parameter(
		"glitch_amount",
		0.0
	)

	await get_tree().create_timer(0.06).timeout
	if _leaving:
		return


	glitch_material.set_shader_parameter(
		"glitch_amount",
		0.55
	)

	await get_tree().create_timer(0.12).timeout
	if _leaving:
		return


	# =====================================================
	# FASE 3 - GLITCH FUERTE
	# =====================================================

	glitch_material.set_shader_parameter(
		"glitch_amount",
		1.0
	)

	await get_tree().create_timer(0.20).timeout
	if _leaving:
		return


	# =====================================================
	# FASE 4 - VHS
	# =====================================================

	_play_sfx("VHS")
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
		if _leaving:
			return


	# =====================================================
	# FASE 5 - APAGADO CRT
	# =====================================================

	$SFX/VHS.stop()
	_play_sfx("CRTShutdown")
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
		if _leaving:
			return


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
	if _leaving:
		return


	# =====================================================
	# FASE 7 - NEGRO
	# =====================================================

	glitch_material.set_shader_parameter(
		"crt_shutdown",
		1.0
	)

	await get_tree().create_timer(0.18).timeout
	if _leaving:
		return


	# =====================================================
	# CAMBIAR AL MENÚ
	# =====================================================

	_go_to_menu()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_go_to_menu()


func _play_sfx(sound_name: String) -> void:
	if sfx_enabled and not _leaving:
		var player := get_node("SFX/" + sound_name) as AudioStreamPlayer
		player.play()


func _loop_typing() -> void:
	if _typing and not _leaving:
		_play_sfx("Typing")


func _stop_sfx() -> void:
	_typing = false
	var sounds := get_node_or_null("SFX")
	if sounds != null:
		for child in sounds.get_children():
			if child is AudioStreamPlayer:
				child.stop()


func _go_to_menu() -> void:
	if _leaving:
		return
	_leaving = true
	_stop_sfx()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Menu/MainMenu.tscn")


func _exit_tree() -> void:
	_leaving = true
	_stop_sfx()
