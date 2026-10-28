extends RefCounted
## The "Mua" dialog's choice for a unit-priced item offer (buy_quantity_dialog.gd): a count (▲ / ▼,
## from 1) times a preset (x3 / x5 / x10, or none = x1); the total is what is bought (the offers
## sent as POST /shop/purchase quantity). The total never passes `room` (the offers that still fit
## in the bag: ShopModel.room()); ▲ and a preset that would pass it are off. Short of coins: the
## price shows red and Mua is off (▲ still works: the player sees what more would cost).

## The presets (the dialog's design: multipliers of the count).
const PRESETS := [3, 5, 10]

var room := 0 # offers that still fit
var unit_price := 0 # the offer's priceAmount
var wallet := -1 # the player's balance in the offer's currency, -1 unknown
var count := 1
var preset := 1 # 1 = none


func _init(room_left: int = 0, price: int = 0, balance: int = -1) -> void:
	room = maxi(room_left, 0)
	unit_price = maxi(price, 0)
	wallet = balance
	count = 1 if room >= 1 else 0


## The offers bought: count × preset.
func total() -> int:
	return count * preset


## What the total costs.
func price() -> int:
	return unit_price * total()


func can_up() -> bool:
	return (count + 1) * preset <= room


func can_down() -> bool:
	return count > 1


func up() -> bool:
	if not can_up():
		return false
	count += 1
	return true


func down() -> bool:
	if not can_down():
		return false
	count -= 1
	return true


## Whether preset p fits (once at least).
func preset_allowed(p: int) -> bool:
	return p >= 1 and p <= room


## Picks preset p; picking the chosen one again goes back to x1. The count shrinks to fit.
func toggle(p: int) -> void:
	if p == preset:
		preset = 1
	elif preset_allowed(p):
		preset = p
	else:
		return
	count = clampi(count, 1 if room >= 1 else 0, room / preset)


## Whether the balance pays for the total (an unknown balance: yes, the server decides).
func affordable() -> bool:
	return wallet < 0 or price() <= wallet


func can_buy() -> bool:
	return total() >= 1 and total() <= room and affordable()
