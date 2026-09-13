# Resources — plantillas de datos (Godot 4)

Docs de motor: [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html), [Node alternatives](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html).

Los nodos hacen (dibujan, simulan, disparan). Los Resources **son datos**. Godot carga cada archivo una vez y lo comparte: por eso sirven de catálogo.

## Cuándo usar Resource (prioridad)

Si hay **varios tipos** que comparten la misma escena y cambian números, refs o PackedScenes:

- Balas / proyectiles (`damage`, `speed`, `lifetime`, `scene`)
- Enemigos / NPCs (`max_hp`, `speed`, `loot`, `scene`)
- Power-ups / items (`id`, `duration`, `icon`)
- Armas / habilidades (`fire_rate`, `projectile`, `sfx`)
- Tablas (spawn weights, waves, loot)

Una escena `bullet.tscn`. Diez `.tres`. Cero `if kind ==`.

Si cambia la **estructura** del árbol (otro collider, otro hijo), packed scene distinta o composición — no un Resource con 40 flags “enable_wing”.

`class` interna que extiende Resource **no serializa**. Siempre script de archivo + `class_name`.

## Receta

1. Script `extends Resource` + `class_name BulletData`.
2. `@export` / `@export_group` / `@export_range`. Todo parámetro de `_init` con default (si no, el inspector falla).
3. FileSystem → Create Resource → `BulletData` → `plasma.tres`, `spread.tres` (texto `.tres` para git).
4. En el actor: `@export var data: BulletData`. Arrastrar el `.tres`.
5. Runtime lee `data.speed`. Estado vivo (`hp` actual) en el nodo, no en el `.tres`.

```gdscript
class_name BulletData
extends Resource

@export var display_name: String = "Plasma"
@export var damage: int = 1
@export var speed: float = 520.0
@export var lifetime_sec: float = 1.4
@export var scene: PackedScene  # si el tipo cambia de visual
```

```gdscript
# bullet.gd — un solo script para todos los tipos
@export var data: BulletData

func _ready() -> void:
	assert(data != null)
```

El arma/spawner guarda el Resource (o el Resource guarda la `PackedScene`) y hace `data.scene.instantiate()` + asigna `data`.

## Externo vs built-in

| | Cuándo |
|--|--------|
| `.tres` externo | Lo comparten varias escenas (jugador, enemigo, UI). **Default para plantillas.** |
| Built-in en el `.tscn` | Dato de una sola instancia, no reutilizable. |

## No mutar la plantilla

`load("res://resources/bullets/plasma.tres")` devuelve **la misma** instancia. `data.damage = 3` en runtime ensucia todas las balas (y en editor puede escribir el asset).

- Definición: solo lectura.
- Copia de trabajo: `data.duplicate()` (buffs, rolls).
- Instancia de escena: `resource_local_to_scene` si el override es de ese `.tscn`.

HP máximo en el Resource; HP actual en el nodo (o `duplicate()` al spawnear).

## Dónde viven

Clean: `src/resources/<familia>/`. Estándar: `resources/<familia>/` o junto al actor. El `.gd` de la clase junto a los `.tres`.

Tablas: Resource que exporta `Array[EnemyData]` o `Dictionary` de Resources — no JSON parseado a mano si el inspector puede editarlo.

## Relación con constantes

`GameConstants` / `MatchRules.tres`: pocos valores de **ronda**.  
Catálogo de contenido: Resources.  
Look de un glow en *esta* escena: `@export` del nodo.

## Anti-patrones

- `enum BulletKind` + `match` de stats en el proyectil.
- Un `.tres` por *instancia viva* (eso es el nodo).
- Inner class `class Foo extends Resource`.
- Pisar `@export var data` desde código en `_ready` para forzar un número de diseño.
- Meter PackedScenes pesadas y `duplicate(true)` profundo sin necesidad (compartí la definición, instanciá la escena).
