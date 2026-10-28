extends RefCounted
## The replay visuals of a shot item (ShotResolved actionMode "item"): a SkillView per item type
## (GET /gamedata items[].type) that match_screen begins and feeds like a skill's (projectile
## views, explosions, timeline events). Visual only: paths, damage, statuses and timing are the
## server's.
## - poison (Bom độc): the shell tinted green with bubbles (ProjectileView ITEM_LOOKS), a green
##   poison cloud where it bursts (poison_shot.gd); the poison status as any other;
## - nuke (Bom huỷ diệt), laser (Laze): the signal flare, the strike marker, the falling nuke or the
##   converging beams and their blast (strike_shot.gd);
## - multi_shot (Bắn đôi), fan_shot (Bắn ba tia): no view of their own: ShotPlayer flies every
##   projectile on its own path and launchDelay, each with its own explosion.
## A shot whose type this client does not know but that carries a strike event plays as a strike.

const GameData := preload("res://autoload/game_data_model.gd")
const PoisonShot := preload("res://match/views/items/poison_shot.gd")
const StrikeShot := preload("res://match/views/items/strike_shot.gd")

const VIEWS := {"poison": PoisonShot, "nuke": StrikeShot, "laser": StrikeShot}


## A new view for the item shot of this timeline (ShotTimeline), null when it needs none.
static func view_for(timeline) -> Variant:
	if timeline == null:
		return null
	var script = VIEWS.get(GameData.item_type(timeline.item_id))
	if script == null and not timeline.events_of("strike").is_empty():
		script = StrikeShot
	return script.new() if script != null else null
