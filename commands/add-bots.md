---
description: "Bots (addon BotKit): un nodo en tu personaje que juega como una persona, apretando sus teclas; ve, apunta con límites humanos, elige arma, recorre el navmesh, con conductas propias y presets de dificultad, en 3D."
---

Agregá **bots que juegan a un personaje como una persona** en el **proyecto Godot del juego** con el addon BotKit:
- un `Bot3D` hijo de cada personaje que juega un bot, y el personaje leyendo `bot.input` donde leía `Input`;
- sus enemigos en un grupo;
- un `BotWeapon` por arma, si tiene más de una;
- un `BotGoal3D` en cada pickup que valga la pena;
- un `BotMode` por conducta propia del juego (huir, custodiar), si hace falta.

Después la persona ve su vista y sus manijas en la vista 3D y lo mira jugar con `show_in_game`; el agente arma y explica.

Esto **no** es el personaje, sus armas, su vida ni su muerte: el kit aprieta teclas y el juego las convierte en movimiento y disparos. **No** es la red: un juego en red decide qué asiento juega un bot y conecta sus teclas a su entrada. **No** es una IA de estrategia ni de RTS.

Cargar: `godot-bot-kit`, `godot-composition-first`.

Si falta `addons/bot_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT bot_kit
```

Habilitá **BotKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Qué personaje juega el bot y dónde lee hoy sus teclas (el script que llama a `Input`); los nombres de sus acciones (moverse, saltar, disparar, cambiar de arma); si gira con el mouse o con valores.
2. A quién pelea: todos contra todos, equipos, solo contra el jugador; qué pasa al morir (cuándo reaparece).
3. Sus armas: cuáles, a qué distancia conviene cada una, si alguna se tira en parábola (velocidad y gravedad del proyectil), sus reglas (calor, munición, carga).
4. Qué pickups hay y cuándo vale la pena ir a buscarlos.
5. Si hace falta una conducta propia (huir herido, custodiar, seguir a un líder) y la dificultad (fácil, normal, difícil, o los números).
6. Si el juego es en red (con MpKit o con qué), y si el nivel tiene el navmesh horneado.

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin BotKit
[+] bots/bot.tscn                        # Bot3D: weapons, difficulty, Controls con las acciones del juego; Flee (BotMode)
[+] bots/flee.gd                         # BotMode del juego: herido, a la salud más cercana
[+] bots/weapons/rifle.tres              # BotWeapon: 0 a 40 m, HOLD
[+] bots/weapons/grenade.tres            # BotWeapon: 6 a 16 m, la velocidad y la gravedad de la granada del juego, TAP
[~] scenes/player/player.gd             # input = Input o bot.input; weapon_changed cambia el arma; weapon_score sin munición
[~] scenes/player/player.tscn           # en el grupo bot_target
[~] scenes/pickups/health.tscn           # BotGoal3D: priority 2; wanted: herido
[~] scenes/levels/arena.tscn             # navmesh horneado; los bots que llenan los asientos
```

Arrancá desde `addons/bot_kit/examples/minimal_3d` (un robot que te caza) o `arena_3d` (cuatro bots, rifle y granadas, pickups, huir, dificultad).

## 3. Implementar

Seguí [godot-bot-kit](../skills/godot-bot-kit/SKILL.md) y `addons/bot_kit/README.md`.

- El bot hijo del personaje, `head` en lo que mira arriba y abajo, las acciones del juego en «Controls».
- El personaje lee `bot.input` (o una variable `input` que vale `Input` para una persona). Con `turn_body` apagado, aplica `input.get_value(&"yaw")` y `&"pitch"`.
- Enemigos en `target_group`; equipos o cuerpos muertos en `is_enemy`.
- Las armas como `BotWeapon`; `weapon_changed` cambia el arma del personaje; las reglas del juego en `weapon_score`.
- `BotGoal3D` en los pickups (un pickup tomado se esconde); `wanted` para cuándo vale la pena.
- Al morir `enabled = false`, al reaparecer `true`. En red, `enabled` solo donde se decide el juego y las señales de `bot.input` conectadas a su entrada.
- Decile a la persona cómo verlo: seleccionar el bot muestra su vista, su cono y su distancia en la vista 3D; `show_in_game` dibuja lo que piensa.

## 4. Listo cuando

- El bot no muestra avisos y la persona vio su vista y sus manijas.
- F6: el bot recorre el nivel, pelea con límites humanos, cambia de arma por la distancia, va a los pickups que le hacen falta y sale de donde se traba.
- En red, juega en el servidor y una persona que toma su asiento lo reemplaza sin teclas trabadas.
- Nada del personaje, sus armas, su vida ni su red dentro de `addons/bot_kit`.
