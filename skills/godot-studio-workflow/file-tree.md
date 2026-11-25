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
foo/
├── [+] foo.tscn              # contenedor: física y disposición; orquesta a sus hijos
├── [+] foo.gd                # delgado: señales hacia arriba, referencias @export
├── [+] foo_type.gd           # class_name FooType: los números de diseño de un foo
├── [+] fast/fast_foo_type.tres   # una variante; no se muta al correr
└── [-] old_foo.gd            # reemplazado por foo.gd
shared/components/
├── [+] bar.tscn              # packed reutilizable (la usan dos entidades)
└── [+] bar.gd
levels/forest/
└── [~] forest.tscn           # instancia foo.tscn bajo %Actors
docs/
└── [~] tuning.md             # filas nuevas: velocidad y daño de foo
```

Corte chico (typo, `@export`, bug de 1–3 archivos): alcanza la lista, sin tabla.

```text
[~] player/player.tscn   # coyote_time 0.10 → 0.12 (@export de la raíz)
```

Más un **mapa de responsabilidades** (una fila por archivo o nodo):

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|-------|------------------------|------|------------------------|
| `foo.gd` | Orquesta input → `apply_*` | Nodo | Si también pintara HUD, split |
| `bar.tscn` | FX / HUD / hitbox | Packed | Segundo caller o F6 |
| `fast_foo_type.tres` | Números de una variante | Resource de tipo | Otra variante = otro `_type.tres` |

Para cada número de diseño nuevo, el plan trae su fila de `docs/tuning.md` (quiero cambiar → archivo → nodo → propiedad), y `[~] docs/tuning.md` va en el árbol. Si cambiarlo exige abrir más de 2 archivos, el corte se rediseña antes del OK.

Cada archivo del árbol va en la carpeta que le toca y cada `.tres` lleva su sufijo ([godot-code-quality](../godot-code-quality/SKILL.md) §1).

Por entidad: la carpeta de la entidad, o `shared/` ([by-entity.md](../godot-layered-architecture/by-entity.md)).  
Sistemas + contenido: `systems/`, `content/`, `ui/` ([systems-content.md](../godot-layered-architecture/systems-content.md)).  
Clean (solo un repo que ya lo declara): [clean.md](../godot-layered-architecture/clean.md).

## Escena de prueba

Va en el mismo árbol, bajo `res://debug/`, y en el RFC o en el `F<n>`. La construye el developer con piezas del producto. El playtester no la crea y no la altera: solo la juega.

```text
debug/
└── goal_ready.tscn     # actor + objetivo, con otros @export en la instancia (mismo script, otros números)
```

El estado inicial hace **fácil** el criterio (no recorrer todo el juego hasta llegar). No lo deja **ya cumplido** (el objetivo no empieza resuelto, el aviso no empieza visible). La escena de debug cambia números (un `@export` en la instancia, o un `.tres` de debug si la feature ya usa uno); no un script paralelo. `res://debug/` no entra en el export (`debug/*` en el filtro de exclusión del preset) y nada del juego la nombra: `rg -n "res://debug" --glob '!debug/**' --glob '!agent/**'` da vacío.

## Señales de “componé más”

- Un `.gd` pinta, spawnea, puntúa y cambia de escena.
- Textos o números escritos en el código (los textos van al archivo de traducciones; los números, a su dueño según la regla 0).
- El mismo bloque copiado en dos features → `shared/` o packed.
- HUD mezclado con reglas de partida.

## Señales de “componé menos”

- Packed scene de un ColorRect que nadie reusa.
- Autoload para el puntaje de *esta* ronda.
- Una carpeta `domain/`, `core/` o `scenes/` en un proyecto que no declaró Clean.
- Un `.tres` que no cumple ninguna de las tres condiciones de la regla 0, o uno que apunta a otro por tag o texto.
- Un autoload, registry, locator o manager nuevo para algo que resuelve una señal, un `@export` o el bus `Events`.

## Qué pedir al usuario

Mostrá el árbol (con `[+]` / `[~]` / `[-]`) + la tabla. Preguntá: ¿está bien el corte, o querés más/menos piezas? Recién con OK se escribe: corre `studio-developer` o lo hace este chat. Si al implementar hace falta un archivo que no estaba en el árbol, se para y se muestra el árbol corregido antes de seguir.
