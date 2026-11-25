# Resources — plantillas de datos (Godot 4)

Docs: [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), [Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html).

Los nodos hacen. Los Resources **son datos**. Godot carga cada archivo una vez y lo comparte.

## Cuándo usar Resource

La regla completa (un dueño por número, las tres condiciones de un `.tres`, catálogos) está en la regla 0 de [godot-code-quality](../godot-code-quality/SKILL.md). Acá, cómo se hace.

Varios tipos, misma escena, cambian números, referencias o PackedScenes: proyectiles, enemigos, items, armas, oleadas. Una escena `projectile.tscn`. Diez `_type.tres`. Cero `if kind ==`.

## Variantes: números o estructura

- **Otros números:** otro `_type.tres` (duplicar el archivo en el FileSystem y cambiarle los valores).
- **Otra estructura u otro arte:** *New Inherited Scene* de la escena base. Solo cambia lo que difiere. Un nivel de herencia, no más.
- No un Resource con 40 flags, ni una escena copiada nodo a nodo.
- Registrar la variante: en el catálogo que la ofrece (`@export var types: Array[EnemyType]` del spawner, o un `_catalog.tres`).

`class` interna que extiende Resource **no serializa**. Script de archivo + `class_name`.

## Receta

1. `extends Resource` + `class_name ProjectileType`.
2. `@export` con defaults (si no, el inspector falla).
3. Create Resource → `fast_projectile_type.tres`, `slow_projectile_type.tres` (texto `.tres` para git).
4. En el actor: `@export var type: ProjectileType`.
5. Cada `@export` con su `##`, rango y unidad: es lo único que lee quien ajusta.
6. Si `type == null`: `_get_configuration_warnings()`; `assert` solo extra en debug.

```gdscript
class_name ProjectileType
extends Resource
## One kind of projectile. One file per variant.

## Name shown in the HUD (a translation key).
@export var display_name: String = "PROJECTILE_DEFAULT"
## Damage per hit.
@export_range(0, 100) var damage: int = 1
## Travel speed.
@export_range(0.0, 2000.0, 10.0, "suffix:px/s") var speed: float = 400.0
## How long it lives without hitting anything.
@export_range(0.1, 10.0, 0.1, "suffix:s") var lifetime_s: float = 1.5
## Scene to spawn, if this variant looks different.
@export var scene: PackedScene
```

```gdscript
@export var type: ProjectileType

func _get_configuration_warnings() -> PackedStringArray:
	if type == null:
		return PackedStringArray(["Assign a ProjectileType resource."])
	return PackedStringArray()
```

## Externo o embebido

`.tres` externo, con nombre y sufijo: tipos, configuración de balance, catálogos y todo look que alguien va a retocar. Embebido en la escena: lo que no tiene decisión de diseño ni de arte (una forma de colisión).

## No mutar la plantilla

`load("res://projectiles/fast/fast_projectile_type.tres")` es **la misma** instancia. `type.damage = 3` ensucia todas.

- Definición: solo lectura.
- Copia de trabajo: `type.duplicate()`.
- HP máximo en el Resource; HP actual en el nodo.

## Dónde viven

Junto a la escena que los usa, en la carpeta de la entidad (`projectiles/projectile.tscn`, `projectile_type.gd`, `fast/fast_projectile_type.tres`). Lo que comparten varias entidades: `shared/` (o `content/` en sistemas + contenido). Carpetas y sufijos: [godot-code-quality](../godot-code-quality/SKILL.md) §1.

Un archivo por elemento, con un nombre que se lee (`terrains/plain_type.tres`, `terrains/forest_type.tres`), no un array de sub-recursos anónimos (`Resource_umusd`) dentro de un set.

## Catálogos

Una lista de tipos para elegir (terrenos de un tablero, oleadas, órdenes) es un catálogo: `Array[TerrainType]`, con cada entrada en su archivo.

```gdscript
class_name TerrainType
extends Resource
## One terrain of the board. One file per terrain.

## Key painted on the cells. Declared here and nowhere else.
@export var id: StringName
## Tile scene drawn for this terrain.
@export var tile: PackedScene
## Steps it costs to enter. 0 = cannot be crossed.
@export_range(0, 10) var move_cost: int = 1
```

El costo de cruzar un bosque es un número de `forest_type.tres`, no un `match` en el código. Con muchas variantes (unas 15 o más), una vista de tabla ayuda a compararlas (regla 0).

## Anti-patrones

- `enum Kind` + `match` de stats en el proyectil.
- Un `.tres` por instancia viva.
- Una cadena `.tres` → `.tres` → nodo para encontrar un número.
- Una tabla ciega: un `Dictionary` sin tipo, o sub-recursos anónimos dentro de un set.
- Un `.tres` sin sufijo de tipo.
- Inner class `class Foo extends Resource`.
- Pisar `@export var type` en `_ready` para forzar un número de diseño.
