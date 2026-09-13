---
name: godot-composition-first
description: >-
  Diseña escenas Godot 4 por composición: nodos hijos, packed scenes,
  StateMachine, stacks de FX, Resources (.tres) como plantillas de balas,
  enemigos y power-ups, @export y valores del editor por encima de hardcode.
  Prioriza reutilizar componentes en shared/addons. Usar al crear o editar
  .tscn, GDScript, shaders, FSM, trails, HUD, o al decidir entre herencia,
  constantes, Resources e inspector.
---

# Godot — composición, editor y reuso

Acompañante de [godot-layered-architecture](../godot-layered-architecture/SKILL.md) (ese skill **pregunta** Clean vs estándar). Esta skill decide **cómo se arma el árbol y los datos**, no si hay carpeta `domain/`.

## Prioridades (siempre)

Siempre se priorice:

- arquitectura facil de escalar y limpia en capas
- siempre tienen prioridad las estructuras de composicion
- siempre tienen prioirdad los nodos y las configuraciones sobre el editor
- siempre se debe dar prioridad a la reusabilidad de los componenetes

## 1. Composición gana a herencia

El pawn / actor es un **contenedor delgado**: física + orquestación. El comportamiento vive en hijos.

```
Pawn (RigidBody2D / CharacterBody2D)     ← poco código, claims de autoridad
├── Hull          Polygon2D / Sprite2D
├── Trail         componente reusable
├── Feedback      preview de fuerza, aim, etc.
├── States        StateMachine
│   ├── Coasting
│   ├── Aiming
│   └── Eliminated
└── MultiplayerSynchronizer
```

- Estados = nodos `State` bajo un `StateMachine`, no un `enum` + `match` de 200 líneas en el pawn.
- Input (swipe, botón) es **otro nodo** (a menudo hermano en el mundo), no mezclado con física.
- Un FX nuevo es un hijo o una packed scene, no un parámetro más en la superclase.

Herencia solo para el contrato mínimo (`State extends Node`, `CrtPass extends Control`). Si vas a `class BigShip extends Ship` con más sistemas, paramá: componé.

El ejemplar: nave = `RigidBody2D` + trail + force feedback + FSM; post-FX = stack de passes.

## 2. Nodos y configuración del editor ganan al código

El `.tscn` y el inspector son la fuente de verdad del **look, layout y tunables de instancia**.

Hacer:

- `@export` / `@export_group` / `@export_range` para knobs que un humano va a tweakear (colores, amplitudes de shader, lags, “react to audio”).
- Dejar el default en la escena. El script declara el tipo y un fallback razonable; **no** pisa el valor guardado.
- Materiales y shaders: knobs en el material del pass, no reescritos desde un autoload de constantes.
- Layout HUD: anclas, `mouse_filter`, capas — en la escena.

No hacer:

- `_init` / `_ready` que copie `GameConstants.FOO` sobre un `@export` de apariencia (“para que coincida con el PRD”). Eso mata el editor.
- Un único `GameConstants` con 80 floats de vórtice/CRT. Eso no escala a otro título ni a dos instancias distintas.
- `return` temprano en `fragment()` u otros hacks que dejen el `ColorRect` opaco al togglear un pass.

`GameConstants` (o un `MatchRules.tres`) queda para **reglas de ronda**: duración, vidas, layers. Si tweakeás el look en play y perdés el valor al recargar, el knob estaba en el lugar equivocado.

## 2.1 Resources = plantillas de tipo (prioridad)

Números / refs que definen **un tipo** de contenido (otra bala, otro enemigo, otro power-up): **no** van como `enum` + `match` ni como 40 constantes. Van en un `class_name XData extends Resource` y un `.tres` por tipo.

- Una escena `bullet.tscn`; `plasma.tres` / `spread.tres` se asignan al `@export var data`.
- Stats de definición (damage, speed, icon, PackedScene) en el Resource.
- HP actual, cooldown en curso: en el nodo. No mutar el `.tres` compartido (`duplicate()` si hace falta una copia).
- `.tres` externo si lo reusan varias escenas; built-in solo si es de esa instancia.

Guía completa: [resources.md](resources.md).

## 3. Reusabilidad de componentes

Antes de escribir un script en `features/` o `scenes/`:

1. ¿Existe ya en `src/shared/` o `addons/`?
2. Si no, ¿un segundo caller lo va a necesitar (otro feature, otro juego, editor preview)? → nacer en `shared/` del juego o en `addons/` del framework (`Joelnicolass/godot-studio-skills`), no fork por título.
3. API del componente: signals + `@export`. Cero nombres de puntaje, slots o copy del producto.

Patrones que se extraen, no se duplican:

| Pieza | Forma reusable |
|-------|----------------|
| Wrap de mundo | helper estático (`Wrap2D.wrap_position`) |
| FSM | `StateMachine` + `State` genéricos; el estado puede preguntar al parent |
| Post-proceso | `PostFxStack` (CanvasLayer) + **un pass = una packed scene** intercambiable |
| Autoridad / sync | `MpAuthority` (addon), no copiado en cada pawn |
| Copy de UI | un módulo de strings, no literales en cada botón |
| Tipos de entidad | `class_name` Resource + `.tres` plantilla, no un script por variante de stats |

Un pass (CRT, ripple, bloom) es un nodo con `BackBufferCopy` + `ColorRect` + shader propio. El stack no conoce el juego. Encender slow-time no mezcla ripple **dentro** del shader CRT: se tweenea el pass ripple.

Shaders: un efecto, un archivo. Componer en el árbol, no en un uber-shader.

## 4. Cómo implementar un componente nuevo

1. Packed scene chica (`shared/` o `scenes/components/`) + script `class_name`.
2. Knobs `@export`. Probar en el inspector con el juego pausado / tool button si hace falta preview.
3. El feature **instancia** el componente (hijo en la escena del mundo o del pawn). No `load` el shader y setea uniforms a mano desde el arena.
4. Comunicación: `GameEvents` o signals del propio nodo. El CRT no llama a `GameSession`.
5. Si el componente tiene variante por jugador (color de estela), recibe un tint por método público — no lee `PlayerId` por dentro si se puede evitar.

## 5. Anti-patrones

- God-node `Arena.gd` / `World.gd` que dibuja FX, spawnea, puntúa y cambia de escena.
- `match state` o `match bullet_kind` gigante en el pawn.
- Duplicar `crt.gdshader` “un poquito distinto” en dos features.
- Configurar collision layers solo en código **y** distinto en el inspector (elegí inspector + una constante de **layer index** de negocio).
- Hijos creados 100% en código cuando una escena packed los haría editables.
- Mutar `plasma.tres` en runtime y afectar a todas las balas.

## Checklist

- [ ] ¿Se puede apagar/reordenar este comportamiento sacando o moviendo un nodo hijo?
- [ ] ¿Un diseñador puede tunearlo en el inspector (nodo o `.tres`) sin tocar GDScript?
- [ ] ¿El script del contenedor sigue orquestando, no implementando el efecto?
- [ ] ¿Las variantes de tipo son Resources, no `if kind`?
- [ ] ¿Vive en `shared/` o `addons/` si no es regla de este género?
- [ ] ¿El componente no puntúa ni mezcla responsabilidades?

Patrones concretos: [patterns.md](patterns.md). Resources: [resources.md](resources.md).
