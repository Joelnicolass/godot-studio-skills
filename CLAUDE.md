# Ramas: RC antes de las principales

Dos ramas **principales** (no pushear trabajo directo):

- `main` — inglés (worktree `godot-studio-skills-en`)
- `release/spanish` — español (worktree `godot-studio-skills`)

Orden fijo:

1. Implementar en un par **RC**, no en las principales.
2. Nombrar `rc/vX.Y.Z` (desde `main`) y `rc/vX.Y.Z-spanish` (desde `release/spanish`). X.Y.Z = siguiente versión del kit (último tag `v0.6.0` → siguiente `v0.7.0`). Un segundo candidato: `rc/vX.Y.Z-rc.2` / `rc/vX.Y.Z-rc.2-spanish`.
3. Commit + push **solo** a esas RC.
4. Merge / push a `main` y `release/spanish` **únicamente** cuando el usuario acepte la RC.

Espejo ES/EN en el mismo corte. No commit/push a las principales “para ir adelantando”.

## Kit

Skills en `skills/`, commands en `commands/`, subagentes en `agents/`: los mismos archivos se instalan en Claude Code (`./install.sh --claude`) y en Cursor (`./install.sh`). No escribas instrucciones que solo valgan en un harness sin nombrar el equivalente del otro. El flujo pide **siempre** el árbol de archivos (`[+]` / `[~]` / `[-]`) antes de tocar el juego; no agregues un camino que lo saltee. Un subagente de solo lectura lleva `readonly: true` (Cursor) **y** `disallowedTools` (Claude Code).

Reglas de diseño de cada kit, además de las de su skill:

- Cuando dos kits tienen que actuar juntos, el kit ofrece un punto de enganche con un `Callable` (`tree.buy(id, wallet.pay)`), no una receta de varios pasos que el usuario tiene que respetar en orden. Ningún kit nombra a otro.
- El núcleo de un kit nunca crea un `RandomNumberGenerator`: lo recibe. El nodo puede crear uno propio desde `rng_seed` (0: una semilla propia, distinta en cada nodo) y siempre acepta el de la partida en `rng`; cambiar `rng_seed` no toca un `rng` asignado.
- En un kit nuevo, el nodo expone su núcleo como propiedad (`fog.fog`, `pile.stack`) y reenvía solo las llamadas de «En 3 pasos», cada una con su comentario `##`.

Estas reglas también viven en `.cursor/rules/kits.mdc`; cambiá las dos.

Esta regla también vive en `.cursor/rules/release-candidate.mdc`; cambiá las dos.
