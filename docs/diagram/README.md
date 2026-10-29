# Flow diagrams

The kit's Archify sources. The HTML is published on GitHub Pages; these JSON files are what the kit versions.

| Diagram | What it shows | Spec | HTML |
|---|---|---|---|
| One feature, from idea to close | The interview, F n, one OK on the tree, build, review, playtest of `res://debug/`, where a FAIL returns, and when it is done | [studio-flow.workflow.json](studio-flow.workflow.json) | [index.html](index.html) |
| A kit in your game | One `/add-*`: the kit's skill and command, the tree, the addon, the minimal example as the pattern, and your scene | [kit-flow.workflow.json](kit-flow.workflow.json) | [kits.html](kits.html) |

- Live: https://joelnicolass.github.io/godot-studio-skills/en.html and `kits-en.html`
- Skill: [tt-a1i/archify](https://github.com/tt-a1i/archify) (v3.2)

Regenerate (needs an archify checkout; run it inside this folder):

```bash
node <archify>/archify/bin/archify.mjs finalize workflow studio-flow.workflow.json index.html --quality showcase --json
node <archify>/archify/bin/archify.mjs finalize workflow kit-flow.workflow.json kits.html --quality showcase --json
```

`finalize` validates, writes the HTML and checks it in a real Chrome; it leaves `*.finalize.json` receipts next to it, which are not versioned. `docs/en.html` is a copy of `index.html`.
