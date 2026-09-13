---
name: godot-layered-architecture
description: >-
  Elige y aplica arquitectura Godot 4 (GDScript): Clean en capas (domain
  RefCounted, core autoloads, features) o estándar por escenas y scripts
  pequeños. Siempre pregunta al usuario cuál usar. Prioriza composición,
  Resources (.tres) para tipos de balas/enemigos/power-ups, editor y
  componentes reutilizables. Usar al crear o modificar un proyecto Godot,
  GDScript, escenas, reglas de partida, GameSession, GameEvents, features,
  HUD o al arrancar un juego nuevo.
---

# Godot — arquitectura

Base para juegos Godot 4 (GDScript). Hay **dos estilos** válidos. El agente **no asume Clean**.

Siempre cargar también [godot-composition-first](../godot-composition-first/SKILL.md) (incluye Resources). Si hay red: [godot-mp-kit](../godot-mp-kit/SKILL.md). Un título nuevo o un RFC de feature: [godot-studio-workflow](../godot-studio-workflow/SKILL.md) (el chat principal orquesta commands y subagentes).

## Prioridades (siempre)

Siempre se priorice:

- arquitectura facil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes

En el camino **estándar**, “capas” no significa carpetas `domain/core/features`. Significa scripts chicos, una responsabilidad por pieza, y composición de nodos/Resources. La excepción es solo la división Clean; el resto de lineamientos **no se relaja**.

## 1. Elegir estilo (obligatorio)

**Preguntar siempre** al usuario, con AskQuestion si está disponible, **antes** de crear carpetas, autoloads o una feature que fije la forma del proyecto.

Opciones:

1. **Clean / en capas** — `features → core → domain`. Reglas en `RefCounted` sin `Node`. Fachada de sesión + eventos. Ver [clean.md](clean.md).
2. **Estándar Godot** — escenas + scripts junto a la escena, sin capas domain/core. Misma calidad de código. Ver [standard.md](standard.md).

Prompt sugerido:

> ¿Qué arquitectura querés para este proyecto / este cambio?
> - Clean (domain / core / features)
> - Estándar (escenas y scripts; sin capas Clean)

No preguntar de nuevo si: el usuario ya eligió en este chat; pidió un estilo por nombre; o el repo **ya lo declara** (AGENTS.md / README) **y** el trabajo es sobre ese mismo juego (no un título nuevo).

Si el usuario no responde aún, **no** scaffoldear `src/domain/` ni un `scripts/` gigante: esperar.

## 2. Lineamientos comunes (los dos caminos)

| Prioridad | En código |
|-----------|-----------|
| Composición | Árbol de nodos + packed scenes. No superclase de 800 líneas. |
| Editor | Knobs en `@export` y `.tscn`. No pisar el inspector en `_init`/`_ready`. |
| Resources | Tipos de bala / enemigo / power-up / arma = `class_name` + `.tres` plantilla. Una escena, muchos datos. Ver [resources.md](../godot-composition-first/resources.md). |
| Reuso | Extraer a `shared/` o `addons/` al segundo caller. |
| Scripts chicos | Una responsabilidad. Si crece, hijo o componente, no “un if más”. |
| Señales | Hijo → padre con signals. Padre llama API del hijo. Entre sistemas no relacionados: bus de eventos, no `get_node("../../")`. |

Autoloads solo para servicios de verdad globales (eventos, audio, cambio de escena, MpKit). Un spawner o el puntaje de *esta* partida no es un singleton eterno.

UI en el idioma del producto; identificadores de código en inglés.

## 3. Datos: qué va dónde

| Cosa | Dónde |
|------|--------|
| Catálogo de tipos (plasma vs spread, grunt vs tank, slow-time vs shield) | **Resource** `.tres` (plantilla). Una clase de datos, N archivos. |
| Look de *esta* instancia en *esta* escena | `@export` en el nodo / material |
| Reglas de partida compartidas host/guest (duración, vidas, layers) | Clean: `GameConstants` o un `MatchRules.tres`. Estándar: un Resource de reglas o constantes únicas — no literales copiados. |
| HP actual, cooldown en curso, combo | Estado **runtime** en el nodo o tracker; **no** mutar el `.tres` de definición |

## 4. Cómo agregar una feature

Clasificar antes del sprite. Checklist: [adding-features.md](adding-features.md).

| Tipo | Dueño | Ejemplos |
|------|--------|----------|
| **A. Input** | Cliente lee; host aplica | puntero, disparar |
| **B. Simulación** | Solo host si hay red | proyectil, enemigo |
| **C. Estado de partida** | Clean: sesión/domain. Estándar: nodo de match chico, no el World dios | munición, combo |
| **D. Presentación** | Local, sin RPC de daño | flash, post-proceso |
| **E. UI** | HUD / menús | icono cooldown |
| **F. Definición de tipo** | Resource plantilla | `plasma.tres`, `grunt.tres` |

## 5. IDs (si hay multiplayer)

- **Slot lógico**: key de score/vidas/HUD.
- **Peer ENet**: solo RPC y authority.

HUD: `MpKit.local_slot()`, nunca `get_unique_id()`.

## Anti-patrones (ambos caminos)

- `World.gd` / `Arena.gd` que pinta, spawnea, puntúa y cambia de escena.
- `if bullet_kind == "plasma"` en el proyectil en vez de un `.tres`.
- Mutar un Resource compartido (`data.damage = 3`) y romper todas las instancias.
- Feature nueva por herencia profunda.
- Literales de negocio copiados (`60`, `3`, `7777`).
- Copiar un componente en vez de extraerlo.

Ejemplos de código genéricos: [examples.md](examples.md).
