---
name: godot-spill-kit
description: >-
  Sangre y cualquier otra sustancia que derrama un cuerpo en un juego Godot 4 3D,
  con el addon SpillKit: cada golpe salpica gotas y deja manchas en el piso que
  quedan toda la partida, y al morir crece un charco que sigue la pendiente y no
  se sube a un cordón. Cada sustancia es un tipo en el inspector (sangre, icor,
  aceite, baba, tinta) con el aspecto húmedo del kit, texturas PBR propias
  (albedo, normal, ORM) o el shader del juego (PS1). Reglas como valores (golpe
  fuerte al 40 %, salpicaduras cada 0,25 s), una sola propiedad para la red,
  Compatibility y WebGL 2, nada en un servidor dedicado, botones para probarlo
  en el editor. Usar cuando el usuario quiere sangre, gore, salpicaduras,
  manchas en el piso, charcos al morir, icor de bichos, aceite que pierde un
  barril, o /add-spill. No es la vida ni el daño del juego, ni su red.
---

# Godot — lo que derrama un cuerpo (SpillKit)

Addon `addons/spill_kit/` en el proyecto del **juego**. Referencia: `addons/spill_kit/README.md`; API por pieza: [api.md](api.md).

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project spill_kit
```

Habilitá el plugin **SpillKit** (la línea de costo del inspector; los nodos, sus botones y sus avisos andan sin él). Pedido acotado: `/add-spill`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Tres llamadas.** Un `SpillSource3D` en el pecho del cuerpo con su `type`. El juego llama `hit(daño, vida_máxima, desde)` donde saca vida y `die()` cuando muere. Las reglas (fuerte al 40 %, livianas cada 0,25 s, golpecitos que se suman) son valores del componente, no código del juego.
- **Una sustancia, un tipo.** Un `SpillType` (`.tres`) por sustancia, compartido por todos los cuerpos que la derraman: color, gotas, manchas, charco y aspecto. Arrancá copiando uno de `addons/spill_kit/examples/types/`.
- **La persona lo prueba en el editor.** Seleccionar el componente y apretar Spray, Heavy spray o Die (puddle) en «Try it» dibuja en la vista 3D sobre el piso de la escena. Decile cómo; el agente arma los nodos y el tipo con valores iniciales.
- **Un pool por nivel.** Un `SpillPool3D` en el nivel, con los tipos del nivel en `types` (así sus shaders compilan al cargar y no en el primer golpe). Sin él, el primer componente arma uno con los valores de entrada.
- **El piso es una capa.** `floor_mask` del pool: el piso y lo que puede mancharse. Los cuerpos en otra capa; el propio cuerpo se encuentra solo y nunca recibe manchas.
- **El aspecto, en el tipo.** Solo color = el aspecto húmedo del kit. Texturas PBR = `mark_` / `puddle_` / `drop_` + `albedo_texture`, `normal_texture`, `orm_texture` (como `GrassMesh`). El shader del juego (PS1) = `mark_material` / `puddle_material` / `drop_material`, con `texture_parameter` y `color_parameter` para los nombres de sus uniforms (un shader de gotas puede tomar el color de `COLOR` y no declarar ninguno).
- **Ningún kit depende de otro.** SpillKit no tiene red: un juego en red llama a `hit()` y `die()` solo en la autoridad y sincroniza `wound`.
- **El costo lo dice el inspector del pool.** Gotas, manchas, charcos y draw calls; nada se crea por golpe.

## Red

**Con MpKit:** en el `MpActor` del cuerpo, `Spill:wound` en **Sync › sync_extra** (todo viaja al nacer, así que quien entra tarde arranca del valor actual), y el daño detrás de la autoridad:

```gdscript
func take_damage(amount: float, from: Vector3) -> void:
	if not MpKit.is_authority():
		return
	hp -= amount
	$Spill.hit(amount, max_hp, from)
	if hp <= 0.0:
		$Spill.die()
```

En un servidor dedicado, un export con la feature `dedicated_server` (o corrido headless) no arma nada. Uno corrido con el editor headless sí: `pool.shown = not MpKit.is_dedicated()` en el pegamento del juego.

**Con el `MultiplayerSynchronizer` de Godot:** la propiedad `Spill:wound`, con Spawn prendido y Replicate On Change; `hit()` y `die()` detrás de `multiplayer.is_server()`.

## Árbol

```
Level
├── SpillPool3D                    # types: los tipos del nivel; floor_mask: el piso
├── Floor (StaticBody3D)           # en la capa del piso
└── Enemy (CharacterBody3D)        # en otra capa: los rayos del piso lo atraviesan
    ├── Health (el componente de vida del juego)   # al sacar vida: Spill.hit(); al morir: Spill.die()
    └── Spill (SpillSource3D)      # en el pecho; type: green_blood.tres
```

Arrancá desde `addons/spill_kit/examples/minimal_3d/minimal_3d.tscn` (un muñeco que sangra) o `substances_3d` (seis sustancias: aspecto del kit, PBR propio, shader propio, pendiente, cordón, noche y linterna).

## Qué va dónde

| Kit | Juego |
|---|---|
| Cuándo un golpe sangra y cuánto (`heavy_from`, `every_s`, `min_lost`) | La vida, el daño, de dónde vino el golpe |
| Gotas, manchas, charcos, su aspecto | Qué sustancias hay y quién derrama cuál |
| `wound`, una propiedad | Quién decide el daño y cómo viaja `wound` |
| `shown`, `clear()` | La opción «sangre» del jugador, las rondas |

## Listo cuando

- El componente y el pool no muestran avisos, y la persona probó (o sabe probar) Spray y Die (puddle) en la vista 3D.
- F6: un golpe salpica y mancha el piso, uno del 40 % sale fuerte, la muerte deja un charco.
- En red: otra instancia ve las mismas salpicaduras; una que entra tarde no ve las viejas.
- `godot --headless --path spillkit_lab --script res://addons/spill_kit/tests/spill_test_runner.gd` da `SPILLKIT TESTS PASS` (en el repo del kit).

## Antipatrones

- Crear partículas, decals o mallas en cada golpe: el pool reusa las suyas.
- La regla del golpe fuerte en el código del juego: es `heavy_from` del componente (y `heavy` en `hit()` para un remate).
- Sincronizar cada salpicadura con un RPC: `wound` es una propiedad; quien entra tarde compara contadores.
- Llamar a `hit()` en todos los peers de un juego en red: solo donde se decide el daño.
- Un material por cuerpo: un tipo por sustancia, compartido.
- Los cuerpos en la capa del piso sin ser el que sangra: reciben manchas encima. Sacalos de `floor_mask`.
- `Decal` o `GPUParticles3D` para la sangre de un juego que sale en la web: el kit usa MultiMesh y CPUParticles3D.
