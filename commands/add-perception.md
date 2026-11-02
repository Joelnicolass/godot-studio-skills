---
description: "Percepción (addon PerceptionKit): actores que ven dentro de un cono y pierden de vista más lejos, notan lo que tienen cerca, son tapados por muros, oyen los ruidos del juego y recuerdan la última posición conocida, en 2D o 3D, con manijas para arrastrar la vista en el editor."
---

Dale **sentidos a un actor** en el **proyecto Godot del juego** con el addon PerceptionKit: un `PerceptionSensor3D` (o 2D) en su cabeza, un `PerceptionTarget3D` (o 2D) en lo que tiene que ver, los bandos como capas de física y los ruidos del juego llamando a `hear()`. Después la persona dimensiona la vista arrastrando sus manijas en la escena del actor; el agente arma y explica.

Esto **no** es lo que hace el actor con eso (sus estados, perseguir, combate): eso es del juego, que lee el sensor. **No** es la red: un juego en red decide quién percibe (`enabled`). **No** inventa los ruidos ni la luz del juego.

Cargar: `godot-perception-kit`, `godot-composition-first` (y `godot-fsm` para los estados del actor).

Si falta `addons/perception_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT perception_kit
```

Habilitá **PerceptionKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Quién percibe (qué escenas de actor) y qué (el jugador, bots, otros enemigos, linternas); 2D o 3D.
2. Los bandos: quién ve a quién (una capa de física por bando).
3. La vista: hasta dónde, qué tan ancha, qué tan cerca notan lo que tienen atrás; qué tapa (las capas de los muros); la altura de los ojos.
4. El oído: qué ruidos hace el juego (disparos, pasos) y hasta dónde llega cada uno; dónde se emiten hoy.
5. Luz y oscuridad, cobertura, noche: qué cambia qué tan visible es un objetivo, si algo.
6. Qué hace el actor cuando percibe y cuando olvida (sus estados), y si el juego es en red (quién percibe).

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin PerceptionKit; nombres de capa para los bandos (survivors, threats)
[~] scenes/enemies/guard.tscn            # Head > PerceptionSensor3D (máscara: survivors; valores arrastrados con sus manijas)
[~] scenes/player/player.tscn            # PerceptionTarget3D en el pecho, en la capa survivors
[~] scenes/enemies/guard_states/*.gd     # los estados del actor leen el sensor: latest(), sees_any(), is_aware()
[~] scripts/noise.gd                     # la señal de ruidos del juego llama a sensor.hear(position, radius, source)
```

Arrancá desde `addons/perception_kit/examples/minimal_3d` (un guardia que gira la cabeza), `minimal_2d` o `guards_3d` (vigilar, mirar, buscar, volver; ruido, linterna, noche, sombra).

## 3. Implementar

Seguí [godot-perception-kit](../skills/godot-perception-kit/SKILL.md) y `addons/perception_kit/README.md`.

- Poné el sensor en lo que gira para mirar; su cuerpo se encuentra solo (`body`). El objetivo donde se lo ve.
- Nombrá una capa por bando; los objetivos en la capa de su bando, las máscaras de los sensores en los bandos que ven; `occlusion_mask` en los muros.
- Decile a la persona cómo dimensionar la vista: seleccionar el sensor, arrastrar las manijas de vista, pérdida, ángulo, cercanía y ojos en la vista 3D (o 2D); Ctrl+Z deshace.
- Los estados del actor: `perceived` arranca la alerta, `forgotten` la termina, `latest()` dice adónde mirar o ir.
- Los ruidos del juego llaman a `hear()`; la luz y la oscuridad ponen `visibility`, `sight_scale` o `reach_by_kind`; un juego en red pone `enabled` solo en su autoridad.

## 4. Listo cuando

- Los sensores no muestran avisos y la persona dimensionó (o sabe dimensionar) las vistas con las manijas.
- F6 con `show_in_game`: el actor ve al objetivo en su vista, lo pierde pasado el radio de pérdida o detrás de un muro, oye un ruido y olvida pasado `memory_s`.
- Los estados del actor reaccionan.
- Nada de código de estados, combate o red dentro de `addons/perception_kit`.
