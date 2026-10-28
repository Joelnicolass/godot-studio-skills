---
name: godot-testing
description: >-
  Testea proyectos Godot 4 con GUT (GDScript) o GdUnit4 (C#) y los corre en CI
  (GitHub Actions: gdformat, gdlint, import headless y GUT). Usar al escribir
  tests unitarios, de escena, de Resources, señales, reglas puras o domain
  RefCounted, al armar el CI headless o al elegir un runner de tests de Godot.
---

# Godot — tests y CI

No inventes un runner. Detectá el que ya está (GUT, GdUnit4, script del repo). Si no hay y el usuario pidió tests: **GUT** para GDScript, **GdUnit4** si el proyecto es C#. No instales un framework sin decirlo.

Arquitectura: [godot-layered-architecture](../godot-layered-architecture/SKILL.md). Composición: [godot-composition-first](../godot-composition-first/SKILL.md). Lint y avisos de tipos: [godot-code-quality](../godot-code-quality/SKILL.md).

## Qué testear

| Capa | Cómo |
|------|------|
| Reglas puras (`class_name` + `static func`) y domain Clean (`RefCounted`) | `MyRule.new()` o la llamada estática. Sin escena ni autoloads. Es el primer lote |
| Resource de tipo | Construir el Resource o cargar el `.tres`; no mutar el asset compartido |
| Nodo / componente | Agregarlo como hijo del test con `add_child_autofree`. Probar señales |
| Feel / cámara / juicy | Playtest anotado. Un unit test verde no prueba que se sienta bien |

No tests de relleno. Cada test debe **fallar** si un criterio de aceptación se rompe.

## GUT (GDScript)

- **Instalar:** «GUT - Godot Unit Testing» desde la Asset Library, o un release de [bitwes/Gut](https://github.com/bitwes/Gut/releases). GUT 9.x es para Godot 4; elegí el release cuyas notas declaran tu versión de Godot. Habilitá el plugin.
- **Carpetas:** `res://test/unit/` (rápidos, reglas puras) y `res://test/integration/` (escenas). Archivos `test_*.gd`, `extends GutTest`, funciones `test_*`.
- `before_each` / `after_each` por test; `before_all` / `after_all` por script.
- Nodos: `add_child_autofree(scene.instantiate())`; `assert_no_new_orphans()` si sospechás fugas.
- Señales: `watch_signals(node)` y `assert_signal_emitted(node, "died")`.
- Input: helpers de GUT (`GutInputSender`), y **limpiarlos** en el teardown.
- `test/` y `addons/gut/` quedan fuera del export (filtro de exclusión del preset).
- Opciones por defecto en `res://.gutconfig.json`; las de la línea de comandos las pisan.

```bash
# From the project root (where project.godot is)
godot --headless --path "$PWD" --import      # clean checkout: builds the class_name cache
godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit -ginclude_subdirs -gexit
```

Devuelve `0` si todo pasa y `1` si algo falla: el CI usa ese código. `-gjunit_xml_file=<ruta>` escribe un informe JUnit. Pegá la salida real.

## GdUnit4 (C#)

- Usá el runner de GdUnit4 del proyecto: scene runner y `simulate_action_*` según su API.
- No mezcles GUT y GdUnit4 en el mismo título sin motivo.

## CI (GitHub Actions)

Un workflow que hace en cada push y PR lo mismo que corrés a mano: formato, lint, import y tests. Fijá la versión exacta de Godot del proyecto.

```yaml
# .github/workflows/godot-checks.yml
name: Godot checks
on: [push, pull_request]

jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install "gdtoolkit==4.*"
      - run: gdformat --check scenes test
      - run: gdlint scenes test
      - uses: chickensoft-games/setup-godot@v2
        with:
          version: 4.x.y          # the project's exact version
          use-dotnet: false
          include-templates: false
      - run: godot --headless --path "$PWD" --import
      - run: godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit
```

- Ajustá las carpetas a las del proyecto, y `working-directory` si el juego vive en una subcarpeta.
- En un proyecto viejo con muchos hallazgos de lint, el código existente puede ir con `continue-on-error: true` hasta la pasada de `gdformat`. Los tests y el código nuevo bloquean desde el primer día.
- `npm test` o el typecheck de TS no aplican.

## Anti-patrones

- Instalar GUT «por las dudas» en un juego en el que el usuario no quería tests.
- Testear el `.tscn` entero para una suma que vive en una regla pura.
- Dejar nodos sin liberar.
- Afirmar cobertura de feel con un `assert_eq` sobre un float de shader.
- Un CI que corre algo distinto de lo que corrés a mano.
