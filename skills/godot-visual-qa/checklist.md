# UI/UX checklist (Godot)

Use **after** a capture. Compare with `VISUAL.md` and the refs.

## Hierarchy

- [ ] The most important thing (price, turn, CTA) is the largest / most contrasted.
- [ ] Chrome labels (debug, rarity chips) do not compete with content if `VISUAL.md` asks for another signal (foil, color).
- [ ] Empty and error states are readable.

## Readability

- [ ] Type sized for the viewport (e.g. 720×1280): no microtext.
- [ ] Text/background contrast (including over art).
- [ ] Copy in the product language; no IDs on the HUD.

## Consistency

- [ ] Same type family / theme as the rest.
- [ ] Spacing and margins aligned with other touched screens.
- [ ] Rarity / faction / team color consistent with `VISUAL.md`.

## Use

- [ ] Hit targets usable (not 32 px buttons on mobile).
- [ ] `mouse_filter`: FX do not eat clicks; HUD `IGNORE` except controls.
- [ ] Anchors: does not break on `expand` / another resolution.

## Fidelity

- [ ] Not a tiny stamp in a shader void if the refs show full chrome.
- [ ] Motion: if `VISUAL.md` asks for subtle, there is no strong rocking.
- [ ] Pixel art: nearest filter; no stretch that crops the atlas badly.

Blocker vs nit: a blocker prevents play or violates a written rule. The rest is a suggestion.
