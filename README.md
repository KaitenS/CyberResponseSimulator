
<h1 align="center">
  CyberResponse Simulator
</h1>

<p align="center">
  <img src="./Assets/BANNER.gif" width="500">
</p>

---

## 📌 Descripción

**[CyberResponse Simulator]** es un simulador educativo desarrollado con el objetivo de enseñar los fundamentos de la respuesta ante incidentes de ciberseguridad mediante escenarios interactivos basados en situaciones reales.

El proyecto está dirigido principalmente a estudiantes, personas interesadas en la ciberseguridad y organizaciones que buscan capacitar a nuevos analistas, y busca resolver el problema de la falta de experiencia práctica en la toma de decisiones durante un incidente de seguridad, ofreciendo un entorno seguro donde los usuarios pueden identificar amenazas, analizar información y aplicar procedimientos de respuesta sin poner en riesgo una infraestructura real.

### 🎯 Objetivos principales

- Simular incidentes comunes de ciberseguridad en un entorno interactivo.
- Enseñar el proceso de identificación, análisis y respuesta ante amenazas.
- Desarrollar la capacidad de tomar decisiones bajo presión.
- Facilitar el aprendizaje mediante una experiencia práctica y entretenida.

---

## 🛠️ Tecnologías utilizadas

### Motor de desarrollo

- Godot Engine 4

### Lenguajes

- GDScript

### Modelado y diseño

- Blender
- Blockbench

### Control de versiones

- Git
- GitHub

### Herramientas

- Visual Studio Code
- Libresprite

---

## 🚀 Instalación y ejecución

### 📋 Requisitos previos

**Queda pendiente**

---

## 👥 Equipo de desarrollo

| Integrante | Rol Scrum | Rol dentro del Proyecto |
|------------|------------|-------------------------|
| Benjamin Salinas | Product Owner | Líder del proyecto, Programador, Modelado 3D, Desarrollo del Gameplay y coordinación del equipo |
| Alexander Carrasco | Scrum Master | Programador, Modelado 3D, Diseño de escenarios, coordinación de Sprints y apoyo en la organización del proyecto |
| Alejandro Álvarez | Developer | Programador, Modelado 3D, Testing, documentación y desarrollo de funcionalidades |

# 📋 Metodología de trabajo

El desarrollo del proyecto sigue una metodología **Scrum**, organizando el trabajo mediante iteraciones cortas (Sprints) para entregar avances funcionales de manera continua.

Para la gestión del proyecto se utilizan las siguientes prácticas:

- Planificación de tareas por Sprint.
- División del trabajo según especialidad de cada integrante.
- Control de versiones mediante Git y GitHub.
- Reuniones periódicas para revisar avances y resolver problemas.
- Desarrollo incremental del MVP.

---

# 🏗️ Arquitectura de la solución

CyberResponse Simulator utiliza una arquitectura modular basada en escenas de Godot Engine.

```text
                   Usuario
                      │
                      ▼
               Interfaz (UI/HUD)
                      │
                      ▼
             Gestor del Juego (Game Manager)
          ┌───────────┼───────────┐
          ▼           ▼           ▼
     Sistema de   Sistema de   Sistema de
     Incidentes    Objetivos     Puntuación
          │           │           │
          └───────────┼───────────┘
                      ▼
             Escenario de Oficina
                      │
                      ▼
              Recursos del Proyecto
       (Modelos, Audio, Scripts, UI)
```

### Componentes principales

- **Interfaz (UI):** Presenta la información al jugador y recibe sus acciones.
- **Game Manager:** Controla el flujo general del simulador.
- **Sistema de Incidentes:** Gestiona los eventos de phishing, malware y DDoS.
- **Sistema de Objetivos:** Lleva el seguimiento de las tareas del jugador.
- **Sistema de Puntuación:** Evalúa el desempeño según las decisiones tomadas.
- **Escenario:** Representa la oficina virtual donde se desarrolla la simulación.
