---
name: godot-platformer-2d
description: >-
  Agrega perdón de plataformas 2D en Godot 4 (PlatKit): coyote time, jump
  buffer, gravedad reducida en el apex, corrección de esquina, memoria de
  lift. Usar cuando el usuario quiere un player de plataformas, coyote, jump
  buffer, feel tipo Celeste o /add-platformer-2d. No dash/stamina. No 3D.
---

# Godot — plataformas 2D (perdón)

Feel de movimiento 2D que **ensancha** ventanas de timing y posición a favor del jugador. No es un nivel, no es puntaje, no es Celeste.

Addon `addons/plat_kit/` (`PlatMotor` hijo de `CharacterBody2D`). Artículo de referencia: [Celeste & Forgiveness](https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html) (Maddy Thorson).

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project plat_kit
```

Enable **PlatKit**. Pedido acotado: `/add-platformer-2d`. Estados: [godot-fsm](../godot-fsm/SKILL.md). Juicy de land/jump: `/add-juicy`. Motion de squash: [godot-animation](../godot-animation/SKILL.md).

Ejemplo de referencia: `addons/plat_kit/examples/minimal_2d/` (F6), sin código: un `CharacterBody2D` con su `PlatMotor`, un piso y dos repisas. Los tests del addon (`res://addons/plat_kit/tests/plat_test_runner.gd`) juegan el motor sobre física real.

**No** copies el addon en un top-down, un fighter 3D o un menú.

## En el addon (defaults)

| Truco | Qué hace | Knob |
|-------|----------|------|
| Coyote time | Saltás un rato después de dejar el borde | `coyote_time` |
| Jump buffer | Jump apretado en el aire se consume al aterrizar | `jump_buffer` |
| Apex gravity | Con jump hold, mitad de gravedad cerca del pico | `apex_gravity_mult` |
| Jump corner | Si el techo recorta, wiggling horizontal | `jump_corner_pixels` |
| Lift remember | Momentum de plataforma, una vez (Godot lo suma al dejarla; el motor, en coyote) | `lift_remember` |
| Wall jump window | Extra píxeles (off) | `wall_jump_enabled`, `wall_extra_pixels` |

`read_input = false` + `axis` / `request_jump()` / `release_jump()` cuando un estado, una IA o la red alimentan el motor (sin `release_jump()` el salto queda siempre mantenido). Con `auto_process = false`, el que lo maneja llama `tick(delta)`.

## En el juego (no el addon)

Celeste también hace cosas **de ese título**. Documentadas en [forgiveness.md](forgiveness.md): dash corner, pop a one-way, super wall-jump, stamina refund. Implementalas como hijos / glue si el producto las pide. No las metas en `plat_kit`.

## Árbol

```
Player (CharacterBody2D)
├── CollisionShape2D
├── Visual
├── PlatMotor
└── States                 # opcional, fsm_kit
    ├── Idle
    ├── Air
    └── Wall               # solo si hay wall jump
```

## MP

El motor corre donde se simula (servidor o 1P); los demás dibujan el cuerpo sincronizado. La entrada del dueño llega al servidor por la red del juego (con MpKit, su `MpInput`) y el servidor le pasa `axis` / `request_jump()` / `release_jump()`. Los temporizadores del motor (coyote, buffer, lift) no son parte de la pose: una reconciliación no los rebobina.

## Anti-patrones

- `is_on_floor()` + jump **sin** coyote/buffer en un platformer de precisión.
- Copiar Madeline (dash, stamina, crystals) “porque el artículo”.
- Motor en el script del `CharacterBody2D` y otra copia en un estado.
- Autoload `PlayerController`.
