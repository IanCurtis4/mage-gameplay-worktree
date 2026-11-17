extends "res://scripts/classes/fixture/fixture_kit.gd"
## E12 H1 fixture kit: the E09 fixture kit plus ClassKit.hud_state (format
## ragrpg_kit_hud_v1, docs/epics/e12/h1_hud_seam_api.md). Never listed in
## ClassKitRegistry.MODULES; tests install it with ClassKitRegistry.install_fixture().
##
## `hud_variant` picks the answer: VALID (every key, kind, space and shape of the
## format), EMPTY ({}), or one invalid variant per KitHudState error code (the variant
## name is the code). hud_state is pure: it reads the kit and the player, never writes.

const VALID := &"valid"
const EMPTY := &"empty"

## Answer of hud_state. Run state like the other fixture fields (fragment in this folder).
var hud_variant: StringName = VALID

## Every variant: VALID, EMPTY and one per error code, in KitHudState.ERROR_CODES order.
static func variants() -> Array[StringName]:
	var result: Array[StringName] = [VALID, EMPTY]
	result.append_array(KitHudState.ERROR_CODES)
	return result

func _hud_slot(index: int) -> StringName:
	return ClassKitRegistry.SKILL_IDS[fixture_id][index]

func hud_state(player: PlayerActor) -> Dictionary:
	if hud_variant == EMPTY: return {}
	var state := valid_state(player)
	var resources: Array = state["resources"]
	if hud_variant == KitHudState.INVALID_SCHEMA:
		state["schema"] = "ragrpg_kit_hud_v0"
	elif hud_variant == KitHudState.KIT_MISMATCH:
		state["kit_id"] = &"fixture_other_kit"
	elif hud_variant == KitHudState.UNKNOWN_KEY:
		state["portrait"] = &"fixture"
	elif hud_variant == KitHudState.INVALID_RESOURCE:
		(resources[0] as Dictionary)["value"] = 6 # above max (5), not unlimited
	elif hud_variant == KitHudState.DUPLICATE_RESOURCE:
		resources.append((resources[0] as Dictionary).duplicate())
	elif hud_variant == KitHudState.UNKNOWN_SKILL:
		(state["skills"] as Dictionary)[&"slash"] = {"ready": true, "reason": &""}
	elif hud_variant == KitHudState.INVALID_SKILL:
		((state["skills"] as Dictionary)[_hud_slot(2)] as Dictionary)["reason"] = &"" # refused without a reason
	elif hud_variant == KitHudState.INVALID_ZONE:
		((state["zones"] as Array)[0] as Dictionary)["radius"] = 0.0
	elif hud_variant == KitHudState.INVALID_MARK:
		((state["target_marks"] as Array)[0] as Dictionary)["value"] = 6 # above the Sentence cap
	elif hud_variant == KitHudState.NON_FINITE:
		(resources[3] as Dictionary)["remaining"] = INF
	return state

## The full valid answer: every key of every section, all resource kinds (pips with and
## without unlimited, charges with recharge, timer), skills ready and refused with
## charges and recharge, cone/circle/wide-circle zones in world and flat space, and
## pips/badge marks. Built fresh on every call; reads only.
func valid_state(player: PlayerActor) -> Dictionary:
	var prefix := String(ClassKitRegistry.IDENTITIES[fixture_id]["prefix"]) if ClassKitRegistry.IDENTITIES.has(fixture_id) else "sanctuary_"
	var flat_center := Vector3(player.global_position.x, player.global_position.y, 0.0) if player != null else Vector3(400.0, 350.0, 0.0)
	var own_id := player.get_instance_id() if player != null else 1
	var mark_target := victim_id if victim_id != 0 else own_id
	return {
		"schema": KitHudState.SCHEMA,
		"kit_id": kit_id(),
		"resources": [
			{"id": StringName(prefix + "grace"), "label": "Graça", "kind": &"pips", "value": 3, "max": 5, "unlimited": false, "element": &"light"},
			{"id": &"sanctuary_grace_hour", "label": "Graça ilimitada", "kind": &"pips", "value": 5, "max": 5, "unlimited": true, "remaining": 4.5, "total": 8.0, "element": &"light"},
			{"id": StringName(prefix + "refraction"), "label": "Refração", "kind": &"charges", "value": 1, "max": 2, "remaining": 2.5, "total": 6.0, "element": &"arcane"},
			{"id": &"flank_duel", "label": "Duelo", "kind": &"timer", "remaining": 3.0, "total": 10.0, "element": &""},
		],
		"skills": {
			_hud_slot(0): {"ready": true, "reason": &""},
			_hud_slot(2): {"ready": false, "reason": &"fixture_refused", "charges": 0, "max_charges": 2, "recharge_remaining": 1.5, "recharge_total": 4.0},
		},
		"zones": [
			{"role": &"fixture_oath", "space": &"world", "center": Vector3(120.0, 0.0, 80.0), "shape": SanctuaryRules.SHAPE_CONE, "radius": 160.0, "half_angle": PI / 4.0, "facing": Vector3(1.0, 0.0, 0.0), "element": &"fire", "remaining": 5.0, "total": 9.0},
			{"role": &"fixture_circle", "space": &"flat", "center": flat_center, "shape": SanctuaryRules.SHAPE_CIRCLE, "radius": 120.0, "element": &"ice", "remaining": 2.0, "total": 9.0},
			{"role": &"fixture_hour", "space": &"world", "center": Vector3(0.0, 0.0, 0.0), "shape": SanctuaryRules.SHAPE_WIDE_CIRCLE, "radius": 220.0, "facing": Vector3(0.0, 0.0, 1.0), "element": &"tricolor"},
		],
		"target_marks": [
			{"target_id": mark_target, "key": &"flank_victim", "kind": &"pips", "value": 3, "max": 5, "element": &"arcane"},
			{"target_id": mark_target, "key": StringName(prefix + "seal"), "kind": &"badge", "element": &"lightning"},
		],
	}
