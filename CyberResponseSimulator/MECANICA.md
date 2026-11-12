# Mecánica DDoS – CyberResponseSimulator

## Flujo
1. Inicia el incidente (aleatorio vía IncidentFlowManager, o siempre en modo práctica).
2. Tres servidores (Alertas, Cámaras, Monitoreo) reciben oleadas de tráfico; la barra de **disponibilidad** baja.
3. En el PC (icono **Servidores**) se ve el monitor de red: flujo, protocolo, origen/destino y telemetría.
4. El jugador identifica el vector y aplica la contramedida correcta.
5. Si un rack cae, se reinicia **físicamente** en el rack. Puede fallar: entonces hay que ir al PC y superar la verificación (secuencia de flechas 1/2/3/5, o código de 4 dígitos mostrado en el rack) y volver a reiniciar.
6. Eventos aleatorios: **ransomware** (aislar el rack desde el PC) y **apagón** (6 s sin PC; usar racks físicos).
7. Fin: calificación S–D, retroalimentación, récord y últimas partidas.

## Comandos
| Acción | Cómo |
|---|---|
| Abrir monitor | Clic en icono Servidores |
| Mitigar | Botones SYN Cookies / Filtro UDP / Rate limit / Blackhole |
| Verificación | Flechas del teclado, o dígitos 0-9 para el código |
| Aislar rack infectado | Botón AISLAR en la tarjeta |
| Silenciar / efectos reducidos | M / N |

## Qué enseña cada vector
| Vector | Contramedida | Concepto |
|---|---|---|
| SYN flood | SYN Cookies | Agotamiento de conexiones semiabiertas (handshake TCP) |
| UDP / amplificación DNS | Filtro UDP | Reflexión y amplificación; spoofing de origen |
| HTTP flood | Rate limit | Límite de peticiones por cliente en capa 7 |
| Botnet masiva | Blackhole | Descartar tráfico a costa de disponibilidad (trade-off) |
| Tráfico legítimo (falsa alarma) | No bloquear | Distinguir pico legítimo de ataque; falsos positivos |
| Ataque combinado | Varias medidas | Defensa en profundidad |
| Ransomware | Aislar | Contención y segmentación |
| Apagón | Reinicio físico | Continuidad operativa y respaldo |
| Verificación de reinicio | Flechas / código | Autenticación/verificación antes de restaurar servicios |

## Balance (simulación con bots, Normal, 55 s)
Experto 96 % de victorias, Bueno 83 %, Novato 56 %.
