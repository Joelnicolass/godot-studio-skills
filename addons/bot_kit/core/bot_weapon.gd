@tool
class_name BotWeapon
extends Resource

## One way a Bot3D attacks: at what distance it is the right choice, how to aim it and how to pull its trigger. List a
## bot's weapons in its `weapons`. In a fight the bot picks, on each think, the weapon with the highest score at its
## enemy's distance, and says so with `Bot3D.weapon_changed`: your game switches to it (its gun, its slot, its key).
## No weapon scores (all out of range, or your `Bot3D.weapon_score` said 0): the bot holds its fire.
## The game's own rules (heat, ammo, a back to stab) go in `Bot3D.weapon_score`, not here.

enum Trigger {
	## Held down, in the bursts of the bot's difficulty (an automatic gun, a flamethrower).
	HOLD,
	## One press every `tap_every_s` (a pistol, a shotgun, a throw).
	TAP,
	## Held a while, up to `charge_s`, then let go: the shot leaves on the release (a bow, a charged beam).
	CHARGE,
}

## Your game's name for it (the bot only shows it).
@export var name: StringName = &""
## The action it presses to fire. Empty: the bot's `fire_action`.
@export var fire_action: StringName = &""

@export_group("When")
## How good a choice it is inside its range. The highest wins.
@export_range(0.0, 10.0, 0.1) var score := 1.0
## It is picked only from this far…
@export_range(0.0, 500.0, 0.5, "suffix:m") var min_m := 0.0
## …up to this far.
@export_range(0.0, 500.0, 0.5, "suffix:m") var max_m := 100.0
## On each think it may be picked only this often (1: always). A mine now and then.
@export_range(0.0, 1.0, 0.01) var chance := 1.0
## The distance the bot keeps from its enemy while it uses this weapon. -1: the difficulty's `keep_m`.
@export_range(-1.0, 100.0, 0.5, "suffix:m") var keep_m := -1.0
## It fires only this close; farther it walks in (a hammer picked to close in). 0: anywhere in range.
@export_range(0.0, 100.0, 0.1, "suffix:m") var fire_within_m := 0.0

@export_group("Aim")
## How fast its shot flies; the bot aims ahead of a walking enemy by the flight time. 0: it hits at once.
@export_range(0.0, 500.0, 0.5, "suffix:m/s") var projectile_speed_m_s := 0.0
## The gravity on its shot; above 0 the bot lobs it in an arc, over cover (it needs no clear line).
@export_range(0.0, 100.0, 0.1, "suffix:m/s²") var gravity_m_s2 := 0.0
## It aims at most this far ahead of the enemy's walk.
@export_range(0.0, 3.0, 0.05, "suffix:s") var lead_max_s := 0.5
## Where on the enemy it aims, above its feet (low for a blast, so a miss bursts near the feet). -1: the bot's
## `aim_height_m`.
@export_range(-1.0, 3.0, 0.05, "suffix:m") var aim_height_m := -1.0

@export_group("Trigger")
@export var trigger := Trigger.HOLD
## TAP: one press this often.
@export_range(0.05, 5.0, 0.05, "suffix:s") var tap_every_s := 0.3
## CHARGE: the longest it holds before letting go (it picks a while between 40 % and all of it).
@export_range(0.05, 5.0, 0.05, "suffix:s") var charge_s := 1.2
## CHARGE: how often it just taps instead.
@export_range(0.0, 1.0, 0.01) var tap_chance := 0.0


## Its score at `distance_m` (0 outside its range). `chance` is the bot's roll, not this.
func score_at(distance_m: float) -> float:
	return score if distance_m >= min_m and distance_m <= max_m else 0.0


## The shot arcs (gravity on it).
func lobs() -> bool:
	return gravity_m_s2 > 0.0 and projectile_speed_m_s > 0.0
