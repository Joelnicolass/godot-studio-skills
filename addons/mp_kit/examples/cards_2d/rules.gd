extends RefCounted

## High card for three seats: the game's public rules, plain data. Each seat plays one card from its hand in turn; the
## highest card on the table takes the trick and leads the next one. Every peer applies the same moves the same way.
## The hands are not here: they are each seat's own (MpSeatState), so only the server and their seat know them.

const SEATS := 3
const HAND := 3

## The seat whose card it is.
var turn := 1
## The cards on the table in this trick: slot -> card.
var table: Dictionary[int, int] = {}
## The last trick taken: slot -> card (to show it).
var last_trick: Dictionary[int, int] = {}
## Tricks each seat took.
var tricks: Dictionary[int, int] = {1: 0, 2: 0, 3: 0}
## Tricks played since the last deal.
var tricks_this_round := 0


func reset(first: int) -> void:
	turn = first
	table = {}
	last_trick = {}
	tricks = {1: 0, 2: 0, 3: 0}
	tricks_this_round = 0


## Why `slot` cannot play `card` from `hand` now, or "" when it can.
func reason_against(slot: int, card: int, hand: Array) -> String:
	if slot != turn:
		return "It is not your turn."
	if not hand.has(card):
		return "That card is not in your hand."
	return ""


## Plays a card. True when it ended a round (every card of the hands was played): the server deals again.
func play(slot: int, card: int) -> bool:
	table[slot] = card
	turn = slot % SEATS + 1
	if table.size() < SEATS:
		return false
	var best := 0
	for seat: int in table:
		if best == 0 or table[seat] > table[best]:
			best = seat
	tricks[best] += 1
	last_trick = table
	table = {}
	turn = best
	tricks_this_round += 1
	if tricks_this_round < HAND:
		return false
	tricks_this_round = 0
	return true


func hash_value() -> int:
	return hash([turn, table, tricks, tricks_this_round])
