# <img src="icons/rts_kit.svg" width="32" height="32" alt=""> RtsKit

La capa de mando de un juego de estrategia en tiempo real, para **2D y 3D**: unidades, selección y grupos, órdenes tipadas que se reparten en formación, la entrada que las da (clic derecho según el contexto, órdenes armadas, un menú o un panel de comandos opcionales), las señales del cursor y las cámaras de RTS. **Sin** red, **sin** reglas de juego, **sin** autoload. No mueve ninguna unidad ni pelea ninguna pelea: eso lo hace el juego con la orden que el kit le da a cada unidad.

No depende de ningún otro kit. Un juego en red lo conecta con MpKit (o con cualquier transporte) con dos llamadas propias (ver [Red](#red)); un RTS de un jugador no conecta nada.

**Lo más corto:** tus unidades con un hijo `RtsUnit`, y **un nodo** en la escena de batalla: `rig/rts_command_rig_3d.tscn` (o `rts_command_rig_2d.tscn`) con dos sockets, la cámara y el suelo. Ya elegís y ordenás.

**¿Nunca usaste el kit?** Empezá por [GUIDE.md](GUIDE.md): una unidad, el equipo, las formas de dar órdenes, cómo hacer tuya cada parte y el multijugador con MpKit, paso a paso.

## Instalar

```bash
# Copia el addon al proyecto de tu juego.
./install.sh --addon /path/to/godot-project rts_kit
```

Habilitá el plugin **RtsKit**. Proyecto > Herramientas > *RtsKit: Add default input actions* escribe las teclas por defecto en el Input Map para que las puedas reasignar ahí (sin eso, `RtsCommandInput` agrega las que falten al correr).

## Ejemplo mínimo

`examples/minimal_2d/minimal_2d.tscn` (F6): seis soldados, una cámara y el equipo de mando, que es **un nodo**: la escena `rig/rts_command_rig_2d.tscn` con su socket `camera` puesto en el inspector. Arrastrá un rectángulo sobre los soldados, hacé clic derecho en el suelo y van en línea; Ctrl/Cmd+1 guarda el grupo y 1 lo trae.

```
Minimal2D
├── Units/Soldier1…6     # soldier.tscn
├── Camera               # RtsCamera2D
├── Rig                  # rts_command_rig_2d.tscn: camera = Camera
└── Hud/Help             # tu HUD, después del equipo
```

En 3D es igual con `rig/rts_command_rig_3d.tscn` y dos sockets: `camera` y `ground` (el cuerpo de tu suelo).

Una unidad es tu escena con un hijo `RtsUnit`, y tu script hace lo que el kit no: caminar hasta su lugar y avisar.

```
Soldier (CharacterBody2D, soldier.gd)   # capa 2: la de las unidades
├── Shape, Body
├── Ring                                # visible mientras está elegida
└── RtsUnit                             # owner_slot = 1, kind = soldier, size = 34 (px)
```

```gdscript
# soldier.gd: el soldado camina hasta el lugar que le da la orden y avisa cuando llegó.
extends CharacterBody2D

## Pixels per second.
@export var speed := 160.0
## How close counts as there, in pixels.
@export var arrive := 4.0

var order: RtsUnitOrder

@onready var unit: RtsUnit = $RtsUnit
@onready var ring: CanvasItem = $Ring


func _ready() -> void:
	unit.order_started.connect(_on_order_started)
	unit.order_ended.connect(_on_order_ended)
	unit.selected_changed.connect(func(on: bool) -> void: ring.visible = on)


func _on_order_started(next: RtsUnitOrder, _replaced: RtsUnitOrder) -> void:
	order = next


func _on_order_ended(old: RtsUnitOrder, _result: StringName) -> void:
	if old == order:
		order = null


func _physics_process(delta: float) -> void:
	if order == null:
		return
	# spot_2d() is this unit's place in the formation; it follows a guarded body that walks.
	var to := order.spot_2d() - global_position
	if to.length() <= arrive:
		velocity = Vector2.ZERO
		if order.type.ends_on_its_own:
			unit.complete()  # the next queued order, if any, starts by itself
		return
	velocity = to.normalized() * minf(speed, to.length() / delta)
	move_and_slide()
```

En 2D el mundo se mide en píxeles: el equipo 2D ya trae sus distancias en píxeles, y el inspector muestra `px` al lado de cada una (`m` en 3D).

## Un mismo suelo para 2D y 3D

El kit piensa en un solo espacio (`RtsSpace`): el suelo es el plano XZ e Y es arriba, las coordenadas del mundo 3D tal como son. Un punto del mundo 2D `(x, y)` es el punto del kit `(x, 0, y)`: visto desde arriba, un campo 3D y un mapa 2D cenital son el mismo dibujo, así que una formación, una distancia y un yaw sirven para los dos. Solo convierten los bordes: `RtsSpace.from_2d` / `to_2d`, `RtsUnitOrder.spot_2d()`.

Las unidades del mundo son metros en 3D y **píxeles en 2D**, y las distancias del kit se escriben en la unidad del mundo: `RtsOrders.spacing_base`, `max_spacing`, `retarget_range`, `RtsSelection.same_type_radius` y `RtsUnit.size`. El inspector muestra cuál es al lado de cada valor: `px` cuando el nodo cuelga de un `Node2D`, `m` cuando cuelga de un `Node3D` (el más cercano hacia arriba; si no cuelga de ninguno, no muestra unidad). `rts_command_rig_2d.tscn` las trae en píxeles (8, 120, 1200 y 600) y `rts_command_rig_3d.tscn` en metros; `RtsUnit.size` lo ponés vos en cada unidad (unos 34 px el soldado del ejemplo). Si armás las piezas a mano en 2D, los valores por defecto de `RtsOrders` y `RtsSelection` son metros: poné los tuyos en píxeles.

Yaw: adelante es `(sin yaw, 0, cos yaw)` y la derecha `(-cos yaw, 0, sin yaw)`. Las cámaras y `RtsPointer.camera_yaw()` dan el yaw con el que gira una formación: hacia donde mira la vista en 3D, hacia arriba de la pantalla en 2D.

## El equipo

El equipo de mando es una escena del kit con todas las piezas ya conectadas. Instanciala en tu escena de batalla y asigná sus sockets:

| Escena | Sockets | Distancias |
|---|---|---|
| `addons/rts_kit/rig/rts_command_rig_3d.tscn` | `camera` (tu `Camera3D`, por ejemplo un `RtsCamera3D`) y `ground` (el cuerpo de tu suelo, o el padre de sus cuerpos) | metros |
| `addons/rts_kit/rig/rts_command_rig_2d.tscn` | `camera` (tu `Camera2D`, por ejemplo un `RtsCamera2D`); `ground` es opcional | píxeles |

```
Juego
├── Units / …                      # tus cuerpos, cada uno con un hijo RtsUnit
├── Camera                         # RtsCamera3D o RtsCamera2D
├── Rig                            # rts_command_rig_3d.tscn (RtsCommandRig): camera, ground, menu
│   ├── Command                    # RtsCommandInput: reparte las teclas, comparte local_slot
│   │   ├── Selection              # RtsSelection
│   │   ├── Orders                 # RtsOrders: quién obedece, formaciones, lugares
│   │   ├── Pointer                # RtsPointer: pantalla -> mundo
│   │   ├── State                  # RtsCommandState: qué está armado, qué se dijo
│   │   ├── Armed                  # RtsArmedCommand
│   │   ├── OrderInput             # RtsOrderInput: clic derecho, clics armados, entradas de menú
│   │   ├── SelectInput            # RtsSelectInput: botón izquierdo y rectángulo
│   │   ├── GroupKeys              # RtsGroupKeys
│   │   ├── OrderButton            # RtsOrderButton: el botón derecho (+ un menú opcional)
│   │   └── Probe                  # RtsTargetProbe: qué hay bajo el puntero (cursor, señal)
│   └── ViewLayer/View/Box         # el Control a pantalla completa que toma los clics del mundo,
│                                  #   y el rectángulo de selección
└── Hud (CanvasLayer)              # tu HUD: después del equipo en el árbol
    ├── CommandCard                # opcional: RtsCommandCard, botones para cada orden
    ├── RadialMenu                 # opcional: rts_radial_menu.tscn (va en el socket menu del equipo)
    └── Cue                        # opcional: rts_command_cue.tscn
```

**La raíz (`RtsCommandRig`)** tiene solo lo que el equipo necesita de tu batalla:

| Socket | Qué es |
|---|---|
| `camera` | La cámara de la batalla. A un `RtsCamera3D` / `RtsCamera2D` sin `edge_area` el equipo le pone su `View`: los bordes panean sobre el mundo y se frenan sobre tu HUD |
| `ground` | 3D: el cuerpo del suelo; nada más de esa capa cuenta como suelo (un edificio no). 2D: opcional, el suelo es todo el plano |
| `menu` | Opcional: el menú que abre el botón derecho al mantenerlo (`rts_radial_menu.tscn` o el tuyo) |

Si falta `camera` (o `ground` en 3D), o la cámara es de la otra dimensión, el nodo muestra un aviso en el editor.

**Las piezas** guardan todo lo demás, cada valor en la pieza que lo usa. En el editor: clic derecho sobre el equipo > **Editable Children**, y cambiás `Command/Orders` (catálogos, espaciado), `Command/Selection` (límite, radio), `Command` (`local_slot`, teclas) o conectás tu HUD a una pieza. En código, la raíz las da por nombre: `rig.selection`, `rig.orders`, `rig.command`, `rig.order_input`, `rig.select_input`, `rig.armed`, `rig.state`, `rig.pointer`, `rig.probe`, `rig.order_button`, `rig.group_keys`, `rig.view`, `rig.box`.

```gdscript
# El script de tu batalla escucha la selección y dice quién es el jugador de esta pantalla.
@export var rig: RtsCommandRig


func _ready() -> void:
	rig.command.local_slot = 1
	rig.selection.changed.connect(func(units: Array[RtsUnit]) -> void: print(units.size()))
```

**Tu HUD va después del equipo** en el árbol, en su propio `CanvasLayer` (o en una capa más alta): lo que queda encima de `View` conserva sus clics, y el resto del clic es del mundo.

Cada pieza es un nodo con sockets `@export`; si sacás una (con Editable Children), ese comando desaparece y nada más se rompe. Los tres ejemplos usan el equipo: `examples/minimal_2d` (lo mínimo, arriba), `examples/skirmish_3d` (con el menú radial, el cursor y los pings) y `examples/skirmish_2d` (sin ningún menú: un clic derecho simple y el panel de comandos). ¿Preferís armarlo a mano, pieza por pieza? [GUIDE.md › 3](GUIDE.md#3-el-equipo-de-mando) tiene la tabla de sockets.

## La unidad (RtsUnit)

Un hijo del cuerpo (cualquier Node3D o Node2D). Es el contrato entre tu juego y el kit:

| Campo | Qué es |
|---|---|
| `owner_slot`, `team` | De quién es (0 = de nadie) y para qué equipo pelea (-1 = el slot de su dueño) |
| `kind`, `tags` | «Elegir todas las de este tipo»; tags libres para filtros |
| `selectable`, `orderable`, `targetable` | Si su dueño la puede elegir, si toma órdenes ahora, si los demás le pueden apuntar (todo apagado cuando muere) |
| `size` | Su ancho: las formaciones espacian por la más ancha |
| `center`, `icon`, `formation` | El punto que proyecta un rectángulo de selección; su imagen; la formación que mantiene |
| `refused` | Las órdenes que nunca toma (un pacifista: `[&"attack", &"attack_move"]`) |

Una regla de tu juego va en un script que `extends RtsUnit` y redefine `accepts(command)`, `is_foe(other)`, `facing_yaw()` o `center_point()`.

**La cola de órdenes.** El kit da órdenes con `give(order, queue)`; tu juego escucha `order_started(order, replaced)`, la cumple y avisa `complete()` o `fail(reason)`; la siguiente de la cola (Shift) arranca sola. `order_ended(order, result)` dice por qué se fue una (`done`, `failed`, `replaced`, `stopped`, `cancelled`). `is_idle()`, `current_order()`, `queued_orders()`. Un `RtsUnitOrder` lleva la orden, su blanco, el punto de la orden, el lugar y la orientación de esta unidad; `spot()` es dónde tiene que estar ahora (sigue a un cuerpo custodiado). `order.is_repeat_of(replaced)` distingue una simple actualización (una IA que repite una orden de seguir).

## Órdenes (RtsOrders)

`apply(order, from_slot)` es la regla: solo obedecen las unidades de `from_slot` que pueden recibir órdenes y aceptan esa orden (como mucho `max_units`); el grupo se para en la formación que mantiene la mayoría (un empate: la primera del catálogo); las unidades se separan `min(spacing_per_size · la más ancha + spacing_base, max_spacing)`; los lugares giran con la orientación de la orden (con la del cuerpo custodiado en una orden GUARD) y cada unidad toma su lugar en forma greedy por distancia, o fila por fila en una formación de varias filas (no se cruzan dos caminos). Un ataque a una unidad hace que cada unidad ataque al enemigo más cercano a su propio lugar (`retarget_range`, regla: `closest_foe`). Una retirada manda a todo el bando a su ancla (`anchor_for`: por defecto, la unidad con el tag `anchor`). La orden `formation` solo guarda una formación; nadie se mueve.

`request(order)` es la del jugador local: emite `requested` y le pasa la orden a `send`, que por defecto es `apply(order, local_slot)`. Una IA llama a `apply` (o `apply_units`) directo con nodos: no se convierte nada.

Los tipos de orden son datos (`RtsCommandType` en un `RtsCommandCatalog`: a qué apuntan, cómo se reparte el grupo, quién las toma). El catálogo del kit trae `move`, `attack`, `guard`, `guard_area`, `attack_move` y `retreat`; hacé tu propio `.tres` para más (o con otros nombres). Las formaciones también son datos (recursos `RtsFormation` en un `RtsFormationCatalog`: línea, flancos, falange, semicírculo, círculo, cuña, escaramuza); extendé `RtsFormation` para una forma tuya.

### Red

El kit no manda nada. `RtsOrder.to_array()` / `RtsOrder.from_array(data, root)` convierten una orden en datos simples y de vuelta (las unidades por NodePath, o por tus ids con `id_of` / `node_of`); `from_array` rechaza datos mal formados (forma, tipos, tamaños, NaN). Un juego en red escribe el pegamento en su propio código. Con MpKit, por su canal propio (sin RPC a mano; también anda sin red):

```gdscript
# Las órdenes del jugador local viajan al servidor, que las aplica como el jugador que las mandó.
# Todos los peers: las órdenes del jugador local van al servidor.
orders.send = func(order: RtsOrder) -> void:
	MpKit.send_custom(&"rts_order", {"order": order.to_array(func(body: Node) -> String: return String(body.name))})

# El servidor las aplica como el jugador que las mandó.
MpKit.custom_received.connect(func(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel == &"rts_order" and MpKit.is_authority():
		var slot := MpKit.slot_for_peer(from_peer) if MpKit.is_networked() else MpKit.local_slot()
		orders.apply(RtsOrder.from_array(data.get("order"), self, func(id: String) -> Node: return units_root.get_node_or_null(NodePath(id))), slot))
```

`apply` revisa cada unidad contra el slot del que mandó, así que un cliente solo puede ordenar lo que es de ese jugador. El camino completo (unidades que hace aparecer MpKit, su dueño, quién soy «yo», un servidor dedicado): [GUIDE.md › 6](GUIDE.md#6-multijugador-con-mpkit).

## Entrada

- **Botón izquierdo** (`RtsSelectInput`): un clic elige; Shift alterna; Ctrl / Cmd o un doble clic eligen las del mismo tipo cerca; arrastrar más de 3 px dibuja un rectángulo (Shift suma). Con algo armado, el clic es para eso. Un clic sobre un cuerpo que no es una unidad propia emite `clicked_other`; un clic simple en el suelo limpia (`clicked_empty`).
- **Botón derecho** (`RtsOrderButton`): ordena según el contexto (`RtsOrderInput.context_orders`: a un enemigo se lo ataca, a un cuerpo propio o neutral se lo custodia, al suelo se va; `classify` suma clases tuyas, como un cadáver). Con un `menu`, mantener el botón lo abre en el punto apretado y la entrada elegida corre ahí.
- **Teclas** (`RtsCommandInput.command_keys`): una orden que apunta se arma para el próximo clic izquierdo; una que no apunta (la retirada) pasa ya. Alt+1..8 guarda una formación. Grupos: Ctrl+N guarda (Cmd en macOS, `command_on_macos`), N elige, Shift+N suma.
- **Lo que espera un clic** (`RtsArmedCommand`): cualquier orden del catálogo, o lo que arme tu juego (`arm(&"fireball", payload)`): el clic de un modo del juego vuelve como `RtsSelectInput.armed_clicked`.
- **Los menús son opcionales.** Toda interfaz de comandos muestra entradas `RtsMenuEntry` (una orden, una formación, o `CUSTOM` para tu juego) y las corre con `RtsOrderInput.run_entry(entry, screen)`. El kit trae dos: `RtsCommandCard` (un panel de botones con sus teclas) y `RtsRadialMenu` (anillos que se llenan a mano o desde los catálogos). Escribí el tuyo extendiendo `RtsOrderMenu` (se abre en un punto) o llamando a `run_entry` desde cualquier botón. Sin menú, el botón derecho es un clic derecho simple.
- **Interfaces modales**: un menú de pausa entra a `RtsWorldInput.modal_group` (`rts_modal`) mientras está abierto, y ninguna entrada del mundo lee nada.
- **Mapa de teclas** (`RtsKeymap`): las acciones y teclas por defecto; `install()` solo agrega las que el proyecto no tiene.

## Cámaras

`RtsCamera3D` y `RtsCamera2D` comparten un contrato: `yaw`, `is_dragging()` (un clic que termina un arrastre no es una orden), `focus(point)`, `debug_pointer`. El modo FOLLOW mantiene un cuerpo a la vista (3D: tercera persona detrás de él, gira con las teclas, los bordes y la mirada libre, zoom con la rueda; el ojo nunca baja del suelo, incluido el suelo vivo de `height_at`). El modo FREE es la vista cenital: paneo con las flechas, los bordes de la pantalla y arrastrando con el botón del medio, giro con Q / E (3D), zoom con la rueda, siempre dentro de `bounds`. Los bordes se frenan con el puntero sobre la UI (un botón o un panel del HUD: cualquier control cuyo filtro de mouse no sea *Ignore*); `edges_over_gui` los deja andar encima. `edge_area` los limita a un control (la vista del mundo); `wheel_blockers` saca la rueda de encima de un minimapa. `RtsCameraEffect` suma un temblor encima.

## Señales y pings

`RtsTargetProbe` nombra lo que hay bajo el puntero; `RtsCursorSkin` pone el cursor de hardware desde un `RtsCueSet`; `rts_command_cue.tscn` dibuja el ícono armado junto al puntero y hace destellar los rechazos con sus palabras (`RtsCueSet.reason_text`). `RtsArmedPreview` le pregunta a tu regla qué contestaría un clic mientras hay algo armado (un edificio que no puede ir ahí). `RtsPing3D` / `RtsPing2D` marcan adónde fue una orden.

## Tests

```bash
# Corre todos los tests del kit, sin ningún juego.
godot --headless --path rtskit_lab --script res://addons/rts_kit/tests/rts_test_runner.gd
```

`RTSKIT TESTS PASS (n)`. Cubren los lugares de las formaciones, quién obedece, el reparto de lugares (greedy y por filas), el re-blanco y la retirada, los datos simples de una orden, la cola, la selección (clic, tipo, rectángulo en 2D y 3D con oclusión, límite, grupos), la entrada sobre colisiones reales (puntero, contexto, ciclo de armado, rectángulo con eventos de mouse, el menú radial, el panel de comandos, las teclas, los modales), las dos cámaras, el equipo como un solo nodo en 2D y 3D (sockets, avisos, menú, bordes, un HUD encima), la unidad que muestra el inspector, que el kit no nombra a ningún otro, y los tres ejemplos jugados de punta a punta. Un test que corta con un error de script, o que no llega a chequear nada, falla. `rtskit_lab/` es un proyecto aparte para ellos; ahí `addons/rts_kit` es un symlink.

## Tips y recomendaciones

- **Instanciá el equipo, no lo armes.** Arrastrá `rig/rts_command_rig_3d.tscn` (o `rts_command_rig_2d.tscn`) a tu escena y asigná `camera` y `ground`. Para cambiar una pieza: clic derecho > Editable Children.
- **Capas:** el suelo en la 1 y las unidades en la 2 (`RtsPointer.ground_mask`, `unit_mask`). Una unidad fuera de la capa de unidades no se puede elegir con un clic.
- **La `View` del equipo toma los clics del mundo.** Poné tu HUD después del equipo en el árbol (o en una capa más alta): todo lo que esté encima conserva sus clics.
- **En 2D las distancias son píxeles** y el inspector lo dice (`px`). El equipo 2D ya las trae; `RtsUnit.size` va en cada unidad.
- **Avisá siempre.** Una orden que termina sola (`move`, `attack`) espera tu `complete()` o `fail(reason)`; si no avisás, la cola nunca avanza.
- **Una unidad muerta** apaga `selectable`, `orderable` y `targetable`: sale sola de la selección y de los grupos.
- **Reglas por unidad** en un script que `extends RtsUnit` (`accepts`, `is_foe`), no en la entrada.
- **Una IA** llama `orders.apply(order, slot)` o `apply_units` con nodos; no pasa por la entrada ni por `request`.
- **Teclas:** Proyecto ▸ Herramientas ▸ *RtsKit: Add default input actions* las escribe en el Input Map para reasignarlas.

## Lo que no trae esta versión

El movimiento de las unidades (pathfinding, avoidance), la visión y la niebla de guerra, un minimapa y el combate son del juego por ahora; las próximas versiones suman movimiento, visión y minimapa, y los controles modernos (más teclas de grupos y de selección, colas con Shift y waypoints, puntos de reunión, patrullar, mantener posición, posturas, posiciones de cámara, alertas). Ver `CHANGELOG.md`.
