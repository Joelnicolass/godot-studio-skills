# RtsKit

La capa de mando de un juego de estrategia en tiempo real, para **2D y 3D**: unidades, selección y grupos, órdenes tipadas que se reparten en formación, la entrada que las da (clic derecho según el contexto, órdenes armadas, un menú o un panel de comandos opcionales), las señales del cursor y las cámaras de RTS. **Sin** red, **sin** reglas de juego, **sin** autoload. No mueve ninguna unidad ni pelea ninguna pelea: eso lo hace el juego con la orden que el kit le da a cada unidad.

No depende de ningún otro kit. Un juego en red lo conecta con MpKit (o con cualquier transporte) con dos llamadas propias (ver [Red](#red)); un RTS de un jugador no conecta nada.

**¿Nunca usaste el kit?** Empezá por [GUIDE.md](GUIDE.md): una unidad, el equipo, las formas de dar órdenes, cómo hacer tuya cada parte y el multijugador con MpKit, paso a paso.

## Instalar

```bash
./install.sh --addon /path/to/godot-project rts_kit
```

Habilitá el plugin **RtsKit**. Proyecto > Herramientas > *RtsKit: Add default input actions* escribe las teclas por defecto en el Input Map para que las puedas reasignar ahí (sin eso, `RtsCommandInput` agrega las que falten al correr).

## Un mismo suelo para 2D y 3D

El kit piensa en un solo espacio (`RtsSpace`): el suelo es el plano XZ e Y es arriba, las coordenadas del mundo 3D tal como son. Un punto del mundo 2D `(x, y)` es el punto del kit `(x, 0, y)`: visto desde arriba, un campo 3D y un mapa 2D cenital son el mismo dibujo, así que una formación, una distancia y un yaw sirven para los dos. Solo convierten los bordes: `RtsSpace.from_2d` / `to_2d`, `RtsUnitOrder.spot_2d()`.

Las unidades del mundo son metros en 3D y **píxeles en 2D**. Las distancias que expone el kit (`RtsOrders.spacing_base`, `max_spacing`, `retarget_range`, `RtsSelection.same_type_radius`, `RtsUnit.size`) vienen en metros: un juego 2D las pone en píxeles (el ejemplo 2D lo muestra).

Yaw: adelante es `(sin yaw, 0, cos yaw)` y la derecha `(-cos yaw, 0, sin yaw)`. Las cámaras y `RtsPointer.camera_yaw()` dan el yaw con el que gira una formación: hacia donde mira la vista en 3D, hacia arriba de la pantalla en 2D.

## El equipo

```
Juego
├── Units / …                      # tus cuerpos, cada uno con un hijo RtsUnit
├── Camera                         # RtsCamera3D o RtsCamera2D
├── Command                        # RtsCommandInput: reparte las teclas, comparte local_slot
│   ├── Selection                  # RtsSelection
│   ├── Orders                     # RtsOrders: quién obedece, formaciones, lugares
│   ├── Pointer                    # RtsPointer: pantalla -> mundo
│   ├── State                      # RtsCommandState: qué está armado, qué se dijo
│   ├── Armed                      # RtsArmedCommand
│   ├── OrderInput                 # RtsOrderInput: clic derecho, clics armados, entradas de menú
│   ├── SelectInput                # RtsSelectInput: botón izquierdo y rectángulo
│   ├── GroupKeys                  # RtsGroupKeys
│   ├── OrderButton                # RtsOrderButton: el botón derecho (+ un menú opcional)
│   └── Probe                      # RtsTargetProbe: qué hay bajo el puntero (cursor, señal)
└── Hud (CanvasLayer)
    ├── View                       # un Control a pantalla completa que toma los clics del mundo
    │   └── Box                    # el rectángulo de selección (cualquier Control)
    ├── CommandCard                # opcional: RtsCommandCard, botones para cada orden
    ├── RadialMenu                 # opcional: rts_radial_menu.tscn (un RtsOrderMenu)
    └── Cue                        # opcional: rts_command_cue.tscn
```

Cada pieza es un nodo con sockets `@export`; si sacás uno, ese comando desaparece y nada más se rompe. Los dos ejemplos traen el equipo entero conectado: `examples/skirmish_3d` (con el menú radial) y `examples/skirmish_2d` (sin ningún menú: un clic derecho simple y el panel de comandos).

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

`RtsCamera3D` y `RtsCamera2D` comparten un contrato: `yaw`, `is_dragging()` (un clic que termina un arrastre no es una orden), `focus(point)`, `debug_pointer`. El modo FOLLOW mantiene un cuerpo a la vista (3D: tercera persona detrás de él, gira con las teclas, los bordes y la mirada libre, zoom con la rueda; el ojo nunca baja del suelo, incluido el suelo vivo de `height_at`). El modo FREE es la vista cenital: paneo con las flechas, los bordes de la pantalla y arrastrando con el botón del medio, giro con Q / E (3D), zoom con la rueda, siempre dentro de `bounds`. `edge_area` limita los bordes a la vista del mundo; `wheel_blockers` saca la rueda de encima de un minimapa. `RtsCameraEffect` suma un temblor encima.

## Señales y pings

`RtsTargetProbe` nombra lo que hay bajo el puntero; `RtsCursorSkin` pone el cursor de hardware desde un `RtsCueSet`; `rts_command_cue.tscn` dibuja el ícono armado junto al puntero y hace destellar los rechazos con sus palabras (`RtsCueSet.reason_text`). `RtsArmedPreview` le pregunta a tu regla qué contestaría un clic mientras hay algo armado (un edificio que no puede ir ahí). `RtsPing3D` / `RtsPing2D` marcan adónde fue una orden.

## Tests

```bash
godot --headless --path rtskit_lab --script res://addons/rts_kit/tests/rts_test_runner.gd
```

`RTSKIT TESTS PASS (n)`. Cubren los lugares de las formaciones, quién obedece, el reparto de lugares (greedy y por filas), el re-blanco y la retirada, los datos simples de una orden, la cola, la selección (clic, tipo, rectángulo en 2D y 3D con oclusión, límite, grupos), la entrada sobre colisiones reales (puntero, contexto, ciclo de armado, rectángulo con eventos de mouse, el menú radial, el panel de comandos, las teclas, los modales), las dos cámaras, y los dos ejemplos jugados de punta a punta. `rtskit_lab/` es un proyecto aparte para ellos; ahí `addons/rts_kit` es un symlink.

## Lo que no trae esta versión

El movimiento de las unidades (pathfinding, avoidance), la visión y la niebla de guerra, un minimapa y el combate son del juego por ahora; RtsKit 0.3–0.5 suman movimiento, visión y minimapa, y la 0.2 los controles modernos (más teclas de grupos y de selección, colas con Shift y waypoints, puntos de reunión, patrullar, mantener posición, posturas, posiciones de cámara, alertas). Ver `CHANGELOG.md`.
