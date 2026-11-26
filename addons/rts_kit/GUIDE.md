# Guía de RtsKit: tu RTS, paso a paso

Para quien nunca usó el kit. Va desde una escena de batalla vacía hasta unidades que elegís y ordenás; después muestra cómo hacer tuya cada parte, y al final cómo jugarlo en red con MpKit. La referencia de cada pieza está en [README.md](README.md); la API, en [skills/godot-rts-kit/api.md](../../skills/godot-rts-kit/api.md).

**La idea que tenés que llevarte:** RtsKit **manda**, tu juego **actúa**. El kit decide quién se puede elegir, quién obedece una orden, la formación y dónde se para cada unidad. Tu juego la lleva caminando hasta ahí, pelea, muere. El kit le da a cada unidad un `RtsUnitOrder`; tu unidad avisa cuando terminó.

- [1. Instalar](#1-instalar)
- [2. Una unidad](#2-una-unidad)
- [3. El equipo de mando](#3-el-equipo-de-mando)
- [4. Cómo da órdenes el jugador](#4-cómo-da-órdenes-el-jugador)
- [5. Hacelo tuyo](#5-hacelo-tuyo)
- [6. Multijugador con MpKit](#6-multijugador-con-mpkit)
- [7. Lista de control](#7-lista-de-control)

## 1. Instalar

```bash
# Copia el addon al proyecto de tu juego.
./install.sh --addon /path/to/tu-proyecto-godot rts_kit
```

1. Proyecto > Configuración del proyecto > Plugins: habilitá **RtsKit**.
2. Proyecto > Herramientas > **RtsKit: Add default input actions**. Las acciones del kit aparecen en el Input Map, donde las podés reasignar (sección 5.8).
3. Abrí `addons/rts_kit/examples/minimal_2d/minimal_2d.tscn` y apretá F6: es lo que arman las secciones 2 y 3, en 2D. `skirmish_3d` (o `skirmish_2d`) tiene todo lo demás de esta guía.

## 2. Una unidad

Una unidad es una escena tuya (un `CharacterBody3D`, un `CharacterBody2D`, cualquier cuerpo) con un hijo **RtsUnit**.

```
Soldier (CharacterBody3D)        # tu cuerpo, tu script
├── CollisionShape3D             # en la capa de unidades (la 2 por defecto): los clics la encuentran
├── MeshInstance3D
├── SelectionRing                # lo que muestres mientras está elegida
├── NavigationAgent3D            # tu movimiento
└── RtsUnit                      # owner_slot, kind, size…
```

En el inspector de `RtsUnit`:

| Campo | Ponele |
|---|---|
| `owner_slot` | El jugador dueño (1 en un juego de un jugador; 0 = de nadie) |
| `kind` | Su tipo, por ejemplo `soldier`: Ctrl / Cmd + clic elige todos los `soldier` cerca |
| `size` | Su ancho en unidades del mundo (el inspector muestra `m` en 3D y `px` en 2D): las formaciones espacian por la más ancha |
| `center` | Opcional: un `Marker3D` en el medio del cuerpo, para el rectángulo de selección |

Después, **el script de tu unidad** hace lo que el kit no puede: camina, pelea y avisa.

```gdscript
# soldier.gd, código de tu juego: el soldado camina hasta el lugar de su orden, avisa cuando
# llegó y deja de ser una unidad cuando muere.
extends CharacterBody3D

@export var speed := 6.0

var order: RtsUnitOrder

@onready var unit: RtsUnit = $RtsUnit
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var ring: Node3D = $SelectionRing


func _ready() -> void:
	unit.order_started.connect(_on_order_started)
	unit.order_ended.connect(_on_order_ended)
	unit.selected_changed.connect(func(on: bool) -> void: ring.visible = on)


func _on_order_started(next: RtsUnitOrder, _replaced: RtsUnitOrder) -> void:
	order = next


func _on_order_ended(old: RtsUnitOrder, _result: StringName) -> void:
	if old == order:
		order = null


func _physics_process(_delta: float) -> void:
	if order == null:
		return
	# spot() es el lugar de esta unidad en la formación; sigue a un cuerpo custodiado que camina.
	agent.target_position = order.spot()
	if agent.is_navigation_finished():
		if order.type.ends_on_its_own:
			unit.complete()   # la siguiente orden de la cola (si hay) arranca sola
		return
	var next := agent.get_next_path_position()
	velocity = (next - global_position).normalized() * speed
	move_and_slide()


func die() -> void:
	# Una unidad muerta sale sola de toda selección y todo grupo.
	unit.selectable = false
	unit.orderable = false
	unit.targetable = false
```

- `order.command` dice qué orden es (`move`, `attack`, `guard`…); `order.target` es el cuerpo sobre el que actuar (un enemigo, un amigo a custodiar) o null. Un juego de verdad persigue y golpea a `order.target` en `attack`, y pelea con lo que se acerque en `guard_area` / `attack_move`; el `RtsExampleWalker` del ejemplo solo camina.
- `ends_on_its_own` está prendido en `move` y `attack` (avisá `complete()` al llegar / cuando el blanco murió) y apagado en `guard`, `guard_area`, `attack_move` y `retreat` (siguen hasta que otra orden las reemplaza).
- ¿Algo salió mal (no hay camino)? `unit.fail(&"no_path")`.

**2D** es igual con un `CharacterBody2D`, un `CollisionShape2D` en la capa 2 y `order.spot_2d()`: es el `soldier.gd` de `examples/minimal_2d` (camina en línea recta, sin `NavigationAgent2D`). En 2D las unidades del mundo son **píxeles**: poné `RtsUnit.size` en píxeles (el inspector muestra `px`; sección 5.6).

## 3. El equipo de mando

El equipo de mando es **un nodo**: una escena del kit con todas las piezas ya conectadas entre sí.

1. Arrastrá `addons/rts_kit/rig/rts_command_rig_3d.tscn` a tu escena de batalla (2D: `rts_command_rig_2d.tscn`).
2. En su inspector, asigná **Camera** (tu cámara) y **Ground** (el cuerpo de tu suelo; en 2D es opcional).
3. Poné tu HUD después del equipo en el árbol, en su propio `CanvasLayer`.

```
Battle (Node3D)
├── Ground                         # tu suelo (un StaticBody3D en la capa 1)
├── Units                          # tus unidades
├── Camera                         # RtsCamera3D (2D: RtsCamera2D)
├── Rig                            # rts_command_rig_3d.tscn: camera = Camera, ground = Ground
└── Hud (CanvasLayer)              # tu HUD, después del equipo
```

Apretá F6: arrastrá un rectángulo sobre tus unidades, hacé clic derecho en el suelo, y van en línea. Si falta un socket, el nodo muestra un aviso en el editor (el triángulo amarillo) que dice cuál.

**Qué hace cada socket.** `camera` le dice al equipo desde dónde se mira (y a un `RtsCamera` sin `edge_area` le pone la vista del equipo, así los bordes de la pantalla panean sobre el mundo y se frenan sobre tu HUD). `ground` dice qué es suelo: los edificios de la misma capa no cuentan. `menu` es opcional (sección 4).

**Qué hay adentro.** Las piezas del kit, cada una un nodo chico que hace una cosa:

```
Rig (RtsCommandRig)
├── Command                        # RtsCommandInput
│   ├── Selection                  # RtsSelection
│   ├── Orders                     # RtsOrders
│   ├── Pointer                    # RtsPointer
│   ├── State                      # RtsCommandState
│   ├── Armed                      # RtsArmedCommand
│   ├── OrderInput                 # RtsOrderInput
│   ├── SelectInput                # RtsSelectInput
│   ├── GroupKeys                  # RtsGroupKeys
│   ├── OrderButton                # RtsOrderButton
│   └── Probe                      # RtsTargetProbe (para el cursor)
└── ViewLayer (CanvasLayer)
    └── View                       # Control a pantalla completa: toma los clics del mundo
        └── Box                    # Panel: el rectángulo de selección mientras arrastrás
```

**Cómo llegás a una pieza.**

- En el editor: clic derecho sobre `Rig` > **Editable Children**. Las piezas aparecen en el árbol y cada una muestra sus valores en el inspector (el espaciado en `Command/Orders`, el límite de la selección en `Command/Selection`, las teclas en `Command`). También las podés elegir en un socket de tu HUD.
- En código: la raíz las da por nombre (`rig.selection`, `rig.orders`, `rig.order_input`, `rig.armed`, `rig.state`, `rig.command`…).

```gdscript
# El script de tu batalla muestra cuántas unidades hay elegidas.
@export var rig: RtsCommandRig
@export var status: Label


func _ready() -> void:
	rig.selection.changed.connect(
		func(units: Array[RtsUnit]) -> void: status.text = "%d elegidas" % units.size()
	)
```

**`View` distingue «un clic en el mundo» de «un clic en el HUD»**: todo lo del HUD que esté encima conserva sus clics. Por eso tu HUD va después del equipo en el árbol (o en un `CanvasLayer` con una capa más alta).

Capas de física: por defecto el suelo es la capa 1 y las unidades la 2 (`RtsPointer.ground_mask`, `unit_mask`, `pick_mask`). Cambialas en `Command/Pointer` si tu proyecto usa otras.

**Quién soy «yo».** `Command.local_slot` (`rig.command.local_slot`) es el jugador de esta pantalla (1 por defecto) y le pasa ese valor a la selección, las órdenes y el puntero. Solo las unidades de ese slot se pueden elegir y ordenar.

**¿Armarlo a mano?** Se puede: el equipo es solo estos nodos con sus sockets `@export`, y cada pieza anda sola. Los sockets, pieza por pieza:

| Nodo | Sockets |
|---|---|
| `Command` | `selection`, `orders`, `pointer`, `armed`, `state`, `order_input`, `select_input`, `group_keys`, `order_button` (sus hijos) |
| `Selection` | `box` = el `Box` |
| `Pointer` | `camera` = tu cámara; `ground` = el cuerpo de tu suelo |
| `Armed` | `state` |
| `OrderInput` | `selection`, `orders`, `pointer`, `armed`, `state` |
| `SelectInput` | `view` = la `View`, `selection`, `pointer`, `armed`, `order_input` |
| `GroupKeys` | `selection` |
| `OrderButton` | `view` = la `View`, `order_input`, `pointer` (y `menu`, sección 4) |
| `Probe` | `pointer`, `world_view` = la `View` |
| tu cámara | `ground`, `edge_area` = la `View` |

Si tu mundo lee los clics en `_unhandled_input` (sin una `View`), dejá `edge_area` vacío: los bordes igual se frenan sobre los botones y paneles del HUD.

## 4. Cómo da órdenes el jugador

De fábrica, sin ningún menú:

- **Clic derecho**: en el suelo, mover; sobre un enemigo, atacar; sobre un cuerpo propio o neutral, custodiarlo.
- **Teclas**: A / G / M arman atacar / custodiar / mover para el próximo clic izquierdo; R retira; Alt+1..8 guardan una formación; Ctrl+1..0 (Cmd en macOS) guardan un grupo, 1..0 lo eligen, Shift+1..0 le suman.

Encima de eso, la interfaz de comandos que quieras. Todas muestran las mismas entradas (`RtsMenuEntry`: una orden, una formación, o algo tuyo) y las corren igual (`RtsOrderInput.run_entry`).

**Un panel de comandos** (botones, a la manera clásica de los RTS). Sumá al HUD un `GridContainer` con el script `rts_command_card.gd`; con Editable Children prendido en el equipo, poné sus sockets `order_input` (`Command/OrderInput`) y `command_input` (`Command`, por las teclas que muestra). Arma un botón por orden y por formación. Un botón que apunta (atacar) se arma para el próximo clic izquierdo; retirarse pasa ya; una formación la guarda la selección. `skirmish_2d` tiene uno.

**El menú radial** (mantener el botón derecho). Instanciá `addons/rts_kit/ui/radial/rts_radial_menu.tscn` bajo tu HUD y ponelo en el socket **Menu** del equipo. Mantener el botón derecho 0,25 s lo abre donde apretaste; lo que soltás corre en ese punto; el centro cancela. Su layout es una lista de anillos: por defecto uno con todas las órdenes y otro con todas las formaciones; editá `rts_default_layout.tres` (o una copia) para elegir. `skirmish_3d` tiene uno.

**El tuyo.** Un botón en cualquier lado: `button.pressed.connect(func() -> void: rig.order_input.run_entry(entry))`. Un menú que se abre en un punto (una lista, una torta tuya): un script que `extends RtsOrderMenu` y redefine `open_at`, `point_at`, `confirm`, `cancel` e `is_open`; ponelo en el socket **Menu** del equipo.

Si sacás cualquiera, el clic derecho y las teclas siguen andando.

## 5. Hacelo tuyo

### 5.1 Tus tipos de orden

Las órdenes son datos. Hacé un recurso nuevo **RtsCommandCatalog**, sumale ítems **RtsCommandType** y ponelo en `Command/Orders.commands` y en `Command/Armed.commands` (Editable Children). Arrancá desde una copia de `addons/rts_kit/commands/commands.tres`. Una orden de «mantener posición», por ejemplo:

| Campo | Valor |
|---|---|
| `id` | `hold` |
| `display_name` | `Hold position` |
| `target` | `NONE` (no apunta a nada: pasa ya) |
| `uses_formation` | apagado (cada unidad se queda donde está) |
| `ends_on_its_own` | apagado |

Dale una tecla: sumá una acción `my_hold` al Input Map y `my_hold → hold` a `Command.command_keys`. El script de tu unidad atiende `order.command == &"hold"` (frenar, pelear solo con lo que entre en rango). Aparece sola en el panel de comandos y en el menú radial.

### 5.2 Tus formaciones

Extendé `RtsFormation` y devolvé los lugares (derecha, adelante) para `count` unidades:

```gdscript
# column_formation.gd: una formación tuya, en fila india detrás del punto de la orden.
class_name ColumnFormation
extends RtsFormation


func slots(count: int, spacing: float, _target_distance: float, _role: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in count:
		result.append(Vector2(0.0, -i * spacing))
	return result
```

Creá un recurso `ColumnFormation` (id `column`, un nombre), sumalo a una copia de `addons/rts_kit/orders/formations/formations.tres` y ponela en `Command/Orders.formations`. La primera formación del catálogo gana los empates; Alt+N elige la N-ésima.

### 5.3 Reglas de tus unidades

Un script que extiende `RtsUnit` (usalo en vez de `RtsUnit` en tus unidades):

```gdscript
# my_unit.gd: una unidad con reglas tuyas (un pacifista no ataca; un monstruo neutral es enemigo
# de todos).
class_name MyUnit
extends RtsUnit

@export var aggressiveness := 1.0


## Los pacifistas se mueven pero nunca atacan.
func accepts(command: StringName) -> bool:
	if aggressiveness <= 0.0 and command in [&"attack", &"attack_move"]:
		return false
	return super.accepts(command)


## Los monstruos neutrales muerden a todos.
func is_foe(other: RtsUnit) -> bool:
	return team_id() == 0 or super.is_foe(other)
```

Para un pacifista solo no hace falta script: `refused = [attack, attack_move]` en el inspector.

### 5.4 Qué significa un clic derecho

`Command/OrderInput.context_orders` mapea lo que hay bajo el puntero a una orden: `enemy`, `own`, `ally`, `neutral`, `other` (un cuerpo que no es unidad) y `ground`. Sumá clases de tu juego con `classify`:

```gdscript
# Un clic derecho sobre un cadáver ordena custodiar el lugar donde está.
# En el script de tu batalla:
@export var rig: RtsCommandRig


func _ready() -> void:
	rig.order_input.classify = func(body: Node) -> StringName:
		return &"corpse" if body.is_in_group(&"corpse") else &""
	rig.order_input.context_orders[&"corpse"] = &"guard_area"
	rig.order_input.point_contexts.append(&"corpse")   # ordenar en su lugar, no sobre el cuerpo
```

### 5.5 Hechizos, edificios y otras cosas que se arman

```gdscript
# Un botón arma una bola de fuego; el próximo clic izquierdo en el suelo la lanza ahí.
@export var rig: RtsCommandRig


func _ready() -> void:
	rig.select_input.armed_clicked.connect(_on_armed_click)


func _on_fireball_button() -> void:
	rig.armed.arm(&"fireball", fireball_data)   # el cursor lo muestra; un clic derecho lo cancela


func _on_armed_click(mode: StringName, screen: Vector2) -> void:
	if mode != &"fireball":
		return
	var point: Variant = rig.pointer.ground_at(screen)
	if point == null:
		rig.state.say(RtsRefusal.NO_GROUND)   # hace destellar la señal de rechazo
		return
	cast_fireball(point, rig.armed.payload)
	rig.armed.mode = &""   # o dejalo armado para otro lanzamiento
```

Mientras está armado, un **RtsArmedPreview** (sockets `armed`, `state` y `pointer` del equipo; el callable `answer`) le puede preguntar a tu regla qué contestaría un clic, así el cursor pasa a «bloqueado» antes de que el jugador haga clic.

### 5.6 2D: distancias en píxeles

En 2D el mundo se mide en píxeles, y las distancias del kit se escriben en la unidad del mundo. El inspector muestra cuál es al lado de cada valor: `px` cuando el nodo cuelga de un `Node2D`, `m` cuando cuelga de un `Node3D`.

- `rts_command_rig_2d.tscn` ya las trae en píxeles: `Orders.spacing_base` 8, `max_spacing` 120, `retarget_range` 1200 y `Selection.same_type_radius` 600. Cambialas con Editable Children si tus unidades son mucho más grandes o más chicas.
- `RtsUnit.size` lo ponés vos en cada unidad, en píxeles: su ancho (unos 34 para un cuerpo de 28 px).
- Si armás las piezas a mano, los valores por defecto de `RtsOrders` y `RtsSelection` son metros: en 2D poné los tuyos.

### 5.7 Cámara

- Una vista cenital libre: `RtsCamera3D.mode = FREE`, `bounds` con tu mapa, `free_min_distance` / `free_max_distance` para el zoom.
- Un RTS con héroe: `mode = FOLLOW` y `set_follow(hero)`.
- Las dos: cambiá `mode` al correr (los ejemplos lo hacen con F).
- 2D: `RtsCamera2D` con `bounds`, `min_zoom`, `max_zoom`; `can_turn` para que Q / E giren la vista.
- Un temblor: un script que extiende `RtsCameraEffect`, en `effect`.
- Táctil: no hay nada que hacer. Un dedo arrastra el mapa, dos pellizcan y giran, un toque selecciona. Ajustá `touch_drag_px`, `pinch_zoom` y `twist_turn`; poné `touch_enabled = false` si tu juego lee los dedos por su cuenta.
- Un mapa de estrategia, donde arrastrar con el botón izquierdo lo mueve: `select_drag_pans = true`.
- Deslizarse hasta un punto (una alerta, una unidad): `camera.focus(point, seconds)`.

### 5.8 Teclas

Reasigná cualquier acción en Configuración del proyecto > Input Map: el kit solo agrega las que faltan. Las teclas para guardar grupos usan Cmd en macOS; poné `Command.command_on_macos = false` (Editable Children) para usar Ctrl en todos lados (vale solo para las que agrega el kit).

### 5.9 Menús, pausa y el HUD

Una pantalla de pausa u opciones entra al grupo `rts_modal` mientras está abierta (`add_to_group(RtsWorldInput.modal_group)`): ningún clic, tecla, borde ni rueda llega al mundo. Un panel de tu HUD conserva sus clics mientras tu HUD esté después del equipo en el árbol.

### 5.10 El cursor y las palabras

Hacé un recurso **RtsCueSet**: las imágenes del cursor según lo que hay bajo el puntero, el ícono de cada orden armada, el ícono de rechazo y las palabras de cada rechazo (`reason_texts`, traducidas con `tr`). Usalo en `Command/State.cues` (Editable Children), en `Cue.cues` y en un `RtsCursorSkin`; los sockets `state` y `probe` de esos dos apuntan a `Command/State` y `Command/Probe`.

## 6. Multijugador con MpKit

RtsKit no tiene red y nunca nombra a MpKit; unas pocas líneas de **tu** código los conectan. Esta sección supone un mundo que ya anda con MpKit (el `QUICKSTART.md` de MpKit: un `MpGame`, un boot con `MpFlow`, un mundo con `MpWorld`).

**El modelo.** El servidor corre las reglas: aplica las órdenes y mueve las unidades. Un cliente le manda sus órdenes al servidor y ve moverse las unidades por la sincronización de MpKit. El servidor revisa cada unidad de una orden contra el slot del jugador que la mandó, así que un cliente solo puede ordenar sus propias unidades.

### 6.1 Unidades que ven todos

En la escena de la unidad, sumá un **MpActor** junto al `RtsUnit`: sincronizá posición y rotación, y en *Extra* las banderas de la unidad que necesitan los clientes:

```
RtsUnit:selectable
RtsUnit:targetable
```

En el script de la unidad, tomá el dueño del MpActor (el spawn se lo lleva a cada peer antes de `_ready`) y corré la lógica de la unidad solo en el servidor:

```gdscript
# La unidad toma su dueño del MpActor y solo el servidor la mueve.
@onready var net: MpActor = $MpActor


func _ready() -> void:
	unit.owner_slot = net.owner_slot
	# … el resto de la sección 2


func _physics_process(_delta: float) -> void:
	if not net.is_authority():   # los clientes solo dibujan lo que manda el servidor
		return
	# … el movimiento de la sección 2
```

Hacé aparecer las unidades en el servidor con un **MpSpawner** (`GUIDE.md` de MpKit, 7.2): un nodo vacío `Units`, un `MpSpawner` con `spawn_path = ../Units` y la escena de tu unidad en **Extra Scenes**. Después, en el servidor:

```gdscript
# El servidor hace aparecer seis soldados por jugador, cada grupo en el punto de su asiento.
const SOLDIER := preload("res://units/soldier.tscn")

@export var spawner: MpSpawner
## Los SpawnPoints del MpWorld: un marcador por asiento.
@export var spawn_points: Node


func _spawn_armies() -> void:
	if not MpKit.is_authority():
		return
	for slot in MpKit.occupied_slots():
		var start: Vector3 = (spawn_points.get_child(slot - 1) as Node3D).global_position
		for i in 6:
			spawner.spawn_actor(SOLDIER, {"position": start + Vector3(i * 2.0, 0, 0)}, slot)
```

### 6.2 Órdenes por la red

Un nodo de tu juego manda las órdenes del jugador local por el canal propio de MpKit y aplica en el servidor las que llegan. No se escribe ningún RPC a mano, y el mismo código anda en una partida de un jugador (MpKit entrega el mensaje localmente):

```gdscript
# rts_network.gd, código de tu juego: las órdenes del jugador local viajan al servidor por el
# canal propio de MpKit, y el servidor las aplica como el jugador que las mandó.
extends Node

const CHANNEL := &"rts_order"

@export var rig: RtsCommandRig
## Dónde están las unidades (el spawn_path del MpSpawner): una orden nombra a las unidades por el nombre de su nodo.
@export var units_root: Node


func _ready() -> void:
	MpKit.custom_received.connect(_on_custom)
	rig.orders.send = func(order: RtsOrder) -> void:
		MpKit.send_custom(CHANNEL, {"order": order.to_array(_id_of)})


func _on_custom(channel: StringName, data: Dictionary, from_peer: int) -> void:
	if channel != CHANNEL or not MpKit.is_authority():
		return
	var slot := MpKit.slot_for_peer(from_peer) if MpKit.is_networked() else MpKit.local_slot()
	rig.orders.apply(RtsOrder.from_array(data.get("order"), self, _node_of), slot)


func _id_of(body: Node) -> String:
	return String(body.name)


func _node_of(id: String) -> Node:
	return units_root.get_node_or_null(NodePath(id))
```

- Si tu `MpGame` tiene una lista `custom_channels`, sumale `rts_order` (una lista vacía permite todos los canales).
- Las unidades viajan por el nombre de su nodo: unos pocos bytes cada una. MpKit rechaza un mensaje propio más grande que `custom_max_bytes` (8 KB) y más de unos 30 por segundo por jugador: entran cientos de unidades por orden.
- `RtsOrder.from_array` rechaza datos mal formados, y `apply` rechaza unidades de otro slot: un cliente modificado no puede ordenar lo que no es suyo.

### 6.3 Quién soy «yo»

El jugador de esta pantalla es el slot local de MpKit. En el script de tu batalla:

```gdscript
# El jugador de esta pantalla es el slot local de MpKit; un servidor dedicado no tiene jugador.
@export var rig: RtsCommandRig
@export var hud: CanvasLayer


func _ready() -> void:
	rig.command.local_slot = MpKit.local_slot()
	if MpKit.is_dedicated():
		# Ni selección ni HUD.
		rig.process_mode = Node.PROCESS_MODE_DISABLED
		hud.visible = false
```

Equipos (2 contra 2): poné `RtsUnit.team` en las unidades y `rig.command.local_team` para el jugador.

### 6.4 Lo que queda local

La selección, los grupos, el cursor, los menús, la cámara y los pings viven en la máquina de cada jugador: nada de eso viaja. Solo viajan las órdenes. Una formación que guarda un jugador (Alt+N) también es una orden (`formation`), así que el servidor la conoce.

## 7. Lista de control

- [ ] Cada unidad tiene un `RtsUnit` con `owner_slot`, `kind` y `size`; las unidades muertas apagan `selectable`, `orderable` y `targetable`.
- [ ] El script de tu unidad escucha `order_started` y llama a `complete()` / `fail()`.
- [ ] El equipo (`rts_command_rig_3d.tscn` o `rts_command_rig_2d.tscn`) está en la escena, con `camera` y `ground` puestos y sin avisos; tu HUD está después en el árbol; el suelo y las unidades están en las capas del puntero.
- [ ] F6: un rectángulo elige solo tus unidades, un clic derecho en el suelo las lleva en formación, sobre un enemigo atacan, Ctrl/Cmd+1 y después 1 recupera el grupo, Alt+N guarda una formación.
- [ ] 2D: el equipo 2D y `RtsUnit.size` en píxeles (el inspector muestra `px`).
- [ ] En red: las unidades las hace aparecer un `MpSpawner` con el slot del dueño; el nodo de pegamento está en el mundo; `local_slot` sale de MpKit; la lógica de la unidad corre solo donde `net.is_authority()`.
