---
name: godot-layered-architecture
description: >-
  Elige y aplica la arquitectura de un juego Godot 4 (GDScript): un solo
  estilo con dos tamaños, «por entidad» (el default) o «sistemas + contenido»
  (mucho contenido o alguien que ajusta valores sin programar). Pregunta el
  tamaño y recomienda el default. Cada sistema es un nodo visible en el editor
  con un núcleo puro opcional al lado. Clean en capas solo en un repo que ya
  lo declara o si el usuario lo pide por nombre. Usar al crear o modificar un
  proyecto Godot, GDScript, escenas, carpetas, reglas de partida, features,
  HUD o al arrancar un juego nuevo.
---

# Godot — arquitectura

Base para juegos Godot 4 (GDScript). Hay **un estilo** con **dos tamaños**. El juego se arma igual que un kit: cada sistema es un nodo que se ve en el editor, con sus `@export` y sus señales, y al lado un núcleo puro opcional para las reglas que merecen un test.

Siempre cargar también [godot-composition-first](../godot-composition-first/SKILL.md) y [godot-code-quality](../godot-code-quality/SKILL.md) (regla 0, carpetas, patrones, tipado, lint). Tests: [godot-testing](../godot-testing/SKILL.md). Multiplayer: **preguntar** (ninguno / local-WiFi / online) — [godot-mp-kit](../godot-mp-kit/SKILL.md) solo si hay MP. 2D/3D: **preguntar**; si es 3D, MCP Blender solo con OK. Un título nuevo o un RFC: [godot-studio-workflow](../godot-studio-workflow/SKILL.md).

## Prioridades (siempre)

- Simple y predecible: cada cosa donde un humano la adivina, y cambiar un número abre como mucho 2 archivos.
- Un humano lo encuentra: `docs/tuning.md` dice qué abrir para cada cosa.
- Composición antes que herencia.
- Nodos y editor antes que código: lo que se puede ver y cambiar en el inspector no se arma por código.
- Componentes reusables.

## 1. Elegir el tamaño (obligatorio)

**Preguntar siempre** al usuario, con la tool de preguntas (`AskUserQuestion` en Claude Code / `AskQuestion` en Cursor, si está), **antes** de crear carpetas, autoloads o una feature que fije la forma del proyecto. La pregunta es por tamaño, y trae una recomendación:

> ¿Juego chico (uno o dos programadores, hasta unos 10 tipos de entidad), o juego con mucho contenido o con alguien que ajusta valores sin programar?

1. **Por entidad** (recomendado, el default) — una carpeta por tema, con todo lo de esa entidad adentro. Ver [by-entity.md](by-entity.md).
2. **Sistemas + contenido** — las reglas en `systems/` y todo lo que editan diseño y arte en `content/`. Ver [systems-content.md](systems-content.md).

Si el usuario no sabe, usá **por entidad**. Se puede pasar a sistemas + contenido después: es mover carpetas, no reescribir.

No preguntar de nuevo si: el usuario ya eligió en este chat; pidió un tamaño por nombre; o el repo **ya lo declara** (RULES.md) **y** el trabajo es sobre ese mismo juego.

Si no hay respuesta, **no** crees carpetas.

**Clean en capas** (`features → core → domain`) no se ofrece a un proyecto nuevo. Vale en un repo que ya lo declara o si el usuario lo pide por nombre: [clean.md](clean.md). No se cambia el estilo de un juego ya empezado.

Carpetas, nombres de archivo y sufijos: [godot-code-quality](../godot-code-quality/SKILL.md) §1. La elección queda en RULES.md.

## 2. Lineamientos comunes

| Prioridad | En código |
|-----------|-----------|
| Composición | Árbol + packed scenes. No una superclase de 800 líneas. |
| Editor | Perillas en `@export` y en el `.tscn`. No pisar el inspector en `_init` / `_ready`. |
| Datos | Dónde vive cada número y cuándo existe un `.tres`: regla 0 de [godot-code-quality](../godot-code-quality/SKILL.md). |
| Reuso | Lo que usan dos entidades va a `shared/` (o a `systems/`); lo que sirve a otro juego, a `addons/`. |
| Una responsabilidad | Un script, un trabajo. Se parte por responsabilidad (hijo o componente), no por cantidad de líneas. |
| Señales | Nombre en **pasado**, tipadas (`signal died(who: Node)`). El padre conecta; el hijo no nombra al padre. Entre sistemas que no se conocen, el bus `Events`. |

### Escenas autónomas (docs Godot)

Diseñá cada packed scene para correr **sola** (F6), sin depender de lo que la rodea. Si necesita al mundo, el **padre se lo pasa** (`@export var health: Health`). El árbol es **relacional**, no espacial: un nodo es hijo solo si al borrar el padre debe borrarse también; si no, es hermano + `RemoteTransform2D` / `RemoteTransform3D`. Reparto típico: `Main` persistente, `World` (se cambian los niveles) y `GUI` hermana (no se borra con el nivel).

### Núcleo puro (los dos tamaños)

Una regla que merece un test sin escena (puntaje, turnos, costos, quién gana) va en un script puro **al lado del nodo que la usa**: `match/match.gd` (el nodo) y `match/match_rules.gd` (el núcleo). Es el contrato de los kits (`GridBoard` + `CellGrid`, `TurnClock` + `TurnCycle`, `Wallet` + `Purse`).

- `extends RefCounted`. Se crea con `new()` en el nodo y en los tests.
- No toca `Node`, `Input`, `MultiplayerAPI`, `get_tree()`, `@rpc` ni `await` de escena. No lee autoloads.
- Recibe números o Resources por constructor o por argumento. Los números salen del inspector del nodo o de un `.tres`: el núcleo no guarda balance en constantes.
- El nodo lo envuelve: le pasa sus `@export`, llama sus métodos y emite las señales. El humano ve el nodo; el núcleo no agrega nada que tocar.
- Es opcional. Si la regla son tres líneas, quedan en el nodo.

No hay una carpeta `domain/` aparte.

### Dónde vive cada cosa

| Qué | Usar | No |
|-----|------|-----|
| Tipos con variantes (proyectil A o B, enemigo scout o tank) | `class_name XType extends Resource` + un `x_type.tres` por variante | `if kind ==`, un autoload con stats |
| Números de diseño de una entidad | El `.tres` de su tipo, o la raíz de su escena (regla 0) | El mismo número en dos inspectores |
| Reglas de partida (duración, vidas) | `@export` de la escena `match.tscn`; un `match_config.tres` si lo ajusta alguien que no abre escenas, lo leen varias piezas o hay varios modos | Literales copiados |
| Look (material, `Environment`, tema, curva) | Un archivo con nombre y sufijo ([godot-composition-first](../godot-composition-first/SKILL.md) §3.1) | Un sub-recurso anónimo que alguien va a querer retocar |
| HP actual, cooldown en curso | Variable del nodo, al correr | Mutar el `.tres` |
| Puntaje y vidas de *esta* partida | Nodo `Match` | Un `ScoreManager` eterno |
| Comportamiento de un actor | Nodo hijo con `class_name`, o packed scene | Un manager global |
| Helpers puros | `class_name` + `static func` | Un singleton vacío |
| Servicio global y aislado que sobrevive al cambio de escena | Autoload en `autoloads/` (MpKit, el bus `Events` solo con señales) | Un autoload que guarda nodos visuales o el puntaje de la ronda; registry, locator o manager |

Un autoload con valores que se ajustan se registra como escena (`.tscn`) o lee un `.tres`: un autoload de script no tiene inspector.

Textos de la UI en el idioma del producto, en el archivo de traducciones; identificadores de código en inglés.

## 3. Cómo agregar una feature

Checklist: [adding-features.md](adding-features.md). Tests: [godot-testing](../godot-testing/SKILL.md).

## 4. IDs (si hay multiplayer)

Slot lógico = HUD y vidas. Peer ENet = solo RPC. HUD: `MpKit.local_slot()` (0 = proceso dedicated, no hay jugador). Nunca `get_unique_id()`.

## Anti-patrones

- `World.gd` que pinta, crea enemigos, puntúa y cambia de escena.
- `if kind == "fast"` en el proyectil en vez de un `.tres` de tipo.
- Mutar un Resource compartido (`type.damage = 3`).
- Feature nueva por herencia profunda de scripts.
- Autoload para algo que es un nodo o un Resource.
- Patrones inventados (registry, service locator, manager de managers).
- Carpetas `domain/`, `core/` o `features/` en un proyecto que no declaró Clean.

Ejemplos: [examples.md](examples.md).
