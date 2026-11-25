# Tamaño chico — por entidad

El default. Para uno o dos programadores y hasta unos 10 tipos de entidad. Sigue la recomendación de Godot: cada cosa lo más cerca posible de la escena que la usa ([organización del proyecto](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)).

Valen los lineamientos comunes de [SKILL.md](SKILL.md): simple y predecible, composición, editor, núcleo puro opcional, una responsabilidad por script, señales arriba y llamadas abajo.

## Forma del proyecto

Una carpeta por tema en la raíz, sin una carpeta `scenes/` que envuelva todo.

```
res://
├── main/                  main.tscn, main.gd            # entrada: World + GUI
├── player/                player.tscn, player.gd
│   ├── model/             player.glb, player_material.tres
│   └── audio/
├── enemies/
│   ├── enemy.tscn         # la escena base
│   ├── enemy.gd
│   ├── enemy_type.gd      # class_name EnemyType extends Resource
│   ├── bat/               bat_type.tres, bat.png
│   └── tank/              tank_type.tres, tank.tscn (heredada de enemy.tscn)
├── levels/
│   └── forest/            forest.tscn, forest_env.tres
├── match/                 match.tscn, match.gd, match_rules.gd   # nodo + núcleo puro
├── ui/
│   ├── hud/               hud.tscn, hud.gd
│   └── game_theme.tres
├── shared/                lo que usan dos o más entidades, por tipo
│   ├── components/        health.gd, hitbox.tscn
│   ├── shaders/           hit_flash.gdshader
│   ├── materials/         stone_material.tres
│   └── vfx/               hit_flash.tscn
├── locale/                texts.csv                     # los textos del jugador
├── autoloads/             events.gd
├── debug/                 escenas de prueba (fuera del export)
├── addons/                kits
└── docs/                  architecture.md, tuning.md, .gdignore
```

Reglas de carpetas y sufijos (`_type.tres`, `_material.tres`, …): [godot-code-quality](../godot-code-quality/SKILL.md) §1. En corto:

- Lo que usa una sola entidad vive en su carpeta.
- Si la carpeta pasa de unos 8 archivos, el arte baja a subcarpetas por tipo **dentro de la entidad** (`model/`, `textures/`, `audio/`, `vfx/`). La escena, su script y su `.tres` de tipo quedan arriba.
- Lo que usan dos o más entidades va a `shared/`, ahí sí por tipo.
- El código que conecta un kit con el juego (arrancar la red, cargar el mundo) es un autoload en `autoloads/` o un nodo de `main/`. No hay carpeta `glue/`, `scripts/`, `resources/` ni `assets/`.

Inválido: un `player.gd` de mil líneas con `match weapon`.

## Escenas autónomas

Cada `.tscn` debe poder abrirse con **F6** y funcionar (o avisar). Docs: [organización de escenas](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html).

- No depende de lo que la rodea. Lo que falta, el padre se lo pasa: `@export var health: Health`, un `Callable` o un nodo.
- Señales en **pasado** y tipadas. El **padre** hace `child.died.connect(...)`. El hijo no llama `get_parent().on_died()`.
- Nodos de *esta* escena: `%UniqueName` (`%Sprite`). Entre escenas: una referencia `@export`, no `get_node("../../Audio")`.
- Si una referencia obligatoria está vacía: `@tool` + `_get_configuration_warnings()`.
- Relacional, no espacial: ¿al borrar el padre debe borrarse el hijo? Si no, hermano. Posición relativa: `RemoteTransform2D` / `RemoteTransform3D`.
- `Main` (entrada) → `World` (se reemplazan los niveles) + `GUI` (hermana; no muere con el nivel).

## Una responsabilidad por script

- Un nodo = un trabajo. Movimiento ≠ vida ≠ disparo ≠ HUD.
- Extraer una packed scene hija cuando el script hace dos sistemas.
- Herencia de scripts rasa: `State extends Node`. No `EliteFlyingEnemy extends FlyingEnemy extends Enemy`.
- El mundo **compone** spawners, cámara y efectos. No puntúa en el mismo archivo que crea enemigos.
- Sin tope de líneas: un script cohesivo de 400 líneas está bien; dos sistemas en 120 líneas, no.

## Estado de partida

- La escena `match/match.tscn`, con un nodo `Match` chico, instanciada en el mundo. Sus reglas (duración, vidas) son `@export` de su raíz: un archivo con nombre obvio.
- Las reglas que merecen un test van al núcleo puro de al lado (`match_rules.gd`).
- Autoload **solo si** el estado sobrevive al cambio de escena.
- Con red: solo el host cambia ese estado.

## Autoloads

Sí: el bus `Events` (solo señales tipadas), `MpKit`, el arranque de la red.
No: `EnemyManager`, una fábrica global de proyectiles, el inventario de la partida si puede vivir en el árbol. Audio: `AudioStreamPlayer` o un componente en la escena; un autoload de sonido solo si es un servicio aislado.

## Checklist extra

- [ ] ¿La escena corre con F6? ¿Lo que necesita le llega por `@export`? ¿Avisa si falta una referencia?
- [ ] ¿Cada archivo nuevo está en la carpeta de su entidad o en `shared/`, con su sufijo?
- [ ] ¿Cambiar un número abre como mucho 2 archivos, y `docs/tuning.md` dice cuáles?
- [ ] ¿No apareció `scenes/`, `scripts/`, `resources/`, `assets/` ni `domain/`?
