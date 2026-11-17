extends ClassKit
## E09 C1.13 fixture kit. Never listed in ClassKitRegistry.MODULES: tests install it
## over one of the four IDs with ClassKitRegistry.install_fixture(). It exercises
## every hook of the seam and records each call in `calls`.

var fixture_id: StringName = &""
var calls: Array[String] = []
var cancel_next_hit := false
var compact_blocker := ""
var concealed := false
var basic_range := 0.0
var basic_delivery: StringName = &""
var basic_bonus := 0.0
var last_hit: Dictionary = {}
var last_heal: Dictionary = {}
var last_event: Dictionary = {}
var ticks := 0.0
var victim_id := 0
# T1.2: cost rule (cost_scale * base + cost_offset; identity by default) and the
# record of origin commits (entity IDs only, never Node references).
var cost_scale := 1.0
var cost_offset := 0.0
var base_commits: Array[Dictionary] = []

func _init(id: StringName = &"") -> void:
	fixture_id = id

func kit_id() -> StringName:
	return fixture_id

func ready_for_play() -> bool:
	return true

func display_name() -> String:
	return "Kit de teste"

func create_runtime() -> ClassKit:
	var runtime: ClassKit = (get_script() as Script).new(fixture_id)
	runtime.evolution_id = fixture_id
	return runtime

func skill_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	var ids: Array = ClassKitRegistry.SKILL_IDS.get(fixture_id, [])
	for index: int in ids.size():
		var active: bool = ClassKitRegistry.SLOT_CATEGORIES[index] == &"active"
		var definition := SkillDefinition.new()
		definition.id = ids[index]
		definition.display_name = "Teste %d" % (index + 1)
		definition.category = SkillDefinition.Category.ACTIVE if active else SkillDefinition.Category.PASSIVE
		definition.handler_id = SkillDefinition.Handler.KIT
		definition.targeting = SkillDefinition.Targeting.SINGLE_TARGET if index == 2 else SkillDefinition.Targeting.SELF
		definition.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		if index == 2: definition.element = &"light"
		definition.range = 200.0
		for rank: int in range(1, (SkillDefinition.MAX_ACTIVE_RANK if active else SkillDefinition.MAX_PASSIVE_RANK) + 1):
			var values := SkillRankDefinition.new()
			values.rank = rank
			if active:
				values.sp_cost = 5.0
				values.cooldown = 1.0
				values.range = 200.0
				values.power = 1.0 + 0.1 * float(rank)
				values.variable_cast_time = 0.5 if index == 3 else 0.0
			else:
				values.power = 0.05 * float(rank)
			definition.ranks.append(values)
		result.append(definition)
	return result

func learning_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ids: Array = ClassKitRegistry.SKILL_IDS.get(fixture_id, [])
	for index: int in ids.size():
		var active: bool = ClassKitRegistry.SLOT_CATEGORIES[index] == &"active"
		var cap := SkillDefinition.MAX_ACTIVE_RANK if active else SkillDefinition.MAX_PASSIVE_RANK
		var free_rank := 1 if index == 0 else 0
		result.append({"skill_id": ids[index], "category": &"active" if active else &"passive", "free_rank": free_rank, "max_purchased_rank": cap - free_rank, "job_level": ClassKitRegistry.JOB_LEVELS[index], "prerequisites": {}})
	return result

func passive_modifier_source(skill_id: StringName, rank: int) -> Dictionary:
	var ids: Array = ClassKitRegistry.SKILL_IDS.get(fixture_id, [])
	if ids.is_empty() or skill_id != ids[1]: return {}
	return {"source_id": StringName("passive_" + String(skill_id)), "label": "Passiva de teste", "increased": {&"physical_defense": 0.05 * float(rank)}}

func causal_families() -> Array[StringName]:
	return [StringName(String(ClassKitRegistry.IDENTITIES[fixture_id]["prefix"]) + "fixture_family")]

func feedback_recipes() -> Dictionary:
	var result := {}
	for skill: StringName in ClassKitRegistry.SKILL_IDS.get(fixture_id, []):
		result[skill] = [&"impact", &"arcane", &"", FeedbackRecipeCatalog.COMMIT]
	return result

func basic_attack_recipe() -> Array:
	return [&"melee", &"physical", &"", 0]

func skill_texts() -> Dictionary:
	var result := {}
	for skill: StringName in ClassKitRegistry.SKILL_IDS.get(fixture_id, []):
		result[skill] = {"flavor": "Texto de teste.", "effect": "Efeito de teste.", "combo": "", "mechanics": "Mecânica de teste."}
	return result

func vfx_effects() -> Dictionary:
	var ids: Array = ClassKitRegistry.SKILL_IDS.get(fixture_id, [])
	var prefix: String = ClassKitRegistry.IDENTITIES[fixture_id]["prefix"]
	return {StringName(prefix + "fixture_burst"): {"skill_id": ids[2], "kinds": [&"impact"], "size": 80.0}}

func draw_vfx(effect_id: StringName, canvas: CanvasItem, _pulse: Dictionary, position: Vector2, t: float) -> bool:
	if not String(effect_id).ends_with("fixture_burst"): return false
	canvas.draw_circle(position, 8.0 + 12.0 * t, Color(1.0, 0.9, 0.5, 1.0 - t))
	return true

func on_attach(_player: PlayerActor) -> void:
	calls.append("attach")

func on_tick(_player: PlayerActor, delta: float) -> void:
	ticks += delta

func can_cast(_player: PlayerActor, cast: Dictionary) -> Dictionary:
	if StringName(cast.get("skill_id", &"")) == &"" : return {"ok": false, "error_code": &"fixture_refused"}
	return {"ok": true, "error_code": &""}

func on_cast_requested(_player: PlayerActor, cast: Dictionary) -> void:
	calls.append("requested:" + String(cast["skill_id"]))

func on_cast_confirmed(_player: PlayerActor, cast: Dictionary) -> void:
	calls.append("confirmed:" + String(cast["skill_id"]) + ":" + str(cast["rank"]) + ":" + String(cast["element"]))

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	calls.append("resolved:" + String(cast["skill_id"]))
	var victim := cast.get("target") as CombatActor
	if is_instance_valid(victim):
		victim_id = victim.get_instance_id()
		var request := player.kit_make_request(victim, StringName(cast["skill_id"]), player.stat_breakdown.value(&"melee_attack"), 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
		player.kit_emit_hit(request, victim)
	return true

func basic_attack_profile(_player: PlayerActor) -> Dictionary:
	if basic_range <= 0.0: return {}
	return {"range": basic_range, "delivery": basic_delivery if not basic_delivery.is_empty() else &"direct"}

func compose_basic_attack(_player: PlayerActor, _target: CombatActor, request: DamageRequest) -> DamageRequest:
	calls.append("basic")
	if basic_bonus > 0.0:
		var composed := request.copy()
		composed.damage_dealt_multiplier *= 1.0 + basic_bonus
		return composed
	return request

func before_hit_mitigation(_player: PlayerActor, hit: Dictionary) -> Dictionary:
	calls.append("before:" + String(hit.get("kind", &"")))
	if cancel_next_hit:
		cancel_next_hit = false
		return {"cancel": true, "reason": &"fixture_parry"}
	return {}

func after_hit_mitigation(_player: PlayerActor, hit: Dictionary, result: Dictionary) -> void:
	calls.append("after:" + ("front" if bool(hit.get("frontal", false)) else "back"))
	last_hit = {"frontal": bool(hit.get("frontal", false)), "damage": float(result.get("actual_damage", 0.0))}

func on_shield_broken(_player: PlayerActor, _hit: Dictionary, _result: Dictionary) -> void:
	calls.append("shield_broken")

func on_heal(_player: PlayerActor, requested: float, applied: float, source: StringName) -> void:
	calls.append("heal:" + String(source))
	last_heal = {"requested": requested, "applied": applied, "excess": maxf(0.0, requested - applied)}

func on_damage_dealt(_player: PlayerActor, result: Dictionary) -> void:
	calls.append("dealt:" + String(result.get("skill_id", &"")))

func on_kill_confirmed(_player: PlayerActor, _result: Dictionary) -> void:
	calls.append("kill")

func on_death(_player: PlayerActor) -> void:
	calls.append("death")

func on_return(_player: PlayerActor) -> void:
	calls.append("return")

func on_build_changed(_player: PlayerActor) -> void:
	calls.append("build")

func on_enemy_attack(_player: PlayerActor, event: Dictionary) -> void:
	calls.append("enemy_attack:" + String(event.get("kind", &"")))
	last_event = {"kind": event.get("kind"), "commit_time": event.get("commit_time"), "impact_time": event.get("impact_time")}

func concealment_active(_player: PlayerActor) -> bool:
	return concealed

func on_reveal(_player: PlayerActor, _duration: float) -> void:
	calls.append("reveal")
	concealed = false

func snapshot_compact_blocker(_player: PlayerActor) -> String:
	return compact_blocker

func skill_cost(_player: PlayerActor, _skill_id: StringName, base_cost: float) -> float:
	return base_cost * cost_scale + cost_offset

func on_base_skill_committed(_player: PlayerActor, skill_id: StringName, context: Dictionary) -> void:
	var target_actor: Variant = context.get("target")
	base_commits.append({"skill_id": skill_id, "target_id": (target_actor as Object).get_instance_id() if is_instance_valid(target_actor) else 0, "point": context.get("point", Vector2.INF), "world": bool(context.get("world", false)), "rank": int(context.get("rank", 0)), "element": StringName(context.get("element", &""))})
