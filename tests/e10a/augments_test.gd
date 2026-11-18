extends SceneTree
## E10a T11 — the six Acólito-family augments (docs/epics/e10a_contract.md C8, D7): identity
## eligibility, pt-BR readability, recipe shape (existing handlers only, no Madness/Delirium/Ecstasy
## axis, so the D4 limits are untouched by construction) and a short combat per augment on the
## real base and kits with a measurable effect. Hits are real kit requests through RunController's
## damage path; the secondary is read from status_damage_requested, as in the E06 pilot runtime
## test. Fixture profiles only; nothing is written to disk.
const IDS: Array[StringName] = [&"pilot_acolyte_pressure", &"pilot_acolyte_reserve", &"pilot_priest_a", &"pilot_priest_b", &"pilot_cultist_a", &"pilot_cultist_b"]
const EVOLUTION := {&"pilot_priest_a": &"priest", &"pilot_priest_b": &"priest", &"pilot_cultist_a": &"cultist", &"pilot_cultist_b": &"cultist"}
const HIT_SKILL := {&"pilot_priest_b": &"priest_judgment", &"pilot_cultist_a": &"cultist_shared_delirium", &"pilot_cultist_b": &"cultist_abyss_gaze"}
const EVOLUTION_BUILDS := {
	&"priest": {&"priest_sanctuary": 5, &"priest_grace": 3, &"priest_aegis": 5, &"priest_judgment": 3, &"priest_holy_hour": 5},
	&"cultist": {&"cultist_abyss_gaze": 5, &"cultist_ecstasy": 3, &"cultist_impossible_idol": 4, &"cultist_shared_delirium": 5, &"cultist_open_pupil": 3},
}
const BASE_RANKS := {&"acolyte_punishing_light": 3, &"acolyte_prayer": 3, &"acolyte_votive_shield": 3, &"acolyte_shadow_seal": 3, &"acolyte_protective_faith": 2}

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var catalog: BuildEffectCatalog
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var secondaries: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	var loaded := BuildContentLoader.load_catalog(true)
	_check(loaded["ok"], "active catalog loads with the six new augments")
	if not loaded["ok"]:
		quit(1)
		return
	catalog = loaded["catalog"]
	_check_recipes()
	_check_eligibility()
	_check_readability()
	_check_combat()
	_cleanup()
	print("E10a T11 augments: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _definition(id: StringName) -> AugmentDefinition:
	return catalog.get_definition(&"augment", id) as AugmentDefinition

func _snapshot(evolution: StringName) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"acolyte"
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"acolyte", evolution)
	snapshot.skill_ranks = {}
	for skill: StringName in BASE_RANKS:
		snapshot.skill_ranks[skill] = int(BASE_RANKS[skill])
	if evolution != &"":
		for skill: StringName in EVOLUTION_BUILDS[evolution]:
			snapshot.skill_ranks[skill] = int(EVOLUTION_BUILDS[evolution][skill])
	return snapshot

func _check_recipes() -> void:
	_check(catalog.ids(&"augment").size() == 37, "catalog holds 37 augments (31 + 6)")
	for id: StringName in IDS:
		var definition := _definition(id)
		_check(definition != null, "registered %s" % id)
		if definition == null:
			continue
		_check(definition.max_stacks == 3 and definition.effects.size() == 1, "three stacks, one recipe %s" % id)
		var effect: EffectDefinition = definition.effects[0]
		_check(effect.stack_values == [effect.magnitude, effect.magnitude * 2.0, effect.magnitude * 3.0], "curve is magnitude x stack %s" % id)
		_check(not (String(effect.axis).contains("madness") or String(effect.axis).contains("delirium") or String(effect.axis).contains("ecstasy")), "no Madness/Delirium/Ecstasy axis (D4) %s" % id)
		_check(effect.handler_id in [EffectDefinition.Handler.STAT_MODIFIER, EffectDefinition.Handler.HIT_DAMAGE], "only existing handlers %s" % id)
		_check(definition.allowed_origins == [&"acolyte"], "origin acolyte %s" % id)
		if EVOLUTION.has(id):
			_check(definition.allowed_evolutions == [EVOLUTION[id]], "evolution restriction %s" % id)
		else:
			_check(definition.allowed_evolutions.is_empty(), "base augment has no evolution restriction %s" % id)
		if HIT_SKILL.has(id):
			_check(effect.target_skill_ids == [HIT_SKILL[id]] and ClassCatalog.skill_definition(HIT_SKILL[id]) != null, "targets one real skill %s" % id)

func _check_eligibility() -> void:
	var matrix := {
		&"pilot_acolyte_pressure": [&"", &"priest", &"cultist"], &"pilot_acolyte_reserve": [&"", &"priest", &"cultist"],
		&"pilot_priest_a": [&"priest"], &"pilot_priest_b": [&"priest"], &"pilot_cultist_a": [&"cultist"], &"pilot_cultist_b": [&"cultist"],
	}
	for id: StringName in IDS:
		var definition := _definition(id)
		for evolution: StringName in [&"", &"priest", &"cultist"]:
			_check(BuildEffectCatalog.definition_allowed(definition, _snapshot(evolution)) == (evolution in matrix[id]), "eligibility %s for '%s'" % [id, evolution])
		for other: StringName in [&"mage", &"swordsman", &"archer"]:
			var foreign := BuildSnapshot.new()
			foreign.base_class_id = other
			_check(not BuildEffectCatalog.definition_allowed(definition, foreign), "%s blocked for %s" % [id, other])
		var foreign_evolution := BuildSnapshot.new()
		foreign_evolution.base_class_id = &"mage"
		foreign_evolution.evolution_id = &"elementalist"
		_check(not BuildEffectCatalog.definition_allowed(definition, foreign_evolution), "%s blocked for elementalist" % id)

func _check_readability() -> void:
	var seen: Dictionary = {}
	for id: StringName in IDS:
		var definition := _definition(id)
		_check(not definition.display_name.is_empty() and not definition.flavor_text.is_empty() and not definition.description.is_empty(), "name, flavor and description present %s" % id)
		_check(not seen.has(definition.display_name), "unique display name %s" % id)
		seen[definition.display_name] = true
		_check(definition.description == ContentAuthoring.describe(&"augment", definition), "description is the canonical factual text %s" % id)
		var values: Array[float] = definition.effects[0].stack_values
		_check(definition.description.contains("+%d / +%d / +%d" % [int(values[0]), int(values[1]), int(values[2])]), "description shows the curve %s" % id)
		for text: String in [definition.display_name, definition.flavor_text, definition.description]:
			_check(not text.contains("pilot_") and not text.contains("_"), "no internal id in visible text %s" % id)
	_check(_definition(&"pilot_priest_b").description.contains("Juízo") and _definition(&"pilot_cultist_a").description.contains("Delírio Compartilhado") and _definition(&"pilot_cultist_b").description.contains("Olhar do Abismo"), "targeted descriptions name the skill in pt-BR")

# --- Short combat -------------------------------------------------------------------------

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	secondaries.clear()

func _setup(evolution: StringName, stacks: Dictionary) -> void:
	_cleanup()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	var state := RunState.from_build("augments-" + str(checks), _snapshot(evolution))
	state.augment_stacks.assign(stacks)
	var injected := state.set_effect_catalog(catalog)
	_check(injected["ok"] or stacks.has(&"pilot_priest_a"), "run injects the active catalog")
	player = PlayerActor.new()
	player.configure(navigation, state)
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(400, 350)
	controller.player = player
	controller.run_state = state
	controller.rng.seed = 29
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	player.status_damage_requested.connect(func(request: DamageRequest, _victim: CombatActor) -> void: secondaries.append(request.copy()))

func _enemy(at: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	controller.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position = at
	enemy.health.max_hp = 100000.0
	enemy.health.current_hp = 100000.0
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(enemy)
	return enemy

## One direct hit of `skill` through the real request path, then the build-effect procs as main.gd does.
func _hit(enemy: CombatActor, skill: StringName) -> void:
	player._begin_effect_emission()
	var request := player.kit_make_request(enemy, skill, 0.0, 100.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	player.kit_emit_hit(request, enemy)

func _secondary_total() -> float:
	var total := 0.0
	for request: DamageRequest in secondaries:
		total += request.magic_damage
	return total

func _baseline(evolution: StringName) -> Dictionary:
	_setup(evolution, {})
	return {"hp": player.health.max_hp, "sp": player.max_sp}

func _check_combat() -> void:
	var base_line := _baseline(&"")
	var priest_line := _baseline(&"priest")
	var cultist_line := _baseline(&"cultist")
	# acolyte_pressure: any hit of the base; 6 / 12 / 18 per stack.
	for stacks: int in [1, 2, 3]:
		_setup(&"", {&"pilot_acolyte_pressure": stacks})
		var enemy := _enemy(Vector2(460, 350))
		_hit(enemy, &"acolyte_punishing_light")
		_hit(enemy, &"acolyte_shadow_seal")
		_check(secondaries.size() == 2 and is_equal_approx(_secondary_total(), 12.0 * stacks), "pressure adds %d per hit at %d stack(s)" % [6 * stacks, stacks])
		_check(secondaries.all(func(request: DamageRequest) -> bool: return request.is_secondary and not request.can_crit), "pressure secondaries are secondary and cannot crit")
	_setup(&"priest", {&"pilot_acolyte_pressure": 1})
	_hit(_enemy(Vector2(460, 350)), &"priest_judgment")
	_check(secondaries.size() == 1, "pressure also serves the evolution's hits")
	# acolyte_reserve: +6 SP per stack, on the base and on both pures.
	for evolution: StringName in [&"", &"priest", &"cultist"]:
		var line: Dictionary = {&"": base_line, &"priest": priest_line, &"cultist": cultist_line}[evolution]
		_setup(evolution, {&"pilot_acolyte_reserve": 2})
		_check(is_equal_approx(player.max_sp - float(line["sp"]), 12.0), "reserve raises max SP by 12 at 2 stacks ('%s': %.1f)" % [evolution, player.max_sp - float(line["sp"])])
	# priest_a: +30 max HP per stack, only composed for the priest.
	_setup(&"priest", {&"pilot_priest_a": 3})
	_check(is_equal_approx(player.health.max_hp - float(priest_line["hp"]), 90.0), "Muralha da Fé raises max HP by 90 at 3 stacks (%.1f)" % (player.health.max_hp - float(priest_line["hp"])))
	_setup(&"cultist", {&"pilot_priest_a": 3})
	_check(is_equal_approx(player.health.max_hp, float(cultist_line["hp"])), "priest stat augment is inert on the cultist run")
	# Targeted hit augments: exact skill only, one secondary, no cascade, curve per stack.
	for id: StringName in [&"pilot_priest_b", &"pilot_cultist_a", &"pilot_cultist_b"]:
		var evolution: StringName = EVOLUTION[id]
		_setup(evolution, {id: 1})
		var enemy := _enemy(Vector2(460, 350))
		_hit(enemy, &"acolyte_punishing_light")
		_check(secondaries.is_empty(), "%s ignores other skills" % id)
		_hit(enemy, HIT_SKILL[id])
		_check(secondaries.size() == 1 and is_equal_approx(secondaries[0].magic_damage, 6.0), "%s adds exactly 6 on %s" % [id, HIT_SKILL[id]])
		if secondaries.size() == 1:
			player.kit_emit_hit(secondaries[0], enemy)
			_check(secondaries.size() == 1, "%s secondary cannot cascade" % id)
		_setup(evolution, {})
		_hit(_enemy(Vector2(460, 350)), HIT_SKILL[id])
		_check(secondaries.is_empty(), "%s: without the augment the same hit has no secondary" % id)
		_setup(evolution, {id: 3})
		for index: int in 5:
			_hit(_enemy(Vector2(440 + index * 12, 330 + index * 8)), HIT_SKILL[id])
		_check(secondaries.size() == 5 and is_equal_approx(_secondary_total(), 90.0), "%s three stacks add 18 on each of five hits" % id)
