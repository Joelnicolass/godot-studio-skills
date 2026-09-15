---
name: godot-studio-memory
description: >-
  Notes that survive between Cursor chats for a Godot studio project:
  decisions, bugfixes, gotchas, user prefs, next step. Uses Engram MCP if
  those tools exist; otherwise .studio/MEMORY.md next to project.godot.
  Use at session start, when recalling past work, after a meaningful
  decision, or before ending a session.
---

# Memoria entre chats

PRD/RFC son la verdad de producto. Esto es el **cuaderno del estudio**: por qué se eligió X, un bug que no hay que reabrir, “la próxima vez empezá por acá”.

No instales nada. Si en este chat hay tools `mem_search` / `mem_save` / `mem_context` / `mem_session_summary` (**Engram**), usalas. Si no, `{carpeta_con_project.godot}/.studio/MEMORY.md`.

No guardes secretos. No dumps de diffs ni de tool calls.

## Cuándo

| Momento | Acción |
|---------|--------|
| Arranque, o “acordate / qué hicimos” | Leer contexto (MCP: `mem_context` luego `mem_search`; si no, MEMORY.md) |
| Antes de re-decidir un patrón | Buscar; no contradigas una decisión ya escrita sin decirlo |
| Bugfix, decisión, gotcha, preferencia del usuario | Anotar **ya** |
| Antes de “listo” si hubo trabajo de producto | Un párrafo: qué se hizo, qué sigue, archivos clave |

Formato de una nota (MCP `mem_save` o un heading en el archivo):

```text
**What**: una frase buscable
**Why**: pedido / bug / feel
**Where**: path
**Learned**: gotcha (si hay)
```

En el archivo, decisiones que evolucionan van bajo el mismo heading (`### auction/must-open-bid`). Sesiones: append al final (`## 2026-09-15`).

Si una nota cambia el producto, actualizá también PRD / RULES / VISUAL / RFC.

## Engram (opcional)

Binario + MCP, no parte de este repo. Solo si el usuario quiere: `brew install gentleman-programming/tap/engram` y en el juego `.cursor/mcp.json`:

```json
{ "mcpServers": { "engram": { "command": "engram", "args": ["mcp"] } } }
```

Con eso alcanza. No hace falta TUI, git-sync ni el resto del ecosistema.
