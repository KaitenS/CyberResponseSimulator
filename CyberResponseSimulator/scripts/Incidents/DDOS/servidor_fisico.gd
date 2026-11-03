extends StaticBody3D
class_name ServidorFisico
## Rack fisico dentro de la sala de servidores.
## El jugador se para frente a el y MANTIENE la tecla de interaccion
## durante 5 segundos para reiniciarlo. Si se suelta, se cancela.
##
## Estructura de la escena (ver servidor_fisico.tscn):
##   ServidorFisico (StaticBody3D)  <- este script
##     |- CollisionShape3D
##     |- MeshInstance3D            (el rack)
##     |- Pantalla (Label3D)        (texto de estado)
##     |- Luz (OmniLight3D)         (verde/ambar/rojo segun estado)
##     |- Led1, Led2, Led3          (tira de leds frontales, sincronizados)
##     |- Ventilador (MeshInstance3D) (gira mas rapido cuanto mas carga)
##     |- Chispas (GPUParticles3D)  (estallido breve cuando el rack cae)

@export var id_servidor: IncidenteDDoS.Servidor = IncidenteDDoS.Servidor.ALERTAS

@export var pantalla: Label3D
@export var luz: OmniLight3D
@export var malla: MeshInstance3D
@export var leds: Array[MeshInstance3D] = []
@export var ventilador: Node3D
@export var chispas: GPUParticles3D

@export var color_ok := Color(0.25, 1.0, 0.45)
@export var color_alerta := Color(1.0, 0.75, 0.15)
@export var color_caido := Color(1.0, 0.2, 0.2)

## Apariencia profesional: el script agrega por codigo bisel, unidades 1U con
## leds, placa con el nombre y un medidor de leds (sin texto de % ni barras).
@export var estilizar := true
@export var mostrar_medidor := true

const VELOCIDAD_VENTILADOR_MIN := 1.5   ## rad/seg con el servidor sin carga
const VELOCIDAD_VENTILADOR_MAX := 14.0  ## rad/seg a carga maxima

var _manteniendo := false
var _progreso := 0.0
var _parpadeo := 0.0
var _online_anterior := true
var _t := 0.0
var _mini_leds: Array[MeshInstance3D] = []
var _segmentos: Array[MeshInstance3D] = []
var _placa: Label3D


func _ready() -> void:
	add_to_group("interactuable")
	# Cada led necesita su propio material: en la escena los comparten y se
	# pisaban entre racks (todos mostraban el color del ultimo).
	for led in leds:
		if led != null:
			var base := led.get_surface_override_material(0)
			if base != null:
				led.set_surface_override_material(0, base.duplicate())
	if estilizar:
		_construir_detalles()
	IncidenteDDoS.servidor_estado_cambiado.connect(_on_estado_cambiado)
	_online_anterior = true
	_refrescar_pantalla()
	if chispas:
		chispas.emitting = false
		chispas.one_shot = true


# ------------------------------------------------- API que llama el jugador

func texto_prompt() -> String:
	if not IncidenteDDoS.activo:
		return "%s - operativo" % IncidenteDDoS.NOMBRE_SERVIDOR[id_servidor]
	if IncidenteDDoS.apagon_restante > 0.0:
		return "Reinicio general en curso..."
	if IncidenteDDoS.infectado[id_servidor]:
		return "SERVIDOR INFECTADO (ransomware): aislalo en el PC > Servidores"
	if IncidenteDDoS.verificaciones_pendientes[id_servidor] > 0:
		if IncidenteDDoS.tipo_verificacion[id_servidor] == IncidenteDDoS.Verificacion.CODIGO:
			return "REINICIO FALLIDO: memoriza el CODIGO %s y escribelo en el PC > Servidores" % IncidenteDDoS.codigo_rack[id_servidor]
		return "REINICIO FALLIDO: autoriza en el PC > Servidores (%d)" % IncidenteDDoS.verificaciones_pendientes[id_servidor]
	if IncidenteDDoS.autorizado[id_servidor]:
		return "[MANTENER E] Reiniciar %s (AUTORIZADO)" % IncidenteDDoS.NOMBRE_SERVIDOR[id_servidor]
	if IncidenteDDoS.esta_online(id_servidor):
		return "[MANTENER E] Reiniciar %s  (carga %d%%)" % [
			IncidenteDDoS.NOMBRE_SERVIDOR[id_servidor],
			int(IncidenteDDoS.carga_de(id_servidor))
		]
	return "[MANTENER E] RESTAURAR %s" % IncidenteDDoS.NOMBRE_SERVIDOR[id_servidor]


## Llamalo cada frame mientras el jugador mira el rack y mantiene la tecla.
func mantener_interaccion(delta: float) -> void:
	if not IncidenteDDoS.activo or IncidenteDDoS.apagon_restante > 0.0:
		return
	if not _manteniendo:
		if not IncidenteDDoS.iniciar_reinicio(id_servidor):
			return
		_manteniendo = true
	_progreso = IncidenteDDoS.avanzar_reinicio(id_servidor, delta)
	if _progreso >= 1.0:
		_manteniendo = false
		_progreso = 0.0


## Llamalo cuando el jugador suelta la tecla o deja de mirar el rack.
func soltar_interaccion() -> void:
	if not _manteniendo:
		return
	_manteniendo = false
	_progreso = 0.0
	IncidenteDDoS.cancelar_reinicio(id_servidor)


# ------------------------------------------------------------- VISUAL

func _process(delta: float) -> void:
	_parpadeo += delta
	_refrescar_pantalla()
	_refrescar_luz()
	_refrescar_leds()
	_refrescar_ventilador(delta)
	if estilizar:
		_t += delta
		_refrescar_detalles()


func _estado_actual() -> String:
	## Devuelve "ok", "alerta" o "caido". Centraliza la logica de estado
	## para que pantalla, leds y luz siempre coincidan entre si.
	if not IncidenteDDoS.activo:
		return "ok"
	if not IncidenteDDoS.esta_online(id_servidor):
		return "caido"
	if IncidenteDDoS.carga_de(id_servidor) > 60.0:
		return "alerta"
	return "ok"


func _refrescar_pantalla() -> void:
	## Pantalla compacta: solo el estado en pocas palabras. El % de carga vive en
	## el PC (ventana Servidores) y en el medidor de leds del rack.
	if pantalla == null:
		return

	if estilizar:
		pantalla.font_size = 20
		pantalla.pixel_size = 0.0028
		pantalla.position = Vector3(0, 0.52, 0.264)
		pantalla.outline_size = 0
		pantalla.line_spacing = -2.0

	if _manteniendo:
		pantalla.text = "REINICIANDO\n%d%%" % int(_progreso * 100.0)
		pantalla.modulate = color_alerta
		return

	if not IncidenteDDoS.activo:
		pantalla.text = "OPERATIVO"
		pantalla.modulate = color_ok
		return

	if IncidenteDDoS.infectado[id_servidor]:
		var parpadea_i := fmod(_parpadeo, 0.6) < 0.35
		pantalla.text = "RANSOMWARE\nAISLAR EN PC" if parpadea_i else "AISLAR EN PC"
		pantalla.modulate = Color(1.0, 0.2, 0.9)
		return

	if IncidenteDDoS.verificaciones_pendientes[id_servidor] > 0:
		var parpadea := fmod(_parpadeo, 1.0) < 0.6
		if IncidenteDDoS.tipo_verificacion[id_servidor] == IncidenteDDoS.Verificacion.CODIGO:
			pantalla.text = "%s\nCODIGO %s" % [
				"REINICIO FALLIDO" if parpadea else "",
				IncidenteDDoS.codigo_rack[id_servidor]]
		else:
			pantalla.text = "%s\nVERIFICAR EN PC (%d)" % [
				"REINICIO FALLIDO" if parpadea else "",
				IncidenteDDoS.verificaciones_pendientes[id_servidor]]
		pantalla.modulate = color_alerta
		return

	if IncidenteDDoS.apagon_restante > 0.0:
		pantalla.text = "REINICIO\nGENERAL"
		pantalla.modulate = color_alerta
		return

	if not IncidenteDDoS.esta_online(id_servidor):
		var visible_ahora := fmod(_parpadeo, 0.8) < 0.5
		pantalla.text = "SIN SERVICIO" if visible_ahora else ""
		pantalla.modulate = color_caido
		return

	# El estado se distingue por texto y no solo por color (accesibilidad).
	if IncidenteDDoS.carga_de(id_servidor) < 60.0:
		pantalla.text = "EN LINEA"
		pantalla.modulate = color_ok
	else:
		pantalla.text = "CARGA ALTA"
		pantalla.modulate = color_alerta


func _refrescar_luz() -> void:
	if luz == null:
		return
	if not IncidenteDDoS.activo:
		luz.light_color = color_ok
		luz.light_energy = 1.0
		return
	if not IncidenteDDoS.esta_online(id_servidor):
		luz.light_color = color_caido
		luz.light_energy = 1.0 + sin(_parpadeo * 12.0) * 0.8
	elif IncidenteDDoS.carga_de(id_servidor) > 60.0:
		luz.light_color = color_alerta
		luz.light_energy = 1.0 + sin(_parpadeo * 6.0) * 0.4
	else:
		luz.light_color = color_ok
		luz.light_energy = 1.0


## Tira de leds en la cara frontal del rack. Se leen de un vistazo desde
## lejos, mucho antes de poder leer el texto de la pantalla.
func _refrescar_leds() -> void:
	if leds.is_empty():
		return

	var estado := _estado_actual()
	var color: Color
	var parpadeando := false

	match estado:
		"caido":
			color = color_caido
			parpadeando = true
		"alerta":
			color = color_alerta
		_:
			color = color_ok

	var energia := 1.0
	if parpadeando:
		energia = 0.3 + 0.7 * (0.5 + 0.5 * sin(_parpadeo * 10.0))

	for led in leds:
		if led == null:
			continue
		var mat := led.get_surface_override_material(0)
		if mat == null or not (mat is StandardMaterial3D):
			mat = StandardMaterial3D.new()
			mat.emission_enabled = true
			led.set_surface_override_material(0, mat)
		mat.albedo_color = color
		mat.emission = color
		mat.emission_energy_multiplier = energia * 2.0


## El ventilador gira mas rapido cuanto mas carga tiene el servidor.
## Comunica "esfuerzo" sin que el jugador necesite leer ningun numero.
func _refrescar_ventilador(delta: float) -> void:
	if ventilador == null:
		return
	var carga := IncidenteDDoS.carga_de(id_servidor) if IncidenteDDoS.activo else 0.0
	var velocidad := lerpf(VELOCIDAD_VENTILADOR_MIN, VELOCIDAD_VENTILADOR_MAX, clampf(carga / 100.0, 0.0, 1.0))
	ventilador.rotate_z(velocidad * delta)


# ------------------------------------------------- DETALLES PROCEDURALES

func _caja3d(tam: Vector3, pos: Vector3, color: Color, metal := 0.5, rugo := 0.5, emisivo := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = rugo
	if emisivo:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.5
	m.material_override = mat
	m.position = pos
	add_child(m)
	return m


func _construir_detalles() -> void:
	var zf := 0.255   # cara frontal del rack
	# Carcasa mas oscura y con acabado satinado
	if malla != null:
		var carcasa := StandardMaterial3D.new()
		carcasa.albedo_color = Color(0.07, 0.08, 0.1)
		carcasa.metallic = 0.7
		carcasa.roughness = 0.4
		malla.material_override = carcasa

	# Bisel frontal y franja de acento superior
	_caja3d(Vector3(0.56, 1.74, 0.006), Vector3(0, 0, zf), Color(0.11, 0.12, 0.15), 0.6, 0.45)
	_caja3d(Vector3(0.56, 0.012, 0.01), Vector3(0, 0.865, zf + 0.002), Color(0.25, 0.8, 0.9), 0.0, 0.5, true)

	# Placa con el nombre (pequena, sin porcentajes)
	_placa = Label3D.new()
	var nombre: String = IncidenteDDoS.NOMBRE_SERVIDOR[id_servidor]
	_placa.text = nombre.replace("Servidor de ", "").to_upper()
	_placa.font_size = 24
	_placa.pixel_size = 0.0028
	_placa.modulate = Color(0.78, 0.86, 0.92)
	_placa.outline_size = 0
	_placa.position = Vector3(0, 0.79, zf + 0.004)
	add_child(_placa)

	# Pantalla: panel negro donde se escribe el estado
	_caja3d(Vector3(0.5, 0.2, 0.008), Vector3(0, 0.52, zf + 0.001), Color(0.01, 0.015, 0.02), 0.1, 0.2)
	_caja3d(Vector3(0.512, 0.212, 0.004), Vector3(0, 0.52, zf - 0.001), Color(0.2, 0.24, 0.3), 0.7, 0.35)

	# Medidor de 8 leds bajo la pantalla (carga / progreso de reinicio)
	if mostrar_medidor:
		for i in 8:
			var seg := _caja3d(Vector3(0.042, 0.016, 0.006), Vector3(-0.2 + i * 0.0572, 0.375, zf + 0.002),
				Color(0.15, 0.17, 0.2), 0.0, 0.6, true)
			_segmentos.append(seg)

	# Rejilla circular detras del ventilador y leds frontales mas finos
	var disco := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.11
	cil.bottom_radius = 0.11
	cil.height = 0.006
	disco.mesh = cil
	var mat_disco := StandardMaterial3D.new()
	mat_disco.albedo_color = Color(0.04, 0.045, 0.055)
	mat_disco.metallic = 0.4
	mat_disco.roughness = 0.5
	disco.material_override = mat_disco
	disco.rotation_degrees = Vector3(90, 0, 0)
	disco.position = Vector3(0, -0.2, zf + 0.001)
	add_child(disco)
	for led in leds:
		if led != null:
			led.scale = Vector3(0.5, 0.5, 1.0)
			led.position.y = -0.7

	# Unidades 1U con rejilla y led de actividad
	var ys := [0.28, 0.14, 0.0, -0.4, -0.52]
	for k in ys.size():
		var y: float = ys[k]
		_caja3d(Vector3(0.5, 0.1, 0.008), Vector3(0, y, zf + 0.001), Color(0.15, 0.16, 0.19), 0.6, 0.4)
		for r in 6:
			_caja3d(Vector3(0.012, 0.06, 0.004), Vector3(0.02 + r * 0.03, y, zf + 0.006), Color(0.05, 0.055, 0.065), 0.2, 0.7)
		var led := _caja3d(Vector3(0.022, 0.022, 0.006), Vector3(-0.2, y, zf + 0.006), color_ok, 0.0, 0.5, true)
		_mini_leds.append(led)


func _refrescar_detalles() -> void:
	var estado := _estado_actual()
	var color := color_ok
	match estado:
		"caido":
			color = color_caido
		"alerta":
			color = color_alerta
	if IncidenteDDoS.activo and IncidenteDDoS.infectado[id_servidor]:
		color = Color(1.0, 0.2, 0.9)

	# Leds de actividad: parpadeo suave en reposo, rapido con carga, apagados si cae.
	var rapidez := 3.0 if estado == "ok" else (8.0 if estado == "alerta" else 12.0)
	for i in _mini_leds.size():
		var mat := _mini_leds[i].material_override as StandardMaterial3D
		var on := sin(_t * rapidez + i * 2.3) > -0.2
		var e := 1.6 if on else 0.15
		if estado == "caido":
			e = 0.1 + 0.9 * (0.5 + 0.5 * sin(_t * 8.0)) if i == 0 else 0.05
		mat.albedo_color = color
		mat.emission = color
		mat.emission_energy_multiplier = e

	# Medidor
	if _segmentos.is_empty():
		return
	var valor := 0.0
	if _manteniendo:
		valor = _progreso
	elif IncidenteDDoS.activo and IncidenteDDoS.esta_online(id_servidor):
		valor = clampf(IncidenteDDoS.carga_de(id_servidor) / 100.0, 0.0, 1.0)
	var encendidos := int(round(valor * _segmentos.size()))
	for i in _segmentos.size():
		var mat := _segmentos[i].material_override as StandardMaterial3D
		if i < encendidos:
			var c := color_ok
			if _manteniendo:
				c = color_alerta
			elif i >= 7:
				c = color_caido
			elif i >= 5:
				c = color_alerta
			mat.albedo_color = c
			mat.emission = c
			mat.emission_energy_multiplier = 1.8
		else:
			mat.albedo_color = Color(0.14, 0.16, 0.19)
			mat.emission = Color(0.14, 0.16, 0.19)
			mat.emission_energy_multiplier = 0.2


func _on_estado_cambiado(id: int, online: bool) -> void:
	if id != id_servidor:
		return
	_refrescar_pantalla()
	# Estallido de chispas justo en el instante en que el servidor cae
	# (no cuando se reinicia hacia arriba).
	if _online_anterior and not online and chispas:
		chispas.restart()
		chispas.emitting = true
	_online_anterior = online
