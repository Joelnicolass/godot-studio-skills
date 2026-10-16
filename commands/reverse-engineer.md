---
description: "Ingeniería inversa de una mecánica de otro juego o app con REA (deducir o decompilar) para reimplementarla en Godot."
argument-hint: "<juego o app> <qué querés entender>"
---

Entendé **cómo** funciona una mecánica o feature de otro juego / app y dejala lista para reimplementarla en el **proyecto Godot del juego**. Herramienta: [REA](https://github.com/Joelnicolass/rea).

Esto **no** implementa la feature: termina en un informe y en el `F<n>`. Después va `/implement-feature`.

Cargar: `godot-reverse-engineering`. Si está `godot-studio-workflow`, la investigación la hace el orquestador (este chat), no un `studio-developer`.

## 1. Acotar

Si falta, preguntá en un lote (`AskUserQuestion` en Claude Code / `AskQuestion` en Cursor, si está):

1. Qué juego / app y **qué** comportamiento (una pregunta concreta).
2. ¿Es tuyo o tenés autorización para analizarlo (licencia / EULA)? Sin un sí claro, quedate en **deducir** por observación.
3. Qué hay: build web, `.exe`, `Assembly-CSharp.dll`, APK, solo video / gameplay.

## 2. Elegir camino

Deducir (observar, medir) antes que decompilar. Tabla en [godot-reverse-engineering](../skills/godot-reverse-engineering/SKILL.md). Si hace falta REA y no están sus tools: pedí OK para `npx rea-agents setup`; no lo instales solo.

## 3. Investigar

Evidencia por cada conclusión (función, offset, captura, frame). Lo que no se pudo ver queda como **desconocido**, no como supuesto.

## 4. Informe

En `FEATURES.md` (`F<n>` nuevo o el existente) o `research/RE-<slug>.md`:

- Qué hace, en una frase.
- Fórmula / tabla de valores / máquina de estados.
- Evidencia y desconocidos.
- Qué se vuelve `@export` o `.tres` en Godot.

Sin código decompilado ni assets del original.

## 5. Listo cuando

- El usuario entiende el mecanismo y tiene números para tunear.
- El `F<n>` tiene criterios medibles con esos números.
- Próximo paso propuesto: `/implement-feature`.
