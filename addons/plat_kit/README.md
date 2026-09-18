# PlatKit

Motor de **plataformas 2D** como hijo de un `CharacterBody2D`: coyote, jump buffer, gravedad en el apex, corrección de esquina, memoria de lift. **Cero** niveles, puntaje, dash o stamina.

Ventanas de perdón al estilo Celeste ([Maddy Thorson](https://maddymakesgames.com/articles/celeste_and_forgiveness/index.html)): agrandar timing y posición a favor del jugador. El addon **no** es un clon de Celeste.

## Instalar

```bash
./install.sh --addon /path/to/godot-project plat_kit
```

Habilitá el plugin **PlatKit**. Tools → `PlatKit: Add motor to selected CharacterBody2D`.

InputMap: `move_left`, `move_right`, `jump` (o cambiá los `@export`).

## Árbol

```
Player (CharacterBody2D)
├── CollisionShape2D
├── Visual
└── PlatMotor          # body = Player (o el parent)
```

Si usás una máquina de estados: va como **otro** hijo del actor. Un estado llama `request_jump()` / setea `axis` con `read_input = false` (MP: el host simula).

## Knobs (inspector)

| Grupo | Qué |
|-------|-----|
| Jump | `coyote_time`, `jump_buffer`, `cut_jump_mult` |
| Apex | `apex_gravity_mult` si se mantiene jump cerca de vy=0 |
| Corner | `jump_corner_pixels` (techo); `side_corner_pixels` (0 = off; dash del **juego** llama `try_side_corner_correct`) |
| Lift | `lift_remember` — velocidad de la plataforma unos frames después |
| Wall jump | off por default; `wall_extra_pixels` |

Dash, one-way pop, stamina refund: **glue del juego**, no este addon.

## MP

El motor corre donde hay autoridad de física (host / 1P). Guest no simula el salto. No metas PlatKit dentro de otro addon.
