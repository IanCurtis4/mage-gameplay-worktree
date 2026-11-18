extends "res://scripts/classes/fixture/fixture_kit.gd"
## E10a T4 fixture kit: the T1 fixture kit plus a Madness family authority, forwarding
## the seam hooks as the Acólito base (T5) and the Cultista (T7) are expected to
## (docs/epics/e10a/t4_madness_api.md). Never listed in ClassKitRegistry.MODULES; tests
## install it with install_fixture(). Fixture skills (T1 fixture slots): slot 0 places the
## Idol at the cast point, slot 2 (single target) strikes and adds `madness_per_cast`
## Madness to the target, once per commit.

var madness := MadnessAuthority.new()
var madness_per_cast := 40.0
## Madness added by every confirmed damage result (0 = off); relayed results never count.
var madness_per_hit := 0.0
var hit_gains := 0

func _slot(index: int) -> StringName:
	return ClassKitRegistry.SKILL_IDS[fixture_id][index]

func on_attach(player: PlayerActor) -> void:
	super(player)
	var prefix := String(ClassKitRegistry.IDENTITIES[fixture_id]["prefix"])
	madness.configure(player, {"stat_source_id": StringName(prefix + "ecstasy"), "ecstasy_enabled": true})

func on_tick(player: PlayerActor, delta: float) -> void:
	super(player, delta)
	madness.tick(player, delta)

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	if skill == _slot(0):
		calls.append("resolved:" + String(skill))
		var point: Variant = cast["anchor"] if bool(cast.get("world", false)) and cast.get("anchor") is ExpeditionWorldPoint else cast.get("point", player.global_position)
		return madness.place_idol(player, point)["ok"]
	if skill == _slot(2):
		var resolved := super(player, cast)
		var victim := cast.get("target") as CombatActor
		if is_instance_valid(victim) and victim.is_alive(): madness.add(victim, madness_per_cast, MadnessHelpers.cast_event(cast, player.kit_time), player)
		return resolved
	return super(player, cast)

func skill_cost(player: PlayerActor, skill_id: StringName, base_cost: float) -> float:
	return madness.skill_cost(super(player, skill_id, base_cost))

func temporary_stat_sources(player: PlayerActor) -> Array[Dictionary]:
	return madness.temporary_stat_sources(player)

func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
	var decision := super(player, hit)
	if bool(decision.get("cancel", false)): return decision
	return madness.before_hit(player, hit)

func on_damage_dealt(player: PlayerActor, result: Dictionary) -> void:
	super(player, result)
	if madness_per_hit <= 0.0: return
	var victim := instance_from_id(int(result.get("target_id", 0))) as CombatActor
	var event := MadnessHelpers.result_event(result)
	if is_instance_valid(victim) and victim.is_alive() and not event.is_empty() and bool(madness.add(victim, madness_per_hit, event, player)["ok"]): hit_gains += 1

func on_death(player: PlayerActor) -> void:
	super(player)
	madness.on_death(player)

func on_build_changed(player: PlayerActor) -> void:
	super(player)
	madness.on_build_changed(player)

func snapshot_compact_blocker(player: PlayerActor) -> String:
	var own := super(player)
	return own if not own.is_empty() else madness.compact_blocker(player)
