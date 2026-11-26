extends RefCounted

## Three in a row for seats 1 and 2: the game's rules, plain data. The same moves give the same board on every peer.

const LINES := [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]
const DRAW := -1

## 0: free; 1 or 2: the seat that took it.
var cells := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
## The seat whose move it is.
var turn := 1
## 0 while playing, the seat that made three in a row, or DRAW.
var winner := 0


func reset(first: int) -> void:
	cells = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
	turn = first
	winner = 0


## Why `slot` cannot take `cell` now, or "" when it can.
func reason_against(slot: int, cell: int) -> String:
	if winner != 0:
		return "The game is over."
	if slot != turn:
		return "It is not your turn."
	if cell < 0 or cell >= cells.size():
		return "There is no such cell."
	if cells[cell] != 0:
		return "That cell is taken."
	return ""


func place(slot: int, cell: int) -> void:
	cells[cell] = slot
	for line: Array in LINES:
		if cells[line[0]] == slot and cells[line[1]] == slot and cells[line[2]] == slot:
			winner = slot
	if winner == 0 and not cells.has(0):
		winner = DRAW
	turn = 2 if slot == 1 else 1


## The same number on every peer with the same board.
func hash_value() -> int:
	return hash([cells, turn, winner])
