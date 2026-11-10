# BotKit

Bots que juegan a tu personaje como una persona, en 3D:
- **Un nodo en tu personaje.** `Bot3D` aprieta las mismas teclas que aprieta un jugador, en `bot.input`, que se lee igual que el `Input` de Godot. Tu personaje camina, salta y dispara con su propio código, sin saber si lo juega una persona o un bot.
- **Ve** al enemigo más cercano de un grupo, dentro de su alcance y sin muros en el medio, y recuerda dónde lo vio por última vez.
- **Pelea como una persona:** gira a una velocidad humana, apunta con error, tarda en reaccionar antes del primer tiro, dispara solo dentro de un cono, en ráfagas, adelanta el tiro a un enemigo que camina y tira granadas en parábola por encima de la cobertura. Mantiene su distancia y se corre de costado.
- **Elige el arma** que conviene a la distancia (`BotWeapon`), con las reglas propias de tu juego (calor, munición) en una función.
- **Recorre el nivel** por su navmesh: a un pickup (`BotGoal3D`), a donde vio a un enemigo, o a cualquier punto alcanzable. Si se traba, salta y elige otro camino.
- **Tus conductas** (huir, custodiar, seguir a un líder) son nodos hijos (`BotMode`): el bot hace lo que más quiere hacer.
- **Dificultad:** tres presets (fácil, normal, difícil) en un recurso (`BotDifficulty`).
- **En el editor:** su vista, su cono de disparo y su distancia de pelea dibujados en la vista 3D, con manijas para la altura de los ojos y de la puntería; el alcance de cada meta, con su manija.

No tiene código de red ni autoload, y BotKit no depende de ningún otro kit. En un juego en red corre en el servidor y sus teclas viajan como las de un jugador (abajo, [Red](#red)).

```bash
./install.sh --addon /path/to/godot-project bot_kit
```

Habilitá el plugin **BotKit** para los dibujos y las manijas del editor. Los nodos andan sin él.

**Ejemplos:**

- `examples/minimal_3d/minimal_3d.tscn`: lo mínimo, un robot que te caza alrededor de unos muros (abajo, [Ejemplo mínimo](#ejemplo-mínimo)). **Flechas:** caminar. **F:** dibujar lo que piensa.
- `examples/arena_3d/arena_3d.tscn`: cuatro bots pelean en una arena con un rifle y granadas, van a buscar salud y granadas cuando les faltan, huyen a la salud cuando están heridos (un `BotMode` del ejemplo) y reaparecen al morir. Teclas:
  - **1, 2, 3:** fácil, normal, difícil.
  - **F:** dibujar lo que piensa cada uno.
  - **Izquierda y derecha:** girar alrededor de la arena.

## Empezar

1. **Agregá un `Bot3D`** como hijo de tu personaje (el `CharacterBody3D`). Si su cabeza o su cámara gira para mirar arriba y abajo, ponela en `head`.
2. **Hacé que tu personaje lea `bot.input`** donde el de un jugador lee `Input`: los mismos métodos (`get_vector`, `is_action_pressed`, `is_action_just_pressed`). Las teclas de entrada son las de la plantilla de personaje de Godot (`ui_left`, `ui_right`, `ui_up`, `ui_down`, `ui_accept`) más `fire`; cambialas en el grupo «Controls».
3. **Poné a sus enemigos en el grupo `bot_target`** (Node › Groups). Su propio personaje nunca cuenta.
4. **Horneá el navmesh del nivel** (un `NavigationRegion3D` › Bake NavigationMesh): por ahí camina.

Con eso ya pelea y recorre el nivel. Para más: armas en `weapons`, una dificultad en `difficulty`, un `BotGoal3D` en cada pickup.

## Ejemplo mínimo

`examples/minimal_3d/minimal_3d.tscn` (F6): un robot y vos en un piso con cuatro muros.

```
Minimal3D (minimal_3d.gd)                # dibuja los tiros y cuenta los que te pegan
├── WorldEnvironment, Sun, Camera3D
├── Level (NavigationRegion3D)          # el navmesh horneado del piso y los muros
│   ├── Floor (StaticBody3D)            # en la capa 1, como los muros
│   └── Wall, Wall2, Wall3, Wall4
├── You (CharacterBody3D, you.gd)       # en el grupo bot_target: lee Input (las flechas)
├── Robot (CharacterBody3D, robot.gd)   # la plantilla de personaje de Godot, leyendo bot.input
│   ├── Head (Node3D)                   # a 1,6 m: gira arriba y abajo para mirar
│   └── Bot3D                           # head: Head; todo lo demás de entrada
└── Label
```

```gdscript
# robot.gd (lo esencial): la plantilla de Godot, con bot.input donde decía Input
func _physics_process(delta: float) -> void:
	var input := bot.input
	if not is_on_floor():
		velocity += get_gravity() * delta
	if input.is_action_just_pressed(&"ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var keys := input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	var direction := transform.basis * Vector3(keys.x, 0.0, keys.y)
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	move_and_slide()
	if input.is_action_pressed(&"fire") and _cooldown_s <= 0.0:
		_shoot()  # un rayo desde la cabeza, hacia donde mira
```

**Tips del ejemplo:**
- El bot gira al personaje (y la cabeza) él mismo. Tu código solo lo mueve hacia donde mira, como con un jugador.
- `fire` no está en el InputMap del proyecto, y no hace falta: las teclas del bot son suyas, no del teclado.
- El robot ve en todas las direcciones. Detrás de un muro (capa 1, la `sight_mask` de entrada) no te ve; al perderte, a veces va a donde te vio por última vez.

## Red

El kit no tiene red. En un juego en red, el bot corre donde se decide el juego (el servidor) y aprieta las teclas de un asiento como si fuera su jugador: sus señales `pressed`, `released` y `value_changed` tienen la forma justa para conectarlas a la entrada de red del juego. Apagá `turn_body`, así el bot solo escribe hacia dónde mira y tu personaje lo aplica, como con un jugador.

**Con MpKit:** en el servidor, sobre el peón del asiento libre.

```gdscript
var bot := preload("res://bot.tscn").instantiate() as Bot3D  # un Bot3D guardado como escena
bot.turn_body = false
pawn.add_child(bot)
var keys := pawn.get_node(^"MpInput") as MpInput
bot.input.pressed.connect(keys.bot_press)
bot.input.released.connect(keys.bot_release)
bot.input.value_changed.connect(keys.bot_set_value)  # yaw y pitch, en radianes
```

Cuando una persona toma el asiento (`keys.has_player()`, o `Mp.gate().joined_late`), liberá el bot con `bot.queue_free()`: suelta todas las teclas al irse. Para llenar los asientos libres, mirá el ejemplo `bots_2d` de MpKit.

**Sin MpKit:** `enabled = multiplayer.is_server()` en cada máquina, y lo que tu red haga con las teclas de un jugador, conectado a las mismas tres señales.

## El bot (`Bot3D`)

| Propiedad | De entrada | Qué es |
|---|---|---|
| `enabled` | sí | Apagado suelta todas las teclas, olvida a su enemigo y espera. Apagalo donde no se decide el juego y mientras su personaje está muerto |
| `body` | su padre | El personaje que juega |
| `head` | vacío | Lo que gira arriba y abajo para mirar (su `rotation.x`) |
| `difficulty` | `presets/normal.tres` | Qué tan bien juega |
| `weapons` | vacío | Sus armas; vacío, una sola en `fire_action`, a cualquier distancia, en ráfagas |
| `target_group` | `bot_target` | Sus enemigos son los nodos de este grupo |
| `turn_body` | sí | Gira al personaje y a `head` él mismo; apagado solo escribe `yaw` y `pitch` |
| Controls | las de la plantilla de Godot | `move_left` (`ui_left`), `move_right`, `move_forward` (`ui_up`), `move_back`, `jump_action` (`ui_accept`), `fire_action` (`fire`), `yaw_value`, `pitch_value` |
| Eyes | 1,6 m / 1,1 m | `eye_height_m` (desde dónde mira), `aim_height_m` (dónde apunta en un enemigo), `sight_mask` (lo que tapa su vista y sus tiros: los muros), `pitch_limit_deg` |
| Fight | | `fight_want` (1), `strafe_s` (cada cuánto cambia de costado), `jump_chance` |
| Roam | | `roam_want` (0,1), `navigation_layers`, `arrive_m`, `reach_slack_m`, `stuck_s` y `stuck_m` (cuándo está trabado), `repath_s` |
| Thinking | 0,2 s | `think_s` (cada cuánto mira y decide), `random_seed` (0: distinto cada vez) |
| `show_in_game` | no | Dibuja, mientras el juego corre, su enemigo, su camino, su meta y qué hace |

**Lo que lee el juego:** `input` (sus teclas), `target` (su enemigo, o null), `weapon`, `mode` (`&"fight"`, `&"roam"` o el nombre de un `BotMode`), `goal` (a dónde camina), `last_seen`.

**Señales:** `target_changed(enemigo)`, `weapon_changed(arma)` (cambiá el arma de tu personaje), `mode_changed(modo)`, `stuck`.

**Las reglas propias del juego, en funciones** (todas opcionales):
- `is_enemy = func(node) -> bool`: si un nodo del grupo es enemigo (un equipo, un cuerpo muerto).
- `choose_target = func() -> Node3D`: tu propia elección de enemigo, en lugar de su vista (otra percepción, una pelea con guion).
- `weapon_score = func(weapon, distance_m, score) -> float`: tu regla sobre un arma (calor, munición, la espalda de un enemigo); 0 es «ahora no».

**Lo que usa un modo:** `walk_to(punto, delta)`, `aim_and_fire(delta)`, `move(dirección)`, `look_toward(dirección, delta)`, `turn_to(yaw, pitch, delta)`, `press(acción)`, `release(acción)`, `tap(acción)`, `jump()`, `stop()`, `can_see(punto, de)`, `random_reachable_point()`, `eye_position()`, `flat_distance_to(punto)`, `current_difficulty()`.

## Querés → escribí

| Querés | Escribí |
|---|---|
| Un bot en tu personaje | Un `Bot3D` hijo del personaje, y el personaje lee `bot.input` |
| Que pelee con otros bots | Todos los personajes en el grupo `bot_target` |
| Equipos | `bot.is_enemy = func(node): return node.team != team` |
| Más fácil o más difícil | `bot.difficulty = preload("res://addons/bot_kit/presets/hard.tres")` |
| Un arma de cerca y una de lejos | Dos `BotWeapon` en `weapons`, con su `min_m` y `max_m`; cambiá el arma en `weapon_changed` |
| Una granada en parábola | `projectile_speed_m_s` y `gravity_m_s2` en su `BotWeapon` (los mismos que tu granada); `trigger` en TAP |
| Que no use un arma sin munición | `bot.weapon_score = func(weapon, distance, score): return 0.0 if sin_munición else score` |
| Que vaya a buscar un pickup | Un `BotGoal3D` en la escena del pickup; escondé el pickup cuando lo toman |
| Que solo lo busque si le hace falta | `goal.wanted = func(bot): return bot.body.health < 80` |
| Que huya cuando está herido | Un `BotMode` hijo del bot que quiere 2 bajo cierta vida y camina con `bot.walk_to()` |
| Que el bot no juegue mientras está muerto | `bot.enabled = false`; al revivir, `true` |
| Ver lo que piensa | `show_in_game` |
| Un bot en red | [Red](#red) |

## Armas (`BotWeapon`)

Un recurso por arma. En una pelea, en cada pensamiento, el bot elige la de mayor puntaje a la distancia de su enemigo y lo avisa con `weapon_changed`. Si ninguna puntúa, no dispara (pero sigue peleando).

| Grupo | Propiedades |
|---|---|
| | `name` (el de tu juego), `fire_action` (vacío: la del bot) |
| When | `score` (el mayor gana), `min_m` y `max_m` (su alcance), `chance` (cada cuánto la elige si no la tiene: una mina de vez en cuando), `keep_m` (la distancia que mantiene con ella; -1: la de la dificultad), `fire_within_m` (dispara solo así de cerca: un martillo que elige para acercarse) |
| Aim | `projectile_speed_m_s` (0: pega al instante; si no, adelanta el tiro), `gravity_m_s2` (mayor a 0: la tira en parábola, por encima de la cobertura), `lead_max_s`, `aim_height_m` (-1: la del bot; bajo para una explosión) |
| Trigger | `trigger`: HOLD (apretado, en las ráfagas de la dificultad), TAP (un toque cada `tap_every_s`), CHARGE (apretado hasta `charge_s` y suelto; `tap_chance` de un toque corto) |

## Dificultad (`BotDifficulty`)

| Grupo | Propiedades | Fácil / normal / difícil |
|---|---|---|
| Seeing | `sight_m`, `reaction_s` | 25 / 35 / 45 m; 1,2 / 0,8 / 0,55 s |
| Aim | `turn_deg_s`, `aim_error_deg`, `fire_cone_deg` | 92 / 149 / 229 °/s; 14 / 9 / 6°; 5 / 6 / 7° |
| Firing | `burst_s`, `burst_pause_s` | 0,4 + 1,3 / 0,8 + 0,6 / 1,5 + 0,25 s |
| Moving | `move_scale`, `keep_m`, `chase_chance`, `goal_reach_scale` | 0,6 / 0,78 / 1; 12 / 10 / 9 m; 0,25 / 0,6 / 1; 0,5 / 1 / 1,4 |

Un preset es compartido: para ajustar un solo bot, hacé su dificultad única en el inspector (o duplicá el archivo).

## Metas (`BotGoal3D`)

Un lugar al que vale la pena caminar para un bot sin nadie con quién pelear: ponelo en la escena de un pickup. El bot camina a la meta de mayor `priority` dentro de su `reach_m` (por la escala de su dificultad), la más cercana de esas. Una meta escondida (el pickup se tomó y se escondió) o apagada (`enabled`) no cuenta para ningún bot. Una que no puede alcanzar (arriba de un mueble) la deja de lado unos segundos. `wanted = func(bot) -> bool` es tu regla de si ese bot la quiere ahora.

## Modos propios (`BotMode`)

Lo que hace tu bot además de pelear y recorrer: huir, custodiar una puerta, seguir a un líder, llevar una bandera. Un nodo hijo del `Bot3D` que sobrescribe `_want(bot)` (cuánto quiere correr ahora) y `_tick(bot, delta)` (cada frame mientras corre), y si hace falta `_enter` y `_exit`. En cada pensamiento el bot hace lo que más quiere: su pelea quiere `fight_want` (1) mientras ve a un enemigo, su recorrida `roam_want` (0,1) siempre. Un empate deja lo que hace.

```gdscript
# flee.gd (del ejemplo arena_3d): herido, corre a la salud más cercana
extends BotMode

func _want(bot: Bot3D) -> float:
	return 2.0 if bot.body.health < 35.0 and _nearest_health(bot) != null else 0.0

func _tick(bot: Bot3D, delta: float) -> void:
	bot.walk_to(_nearest_health(bot).global_position, delta)
```

## En el editor

- **El bot:** seleccionalo y la vista 3D dibuja su vista (el `sight_m` de su dificultad, alrededor de sus ojos), su cono de disparo hacia adelante, la distancia que mantiene en una pelea (alrededor de sus pies) y dónde apunta en un enemigo. Las manijas mueven `eye_height_m` y `aim_height_m`.
- **La meta:** su alcance, con una manija para arrastrarlo.
- Cada arrastre se deshace. La vista, el cono y la distancia viven en la dificultad (un preset compartido): se dibujan y se cambian en el inspector.
- **Avisos:** un bot que no está en un personaje, un grupo vacío, un arma con `min_m` mayor a `max_m`, un `BotMode` fuera de un bot, una meta sin alcance.

## Rendimiento

- Piensa cada `think_s` (0,2 s), y cada bot en su propio momento: busca a su enemigo (un rayo por candidato dentro de su alcance), su arma y su modo.
- En cada frame: un rayo para la línea de tiro mientras apunta, unas pocas consultas al navmesh mientras pelea (para no salirse de la malla), y su camino.
- Pide su camino al NavigationServer3D cuando cambia la meta y cada `repath_s` (1 s). Un punto al azar prueba hasta ocho caminos.
- No crea nodos mientras juega. `show_in_game` sí dibuja; dejalo apagado en un servidor.
- Medido en una M4: 16 bots peleando en una arena con muros cuestan unos 0,8 ms por frame en total (0,05 ms cada uno), sin contar el movimiento de sus personajes.

## Tips y recomendaciones

- **Guardá tu bot como escena** (el `Bot3D` con sus armas y sus modos) y hacé aparecer copias en cada personaje que juega un bot.
- **Una capa para los muros.** `sight_mask` es lo que tapa su vista y sus tiros. Si los personajes también están en la máscara, el suyo y el de su enemigo nunca tapan; un tercero sí.
- **El navmesh, horneado en el editor.** Un nivel que lo hornea al cargar tiene que esperar unos frames: el bot se queda quieto hasta que la malla está.
- **La granada del bot y la del juego, iguales.** Si `projectile_speed_m_s` y `gravity_m_s2` son los de tu proyectil, la parábola cae donde apuntó.
- **El error de puntería es humano:** con un error mayor que el cono, el bot dispara menos (espera a que el error caiga dentro). Para un bot que dispara mucho y erra, bajá el error y subí el cono.
- **Ve en todas las direcciones.** Para un cono de vista, oídos o memoria, conectá tu percepción en `choose_target`.

## De dónde salen las ideas

La primera versión fueron los bots de un shooter en red, que llenaban los asientos vacíos y le dejaban el lugar a una persona. Este kit los hizo genéricos:
- **Un bot que aprieta teclas en lugar de mover el cuerpo:** el personaje se mueve igual con una persona o con un bot, y la red no cambia.
- **Límites humanos en la puntería** (giro, error, reacción, cono, ráfagas), como en los bots de los shooters de arena: así un bot se puede ganar.
- **Elegir por puntaje** (el arma, lo que hace): cada opción dice cuánto quiere, y gana la que más quiere. Agregar una es agregar un nodo, no tocar una máquina de estados.
- **Recorrer por metas con prioridad**, a donde vio al enemigo y a un punto al azar alcanzable, con un salto para salir de donde se trabó.

## Tests

```bash
godot --headless --path botkit_lab --script res://addons/bot_kit/tests/bot_test_runner.gd
```

El resultado es `BOTKIT TESTS PASS (n)`. Los tests cubren:

- **sus teclas:** se leen como `Input` (fuerza, eje, vector de largo 1 como mucho, recién apretada en su frame), y sus señales salen una vez por cambio y se conectan a otra entrada;
- **la matemática de la puntería:** los ángulos del adelante de Godot, el giro por el camino corto, el adelanto por el tiempo de vuelo, una parábola que cae en su punto;
- **la vista:** el más cercano sin muros en el medio, uno escondido o fuera de alcance no cuenta, su propio cuerpo y el del enemigo nunca tapan, `is_enemy`, `choose_target`, un enemigo liberado;
- **la pelea:**
  - gira a su velocidad, reacciona y recién dispara cuando apunta dentro de su cono;
  - ráfagas y pausas; TAP y CHARGE; un error mucho mayor que el cono no dispara;
  - mantiene su distancia, se corre de costado y retrocede si está muy cerca; la parábola de una granada;
- **las armas:** por distancia y puntaje, `chance`, la regla del juego, sin arma que sirva no dispara, `fire_within_m` y su propia distancia;
- **la recorrida:** la meta de mayor prioridad a su alcance (rodeando un muro), una escondida o que no quiere no cuenta, la escala de la dificultad, a donde vio al enemigo, un punto al azar nunca en una isla, trabado salta y cambia, sin navmesh se queda quieto;
- **los modos:** pelear y recorrer, un modo que quiere más toma el control y lo devuelve, un empate deja lo que hace, uno apagado nunca corre, un modo camina con las funciones del bot;
- **apagado o liberado:** suelta todas las teclas, también las de una entrada a la que se conectó; sin `turn_body` solo escribe hacia dónde mira;
- **cada archivo carga; los presets suben de dificultad; lo que corre en un servidor no usa cámara ni pantalla; no se nombra ningún otro kit ni juego;**
- **los dos ejemplos, de punta a punta.**

Un test que se corta por un error de script, o que nunca llega a chequear nada, falla.

Las manijas tienen su propio chequeo en un editor real:

```bash
BOTKIT_EDITOR_CHECK=1 godot --headless --editor --path botkit_lab
```

Revisa que el bot y la meta tengan el gizmo del kit, arrastra sus manijas desde la cámara de la vista 3D, deshace y rehace cada arrastre, y guarda la escena con sus valores. Imprime `EDITOR CHECK PASS`.

## Fuera del kit

Esto es del juego:

- el personaje y cómo se mueve con las teclas;
- las armas de verdad: el daño, la munición, el calor (el kit recibe tu regla en `weapon_score`);
- qué pickup vale la pena para quién (`wanted`);
- la vida, la muerte y la reaparición (apagá el bot con `enabled`);
- en red: qué asiento juega un bot, y cuándo una persona lo toma.
