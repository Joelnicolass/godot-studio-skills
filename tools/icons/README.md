# Editor icons of the kits

One 16 × 16 icon for every kit class the editor shows (nodes and `Resource`) and one emblem per
kit. A generator makes them: nobody draws them by hand or edits the SVGs.

It lives here, outside `addons/`, because the kits are copied into games and carry no tools.
Each kit only gets its `addons/<kit>/icons/` folder.

## Regenerate

From the repo root, with Aseprite on the `PATH`:

```bash
python3 tools/icons/list_classes.py      # which classes carry an icon -> classes.tsv
aseprite -b --script-param out="$PWD/addons" --script tools/icons/generate.lua
python3 tools/icons/preview.py /tmp/icons-preview.png 3   # sample sheet (needs Pillow)
```

The generator warns when a class has no glyph, when a glyph does not exist or when its rows
differ in width. It leaves in `manifest.tsv` which icon each class got.

## Check

Without opening the editor, for each lab (the project has to be imported):

```bash
godot --headless --path gridkit_lab --import
godot --headless --path gridkit_lab -s "$PWD/tools/icons/check_icons.gd"
```

It checks that every class of `classes.tsv` the project has is registered with its `@icon`, that
the file is the one of its kit and that it loads as a 16 × 16 texture, and the same for the
emblem. It exits with code 1 when something fails.

## Files

| File | What it holds |
|---|---|
| `kits.lua` | The colour of each kit and the glyph of each class |
| `glyphs.lua` | The glyphs, as rows of characters (`#` colour, `+` light, `o` dark, `.` empty) |
| `generate.lua` | The generator: centres the glyph, adds the outline and saves the SVG |
| `list_classes.py` | Finds the classes with a `class_name` that are a node or a `Resource` |
| `classes.tsv`, `manifest.tsv` | Generated: the list of classes and the icon of each |
| `preview.py` | The sample sheet over a dark and a light background |
| `check_icons.gd` | The check with no window |

## The system

- **The colour tells the kit.** Each kit has one colour and all its icons use it, with a light
  tone for a second part and a dark one for the outline and the holes.
- **The glyph tells what the class does.** Similar classes share a glyph with a light mark in the
  bottom right corner (a cursor for the input ones, a tick, an arrow).
- **The blue or red dot** is Godot's colour for `Node2D` and `Node3D`. Only the classes with a
  twin in the other dimension carry it (`PropScatter2D` / `PropScatter3D`).
- **The dark outline** is what makes the icon readable on the light theme. On the dark theme it
  hardly shows: that is why the dark tone is used for holes inside a shape and never for a stroke
  on its own.
- **The emblem** of a kit is a tile in its colour with the drawing in the dark tone:
  `addons/<kit>/icons/<kit>.svg`. It goes in the title of the kit's README and in its editor bar,
  when it has one.

## Add a class

1. Run `list_classes.py`.
2. In `kits.lua`, add the class with a glyph of `glyphs.lua`, or draw a new one there (up to 14 × 14).
3. Regenerate and look at the sample sheet on both backgrounds.
4. In the class's script, after `@tool` and before `class_name`:
   `@icon("res://addons/<kit>/icons/<file>.svg")`.
5. Import the kit's lab (`--headless --path <kit>_lab --import`). In the new SVG's `.import` set
   `editor/scale_with_editor_scale=true` (Godot rasterizes the SVG at the editor's scale and the
   pixels stay sharp on a high-density screen) and
   `editor/convert_colors_with_editor_theme=false` (the colours are the kit's on both themes).
   Import again and commit the `.import`.
6. Run `check_icons.gd`.
