# Harness AgentKit — no contaminar producto

Leé esto **antes** de escribir un helper de playtest. El fallo típico: el flow no puede armar el estado con clicks, entonces se agregan métodos de setup / forzar estado / contar / pausar **en `src/`**. A veces llevan prefijo `agent_*`; a veces un nombre de dominio del juego. Eso **es** contaminación. El nombre no importa; importa **quién lo llama**.

## Dónde puede vivir código de playtest

| Path | ¿Playtest? |
|------|------------|
| `res://agent/flows/*.json` | sí |
| `res://agent/harness/*.gd` | sí (`extends Node`, **sin** `class_name`) |
| `res://agent/fixtures/` | sí (`.tres` / `.tscn` solo para el run) |
| `res://src/`, `res://scenes/`, glue de producto | **no** |

Antes de editar un archivo fuera de `res://agent/`: **pará**. Si el cambio solo sirve al flow, va al harness.

## Qué es playtest (rol, no prefijo)

En producto **no** va un método cuyo trabajo sea, para el flow:

- spawnear o colocar entidades que el jugador no coloca en esa pantalla
- forzar un estado (contacto, cooldown, victoria, seed de pelea)
- contar nodos para un assert
- pausar o desactivar sistemas “hasta que el agente termine”
- reconstruir o reemplazar el mundo solo para el run

`func agent_*` en `src/` está prohibido. **Sacar el prefijo y dejar el mismo rol también.**

Una API pública en producto solo si el **juego** ya la necesita (load, generador, editor, replay). Si el único caller es el JSON del flow o `res://agent/`, es playtest: va al harness.

## Qué puede hacer el harness

Orden:

1. Clicks / `press` / `wait_until` como un jugador. Preferí esto.
2. `call.harness` a un script en `res://agent/harness/`.
3. En el harness: escena actual, `%UniqueName`, `find_children`, packed scenes **ya** del juego, señales **públicas**. Contar = `find_children`, no un getter nuevo en producto.
4. Fixtures en `res://agent/fixtures/`. No dupliques la lógica de construcción del mundo.

```json
{ "call": { "harness": "hooks", "method": "setup_slice" } }
```

## Si el razonamiento suena así, pará

Estos argumentos **no** limpian el producto:

- “Llamo un `_on_*` / `call()` a privados, no contaminé.”
- “Extiendo la clase de producto desde `agent/` y el script original queda intacto.”
- “Renombro `agent_*` a un nombre que parece de gameplay.”
- “Agrego un público solo para el flow.”
- “Piso una ref privada del contenedor con `set("_…")` / duplico la escena de producto para el run.”

El helper va a `res://agent/harness/*.gd`. En `src/` solo API que el **juego** ya necesita. Setup, pausa, forzar estado y conteos = harness (`find_children`, señales públicas, APIs que el jugador también usa).

## Mentiras que no uses

- `call()` a `_privados` / tocar listas internas **no** justifica agregar esos métodos en producto “para que sea usable”.
- `extends` una clase de producto bajo `agent/` no limpia el producto si igual le pedís API de playtest.
- Un método público cuyo único caller es el flow **es** playtest. Nombre de producto (`load_level`, aplicar un layout) solo si el **juego** también lo usa. Si no hay caller de producto, no lo agregues: hacé el setup en el harness o **pará** y pedí OK.
- `set("_ref", …)` en el contenedor para “no tocar producto” es el mismo acoplamiento.

## Chequeo al terminar

```bash
rg -n "func agent_" src scenes
git diff --stat -- src scenes
```

Cero `func agent_`. El diff del playtest **no agrega métodos** en `src/` salvo una API de producto **ya justificada** (quién más la llama, no el flow).
