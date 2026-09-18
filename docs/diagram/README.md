# Flow diagram

Archify source for one iteration of the studio workflow. The interactive HTML is published on GitHub Pages; this JSON is what the kit versions.

- Live: https://joelnicolass.github.io/godot-studio-skills/en.html
- Spec: [studio-flow.workflow.json](studio-flow.workflow.json)
- Skill: [tt-a1i/archify](https://github.com/tt-a1i/archify)

Regenerate (needs an archify checkout):

```bash
node bin/archify.mjs validate workflow studio-flow.workflow.json --quality showcase
node bin/archify.mjs deliver workflow studio-flow.workflow.json index.html --quality showcase
```
