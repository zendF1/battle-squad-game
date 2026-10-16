# Inventory + Equipment — plan

Goal: players buy equipment in the Shop, see everything they own in "Túi đồ", and put gear on /
take it off per character on the "Nhân vật" screen (layout like `equipment_sc.png`: gear slots
around the character, owned gear on the right). Equipment stats already apply in battle and in
`GET /player/characters` (`stats.fromEquipment`, shared `battlestats` package).

## What the server has today (main)

- Owned instances `player_equipment` (upgradeLevel 0–16, 2 gem sockets, equipped per character
  via `equipped_on`, unique per (player, character, slot)). Slots: weapon, armor, helmet, pants,
  boots, gloves.
- Routes: `GET /player/equipment`, `POST /player/equipment/{equip,unequip,upgrade,dismantle,
  socket,unsocket}`, `GET /shop/equipment?characterId=`, `POST /shop/equipment/buy {itemId}`,
  stones/gems/materials shops, merge, crafting.
- Catalog: 24 normal items (Iron/Steel/Mithril/Dragon × 6 slots, required level 10/20/30/40)
  and 24 crafted items, seeded **only by cmd/admin** (not in the normal stack).

Problems to fix first:
1. Catalog, stones, rates, gems, materials, recipes are empty unless cmd/admin ran once.
2. Required levels 10/20/30/40 compare against the character level, but the default level
   table (`character_levels`) only went to 10 → only the Lv10 tier could be worn. Fixed by
   extending the table (S1b), not by lowering the gear levels.
3. `GET /player/equipment` returns no name/stats; no route serves the full catalog (crafted
   items, upgrade rates, set bonuses).
4. `POST /shop/equipment/buy` has no idempotency key → a retry after a timeout can charge twice.
5. Equipped items can be dismantled; crafting is broken (`material_id` vs `materialId` JSON key).
6. No tests for equip/unequip/buy; docs don't list equipment routes.

## Batch 1 — Shop trang bị, Túi đồ, mặc/tháo đồ

### Server
- S1 Migration `016_default_equipment_catalog` (idempotent, registered in cmd/migrate): seed
  the normal items, stones, upgrade rates, gems, materials, recipes (same data as admin seed,
  recipe JSON key fixed). Required levels follow `docs/equipment-system-design.md`: normal tiers
  **10 / 20 / 30 / 40**, crafted silver/gold/titan/diamond **15 / 35 / 55 / 75** (character
  level). Admin seed uses the same values. (A first version lowered them to 1/4/7/10 and
  2/5/8/10 to fit a level cap of 10; that was wrong and is undone by S1b.)
- S1b Migration `019_equipment_design_levels`: restores rows still holding the 1/4/7/10 and
  2/5/8/10 remap (only slots whose four rows all still hold it), extends `character_levels` to
  level 80 (L2–L10 unchanged; `expRequired(L) = 5200 + 1200n + 25n(n+1)/2`, n = L − 10:
  L20 18 575, L40 52 825, L75 136 825, L80 151 325) when it is still the untouched 10-level
  default, and makes weapons per character: 16 items `<character>_weapon_lv10..lv40` ("Rookie
  Sword", "Tanko Cannon", "Spark Staff", "Flora Slingshot"; generic weapon stats/prices), the 4
  generic `normal_weapon_lvN` become inactive (owned pieces still work). Armor/helmet/pants/
  boots/gloves stay shared.
- S2 `GET /equipment/catalog` → `{items:[EquipmentItemConfig…], upgradeRates, setBonuses,
  stones}` (every item incl. crafted and inactive ones with `isActive: false`, so owned retired
  pieces keep their name/stats; the shop filters `isActive`). Cacheable by the client.
- S3 `POST /shop/equipment/buy {itemId, idempotencyKey}` — same replay rules as `/shop/purchase`
  (same key + item replays the result, no second charge; key reused for another item → 409).
- S4 Fixes: dismantle refuses equipped items (`EQUIP_EQUIPPED`); crafting reads both JSON keys;
  equipment `handleServiceError` logs unknown errors; buy checks the item is active.
- S5 Integration tests: buy (balance, replay), equip (wrong character, level, slot swap
  auto-unequips), unequip, stats change in `GET /player/characters`, dismantle guard.
- S6 Docs: technical-documentation.md routes + error codes + catalog.

### Client (Godot)
- C1 Data: `PlayerState` caches the catalog (loaded once) and owned equipment (refresh after buy
  / equip / unequip / match end). Pure helpers with tests: Vietnamese slot names (Vũ khí, Áo,
  Mũ, Quần, Giày, Găng), item display names (Kiếm Sắt, Áo Thép…), stat lines, compare with the
  equipped piece (green +N / red −N), "Lv yêu cầu", idempotency keys for equipment buys.
- C2 Art: bake slot icons and one icon per item (6 slots × 4 tiers, tier colours
  Sắt/Thép/Mithril/Rồng) + hexagon slot frame + "+N" badge into `assets/icons/equipment/`
  through tools/bake_art.gd; listed in `ui/art.gd`.
- C3 Shop: tabs **Vật phẩm · Trang bị · Nhân vật · Kim cương**. Trang bị: slot filter chips,
  cards (icon, name, Lv yêu cầu, stats, price), "Mua" → confirm → buy; toast + refresh wallet
  and owned gear. Owned count shown ("Đã có 2"). Sells the shared gear plus the weapons of the
  lobby's character only ("Vũ khí của Rookie"; `EquipmentModel.shop_items(catalog, slot,
  character)`); weapon names "Kiếm Rookie", "Pháo Tanko", "Gậy Spark", "Ná Flora" (icons shared
  per slot/tier). EXP bars follow the 80-level default table (`Progress.character_threshold`);
  the server's `isMaxLevel` decides MAX.
- C4 **Túi đồ** page (replaces Hồ sơ → Kho đồ; lobby "Kho đồ" opens it): tabs **Trang bị**
  (grid: icon, +N, "Đang mặc · Tanko" badge, slot filter, sort by level) and **Vật phẩm**
  (consumables, as today). Tap gear → detail popup (stats, who wears it, "Mặc cho <nhân vật
  đang chọn>" / "Tháo").
- C5 **Nhân vật** page (lobby "Nhân vật" / avatar): like `equipment_sc.png` — 6 hexagon slots
  around the character (left), character on the pedestal with ◀ ▶, right panel tabs
  **Trang bị** (owned gear for the tapped slot, compare popup, Mặc/Tháo) and **Chỉ số** (the
  current stats + point allocation from Hồ sơ). Stats refresh after each equip/unequip. Gear
  that can't be worn is shown dimmed with the reason (Lv yêu cầu N / nhân vật khác).
- C6 Lobby + prep: info card stats already include equipment; prep shows the worn gear row
  (read-only icons).

## Batch 2 — Cường hoá (+N)
- Server: stones shop already exists; expose rates in the catalog (S2).
- Client: "Cường hoá" in the gear popup: pick stones, success %, safe zones (+6/+10/+14 keep),
  fail-reset warning, result animation; stones in Túi đồ → Nguyên liệu; stones in Shop.

## Batch 3 — Ngọc khảm, Tách, Chế tạo
- Gem shop/merge/socket UI, "Tách" (dismantle → stones refund) with confirm, crafting recipes
  with materials, set bonus display for crafted tiers.

## Order / safety
- Server S1–S6 first (one agent), then client C1–C6 (one agent, after the assets bake is
  merged because C2 extends the baker). Reviewer pass after each.
- Not in scope: visual gear on the character sprite (later with real art), equipment for bots,
  selling gear for coin.
