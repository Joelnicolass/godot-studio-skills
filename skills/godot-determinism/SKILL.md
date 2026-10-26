---
name: godot-determinism
description: >-
  Agrega un banco de humo de determinismo a un proyecto Godot 4 con el módulo
  de determinismo de AgentKit (DetRecorder, det_run.sh, det_cases.txt, base).
  Usar en juegos con red (lockstep, predicción, simulación host-authoritative
  que debe coincidir), repeticiones (replays) y grabaciones, y regresión de humo
  («¿mi cambio movió la simulación?»). Cubre cablear el registrador, escribir
  casos, crear la base con bless, leer CONTAMINATED y el watchdog, la cola de
  Godot y las fuentes típicas de no determinismo.
---

# Godot — banco de determinismo

La misma corrida, con las mismas entradas, debe dar el mismo digest sea cual sea el reloj de render. El banco registra la simulación en un sha256 y lo compara entre relojes (`fixed`, `fixed2`, `stress`, opcional `window`) y contra una base guardada. Es una **prueba de humo**, no un contrato byte a byte.

Módulo: `addons/agent_kit/determinism/` (parte de AgentKit). API y flags completos: [reference.md](reference.md). Tests de reglas y unidades: [godot-testing](../godot-testing/SKILL.md). Diseño multiplayer: [godot-mp-kit](../godot-mp-kit/SKILL.md). Manejar el juego con flows: [godot-agent-kit](../godot-agent-kit/SKILL.md).

## Cuándo usarlo

- **Red:** lockstep, rollback o juegos host-authoritative donde dos máquinas deben calcular lo mismo, o donde repetir las entradas debe reproducir la partida.
- **Repeticiones:** cualquier feature que grabe entradas o semillas y las reproduzca.
- **Regresión de humo:** un chequeo barato en cada corte de que un refactor no movió la simulación.

**No** usarlo para: UI pura, visuales de una vez, o código sin simulación que registrar. Preguntá antes si el proyecto no tiene una escena que corra headless; el banco necesita una.

## Cómo funciona

1. Una **escena de banco** arranca la simulación desde args de CLI (`--seed=7`, un nombre de escenario), sin humano.
2. Un nodo `DetRecorder` escribe una línea por evento notable, `"<tick> <tipo> <texto>"`, y las hashea en orden.
3. Al terminar la escena llama a `write_outputs(report)`: un JSON con el digest y, opcional, las líneas.
4. `det_run.sh` lanza la escena varias veces con relojes distintos y compara los digests.
5. Una **base** guardada (`caso digest` por línea) dice si la corrida de referencia de hoy sigue igual a la última aceptada.

## Cablear DetRecorder

- Agregá un hijo `DetRecorder` a la escena de banco (o a tu nodo de partida/auditoría). Con `self_tick = true`, ponelo **antes** de los nodos que mira en el árbol, para que el tick avance primero.
- Si el orden de `_physics_process` te importa, usá `self_tick = false` y llamá `recorder.advance()` una vez por paso de física en el punto donde debe moverse el reloj.
- Al inicio: `recorder.keep_lines = not DetCli.events_path().is_empty()`, luego `recorder.start()`.
- Durante la corrida: `recorder.record("tipo", "texto")` para eventos (spawns, muertes, daño, cambios de fase) y `recorder.sample(cuerpos)` cada N ticks para posiciones (redondeadas, ordenadas por nombre).
- Al final: `recorder.stop()`, `recorder.write_outputs({"seed": seed})`, y `get_tree().quit()`.
- Las líneas llevan **solo estado de juego**: sin hora de pared, sin ids de objeto, sin iterar diccionarios que dependan del orden de inserción, sin floats de precisión ilimitada.
- El registrador solo mira. Nunca decide ni cambia el juego.

## Escribir det_cases.txt

Un caso por línea, `nombre|args|quick|set`:

```
# nombre|args|quick|set
seed1|--seed=1|all|all
seed7|--seed=7|fixed|all
heavy|--seed=3 --units=200||all
```

- `args` van a la escena después de `--` y se leen con `DetCli.args()`.
- `quick`: `all` (todos los modos), `fixed` (solo referencia, lo más barato) o vacío (no entra en `quick`).
- `set`: `all` es parte de la corrida completa `all` (usala al cerrar un hito).
- `quick` chico: pocos casos cortos que cubran los sistemas principales. Cada corrida, menos de un minuto.

## Configurar det.cfg

Un archivo shell junto a `det_cases.txt`, que el runner carga con `source`:

```
DET_SCENE=res://debug/bench.tscn
DET_OUT=agent/out/det
DET_BASELINE=agent/det_baseline.txt
```

Opcionales: `DET_RSS_LIMIT_KB`, `DET_LIMIT_FIXED/STRESS/WINDOW` (segundos), `DET_STRESS_FPS`, `GODOT_BIN`, `GODOT_RUN_NS`. Detalle en [reference.md](reference.md).

## Correr el banco

```
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt quick --no-window
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt seed1 fixed fixed2
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt all fixed fixed2 stress
bash addons/agent_kit/determinism/det_run.sh agent/det_cases.txt table
```

Envolvelo en un script del proyecto (`agent/run_determinism.sh`) para que se escriba un comando corto.

## Crear la base (bless)

1. Corré `quick` (o los casos a mano) para que existan resultados `fixed`.
2. Verificá que los casos que se movieron den igual en `fixed` y `fixed2` (ver la política abajo).
3. `det_run.sh agent/det_cases.txt bless` escribe `DET_BASELINE` con el digest `fixed` de cada caso quick.
4. Commiteá la base junto con el cambio que la causó y anotá una línea con el porqué.

Después `quick` imprime `baseline CASO OK|FAIL` por caso y `QUICK PASS` o `QUICK FAIL`.

## Leer el resultado

- `DETERMINISM PASS`: todos los modos de todos los casos igualaron a `fixed`, sin marcas.
- `!=` en la tabla: ese modo divergió. Si hay `.events`, la última columna muestra la primera línea distinta.
- **CONTAMINATED**: otro Godot (que no es un editor) estaba vivo mientras se medía la corrida. El digest puede estar bien, pero la corrida no cuenta; repetila sola.
- **watchdog**: `rss_kill` (memoria sobre el límite), `timeout_kill` (tiempo límite del modo), `script_error_kill` (error de parseo/compilación en el log: se mata al instante, arreglá el script). Cualquiera rompe el veredicto.
- `quick` exige al menos dos modos frescos por caso; archivos viejos de una corrida anterior nunca cuentan.

## Una cola de Godot, sin ventana en paralelo

Todo Godot que lanza el banco pasa por `harness/godot_run.sh`: cola FIFO, hasta 3 headless a la vez, una ventana a la vez, un import solo, nunca más de 4 Godots. Usá el mismo `GODOT_RUN_NS` para todo lo que lance Godot en la máquina, así comparten el presupuesto.

**Ninguna ventana corre en paralelo con el banco.** Una ventana y un banco headless a la vez distorsionan los tiempos y marcan las corridas CONTAMINATED; dos ventanas pueden colgar la máquina. Corré primero el banco headless y el caso con ventana solo después (un caso con ventana debe autoarrancar y cerrarse solo).

## Política liviana

El banco es una prueba de humo:

- `quick` en cada corte. `all` solo al cerrar un hito.
- Si un digest cambió por un cambio **a propósito**: confirmá que `fixed` y `fixed2` dan el mismo digest nuevo en cada caso movido (la corrida se sigue repitiendo), después `bless` y escribí una línea con qué cambió.
- Si `fixed` y `fixed2` no coinciden, es un bug real (no determinismo), no se regraba.
- Sin informe de primer tick distinto ni ceremonia de cuatro modos para cambios comunes. La exactitud byte a byte es para cuando el producto la pide (rollback, repeticiones competitivas).

## Fuentes comunes de no determinismo

- **RNG sin semilla:** `randi()`, `randf()`, `shuffle()` sobre el generador global. Usá un `RandomNumberGenerator` con semilla explícita, dueño de la partida.
- **Dependencia del fps:** `_process(delta)` para gameplay, `delta` del reloj de render, `Time.get_ticks_msec()`, timers en tiempo de pared. Pasá a `_physics_process` con ticks fijos y contá ticks.
- **Orden de nodos:** `get_children()`, grupos, señales en orden de árbol, orden de `_physics_process` entre hermanos. Ordená por una clave estable (nombre, id) antes de iterar; cambiá el orden solo a propósito.
- **Navegación asíncrona / iteraciones de región:** mapas de `NavigationServer` que sincronizan en varios frames, agentes que esperan un camino, regiones horneadas que terminan en momentos distintos. Esperá a que el mapa esté listo antes de tickear y mantené las consultas de camino dentro del tick.
- **Hilos de evasión (avoidance):** las velocidades de evasión llegan por callback, calculadas en un hilo. Aplicalas en un punto fijo del tick; apagá el threading de evasión en los ajustes del proyecto si los resultados varían.
- **Timing de física:** `physics_ticks_per_second` distinto entre editor y banco, `max_physics_steps_per_frame` que recorta pasos en `stress`, cuerpos que duermen. Mantené los ajustes del proyecto idénticos en todos los modos.
- **Diccionarios / Arrays de objetos:** hash por id de objeto, iteración de conjuntos sin orden armados con `instance_id`.
- **Hilos y `await`:** trabajo que termina «cuando termina». Unilo dentro del tick, o registralo solo tras una demora fija en ticks.
- **Floats en las líneas:** imprimí con decimales fijos (`position_decimals`) para que el ruido bajo el umbral no entre al digest.

## Anti-patrones

- Registrar hora de pared o ids de objeto en las líneas.
- Regrabar la base sin comparar `fixed` con `fixed2`.
- Correr una ventana mientras corre el banco headless.
- Subir los tiempos límite para tapar un cuelgue en vez de leer el watchdog.
- Meter nombres de juego o puntaje en el módulo; los casos y la base viven en el proyecto.
- Forkear `det_run.sh` por proyecto en vez de usar `det.cfg`.

## Checklist

- [ ] La escena de banco corre headless desde args de CLI y se cierra sola.
- [ ] `DetRecorder` cableado; las líneas llevan solo estado de juego.
- [ ] `det_cases.txt` y `det.cfg` en el proyecto (`agent/`).
- [ ] `fixed` == `fixed2` en cada caso quick.
- [ ] Base grabada y commiteada con una línea de motivo.
- [ ] `quick --no-window` imprime `QUICK PASS`.
- [ ] Ningún otro Godot ni ventana corrió durante el banco (sin CONTAMINATED).
