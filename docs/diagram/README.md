# Diagramas del flujo

Fuentes Archify del kit. Los HTML se publican en GitHub Pages; estos JSON son lo que se versiona.

| Diagrama | Qué muestra | Spec | HTML |
|---|---|---|---|
| Una feature, de la idea al cierre | La entrevista, el F n, un OK sobre el árbol, construcción, review, playtest de `res://debug/`, adónde vuelve un FAIL y cuándo está listo | [studio-flow.workflow.json](studio-flow.workflow.json) | [index.html](index.html) |
| Un kit en tu juego | Un `/add-*`: la skill y el command del kit, el árbol, el addon, el ejemplo mínimo como patrón y tu escena | [kit-flow.workflow.json](kit-flow.workflow.json) | [kits.html](kits.html) |

- Live: https://joelnicolass.github.io/godot-studio-skills/ (y `kits.html`)
- Skill: [tt-a1i/archify](https://github.com/tt-a1i/archify) (v3.2)

Regenerar (hace falta un checkout de archify; correlo dentro de esta carpeta):

```bash
node <archify>/archify/bin/archify.mjs finalize workflow studio-flow.workflow.json index.html --quality showcase --json
node <archify>/archify/bin/archify.mjs finalize workflow kit-flow.workflow.json kits.html --quality showcase --json
```

`finalize` valida, genera el HTML y lo chequea en un Chrome real; deja recibos `*.finalize.json` al lado, que no se versionan.
