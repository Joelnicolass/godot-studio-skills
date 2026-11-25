---
name: godot-composition-first
description: >-
  Diseña escenas Godot 4 por composición: nodos hijos, packed scenes,
  FsmMachine, pases de FX, sockets @export tipados, %UniqueName, InputMap y
  el valor en el nodo que lo usa; Resources (.tres) solo para tipos que se
  comparten. Prioriza reutilizar componentes en shared/addons.
  Usar al crear o editar .tscn, GDScript, shaders (Godot Shaders / Shadertoy),
  sprites 2D (Aseprite MCP), fuentes pixel de imagen, modelos 3D (Blender MCP),
  materiales procedurales (Material Maker), FSM, HUD, controles táctiles
  (VirtualJoystick, TouchScreenButton, mirar arrastrando), o al decidir
  entre herencia, constantes, Resources e inspector.
---

# Godot — composición, editor y reuso

Acompañante de [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Esta skill decide **cómo se arma el árbol y los datos**.

Prioridad: simple y predecible, composición, nodos/editor, reuso. Convenciones de código, patrones y review: [godot-code-quality](../godot-code-quality/SKILL.md). Tests: [godot-testing](../godot-testing/SKILL.md).

## 1. Composición gana a herencia

El actor es un **contenedor delgado**: física + orquestación. El comportamiento vive en hijos.

```
Actor (CharacterBody2D o RigidBody2D)
├── Visual          Sprite2D / MeshInstance
├── Health          componente reusable
├── Hitbox/Hurtbox  Area2D packed scenes
├── States          FsmMachine
│   ├── Idle
│   ├── Move
│   └── Hurt
└── MultiplayerSynchronizer   # si hay red
```

- Estados = nodos `FsmState` bajo un `FsmMachine` (addon `fsm_kit`), no un `enum` + `match` de 200 líneas.
- Input es **otro nodo** (InputMap), no mezclado con física.
- Un FX nuevo es un hijo o packed scene, no un parámetro más en la superclase.

Herencia solo para el contrato mínimo (`FsmState extends Node`, `FxPass extends Control`). Si vas a `class EliteEnemy extends Enemy` con más sistemas, paramá: componé.

## 2. Sockets `@export` y `%UniqueName`

Entre componentes / escenas: **socket tipado**, no path frágil.

```gdscript
@export var health: Health
```

El padre (o el inspector) asigna la referencia. El hijo no hace `get_node("../../Health")`.

Dentro de **esta** escena: `%UniqueName` — `@onready var sprite: Sprite2D = %Sprite2D`.

Si el socket es obligatorio y está vacío: `@tool` + `_get_configuration_warnings()` (el inspector avisa; no esperes al `assert` en `_ready`).

## 3. Nodos y editor ganan al código

El `.tscn` y el inspector son la fuente de verdad del **look, layout y tunables de instancia**. «Editor first» = el valor vive **en el nodo que lo usa**, a la vista en el inspector; no un `.tres` ni un puntero intermedio para cada cosa (regla 0 de [godot-code-quality](../godot-code-quality/SKILL.md)). Si cambiar un número exige abrir más de 2 archivos, el diseño está mal.

Hacer: `@export` / `@export_group` / `@export_range`; default en la escena; el script **no** pisa el valor guardado.

No hacer: `_ready` que copie reglas de ronda sobre un `@export` de apariencia; un dump de 80 floats de shader en un autoload; un tag o texto que apunta a otro recurso.

Reglas de ronda: `@export` en el nodo `Match`. Si tweakeás el look en play y lo perdés al recargar, el knob estaba mal.

Motion / juicy: [godot-animation](../godot-animation/SKILL.md) y [godot-juicy](../godot-juicy/SKILL.md). Tween **o** `AnimationPlayer` según el clip; knobs en el inspector. Los 12 principios aplican igual. FSM: [godot-fsm](../godot-fsm/SKILL.md). Plataformas 2D: [godot-platformer-2d](../godot-platformer-2d/SKILL.md).

## 3.1 Resources de datos = tipos que se comparten

Un `.tres` de **datos** existe si **varias cosas lo comparten** o si **se edita como tipo**: `class_name XData extends Resource` + un `.tres` por variante. Una escena `projectile.tscn`; `projectile_fast.tres` / `projectile_slow.tres` en `@export var data`. Un valor que usa una sola escena es un `@export` del nodo, no un `.tres`.

Esa regla es para datos. El **look** (un material, un `Environment`, un tema, una textura procedural) es un asset: siempre un archivo con nombre (`stone.tres`, `world_env.tres`), aunque lo use una sola escena, y nunca un sub-recurso dentro de una escena de cableado (el mundo, `Main`). La carpeta la decide RULES.md ([godot-code-quality](../godot-code-quality/SKILL.md) §1).

Un Resource cuyo único contenido es un `Dictionary` o un `Array` (nombre → material, una lista de materiales por sprite) no es un tipo que alguien edite: es una tabla de búsqueda disfrazada. Cada elemento es su propio archivo, o un `@export` en el nodo que lo usa.

HP actual en el nodo. No mutar el `.tres` (`duplicate()` si hace falta copia). Guía: [resources.md](resources.md).

## 4. InputMap

Acciones semánticas en Project Settings → Input Map: `move_left`, `attack`, `pause`. No `KEY_A` / `press_shift`.

- Movimiento continuo / hold: `_physics_process` + `Input.get_vector(...)`.
- One-shot de gameplay (salto, ataque): `_unhandled_input` (la UI ya pudo consumir el evento).
- `_input` solo para interceptar (pausa, remap).
- Celular o tablet: `VirtualJoystick` y `TouchScreenButton` aprietan las mismas acciones; el juego no lee toques. Mostrarlos solo en teléfonos, mirar arrastrando en 3D y acciones de un toque: [touch.md](touch.md).

El catcher de input llama `apply_*` (en red, el `MpInput` del actor manda las acciones y el servidor aplica); no spawnea ni puntúa.

## 5. Reuso

Antes de escribir un script en `features/` o `scenes/`:

1. ¿Existe en `shared/` o `addons/`?
2. Segundo caller → nace en `shared/` o `addons/`, no fork por título.
3. API: signals en pasado + `@export`. Cero puntaje ni copy de producto.

| Pieza | Forma reusable |
|-------|----------------|
| FSM | addon `fsm_kit`: `FsmMachine` + `FsmState`; el actor se inyecta (`@export var actor`) |
| Plataformas 2D | addon `plat_kit`: `PlatMotor` (coyote, buffer, apex). Dash/stamina = glue |
| Salud / hit | `Health` + Hitbox/Hurtbox packed scenes |
| Post-proceso | stack CanvasLayer; **un pass = una packed scene** |
| Autoridad / sync | `MpAuthority` (addon) |
| Copy de UI | módulo de strings |
| Tipos compartidos | Resource + `.tres` |

Un pass (bloom, grain, distorsión) = `BackBufferCopy` + `ColorRect` + shader propio. El stack no conoce el juego. Un pickup no mete lógica dentro del shader de otro pass: tweenea **ese** pass.

Shaders: un efecto, un archivo. **No inventes** el FX si hay catálogo: [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) primero; [Shadertoy](https://www.shadertoy.com) si hay que portar. Guía: [assets.md](assets.md).

Sprites 2D: **preguntá** si quiere MCP/sprites y pedí **referencias**. Skill [godot-animation](../godot-animation/SKILL.md). Si dice que sí: MCP [Aseprite](https://github.com/diivi/aseprite-mcp) ([assets.md](assets.md)). Si no: placeholder. No un sprite inventado.

3D: **preguntá** si quiere el MCP de [Blender](https://www.blender.org/lab/mcp-server/). Si sí: instalalo, pedí referencias, y el modelo entra como `.blend` directo o como `.glb`. Si no: placeholder. Detalle en [assets.md](assets.md).

Materiales / texturas (piso, pared, terreno, tile 2D): **preguntá** si quiere crearlos con [Material Maker](https://github.com/RodZill4/material-maker) y pedí referencias. Cada superficie es un `.tres` que se elige en el inspector; en un modelo importado, en su import: **Advanced…** › el material › **Use External** con la ruta del `.tres`, no por código ni por el nombre del slot al correr. Skill [godot-material-maker](../godot-material-maker/SKILL.md).

## 6. Cómo implementar un componente

1. Packed scene chica + `class_name`.
2. Knobs `@export`. Warnings si falta un socket.
3. El feature **instancia** el componente en la escena. No `load` shaders a mano desde el mundo. Un componente reusable dueño de su shader (como `Sprite3D` con el suyo) sí puede hacer `preload` y armar su material, con los knobs como `@export` del componente.
4. Señales del propio nodo; el padre conecta. El bus `Events` solo para sistemas que no se conocen. El pass FX no llama a la sesión.
5. Variante por jugador (tint): método público, no lee IDs internos.

## 7. Preview en el editor

Abrir la escena en el editor muestra el juego como se ve al correr: materiales, props, el tablero. Lo que solo existe al correr se tunea a ciegas.

- Un componente de look (arma mallas, coloca props, aplica un material) es `@tool`. Un `@export` con setter que lo reconstruye muestra el cambio en el editor.
- Lo generado no se guarda en la escena: los hijos que agrega quedan sin `owner`, y una propiedad generada sale del guardado con `_validate_property` (sin `PROPERTY_USAGE_STORAGE`).
- La lógica de juego (input, timers, señales de la partida) no corre en el editor: cortala con `Engine.is_editor_hint()` en `_ready` y `_process`. La preview sí corre.
- Lo procedural lleva un `@export var preview_seed`, así el editor muestra un resultado fijo.

## Anti-patrones

- God-node `World.gd` que dibuja FX, spawnea, puntúa y cambia de escena.
- `match kind` gigante en el actor.
- Duplicar un shader “un poquito distinto” en dos features.
- Collision layers distintos en código y en el inspector.
- Hijos 100% en código cuando una packed scene los haría editables.
- Mutar el `.tres` de tipo en runtime.
- Un `.tres` de datos que usa una sola escena, o que apunta a otro por tag o texto.
- Un Resource que solo es un `Dictionary` o un `Array` (nombre → recurso).
- Materiales o un `Environment` embebidos como sub-recursos en la escena del mundo.
- Un look que solo existe al correr: materiales asignados en `_ready`, props creados por código sin preview.

## Checklist

- [ ] ¿Se apaga el comportamiento sacando un hijo?
- [ ] ¿Se tunnea en el inspector, en el nodo que usa el valor? ¿Cambiar un número abre como mucho 2 archivos?
- [ ] ¿Sockets `@export` / `%UniqueName` en vez de paths `../..`?
- [ ] ¿InputMap, no scancodes?
- [ ] ¿Variantes que se comparten = Resources; un valor de una sola escena = `@export`?
- [ ] ¿Cada material, `Environment` y tema es un archivo con nombre?
- [ ] ¿Abro la escena en el editor y se ve como en el juego (materiales, props)? ¿Qué parte del look solo existe al correr, y por qué?
- [ ] ¿La escena corre con F6?
- [ ] ¿Shader de catálogo o port documentado? ¿Sprite 2D: OK del usuario + referencias + Aseprite, o placeholder? ¿3D: OK + Blender MCP + `.blend` o `.glb`, o placeholder?

Patrones: [patterns.md](patterns.md). Resources: [resources.md](resources.md). Assets: [assets.md](assets.md). Código: [examples.md](examples.md).
