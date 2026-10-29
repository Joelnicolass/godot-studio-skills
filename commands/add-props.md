---
description: "Planta props (addon PropKit): árboles, rocas o arbustos sobre el suelo, dibujados en lotes, que cortan un navmesh horneado por zonas."
---

Plantá **props** en el **proyecto Godot del juego** con el addon PropKit:

- un `PropScatter3D` / `PropScatter2D` que los planta;
- un `PropBatch3D` que los dibuja barato (3D);
- un `PropNavZones3D` / `PropNavZones2D` cuyo navmesh cortan, que se rehornea solo donde algo cambió.

Esto **no** es pasto (GrassKit, un kit aparte) ni lo que hace un prop en el juego (vida, botín, talar): eso queda en el juego. **No** es multijugador: un cambio en el juego viaja como dato por el transporte del juego y cada peer lo hace (el navmesh sigue a sus props). **No** inventa el arte de los props.

Cargar: `godot-prop-kit`, `godot-composition-first`.

Si no está `addons/prop_kit/`:

```bash
./install.sh --addon /ABS/GODOT_ROOT prop_kit
```

Habilitá **PropKit**. Si está cargado `godot-studio-workflow`: orquestador → árbol (este chat si son 1–3 archivos; si no, `studio-tech-lead`) → OK → `studio-developer`. Sin subagente extra.

## 1. Alcance

Si falta, preguntá en una sola tanda:

1. 2D o 3D, qué escena, y cuál es el suelo (colliders, el terreno del juego, un área plana).
2. Qué props (sus escenas) y cómo se reparten (bosques y claros, una cobertura pareja, un mapa pintado).
3. De qué se alejan (puntos de inicio, edificios, caminos), por grupo.
4. ¿Bloquean el movimiento? Entonces: la configuración del navmesh (radio del agente, tamaño de celda), y si cambia durante el juego (props que se quitan o se construyen).
5. ¿Es en red? Entonces el cambio viaja por el transporte del juego y cada peer rehornea (`apply_mode` MANUAL para un juego en lockstep).

## 2. Plan

Mostrá el árbol de archivos antes de tocar el juego (`[+]` nuevo, `[~]` cambia, `[-]` se borra), por ejemplo:

```
[+] scenes/props/tree.tscn             # StaticBody3D, grupo prop_obstruction, su propia capa de colisión
[~] scenes/maps/forest/map.tscn        # PropScatter3D (+ PropBatch3D, PropNavZones3D)
[+] scenes/maps/forest/map_nav.res     # lo escribe «Bake»
[+] scenes/maps/terrain_ground.gd      # solo si el suelo es del juego: extends PropGround, @tool
[~] project.godot                      # plugin PropKit; una capa de colisión para los props
```

Arrancá desde `addons/prop_kit/examples/minimal_3d` (scatter + lotes), `forest_3d` (más el navmesh) o `grove_2d` (2D).

## 3. Implementar

Seguí [godot-prop-kit](../skills/godot-prop-kit/SKILL.md) y `addons/prop_kit/README.md`.

- Apretá «Scatter» y después «Bake» (el inspector avisa cuando el horneado ya no coincide con los props).
- Durante el juego, liberar o agregar un prop es todo: el navmesh rehornea sus zonas (`follow_props`). Un prop que se movió: `rebake_prop(prop)`. Cambió el suelo o un edificio: `rebake(position, radius)`.
- Esperá los caminos con `if not nav.is_ready(): await nav.updated`.
- El suelo del juego, si lo hay, es un script `@tool` que `extends PropGround`.

## 4. Listo cuando

- «Scatter» da los mismos props dos veces y ninguno dentro de una zona prohibida.
- F6 carga el horneado guardado sin hornear (`stats.zones_baked` 0), y un camino rodea los props.
- Liberar un prop rehornea solo sus zonas (`stats.zones_baked` < `zones_total`, `parse_ms` 0).
- Nada de movimiento, daño ni red dentro de `addons/prop_kit`.
