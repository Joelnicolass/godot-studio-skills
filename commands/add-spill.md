---
description: "Sangre y otras sustancias (addon SpillKit): cada golpe salpica y mancha el piso, al morir crece un charco; cada sustancia es un tipo con el aspecto húmedo del kit, PBR propio o el shader del juego, en 3D, con una sola propiedad para la red."
---

Agregá **lo que derrama un cuerpo** en el **proyecto Godot del juego** con el addon SpillKit:
- un `SpillSource3D` en el pecho de cada cuerpo que sangra, con su tipo;
- un `SpillType` por sustancia (sangre, icor, aceite, baba, tinta);
- un `SpillPool3D` en el nivel;
- `hit()` donde el juego saca vida y `die()` donde muere.

Después la persona lo prueba con los botones del componente en la vista 3D; el agente arma y explica.

Esto **no** es la vida ni el daño del juego: el kit recibe el daño de un golpe y la vida máxima. **No** es la red: un juego en red decide quién llama a `hit()` y cómo viaja `wound`. **No** es el gore de desmembrar ni las heridas en la malla del cuerpo.

Cargar: `godot-spill-kit`, `godot-composition-first`.

Si falta `addons/spill_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT spill_kit
```

Habilitá **SpillKit**. Si `godot-studio-workflow` está cargado: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. Qué cuerpos derraman y qué sustancia cada uno (sangre roja, sangre verde de un bicho, aceite de un robot); dónde salen las gotas (el pecho, el caparazón).
2. El aspecto de cada sustancia:
   - el aspecto húmedo del kit (solo un color);
   - texturas PBR propias (albedo, normal, ORM);
   - o el material o shader del juego (PS1) y los nombres de sus uniforms de textura y color.
3. Dónde se saca vida hoy (el componente de vida, el hurtbox) y dónde muere un cuerpo. Si hay golpes que siempre son fuertes (el remate de un combo).
4. Las reglas: desde qué parte de la vida un golpe es fuerte (40 %), cada cuánto como mucho una salpicadura liviana (0,25 s).
5. La capa del piso; si los cuerpos están en otra.
6. Si el juego es en red (quién decide el daño, con qué sincroniza), si sale en la web, y si el jugador puede apagar la sangre.

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambiado, `[-]` borrado), por ejemplo:

```
[~] project.godot                        # plugin SpillKit; nombre de la capa del piso
[+] resources/spill/blood.tres           # SpillType: rojo, el aspecto del kit
[+] resources/spill/green_blood.tres     # SpillType: verde, con mark_material = el material PS1 del juego
[~] scenes/levels/level_1.tscn           # SpillPool3D: types [blood, green_blood]; floor_mask: el piso
[~] scenes/enemies/enemy.tscn            # Spill (SpillSource3D) en el pecho, type green_blood; Spill:wound en lo que sincroniza el juego
[~] scenes/enemies/enemy.gd             # al sacar vida: $Spill.hit(damage, max_hp, from); al morir: $Spill.die()
[~] scenes/ui/pause_menu.gd              # la opción «sangre» pone pool.shown
```

Arrancá desde `addons/spill_kit/examples/minimal_3d` (un muñeco que sangra) o `substances_3d` (seis sustancias: aspecto del kit, PBR propio, shader propio, pendiente, cordón, noche). Copiá los tipos de `addons/spill_kit/examples/types/`.

## 3. Implementar

Seguí [godot-spill-kit](../skills/godot-spill-kit/SKILL.md) y `addons/spill_kit/README.md`.

- Un tipo por sustancia; el componente en el pecho con su tipo; el pool en el nivel con los tipos en `types`.
- `hit(damage, max_hp, from)` donde se saca vida (`from`: el punto del impacto o el atacante), `heavy = true` para un remate; `die()` al morir.
- Un material propio en `mark_material` / `puddle_material` / `drop_material`, con `texture_parameter` y `color_parameter` si sus uniforms se llaman distinto.
- En red: `hit()` y `die()` solo en la autoridad, y `wound` sincronizado (MpKit: `Spill:wound` en `sync_extra`; MultiplayerSynchronizer: Spawn y On Change).
- Decile a la persona cómo probarlo: seleccionar el componente y apretar Spray, Heavy spray y Die (puddle) en la vista 3D; el costo se lee arriba del inspector del pool.

## 4. Listo cuando

- El componente y el pool no muestran avisos, y los botones dibujan sobre el piso de la escena.
- F6: un golpe salpica y mancha, uno fuerte deja tres manchas, la muerte deja un charco que crece.
- En red, otra instancia ve lo mismo y una que entra tarde no ve lo viejo.
- Nada de vida, daño ni red dentro de `addons/spill_kit`.
