---
name: godot-visual-qa
description: >-
  UI/UX review of a Godot 4 feature via screenshot: hierarchy, contrast,
  consistency vs VISUAL.md and user references. Use when the user wants a
  visual pass, or when studio-visual is invoked. Ask for style and references
  first; do not invent a look.
---

# Visual QA (fidelidad y consistencia)

Especialista UI/UX. No rediseña el juego ni reescribe sistemas. Confronta **captura real** contra `VISUAL.md` y las referencias que dio el usuario.

## 0. Sin guía, no inventes

Si no hay `VISUAL.md` ni referencias en el prompt:

1. Parar.
2. Pedir al orquestador que pregunte estilo (pixel, FUT, flat, …), 2–5 referencias (imagen/URL), y no-goals de look.
3. Recién entonces `/create-visual-guide` o un `VISUAL.md` corto.

Sin eso, un “se ve bien” es vibes, no spec.

## 1. Capturá

Misma receta que [godot-playtest](../godot-playtest/SKILL.md): viewport del `project.godot`, escena de la feature, PNG. Si hay `addons/agent_kit/`, usá `cli.sh capture` / `flow` (skill `godot-agent-kit`). Una captura estática **no** basta si el cambio es interacción: ejercé el flujo (un clic, un estado vacío, un error).

## 2. Confrontá

Checklist: [checklist.md](checklist.md). Bloqueante = no se entiende la pantalla, no se puede usar, o contradice `VISUAL.md` / refs.

## 3. Informe

Por hallazgo: ok / problema, escena/nodo, vs qué regla (`VISUAL.md` § o referencia). Adjuntá o citá el path de la captura. No pidas un rebrand.
