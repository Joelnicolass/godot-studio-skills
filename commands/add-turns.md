---
description: "Turnos (addon TurnKit): de quién es el turno, acciones, fases, tiempo por turno, rondas, ciclos, jugador inicial que rota e iniciativa; un TurnClock con un TurnSeat por jugador, o un TurnCycle en las reglas."
---

Agregá **turnos** al **proyecto Godot del juego** con el addon TurnKit:
- un `TurnClock` con un `TurnSeat` por jugador, o un `TurnCycle` en las reglas del juego mostrado con `use_cycle`;
- acciones por turno, rondas, ciclos y el fin de la partida;
- si hace falta, fases dentro del turno, tiempo por turno, un jugador inicial que rota o un orden de ronda propio (iniciativa).

Después la persona ve los avisos del reloj en el inspector y juega el flujo con los botones del juego; el agente arma y explica.

Esto **no** son las reglas del juego (qué cuesta una acción, qué se hace en cada fase), ni los bots, ni la red: el kit lleva la cuenta de los turnos y el juego escucha las señales.

Cargar: `godot-turn-kit`, `godot-composition-first`.

Si falta `addons/turn_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT turn_kit
```

Habilitá **TurnKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Cuántos jugadores hay, cuáles son bots y quién abre; si cada ronda la abre el mismo o rota.
2. Cuántas acciones tiene un turno (o ninguna: sin límite) y si el turno tiene fases (cuáles, en qué orden).
3. Si hay tiempo por turno (cuántos segundos) y qué pasa al agotarse: pasa solo o solo avisa.
4. Si el orden de la ronda es fijo o lo decide el juego (iniciativa, quién juega primero según una tirada o un puntaje).
5. Cuántas rondas hacen un ciclo (una era, un año), cuántos ciclos dura la partida o si no termina, y qué pasa al final de cada ronda o ciclo.
6. Dónde viven las reglas hoy (el estado de la partida) y si el juego es en red (con MpKit o con qué).

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin TurnKit
[+] scenes/turns/turns.tscn              # TurnClock: actions_per_turn, phases = [draw, play], turn_seconds = 30; un TurnSeat por jugador
[~] game/state.gd                        # TurnCycle de las reglas (si las reglas lo llevan); use_cycle en el reloj
[~] scenes/hud/hud.gd                    # escucha turn_started, phase_started, turn_timed_out; muestra time_left
[~] game/rules.gd                        # en round_ended: set_round_order(iniciativa)
```

Arrancá desde `addons/turn_kit/examples/minimal`: tres asientos, fases, tiempo y jugador inicial que rota.

## 3. Implementar

Seguí [godot-turn-kit](../skills/godot-turn-kit/SKILL.md) y `addons/turn_kit/README.md`.

- Un `TurnClock` con un `TurnSeat` hijo por jugador, en el orden en que juegan; los valores en el inspector (grupos Turn, Round, Phases, Time).
- Con reglas propias: un `TurnCycle` en el estado del juego, mostrado con `clock.use_cycle(...)`; nunca lo reinicies.
- El juego escucha `turn_started`, `phase_started`, `turn_timed_out`, `round_ended`, `cycle_ended` y `finished`.
- `next_phase()` y `end_turn()` desde los botones o las reglas; los bots cierran su turno con `end_turn.call_deferred()`.
- Iniciativa: `set_round_order(...)` en `round_ended`.
- En red: el servidor hace `tick` y manda `to_dict()`; los clientes apagan `advance_time`.
- Decile a la persona qué ve en el inspector (avisos, grupos) y cómo probar los turnos con F6.

## 4. Listo cuando

- El reloj no muestra avisos y los turnos pasan en el orden esperado.
- F6: las acciones, las fases y el tiempo (si se usan) se ven y el turno pasa solo al agotarse el tiempo.
- La partida termina cuando tiene que.
- Nada de las reglas del juego, bots ni red dentro de `addons/turn_kit`.
