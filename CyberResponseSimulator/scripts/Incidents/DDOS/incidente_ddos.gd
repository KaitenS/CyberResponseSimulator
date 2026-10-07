extends Node
## AUTOLOAD -> Nombre: "IncidenteDDoS"
##
## Director del incidente de Ataque DDoS.
## Controla oleadas, carga de los servidores, disponibilidad global,
## mitigaciones, reinicios y puntaje.
## Ningun nodo visual vive aqui: solo estado y reglas.

# ---------------------------------------------------------------- SEÑALES
signal incidente_iniciado()
signal incidente_terminado(exito: bool, resumen: Dictionary)
signal oleada_iniciada(indice: int, vector: int, objetivos: Array, telemetria: Dictionary)
signal oleada_neutralizada(indice: int, vector: int)
signal oleada_expirada(indice: int)
signal servidor_estado_cambiado(id: int, online: bool)
signal mitigacion_resultado(exito: bool, mensaje: String)
signal log_terminal(texto: String)
signal alerta_encolada(cantidad: int)

# ---------------------------------------------------------------- ENUMS
enum Servidor { ALERTAS, CAMARAS, MONITOREO }
enum Vector { SYN_FLOOD, UDP_AMP, HTTP_FLOOD, BOTNET }
enum Mitigacion { SYN_COOKIES, FILTRO_UDP, RATE_LIMIT, BLACKHOLE }

const NOMBRE_SERVIDOR := {
	Servidor.ALERTAS: "Servidor de Alertas",
	Servidor.CAMARAS: "Servidor de Camaras",
	Servidor.MONITOREO: "Servidor de Monitoreo",
}

const NOMBRE_VECTOR := {
	Vector.SYN_FLOOD: "SYN Flood",
	Vector.UDP_AMP: "Amplificacion UDP",
	Vector.HTTP_FLOOD: "HTTP Flood",
	Vector.BOTNET: "Botnet distribuida",
}

const NOMBRE_MITIGACION := {
	Mitigacion.SYN_COOKIES: "SYN Cookies",
	Mitigacion.FILTRO_UDP: "Filtro UDP / bloqueo puerto 53",
	Mitigacion.RATE_LIMIT: "Rate limiting por sesion",
	Mitigacion.BLACKHOLE: "Blackhole de rango de origen",
}

## Vector -> contramedida correcta
const CONTRAMEDIDA := {
	Vector.SYN_FLOOD: Mitigacion.SYN_COOKIES,
	Vector.UDP_AMP: Mitigacion.FILTRO_UDP,
	Vector.HTTP_FLOOD: Mitigacion.RATE_LIMIT,
	Vector.BOTNET: Mitigacion.BLACKHOLE,
}

# ---------------------------------------------------------- BALANCE (tunear aqui)
const DURACION_INCIDENTE := 180.0      ## Duracion total del ataque en segundos
const INTERVALO_OLEADA := 22.0         ## Cada cuanto entra una oleada nueva
const DURACION_OLEADA := 30.0          ## Cuanto vive una oleada sin mitigar
const ESCALADA_POR_OLEADA := 0.22      ## Intensidad += esto por cada oleada

const PRESION_BASE := 6.0              ## Carga/seg que mete una oleada (intensidad 1.0)
const PRESION_MITIGADA := 0.15         ## Multiplicador de presion tras mitigar bien
const RECUPERACION_CARGA := 7.0        ## Carga/seg que baja un servidor sin presion
const CARGA_MAXIMA := 100.0

const DISPONIBILIDAD_MAXIMA := 100.0
const DRENAJE_POR_CAIDO := 1.6         ## Disponibilidad/seg que pierde cada servidor caido
const REGEN_DISPONIBILIDAD := 0.6      ## Disponibilidad/seg cuando todo esta online

const TIEMPO_REINICIO_INDIVIDUAL := 5.0
const TIEMPO_REINICIO_GENERAL := 3.5
const APAGON_REINICIO_GENERAL := 8.0   ## Segundos con los 3 caidos tras el reinicio general
const CARGA_TRAS_REINICIO := 10.0

const COOLDOWN_MITIGACION := 3.0       ## Cooldown normal entre contramedidas
const COOLDOWN_FALLO := 10.0           ## Castigo por bloquear trafico legitimo

const PUNTOS_OLEADA_MITIGADA := 120
const PUNTOS_FALSO_POSITIVO := -60
const PUNTOS_POR_SEG_CAIDO := -1.5
const PUNTOS_REINICIO_GENERAL := -80

const FACTOR_JORNADA_SIN_CAMARAS := 1.5

# ---------------------------------------------------------------- ESTADO
var activo: bool = false
var tiempo_restante: float = 0.0
var disponibilidad: float = DISPONIBILIDAD_MAXIMA
var puntaje: float = 0.0

## Cada servidor: { carga, online, reiniciando, progreso_reinicio }
var servidores: Array[Dictionary] = []

## Cada oleada activa: { indice, vector, objetivos, intensidad, mitigada, vida, telemetria }
var oleadas: Array[Dictionary] = []

var cooldown_restante: float = 0.0
var alertas_en_cola: int = 0
var apagon_restante: float = 0.0

var _temporizador_oleada: float = 0.0
var _contador_oleadas: int = 0
var _oleadas_mitigadas: int = 0
var _falsos_positivos: int = 0
var _usos_reinicio_general: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(false)
	_reset_estado()


# ================================================================ API PUBLICA

func iniciar() -> void:
	_reset_estado()
	activo = true
	set_process(true)
	emit_signal("incidente_iniciado")
	_log("[ALERTA] Trafico anomalo detectado hacia la infraestructura interna.")
	_log("[ALERTA] Prioridad ALTA. Mantenga los servicios en linea.")
	_lanzar_oleada()


func abortar() -> void:
	if activo:
		_finalizar(false)


func esta_online(id: int) -> bool:
	return servidores[id].online


func carga_de(id: int) -> float:
	return servidores[id].carga


## Multiplicador de velocidad de la jornada. Conectalo a tu reloj del dia.
func factor_tiempo_jornada() -> float:
	if activo and not esta_online(Servidor.CAMARAS):
		return FACTOR_JORNADA_SIN_CAMARAS
	return 1.0


## True si las acciones del jugador deben otorgar puntaje.
func puede_registrar_puntaje() -> bool:
	return esta_online(Servidor.MONITOREO)


## Llamalo desde tu gestor de incidentes antes de mostrar una alerta nueva.
## Si el servidor de alertas esta caido, la alerta queda oculta.
func intentar_emitir_alerta() -> bool:
	if activo and not esta_online(Servidor.ALERTAS):
		alertas_en_cola += 1
		emit_signal("alerta_encolada", alertas_en_cola)
		return false
	return true


## El jugador aplica una contramedida desde la terminal.
func aplicar_mitigacion(m: int) -> void:
	if not activo:
		return
	if cooldown_restante > 0.0:
		emit_signal("mitigacion_resultado", false,
			"Consola ocupada. Espere %.1f s." % cooldown_restante)
		return

	var objetivo := _oleada_activa_para(m)
	if objetivo == -1:
		_falsos_positivos += 1
		puntaje += PUNTOS_FALSO_POSITIVO
		cooldown_restante = COOLDOWN_FALLO
		_castigo_falso_positivo()
		var msg := "FALSO POSITIVO: %s no corresponde al trafico actual.\nSe bloqueo trafico legitimo de usuarios." % NOMBRE_MITIGACION[m]
		emit_signal("mitigacion_resultado", false, msg)
		_log("[ERROR] " + msg.replace("\n", " "))
		return

	var ol: Dictionary = oleadas[objetivo]
	ol.mitigada = true
	_oleadas_mitigadas += 1
	cooldown_restante = COOLDOWN_MITIGACION

	if puede_registrar_puntaje():
		puntaje += PUNTOS_OLEADA_MITIGADA
	else:
		_log("[AVISO] Monitoreo offline: esta accion no otorga puntaje.")

	var txt := "Contramedida aplicada. %s neutralizado." % NOMBRE_VECTOR[ol.vector]
	emit_signal("mitigacion_resultado", true, txt)
	emit_signal("oleada_neutralizada", ol.indice, ol.vector)
	_log("[OK] " + txt)


## Reinicio individual: lo llama el rack fisico cuando el jugador empieza a mantener E.
func iniciar_reinicio(id: int) -> bool:
	if not activo:
		return false
	if servidores[id].reiniciando or apagon_restante > 0.0:
		return false
	servidores[id].reiniciando = true
	servidores[id].progreso_reinicio = 0.0
	_set_online(id, false)
	_log("[SYS] Reiniciando %s..." % NOMBRE_SERVIDOR[id])
	return true


func cancelar_reinicio(id: int) -> void:
	if not servidores[id].reiniciando:
		return
	servidores[id].reiniciando = false
	servidores[id].progreso_reinicio = 0.0
	if servidores[id].carga < CARGA_MAXIMA:
		_set_online(id, true)
	_log("[SYS] Reinicio de %s cancelado." % NOMBRE_SERVIDOR[id])


func avanzar_reinicio(id: int, delta: float) -> float:
	if not servidores[id].reiniciando:
		return 0.0
	servidores[id].progreso_reinicio += delta
	var p: float = clampf(servidores[id].progreso_reinicio / TIEMPO_REINICIO_INDIVIDUAL, 0.0, 1.0)
	if p >= 1.0:
		_finalizar_reinicio(id)
	return p


## Reinicio general desde la terminal.
func reinicio_general() -> void:
	if not activo or apagon_restante > 0.0:
		return
	_usos_reinicio_general += 1
	puntaje += PUNTOS_REINICIO_GENERAL
	apagon_restante = TIEMPO_REINICIO_GENERAL + APAGON_REINICIO_GENERAL
	for id in servidores.size():
		servidores[id].reiniciando = false
		servidores[id].progreso_reinicio = 0.0
		servidores[id].carga = CARGA_TRAS_REINICIO
		_set_online(id, false)
	_log("[SYS] REINICIO GENERAL. Los tres sistemas quedaran fuera de servicio.")


# ================================================================ LOOP

func _process(delta: float) -> void:
	if not activo:
		return

	tiempo_restante = maxf(0.0, tiempo_restante - delta)
	cooldown_restante = maxf(0.0, cooldown_restante - delta)

	if apagon_restante > 0.0:
		apagon_restante -= delta
		if apagon_restante <= 0.0:
			apagon_restante = 0.0
			for id in servidores.size():
				_set_online(id, true)
			_log("[SYS] Sistemas restaurados tras el reinicio general.")

	_actualizar_oleadas(delta)
	_actualizar_servidores(delta)
	_actualizar_disponibilidad(delta)

	_temporizador_oleada -= delta
	if _temporizador_oleada <= 0.0 and tiempo_restante > 12.0:
		_lanzar_oleada()

	if disponibilidad <= 0.0:
		_finalizar(false)
	elif tiempo_restante <= 0.0:
		_finalizar(true)


func _actualizar_oleadas(delta: float) -> void:
	for i in range(oleadas.size() - 1, -1, -1):
		oleadas[i].vida -= delta
		if oleadas[i].vida <= 0.0:
			var idx: int = oleadas[i].indice
			oleadas.remove_at(i)
			emit_signal("oleada_expirada", idx)


func _actualizar_servidores(delta: float) -> void:
	for id in servidores.size():
		var s: Dictionary = servidores[id]

		if s.reiniciando or apagon_restante > 0.0:
			continue

		var presion := 0.0
		for ol in oleadas:
			if id in ol.objetivos:
				var f: float = PRESION_MITIGADA if ol.mitigada else 1.0
				presion += PRESION_BASE * ol.intensidad * f

		if presion > 0.0:
			s.carga = minf(CARGA_MAXIMA, s.carga + presion * delta)
		else:
			s.carga = maxf(0.0, s.carga - RECUPERACION_CARGA * delta)

		if s.carga >= CARGA_MAXIMA and s.online:
			_set_online(id, false)
			_log("[CRITICO] %s FUERA DE SERVICIO." % NOMBRE_SERVIDOR[id])


func _actualizar_disponibilidad(delta: float) -> void:
	var caidos := 0
	for s in servidores:
		if not s.online:
			caidos += 1

	if caidos > 0:
		disponibilidad = maxf(0.0, disponibilidad - DRENAJE_POR_CAIDO * caidos * delta)
		puntaje += PUNTOS_POR_SEG_CAIDO * caidos * delta
	else:
		disponibilidad = minf(DISPONIBILIDAD_MAXIMA, disponibilidad + REGEN_DISPONIBILIDAD * delta)


# ================================================================ INTERNO

func _reset_estado() -> void:
	servidores.clear()
	for i in 3:
		servidores.append({
			"carga": 0.0,
			"online": true,
			"reiniciando": false,
			"progreso_reinicio": 0.0,
		})
	oleadas.clear()
	tiempo_restante = DURACION_INCIDENTE
	disponibilidad = DISPONIBILIDAD_MAXIMA
	puntaje = 0.0
	cooldown_restante = 0.0
	alertas_en_cola = 0
	apagon_restante = 0.0
	_temporizador_oleada = INTERVALO_OLEADA
	_contador_oleadas = 0
	_oleadas_mitigadas = 0
	_falsos_positivos = 0
	_usos_reinicio_general = 0


func _set_online(id: int, valor: bool) -> void:
	if servidores[id].online == valor:
		return
	servidores[id].online = valor
	emit_signal("servidor_estado_cambiado", id, valor)


func _finalizar_reinicio(id: int) -> void:
	servidores[id].reiniciando = false
	servidores[id].progreso_reinicio = 0.0
	servidores[id].carga = CARGA_TRAS_REINICIO
	_set_online(id, true)
	_log("[OK] %s restaurado." % NOMBRE_SERVIDOR[id])
	if id == Servidor.ALERTAS and alertas_en_cola > 0:
		_log("[ALERTA RECUPERADA] Se detectaron %d incidentes mientras el sistema estaba fuera de servicio." % alertas_en_cola)


func _lanzar_oleada() -> void:
	_temporizador_oleada = INTERVALO_OLEADA
	var intensidad := 1.0 + ESCALADA_POR_OLEADA * float(_contador_oleadas)

	var vector: int = _rng.randi_range(0, 3)
	var objetivos: Array[int] = []
	var disponibles: Array[int] = [0, 1, 2]
	disponibles.shuffle()
	# A partir de la tercera oleada el ataque se reparte en dos servidores.
	var cantidad := 1 if _contador_oleadas < 2 else (2 if _rng.randf() < 0.6 else 1)
	for i in cantidad:
		objetivos.append(disponibles[i])

	var telemetria := _generar_telemetria(vector, intensidad)

	oleadas.append({
		"indice": _contador_oleadas,
		"vector": vector,
		"objetivos": objetivos,
		"intensidad": intensidad,
		"mitigada": false,
		"vida": DURACION_OLEADA,
		"telemetria": telemetria,
	})

	var nombres: Array[String] = []
	for o in objetivos:
		nombres.append(NOMBRE_SERVIDOR[o])
	_log("[TRAFICO] Pico anomalo hacia: %s" % ", ".join(nombres))

	emit_signal("oleada_iniciada", _contador_oleadas, vector, objetivos, telemetria)
	_contador_oleadas += 1


## Firmas de red por vector. Esto es lo que el jugador debe leer para decidir.
func _generar_telemetria(vector: int, intensidad: float) -> Dictionary:
	var base := 40000.0 * intensidad
	match vector:
		Vector.SYN_FLOOD:
			return {
				"paquetes_seg": int(base * 3.4 + _rng.randf_range(-3000, 3000)),
				"tamano_medio": "%d B" % _rng.randi_range(54, 66),
				"porcentaje_syn": "%d %%" % _rng.randi_range(93, 99),
				"ips_origen": "~%d k (mayoria falsificadas)" % _rng.randi_range(120, 260),
				"puerto_destino": "443/TCP",
				"handshakes_completados": "%d %%" % _rng.randi_range(1, 4),
				"nota": "Conexiones semiabiertas acumuladas en la tabla de estado.",
			}
		Vector.UDP_AMP:
			return {
				"paquetes_seg": int(base * 0.9 + _rng.randf_range(-1500, 1500)),
				"tamano_medio": "%d B" % _rng.randi_range(2800, 3600),
				"porcentaje_syn": "0 %",
				"ips_origen": "%d (resolutores DNS publicos)" % _rng.randi_range(180, 420),
				"puerto_destino": "aleatorio/UDP  <- origen 53/UDP",
				"handshakes_completados": "n/a (sin conexion)",
				"nota": "Respuestas enormes a consultas que nadie realizo. Ratio de amplificacion 54x.",
			}
		Vector.HTTP_FLOOD:
			return {
				"paquetes_seg": int(base * 0.4 + _rng.randf_range(-800, 800)),
				"tamano_medio": "%d B" % _rng.randi_range(420, 780),
				"porcentaje_syn": "%d %%" % _rng.randi_range(4, 9),
				"ips_origen": "%d" % _rng.randi_range(600, 1400),
				"puerto_destino": "80/TCP y 443/TCP",
				"handshakes_completados": "%d %%" % _rng.randi_range(94, 100),
				"nota": "Peticiones GET validas y repetidas a /login. Mismo User-Agent en el 89 %% del trafico.",
			}
		_:
			return {
				"paquetes_seg": int(base * 2.1 + _rng.randf_range(-2500, 2500)),
				"tamano_medio": "%d B" % _rng.randi_range(700, 1500),
				"porcentaje_syn": "%d %%" % _rng.randi_range(25, 45),
				"ips_origen": "%d k IPs residenciales reales" % _rng.randi_range(40, 90),
				"puerto_destino": "multiple",
				"handshakes_completados": "%d %%" % _rng.randi_range(55, 75),
				"nota": "Trafico mixto sostenido desde un unico rango autonomo AS%d." % _rng.randi_range(12000, 64000),
			}


## Devuelve el indice de una oleada activa que esa contramedida resuelve, o -1.
func _oleada_activa_para(m: int) -> int:
	for i in oleadas.size():
		if oleadas[i].mitigada:
			continue
		if CONTRAMEDIDA[oleadas[i].vector] == m:
			return i
	return -1


func _castigo_falso_positivo() -> void:
	disponibilidad = maxf(0.0, disponibilidad - 6.0)
	for id in servidores.size():
		servidores[id].carga = minf(CARGA_MAXIMA, servidores[id].carga + 8.0)


func _finalizar(exito: bool) -> void:
	activo = false
	set_process(false)
	var resumen := {
		"exito": exito,
		"disponibilidad_final": disponibilidad,
		"puntaje": int(maxf(0.0, puntaje + disponibilidad * 4.0)),
		"oleadas_totales": _contador_oleadas,
		"oleadas_mitigadas": _oleadas_mitigadas,
		"falsos_positivos": _falsos_positivos,
		"reinicios_generales": _usos_reinicio_general,
		"alertas_perdidas": alertas_en_cola,
	}
	_log("[FIN] Incidente cerrado. Disponibilidad final: %.0f %%" % disponibilidad)
	emit_signal("incidente_terminado", exito, resumen)


func _log(texto: String) -> void:
	emit_signal("log_terminal", texto)
