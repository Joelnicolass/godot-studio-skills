# Resources — plantillas de datos (Godot 4)

Docs: [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), [Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html).

Los nodos hacen. Los Resources **son datos**. Godot carga cada archivo una vez y lo comparte.

## Cuándo usar Resource

Varios tipos, misma escena, cambian números / refs / PackedScenes: proyectiles, enemigos, items, armas, tablas de spawn. O un dato que **comparten varias** escenas.

Una escena `projectile.tscn`. Diez `.tres`. Cero `if kind ==`.

## Cuándo no

- El valor lo usa **una sola** escena: `@export` en el nodo que lo usa. Un `.tres` intermedio solo agrega un archivo que abrir.
- Un `.tres` que apunta a otro por tag, por texto o por una ruta armada: referenciá el recurso directo (`@export var passive: FuryPassive`).
- Si cambiar un número exige abrir más de 2 archivos, sobra una capa (regla 0 de [godot-code-quality](../godot-code-quality/SKILL.md)).

Si cambia la **estructura** del árbol: packed scene distinta, no un Resource con 40 flags.

`class` interna que extiende Resource **no serializa**. Script de archivo + `class_name`.

## Receta

1. `extends Resource` + `class_name ProjectileData`.
2. `@export` con defaults (si no, el inspector falla).
3. Create Resource → `projectile_fast.tres`, `projectile_slow.tres` (texto `.tres` para git).
4. En el actor: `@export var data: ProjectileData`.
5. Si `data == null`: `_get_configuration_warnings()`; `assert` solo extra en debug.

```gdscript
class_name ProjectileData
extends Resource

@export var display_name: String = "Default"
@export var damage: int = 1
@export var speed: float = 400.0
@export var lifetime_sec: float = 1.5
@export var scene: PackedScene
```

```gdscript
@export var data: ProjectileData

func _get_configuration_warnings() -> PackedStringArray:
	if data == null:
		return PackedStringArray(["Assign a ProjectileData resource."])
	return PackedStringArray()
```

## Externo vs built-in

`.tres` externo = default para plantillas compartidas. Built-in = dato de una sola instancia.

## No mutar la plantilla

`load("res://resources/projectiles/projectile_fast.tres")` es **la misma** instancia. `data.damage = 3` ensucia todas.

- Definición: solo lectura.
- Copia de trabajo: `data.duplicate()`.
- HP máximo en el Resource; HP actual en el nodo.

## Dónde viven

Junto a la escena que los usa, en una carpeta por entidad cuando ayuda (`projectiles/projectile.tscn`, `projectile_data.gd`, `projectile_fast.tres`). Una carpeta de familia aparte (`resources/<familia>/`, o `src/resources/` en Clean) solo para tipos que comparten varias escenas o features.

Reglas de ronda: `@export` del nodo `Match`; un `MatchRules.tres` solo si lo leen varias piezas o hay varios modos para elegir. Catálogo: Resources. Look de instancia: `@export` del nodo.

## Anti-patrones

- `enum Kind` + `match` de stats en el proyectil.
- Un `.tres` por instancia viva.
- Un `.tres` que usa una sola escena, o una cadena `.tres` → `.tres` → nodo para encontrar un número.
- Inner class `class Foo extends Resource`.
- Pisar `@export var data` en `_ready` para forzar un número de diseño.
