extends PanelContainer

## A card scene's root for the HandView tests: it declares `card`, as HandView asks, and counts how often it is set.
## Not a test file.

var card: CardData:
	set(value):
		card = value
		times_set += 1
var times_set := 0
