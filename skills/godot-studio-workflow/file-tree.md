# Árbol de archivos (siempre, antes del OK)

**Siempre**, antes de crear, modificar o borrar cualquier archivo, se muestra el árbol y se espera el OK del usuario. Vale para una feature, un RFC, un command (`/add-juicy`, `/create-material`, `/new-mp-feature`, …), un typo o un `@export`. Lo arma el tech-lead si lo hay; si no, este chat. Sin árbol aprobado no se escribe nada.

Únicas excepciones: lo que escribe el playtester en `res://agent/` (ya cubierto por el OK del slice) y las notas de memoria (`.studio/MEMORY.md`).

Cada línea lleva una marca:

| Marca | Significa |
|-------|-----------|
| `[+]` | Archivo nuevo |
| `[~]` | Archivo existente que se modifica (decí qué cambia) |
| `[-]` | Archivo que se borra |

Los `[~]` y `[-]` también van: el usuario tiene que ver qué se toca de lo que ya existe, no solo lo nuevo.

Sirve para ver, de un vistazo, si la feature es un god-node o un conjunto de piezas.

## Plantilla

```text
<feature>/
├── [+] foo.tscn              # contenedor: física/layout + orquesta hijos
├── [+] foo.gd                # thin: señales hacia arriba, sockets @export
├── [+] bar.tscn              # packed reutilizable (2º caller o F6 solo)
├── [+] bar.gd                # sus números como @export, a la vista en el inspector
└── [+] foo_fast.tres         # solo si es un tipo con variantes que se comparten; no mutar en runtime
scenes/world/
└── [~] world.tscn            # instancia foo.tscn bajo %Actors
scenes/actors/
└── [-] old_foo.gd            # reemplazado por foo.gd
```

Corte chico (typo, `@export`, bug de 1–3 archivos): alcanza la lista, sin tabla.

```text
[~] scenes/player/player.gd   # coyote_time 0.10 → 0.12 (@export)
```

Más un **mapa de responsabilidades** (una fila por archivo o nodo):

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|-------|------------------------|------|------------------------|
| `foo.gd` | Orquesta input → `apply_*` | Nodo | Si también pintara HUD, split |
| `bar.tscn` | FX / HUD / hitbox | Packed | Segundo caller o F6 |
| `foo_fast.tres` | Stats de una variante | Resource | La comparten varias escenas; otra variante = otro `.tres` |

Para cada número ajustable nuevo, el plan dice en qué nodo vive. Si cambiarlo exige abrir más de 2 archivos, el corte se rediseña antes del OK.

Clean: `src/features/<n>/`, `src/core/`, `src/domain/` según [clean.md](../godot-layered-architecture/clean.md).  
Estándar: junto a la escena; no inventar `src/domain/`.

## Escena de prueba

Va en el mismo árbol, bajo `res://debug/`, y en el RFC o en el `F<n>`. La construye el developer con piezas del producto. El playtester no la crea y no la altera: solo la juega.

```text
debug/
└── goal_ready.tscn     # actor + objetivo, con otros @export en la instancia (mismo script, otros números)
```

El estado inicial hace **fácil** el criterio (no recorrer todo el juego hasta llegar). No lo deja **ya cumplido** (el objetivo no empieza resuelto, el aviso no empieza visible). La escena de debug cambia números (un `@export` en la instancia, o un `.tres` de debug si la feature ya usa uno); no un script paralelo. `res://debug/` no entra en el export de release.

## Señales de “componé más”

- Un `.gd` pinta, spawnea, puntúa y cambia de escena.
- Copy o números hardcodeados (el copy va a `tr()`; los números, a un `@export` del nodo que los usa).
- El mismo bloque copiado en dos features → `shared/` o packed.
- HUD mezclado con reglas de partida.

## Señales de “componé menos”

- Packed scene de un ColorRect que nadie reusa.
- Autoload para el puntaje de *esta* ronda.
- `src/domain/` en un proyecto que eligió **estándar**.
- Un `.tres` que usa una sola escena, o uno que apunta a otro por tag o texto.
- Un autoload, registry, locator o manager nuevo para algo que resuelve una señal, un `@export` o el bus `Events`.

## Qué pedir al usuario

Mostrá el árbol (con `[+]` / `[~]` / `[-]`) + la tabla. Preguntá: ¿está bien el corte, o querés más/menos piezas? Recién con OK se escribe: corre `studio-developer` o lo hace este chat. Si al implementar hace falta un archivo que no estaba en el árbol, se para y se muestra el árbol corregido antes de seguir.
