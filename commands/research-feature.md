---
description: "Investigar cómo funciona una mecánica de un juego similar (búsqueda web + observación), deducir su comportamiento y dejarla lista para escribirla en Godot."
argument-hint: "<juego> <qué querés entender>"
---

Entender **cómo** se comporta una mecánica o feature de un juego similar, con fuentes públicas y mirándola, y dejarla lista para armar en el **proyecto Godot del juego**. Sin ingeniería inversa: el otro juego nunca se abre ni se decompila.

Esto **no** implementa la feature: termina en un informe y el `F<n>`. Después, `/implement-feature`.

Cargar: `godot-feature-research`. Si está `godot-studio-workflow`, la investigación la hace el orquestador (este chat), no un `studio-developer`.

## 1. Alcance

Si falta, preguntá en un solo lote (`AskUserQuestion` en Claude Code / `AskQuestion` en Cursor, si está):

1. Qué juego y **qué** comportamiento (una pregunta concreta).
2. Qué puede aportar el usuario: ¿lo juega, tiene un video, conoce una wiki o una charla sobre eso?

## 2. Investigar

Buscá en la web: la wiki y las guías del juego, devlogs y charlas de sus desarrolladores, páginas de frame data y de speedrun, video de gameplay, artículos que analizan la mecánica. Tabla de fuentes en [godot-feature-research](../skills/godot-feature-research/SKILL.md). Cada conclusión con su fuente (un link, un minuto del video, un frame contado). Lo que ninguna fuente muestra queda **desconocido**, no supuesto.

## 3. Deducir

Una fórmula, una tabla de valores o una máquina de estados que explique lo que muestran las fuentes. Marcá cada supuesto.

## 4. Informe

En `FEATURES.md` (un `F<n>` nuevo o existente) o `research/<slug>.md`:

- Qué hace, en una oración.
- Fórmula / tabla de valores / máquina de estados.
- Fuentes y desconocidos.
- Qué pasa a `@export` o `.tres` en Godot.

Nada de código tomado del original ni de fuentes sobre él, y ninguno de sus assets.

## 5. Listo cuando

- El usuario entiende el mecanismo y tiene números para ajustar.
- El `F<n>` tiene criterios medibles con esos números.
- Paso siguiente propuesto: `/implement-feature`.
