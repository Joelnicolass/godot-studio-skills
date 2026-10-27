# Módulo de determinismo — referencia

Todo vive en `addons/agent_kit/determinism/`. Sin nombres de juego, sin puntaje.

## Archivos del módulo

| Archivo | Qué |
|---------|-----|
| `det_recorder.gd` | Nodo `DetRecorder`: registro + sha256 |
| `det_cli.gd` | Helpers estáticos `DetCli` para args `--clave=valor` |
| `det_run.sh` | El runner: modos, watchdog, base, `quick`, `bless`, `table` |
| `det_report.py` | Tabla y veredicto (`DETERMINISM PASS/FAIL`) |
| `harness/godot_run.sh` | Cola FIFO para todo lanzamiento de Godot |
| `harness/godot_busy.sh` | Sonda «¿hay otro Godot corriendo?» antes de un import |
| `det_selftest.sh` | Autoprueba del módulo con su propia escena |
| `example/` | `det_selftest.tscn`, `det.cfg`, `det_cases.txt` |

## API de DetRecorder

`class_name DetRecorder extends Node`.

- `@export var keep_lines := false`: guarda cada línea (hace falta para `--events=` y para el informe de primera línea distinta).
- `@export var self_tick := true`: el nodo cuenta los ticks de física solo. Con `false`, el dueño llama a `advance()`.
- `@export var position_decimals := 1`: decimales que usa `sample()`.
- `start()`, `stop()`, `advance()`.
- `record(kind: String, text: String)`: escribe `"<tick> <tipo> <texto>"` y lo hashea con un salto de línea. Se ignora si no corre.
- `sample(bodies: Array)`: una línea `pos` por cuerpo válido, ordenado por nombre.
- `digest() -> String`: sha256 hex de todas las líneas. La primera llamada fija el valor.
- `write_outputs(report: Dictionary)`: agrega `digest`, `events` (cantidad de líneas), `end_tick`; escribe `--out=*.json` y `--events=*` si vinieron; emite `finished(digest)`.
- Propiedades: `tick`, `running`, `line_count`, `lines`.

## API de DetCli

`class_name DetCli`, todo estático:

- `args() -> Dictionary`: cada `--clave=valor` (o `--flag` solo = true) después de `--`.
- `out_path()`, `events_path()`: dónde el runner quiere el informe y las líneas (`""` si no se pidió).
- `absolute(path)`: las rutas relativas lo son al proyecto.

## CLI de det_run.sh

```
det_run.sh CASOS CASO|all [MODO...] [--no-window]
det_run.sh CASOS quick [--no-window]
det_run.sh CASOS table [CASO...]
det_run.sh CASOS bless
```

- `CASO`: corre ese caso en los modos listados. `all`: todos los casos con `set=all`.
- `quick`: borra los resultados viejos de los casos quick, los corre, compara cada digest `fixed` con la base (`baseline CASO OK|FAIL`), exige dos modos frescos por caso e imprime `QUICK PASS` o `QUICK FAIL`.
- `table`: veredicto y tabla markdown de lo que hay en disco.
- `bless`: escribe la base con los resultados `fixed` de los casos quick. Falla si falta alguno.
- `--no-window`: solo headless (`fixed fixed2 stress`); el conjunto por defecto con ventana es `fixed stress window`.
- `fixed` siempre corre, y el veredicto necesita al menos dos modos frescos.

## Variables de det.cfg

Archivo shell, cargado con `source`; se busca junto al archivo de casos o en `$DET_CFG`. Rutas relativas al proyecto.

| Variable | Por defecto |
|----------|-------------|
| `DET_SCENE` | obligatoria, `res://...` |
| `DET_PROJECT` | carpeta con `project.godot` sobre el archivo de casos |
| `DET_OUT` | `agent/out/det` |
| `DET_BASELINE` | `agent/det_baseline.txt` (líneas `caso digest`) |
| `DET_RSS_LIMIT_KB` | 2500000 |
| `DET_LIMIT_FIXED` / `_STRESS` / `_WINDOW` | 600 / 900 / 900 segundos |
| `DET_STRESS_FPS` | 6 |
| `DET_WINDOW_RES`, `DET_WINDOW_ARGS` | `1280x720`, `--autostart --quit` |
| `DET_JOBS` | 3 (corridas caso/modo a la vez, como mucho 3; `1` = de a una) |
| `GODOT_BIN`, `GODOT_RUN_NS` | búsqueda en PATH; namespace de la cola |

`DET_OUT` y `DET_BASELINE` del entorno ganan sobre el cfg.

## Formato de det_cases.txt

`nombre|args|quick|set`; se ignoran comentarios `#` y líneas vacías.

- `quick`: `all` | `fixed` | vacío.
- `set`: `all` | vacío.
- `args`: se pasan a la escena después de `--`, separados por espacios.

## Modos

| Modo | Qué |
|------|-----|
| `fixed` | `--headless --fixed-fps 60`: lo más rápido posible, 1/60 por frame. La referencia. |
| `fixed2` | `fixed` otra vez: una corrida debe repetirse. |
| `stress` | headless, tiempo real, `--max-fps $DET_STRESS_FPS`: varios pasos de física por frame, así reloj de render != reloj de tick. |
| `window` | ventana real, `--max-fps 60`. Comparable solo si la escena autoarranca y se cierra sola. Nunca dos a la vez. |

## Archivos de salida

En `$DET_OUT`, por `<caso>_<modo>`: `.json` (informe con `digest`, `end_tick`, `events`), `.events` (líneas, si `keep_lines`), `.log` (salida de Godot), `.meta` (`wall_s rss_max_kb contaminated watchdog`).

Columnas de la tabla: caso, modo, sha256, end_tick, líneas, vs fixed, pared, RSS máx, avisos, primera línea distinta.

## Watchdog y CONTAMINATED

El runner mira el proceso hijo de Godot cada segundo:

- `rss_kill`: RSS sobre `DET_RSS_LIMIT_KB`.
- `timeout_kill`: tiempo de pared (desde que Godot arranca de verdad, no desde la espera en la cola) sobre el límite del modo.
- `script_error_kill`: `Parse Error`, `Compile Error` o `Failed to load script` en el log. Se mata al instante.
- `none`: normal.

`contaminated=1` significa que apareció durante la corrida un proceso Godot que no es de este banco (ni un editor); las corridas paralelas del propio banco (su `--out=` está en `DET_OUT`) y el import de la cola sobre el proyecto no cuentan. Es solo un aviso: un digest no depende de la carga, así que nunca rompe el veredicto; el tiempo de pared y la RSS de esa corrida no son comparables. Un corte del watchdog sí rompe el veredicto.

## Cola godot_run.sh

`godot_run.sh <comando godot...>` corre un Godot bajo un esquema para toda la máquina:

- Tickets FIFO: una racha de ventanas no deja sin turno a los headless.
- Headless: hasta `HEADLESS_SLOTS` (3). Ventana: una a la vez, junto a los headless. Import (`--import`): solo. Como mucho `GODOT_MAX` (4) Godots.
- Los locks son carpetas en `/tmp/<GODOT_RUN_NS>_godot.*`; un lock cuyo dueño murió se borra.
- Una ventana tiene tope de pared `GODOT_WINDOW_MAX_S` (600; 0 = sin tope).
- Un preflight de `class_name` avisa `clases sin importar` cuando el caché está viejo; importá una vez y reintentá. `GODOT_RUN_NO_PREFLIGHT=1` lo salta; `GODOT_RUN_PREFLIGHT_EXCLUDE` lista carpetas a ignorar.
- Mismo `GODOT_RUN_NS` en todo script de la máquina que lance Godot, así comparten el presupuesto. Agentes en paralelo usan worktrees separados (un `.godot/` cada uno).

## Autoprueba

`bash addons/agent_kit/determinism/det_selftest.sh` (necesita Godot, unos minutos) corre la escena de ejemplo (20 cuerpos rígidos, semilla fija) en una carpeta temporal y verifica: mismo digest en `fixed`/`fixed2`/`stress`; `bless` y luego `quick` pasa; un digest falso en la base da `QUICK FAIL`; `--break` lo mata `script_error_kill`. Imprime `SELFTEST PASS` o `SELFTEST FAIL`.
