# PerceptionKit

Lo que percibe un actor, en 2D y 3D:
- **Vista:** un cono que empieza a ver a una distancia y sigue viendo hasta otra más lejana, conciencia de lo que tiene cerca en todas las direcciones, y muros que tapan.
- **Oído:** los ruidos del juego, cada uno oído hasta su propia distancia.
- **Cualquier otro sentido:** un tipo propio del juego (una alarma, un olor, un golpe, una linterna prendida), sin tocar el kit.
- **Memoria:** cada cosa percibida se recuerda con dónde estuvo por última vez, y se olvida pasado un tiempo.
- **En el editor:** la vista dibujada en las vistas 2D y 3D, con manijas para arrastrarla; cada arrastre se deshace.

No tiene red, ni reglas de juego, ni autoload, y PerceptionKit no depende de ningún otro kit. Dos señales, `perceived` y `forgotten`, y unas pocas preguntas (`latest()`, `sees_any()`, `is_aware()`) son todo lo que lee la máquina de estados del juego.

```bash
./install.sh --addon /path/to/godot-project perception_kit
```

Habilitá el plugin **PerceptionKit** para las manijas del editor. Los nodos andan sin él.

**Ejemplos:**

- `examples/minimal_3d/minimal_3d.tscn`: lo mínimo, un guardia que gira la cabeza hacia lo que percibe (abajo, [Ejemplo mínimo](#ejemplo-mínimo)).
- `examples/minimal_2d/minimal_2d.tscn`: lo mismo en 2D.
- `examples/guards_3d/guards_3d.tscn`: un patio con dos guardias que vigilan, te miran, buscan donde te vieron u oyeron y vuelven a su lugar. Teclas:
  - **Flechas:** caminar.
  - **Espacio:** un ruido; lo oye cada guardia a menos de 12 m.
  - **L:** tu linterna, un objetivo de tipo `&"light"` que los guardias ven desde 2,5 veces más lejos.
  - **N:** noche; los guardias ven a la mitad de distancia.
  - **La mancha oscura** es sombra: ahí se te ve menos.

## Empezar

1. **Agregá un PerceptionSensor3D** en la cabeza del actor (hijo de lo que gira para mirar). Mira hacia su -Z. Su vista se ve en la vista 3D.
2. **Agregá un PerceptionTarget3D** en lo que tiene que ver, donde se lo ve (el pecho de un personaje).
3. **Arrastrá las manijas de la vista** para darle tamaño: vista, pérdida, ángulo, cercanía, altura de ojos.
4. **Conectá `perceived` y `forgotten`**, o leé `latest()` desde los estados del actor.

En 2D, lo mismo con PerceptionSensor2D (mira hacia su +X; rotalo) y PerceptionTarget2D, en píxeles.

## Ejemplo mínimo

`examples/minimal_3d/minimal_3d.tscn` (F6): un guardia, un muro y vos. Las flechas te mueven; Espacio hace un ruido.

```
Minimal3D (minimal_3d.gd)
├── WorldEnvironment, Sun, Camera3D, Floor
├── Wall (StaticBody3D)                 # en la capa 1: te tapa
├── Guard (StaticBody3D)                # el cuerpo propio del sensor: nunca le tapa la vista
│   └── Head (Node3D)                   # gira hacia lo que percibe
│       ├── Nose
│       └── Sensor (PerceptionSensor3D) # vista 12, pérdida 16, ángulo 100°, cercanía 2, show_in_game
└── Player (CharacterBody3D)
    └── Target (PerceptionTarget3D)     # en el pecho
```

```gdscript
# minimal_3d.gd (lo esencial)
func _physics_process(delta: float) -> void:
	var latest := sensor.latest()  # lo más reciente que recuerda, o null
	if latest != null:
		var to := latest.position - head.global_position
		head.rotation.y = rotate_toward(head.rotation.y, atan2(-to.x, -to.z), deg_to_rad(TURN_DEG_S) * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		sensor.hear(player.global_position, NOISE_RADIUS_M, player.get_instance_id())
```

**Tips del ejemplo:**
- La cabeza gira y el sensor con ella. El cuerpo del guardia se encuentra solo (el cuerpo más cercano arriba del sensor), así que el rayo desde los ojos nunca lo toca; lo mismo con tu cuerpo alrededor de tu objetivo.
- `latest()` es todo lo que necesita el guardia: sigue apuntando a donde te vio u oyó por última vez hasta que te olvida, y después es null.
- Nada en el script sabe del muro: lo sabe la máscara de oclusión (capa 1).

## El sensor (`PerceptionSensor3D` / `PerceptionSensor2D`)

| Valor | Qué hace |
|---|---|
| `sight_radius_m` (`_px`) | Empieza a ver un objetivo dentro de esta distancia y del ángulo de la vista |
| `lose_radius_m` (`_px`) | Sigue viendo al que ya ve hasta esta distancia (sin parpadeo en el borde) |
| `view_angle_deg` | La vista entera, alrededor de su eje vertical (360: todo alrededor). La altura no cuenta |
| `near_radius_m` (`_px`) | Dentro de esta distancia nota también a un objetivo que tiene atrás (los muros igual lo tapan) |
| `eye_height_m` (3D) | Los ojos, a esta altura sobre el sensor (0: el sensor está en los ojos) |
| `occlusion_mask` | Las capas del mundo que tapan a un objetivo |
| `body` | Su propio cuerpo, que nunca estorba. Vacío: el cuerpo más cercano arriba de él |
| `sight_scale` | Escala todos los radios de vista: noche, niebla, un destello que enceguece |
| `reach_by_kind` | Tipos que ve desde más lejos: `{&"light": 2.5}` |
| `hearing_scale` | Escala el radio de todos los ruidos: 0 sordo, 2 oído fino |
| `memory_s` | Olvida a uno este tiempo después de percibirlo por última vez |
| `sense_hz` | Miradas por segundo (5). Cada sensor mira en su propio momento, el mismo en cada corrida |
| `enabled` | Apagado no percibe nada y olvida todo, sin señales |
| `show_in_game` | Dibuja su vista en el juego: gris (nada), ámbar (recuerda algo que no ve), rojo (ve). Nunca en headless |

**Los bandos son capas de física.** La capa de colisión de un objetivo es su bando; un sensor ve a los objetivos de las capas de su máscara de colisión. De entrada los dos están en la capa 1, como cualquier área, así que todos ven a todos. Nombrá una capa por bando (Project Settings › Layer Names), aparte de las del mundo, poné cada objetivo en la capa de su bando y marcá los bandos que ve cada sensor: el motor de física los filtra gratis. El inspector muestra solo la máscara de un sensor y la capa de un objetivo: lo que fija el kit (nada detecta a un sensor, un objetivo no detecta nada) ni se muestra ni se guarda.

**Una mirada** toma los objetivos dentro de la esfera propia del sensor (de radio `reach_m()`, interna, no se guarda), y para cada uno:
1. su radio: `lose_radius_m` si ya lo ve, si no `sight_radius_m`, por `sight_scale`, `reach_by_kind[target.kind]` y la `visibility` del objetivo;
2. dentro de `near_radius_m`, o dentro del radio y del ángulo de la vista;
3. un rayo desde los ojos, que ignora el cuerpo del sensor y el del objetivo.

Lo que pasa, lo ve. Un objetivo que veía y no pasa deja de verse pero sigue recordado, donde estuvo por última vez.

## El objetivo (`PerceptionTarget3D` / `PerceptionTarget2D`)

| Valor | Qué hace |
|---|---|
| `enabled` | Apagado, ningún sensor lo ve (sigue recordado hasta que lo olvidan) |
| `visibility` | 0 a 1: qué tan visible está ahora. El juego la baja en la oscuridad, a cubierto, agachado |
| `kind` | Qué da verlo: `&"sight"`, o uno propio del juego (`&"light"` para una linterna) |
| `radius_m` (`radius_px`) | Su propia esfera (interna, no se guarda) |
| `body` | Su propio cuerpo, que nunca lo tapa. Vacío: el cuerpo más cercano arriba de él |

## Lo que percibe (`PerceptionStimulus`)

| Campo | Qué es |
|---|---|
| `kind` | `PerceptionStimulus.SIGHT`, `HEARING`, o un StringName propio del juego |
| `position` | Dónde estuvo por última vez (`position_2d` en 2D) |
| `strength` | 1 en el ojo (o en el ruido), 0 en el borde de su radio |
| `age_s` | Segundos desde que se percibió por última vez |
| `sensing` | Percibido en la última oportunidad (visto en la última mirada, oído desde entonces) |
| `target` | El objetivo visto, o null (un ruido, o un objetivo liberado) |
| `key` | El id de instancia del objetivo, o el `source` del ruido |

El sensor guarda uno por objetivo visto y uno por tipo y fuente, y actualiza el mismo objeto mientras lo sigue percibiendo: un estado que guarda uno lo lee siempre fresco.

## Señales y preguntas

| Querés | Escribí |
|---|---|
| Reaccionar cuando nota algo | `sensor.perceived.connect(func(stimulus): ...)`: una vez cuando empieza a ver a un objetivo, en cada ruido y en cada `sense()` |
| Reaccionar cuando se rinde | `sensor.forgotten.connect(func(stimulus): ...)`: `stimulus.position` es dónde estuvo por última vez |
| Saber adónde mirar o ir | `sensor.latest()`, o `latest(PerceptionStimulus.HEARING)` |
| Saber si ve a alguien ahora | `sensor.sees_any()`, `sensor.sees(target)` |
| Saber si está en alerta | `sensor.is_aware()`: recuerda algo |
| Todo lo que recuerda | `sensor.remembered()`, o de un tipo |
| Lo que sabe de un objetivo | `sensor.stimulus_of(target)` |

## En el juego

| Querés | Escribí |
|---|---|
| Avisarle de un ruido | `sensor.hear(position, radius_m, source)`: true si lo oyó. Conectá la señal de ruidos del juego a cada sensor que escucha |
| Un sentido propio del juego | `sensor.sense(&"alarm", position, strength, source)` |
| Que perciba solo el servidor | `sensor.enabled = is_server` (lo decide el juego; el kit no tiene red) |
| Esconderse en la oscuridad o a cubierto | `target.visibility = 0.3` |
| Noche o niebla para un guardia | `sensor.sight_scale = 0.5` |
| Una linterna que se ve de lejos | Un PerceptionTarget3D con `kind = &"light"` en la linterna, `enabled` mientras está prendida, y `reach_by_kind = {&"light": 2.5}` en los sensores |
| Dejar de ver a uno muerto o escondido | `target.enabled = false` |
| Olvidar todo (un respawn) | `sensor.forget_all()` |
| Una regla propia del juego para el radio | Un script que `extends PerceptionSensor3D` y sobrescribe `_sight_radius(target, seen, radius) -> float`; si puede devolver más que `reach_m()`, sobrescribí `reach_m()` también |
| Una memoria compartida por un escuadrón | Una `PerceptionMemory` propia del juego, alimentada desde los `perceived` del escuadrón |
| Los chequeos puros, en un test o una herramienta | `PerceptionGeometry.in_view_3d(eye, basis, point, half_angle)`, `in_view_2d()`, `strength_at()` |

## En el editor

Seleccioná un sensor:
- **3D:** su vista se dibuja a la altura de sus ojos, con cinco manijas: **radio de vista**, **radio de pérdida** (queda por encima del de vista), **ángulo** (en el borde del arco de vista), **cercanía** (atrás) y **altura de ojos** (el punto de los ojos; arrastrala mirando de costado).
- **2D:** las mismas cuatro manijas, sin altura de ojos, en la vista 2D.

Cada arrastre es un paso del historial del editor (Ctrl+Z), y uno cancelado deja el valor como estaba. El árbol de escena avisa cuando el radio de pérdida queda por debajo del de vista y cuando la máscara está vacía.

## Rendimiento

Una mirada es barata y llega `sense_hz` veces por segundo, cada sensor en su propio momento, así que nunca miran todos en el mismo frame:
- el motor de física da solo los objetivos dentro de la esfera del sensor, en las capas de su máscara;
- el radio y el ángulo van antes que el rayo, y solo lo que los pasa tira uno, reusando la consulta;
- la memoria envejece en cada frame de física, unas pocas entradas cada una.

**Medido** en headless en una Mac M4, un patio de 40 × 40 m con muros, a 5 Hz:

| Sensores × objetivos | Una mirada | Por frame de física |
|---|---|---|
| 8 × 4 | 7 µs | 0,004 ms |
| 50 × 30 | 38 µs | 0,16 ms |
| 200 × 100 | 163 µs | 2,7 ms |

Con muchos sensores, bajá primero `sense_hz`, después los radios (menos candidatos).

## Tips y recomendaciones

- **Primero las manijas.** Dale tamaño a un sensor con sus manijas en la escena del actor; todas las instancias toman esos valores, y un valor cambiado en una instancia es solo de esa.
- **El sensor en la cabeza.** Girar la cabeza gira la vista; el cuerpo se encuentra solo.
- **Una capa por bando.** De entrada todos ven a todos (capa 1), y las esferas de los sensores también se cruzan con los cuerpos del mundo que están en ella.
- **En una máquina de estados, leé `latest()`, no las señales.** Las señales empiezan y terminan un estado; `latest()` dice adónde mirar mientras dura.
- **Un ruido por fuente.** Dale a `hear()` un `source` (el slot de un jugador, un id de instancia): la misma fuente queda en un solo recuerdo, con su posición más nueva.
- **La histéresis es el punto.** Dejá `lose_radius_m` un cuarto o un tercio por encima de `sight_radius_m`.
- **Los juegos en red** perciben solo en el servidor (`enabled`), y mandan lo que hace el actor con eso, no la percepción.

## De dónde salen las ideas

La percepción de IA de Unreal Engine le dio forma al modelo:
- vista con un radio de vista, un radio de pérdida más lejano y un ángulo periférico;
- ruidos que se reportan al sistema con un alcance;
- estímulos con edad, olvidados pasada una edad máxima;
- los ojos del actor como punto de la vista.

Los juegos de sigilo (Thief, Splinter Cell) hacen que la luz y la oscuridad cambien qué tan visible es un objetivo: acá, `visibility` y la luz como un tipo propio.

## Tests

```bash
godot --headless --path perceptionkit_lab --script res://addons/perception_kit/tests/perception_test_runner.gd
```

El resultado es `PERCEPTIONKIT TESTS PASS (n)`. Los tests cubren:

- **la geometría:** la vista en 3D (sin la altura, girada, escalada) y en 2D, la fuerza, las líneas dibujadas, la cuenta de las manijas;
- **la memoria:** nuevo y refrescado, envejecer y olvidar, el más reciente (uno visto gana un empate), tipos;
- **el sensor 3D con física:**
  - visto dentro de la vista y el radio, una vez; no fuera del ángulo ni del radio;
  - mantenido hasta el radio de pérdida, después recordado donde estuvo por última vez;
  - los muros tapan (y solo en la máscara de oclusión), la cercanía atrás, un muro tapa también a uno cercano;
  - su propio cuerpo y el del objetivo nunca tapan; los ojos por encima de un muro bajo;
  - ruidos: oídos por radio y `hearing_scale`, cada uno percibido, un recuerdo por fuente;
  - olvidado pasado `memory_s`, visto de nuevo antes no se percibe de nuevo, un objetivo liberado se olvida sin objetivo;
  - bandos por capas, `visibility`, `sight_scale`, `reach_by_kind`, un `_sight_radius()` propio del juego;
  - `sense()`, apagado y prendido, un objetivo apagado;
  - su esfera interna y no guardada, el aviso, nada dibujado en headless, cada sensor en su propio momento;
- **el sensor 2D:** la vista apuntada con la rotación, el radio de pérdida y la memoria, muros y cercanía, ruidos, bandos y visibilidad;
- **los arrastres de las manijas** en 3D (girado) y 2D (escalado);
- **una escena guardada y cargada de nuevo** conserva la máscara de un sensor y la capa de un objetivo, y no guarda nada propio del kit;
- **cada script carga; los sensores no usan cámara, imagen ni shader; no se nombra ningún otro kit;**
- **los tres ejemplos, de punta a punta.**

Un test que se corta por un error de script, o que nunca llega a chequear nada, falla.

Las manijas tienen su propio chequeo en un editor real: el gizmo del guardia, arrastrar sus manijas de vista, ángulo y ojos desde la cámara de la vista 3D con deshacer y rehacer, un arrastre cancelado, el aviso, la escena guardada; después las manijas del sensor 2D con el mouse y su deshacer.

```bash
PERCEPTIONKIT_EDITOR_CHECK=1 godot --headless --editor --path perceptionkit_lab
```

Imprime `EDITOR CHECK PASS`.

## Fuera del kit

Esto es del juego:

- lo que hace un actor con lo que percibe (sus estados, sus niveles de alerta, perseguir);
- de dónde salen los ruidos (la señal propia del juego, que llama a `hear()`);
- quién percibe en un juego en red (`enabled`);
- sus bandos (nombres de capas) y lo que significan la luz y la oscuridad (`visibility`, `sight_scale`).
