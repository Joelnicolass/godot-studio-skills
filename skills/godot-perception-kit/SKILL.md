---
name: godot-perception-kit
description: >-
  Le da sentidos a un actor de Godot 4 con el addon PerceptionKit, en 2D y 3D: un
  cono de vista que empieza a ver a una distancia y sigue viendo hasta otra más
  lejana, conciencia de lo cercano en todas las direcciones, muros que tapan,
  ruidos oídos por distancia, cualquier sentido propio del juego (luz, alarmas,
  golpes), una memoria que olvida con la última posición conocida, bandos como
  capas de física, y manijas para arrastrar la vista en el editor. Usar cuando el
  usuario quiere enemigos o guardias que ven u oyen al jugador, sigilo, conos de
  visión, línea de visión, oír ruidos, conciencia o alerta de la IA, investigar
  la última posición conocida, oscuridad o luz que cambian la detección, o
  /add-perception. No es lo que hace el actor con eso (su máquina de estados,
  perseguir, combate) ni la red.
---

# Godot — percepción (PerceptionKit)

Addon `addons/perception_kit/` en el proyecto del **juego**. Referencia: `addons/perception_kit/README.md`; API por pieza: [api.md](api.md).

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project perception_kit
```

Habilitá el plugin **PerceptionKit** (las manijas del editor; los nodos andan sin él). Pedido acotado: `/add-perception`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md); los estados del actor: [godot-fsm](../godot-fsm/SKILL.md).

## Reglas

- **La persona dimensiona la vista, el agente la arma.** Vista, pérdida, ángulo, cercanía y altura de ojos se arrastran con las manijas del sensor en la escena del actor (vista 2D o 3D; cada arrastre se deshace). El agente agrega los nodos con valores iniciales y le dice a la persona cómo arrastrarlos; nunca los ajusta por código en ejecución.
- **Dos nodos.** Un `PerceptionSensor3D` (o 2D) en la cabeza del actor (mira hacia -Z; en 2D hacia +X), un `PerceptionTarget3D` (o 2D) en lo que se ve, donde se lo ve (el pecho). Sus esferas son internas; no hay que agregar ningún CollisionShape.
- **Los bandos son capas de física.** La capa de colisión de un objetivo es su bando; la máscara de un sensor es lo que ve. Nombrá una capa por bando en Project Settings; de entrada todo está en la capa 32. Nada de enum de facciones ni grupos.
- **Los valores viven en el nodo que los usa** (`@export`): los radios del sensor, el ángulo, `memory_s`, `sense_hz`, las escalas; la `visibility` y el `kind` del objetivo. Los valores de cada actor en la escena del actor, un archivo.
- **Los estados leen, las señales empiezan y terminan.** `perceived` arranca una alerta, `forgotten` la termina; mientras dura, los estados leen `latest()` (adónde mirar o ir), `sees_any()`, `is_aware()`. El kit no tiene máquina de estados; la del juego (FsmKit o la suya) lee el sensor por una referencia exportada.
- **Los ruidos los pone el juego.** La señal de ruidos del juego llama a `sensor.hear(position, radius, source)` en los sensores que escuchan; `source` deja un solo recuerdo por quien hace el ruido. Otros sentidos: `sensor.sense(&"kind", position, strength, source)`.
- **La luz y la oscuridad son números.** El juego pone `target.visibility` (sombra, cobertura), `sensor.sight_scale` (noche, niebla) y `reach_by_kind` (`{&"light": 2.5}` para una linterna que es su propio objetivo de tipo light). Cualquier otra cosa: un script `extends PerceptionSensor3D` que sobrescribe `_sight_radius(target, seen, radius)` (y `reach_m()` si devuelve más).
- **Ningún kit depende de otro.** PerceptionKit no tiene red: un juego en red pone `enabled = <es autoridad>` y sincroniza lo que hace el actor, nunca la percepción.
- **El costo son las miradas.** `sense_hz` (5) por la cantidad de sensores; cada sensor en su propio momento, un rayo por candidato que pasa el radio y el ángulo. Bajá `sense_hz`, después los radios.

## Árbol

```
Guard (CharacterBody3D)           # el cuerpo propio del sensor: se encuentra solo, nunca le tapa la vista
├── Head (Node3D)                  # lo que gira para mirar
│   └── Perception (PerceptionSensor3D)   # máscara: los bandos que ve; occlusion_mask: los muros
└── States (la máquina de estados del juego)   # lee Perception: latest(), sees_any(), is_aware()

Player (CharacterBody3D)
└── Seen (PerceptionTarget3D)      # en la capa de su bando, en el pecho
```

Arrancá desde `addons/perception_kit/examples/minimal_3d/minimal_3d.tscn` (un guardia que gira la cabeza), `minimal_2d` (lo mismo en 2D) o `guards_3d` (vigilar, mirar, buscar, volver; un ruido, una linterna, la noche, la sombra).

## Qué va dónde

| Kit | Juego |
|---|---|
| La vista, el radio de pérdida, la cercanía, los muros, la memoria | Lo que hace el actor (estados, niveles de alerta, perseguir, combate) |
| `hear()`, `sense()` | De dónde salen los ruidos y hasta dónde llegan |
| `visibility`, `sight_scale`, `reach_by_kind`, `_sight_radius()` | La luz, la oscuridad, la cobertura y lo que significan |
| Capas como bandos, `enabled` | Qué bandos hay, quién percibe en un juego en red |

## Listo cuando

- El sensor no muestra avisos; su vista se ve en la vista 3D (o 2D) y la persona sabe arrastrar sus manijas.
- F6 con `show_in_game`: gris, rojo cuando ve al objetivo, ámbar después, gris al olvidarlo; un muro tapa; un ruido lo hace girar.
- Los estados del actor reaccionan a `perceived` / `forgotten` y leen `latest()`.
- `godot --headless --path perceptionkit_lab --script res://addons/perception_kit/tests/perception_test_runner.gd` da `PERCEPTIONKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- Un manager o registro de todos los enemigos que chequea a todos los jugadores en cada frame: cada sensor mira por su cuenta, unas pocas veces por segundo.
- Tirar rayos en cada frame desde el script del actor: `sense_hz` y el rayo propio del sensor.
- Bandos como un enum o un grupo chequeados en código: son capas, filtradas por el motor de física.
- Agregar un CollisionShape debajo de un sensor o un objetivo: sus esferas son internas y salen de los valores.
- Ajustar los radios por código en ejecución para el nivel de una persona: se arrastran las manijas; el código cambia `sight_scale` y `visibility`.
- Percibir en todos los peers de un juego en red: `enabled` solo donde decide el juego (el servidor).
- El sensor debajo del cuerpo del actor sin `body` encontrado (sin cuerpo de física arriba): su propio collider le tapa la vista; poné `body`.
