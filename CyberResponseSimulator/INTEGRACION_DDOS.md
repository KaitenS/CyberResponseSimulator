# Mecanica DDoS — integración en CyberResponseSimulator

Estos son únicamente los archivos de la mecánica de **Ataque DDoS**. No tocan nada del proyecto de tus compañeros: viven en su propia subcarpeta para evitar choques de nombres (varios seguramente van a tener su propio `terminal.gd`, `hud.gd`, etc. para su ataque asignado).

## 1. Dónde va cada cosa

Copia estas carpetas dentro de `CyberResponseSimulator/CyberResponseSimulator/` (la carpeta del proyecto Godot en sí, la que tiene `project.godot`):

```
CyberResponseSimulator/
└─ CyberResponseSimulator/
   ├─ scripts/
   │   └─ ddos/              <- pega aquí los 7 .gd (+ sus .uid)
   └─ scenes/
       └─ ddos/              <- pega aquí servidor_fisico.tscn
```

Si `scripts/` o `scenes/` ya tienen subcarpetas de otros compañeros (por ejemplo `scripts/phishing/`), no pasa nada — la tuya (`ddos/`) queda al lado, sin interferir.

## 2. Autoloads a registrar

Este proyecto ya tiene autoloads propios del equipo. **No borres los que ya existan** — solo añade estos dos, en Proyecto → Configuración del Proyecto → Globales:

| Nombre del nodo | Ruta |
|---|---|
| `IncidenteDDoS` | `res://scripts/ddos/incidente_ddos.gd` |
| `AudioDDoS` | `res://scripts/ddos/audio_ddos.gd` |

⚠️ Antes de añadirlos, revisa que ningún compañero ya haya usado esos mismos nombres para su propio sistema. Si hay choque de nombre, avísales — cada autoload debe ser único en todo el proyecto.

## 3. Acción de entrada compartida

Si el proyecto ya tiene una acción de interacción genérica (por ejemplo `interact`), **reutilízala** en vez de crear `interactuar` — mis scripts la llaman así:

- En `player.gd` (el que sea, el del equipo), la función que revisa el objeto mirado debe llamar a `Input.is_action_pressed("interactuar")` y `Input.is_action_just_pressed("interactuar")`.
- Si el equipo ya usa otro nombre de acción, cambia esas dos líneas dentro de `servidor_fisico.gd`... en realidad esas líneas viven en el script del **jugador**, no en los míos — mis scripts (`servidor_fisico.gd`, etc.) solo exponen funciones (`mantener_interaccion`, `soltar_interaccion`, `texto_prompt`) para que el jugador las llame. Coordina con el dueño de `player.gd` para conectar estas piezas.

## 4. Qué necesita tu escena de nivel

En la escena donde va a vivir el ataque DDoS (probablemente una oficina o sala de servidores):

1. **Tres instancias de `scenes/ddos/servidor_fisico.tscn`**, una por servidor. En cada una, en el Inspector, cambia `Id Servidor` a `Alertas`, `Camaras` y `Monitoreo` respectivamente.
2. **Un `CanvasLayer`** con el script `scripts/ddos/terminal_mitigacion.gd`.
3. **Un `CanvasLayer`** con el script `scripts/ddos/hud_ddos.gd`.
4. **Un `CanvasLayer`** con el script `scripts/ddos/pantalla_resultado.gd`.
5. **Un `Node`** con el script `scripts/ddos/disparador_ddos.gd` (ajusta `Retardo Segundos` a cuándo quieres que llegue el ataque).
6. **Un objeto físico** (escritorio, PC, lo que sea) con colisión, metido en el **grupo** `terminal_ddos` — así el jugador puede abrir la consola parado frente a él.

## 5. Conexión con el jugador

Quien mantenga `player.gd` necesita:

- Un `RayCast3D` colgando de la cámara, para detectar a qué objeto mira el jugador.
- Dos variables exportadas: `terminal` (tipo `TerminalMitigacion`) y `resultado` (tipo `PantallaResultado`), asignadas arrastrando los `CanvasLayer` correspondientes.
- En el bucle de interacción: si el objeto mirado es `ServidorFisico`, llamar a `mantener_interaccion(delta)` mientras se mantiene la tecla, y `soltar_interaccion()` al soltarla. Si está en el grupo `terminal_ddos`, llamar a `terminal.abrir()` al presionar la tecla una vez.
- Bloquear movimiento y liberar el mouse mientras `terminal.abierta` o `resultado.abierta` sean `true`.

Si quieres, puedo darte ese fragmento de `player.gd` ya armado para pegar en el script del equipo — pero como no lo he visto, prefiero no tocarlo a ciegas y romper el trabajo de otra persona.

## 6. Flujo de Git recomendado (proyecto compartido)

```
git checkout -b feature/ddos-mitigacion
# copia las carpetas scripts/ddos y scenes/ddos dentro del proyecto
git add scripts/ddos scenes/ddos
git commit -m "Agrega mecanica de ataque DDoS (oleadas, mitigacion, HUD, audio)"
git push origin feature/ddos-mitigacion
```

Y abre un Pull Request en vez de subir directo a `main`, para que el resto del equipo revise antes de fusionar — sobre todo por los autoloads y la acción de entrada, que son las dos cosas que sí pueden chocar con el trabajo de otros.

Revisa también que el `.gitignore` del repo ya excluya `.godot/` (la carpeta de caché del editor) — si no lo hace, avísale al equipo, porque esa carpeta no debería subirse nunca a un repo compartido: es pesada, específica de cada máquina, y se regenera sola.
