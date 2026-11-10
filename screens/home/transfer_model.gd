extends RefCounted
## Chuyển hoá (equipment transfer) as the Nâng cấp page shows it, without UI. Server contract:
## ../battle-squad/docs/contracts/equip-transfer.md.
## - Two pieces of one slot swap their upgrade levels: the target takes the source's level, the
##   source the target's old one (usually +0). Gems, the lock and who wears them stay put.
## - The source must be higher than the target, and the target's cap (UpgradeModel.cap(): its
##   maxUpgradeLevel) at least the source's level: a transfer never loses a level.
## - The price is the catalog's upgradeRates[toLevel = source level].transferGemCost, paid in kim
##   cương khoá only (the unlocked kim cương never counts); 0 = that level cannot be transferred.
## - An older server's catalog sends no transferGemCost: offered() is false and the tab is hidden.

const EquipmentModel := preload("res://screens/home/equipment_model.gd")
const UpgradeModel := preload("res://screens/home/upgrade_model.gd")
const Fmt := preload("res://core/fmt.gd")

const SHORT := "Thiếu kim cương khoá"


## The catalog prices transfers (its upgradeRates rows carry transferGemCost).
static func offered(catalog: Variant) -> bool:
	if not catalog is Dictionary or not catalog.get("upgradeRates") is Array:
		return false
	for r in catalog["upgradeRates"]:
		if r is Dictionary and (r.get("transferGemCost") is int or r.get("transferGemCost") is float):
			return true
	return false


## The kim cương khoá price of transferring a source at `level` (the row whose toLevel is it), 0
## when that level cannot be transferred (no row, no price).
static func cost(catalog: Variant, level: int) -> int:
	if level <= 0 or not catalog is Dictionary or not catalog.get("upgradeRates") is Array:
		return 0
	for r in catalog["upgradeRates"]:
		if r is Dictionary and int(r.get("toLevel", -1)) == level:
			var v = r.get("transferGemCost")
			return maxi(int(v), 0) if v is int or v is float else 0
	return 0


## The pieces that can be a source: +1 and up, the Kho đồ order (EquipmentModel.sort_bag()).
static func sources(owned: Variant, catalog: Variant) -> Array:
	return EquipmentModel.sort_bag(owned, catalog).filter(func(p): return int(p.get("upgradeLevel", 0)) >= 1)


## The pieces that could take `source`'s level: the other pieces of its slot below its level, the
## ones that can first (then the Kho đồ order): [{piece, ok, cap}] (ok: the cap holds the level).
static func targets(owned: Variant, catalog: Variant, source: Dictionary) -> Array:
	if source.is_empty():
		return []
	var id := str(source.get("equipmentId", ""))
	var slot := UpgradeModel.piece_slot(catalog, source)
	var level := int(source.get("upgradeLevel", 0))
	var ok: Array = []
	var dim: Array = []
	for p in EquipmentModel.sort_bag(owned, catalog):
		if str(p.get("equipmentId", "")) == id or UpgradeModel.piece_slot(catalog, p) != slot:
			continue
		if int(p.get("upgradeLevel", 0)) >= level:
			continue
		var c := UpgradeModel.cap(catalog, p)
		var row := {"piece": p, "ok": c >= level, "cap": c}
		(ok if row["ok"] else dim).append(row)
	return ok + dim


## The levels after the swap: {source, target}.
static func after(source: Dictionary, target: Dictionary) -> Dictionary:
	return {"source": int(target.get("upgradeLevel", 0)), "target": int(source.get("upgradeLevel", 0))}


## Why CHUYỂN HOÁ is off ("" when it can be pressed), the server's checks in its order:
## `locked` = kim cương khoá held (-1 unknown: not checked).
static func blocked_reason(catalog: Variant, source: Dictionary, target: Dictionary, locked: int = -1) -> String:
	if source.is_empty():
		return "Chọn món nguồn"
	if target.is_empty():
		return "Chọn món nhận"
	if str(source.get("equipmentId", "")) == str(target.get("equipmentId", "")):
		return "Chọn hai món khác nhau"
	if UpgradeModel.piece_slot(catalog, source) != UpgradeModel.piece_slot(catalog, target):
		return "Hai món phải cùng loại"
	var level := int(source.get("upgradeLevel", 0))
	if level <= int(target.get("upgradeLevel", 0)):
		return "Món nguồn phải cao hơn món nhận"
	var c := UpgradeModel.cap(catalog, target)
	if c < level:
		return "Món nhận chỉ lên được +%d" % c
	var price := cost(catalog, level)
	if price <= 0:
		return "+%d chưa chuyển hoá được" % level
	if locked >= 0 and locked < price:
		return SHORT
	return ""


## The confirmation: "Dùng 250 kim cương khoá?"
static func confirm_text(price: int) -> String:
	return "Dùng %s kim cương khoá?" % Fmt.thousands(price)


## The POST /player/equipment/transfer answer → {source, target (the pieces after the swap, {}
## when missing), gem_spent, gem_balance / gem_unlocked (-1 when missing), replay}.
static func parse_result(data: Variant) -> Dictionary:
	var d: Dictionary = data if data is Dictionary else {}
	return {"source": d["source"] if d.get("source") is Dictionary else {},
		"target": d["target"] if d.get("target") is Dictionary else {},
		"gem_spent": _int(d.get("gemSpent"), 0), "gem_balance": _int(d.get("gemBalance"), -1),
		"gem_unlocked": _int(d.get("gemUnlocked"), -1), "replay": d.get("replay") == true}


static func _int(v: Variant, fallback: int) -> int:
	return int(v) if v is int or v is float else fallback
