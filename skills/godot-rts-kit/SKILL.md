---
name: godot-rts-kit
description: >-
  Agrega controles de RTS a un juego Godot 4, 2D o 3D, con el addon RtsKit:
  unidades (RtsUnit), selección y grupos, órdenes tipadas en formación, clic
  derecho según el contexto, órdenes armadas, un panel de comandos o menú radial
  (opcionales), señales del cursor, cámaras de RTS. Usar cuando el usuario quiere
  un RTS, seleccionar unidades, rectángulo de selección, grupos de control,
  formaciones, attack-move, un panel de comandos o /add-rts-controls. No es
  pathfinding ni combate (son del juego). Sin red adentro: MpKit lo conecta el juego.
---

# Godot — controles de RTS (RtsKit)

Addon `addons/rts_kit/` en el **proyecto del juego**. Paso a paso (una unidad, el equipo, hacerlo del juego, MpKit): `addons/rts_kit/GUIDE.md`. Referencia: `addons/rts_kit/README.md`; API por pieza: [api.md](api.md).

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project rts_kit
```

Habilitá el plugin **RtsKit**. Pedido acotado: `/add-rts-controls`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **El kit manda, el juego actúa.** RtsKit decide quién obedece, la formación y el lugar de cada unidad; el juego mueve el cuerpo y pelea (escucha `RtsUnit.order_started` y llama a `complete()` / `fail()`). No pongas movimiento, daño ni IA dentro de los nodos del kit.
- **Ningún kit depende de otro.** RtsKit no tiene red y nunca nombra a MpKit ni a FsmKit. El multijugador es pegamento en el juego: `orders.send` manda `order.to_array()`; el servidor llama a `orders.apply(RtsOrder.from_array(data, self), sender_slot)`. Con MpKit: su canal propio, las unidades por el nombre de su nodo (GUIDE › 6). El comportamiento de una unidad puede ser una máquina de FsmKit que el juego conecta a `order_started`.
- **Un mismo suelo para 2D y 3D.** Los puntos del kit son 3D (`Vector3`, suelo en XZ). Un punto 2D `(x, y)` es `(x, 0, y)`: `RtsSpace.from_2d` / `to_2d`, `order.spot_2d()`. En 2D las unidades del mundo son píxeles: poné `RtsOrders.spacing_base`, `max_spacing`, `retarget_range`, `RtsSelection.same_type_radius` y `RtsUnit.size` en píxeles.
- **Datos, no código, para tipos de orden y formaciones.** Una orden nueva = un `RtsCommandType` en un catálogo `.tres`; una forma nueva = un script que `extends RtsFormation`. Una regla de una unidad (pacifista, un enemigo que no es «otro equipo») = un script que `extends RtsUnit` y redefine `accepts` / `is_foe`.
- **Los menús son opcionales.** El botón derecho (`RtsOrderButton`) anda sin menú. Las interfaces de comandos muestran `RtsMenuEntry` y llaman a `RtsOrderInput.run_entry(entry, screen)`: `RtsCommandCard` (botones), `RtsRadialMenu` (anillos), o la del juego (`extends RtsOrderMenu`).
- **Los modales bloquean el mundo**: una pausa / opciones entra a `RtsWorldInput.modal_group` mientras está abierta.

## Árbol

```
Juego
├── Units/…                 # cuerpos, cada uno con un hijo RtsUnit (+ la lógica de unidad del juego)
├── Camera                  # RtsCamera3D / RtsCamera2D
├── Command                 # RtsCommandInput
│   ├── Selection, Orders, Pointer, State, Armed
│   ├── OrderInput, SelectInput, GroupKeys, OrderButton
│   └── Probe               # opcional (cursor y señal)
└── Hud
    ├── View (+ Box)        # Control a pantalla completa: los clics del mundo
    ├── CommandCard         # opcional
    ├── RadialMenu          # opcional
    └── Cue                 # opcional
```

Arrancá desde `addons/rts_kit/examples/minimal_2d/minimal_2d.tscn` (lo mínimo: el equipo de la GUIDE › 3 y seis soldados cuyo `soldier.gd` es el script de unidad de la GUIDE › 2 en 2D), `skirmish_3d/skirmish_3d.tscn` (menú radial, cursor, pings) o `skirmish_2d/skirmish_2d.tscn` (sin menú, panel de comandos): el equipo viene conectado en el inspector.

## Qué va dónde

| Kit | Juego |
|---|---|
| Quién se puede elegir y ordenar, los grupos, la formación, cada lugar | Caminar hasta `order.spot()`, pathfinding, avoidance |
| Qué orden significa un clic derecho acá (`context_orders`, `classify`) | Daño, muerte (`selectable = false`, `orderable = false`), IA |
| Órdenes armadas, el cursor, los rechazos | Hechizos y edificios (se arman con `armed.arm(&"modo", payload)` y se responde `armed_clicked`) |
| `request` / `apply` / `to_array` | El transporte (RPC, MpKit), quién es el servidor |

## Listo cuando

- F6: un rectángulo elige solo unidades propias; un clic derecho en el suelo las lleva en formación; sobre un enemigo lo atacan; Ctrl/Cmd+1 y después 1 recupera el grupo; Alt+N guarda una formación.
- Si sacás los nodos del menú / panel de comandos, el clic derecho simple sigue andando.
- `godot --headless --path rtskit_lab --script res://addons/rts_kit/tests/rts_test_runner.gd` → `RTSKIT TESTS PASS` (en el repo del kit).

## Anti-patrones

- Mover unidades desde `RtsOrders`, o una subclase de `RtsUnit` que además hace pathfinding y pelea.
- Un RPC o una llamada a `MpKit` dentro de un nodo de `addons/rts_kit`.
- Copiar un script del kit al juego «para ajustarlo un poco» en vez de `extends` o un catálogo `.tres`.
- Distancias en metros en un juego 2D (las unidades se amontonan en un píxel).
