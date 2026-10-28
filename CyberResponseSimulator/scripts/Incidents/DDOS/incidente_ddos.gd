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
## El reinicio fisico de un rack fallo: hay que autorizarlo en el PC
## (secuencias de flechas) y volver al rack para reiniciar de nuevo.
signal reinicio_fallido(id: int, secuencias: int)
signal secuencia_completada(id: int, restantes: int)
signal reinicio_autorizado(id: int)
## Recompensa por acertar una secuencia: sube la barra de disponibilidad.
signal recompensa_secuencia(id: int, disponibilidad_ganada: float, detalle: String)
## El jugador abrio la ventana Servidores del PC (sirve para el tutorial).
signal consola_abierta()
## El jugador empezo a reiniciar un rack fisico.
signal reinicio_iniciado(id: int)
## Aviso: el ataque sera dado por abandonado si nadie atiende.
signal aviso_abandono(segundos_restantes: float)
## Eventos aleatorios.
signal corte_luz_iniciado(segundos: float)
signal corte_luz_terminado()
signal infeccion_detectada(id: int)
signal servidor_aislado(id: int)
## Emitida para que el jugador (camara) reaccione fisicamente: caida de un
## servidor o falso positivo. intensidad va de 0.0 a 1.0, mientras mas
## fuerte el golpe, mayor la sacudida esperada.
signal impacto_camara(intensidad: float)

# ---------------------------------------------------------------- ENUMS
enum Servidor { ALERTAS, CAMARAS, MONITOREO }
## LEGITIMO es la oleada trampa: parece trafico anomalo pero es real y no requiere accion.
enum Vector { SYN_FLOOD, UDP_AMP, HTTP_FLOOD, BOTNET, LEGITIMO }
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
	Vector.LEGITIMO: "Trafico legitimo (falsa alarma)",
}

const NOMBRE_MITIGACION := {
	Mitigacion.SYN_COOKIES: "SYN Cookies",
	Mitigacion.FILTRO_UDP: "Filtro UDP / bloqueo puerto 53",
	Mitigacion.RATE_LIMIT: "Rate limiting por sesion",
	Mitigacion.BLACKHOLE: "Blackhole de rango de origen",
}

## Vector -> contramedida correcta. LEGITIMO no aparece aqui a proposito:
## no tiene contramedida valida, la jugada correcta es no tocar nada.
const CONTRAMEDIDA := {
	Vector.SYN_FLOOD: Mitigacion.SYN_COOKIES,
	Vector.UDP_AMP: Mitigacion.FILTRO_UDP,
	Vector.HTTP_FLOOD: Mitigacion.RATE_LIMIT,
	Vector.BOTNET: Mitigacion.BLACKHOLE,
}

## Vectores que representan ataques reales (excluye la trampa LEGITIMO).
const VECTORES_ATAQUE := [Vector.SYN_FLOOD, Vector.UDP_AMP, Vector.HTTP_FLOOD, Vector.BOTNET]

# ---------------------------------------------------------- BALANCE (tunear aqui)
const DURACION_INCIDENTE := 120.0      ## Duracion maxima (modo practica); en partida se ajusta al reloj
const INTERVALO_OLEADA := 22.0         ## Cada cuanto entra una oleada nueva
const DURACION_OLEADA := 30.0          ## Cuanto vive una oleada sin mitigar
const ESCALADA_POR_OLEADA := 0.22      ## Intensidad += esto por cada oleada
const INTENSIDAD_MAXIMA := 1.9         ## Tope: en partidas largas no se vuelve imposible

const PRESION_BASE := 7.5              ## Carga/seg que mete una oleada (intensidad 1.0)
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
const PUNTOS_LEGITIMA_IGNORADA := 15   ## Bono por NO tocar una oleada trampa hasta que expira

const FACTOR_JORNADA_SIN_CAMARAS := 1.5

## Probabilidad de que un reinicio fisico de rack FALLE y exija verificacion
## en el PC. (var, no const, para poder tunearla o forzarla en pruebas.)
var prob_fallo_reinicio: float = 0.45
## Cuantas secuencias de flechas pide un reinicio fallido. Se sortea un valor
## de esta lista (mas copias = mas probable): casi siempre 1-2, rara vez 5.
const SECUENCIAS_POSIBLES := [1, 1, 1, 1, 2, 2, 2, 3, 3, 5]
## Recompensa (puntos de la barra de disponibilidad) por acertar una secuencia
## y un extra al completar todas y dejar el rack autorizado.
const RECOMPENSA_SECUENCIA := 4.0
const RECOMPENSA_AUTORIZACION := 6.0
const PUNTOS_SECUENCIA := 20
## Bonos extra: racha de aciertos sin error y secuencia resuelta rapido.
const BONO_RACHA_2 := 2.0
const BONO_RACHA_4 := 4.0
const BONO_RAPIDO := 2.0

## Dificultad progresiva: cada oleada sube la probabilidad de fallo.
const PROB_FALLO_POR_OLEADA := 0.04
const PROB_FALLO_MAXIMA := 0.85
const PROB_FALLO_AUMENTO_MAXIMO := 0.2   ## lo mas que puede subir por oleadas
const SECUENCIAS_AVANZADO := [1, 2, 2, 3, 3, 3, 5, 5]   ## a partir de la oleada 4
const OLEADA_AVANZADA := 4

## Personalidad de cada rack.
const PROB_FALLO_EXTRA := {0: 0.0, 1: 0.15, 2: -0.10}       ## Camaras es inestable
const TIEMPO_REINICIO_SERVIDOR := {0: 5.0, 1: 5.0, 2: 7.0}  ## Monitoreo reinicia lento
const RASGO_SERVIDOR := {0: "", 1: "inestable", 2: "reinicio lento"}

## Tipo de verificacion que pide un reinicio fallido.
enum Verificacion { FLECHAS, CODIGO }

## Si nadie atiende el ataque (ventana Servidores cerrada y sin tocar racks)
## durante este tiempo, se da por abandonado y falla.
const LIMITE_SIN_ATENCION := 40.0
const AVISO_SIN_ATENCION := 0.6   ## fraccion del limite en que se avisa

## Dificultad: 0 facil, 1 normal, 2 dificil -> {presion, prob_fallo}
const DIFICULTADES := [
	{"nombre": "Facil", "presion": 6.0, "prob_fallo": 0.35},
	{"nombre": "Normal", "presion": 7.5, "prob_fallo": 0.45},
	{"nombre": "Dificil", "presion": 9.0, "prob_fallo": 0.55},
]

## Eventos aleatorios (una vez por incidente como maximo).
const PROB_CORTE_LUZ := 0.6
const DURACION_CORTE_LUZ := 6.0
const OLEADA_CORTE_LUZ := 2
const PROB_INFECCION := 0.55
const OLEADA_INFECCION := 3
const PRESION_INFECCION := 5.0         ## carga/seg extra del servidor infectado
const DRENAJE_INFECCION := 0.8         ## disponibilidad/seg extra por infectado
const PUNTOS_AISLAR := 40
const BONO_AISLAR := 3.0

const ARCHIVO_REGISTRO := "user://ddos_registro.json"
const MAX_REGISTROS := 30

## Probabilidad de que una oleada nueva sea trafico legitimo (trampa).
const PROB_LEGITIMA := 0.22
## A partir de que numero de oleada pueden aparecer trampas.
const OLEADA_MINIMA_LEGITIMA := 1
## Probabilidad de que una oleada real venga con un segundo vector combinado.
const PROB_COMBINADA := 0.3
## A partir de que numero de oleada pueden aparecer ataques combinados.
const OLEADA_MINIMA_COMBINADA := 4

# ---------------------------------------------------------------- ESTADO
var activo: bool = false
var tiempo_restante: float = 0.0
var disponibilidad: float = DISPONIBILIDAD_MAXIMA
var puntaje: float = 0.0

## Cada servidor: { carga, online, reiniciando, progreso_reinicio }
var servidores: Array[Dictionary] = []

## Cada oleada activa:
## { indice, vector, vector_extra, objetivos, intensidad, mitigada, mitigada_extra,
##   vida, telemetria, telemetria_extra }
## vector_extra = -1 cuando la oleada tiene un solo vector (caso normal).
var oleadas: Array[Dictionary] = []

## Ultimas lineas del registro (para pantallas que se abren a mitad del incidente).
var historial_log: Array[String] = []

## Por servidor: cuantas secuencias de flechas faltan antes de poder reiniciar.
var verificaciones_pendientes: Array[int] = [0, 0, 0]
## Por servidor: true cuando ya se autorizo en el PC (el proximo reinicio no falla).
var autorizado: Array[bool] = [false, false, false]
## Por servidor: tipo de verificacion pendiente y codigo (si es de codigo).
var tipo_verificacion: Array[int] = [0, 0, 0]
var codigo_rack: Array[String] = ["", "", ""]
## Probabilidad de que un reinicio fallido pida CODIGO en vez de flechas.
var prob_codigo: float = 0.35

## Duracion de esta partida del incidente (se adapta al reloj del juego).
var duracion_total: float = DURACION_INCIDENTE
var _presion_base: float = PRESION_BASE
var nombre_dificultad: String = "Normal"

## Eventos
var corte_restante: float = 0.0
var infectado: Array[bool] = [false, false, false]
var _corte_dado := false
var _infeccion_dada := false
var _corte_en_oleada := -1       ## oleada en la que ocurrira (-1 = no habra corte)
var _infeccion_en_oleada := -1
var _infecciones := 0
var _aislados := 0
var _cortes := 0
var tiempo_sin_atencion: float = 0.0
var _limite_atencion: float = LIMITE_SIN_ATENCION
var _aviso_atencion_dado := false
var _intervalo_oleada: float = INTERVALO_OLEADA
var _duracion_oleada: float = DURACION_OLEADA
var _abandonado := false
var _reinicios_fallidos := 0
var _secuencias_ok := 0
var _codigos_ok := 0
var _racha_max := 0

var cooldown_restante: float = 0.0
var alertas_en_cola: int = 0
var apagon_restante: float = 0.0

var _temporizador_oleada: float = 0.0
var _contador_oleadas: int = 0
var _oleadas_mitigadas: int = 0
var _falsos_positivos: int = 0
var _usos_reinicio_general: int = 0
var _oleadas_legitimas: int = 0
var _oleadas_combinadas: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	set_process(false)
	_reset_estado()


# ================================================================ API PUBLICA

func iniciar(duracion: float = DURACION_INCIDENTE) -> void:
	duracion_total = duracion
	# Ritmo de oleadas y limite de abandono escalan con la duracion.
	_intervalo_oleada = clampf(duracion / 6.0, 9.0, INTERVALO_OLEADA)
	_duracion_oleada = minf(DURACION_OLEADA, _intervalo_oleada * 2.2)
	_limite_atencion = minf(LIMITE_SIN_ATENCION, duracion * 0.6)
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
	if not activo or corte_restante > 0.0:
		return
	registrar_atencion()
	if cooldown_restante > 0.0:
		emit_signal("mitigacion_resultado", false,
			"Consola ocupada. Espere %.1f s." % cooldown_restante)
		return

	var resultado := _buscar_objetivo_mitigacion(m)
	var idx: int = resultado.get("idx", -1)

	if idx == -1:
		_falsos_positivos += 1
		puntaje += PUNTOS_FALSO_POSITIVO
		cooldown_restante = COOLDOWN_FALLO
		_castigo_falso_positivo()
		emit_signal("impacto_camara", 0.5)
		var msg := "FALSO POSITIVO: %s no corresponde al trafico actual.\nSe bloqueo trafico legitimo de usuarios." % NOMBRE_MITIGACION[m]
		emit_signal("mitigacion_resultado", false, msg)
		_log("[ERROR] " + msg.replace("\n", " "))
		return

	var ol: Dictionary = oleadas[idx]
	var parte: String = resultado.get("parte", "principal")
	if parte == "principal":
		ol.mitigada = true
	else:
		ol.mitigada_extra = true

	cooldown_restante = COOLDOWN_MITIGACION

	var completo: bool = ol.mitigada and (ol.vector_extra == -1 or ol.mitigada_extra)
	var txt: String

	if completo:
		_oleadas_mitigadas += 1
		if puede_registrar_puntaje():
			puntaje += PUNTOS_OLEADA_MITIGADA
		else:
			_log("[AVISO] Monitoreo offline: esta accion no otorga puntaje.")
		txt = "Contramedida aplicada. Flujo #%d neutralizado por completo." % (ol.indice + 1)
		emit_signal("oleada_neutralizada", ol.indice, ol.vector)
	else:
		txt = "Contramedida parcial aplicada al flujo #%d. Se detecto una segunda firma: aplique tambien su contramedida." % (ol.indice + 1)

	emit_signal("mitigacion_resultado", true, txt)
	_log("[OK] " + txt)


## Reinicio individual: lo llama el rack fisico cuando el jugador empieza a mantener E.
func iniciar_reinicio(id: int) -> bool:
	if not activo:
		return false
	if servidores[id].reiniciando or apagon_restante > 0.0:
		return false
	if verificaciones_pendientes[id] > 0:
		return false # primero hay que autorizar en el PC
	if infectado[id]:
		return false # primero hay que aislarlo en el PC
	servidores[id].reiniciando = true
	servidores[id].progreso_reinicio = 0.0
	_set_online(id, false)
	registrar_atencion()
	_log("[SYS] Reiniciando %s..." % NOMBRE_SERVIDOR[id])
	emit_signal("reinicio_iniciado", id)
	return true


## Eventos aleatorios: se evaluan al entrar cada oleada.
func _sortear_eventos() -> void:
	if duracion_total < 45.0:
		return
	var n := _contador_oleadas - 1   # indice de la oleada recien lanzada
	if not _corte_dado and n == _corte_en_oleada:
		iniciar_corte_luz()
	if not _infeccion_dada and n == _infeccion_en_oleada:
		var candidatos: Array[int] = []
		for i in 3:
			if esta_online(i) and not servidores[i].reiniciando:
				candidatos.append(i)
		if not candidatos.is_empty():
			infectar(candidatos[_rng.randi_range(0, candidatos.size() - 1)])


func iniciar_corte_luz(segundos: float = DURACION_CORTE_LUZ) -> void:
	_corte_dado = true
	_cortes += 1
	corte_restante = segundos
	_log("[CRITICO] CORTE DE ENERGIA en la oficina. El PC no responde %d s: use los racks." % int(segundos))
	emit_signal("impacto_camara", 0.5)
	emit_signal("corte_luz_iniciado", segundos)


func infectar(id: int) -> void:
	_infeccion_dada = true
	infectado[id] = true
	_infecciones += 1
	_log("[CRITICO] Ransomware detectado en %s. Aislelo desde el PC > Servidores." % NOMBRE_SERVIDOR[id])
	emit_signal("impacto_camara", 0.4)
	emit_signal("infeccion_detectada", id)


## El PC aisla un servidor infectado (boton AISLAR). Tiene el mismo cooldown que
## las contramedidas.
func aislar_servidor(id: int) -> bool:
	if not activo or not infectado[id] or corte_restante > 0.0:
		return false
	if cooldown_restante > 0.0:
		return false
	registrar_atencion()
	infectado[id] = false
	_aislados += 1
	cooldown_restante = COOLDOWN_MITIGACION
	servidores[id].carga = minf(servidores[id].carga, 40.0)
	disponibilidad = minf(DISPONIBILIDAD_MAXIMA, disponibilidad + BONO_AISLAR)
	if puede_registrar_puntaje():
		puntaje += PUNTOS_AISLAR
	_log("[OK] %s aislado y limpiado. Ransomware contenido." % NOMBRE_SERVIDOR[id])
	emit_signal("servidor_aislado", id)
	return true


## Aplica una dificultad (0 facil, 1 normal, 2 dificil). Llamar ANTES de iniciar().
func aplicar_dificultad(nivel: int) -> void:
	var d: Dictionary = DIFICULTADES[clampi(nivel, 0, DIFICULTADES.size() - 1)]
	_presion_base = d.presion
	prob_fallo_reinicio = d.prob_fallo
	nombre_dificultad = d.nombre


## El PC llama esto cada vez que el jugador completa una secuencia de flechas.
func completar_secuencia(id: int, rapida: bool = false, racha: int = 0) -> void:
	if not activo or verificaciones_pendientes[id] <= 0:
		return
	registrar_atencion()
	verificaciones_pendientes[id] -= 1
	_secuencias_ok += 1
	_racha_max = maxi(_racha_max, racha)
	var bono := RECOMPENSA_SECUENCIA
	var detalle := PackedStringArray()
	if racha >= 4:
		bono += BONO_RACHA_4
		detalle.append("RACHA x%d" % racha)
	elif racha >= 2:
		bono += BONO_RACHA_2
		detalle.append("RACHA x%d" % racha)
	if rapida:
		bono += BONO_RAPIDO
		detalle.append("RAPIDO")
	if verificaciones_pendientes[id] == 0:
		bono += RECOMPENSA_AUTORIZACION
	disponibilidad = minf(DISPONIBILIDAD_MAXIMA, disponibilidad + bono)
	if puede_registrar_puntaje():
		puntaje += PUNTOS_SECUENCIA
	emit_signal("recompensa_secuencia", id, bono, " ".join(detalle))
	emit_signal("secuencia_completada", id, verificaciones_pendientes[id])
	if verificaciones_pendientes[id] == 0:
		autorizado[id] = true
		_log("[OK] Reinicio de %s autorizado. Vuelva al rack y mantenga E." % NOMBRE_SERVIDOR[id])
		emit_signal("reinicio_autorizado", id)


## Verifica un codigo escrito en el PC. True si era correcto.
func completar_codigo(id: int, texto: String) -> bool:
	if not activo or verificaciones_pendientes[id] <= 0 or tipo_verificacion[id] != Verificacion.CODIGO:
		return false
	registrar_atencion()
	if texto == codigo_rack[id]:
		_codigos_ok += 1
		completar_secuencia(id, false, 0)
		return true
	_log("[ERROR] Codigo incorrecto para %s." % NOMBRE_SERVIDOR[id])
	emit_signal("impacto_camara", 0.15)
	return false


## Llamalo cuando el jugador hace algo util (abrir el PC, mitigar, reiniciar...).
func registrar_atencion() -> void:
	tiempo_sin_atencion = 0.0
	_aviso_atencion_dado = false


func tiempo_reinicio(id: int) -> float:
	return TIEMPO_REINICIO_SERVIDOR.get(id, TIEMPO_REINICIO_INDIVIDUAL)


## Probabilidad real de que falle el reinicio de un rack ahora mismo.
func prob_fallo_actual(id: int) -> float:
	if prob_fallo_reinicio >= 1.0:
		return 1.0 # forzado (pruebas)
	var aumento := minf(PROB_FALLO_AUMENTO_MAXIMO, PROB_FALLO_POR_OLEADA * float(_contador_oleadas))
	var p: float = prob_fallo_reinicio + aumento + PROB_FALLO_EXTRA.get(id, 0.0)
	return clampf(p, 0.0, PROB_FALLO_MAXIMA)


## Primer servidor que espera verificacion en el PC (-1 si ninguno).
func siguiente_verificacion() -> int:
	if not activo:
		return -1
	for i in 3:
		if verificaciones_pendientes[i] > 0:
			return i
	return -1


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
	var p: float = clampf(servidores[id].progreso_reinicio / tiempo_reinicio(id), 0.0, 1.0)
	if p >= 1.0:
		_finalizar_reinicio(id)
	return p


## Reinicio general desde la terminal.
func reinicio_general() -> void:
	if not activo or apagon_restante > 0.0:
		return
	_usos_reinicio_general += 1
	for i in 3:
		verificaciones_pendientes[i] = 0
		autorizado[i] = false
		tipo_verificacion[i] = Verificacion.FLECHAS
		codigo_rack[i] = ""
	registrar_atencion()
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

	if corte_restante > 0.0:
		corte_restante = maxf(0.0, corte_restante - delta)
		if corte_restante <= 0.0:
			_log("[SYS] Energia restablecida. El PC vuelve a estar disponible.")
			emit_signal("corte_luz_terminado")
			registrar_atencion()

	# Durante un corte el analista no puede usar el PC: no cuenta como abandono.
	if corte_restante > 0.0:
		tiempo_sin_atencion = 0.0
	tiempo_sin_atencion += delta
	if tiempo_sin_atencion >= _limite_atencion:
		_abandonado = true
		_log("[CRITICO] Nadie atendio el ataque. Servicio dado por perdido.")
		_finalizar(false)
		return
	if not _aviso_atencion_dado and tiempo_sin_atencion >= _limite_atencion * AVISO_SIN_ATENCION:
		_aviso_atencion_dado = true
		_log("[ALERTA] Ataque sin atender. Abra Servidores en el PC.")
		emit_signal("aviso_abandono", _limite_atencion - tiempo_sin_atencion)

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
	if _temporizador_oleada <= 0.0 and tiempo_restante > minf(12.0, duracion_total * 0.2):
		_lanzar_oleada()

	if disponibilidad <= 0.0:
		_finalizar(false)
	elif tiempo_restante <= 0.0:
		_finalizar(true)


func _actualizar_oleadas(delta: float) -> void:
	for i in range(oleadas.size() - 1, -1, -1):
		oleadas[i].vida -= delta
		if oleadas[i].vida <= 0.0:
			if oleadas[i].vector == Vector.LEGITIMO and not oleadas[i].mitigada:
				puntaje += PUNTOS_LEGITIMA_IGNORADA
				_log("[OK] El flujo #%d era trafico legitimo. Buen criterio: no se aplico ninguna contramedida." % (oleadas[i].indice + 1))
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
			if ol.vector == Vector.LEGITIMO:
				continue # el trafico legitimo nunca genera carga real
			if id in ol.objetivos:
				var completo: bool = ol.mitigada and (ol.vector_extra == -1 or ol.mitigada_extra)
				var f: float = PRESION_MITIGADA if completo else 1.0
				presion += _presion_base * ol.intensidad * f

		if infectado[id]:
			presion += PRESION_INFECCION

		if presion > 0.0:
			s.carga = minf(CARGA_MAXIMA, s.carga + presion * delta)
		else:
			s.carga = maxf(0.0, s.carga - RECUPERACION_CARGA * delta)

		if s.carga >= CARGA_MAXIMA and s.online:
			_set_online(id, false)
			emit_signal("impacto_camara", 0.8)
			_log("[CRITICO] %s FUERA DE SERVICIO." % NOMBRE_SERVIDOR[id])


func _actualizar_disponibilidad(delta: float) -> void:
	var caidos := 0
	for s in servidores:
		if not s.online:
			caidos += 1

	var infectados := 0
	for i in 3:
		if infectado[i]:
			infectados += 1
	if infectados > 0:
		disponibilidad = maxf(0.0, disponibilidad - DRENAJE_INFECCION * infectados * delta)

	if caidos > 0:
		disponibilidad = maxf(0.0, disponibilidad - DRENAJE_POR_CAIDO * caidos * delta)
		puntaje += PUNTOS_POR_SEG_CAIDO * caidos * delta
	else:
		disponibilidad = minf(DISPONIBILIDAD_MAXIMA, disponibilidad + REGEN_DISPONIBILIDAD * delta)


# ================================================================ INTERNO

func _reset_estado() -> void:
	historial_log.clear()
	verificaciones_pendientes = [0, 0, 0]
	autorizado = [false, false, false]
	servidores.clear()
	for i in 3:
		servidores.append({
			"carga": 0.0,
			"online": true,
			"reiniciando": false,
			"progreso_reinicio": 0.0,
		})
	oleadas.clear()
	tiempo_restante = duracion_total
	tiempo_sin_atencion = 0.0
	_aviso_atencion_dado = false
	_abandonado = false
	_reinicios_fallidos = 0
	_secuencias_ok = 0
	_codigos_ok = 0
	_racha_max = 0
	tipo_verificacion = [0, 0, 0]
	codigo_rack = ["", "", ""]
	corte_restante = 0.0
	infectado = [false, false, false]
	_corte_dado = false
	_infeccion_dada = false
	# Se decide al empezar si habra cada evento (y en que oleada), para que la
	# probabilidad sea POR INCIDENTE y no por oleada.
	_corte_en_oleada = -1
	_infeccion_en_oleada = -1
	if duracion_total >= 45.0:
		if _rng.randf() < PROB_CORTE_LUZ:
			_corte_en_oleada = _rng.randi_range(OLEADA_CORTE_LUZ, OLEADA_CORTE_LUZ + 2)
		if _rng.randf() < PROB_INFECCION:
			_infeccion_en_oleada = _rng.randi_range(OLEADA_INFECCION, OLEADA_INFECCION + 2)
	_infecciones = 0
	_aislados = 0
	_cortes = 0
	disponibilidad = DISPONIBILIDAD_MAXIMA
	puntaje = 0.0
	cooldown_restante = 0.0
	alertas_en_cola = 0
	apagon_restante = 0.0
	_temporizador_oleada = _intervalo_oleada
	_contador_oleadas = 0
	_oleadas_mitigadas = 0
	_falsos_positivos = 0
	_usos_reinicio_general = 0
	_oleadas_legitimas = 0
	_oleadas_combinadas = 0


func _set_online(id: int, valor: bool) -> void:
	if servidores[id].online == valor:
		return
	servidores[id].online = valor
	emit_signal("servidor_estado_cambiado", id, valor)


func _finalizar_reinicio(id: int) -> void:
	servidores[id].reiniciando = false
	servidores[id].progreso_reinicio = 0.0
	servidores[id].carga = CARGA_TRAS_REINICIO

	# Reinicio fisico fallido (aleatorio). Si ya fue autorizado en el PC, sale bien.
	if not autorizado[id] and _rng.randf() < prob_fallo_actual(id):
		_reinicios_fallidos += 1
		var n: int
		if _rng.randf() < prob_codigo:
			# Verificacion por CODIGO: el rack muestra 4 digitos en su pantalla.
			tipo_verificacion[id] = Verificacion.CODIGO
			codigo_rack[id] = "%04d" % _rng.randi_range(0, 9999)
			n = 1
			_log("[ERROR] %s no arranco. Memorice el codigo de su pantalla e ingreselo en el PC > Servidores." % NOMBRE_SERVIDOR[id])
		else:
			tipo_verificacion[id] = Verificacion.FLECHAS
			codigo_rack[id] = ""
			var lista: Array = SECUENCIAS_AVANZADO if _contador_oleadas >= OLEADA_AVANZADA else SECUENCIAS_POSIBLES
			n = lista[_rng.randi_range(0, lista.size() - 1)]
			_log("[ERROR] %s no arranco. Autorice el reinicio en el PC > Servidores (%d secuencia%s) y vuelva al rack." % [
				NOMBRE_SERVIDOR[id], n, "" if n == 1 else "s"])
		verificaciones_pendientes[id] = n
		emit_signal("impacto_camara", 0.4)
		emit_signal("reinicio_fallido", id, n)
		return # el servidor sigue caido

	autorizado[id] = false
	_set_online(id, true)
	_log("[OK] %s restaurado." % NOMBRE_SERVIDOR[id])
	if id == Servidor.ALERTAS and alertas_en_cola > 0:
		_log("[ALERTA RECUPERADA] Se detectaron %d incidentes mientras el sistema estaba fuera de servicio." % alertas_en_cola)


func _lanzar_oleada() -> void:
	_temporizador_oleada = _intervalo_oleada
	var intensidad := minf(INTENSIDAD_MAXIMA, 1.0 + ESCALADA_POR_OLEADA * float(_contador_oleadas))

	var vector: int
	var vector_extra: int = -1

	var es_legitima := _contador_oleadas >= OLEADA_MINIMA_LEGITIMA and _rng.randf() < PROB_LEGITIMA
	if es_legitima:
		vector = Vector.LEGITIMO
		_oleadas_legitimas += 1
	else:
		vector = VECTORES_ATAQUE[_rng.randi_range(0, VECTORES_ATAQUE.size() - 1)]
		if _contador_oleadas >= OLEADA_MINIMA_COMBINADA and _rng.randf() < PROB_COMBINADA:
			vector_extra = VECTORES_ATAQUE[_rng.randi_range(0, VECTORES_ATAQUE.size() - 1)]
			while vector_extra == vector:
				vector_extra = VECTORES_ATAQUE[_rng.randi_range(0, VECTORES_ATAQUE.size() - 1)]
			_oleadas_combinadas += 1

	var objetivos: Array[int] = []
	var disponibles: Array[int] = [0, 1, 2]
	disponibles.shuffle()
	# A partir de la tercera oleada el ataque se reparte en dos servidores.
	var cantidad := 1 if _contador_oleadas < 2 else (2 if _rng.randf() < 0.6 else 1)
	for i in cantidad:
		objetivos.append(disponibles[i])

	var telemetria := _generar_telemetria(vector, intensidad)
	var telemetria_extra := {} if vector_extra == -1 else _generar_telemetria(vector_extra, intensidad)

	oleadas.append({
		"indice": _contador_oleadas,
		"vector": vector,
		"vector_extra": vector_extra,
		"objetivos": objetivos,
		"intensidad": intensidad,
		"mitigada": false,
		"mitigada_extra": false,
		"vida": _duracion_oleada,
		"telemetria": telemetria,
		"telemetria_extra": telemetria_extra,
	})

	var nombres: Array[String] = []
	for o in objetivos:
		nombres.append(NOMBRE_SERVIDOR[o])

	if es_legitima:
		_log("[TRAFICO] Pico de trafico hacia: %s (revisar antes de actuar)" % ", ".join(nombres))
	elif vector_extra != -1:
		_log("[TRAFICO] Ataque combinado hacia: %s (%s + %s)" % [", ".join(nombres), NOMBRE_VECTOR[vector], NOMBRE_VECTOR[vector_extra]])
	else:
		_log("[TRAFICO] Pico anomalo hacia: %s" % ", ".join(nombres))

	emit_signal("oleada_iniciada", _contador_oleadas, vector, objetivos, telemetria)
	_contador_oleadas += 1
	_sortear_eventos()


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
				"nota": "Peticiones GET validas y repetidas a /login. Mismo User-Agent en el 89 % del trafico.",
			}
		Vector.BOTNET:
			return {
				"paquetes_seg": int(base * 2.1 + _rng.randf_range(-2500, 2500)),
				"tamano_medio": "%d B" % _rng.randi_range(700, 1500),
				"porcentaje_syn": "%d %%" % _rng.randi_range(25, 45),
				"ips_origen": "%d k IPs residenciales reales" % _rng.randi_range(40, 90),
				"puerto_destino": "multiple",
				"handshakes_completados": "%d %%" % _rng.randi_range(55, 75),
				"nota": "Trafico mixto sostenido desde un unico rango autonomo AS%d." % _rng.randi_range(12000, 64000),
			}
		_: # Vector.LEGITIMO
			return {
				"paquetes_seg": int(7000 + _rng.randf_range(-1500, 1500)),
				"tamano_medio": "%d B" % _rng.randi_range(400, 900),
				"porcentaje_syn": "%d %%" % _rng.randi_range(3, 8),
				"ips_origen": "%d (rango corporativo conocido)" % _rng.randi_range(4, 12),
				"puerto_destino": "443/TCP",
				"handshakes_completados": "%d %%" % _rng.randi_range(96, 100),
				"nota": "Coincide con la ventana del respaldo nocturno programado. Sin senales de origen falsificado.",
			}


## Busca que oleada activa (y que parte de ella: principal o extra) resuelve
## la contramedida 'm'. Devuelve {idx:-1} si ninguna coincide (falso positivo).
func _buscar_objetivo_mitigacion(m: int) -> Dictionary:
	for i in oleadas.size():
		var ol: Dictionary = oleadas[i]
		if ol.vector == Vector.LEGITIMO:
			continue # nunca hay contramedida correcta para trafico legitimo
		if not ol.mitigada and CONTRAMEDIDA.get(ol.vector, -1) == m:
			return {"idx": i, "parte": "principal"}
		if ol.vector_extra != -1 and not ol.mitigada_extra and CONTRAMEDIDA.get(ol.vector_extra, -1) == m:
			return {"idx": i, "parte": "extra"}
	return {"idx": -1}


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
		"oleadas_legitimas": _oleadas_legitimas,
		"oleadas_combinadas": _oleadas_combinadas,
		"reinicios_fallidos": _reinicios_fallidos,
		"secuencias_ok": _secuencias_ok,
		"codigos_ok": _codigos_ok,
		"racha_max": _racha_max,
		"abandonado": _abandonado,
		"dificultad": nombre_dificultad,
		"cortes_luz": _cortes,
		"infecciones": _infecciones,
		"aislados": _aislados,
		"duracion_total": duracion_total,
		"tiempo_jugado": duracion_total - tiempo_restante,
	}
	# Registro de partidas: se compara contra las anteriores y se guarda.
	var previos := cargar_registro()
	var mejor := 0
	for r in previos:
		mejor = maxi(mejor, int(r.get("puntaje", 0)))
	resumen["mejor_anterior"] = mejor
	resumen["historial"] = previos.slice(maxi(0, previos.size() - 3))
	_guardar_registro(resumen, previos)

	_log("[FIN] Incidente cerrado. Disponibilidad final: %.0f %%" % disponibilidad)
	emit_signal("incidente_terminado", exito, resumen)


# ================================================================ REGISTRO

func cargar_registro() -> Array:
	if not FileAccess.file_exists(ARCHIVO_REGISTRO):
		return []
	var f := FileAccess.open(ARCHIVO_REGISTRO, FileAccess.READ)
	if f == null:
		return []
	var datos = JSON.parse_string(f.get_as_text())
	if datos is Array:
		return datos
	return []


func mejor_puntaje() -> int:
	var mejor := 0
	for r in cargar_registro():
		mejor = maxi(mejor, int(r.get("puntaje", 0)))
	return mejor


func _guardar_registro(resumen: Dictionary, previos: Array) -> void:
	var entrada := {
		"fecha": Time.get_datetime_string_from_system(false, true),
		"exito": resumen.exito,
		"puntaje": resumen.puntaje,
		"disponibilidad": int(resumen.disponibilidad_final),
		"oleadas": resumen.oleadas_totales,
		"mitigadas": resumen.oleadas_mitigadas,
		"falsos_positivos": resumen.falsos_positivos,
		"secuencias_ok": resumen.secuencias_ok,
		"abandonado": resumen.abandonado,
	}
	var lista := previos.duplicate()
	lista.append(entrada)
	if lista.size() > MAX_REGISTROS:
		lista = lista.slice(lista.size() - MAX_REGISTROS)
	var f := FileAccess.open(ARCHIVO_REGISTRO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(lista))


func _log(texto: String) -> void:
	historial_log.append(texto)
	if historial_log.size() > 80:
		historial_log.pop_front()
	emit_signal("log_terminal", texto)
