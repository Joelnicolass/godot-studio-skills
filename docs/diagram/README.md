# Diagrama del flujo

Fuente Archify del flujo de una iteración. El HTML interactivo se publica en GitHub Pages; este JSON es lo que se versiona con el kit.

- Live: https://joelnicolass.github.io/godot-studio-skills/
- Spec: [studio-flow.workflow.json](studio-flow.workflow.json)
- Skill: [tt-a1i/archify](https://github.com/tt-a1i/archify)

Regenerar (hace falta un checkout de archify):

```bash
node bin/archify.mjs validate workflow studio-flow.workflow.json --quality showcase
node bin/archify.mjs deliver workflow studio-flow.workflow.json index.html --quality showcase
```
