---
name: godot-bot-kit
description: >-
  Bots que juegan a un personaje como una persona en un juego Godot 4 3D, con el
  addon BotKit: un nodo en el personaje que aprieta las teclas de un jugador (un
  Input propio que el personaje lee), ve al enemigo más cercano sin muros en el
  medio, gira y apunta con límites humanos (reacción, error, cono de disparo,
  ráfagas, adelantar el tiro, granadas en parábola), elige el arma por la
  distancia, mantiene su distancia y se corre de costado, recorre el navmesh
  hacia pickups, a donde vio al enemigo o a cualquier punto, y sale de donde se
  traba. Conductas propias como nodos hijos (huir, custodiar), presets de
  dificultad, la vista y las manijas en el editor. Usar cuando el usuario quiere
  bots, enemigos que juegan como jugadores, rellenar asientos vacíos con bots,
  un deathmatch contra la máquina, IA de shooter o /add-bots. No es el
  personaje, sus armas ni su vida, ni la red.
---

# Godot — bots que juegan como una persona (BotKit)

Addon `addons/bot_kit/` en el proyecto del **juego**. Referencia: `addons/bot_kit/README.md`; API por pieza: [api.md](api.md).

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project bot_kit
```

Habilitá el plugin **BotKit** (la vista, el cono y las manijas en la vista 3D; los nodos andan sin él). Pedido acotado: `/add-bots`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Un nodo y una línea.** Un `Bot3D` hijo del personaje, y el personaje lee `bot.input` donde el de un jugador lee `Input` (los mismos métodos). El bot nunca mueve el cuerpo: aprieta teclas. Si el personaje ya lee `Input` en varios lugares, una variable `input` que vale `Input` o `bot.input` según quién juega.
- **Las teclas, por nombre.** De entrada, las de la plantilla de personaje de Godot (`ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_accept`) más `fire`; el grupo «Controls» del bot las cambia por las del juego. No hace falta que estén en el InputMap.
- **Mirar.** Con `turn_body` (de entrada) el bot gira al personaje y a su `head`. Si el personaje aplica él mismo hacia dónde mira (un juego en red, una cámara propia), `turn_body = false` y el personaje lee `input.get_value(&"yaw")` y `&"pitch"` (radianes).
- **Enemigos, por grupo.** Los nodos de `target_group` (`bot_target`); equipos y cuerpos muertos con `is_enemy`. Otra percepción (un cono, oídos): `choose_target`.
- **Armas, por distancia.** Un `BotWeapon` por arma, con su alcance, puntaje y gatillo; el personaje cambia de arma en `weapon_changed`. Las reglas del juego sobre un arma (calor, munición) en `weapon_score`, nunca en el kit. Una granada: `projectile_speed_m_s` y `gravity_m_s2` iguales a los del proyectil del juego.
- **Pickups, como metas.** Un `BotGoal3D` en la escena del pickup; un pickup tomado se esconde (y su meta con él). Si le hace falta, en `wanted`.
- **Conductas propias, como nodos.** Un `BotMode` hijo del bot con `_want()` y `_tick()`; usa `walk_to`, `aim_and_fire`, `move`, `look_toward`. Nada de reemplazar la pelea o la recorrida: se les gana queriendo más.
- **Dificultad, en un recurso.** `presets/easy.tres`, `normal.tres`, `hard.tres`; un preset es compartido.
- **Muerto o donde no se decide el juego:** `enabled = false`. Suelta todas sus teclas.
- **Ningún kit depende de otro.** BotKit no tiene red ni percepción propia de otro kit: el juego conecta.
- **La persona lo ve en el editor.** Seleccionar el bot dibuja su vista, su cono y su distancia; las manijas mueven la altura de los ojos y de la puntería. `show_in_game` dibuja lo que piensa mientras juega.

## Red

El bot corre donde se decide el juego y aprieta las teclas de un asiento. **Con MpKit**, en el servidor, sobre el peón de un asiento libre:

```gdscript
var bot := preload("res://bots/bot.tscn").instantiate() as Bot3D
bot.turn_body = false
pawn.add_child(bot)
var keys := pawn.get_node(^"MpInput") as MpInput
bot.input.pressed.connect(keys.bot_press)
bot.input.released.connect(keys.bot_release)
bot.input.value_changed.connect(keys.bot_set_value)
```

Una persona toma el asiento (`keys.has_player()`, `Mp.gate().joined_late`): `bot.queue_free()`, que suelta todas las teclas al irse. Llenar asientos libres: el ejemplo `bots_2d` de MpKit. **Sin MpKit:** `enabled = multiplayer.is_server()` y las tres señales conectadas a la entrada de red del juego.

## Árbol

```
Level
├── Navigation (NavigationRegion3D)     # el navmesh horneado
│   └── Floor, Walls (StaticBody3D)     # en la capa de sight_mask: tapan vista y tiros
├── HealthPickup (Area3D)
│   └── BotGoal3D                        # priority 2, wanted: herido
└── Fighter (CharacterBody3D)            # en el grupo bot_target; lee bot.input
    ├── Head (Node3D)                    # head del bot
    └── Bot3D                            # weapons: [rifle.tres, grenade.tres]; difficulty
        └── Flee (BotMode)               # del juego: herido, corre a la salud
```

Arrancá desde `addons/bot_kit/examples/minimal_3d/minimal_3d.tscn` (un robot que te caza) o `arena_3d` (cuatro bots, rifle y granadas, pickups, un `BotMode` para huir, dificultad en 1, 2, 3).

## Qué va dónde

| Kit | Juego |
|---|---|
| Qué tecla aprieta y cuándo, hacia dónde mira | El personaje, cómo camina, salta y dispara con esas teclas |
| A quién ve, a quién elige (`is_enemy`, `choose_target`) | Los equipos, la vida, la muerte |
| Qué arma conviene a la distancia | Las armas de verdad, el daño, la munición, el calor (`weapon_score`) |
| A qué meta camina | Qué pickup vale la pena para quién (`wanted`) |
| Elegir lo que más quiere | Sus conductas propias (`BotMode`) |
| `pressed`, `released`, `value_changed` | La red, qué asiento juega un bot, cuándo lo toma una persona |

## Listo cuando

- El bot no muestra avisos y la persona vio (o sabe ver) su vista y sus manijas en la vista 3D.
- F6: el bot recorre el nivel, encuentra a un enemigo, gira, reacciona, dispara en ráfagas y mantiene su distancia; pierde al enemigo detrás de un muro y va a buscarlo.
- Con armas: cambia de arma según la distancia; una granada cae donde apuntó.
- En red: el bot juega en el servidor y una persona que toma el asiento lo reemplaza sin teclas trabadas.
- `godot --headless --path botkit_lab --script res://addons/bot_kit/tests/bot_test_runner.gd` da `BOTKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- Mover el cuerpo desde el bot o escribir un personaje aparte para el bot: el bot aprieta teclas y el personaje es el mismo.
- `Input.action_press()` para el bot: es global, lo aprietan todos los bots y la persona a la vez. Cada bot tiene su `bot.input`.
- Las reglas de un arma (calor, munición, espaldas) dentro de un `BotWeapon` copiado o del kit: van en `weapon_score`.
- Un `BotMode` que vuelve a escribir la pelea o la recorrida: llamá a `aim_and_fire` y `walk_to`.
- Dejar el bot prendido con su personaje muerto: `enabled = false`.
- Cambiar un preset compartido para un solo bot: hacé su dificultad única.
- Hornear el navmesh en el juego sin esperar: el bot camina cuando el mapa está; horneálo en el editor.
