---
name: godot-prop-kit
description: >-
  Planta props (árboles, rocas, arbustos) sobre un mundo Godot 4, 2D o 3D, con el
  addon PropKit, dibuja miles en lotes (3D) y hornea el navmesh por zonas con los
  props como obstrucciones baratas que rehornean solo lo que cambió, en hilos de
  trabajo. Usar cuando el usuario quiere un bosque, props plantados, ubicar
  vegetación, zonas prohibidas, un navmesh que los props cortan, rehorneados de
  navmesh lentos, regiones conexas de un navmesh o /add-props. No es pasto
  (GrassKit) ni lo que hace un prop en el juego.
---

# Godot — props y su navmesh (PropKit)

Addon `addons/prop_kit/` en el proyecto del **juego**. Referencia: `addons/prop_kit/README.md`; API por pieza: [api.md](api.md).

Si el addon no está:

```bash
./install.sh --addon /path/to/godot-project prop_kit
```

Habilitá el plugin **PropKit**. Pedido acotado: `/add-props`. Composición: [godot-composition-first](../godot-composition-first/SKILL.md).

## Reglas

- **Tres piezas, cada una por su cuenta.** Scatter (`PropScatter3D` / `PropScatter2D`), dibujo en lotes (`PropBatch3D`) y el navmesh por zonas (`PropNavZones3D` / `PropNavZones2D`). Un juego usa una, dos o las tres.
- **Los props son nodos de la escena.** Un scatter planta hijos guardados: se editan con el gizmo, y se vuelve a plantar solo para reemplazarlos todos. Nunca generes props en el juego "para ahorrar la escena" cuando tienen que chocar o cortar el navmesh igual en todos los peers; el scatter ya es determinista.
- **El suelo es un contrato.** `PropFlatGround`, `PropRayGround` (3D, cualquier collider) o un script del juego que `extends PropGround` con `@tool`. El kit nunca nombra una clase del juego: las zonas prohibidas son grupos (`PropKeepOut`).
- **Los props cortan el navmesh como obstrucciones, no como geometría.** Cada escena de prop pone el grupo `prop_obstruction`, y su capa de colisión queda fuera de la máscara de colisión de la plantilla del navmesh. Leé `PropObstructions.area_of(prop, is_3d)` antes de liberar un prop, y después llamá a `rebake([area], false)`.
- **Ningún kit depende de otro.** PropKit no tiene red: un scatter determinista da los mismos props en todos los peers. Un cambio en el juego viaja como dato del juego por el transporte del juego, cada peer llama a `rebake`, y `apply_mode` MANUAL más `apply()` lo aplica en el mismo tick.
- **Las distancias van en unidades del mundo**: metros en 3D, píxeles en 2D (`spacing`, `zone_size`, `merge_gap`).

## Árbol

```
World                    # source_root del navmesh
├── Ground               # colisión en una capa que el navmesh parsea
├── Forest               # PropScatter3D (sus hijos: los props, grupo prop_obstruction, su propia capa)
└── Camps/…              # nodos en un grupo que el scatter respeta
Batch                    # PropBatch3D (props = [Forest])
Nav                      # PropNavZones3D (plantilla navigation_mesh, .res guardado)
```

Arrancá desde `addons/prop_kit/examples/forest_3d/forest_3d.tscn` o `grove_2d/grove_2d.tscn`.

## Qué va dónde

| Kit | Juego |
|---|---|
| Dónde va cada prop, cuántos, qué variante | Qué es un prop (vida, botín, una animación de tala) |
| Dibujarlos barato | Sus mallas y materiales; otro aspecto por bioma (`mesh_of`) |
| Obstrucciones, zonas, rehorneados, el índice | Cuándo rehornear, el transporte, el tick en que se aplica |
| El contrato del suelo (`PropGround`) | Los datos del terreno detrás |

## Listo cuando

- «Scatter» llena el área: ninguno dentro de una zona prohibida, ninguno sobre una máscara prohibida, el mismo resultado dos veces.
- «Bake» guarda `<escena>_nav.res`; F6 lo carga sin hornear (`stats.zones_baked` 0) y un camino rodea los props.
- Liberar un prop y llamar a `rebake([area], false)` rehornea solo sus zonas (`stats.zones_baked` < `zones_total`, `parse_ms` 0).
- `godot --headless --path propkit_lab --script res://addons/prop_kit/tests/prop_test_runner.gd` da `PROPKIT TESTS PASS` (en el repo del kit).

## Anti-patrones

- Props parseados como geometría del navmesh: su capa está en la máscara de la plantilla, así el horneado paga dos veces. El kit avisa una vez.
- Volver a hornear una NavigationRegion3D gigante en cada cambio en vez de usar zonas.
- `rebake` con `reparse = true` cuando solo cambiaron props.
- `merge_gap` más grande que el diámetro del agente: cierra pasos por los que un agente podría caminar.
- Un script de suelo sin `@tool`: el scatter no lo puede llamar en el editor.
