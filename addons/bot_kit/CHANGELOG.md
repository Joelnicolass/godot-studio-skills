# Changelog de BotKit

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
