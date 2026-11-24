extends Node
## Mejora la ambientacion del mapa: luz ambiente, tonos de color, brillo (glow) en
## leds y pantallas, niebla suave, sombras, luces de apoyo y vineta.
## USO: nodo hijo de Game (ver instrucciones). Todo se puede ajustar en el Inspector.
## Funciona en el renderer "Compatibilidad" que usa tu proyecto.

@export_group("Atmosfera")
@export var color_fondo := Color(0.035, 0.045, 0.07)
@export var color_ambiente := Color(0.50, 0.58, 0.72)
@export_range(0.0, 2.0) var energia_ambiente := 0.55
@export_range(0.0, 0.05) var niebla := 0.006
@export var color_niebla := Color(0.07, 0.09, 0.14)

@export_group("Imagen")
@export_range(0.0, 2.0) var brillo_glow := 0.9
@export_range(0.5, 1.5) var contraste := 1.08
@export_range(0.5, 1.5) var saturacion := 1.1
@export var usar_vineta := true
@export_range(0.0, 1.0) var fuerza_vineta := 0.35

@export_group("Luces")
@export var luz_principal_color := Color(1.0, 0.95, 0.88)
@export_range(0.0, 2.0) var luz_principal_energia := 0.75
@export var sombras := true
## Luz fria sobre el puesto del analista (el PC).
@export var luz_puesto := true
@export var color_luz_puesto := Color(0.45, 0.8, 1.0)
## Luz tenue sobre cada rack de servidores.
@export var luz_racks := true

var _env: Environment
var _luces_apoyo: Array[Light3D] = []
var _energia_amb_base := 0.55


func _ready() -> void:
	var escena := get_tree().current_scene
	if escena == null:
		escena = get_parent()

	_configurar_entorno(escena)
	_configurar_luz_principal(escena)
	_agregar_luces_apoyo(escena)
	if usar_vineta:
		_agregar_vineta()

	# Durante el apagon del DDoS la ambientacion tambien se oscurece.
	if has_node("/root/IncidenteDDoS"):
		var inc := get_node("/root/IncidenteDDoS")
		inc.corte_luz_iniciado.connect(_on_corte.bind(true))
		inc.corte_luz_terminado.connect(_on_corte.bind(false))


func _configurar_entorno(escena: Node) -> void:
	var we := escena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		we = WorldEnvironment.new()
		we.name = "WorldEnvironment"
		escena.add_child.call_deferred(we)
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = color_fondo

	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = color_ambiente
	_env.ambient_light_energy = energia_ambiente
	_energia_amb_base = energia_ambiente

	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.0
	_env.tonemap_white = 6.0

	_env.glow_enabled = brillo_glow > 0.0
	_env.glow_intensity = brillo_glow
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.08
	_env.glow_hdr_threshold = 1.0

	_env.adjustment_enabled = true
	_env.adjustment_contrast = contraste
	_env.adjustment_saturation = saturacion

	_env.fog_enabled = niebla > 0.0
	_env.fog_light_color = color_niebla
	_env.fog_density = niebla

	we.environment = _env


func _configurar_luz_principal(escena: Node) -> void:
	var luz := escena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if luz == null:
		return
	luz.light_color = luz_principal_color
	luz.light_energy = luz_principal_energia
	luz.shadow_enabled = sombras
	luz.directional_shadow_max_distance = 40.0
	luz.shadow_bias = 0.06
	luz.shadow_normal_bias = 1.5


func _agregar_luces_apoyo(escena: Node) -> void:
	if luz_puesto:
		var pc := escena.get_node_or_null("Computer") as Node3D
		if pc != null:
			var l := OmniLight3D.new()
			l.name = "LuzPuesto"
			l.light_color = color_luz_puesto
			l.light_energy = 1.1
			l.omni_range = 5.0
			l.omni_attenuation = 1.4
			pc.add_child(l)
			l.global_position = pc.global_position + Vector3(0, 1.4, 0.4)
			_luces_apoyo.append(l)
	if luz_racks:
		for r in get_tree().get_nodes_in_group("interactuable"):
			if r is Node3D and r.get_class() == "StaticBody3D" and r.has_method("texto_prompt"):
				var l := SpotLight3D.new()
				l.name = "LuzRack"
				l.light_color = Color(0.85, 0.92, 1.0)
				l.light_energy = 1.6
				l.spot_range = 4.0
				l.spot_angle = 55.0
				r.add_child(l)
				l.position = Vector3(0, 1.7, 0.9)
				l.look_at(r.global_position + Vector3(0, 0.3, 0.2), Vector3.UP)
				_luces_apoyo.append(l)


func _agregar_vineta() -> void:
	var capa := CanvasLayer.new()
	capa.name = "Vineta"
	capa.layer = 0
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float fuerza = 0.35;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = dot(uv, uv) * 1.6;
	COLOR = vec4(0.0, 0.0, 0.0, smoothstep(0.12, 0.75, d) * fuerza);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("fuerza", fuerza_vineta)
	rect.material = mat
	capa.add_child(rect)
	add_child(capa)


func _on_corte(iniciado: bool) -> void:
	if _env == null:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(_env, "ambient_light_energy", 0.06 if iniciado else _energia_amb_base, 0.5)
	t.tween_property(_env, "glow_intensity", 0.3 if iniciado else brillo_glow, 0.5)
	for l in _luces_apoyo:
		if is_instance_valid(l):
			t.tween_property(l, "light_energy", 0.0 if iniciado else (1.1 if l is OmniLight3D else 1.6), 0.5)
