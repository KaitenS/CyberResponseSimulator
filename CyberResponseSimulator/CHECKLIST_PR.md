# Checklist antes del Pull Request
- [ ] `forzar_incidente` vacío en el Inspector de IncidentFlowManager (nodo del Game).
- [ ] `DDoSEnMapa.modo_practica` solo se activa desde el botón del menú.
- [ ] Sin `print` de depuración ni ajustes de prueba.
- [ ] Carpetas duplicadas (Windows no distingue mayúsculas): `scripts/Incidents/ddos` vs `DDOS`, `scenes/ddos`.
      Dejar solo `DDOS`: `git mv scripts/Incidents/ddos tmp_x` → `git mv tmp_x scripts/Incidents/DDOS` (dos pasos), mover archivos sobrantes y `git rm` los duplicados. Revisar que Godot no pierda referencias.
- [ ] Probar: jugar normal, práctica, perder + reintentar, ganar.

## Borrador de descripción
**Mecánica DDoS completa**
- Ventana de Servidores dentro del PC (clic fiable), verificación de reinicio (flechas/código), recompensas y combos.
- Dificultad, ransomware, apagón, accesibilidad (M/N), modo práctica, reintentar/reiniciar, registro de partidas.
- Docs en docs/.

**Archivos de compañeros modificados (revisar):** `scripts/Game/ui/CyberDesk.gd`, `scripts/Managers/IncidentFlowManager.gd`, `scripts/Menu/MainMenu.gd`.
**Cómo probar:** menú → Practicar DDoS.
