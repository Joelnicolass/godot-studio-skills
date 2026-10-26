---
description: "Investigar cómo funciona una mecánica de un juego similar (búsqueda web, observación, decompilarlo cuando se puede), deducir su código y dejarla lista para escribirla en Godot."
argument-hint: "<juego> <qué querés entender>"
---

Entender **cómo** funciona una mecánica o feature de un juego similar, desde la web, mirándola y, si el juego se puede abrir, desde su código, y dejarla lista para armar en el **proyecto Godot del juego**.

Esto **no** implementa la feature: termina en un informe y el `F<n>`. Después, `/implement-feature`.

Cargar: `godot-feature-research`. Si está `godot-studio-workflow`, la investigación la hace el orquestador (este chat), no un `studio-developer`.

## 1. Alcance

Si falta, preguntá en un solo lote (`AskUserQuestion` en Claude Code / `AskQuestion` en Cursor, si está):

1. Qué juego y **qué** comportamiento (una pregunta concreta).
2. Qué puede aportar el usuario: ¿lo juega, tiene sus archivos, un video, una wiki o una charla sobre eso?

## 2. Investigar

Buscá en la web: la wiki y las guías del juego, devlogs y charlas de sus desarrolladores, código fuente (juegos open source, mods, repos de la comunidad), páginas de frame data y de speedrun, video de gameplay, artículos que analizan la mecánica. Si el usuario tiene el juego y se puede abrir, ofrecé decompilarlo (preguntá antes de instalar una herramienta). Tabla de fuentes en [godot-feature-research](../skills/godot-feature-research/SKILL.md). Cada conclusión con su fuente (un link, un minuto del video, un frame contado, un archivo del juego). Lo que ninguna fuente muestra queda **desconocido**, no supuesto.

## 3. Deducir

Una fórmula, una tabla de valores o una máquina de estados que explique lo que muestran las fuentes, o el código encontrado. Marcá cada supuesto.

## 4. Informe

En `FEATURES.md` (un `F<n>` nuevo o existente) o `research/<slug>.md`:

- Qué hace, en una oración.
- Fórmula / tabla de valores / máquina de estados, o el código encontrado.
- Fuentes y desconocidos.
- Qué pasa a `@export` o `.tres` en Godot.

Assets del original: preguntá antes de traerlos al juego.

## 5. Listo cuando

- El usuario entiende el mecanismo y tiene números para ajustar.
- El `F<n>` tiene criterios medibles con esos números.
- Paso siguiente propuesto: `/implement-feature`.
