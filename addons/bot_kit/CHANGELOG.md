# Changelog de BotKit

## 0.2.0

- **Elegir por puntaje sin cuerpo ni tiempo real**, para un bot por turnos, de cartas o de estrategia:
  - `BotChoice`: una opción con `id`, `score` y `payload`.
  - `BotBrainCore.best(choices, current_id, rng, noise)`: datos puros. Gana el puntaje más alto por encima de 0 (entre iguales, el primero), y lo actual se queda hasta que otra opción lo supere. El ruido (`noise`) sale del `rng` que le pasás, así que la misma semilla elige igual; sin ruido no toma ningún número.
  - `BotBrain` (nodo): elige entre sus hijos `BotOption` y las opciones del juego (`options`), con `think(context)` o solo cada `think_s` (`auto_think`). Avisa con `chose` y tiene `current`, `last_choices`, `noise`, `rng_seed` y `rng`. Avisa en el editor si no tiene opciones o si dos tienen el mismo id.
  - `BotOption` (nodo): una opción con `score` en el inspector, `_score(context)` o `_choices(context)`.
- **`Bot3D` elige sus modos con `BotBrainCore.best`.** Su API, sus modos y su conducta no cambian, y sus tests pasan sin cambios.
- **Ejemplo `turn_based`:** un aldeano que construye una casa por turnos, con el puntaje de cada opción en pantalla, ruido y la misma semilla con los mismos turnos.
- **Íconos** para `BotBrain` y `BotOption`.
- **`botkit_lab`:** 50 tests, y el chequeo del editor revisa el `BotBrain` del ejemplo.

Nada que actualizar en tu proyecto.

## 0.1.1

- **Iconos propios en el editor:** cada nodo y recurso del kit tiene el suyo, del color del kit: se ven en el árbol de escena, en «Agregar nodo» y en el FileSystem. Reemplazan a los tres que traía el kit (`editor/bot_3d.svg`, `bot_goal_3d.svg`, `bot_mode.svg`).

Nada que actualizar en tu proyecto.

## 0.1.0

La primera versión: bots que juegan a tu personaje como una persona, en 3D.

- `Bot3D`: un nodo en el personaje que aprieta las teclas de un jugador en `bot.input` (`BotInput`, que se lee como `Input`). Ve al enemigo más cercano de `target_group` sin muros en el medio; en una pelea gira a una velocidad humana, apunta con error, reacciona antes del primer tiro, dispara dentro de un cono, en ráfagas, adelanta el tiro y tira en parábola, mantiene su distancia y se corre de costado sin salirse del navmesh. Sin nadie a la vista recorre el navmesh: a una meta, a donde vio al enemigo o a un punto alcanzable al azar; trabado, salta y elige otro camino. `enabled` suelta todas las teclas. `turn_body` apagado solo escribe `yaw` y `pitch`, para un juego en red.
- Las reglas del juego en funciones: `is_enemy`, `choose_target`, `weapon_score`.
- `BotWeapon`: alcance, puntaje, `chance`, `keep_m`, `fire_within_m`, velocidad y gravedad del proyectil, gatillo HOLD, TAP o CHARGE.
- `BotDifficulty` con tres presets: fácil, normal y difícil.
- `BotGoal3D`: un lugar al que vale la pena caminar (un pickup), con prioridad, alcance y `wanted`.
- `BotMode`: conductas propias como nodos hijos; el bot hace lo que más quiere.
- Editor: la vista, el cono de disparo y la distancia de pelea del bot en la vista 3D, con manijas para la altura de los ojos y de la puntería; el alcance de una meta, con su manija; cada arrastre se deshace; avisos. `show_in_game` dibuja lo que piensa mientras juega.
- Ejemplos `minimal_3d` (un robot que te caza) y `arena_3d` (cuatro bots con rifle y granadas, pickups, huir herido, dificultad).
- `botkit_lab`: 40 tests y un chequeo del editor.
