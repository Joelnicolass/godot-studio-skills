class_name BotBrainCore
extends RefCounted

## How a bot picks what to do, with no body and no clock: among scored choices the highest above 0 wins, and what it
## already does stays until another scores higher (a tie keeps it). A little noise, drawn from your game's
## RandomNumberGenerator, makes an easier bot pick a worse choice now and then; the same seed picks the same way.
## Bot3D picks its modes with it and BotBrain its options; a turn-based game can call `best` on its own.


## The choice that wins among `choices`, or null when none scores above 0:
## 1. With `noise` (0 to 1), each score first moves by up to that share of itself, up or down (0.15: ±15 %), with one
##    number from `rng` per choice, in order. With noise 0 nothing is drawn and `rng` may be null.
## 2. A score of 0 or less is out.
## 3. The highest wins; between equal ones, the first in the list.
## 4. The choice whose id is `current_id` (what the bot does now; empty: nothing) stays unless another scores higher.
## The choices are never changed: the noisy scores are not kept.
static func best(
	choices: Array[BotChoice], current_id := &"", rng: RandomNumberGenerator = null, noise := 0.0
) -> BotChoice:
	var spread := clampf(noise, 0.0, 1.0)
	if spread > 0.0 and rng == null:
		push_error("BotBrainCore.best: noise needs an rng (your game's RandomNumberGenerator); picked without it.")
		spread = 0.0
	var winner: BotChoice = null
	var winner_score := 0.0
	var current: BotChoice = null
	var current_score := 0.0
	for choice in choices:
		if choice == null:
			continue
		var score := choice.score
		if spread > 0.0:
			var shift := rng.randf_range(-spread, spread)
			if is_finite(score):
				score += shift * score
		if not score > 0.0:
			continue
		if current == null and not current_id.is_empty() and choice.id == current_id:
			current = choice
			current_score = score
		if winner == null or score > winner_score:
			winner = choice
			winner_score = score
	if current != null and winner_score <= current_score:
		return current
	return winner
