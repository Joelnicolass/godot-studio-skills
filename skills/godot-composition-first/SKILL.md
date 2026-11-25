---
name: godot-composition-first
description: >-
  Diseña escenas Godot 4 por composición: nodos hijos, packed scenes,
  FsmMachine, pases de FX, referencias @export tipadas, %UniqueName, InputMap,
  un dueño por número, Resources de tipo (.tres), catálogos, escenas
  heredadas y preview en el editor. Prioriza reutilizar componentes en
  shared/addons.
  Usar al crear o editar .tscn, GDScript, shaders (Godot Shaders / Shadertoy),
  sprites 2D (Aseprite MCP), fuentes pixel de imagen, modelos 3D (Blender MCP),
  materiales procedurales (Material Maker), FSM, HUD, controles táctiles
  (VirtualJoystick, TouchScreenButton, mirar arrastrando), o al decidir
  entre herencia, constantes, Resources e inspector.
---

# Godot — composición, editor y reuso

Acompañante de [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Esta skill decide **cómo se arma el árbol y los datos**.

Prioridad: simple y predecible, composición, nodos y editor, reuso. Dónde vive cada número, carpetas, patrones y review: [godot-code-quality](../godot-code-quality/SKILL.md). Tests: [godot-testing](../godot-testing/SKILL.md).

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

## 2. Referencias `@export` y `%UniqueName`

Entre componentes o escenas: una **referencia tipada**, no una ruta frágil.

```gdscript
@export var health: Health
```

El padre (o el inspector) asigna la referencia. El hijo no hace `get_node("../../Health")`.

Dentro de **esta** escena: `%UniqueName` — `@onready var sprite: Sprite2D = %Sprite2D`.

Si la referencia es obligatoria y está vacía: `@tool` + `_get_configuration_warnings()` (el inspector avisa; no esperes al `assert` en `_ready`).

## 3. Nodos y editor ganan al código

El `.tscn` y el inspector son la fuente de verdad del **look, la disposición y las perillas**. Dónde vive cada número (un dueño: el tipo o la raíz), cuándo existe un `.tres` y qué es un catálogo: regla 0 de [godot-code-quality](../godot-code-quality/SKILL.md). Cada perilla de diseño tiene su fila en `docs/tuning.md`.

Hacer: `@export` / `@export_group` / `@export_range` con unidad y un `##`; el valor por defecto en la escena; el script **no** pisa el valor guardado.

No hacer: un `_ready` que copie reglas de partida sobre un `@export` de apariencia; un volcado de 80 floats de shader en un autoload; un color o un número de diseño escrito en el código.

Para ajustar con el juego corriendo: editá la escena local (no el árbol *Remote*) con *Debug › Synchronize Scene Changes* activo. El cambio se ve en el juego y queda guardado; lo que se toca en *Remote* se pierde.

Motion / juicy: [godot-animation](../godot-animation/SKILL.md) y [godot-juicy](../godot-juicy/SKILL.md). Tween **o** `AnimationPlayer` según el clip; las perillas y la curva en el inspector. FSM: [godot-fsm](../godot-fsm/SKILL.md). Plataformas 2D: [godot-platformer-2d](../godot-platformer-2d/SKILL.md).

## 3.1 Datos, variantes y look

**Datos.** Un tipo con variantes es `class_name XType extends Resource` + un `x_type.tres` por variante: una escena `projectile.tscn`, y `fast_projectile_type.tres` / `slow_projectile_type.tres` en `@export var type`. Cuándo existe un `.tres` y cuándo es un `@export`: regla 0.

**Variantes.** Otros números: otro `_type.tres`. Otra estructura u otro arte (otra malla, una partícula más): *New Inherited Scene* de la escena base, y solo cambia lo que difiere. Un nivel de herencia, no más. No se copia nodo a nodo.

**Look.** Es un archivo con nombre y sufijo (`stone_material.tres`, `forest_env.tres`) todo recurso de look que alguien va a querer retocar o reusar: materiales, `Environment`, temas, curvas, gradientes de partículas, texturas procedurales. Quedan embebidos en la escena los recursos sin decisión de arte: formas de colisión, mallas primitivas de placeholder, un `StyleBox` que el tema ya define. La carpeta: [godot-code-quality](../godot-code-quality/SKILL.md) §1.

**Colores que elige el juego** (equipos, rareza): salen de un `@export` o de una paleta con nombre (`@export var team_colors: Array[Color]`), nunca de un literal en el código.

HP actual en el nodo. No mutar el `.tres` (`duplicate()` si hace falta una copia). Guía: [resources.md](resources.md).

## 4. InputMap

Acciones semánticas en Project Settings → Input Map: `move_left`, `attack`, `pause`. No `KEY_A` / `press_shift`.

- Movimiento continuo / hold: `_physics_process` + `Input.get_vector(...)`.
- One-shot de gameplay (salto, ataque): `_unhandled_input` (la UI ya pudo consumir el evento).
- `_input` solo para interceptar (pausa, remap).
- Celular o tablet: `VirtualJoystick` y `TouchScreenButton` aprietan las mismas acciones; el juego no lee toques. Mostrarlos solo en teléfonos, mirar arrastrando en 3D y acciones de un toque: [touch.md](touch.md).

El catcher de input llama `apply_*` (en red, el `MpInput` del actor manda las acciones y el servidor aplica); no spawnea ni puntúa.

## 5. Reuso

Antes de escribir un script nuevo:

1. ¿Existe en `shared/` o `addons/`?
2. La segunda entidad que lo usa → pasa a `shared/` (o a `systems/`); si sirve a otro juego, a `addons/`. No una copia por título.
3. API: señales en pasado + `@export`. Sin puntaje ni textos del producto.

| Pieza | Forma reusable |
|-------|----------------|
| FSM | addon `fsm_kit`: `FsmMachine` + `FsmState`; el actor se inyecta (`@export var actor`) |
| Plataformas 2D | addon `plat_kit`: `PlatMotor` (coyote, buffer, apex). Dash/stamina = código del juego |
| Salud / hit | `Health` + Hitbox/Hurtbox packed scenes |
| Post-proceso | stack CanvasLayer; **un pass = una packed scene** |
| Autoridad / sync | `MpAuthority` (addon) |
| Textos de la UI | archivo de traducciones (CSV en `locale/`) + `tr()` |
| Tipos con variantes | Resource + `_type.tres` |

Un pass (bloom, grain, distorsión) = `BackBufferCopy` + `ColorRect` + shader propio. El stack no conoce el juego. Un pickup no mete lógica dentro del shader de otro pass: tweenea **ese** pass.

Shaders: un efecto, un archivo. **No inventes** el FX si hay catálogo: [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) primero; [Shadertoy](https://www.shadertoy.com) si hay que portar. Guía: [assets.md](assets.md).

Sprites 2D: **preguntá** si quiere MCP/sprites y pedí **referencias**. Skill [godot-animation](../godot-animation/SKILL.md). Si dice que sí: MCP [Aseprite](https://github.com/diivi/aseprite-mcp) ([assets.md](assets.md)). Si no: placeholder. No un sprite inventado.

3D: **preguntá** si quiere el MCP de [Blender](https://www.blender.org/lab/mcp-server/). Si sí: instalalo, pedí referencias, y el modelo entra como `.blend` directo o como `.glb`. Si no: placeholder. Detalle en [assets.md](assets.md).

Materiales / texturas (piso, pared, terreno, tile 2D): **preguntá** si quiere crearlos con [Material Maker](https://github.com/RodZill4/material-maker) y pedí referencias. Cada superficie es un `_material.tres` que se elige en el inspector; en un modelo importado, en su import: **Advanced…** › el material › **Use External** con la ruta del `.tres`, no por código ni por el nombre del slot al correr. Skill [godot-material-maker](../godot-material-maker/SKILL.md).

## 6. Cómo implementar un componente

1. Packed scene chica + `class_name`.
2. Perillas `@export` con `##`, rango y unidad. Aviso del editor si falta una referencia.
3. El feature **instancia** el componente en la escena. No `load` shaders a mano desde el mundo. Un componente reusable dueño de su shader (como `Sprite3D` con el suyo) sí puede hacer `preload` y armar su material, con las perillas como `@export` del componente. El shader vive al lado del componente, también en sistemas + contenido (en `systems/<componente>/`, no en `content/shaders/`).
4. Señales del propio nodo; el padre conecta. El bus `Events` solo para sistemas que no se conocen. El pass FX no llama a la sesión.
5. Variante por jugador (un tinte): método público que recibe el color; el color sale de un `@export` o de una paleta, no del código.

## 7. Preview en el editor

Abrir la escena en el editor muestra el juego como se ve al correr: materiales, props, el tablero. Lo que solo existe al correr se ajusta a ciegas.

- Antes de `@tool`, preguntate si puede estar en el `.tscn`. Lo que se ve porque está en la escena no necesita código.
- Un componente de look (arma mallas, coloca props, aplica un material) es `@tool`. Un `@export` con setter que lo reconstruye muestra el cambio en el editor.
- Si el look sale de un Resource (`@export var type: UnitType`), el setter **no** corre cuando se edita una propiedad de ese Resource: conectá su señal `changed` y reconstruí ahí. Si no, alguien cambia el `.tres` y la preview no se entera.
- `@tool` solo en componentes de look. Todo script que un `@tool` usa también es `@tool`. En el editor, nada de `queue_free` sobre nodos guardados ni escribir propiedades que se guardan.
- Lo generado no se guarda en la escena: los hijos que agrega quedan sin `owner`, y una propiedad generada sale del guardado con `_validate_property` (sin `PROPERTY_USAGE_STORAGE`).
- La lógica de juego (input, timers, señales de la partida) no corre en el editor: cortala con `Engine.is_editor_hint()` en `_ready` y `_process`. La preview sí corre.
- Lo procedural lleva un `@export var preview_seed`, así el editor muestra un resultado fijo.
- Una curva que ajusta un artista es un `@export var curve: Curve` (se dibuja en el inspector) o un clip de `AnimationPlayer`. Un `Tween` exporta también su `Tween.TransitionType` y su `Tween.EaseType`; nunca quedan en el código.
- Quien implementa dice, para cada escena nueva, qué tiene que ver un humano al abrirla en el editor sin correrla.

Docs: [running code in the editor](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html).

## Anti-patrones

- God-node `World.gd` que dibuja efectos, crea enemigos, puntúa y cambia de escena.
- `match kind` gigante en el actor.
- Duplicar un shader «un poquito distinto» en dos features.
- Collision layers distintos en código y en el inspector.
- Hijos 100% en código cuando una packed scene los haría editables.
- Mutar el `.tres` de tipo al correr.
- El mismo número en dos inspectores, o una cadena `.tres` → `.tres` para encontrarlo.
- Una tabla ciega: un `Dictionary` sin tipo o sub-recursos anónimos (regla 0).
- Un material, un `Environment` o un tema que alguien va a retocar, embebido como sub-recurso.
- Un look que solo existe al correr: materiales asignados en `_ready`, props creados por código sin preview.
- La curva de un `Tween` (`TRANS_*`, `EASE_*`) escrita en el código.
- Una variante hecha copiando nodos en vez de una escena heredada.

## Checklist

- [ ] ¿Se apaga el comportamiento sacando un hijo?
- [ ] ¿Cada número de diseño tiene un solo dueño y su fila en `docs/tuning.md`? ¿Cambiarlo abre como mucho 2 archivos?
- [ ] ¿Cada `@export` tiene `##`, rango y unidad?
- [ ] ¿Referencias `@export` / `%UniqueName` en vez de rutas `../..`?
- [ ] ¿InputMap, no scancodes?
- [ ] ¿Variantes de números = `_type.tres`; variantes de estructura = escena heredada?
- [ ] ¿Cada material, `Environment`, tema y curva que se retoca es un archivo con nombre y sufijo?
- [ ] ¿Abro la escena en el editor y se ve como en el juego (materiales, props)? ¿Qué parte del look solo existe al correr, y por qué?
- [ ] ¿La escena corre con F6?
- [ ] ¿Shader de catálogo o port documentado? ¿Sprite 2D: OK del usuario + referencias + Aseprite, o placeholder? ¿3D: OK + Blender MCP + `.blend` o `.glb`, o placeholder?

Patrones: [patterns.md](patterns.md). Resources: [resources.md](resources.md). Assets: [assets.md](assets.md). Código: [examples.md](examples.md).
