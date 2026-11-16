extends "res://scripts/classes/fixture/fixture_kit.gd"
## E09 T5 fixture kit: the T1 fixture kit plus a SanctuaryAuthority, forwarding the
## seam hooks exactly as K1/K2 are expected to (docs/epics/e09/t5_delivery.md).
## Never listed in ClassKitRegistry.MODULES; tests install it with install_fixture().
## Fixture skills (T1 fixture slots): slot 0 opens the zone of `zone_config`, slot 2
## (light, single target) spends Grace and strikes a Juízo, slot 3 grants the Égide.

var sanctuary := SanctuaryAuthority.new()
var zone_config: Dictionary = {"role": &"oath", "shape": &"cone"}
var last_spent := 0
var light_gains := 0

func _slot(index: int) -> StringName:
	return ClassKitRegistry.SKILL_IDS[fixture_id][index]

func on_attach(player: PlayerActor) -> void:
	super(player)
	sanctuary.configure(player, StringName(String(ClassKitRegistry.IDENTITIES[fixture_id]["prefix"]) + "fixture_family"))

func on_tick(player: PlayerActor, delta: float) -> void:
	super(player, delta)
	sanctuary.tick(player, delta)

func on_cast_confirmed(player: PlayerActor, cast: Dictionary) -> void:
	super(player, cast)
	if StringName(cast["skill_id"]) == _slot(2): last_spent = sanctuary.spend_for_cast(player, cast, 1)

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	if skill == _slot(0):
		calls.append("resolved:" + String(skill))
		var config := zone_config.duplicate(true)
		config["skill_id"] = skill
		if not config.has("point"): config["point"] = SanctuaryAuthority.cast_point(cast)
		return sanctuary.open_zone(player, config)["ok"]
	if skill == _slot(2):
		calls.append("resolved:" + String(skill))
		var victim := cast.get("target") as CombatActor
		if not is_instance_valid(victim): return false
		victim_id = victim.get_instance_id()
		var request := SanctuaryHelpers.judgment_request(player, victim, skill, player.stat_breakdown.value(&"magic_attack"), last_spent, SanctuaryRules.JUDGMENT_PER_CHARGE, false)
		if request != null: player.kit_emit_hit(request, victim)
		return request != null
	if skill == _slot(3):
		calls.append("resolved:" + String(skill))
		return sanctuary.grant_aegis(player, player.health.max_hp * 0.25, SanctuaryRules.AEGIS_DURATION, player.stat_breakdown.value(&"magic_attack") * 0.5, skill)
	return super(player, cast)

func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
	var decision := super(player, hit)
	if bool(decision.get("cancel", false)): return decision
	return sanctuary.before_hit(player, hit)

func after_hit_mitigation(player: PlayerActor, hit: Dictionary, result: Dictionary) -> void:
	super(player, hit, result)
	# Kit source: a frontal hit mitigated by an active zone.
	if bool(hit.get("frontal", false)) and bool(result.get("landed", false)) and sanctuary.owner_damage_multiplier(hit) < 1.0:
		sanctuary.gain(SanctuaryHelpers.result_event(result), 1)

func on_shield_broken(player: PlayerActor, hit: Dictionary, result: Dictionary) -> void:
	super(player, hit, result)
	sanctuary.on_shield_broken(player, hit, result)

func on_heal(player: PlayerActor, requested: float, applied: float, source: StringName) -> void:
	super(player, requested, applied, source)
	sanctuary.on_heal(player, requested, applied, source)

func on_damage_dealt(player: PlayerActor, result: Dictionary) -> void:
	super(player, result)
	# Kit source: light damage on the sealed target.
	var victim := instance_from_id(int(result.get("target_id", 0))) as CombatActor
	if sanctuary.is_sealed(victim) and SanctuaryHelpers.is_light_result(result):
		light_gains += sanctuary.gain(SanctuaryHelpers.result_event(result), 1)

func on_death(player: PlayerActor) -> void:
	super(player)
	sanctuary.on_death(player)

func on_build_changed(player: PlayerActor) -> void:
	super(player)
	sanctuary.on_build_changed(player)

func snapshot_compact_blocker(player: PlayerActor) -> String:
	var own := super(player)
	return own if not own.is_empty() else sanctuary.compact_blocker()
