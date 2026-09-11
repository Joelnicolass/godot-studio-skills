---
name: godot-layered-architecture
description: >-
  Aplica arquitectura en capas para juegos Godot 4 (GDScript): domain RefCounted
  sin Node, core autoloads, features como nodos/escenas. Prioriza capas
  escalables, composición, configuración en el editor y componentes reutilizables.
  Usar al crear o modificar un proyecto Godot, GDScript, escenas, reglas de
  partida, MatchSession/GameSession, GameEvents, features, HUD o al arrancar un
  juego nuevo con esta base.
---

# Godot — arquitectura en capas

Base extraída de un listen-server 1P/LAN (Godot 4, GDScript). El juego de origen es solo el ejemplar: los nombres (`MatchSession`, `GameEvents`) se adaptan; las capas no.

Siempre cargar también [godot-composition-first](../godot-composition-first/SKILL.md). Si hay red, LAN, RPC o `MpKit`, cargar [godot-mp-kit](../godot-mp-kit/SKILL.md).

## Prioridades (siempre)

Siempre se priorice:

- arquitectura facil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes

Operación (sin excepciones de conveniencia):

| Prioridad | Significa en código |
|-----------|---------------------|
| Capas limpias | Dependencias solo hacia adentro. Una feature nueva no “ataja” reglas en el nodo. |
| Composición | Escena = árbol de componentes. No una superclase de 800 líneas. |
| Editor | Knobs de look/feel en `@export` y en el `.tscn`. No pisar el inspector desde constantes en `_init`/`_ready`. |
| Reuso | Extraer a `src/shared/` (o `addons/`) en cuanto un segundo caller lo necesite. Copiar-pegar un pass/FX/util es un fallo. |

## Capas

```
features (Nodes, .tscn, física, RPCs de pawn, spawners)
    → core (autoloads: sesión, eventos, director de escenas, glue de red)
        → domain (RefCounted: reglas de partida)
```

```
src/
  core/autoload/     # GameConstants, GameEvents, GameSession, SceneDirector
  domain/            # trackers y resolvers puros
  features/<name>/   # una carpeta por feature: scripts + escenas juntas
  shared/            # Wrap, StateMachine, PostFx, copy, utils sin reglas
addons/              # MpKit y otros plugins (cero gameplay)
```

Nombres genéricos: `GameSession` (fachada), `GameEvents` (bus), `SceneDirector` (flow). En el ejemplar: `MatchSession`.

### Domain (`src/domain/`)

- `extends RefCounted` (o `class_name` sobre RefCounted). Se instancia con `new()`.
- Prohibido: `Node`, `Input`, `MultiplayerAPI`, `get_tree()`, `@rpc`, `await` de señales de escena.
- Recibe números por constructor. Los tests no leen autoloads.
- No sabe si hay red ni si hay HUD.

Ejemplos de unidades: reloj, puntaje, combo, vidas, cooldowns, “¿quién gana?”.

### Core

- **GameSession**: arma trackers por slot, `start` / `abort`, `submit_*`, `to_snapshot` / `apply_snapshot`. El cliente **apaga** el tick (`set_process(false)`) al aplicar snapshot.
- **GameEvents**: bus de signals para HUD/FX. Los nodos escuchan; no leen score crudo de la nave.
- **SceneDirector**: cambia de escena. No puntúa.
- **GameConstants**: únicos tunables de **negocio y física de reglas** (duración, vidas, layers, impulso máximo). No es un dumping de look.

1P es un host local de un jugador: misma sesión que 2P. No dupliques reglas “para solo”.

### Features

Nodos Godot. Pueden tener `@rpc`, física, spawners. **No** guardan puntaje/vidas/timer en variables sueltas del pawn.

UI en el idioma del producto; identificadores de código en inglés.

### Shared

Utilidades y componentes de escena sin reglas de partida. Si un FX, wrap, FSM o pass sirve en otro feature o juego, vive acá (o en un addon), no dentro de `features/arena/`.

## Constantes vs inspector

- Regla de partida / anti-cheat / física de negocio → `GameConstants` (un literal, un lugar).
- Apariencia, audio-react, shaders, offsets visuales, “cómo se siente este nodo en esta escena” → `@export` en el componente; el valor canónico es el del editor (`.tscn`).
- Prohibido: `_copy_defaults_from_constants()` que pise `@export` de look en runtime.

Detalle y patrones de escena: [godot-composition-first](../godot-composition-first/SKILL.md).

## Cómo agregar una feature

Antes de codear, clasificar. Si no entra en una caja, no empieces por el sprite.

| Tipo | Dueño | Ejemplos |
|------|--------|----------|
| **A. Input** | Cada cliente lee control local; el host aplica | swipe, botón disparar |
| **B. Simulación** | Solo host spawnea, mueve, colisiona | proyectil, enemigo |
| **C. Estado de partida** | `GameSession` / domain | munición, combo, cooldown |
| **D. Presentación local** | Cada máquina, sin RPC de daño | flash, CRT, partículas |
| **E. UI** | HUD / menús | icono de cooldown |

Checklist y pipeline de input: [adding-features.md](adding-features.md).

## IDs

Dos espacios. Mezclarlos es un bug.

- **Slot lógico** (1 = anfitrión / jugador solo, 2..N = invitados): key de score, vidas, HUD.
- **Peer ENet** (1 = servidor; el cliente puede ser 42 y al rejoin 87): solo para RPC y `set_multiplayer_authority`.

HUD local: `MpKit.local_slot()`, nunca `multiplayer.get_unique_id()`.

## Anti-patrones

- Puntaje o vidas en el pawn / `World.gd` dios.
- `rpc()` dentro de un tracker de dominio.
- Cliente que tiquea el reloj o spawnea actores de simulación.
- Feature nueva como subclase profunda en vez de nodos hijos + signals.
- Literales de negocio (`60`, `3`, `7777`) copiados en features.
- Copiar un shader/pass/util a otra feature en vez de extraerlo a `shared/`.

## Checklist de cambio

- [ ] ¿La regla es testeable sin escena? → domain primero.
- [ ] ¿El nodo solo llama `GameSession.submit_*` y escucha `GameEvents`?
- [ ] ¿Look/feel está en `@export` / escena, no pisado por código?
- [ ] ¿El componente nuevo es componible (hijo, packed scene, pass) y no un `if genre ==` en una clase existente?
- [ ] ¿1P usa el mismo camino que el host LAN?
- [ ] Si hay red: allowlist `submit_*`, autoridad host, ver skill MpKit.
