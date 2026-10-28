---
name: godot-code-quality
description: >-
  Convenciones de calidad de código para Godot 4 (GDScript), según la
  documentación oficial y las herramientas de la comunidad: regla 0 (simple y
  predecible: el valor vive en el nodo que lo usa), patrones probados (señales,
  signal up / call down, bus Events, FSM, componente, command, pool, Resource
  compartido, spawner), tipado real, ## frente a #, idioma, gdformat/gdlint y
  avisos UNSAFE_*. Usar al escribir o revisar GDScript, planificar un corte,
  generar RULES.md, configurar el lint, o al decidir si algo merece un .tres,
  un autoload o un patrón.
---

# Godot — calidad de código

Código «normal» de Godot 4: el que un dev que nunca vio el proyecto reconoce a simple vista y cambia sin preguntar. Todo sale de la documentación oficial y de herramientas de la comunidad ([fuentes](#fuentes)).

Árbol y composición: [godot-composition-first](../godot-composition-first/SKILL.md). Capas: [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Tests y CI: [godot-testing](../godot-testing/SKILL.md). Antes / después: [examples.md](examples.md).

Si una convención propia del proyecto (RULES.md, un CONVENTIONS) contradice esta guía, no la sigas en silencio: señalala y proponé el estándar.

## 0. Regla 0: simple y predecible

Un dev tiene que adivinar dónde vive una cosa y cambiarla abriendo uno o dos archivos.

- «Editor first» quiere decir que el valor vive **en el nodo que lo usa**, como `@export`, a la vista en el inspector. No quiere decir un `.tres` o un puntero para cada cosa.
- Un `.tres` existe solo si **varias cosas lo comparten** o si **se edita como tipo** (un enemigo, un arma con variantes). Si lo usa una sola escena, va como `@export` en el nodo.
- Nada de indirección por tag o por texto. Eso incluye una clave que nombra otro recurso, una ruta armada con un código (`"res://shots/" + tag + ".tscn"`) o un `String` que elige una escena. Referenciá la escena, el nodo o el recurso directo.
- Sin cadenas: si para encontrar un número hay que ir de A a B y de B a C, es un bug de diseño.
- **Medida:** si cambiar un número exige abrir más de 2 archivos, el diseño está mal.
- Si dos diseños funcionan, elegí el de menos archivos y menos saltos, aunque sea menos «general».

## 1. Escenas y referencias

- Un concepto del juego (una criatura, un arma, un widget del HUD) es una **escena** ([scenes vs scripts][s-scenes]). Su comportamiento son nodos hijos visibles en el árbol, cada uno con sus valores en el inspector.
- Las referencias a otros nodos son un `@export var health: Health` asignado en el inspector, o un `%UniqueName` dentro de la misma escena ([interfaces][s-interfaces], [unique nodes][s-unique]). Para nodos de tu propia escena no uses `get_node("Nombre")` con texto, cadenas de `get_parent()` ni búsquedas en runtime por tipo o grupo.
- Escenas y recursos: `@export var x: PackedScene`, arrastrado en el inspector. No pongas `preload` en el default de un `@export`: la escena lo pisa y se desperdicia ([logic preferences][s-logic]).
- Una escena que se repite en dos lugares es su propio `.tscn` y se instancia; nunca se copia nodo a nodo.
- En una escena grande, agrupá los hijos bajo padres simples (`World`, `Systems`, `Hud`, `Audio`) ([scene organization][s-org]).
- Un nodo creado por código es la excepción (pools, balas). Lo que existe una vez por escena va en el `.tscn`.
- Un `@export` obligatorio vacío muestra un aviso en el editor (`_get_configuration_warnings`) **y** hace `push_error` en runtime; nunca un `return` callado.
- Una carpeta por entidad cuando ayuda: `enemies/bat/` con su `.tscn`, `.gd`, `.tres` y arte. Los assets van «lo más cerca posible» de sus escenas ([project organization][s-project]). Una carpeta aparte de datos, solo para tipos que comparten varias escenas.
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
| Tipos y tuning que comparten muchas instancias | **Resource como dato** | Un script `Resource` con `@export` tipados (`EnemyType`), solo si se comparte (regla 0) |
| Crear entidades | **Spawner** | Un nodo por clase de cosa instancia la escena, la configura y la agrega. Con red, un `MultiplayerSpawner` |

- Conectá en el editor (panel Nodo › Señales) si los dos extremos están en la misma escena, y en `_ready` si uno nace en runtime. Nunca por nombre de método en texto.
- La señal lleva los datos tipados: quien escucha no vuelve a preguntarle al emisor qué pasó.
- **No inventes otros patrones:** nada de registries, service locators, managers de managers ni un `X.of(node)` que busca en el árbol. Si ninguno de la tabla encaja, escribí el código directo más simple.

## 3. Autoloads y estado global

- Un autoload es solo para un servicio que **maneja su propia información** durante todo el juego ([autoloads][s-autoload]): el flujo menú ↔ partida, el audio, la red y el bus `Events`. Nada más.
- El estado de una partida vive en un nodo de esa partida, no en un `static var`.
- `class_name X extends RefCounted` con `static func` está bien para reglas y matemática **puras**, sin estado. Son lo primero que se prueba con GUT.
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
- Una sentencia por línea, menos de 100 columnas y dos líneas en blanco entre funciones.
- **Sin tope de líneas por script.** Se parte por responsabilidad, no por cantidad. Un tope bajo lleva a comprimir código (`if` de una línea, líneas de 160 columnas) y a partir una clase cohesiva en varias. gdlint avisa recién a las 1000 líneas o a los 20 métodos públicos.
- **Errores:** `push_error` para un setup roto, `push_warning` para una rareza recuperable y `assert()` para invariantes del programador (no llega al release). Un rechazo del juego (sin maná, fuera de rango) es un enum o una constante `StringName`, no texto libre.

## 5. Comentarios y documentación

- `##` es **documentación de la API**: aparece en la ayuda del editor y como tooltip del inspector en un `@export` ([documentation comments][s-doc]). Va en la clase (justo después de `extends`), en los miembros públicos y en los `@export`, y dice qué hace y qué significan los valores.
- `#` es para notas de implementación, dentro de las funciones y solo cuando el código no lo puede decir solo. Nunca `##` dentro de una función.
- Los comentarios describen el código como es hoy. El historial (números de RFC, nombres de cortes, «antes hacía…») va en git. Una cita a otra fuente (el juego original, un paper, un hilo) va en un doc aparte, no en un `##` que el inspector muestra como tooltip.
- Un README de carpeta solo existe si dice algo que el código no dice, en pocas líneas. La arquitectura va en un `docs/architecture.md` de una página.

## 6. Idioma

- Código, comentarios, `print` / `push_warning` / `push_error`, avisos del editor y grupos del inspector (`@export_group`): **en inglés**.
- Todo lo que ve el jugador pasa por `tr()` (o por el módulo de textos del proyecto).

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

1. **¿Cuántos archivos hay que abrir para cambiar un número de esta feature?** Contalos. Más de 2 = rediseñar.
2. ¿Cada `.tres` nuevo lo comparten varias cosas o se edita como tipo? Si no, es un `@export` en el nodo.
3. ¿Hay una referencia por tag, por texto o por una ruta armada? Pasala a un `@export` directo.
4. ¿Cada comunicación usa un patrón de §2? ¿Apareció un registry, un locator, un manager o un autoload nuevo?
5. ¿El tipado es real? Sobre los `.gd` del diff (revisá cada resultado: un `Dictionary.get` en el borde de red es legítimo):

   ```bash
   git diff --name-only -- '*.gd' | xargs rg -nP '(:|->)\s*(Dictionary|Array)\b(?!\[)'
   git diff --name-only -- '*.gd' | xargs rg -n '\.get\("|\.set\("|has_method\(|\.call\("'
   ```

6. ¿`##` solo en la API y `#` dentro de las funciones, sin historial ni citas? `rg -n '^\s+##'` encuentra `##` indentados.
7. ¿Logs y avisos en inglés, y textos del jugador con `tr()`?
8. ¿`gdformat --check`, `gdlint` y GUT en verde, si el proyecto los tiene? Pegá la salida.

## Fuentes

- Godot 4: [guía de estilo][s-style] · [documentation comments][s-doc] · [static typing][s-typing] · [scene organization][s-org] · [scenes vs scripts][s-scenes] · [autoloads vs nodes][s-autoload] · [Godot interfaces][s-interfaces] · [logic preferences][s-logic] · [project organization][s-project] · [groups][s-groups] · [scene unique nodes][s-unique]
- gdtoolkit: [linter][s-gdlint] · [formatter][s-gdformat] · GUT: [docs][s-gut]
- Comunidad: [GDQuest, GDScript guidelines][s-gdq] · [GDQuest, event bus][s-bus] · [KidsCanCode, node communication][s-kcc] · [Game Programming Patterns][s-gpp] · [godot-demo-projects][s-demos] (referencia de código idiomático)

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
