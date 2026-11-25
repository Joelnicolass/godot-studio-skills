# Iconos de editor de los kits

Un icono de 16 × 16 por cada clase de kit que el editor muestra (nodos y `Resource`) y un emblema
por kit. Salen de un generador: no se dibujan a mano ni se editan los SVG.

Vive acá, fuera de `addons/`, porque los kits se copian a los juegos y no llevan herramientas.
A cada kit solo le llega su carpeta `addons/<kit>/icons/`.

## Regenerar

Desde la raíz del repo, con Aseprite en el `PATH`:

```bash
python3 tools/icons/list_classes.py      # qué clases llevan icono -> classes.tsv
aseprite -b --script-param out="$PWD/addons" --script tools/icons/generate.lua
python3 tools/icons/preview.py /tmp/icons-preview.png 3   # hoja de muestra (necesita Pillow)
```

El generador avisa si una clase no tiene glifo, si un glifo no existe o si sus filas no miden
lo mismo. Deja en `manifest.tsv` qué icono le tocó a cada clase.

## Comprobar

Sin abrir el editor, por cada lab (el proyecto tiene que estar importado):

```bash
godot --headless --path gridkit_lab --import
godot --headless --path gridkit_lab -s "$PWD/tools/icons/check_icons.gd"
```

Revisa que cada clase de `classes.tsv` que el proyecto tiene esté registrada con su `@icon`, que
el archivo sea el de su kit y que cargue como una textura de 16 × 16, y lo mismo el emblema.
Termina con código 1 si algo falla.

## Archivos

| Archivo | Qué tiene |
|---|---|
| `kits.lua` | El color de cada kit y el glifo de cada clase |
| `glyphs.lua` | Los glifos, como filas de caracteres (`#` color, `+` claro, `o` oscuro, `.` vacío) |
| `generate.lua` | El generador: centra el glifo, suma el contorno y guarda el SVG |
| `list_classes.py` | Busca las clases con `class_name` que son nodo o `Resource` |
| `classes.tsv`, `manifest.tsv` | Generados: la lista de clases y el icono de cada una |
| `preview.py` | La hoja de muestra sobre fondo oscuro y claro |
| `check_icons.gd` | La comprobación sin ventana |

## El sistema

- **El color dice el kit.** Cada kit tiene un color y todos sus iconos lo usan, con un tono claro
  para una segunda parte y uno oscuro para el contorno y los huecos.
- **El glifo dice qué hace la clase.** Clases parecidas comparten glifo con una marca clara en la
  esquina de abajo a la derecha (un cursor para las de entrada, un tilde, una flecha).
- **El punto azul o rojo** es el color de `Node2D` y `Node3D` de Godot. Lo llevan solo las clases
  que tienen gemela en la otra dimensión (`PropScatter2D` / `PropScatter3D`).
- **El contorno oscuro** es lo que deja leer el icono sobre el tema claro. En el tema oscuro casi
  no se ve: por eso el tono oscuro se usa para huecos adentro de una forma y nunca para un trazo
  suelto.
- **El emblema** de un kit es una loseta de su color con el dibujo en oscuro:
  `addons/<kit>/icons/<kit>.svg`. Va en el título del README del kit y en su barra del editor,
  si tiene una.

## Sumar una clase

1. Corré `list_classes.py`.
2. En `kits.lua`, sumá la clase con un glifo de `glyphs.lua`, o dibujá uno nuevo ahí (hasta 14 × 14).
3. Regenerá y mirá la hoja de muestra en los dos fondos.
4. En el script de la clase, después de `@tool` y antes de `class_name`:
   `@icon("res://addons/<kit>/icons/<archivo>.svg")`.
5. Importá el lab del kit (`--headless --path <kit>_lab --import`). En el `.import` del SVG nuevo
   dejá `editor/scale_with_editor_scale=true` (Godot rasteriza el SVG a la escala del editor y los
   píxeles quedan nítidos en una pantalla de alta densidad) y
   `editor/convert_colors_with_editor_theme=false` (los colores son los del kit en los dos temas).
   Importá de nuevo y versioná el `.import`.
6. Corré `check_icons.gd`.
