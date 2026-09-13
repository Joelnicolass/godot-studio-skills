# Camino estándar — escenas y scripts

Usar **solo** si el usuario eligió estándar (o el repo ya lo declara). No crear `src/domain/` ni una fachada de sesión “por las dudas”.

Siguen valiendo: composición, editor, Resources, reuso, scripts chicos, señales arriba / llamadas abajo. Solo se omite la división Clean.

## Forma del proyecto (Godot idiomático)

Escena + script **juntos**. No un dump `scripts/` de 200 archivos desconectados de sus `.tscn`.

```
scenes/                 # o res:// con carpetas por área
  actors/
    bullet.tscn + .gd   # un cuerpo; el tipo llega por Resource
    enemy.tscn + .gd
    pawn.tscn + .gd
  components/           # Health, Hitbox, Hurtbox, Trail (packed scenes)
  world/
  ui/
resources/
  bullets/              # bullet_data.gd + plasma.tres + spread.tres
  enemies/
  powerups/
addons/mp_kit/
```

Variante válida: carpetas por feature (`actors/bullet/`) con escena, script y `.tres` adentro. Lo que no es válido: un `Player.gd` de mil líneas y `match weapon`.

## Scripts pequeños y responsabilidades

- Un nodo = un trabajo. Movimiento ≠ HP ≠ disparo ≠ HUD.
- Extraer componente (escena hija) cuando el script pasa de orquestar a implementar dos sistemas.
- Herencia rasa: `State extends Node`. No `EliteFlyingEnemy extends FlyingEnemy extends Enemy`.
- El mundo **compone** spawners, cámara, FX. No puntúa en el mismo archivo que spawnea.

Comunicación (docs Godot — organización de escenas):

- Signals **hacia arriba** (el hijo no nombra al padre).
- Métodos **hacia abajo** (el padre usa la API pública del hijo).
- Autoload de eventos solo entre sistemas que no son padre-hijo.

Escenas lo más autónomas posible: lo que necesitan, lo traen o lo reciben por `@export`.

## Estado de partida sin domain

Si hay score / vidas / timer:

- Un nodo chico `Match` (hijo del mundo o autoload **solo si** sobrevive el cambio de escena), no variables sueltas en cada enemigo.
- Catálogo de tipos sigue siendo Resource, no `enum` + `match` en el Match.
- Con red: el host sigue siendo el único que muta ese estado (skill MpKit). El estándar no autoriza al cliente a simular.

## Autoloads

Sí: `GameEvents` (bus), audio, director de escenas, `MpKit`.  
No: `EnemyManager`, `BulletFactory` global, el inventario del run si puede vivir en el árbol de la partida.

## Checklist extra de este camino

- [ ] ¿Cada `.tscn` se entiende abierta sola?
- [ ] ¿Las variantes son `.tres` (o otra packed scene si cambia la **estructura**), no `if type`?
- [ ] ¿El script cabe en una lectura corta? Si no, componé.
- [ ] ¿No se introdujo `src/domain/` sin que el usuario pidiera Clean?
