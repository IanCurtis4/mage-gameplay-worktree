extends ClassBase
## E10a C1.13 fixture base module. Never listed in ClassBaseRegistry.MODULES: tests install
## it over `acolyte` with ClassBaseRegistry.install_fixture(). It exercises every base data
## method and every hook of the two-module composition, records each call in `calls` and,
## through the static `order_log`, the order of the origin and evolution hooks.

const ID := &"acolyte"
const SKILLS: Array[StringName] = [&"acolyte_punishing_light", &"acolyte_prayer", &"acolyte_votive_shield", &"acolyte_shadow_seal", &"acolyte_disturbing_whisper", &"acolyte_eldritch_vision", &"acolyte_devotion", &"acolyte_protective_faith"]
const ELEMENTS: Array[StringName] = [&"light", &"light", &"light", &"shadow", &"shadow", &"", &"", &"light"]
## Proposed prerequisites of section 1 (closed by T5 in the production module).
const PREREQUISITES := {
	&"acolyte_votive_shield": {&"acolyte_prayer": 1},
	&"acolyte_shadow_seal": {&"acolyte_punishing_light": 1},
	&"acolyte_disturbing_whisper": {&"acolyte_shadow_seal": 1},
	&"acolyte_eldritch_vision": {&"acolyte_disturbing_whisper": 1},
	&"acolyte_devotion": {&"acolyte_punishing_light": 1, &"acolyte_shadow_seal": 1},
	&"acolyte_protective_faith": {&"acolyte_votive_shield": 1},
}

## Process-local order of hook calls of both modules (tests clear it). Never persisted.
static var order_log: Array[String] = []

var calls: Array[String] = []
var cancel_next_hit := false
var hit_multiplier := 1.0
var compact_blocker := ""
var cost_offset := 0.0
var basic_bonus := 0.0
var stat_bonus := 0.0
var refuse_skill: StringName = &""
var ticks := 0.0
var victim_id := 0
var commits: Array[Dictionary] = []
var last_heal: Dictionary = {}

func base_id() -> StringName:
	return ID

func ready_for_play() -> bool:
	return true

func display_name() -> String:
	return "Base de teste"

func create_runtime() -> ClassKit:
	var runtime: ClassKit = (get_script() as Script).new()
	runtime.evolution_id = ID
	return runtime

func initial_attributes() -> Dictionary[StringName, int]:
	return {&"str": 3, &"agi": 4, &"vit": 7, &"int": 8, &"dex": 5, &"luk": 3}

func basic_attack() -> Dictionary:
	return {"delivery": &"magic", "range": 220.0, "power": 1.0}

func starting_skill_ids() -> Array[StringName]:
	return [&"acolyte_punishing_light", &"acolyte_prayer"]

func starting_passive_id() -> StringName:
	return &"acolyte_protective_faith"

func skill_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	for index: int in SKILLS.size():
		var active := index < 6
		var definition := SkillDefinition.new()
		definition.id = SKILLS[index]
		definition.display_name = "Base %d" % (index + 1)
		definition.category = SkillDefinition.Category.ACTIVE if active else SkillDefinition.Category.PASSIVE
		definition.handler_id = SkillDefinition.Handler.KIT
		definition.targeting = SkillDefinition.Targeting.SINGLE_TARGET if index in [0, 3] else SkillDefinition.Targeting.SELF
		definition.action_kind = SkillDefinition.ActionKind.OFFENSIVE if index in [0, 3, 4] else SkillDefinition.ActionKind.DEFENSIVE
		definition.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		definition.element = ELEMENTS[index]
		definition.range = 220.0
		for rank: int in range(1, (SkillDefinition.MAX_ACTIVE_RANK if active else SkillDefinition.MAX_PASSIVE_RANK) + 1):
			var values := SkillRankDefinition.new()
			values.rank = rank
			if active:
				values.sp_cost = 6.0
				values.cooldown = 1.0
				values.range = 220.0
				values.power = 1.0 + 0.1 * float(rank)
			else:
				values.power = 0.05 * float(rank)
			definition.ranks.append(values)
		result.append(definition)
	return result

func learning_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in SKILLS.size():
		var active := index < 6
		result.append({"skill_id": SKILLS[index], "category": &"active" if active else &"passive", "max_purchased_rank": 5 if active else 3, "job_level": 1, "prerequisites": PREREQUISITES.get(SKILLS[index], {})})
	return result

func passive_modifier_source(skill_id: StringName, rank: int) -> Dictionary:
	if skill_id != &"acolyte_protective_faith": return {}
	return {"source_id": &"passive_acolyte_protective_faith", "label": "Fé de teste", "increased": {&"magic_defense": 0.05 * float(rank)}}

func causal_families() -> Array[StringName]:
	return [&"acolyte_fixture_family"]

func feedback_recipes() -> Dictionary:
	var result := {}
	for index: int in SKILLS.size():
		var element: StringName = ELEMENTS[index] if not ELEMENTS[index].is_empty() else &"arcane"
		result[SKILLS[index]] = [&"projectile" if index == 0 else (&"impact" if index == 3 else &"buff"), element, &"", FeedbackRecipeCatalog.COMMIT if index > 0 else 0]
	return result

func basic_attack_recipe() -> Array:
	return [&"projectile", &"light", &"", 0]

func skill_texts() -> Dictionary:
	var result := {}
	for skill: StringName in SKILLS:
		result[skill] = {"flavor": "Prece de teste.", "effect": "Efeito de base de teste.", "combo": "", "mechanics": "Mecânica de base de teste."}
	return result

func vfx_effects() -> Dictionary:
	return {&"acolyte_fixture_glow": {"skill_id": &"acolyte_punishing_light", "kinds": [&"impact"], "size": 64.0}}

func draw_vfx(effect_id: StringName, canvas: CanvasItem, _pulse: Dictionary, position: Vector2, t: float) -> bool:
	if effect_id != &"acolyte_fixture_glow": return false
	canvas.draw_circle(position, 6.0 + 10.0 * t, Color(1.0, 0.95, 0.75, 1.0 - t))
	return true

# --- Hooks -----------------------------------------------------------------------

func _log(entry: String) -> void:
	calls.append(entry)
	order_log.append("base:" + entry)

func on_attach(_player: PlayerActor) -> void:
	_log("attach")

func on_tick(_player: PlayerActor, delta: float) -> void:
	ticks += delta

func can_cast(_player: PlayerActor, cast: Dictionary) -> Dictionary:
	if not refuse_skill.is_empty() and StringName(cast.get("skill_id", &"")) == refuse_skill: return {"ok": false, "error_code": &"fixture_base_refused"}
	return {"ok": true, "error_code": &""}

func on_cast_requested(_player: PlayerActor, cast: Dictionary) -> void:
	_log("requested:" + String(cast["skill_id"]))

func on_cast_confirmed(_player: PlayerActor, cast: Dictionary) -> void:
	_log("confirmed:" + String(cast["skill_id"]) + ":" + String(cast["element"]))

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	_log("resolved:" + String(cast["skill_id"]))
	var victim := cast.get("target") as CombatActor
	if is_instance_valid(victim):
		victim_id = victim.get_instance_id()
		player.kit_emit_hit(player.kit_make_request(victim, StringName(cast["skill_id"]), 0.0, player.stat_breakdown.value(&"magic_attack"), DamageRequest.AccuracyMode.GEOMETRY, false), victim)
	elif StringName(cast["skill_id"]) == &"acolyte_prayer":
		player.heal_player(10.0, &"acolyte_prayer")
	return true

func skill_cost(_player: PlayerActor, _skill_id: StringName, base_cost: float) -> float:
	return base_cost + cost_offset

func on_base_skill_committed(_player: PlayerActor, skill_id: StringName, context: Dictionary) -> void:
	_log("commit:" + String(skill_id))
	commits.append({"skill_id": skill_id, "element": StringName(context.get("element", &"")), "world": bool(context.get("world", false)), "rank": int(context.get("rank", 0))})

func basic_attack_profile(player: PlayerActor) -> Dictionary:
	return super.basic_attack_profile(player)

func compose_basic_attack(_player: PlayerActor, _target: CombatActor, request: DamageRequest) -> DamageRequest:
	_log("basic")
	if basic_bonus <= 0.0: return request
	var composed := request.copy()
	composed.damage_dealt_multiplier *= 1.0 + basic_bonus
	return composed

func before_hit_mitigation(_player: PlayerActor, _hit: Dictionary) -> Dictionary:
	_log("before")
	if cancel_next_hit:
		cancel_next_hit = false
		return {"cancel": true, "reason": &"fixture_base_ward"}
	return {"damage_multiplier": hit_multiplier} if hit_multiplier != 1.0 else {}

func after_hit_mitigation(_player: PlayerActor, _hit: Dictionary, _result: Dictionary) -> void:
	_log("after")

func on_shield_broken(_player: PlayerActor, _hit: Dictionary, _result: Dictionary) -> void:
	_log("shield_broken")

func on_heal(_player: PlayerActor, requested: float, applied: float, source: StringName) -> void:
	_log("heal:" + String(source))
	last_heal = {"requested": requested, "applied": applied}

func on_damage_dealt(_player: PlayerActor, result: Dictionary) -> void:
	_log("dealt:" + String(result.get("skill_id", &"")))

func on_kill_confirmed(_player: PlayerActor, _result: Dictionary) -> void:
	_log("kill")

func on_death(_player: PlayerActor) -> void:
	_log("death")

func on_return(_player: PlayerActor) -> void:
	_log("return")

func on_build_changed(_player: PlayerActor) -> void:
	_log("build")

func temporary_stat_sources(_player: PlayerActor) -> Array[Dictionary]:
	if stat_bonus <= 0.0: return []
	return [{"source_id": &"acolyte_fixture_bonus", "label": "Bônus de teste", "increased": {&"magic_attack": stat_bonus}}]

func on_enemy_attack(_player: PlayerActor, event: Dictionary) -> void:
	_log("enemy_attack:" + String(event.get("kind", &"")))

func snapshot_compact_blocker(_player: PlayerActor) -> String:
	return compact_blocker
