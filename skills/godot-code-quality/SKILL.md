---
name: godot-code-quality
description: >-
  Convenciones de calidad de código para Godot 4 (GDScript), según la
  documentación oficial y las herramientas de la comunidad: regla 0 (simple y
  predecible: un dueño por número, cuándo existe un .tres, catálogos,
  docs/tuning.md), carpetas y sufijos de archivo, patrones probados (señales,
  signal up / call down, bus Events, FSM, componente, command, pool, Resource
  de tipo, catálogo, escena heredada, spawner), tipado real, inspector
  legible, ## frente a #, idioma, gdformat/gdlint y avisos UNSAFE_*. Usar al
  escribir o revisar GDScript, planificar un corte, generar RULES.md, decidir
  dónde va un archivo, configurar el lint, o al decidir si algo merece un
  .tres, un autoload o un patrón.
---

# Godot — calidad de código

Código «normal» de Godot 4: el que un dev que nunca vio el proyecto reconoce a simple vista y cambia sin preguntar. Todo sale de la documentación oficial y de herramientas de la comunidad ([fuentes](#fuentes)).

Árbol y composición: [godot-composition-first](../godot-composition-first/SKILL.md). Tamaño del proyecto: [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Tests y CI: [godot-testing](../godot-testing/SKILL.md). Antes / después: [examples.md](examples.md).

Si una convención propia del proyecto (RULES.md, un CONVENTIONS) contradice esta guía, no la sigas en silencio: señalala y proponé el estándar.

## 0. Regla 0: simple y predecible

Un humano tiene que adivinar dónde vive una cosa y cambiarla abriendo uno o dos archivos. Y si no la adivina, la encuentra en `docs/tuning.md`.

Esta sección es la regla completa. Las otras skills, los agentes y los commands la citan; no la repiten.

### Un dueño por número

«Editor first» quiere decir que el valor está a la vista en el inspector, en un lugar que se adivina. Los números de diseño de una entidad (velocidad, vida, daño, costo) tienen **un** dueño, en este orden:

1. **La entidad tiene un tipo** (`EnemyType`, `WeaponType`): todos sus números de balance están en el `.tres` del tipo. Los componentes los reciben del tipo (`health.setup(type.max_hp)`) y la escena no pisa esos mismos números en el inspector del componente.
2. **No tiene tipo:** se exportan en la **raíz** de la escena, agrupados con `@export_group`. La raíz se los pasa a sus hijos (call down). Se abre la escena y, sin expandir el árbol, se ve todo lo que se puede tocar.
3. **Un componente reusable** (`Health`, `Hitbox`) conserva sus propios `@export` para lo que no es balance de esa entidad, y como valor por defecto cuando nadie le pasa otro. Su tooltip lo dice.

- Nunca el mismo número con valor en dos lugares de una entidad.
- Si los números de diseño de una entidad quedan repartidos en tres o más hijos, creale un tipo aunque tenga una sola variante.

### Cuándo existe un `.tres` de datos

Existe si se cumple una de estas tres:

- **varias cosas lo comparten;**
- **se edita como tipo** (un enemigo, un arma con variantes): `class_name XType extends Resource` + un `x_type.tres` por variante;
- **es balance que ajusta alguien que no abre escenas** (`match_config.tres`, una tabla de oleadas): un archivo se encuentra con el buscador del FileSystem; un nodo dentro de una escena, no.

Si no se cumple ninguna, es un `@export`. El look (un material, un `Environment`, un tema, una curva) es otra cosa: un archivo con nombre ([godot-composition-first](../godot-composition-first/SKILL.md) §3.1).

### Catálogos sí, tablas ciegas no

- **Válido:** un **catálogo** cuyo contenido es una lista tipada de Resources con nombre (`@export var terrains: Array[TerrainType]`), donde cada entrada es su propio archivo y tiene sentido sola. Es lo que hacen `TileSet`, `MeshLibrary`, `SpriteFrames` y los catálogos de los kits. Puede ser un `@export` de un nodo o un `_catalog.tres`.
- **Válido:** una clave de texto que **es dato pintado** (el terreno de una casilla, como en un TileMap), si la clave está declarada en un solo lugar (el `id` del `TerrainType`) y un aviso del editor marca la clave que no existe.
- **Inválido:** un `Dictionary` sin tipo, o `String → Resource`, cuya clave repite algo que ya existe en otro lado (el nombre de un slot de material, el nombre de un nodo); sub-recursos anónimos (`Resource_umusd`) dentro del catálogo; un catálogo que nadie edita y solo existe para que el código busque.
- **Prueba:** si saco una entrada, ¿se ve en el editor qué deja de andar? Si no, es una tabla ciega.
- A partir de unas 15 variantes de un mismo tipo, ofrecé una vista de tabla para compararlas lado a lado (por ejemplo el plugin [Edit Resources as Table](https://github.com/don-tnowe/godot-resources-as-sheets-plugin)), con OK del usuario como cualquier addon de terceros.

### Sin saltos ciegos

- Fuera del dato pintado de arriba, nada de indirección por tag o por texto: una ruta armada con un código (`"res://shots/" + tag + ".tscn"`), un `String` que elige una escena, el nombre de un slot de material como clave, un `node.get(&"prop")` con el nombre guardado en un `@export StringName`, o un diccionario id → índice de shader lejos del nodo que es ese id. Referenciá la escena, el nodo o el recurso directo.
- Sin cadenas: si para encontrar un número hay que ir de A a B y de B a C, es un bug de diseño.
- **Medida:** si cambiar un número exige abrir más de 2 archivos, el diseño está mal.
- Si dos diseños funcionan, elegí el de menos archivos y menos saltos, aunque sea menos «general».

### `docs/tuning.md`: el mapa de perillas

Cada juego tiene `docs/tuning.md`: una tabla «quiero cambiar → archivo → nodo → propiedad», en el idioma del usuario. Quien planifica escribe las filas nuevas en el plan, el árbol incluye `[~] docs/tuning.md`, quien implementa las agrega, y el review marca NEEDS WORK si una feature sumó un `@export` de diseño sin su fila. Las `uniform` de un shader que se ajustan en su material también cuentan: una fila por perilla, con el `_material.tres` como archivo y `shader_parameter/<nombre>` como propiedad.

| Quiero cambiar | Archivo | Nodo | Propiedad |
|---|---|---|---|
| Velocidad del murciélago | `enemies/bat/bat_type.tres` | — | `speed_m_s` |
| Duración de la ronda | `match/match.tscn` | `Match` | `round_seconds` |
| Color del destello de golpe | `shared/vfx/hit_flash.tscn` | `Flash` | `color` |

## 1. Escenas y referencias

- Un concepto del juego (una criatura, un arma, un widget del HUD) es una **escena** ([scenes vs scripts][s-scenes]). Su comportamiento son nodos hijos visibles en el árbol, cada uno con sus valores en el inspector.
- Las referencias a otros nodos son un `@export var health: Health` asignado en el inspector, o un `%UniqueName` dentro de la misma escena ([interfaces][s-interfaces], [unique nodes][s-unique]). Para nodos de tu propia escena no uses `get_node("Nombre")` con texto, cadenas de `get_parent()` ni búsquedas en runtime por tipo o grupo.
- Escenas y recursos: `@export var x: PackedScene`, arrastrado en el inspector. No pongas `preload` en el default de un `@export`: la escena lo pisa y se desperdicia ([logic preferences][s-logic]).
- Una escena que se repite en dos lugares es su propio `.tscn` y se instancia; nunca se copia nodo a nodo.
- En una escena grande, agrupá los hijos bajo padres simples (`World`, `Systems`, `Hud`, `Audio`) ([scene organization][s-org]).
- Un nodo creado por código es la excepción: pools, balas, y lo que depende de los datos de la partida (una loseta por casilla). Aun así es una `PackedScene` exportada que se instancia, no `MeshInstance3D.new()` con su malla y su material armados en el código. Lo que existe una vez por escena va en el `.tscn`.
- Un `@export` obligatorio vacío muestra un aviso en el editor (`_get_configuration_warnings`) **y** hace `push_error` en runtime; nunca un `return` callado.
- **Carpetas.** Una carpeta por tema en la raíz (`player/`, `enemies/bat/`, `levels/forest/`, `ui/hud/`), sin una carpeta `scenes/` que envuelva todo, «lo más cerca posible» de sus escenas ([project organization][s-project]).
  - Lo que usa una sola entidad vive en su carpeta: su `.tscn`, su `.gd`, su `.tres` de tipo y su arte.
  - Si la carpeta pasa de unos 8 archivos, el arte baja a subcarpetas por tipo **dentro de la entidad**: `model/`, `textures/`, `audio/`, `vfx/`. La escena, su script y su `.tres` de tipo quedan arriba, a la vista.
  - Lo que usan dos o más entidades vive en `shared/`, ahí sí por tipo: `shared/components/`, `shared/shaders/`, `shared/materials/`, `shared/textures/`, `shared/vfx/`. En el tamaño sistemas + contenido, lo común de código está en `systems/` y lo común de arte en `content/`.
  - Autoloads en `autoloads/`. Escenas de prueba en `debug/`: quedan fuera del export (`debug/*` en el filtro de exclusión del preset) y nada del juego las nombra. `docs/` lleva un `.gdignore`.
  - No existen `scenes/`, `scripts/`, `resources/`, `assets/` ni `glue/`. Los árboles completos de los dos tamaños: [godot-layered-architecture](../godot-layered-architecture/SKILL.md).
  - Un color por carpeta en el FileSystem (clic derecho › *Set Folder Color*) ayuda a quien navega el proyecto.
- **El nombre dice el tipo.** Un `.tres` lleva un sufijo; uno sin sufijo no pasa el review.

  | Sufijo | Qué es |
  |---|---|
  | `_type.tres` | Datos de un tipo (`bat_type.tres`, un `EnemyType`) |
  | `_config.tres` | Balance global (`match_config.tres`) |
  | `_catalog.tres` | Catálogo: una lista tipada de Resources |
  | `_material.tres` | Material |
  | `_env.tres` | `Environment` |
  | `_theme.tres` | `Theme` |
  | `_layout.tres` | Un mapa o un tablero guardado |
  | `_curve.tres` | `Curve` |
  | Otro recurso | El nombre de su clase en `snake_case` (`_frames.tres` para `SpriteFrames`, `_gradient.tres`) |

- Archivos y carpetas en `snake_case`. El archivo se llama como su `class_name` o su nodo raíz.

## 2. Comunicación: solo patrones probados

Usá estos, y solo estos, para que se reconozcan a simple vista ([Game Programming Patterns][s-gpp]):

| Necesidad | Patrón | Cómo |
|-----------|--------|------|
| Un nodo avisa «pasó algo» | **Señal (observer)** | `signal died(by: Node)`, en pasado y tipada. Quien quiera, conecta; el emisor no sabe quién escucha |
| Un hijo le avisa a su dueño | **Signal up, call down** ([KidsCanCode][s-kcc]) | Los hijos emiten y el padre llama métodos de sus hijos. Un hijo nunca llama a su padre |
| Dos hermanos | **El ancestro media** | El padre común conecta las señales, en la escena o en su `_ready` ([scene organization][s-org]) |
| Sistemas que no se conocen (combate, HUD, audio, IA) | **Bus de eventos** ([GDQuest][s-bus]) | Un autoload `Events` con **solo** declaraciones `signal` tipadas, sin estado ni métodos. Emite el dueño del hecho. Lo local sigue siendo una señal común: el bus es solo para lo que cruza sistemas |
| Una entidad con modos | **FSM** | `FsmMachine` con un `FsmState` hijo por estado ([godot-fsm](../godot-fsm/SKILL.md)), no bloques `match mode:` repartidos |
| Comportamiento que comparten varias entidades | **Componente** | Un nodo hijo con su script y sus `@export` (`Health`, `Hitbox`). La entidad es la suma de sus componentes |
| Órdenes del jugador o de la IA | **Command** | Un objeto o método chico por orden (`move`, `attack`), encolado y ejecutado por un dueño. El mismo camino para el jugador, la IA y la red |
| Muchos objetos de vida corta (balas, partículas) | **Object pool** | El spawner o el bus dueño reusa instancias. Quien pide no hace `queue_free` de lo que es del pool |
| Tipos y números que comparten muchas instancias | **Resource de tipo** | Un script `Resource` con `@export` tipados (`EnemyType`) y un `_type.tres` por variante (regla 0) |
| Una lista de tipos para elegir (terrenos, órdenes, oleadas) | **Catálogo** | `Array[TerrainType]` con un archivo por entrada (regla 0) |
| Una variante con otra estructura u otro arte | **Escena heredada** | *New Inherited Scene* de la escena base; solo cambia lo que difiere. Un nivel de herencia, no más |
| Crear entidades | **Spawner** | Un nodo por clase de cosa instancia la escena, la configura y la agrega. Con red, un `MultiplayerSpawner` |

- Conectá en el editor (panel Nodo › Señales) si los dos extremos están en la misma escena, y en `_ready` si uno nace en runtime. Nunca por nombre de método en texto.
- La señal lleva los datos tipados: quien escucha no vuelve a preguntarle al emisor qué pasó.
- **No inventes otros patrones:** nada de registries, service locators, managers de managers ni un `X.of(node)` que busca en el árbol. Si ninguno de la tabla encaja, escribí el código directo más simple.

## 3. Autoloads y estado global

- Un autoload es solo para un servicio que **maneja su propia información** durante todo el juego ([autoloads][s-autoload]): el flujo menú ↔ partida, el audio, la red y el bus `Events`. Nada más.
- El estado de una partida vive en un nodo de esa partida, no en un `static var`.
- Un autoload con valores que se ajustan se registra como escena (`.tscn`) o lee un `.tres`: un autoload de script no tiene inspector.
- `class_name X extends RefCounted` está bien para reglas y matemática **puras**: el núcleo puro al lado de su nodo ([godot-layered-architecture](../godot-layered-architecture/SKILL.md) §2). Son lo primero que se prueba con GUT.
- Las herramientas de desarrollo no son autoloads del juego exportado.
- Los grupos se declaran como **Global Groups** en Project Settings y se nombran con una constante del dueño (`Enemy.GROUP`) ([groups][s-groups]).

## 4. GDScript

Seguí la [guía de estilo][s-style] y dejá que `gdformat` decida el formato.

- **Orden dentro del script:** `@tool` → `class_name` → `extends` → doc `##` de la clase → `signal` → `enum` → `const` → `static var` → `@export` → variables públicas → privadas (`_x`) → `@onready` → virtuales (`_init`, `_ready`, `_process`…) → métodos públicos → privados. Es el orden que controla gdlint (`class-definitions-order`).
- **Nombres:**
  - `PascalCase` para clases y enums;
  - `snake_case` para funciones y variables, con `_` adelante si son privadas;
  - `CONSTANT_CASE` para constantes y valores de enum;
  - señales en pasado (`died`, `health_changed`);
  - unidades en los nombres numéricos (`cooldown_s`, `range_m`, `speed_m_s`).
- **Tipado real, no solo declarado** ([static typing][s-typing]):
  - `var` y firmas tipadas, y colecciones tipadas (`Array[Enemy]`, `Dictionary[StringName, int]`);
  - acceso tipado (`player.health.current`), no `.get("health")`, `.set("x", v)` ni `"x" in obj` sobre un tipo que conocés;
  - sin `has_method` ni `call("nombre")` sobre tipos conocidos. Si varios tipos comparten un contrato, una base de un nivel o un componente común;
  - una clase tipada en vez de un `Dictionary` con las claves en un comentario. El `Dictionary` solo vale en el borde de la red o del guardado, con `to_dict()` / `from_dict()`;
  - los avisos `UNTYPED_DECLARATION` y `UNSAFE_*` encendidos (§7). El conteo solo puede bajar.
- **Sin valores mágicos:** un enum en vez de `0 / 1 / 2`; un `@export` (con `@export_range` y unidades) en vez de un número de tuning en el código; `delta` o `Engine.physics_ticks_per_second` en vez de un `FPS := 60.0` local.
- **Un inspector que se lee:** cada `@export` de diseño lleva un `##` que dice qué hace en palabras de diseño, un rango con su unidad (`@export_range(0.0, 5.0, 0.05, "suffix:s")`, `"suffix:m"`), y un `@export_group` / `@export_subgroup` si el nodo tiene más de 5. La unidad del inspector es la que el juego usa: no un sufijo `m` sobre un valor en píxeles. Un `@export` cuyo setter reconstruye geometría o el look va en un script `@tool`, así el cambio se ve en el editor.
- Una sentencia por línea, menos de 100 columnas y dos líneas en blanco entre funciones.
- **Sin tope de líneas por script.** Se parte por responsabilidad, no por cantidad. Un tope bajo lleva a comprimir código (`if` de una línea, líneas de 160 columnas) y a partir una clase cohesiva en varias. gdlint avisa recién a las 1000 líneas o a los 20 métodos públicos.
- **Errores:** `push_error` para un setup roto, `push_warning` para una rareza recuperable y `assert()` para invariantes del programador (no llega al release). Un rechazo del juego (sin maná, fuera de rango) es un enum o una constante `StringName`, no texto libre.

## 5. Comentarios y documentación

- `##` es **documentación de la API**: aparece en la ayuda del editor y como tooltip del inspector en un `@export` ([documentation comments][s-doc]). Va en la clase (justo después de `extends`), en los miembros públicos y en los `@export`, y dice qué hace y qué significan los valores.
- `#` es para notas de implementación, dentro de las funciones y solo cuando el código no lo puede decir solo. Nunca `##` dentro de una función.
- Los comentarios describen el código como es hoy. El historial (números de RFC, nombres de cortes, «antes hacía…») va en git. Una cita a otra fuente (el juego original, un paper, un hilo) va en un doc aparte, no en un `##` que el inspector muestra como tooltip.
- Un README de carpeta solo existe si dice algo que el código no dice, en pocas líneas. La arquitectura va en un `docs/architecture.md` de una página, y las perillas en `docs/tuning.md` (regla 0).

## 6. Idioma

- Código, comentarios, `print` / `push_warning` / `push_error`, avisos del editor y grupos del inspector (`@export_group`): **en inglés**.
- Los textos del jugador viven en un archivo de traducciones (un CSV importado, en `locale/`), no en un `.gd`. Un `Control` usa la clave como texto y se traduce solo; el código usa `tr("KEY")` ([internationalizing games][s-i18n]). Cambiar un texto no es editar código.

## 7. Herramientas estándar

No escribas un lint propio con grep para lo que ya cubren el compilador y gdtoolkit. gdtoolkit analiza el árbol sintáctico; un grep no ve una ruta armada con texto ni un orden de declaraciones.

| Chequeo | Cómo |
|---------|------|
| Formato | `gdformat --check <carpetas>` (`pip install "gdtoolkit==4.*"`) |
| Lint | `gdlint <carpetas>`. Sus defaults ya son el estándar: 100 columnas, 1000 líneas, 20 métodos públicos, 6 `return` y el orden de la guía. `gdlint -d` vuelca un `gdlintrc` solo si hace falta cambiar algo (por ejemplo `tab-characters: 4` para medir las columnas como el editor, o excluir `addons/` de terceros) |
| Tipos | Project Settings › Debug › GDScript (con Advanced Settings): los avisos de abajo en *Warn* |
| Tests y CI | GUT y un workflow que corre todo lo anterior: [godot-testing](../godot-testing/SKILL.md) |

```ini
; project.godot (1 = Warn)
[debug]
gdscript/warnings/untyped_declaration=1
gdscript/warnings/unsafe_property_access=1
gdscript/warnings/unsafe_method_access=1
gdscript/warnings/unsafe_cast=1
gdscript/warnings/unsafe_call_argument=1
```

Un chequeo propio solo vale para lo que el estándar no cubre (una frontera de red, assets que no se pueden versionar, scancodes en vez de InputMap), y cada uno dice por qué existe.

## 8. Revisión: las preguntas que mandan

1. **¿Cuántos archivos hay que abrir para cambiar un número de esta feature?** Contalos. Más de 2 = rediseñar. ¿Está su fila en `docs/tuning.md`?
2. ¿Cada número de diseño tiene un solo dueño (el tipo, o la raíz)? ¿Cada `.tres` de datos nuevo cumple una de las tres condiciones de la regla 0?
3. ¿Cada colección es un catálogo tipado con un archivo por entrada? ¿Hay una tabla ciega (un `Dictionary` sin tipo, sub-recursos anónimos)?
4. ¿Hay una referencia por tag, por texto o por una ruta armada que no sea dato pintado? Pasala a un `@export` directo.
5. ¿Cada archivo nuevo está en la carpeta que dice RULES.md, y cada `.tres` tiene su sufijo? ¿Algo del juego nombra `res://debug`?

   ```bash
   rg -n "res://debug" --glob '!debug/**' --glob '!agent/**'   # must be empty
   ```

6. ¿Algún material, malla o nodo se crea o se reasigna en `_ready`? Listalos, y decí si se ven en el editor (en la escena, en el import o con `@tool`) o por qué no.
7. ¿Cada `@export` nuevo tiene un `##`, un rango con unidad y un grupo si el nodo tiene más de 5? Listá los que no. Un `@export` de diseño sin tooltip es NEEDS WORK.

   ```bash
   git diff --name-only -- '*.gd' | xargs rg -n -B1 '^@export'   # every @export should have a ## line above
   ```

8. ¿Cada comunicación usa un patrón de §2? ¿Apareció un registry, un locator, un manager o un autoload nuevo?
9. ¿El tipado es real? Sobre los `.gd` del diff (revisá cada resultado: un `Dictionary.get` en el borde de red es legítimo):

   ```bash
   git diff --name-only -- '*.gd' | xargs rg -nP '(:|->)\s*(Dictionary|Array)\b(?!\[)'
   git diff --name-only -- '*.gd' | xargs rg -n '\.get\("|\.set\("|has_method\(|\.call\("'
   ```

10. ¿`##` solo en la API y `#` dentro de las funciones, sin historial ni citas? `rg -n '^\s+##'` encuentra `##` indentados.
11. ¿Logs y avisos en inglés, y textos del jugador en el archivo de traducciones?
12. ¿`gdformat --check`, `gdlint` y GUT en verde, si el proyecto los tiene? Pegá la salida.

## Fuentes

- Godot 4: [guía de estilo][s-style] · [documentation comments][s-doc] · [static typing][s-typing] · [scene organization][s-org] · [scenes vs scripts][s-scenes] · [autoloads vs nodes][s-autoload] · [Godot interfaces][s-interfaces] · [logic preferences][s-logic] · [project organization][s-project] · [groups][s-groups] · [scene unique nodes][s-unique] · [Resources][s-resources] · [exported properties][s-exports] · [internationalizing games][s-i18n]
- gdtoolkit: [linter][s-gdlint] · [formatter][s-gdformat] · GUT: [docs][s-gut]
- Comunidad: [GDQuest, GDScript guidelines][s-gdq] · [GDQuest, event bus][s-bus] · [KidsCanCode, node communication][s-kcc] · [Game Programming Patterns][s-gpp] · [godot-demo-projects][s-demos] (referencia de código idiomático) · estructura de carpetas: [tps-demo][s-tps], [GDQuest 3D controller][s-gdq3d], [GDQuest: modular architecture][s-modular]

[s-style]: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
[s-doc]: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_documentation_comments.html
[s-typing]: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html
[s-org]: https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html
[s-scenes]: https://docs.godotengine.org/en/stable/tutorials/best_practices/scenes_versus_scripts.html
[s-autoload]: https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_regular_nodes.html
[s-interfaces]: https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_interfaces.html
[s-logic]: https://docs.godotengine.org/en/stable/tutorials/best_practices/logic_preferences.html
[s-project]: https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html
[s-groups]: https://docs.godotengine.org/en/stable/tutorials/scripting/groups.html
[s-unique]: https://docs.godotengine.org/en/stable/tutorials/scripting/scene_unique_nodes.html
[s-gdlint]: https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter
[s-gdformat]: https://github.com/Scony/godot-gdscript-toolkit/wiki/4.-Formatter
[s-gut]: https://gut.readthedocs.io/en/latest/
[s-gdq]: https://gdquest.gitbook.io/gdquests-guidelines/godot-gdscript-guidelines
[s-bus]: https://www.gdquest.com/library/pattern_event_bus_singleton/
[s-kcc]: https://kidscancode.org/godot_recipes/4.x/basics/node_communication/
[s-gpp]: https://gameprogrammingpatterns.com/contents.html
[s-demos]: https://github.com/godotengine/godot-demo-projects
[s-tps]: https://github.com/godotengine/tps-demo
[s-gdq3d]: https://github.com/gdquest-demos/godot-4-3d-third-person-controller
[s-modular]: https://www.gdquest.com/library/modular_game_architecture/
[s-resources]: https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html
[s-exports]: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_exports.html
[s-i18n]: https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html
