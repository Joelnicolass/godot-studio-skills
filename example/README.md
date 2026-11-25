# MpKit Example

Demo mínima del [Godot studio kit](../README.md): **no es un juego**. Enseña MpKit (1P, listen-server, dedicated), composición, Resources `.tres` y el flujo de producto (PRD → FEATURES → RULES → RFCs → código).

Arquitectura: **por entidad** (una carpeta por tema; ver [`docs/architecture.md`](docs/architecture.md)). Arte: placeholders. UI en español en esta rama: los textos están en `locale/texts.csv` y el idioma sale de `internationalization/locale/*` en `project.godot`. Dónde cambiar cada cosa: [`docs/tuning.md`](docs/tuning.md).

## Abrir

Godot **4.7**. Abrí la carpeta `example/` como proyecto.

Si el addon falta o se desactualizó, desde la raíz del studio kit:

```bash
./install.sh --addon-only example
```

El plugin **MpKit** ya está enabled y el autoload `MpKit` va **antes** de `NetSession`. Para CLI de agentes, instalá AgentKit desde [godot-studio-playtest](https://github.com/Joelnicolass/godot-studio-playtest) (`./install.sh --addon-only example agent_kit` desde este kit).

## Jugar

| Modo | Cómo |
|------|------|
| **1P** | F5 → Jugar solo. Toggle 2D/3D. WASD/flechas, **E** emote. |
| **LAN** | Instancia A: Host LAN (aparece en **Salas LAN**). Instancia B: click en la sala o Unirse `127.0.0.1`. Debug → Run Multiple Instances. |
| **Dedicated** | Ver abajo. El servidor **no** es un jugador. |

F6: `player/pawn_2d.tscn`, `player/pawn_3d.tscn`, `levels/match_2d/match_2d.tscn`, `levels/match_3d/match_3d.tscn`. Para ver el pawn 3D con cámara y piso: `debug/pawn_3d_preview.tscn`.

## Dedicated (mismo proyecto)

```bash
godot --headless --path example -- --dedicated
# opcional: --world=3d --mp-port=7777
```

Después, un cliente editor: Unirse `127.0.0.1`.

`--headless` **solo** no es dedicated (GUT/CI también van headless). Hace falta `-- --dedicated`, la etiqueta `dedicated_server`, o un export Dedicated Server. En Ejecutar Instancias, si no marcás **Anular argumentos**, Godot puede ignorar los Argumentos de Inicio de esa fila.

## Qué mirar

| Pieza | Dónde | Rol |
|-------|--------|-----|
| Transporte | `addons/mp_kit/` | ENet, slots, túnel. Cero gameplay. |
| Autoload | `autoloads/net_session.tscn` | `extends MpFlow`: catálogo `2d`/`3d` + emote; sus números, en el inspector |
| Textos | `locale/texts.csv` | Una clave por texto, columnas `es` y `en` |
| Match | `match/demo_match.tscn` | Snapshot `elapsed` (no spawn) |
| Spawn | `MpSlotSpawner` en `levels/match_2d/` y `levels/match_3d/` | Un pawn por slot |
| Chequeos de red | `debug/spawn_lab/`, `agent/` | Laboratorio de spawn + playtest AgentKit |
| Pawns | `player/` | `submit_move` / `apply_move`, `MpReplicate`, pipe |
| Tipos | `player/pawn_*_type.tres` | Color, letra, velocidad — no `if kind` |
| Perillas | `docs/tuning.md` | Qué cambiar, y en qué archivo, nodo y propiedad |
| Producto | `PRD.md`, `FEATURES.md`, `RULES.md`, `RFCs/` | Flujo del estudio |

## Chequeos de red

Dos scripts, un solo grupo de procesos de Godot a la vez (no los corras mientras corren otras pruebas de Godot):

```bash
debug/spawn_lab/run_lab.sh            # headless: laboratorio de MpSpawner
agent/run_mp_playtest.sh              # con ventana: flows AgentKit sobre este demo + el laboratorio
```

- **Laboratorio de spawn** (`debug/spawn_lab/`): dedicado + cliente A + cliente B que entra tarde. El servidor spawnea actores con synchronizer, sin synchronizer, con `MpReplicate` y sin synchronizer, y con uno agregado tarde; un nodo estático con sync; dos salas con su propio `MpSpawner` y `room_id`. Levanta al slot 1 de su sala y, en una segunda corrida, recarga el mundo con los dos clientes conectados. `check_lab.py` imprime PASS/FAIL por escenario.
- **Playtest** (`agent/`): 1P 2D/3D, listen host + cliente, dedicado + A + B tardío en 2D y 3D, todo con los botones del boot y el InputMap. Necesita AgentKit (`./install.sh --addon example agent_kit` desde la raíz del kit). Capturas y logs en `agent/out/mp/`.

Las corridas en red usan `--max-fps 60`, nunca `--fixed-fps`: corta la sincronización con el tiempo real y un servidor headless termina antes de que conecten los clientes.

## Flujo de producto

Este folder **es** el resultado de `/create-prd` → `/verify-prd` → `/extract-features` → `/generate-rules` → `/generate-rfcs` → `/implement-rfc` 001–004 → `/review-rfc`. Estado: [`WORKFLOW-STATUS.md`](WORKFLOW-STATUS.md) y `reviews/`.

## No está

Puntaje, vidas, Steam, predicción, arte de producción, tests GUT (los chequeos de red de arriba son scripts, no un framework de tests). Eso no va en el kit ni en esta guía.
