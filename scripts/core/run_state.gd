class_name RunState
extends RefCounted
## Mutable run-only state. Persistent character data enters only as a value snapshot.

const DEFAULT_CLASS_ID: StringName = &"swordsman"

var class_id: StringName = DEFAULT_CLASS_ID
var run_id: String = ""
var character_id: String = ""
var build_snapshot: BuildSnapshot
var skill_levels: Dictionary[StringName, int] = {}
var augment_stacks: Dictionary[StringName, int] = {}
var pending_choices: int = 0
var current_offer: Array[AugmentDefinition] = []
var _effect_catalog: BuildEffectCatalog
var effect_ledger := EffectProcLedger.new()
var runtime_revision: int = 1
var transaction_locked := false
var card_sockets: Dictionary = {}
var card_inventory := RunCardInventory.new()
var local_equipment: Array[StringName] = []
var _effect_cache_key: int = 0
var _effect_cache: Dictionary = {}
var _effect_cache_serial := 0
var _offer_open := false
var _offer_serial := 0
var _choice_serial := 0
var _choice_ids: Array[int] = []
var _offer_id := 0
var _offer_revision := 0
var _offer_ids: Array[StringName] = []
var _uses_persistent_build: bool = false

func _init(selected_class: StringName = DEFAULT_CLASS_ID) -> void:
	_effect_catalog = BuildContentLoader.pilot()
	select_class(selected_class)

static func from_build(new_run_id: String, source: BuildSnapshot) -> RunState:
	assert(source != null)
	var state := RunState.new()
	state.run_id = new_run_id
	state.effect_ledger = EffectProcLedger.new(new_run_id)
	state.character_id = source.character_id
	state.build_snapshot = source.copy_snapshot()
	state.class_id = state.build_snapshot.base_class_id
	state._uses_persistent_build = true
	state.reset()
	return state

func uses_persistent_build() -> bool:
	return _uses_persistent_build

func select_class(selected_class: StringName) -> bool:
	if _uses_persistent_build:
		return false
	if ClassCatalog.class_definition(selected_class) == null:
		return false
	class_id = selected_class
	build_snapshot = _pilot_snapshot(selected_class)
	reset()
	return true

func queue_choice() -> void:
	pending_choices += 1
	_choice_serial += 1
	_choice_ids.append(_choice_serial)

func can_open_choice(encounter_active: bool) -> bool:
	return pending_choices > 0 and not encounter_active and not transaction_locked

func effect_catalog() -> BuildEffectCatalog:
	return _effect_catalog.copy_catalog()

func set_effect_catalog(catalog: BuildEffectCatalog) -> Dictionary:
	if transaction_locked:
		return BuildEffectCatalog.failure(&"save_in_progress")
	if catalog == null or _offer_open:
		return BuildEffectCatalog.failure(&"offer_open" if _offer_open else &"missing_catalog")
	var candidate := BuildEffectComposer.compose(build_snapshot, effect_state(), [], catalog)
	if not candidate["ok"]:
		return candidate
	_effect_catalog = catalog.copy_catalog()
	runtime_revision += 1
	return {"ok": true, "error_code": &"", "request_id": "", "runtime_revision": runtime_revision}

func effect_state() -> Dictionary:
	return {"augment_stacks": augment_stacks.duplicate(true), "card_sockets": card_sockets.duplicate(true)}

func _ensure_effect_cache(temporary_sources: Array[Dictionary] = []) -> void:
	if build_snapshot == null:
		if _effect_cache.get("error_code", &"") != &"missing_snapshot":
			_effect_cache = BuildEffectCatalog.failure(&"missing_snapshot")
			_effect_cache_serial += 1
		return
	var key := hash([build_snapshot.base_class_id, build_snapshot.evolution_id, build_snapshot.base_level, build_snapshot.job_level, build_snapshot.attribute_allocations, skill_levels, build_snapshot.library_skill_ids, build_snapshot.equipped, build_snapshot.build_version, augment_stacks, card_sockets, temporary_sources, runtime_revision])
	if not _effect_cache.is_empty() and _effect_cache.get("error_code", &"") != &"missing_snapshot" and key == _effect_cache_key:
		return
	var snapshot := build_snapshot.copy_snapshot()
	snapshot.skill_ranks = skill_levels.duplicate(true)
	_effect_cache = BuildEffectComposer.compose(snapshot, effect_state(), temporary_sources, _effect_catalog)
	_effect_cache_key = key
	_effect_cache_serial += 1

func composed_build(temporary_sources: Array[Dictionary] = []) -> Dictionary:
	_ensure_effect_cache(temporary_sources)
	return BuildEffectComposer.copy_result(_effect_cache)

func composition_revision() -> int:
	_ensure_effect_cache()
	return _effect_cache_serial

func effects_valid() -> bool:
	_ensure_effect_cache()
	return _effect_cache.get("ok", false)

func skill_effect_capture(skill_id: StringName) -> Dictionary:
	_ensure_effect_cache()
	return SkillEffectResolver.capture(skill_id, int(skill_levels.get(skill_id, 0)), _effect_cache)

func stat_modifier_sources() -> Array[Dictionary]:
	var result := composed_build()
	var sources: Array[Dictionary] = []
	if result["ok"]:
		sources.assign(result["stat_sources"])
	return sources

func projectile_count(skill_id: StringName) -> int:
	var result := skill_effect_capture(skill_id)
	return int(result["values"]["projectile_count"]) if result["ok"] else 1

func has_open_offer() -> bool:
	return _offer_open

func offer_token() -> Dictionary:
	return {"choice_id": _choice_ids[0] if not _choice_ids.is_empty() else 0, "offer_id": _offer_id, "runtime_revision": _offer_revision}

func open_offer(encounter_active: bool, rng: RandomNumberGenerator) -> Dictionary:
	if not can_open_choice(encounter_active):
		return BuildEffectCatalog.failure(&"encounter_active" if encounter_active else &"no_pending_choice")
	if _offer_open:
		return _offer_dto()
	if rng == null:
		return BuildEffectCatalog.failure(&"missing_rng")
	var before := composed_build()
	if not before["ok"]:
		return before
	var eligible: Array[StringName] = []
	for id: StringName in _effect_catalog.ids(&"augment"):
		if _augment_candidate(id, before)["ok"]:
			eligible.append(id)
	# Validation finishes before RNG/state mutation; all subsequent work is infallible.
	while not eligible.is_empty() and _offer_ids.size() < 3:
		_offer_ids.append(eligible.pop_at(rng.randi_range(0, eligible.size() - 1)))
	_offer_serial += 1
	_offer_id = _offer_serial
	_offer_revision = runtime_revision
	_offer_open = true
	current_offer.clear()
	for id: StringName in _offer_ids:
		current_offer.append(_effect_catalog.get_definition(&"augment", id) as AugmentDefinition)
	return _offer_dto()

func confirm_offer(token: Dictionary, augment_id: StringName, encounter_active: bool) -> Dictionary:
	var valid := _validate_offer_token(token, encounter_active)
	if not valid["ok"]:
		return valid
	if augment_id not in _offer_ids:
		return BuildEffectCatalog.failure(&"not_in_offer")
	var candidate := _augment_candidate(augment_id, composed_build())
	if not candidate["ok"]:
		return candidate
	augment_stacks[augment_id] = int(augment_stacks.get(augment_id, 0)) + 1
	_finish_offer()
	return {"ok": true, "error_code": &"", "request_id": str(token["offer_id"]), "runtime_revision": runtime_revision}

func consume_empty_offer(token: Dictionary, encounter_active: bool) -> Dictionary:
	var valid := _validate_offer_token(token, encounter_active)
	if not valid["ok"]:
		return valid
	if not _offer_ids.is_empty():
		return BuildEffectCatalog.failure(&"offer_not_empty")
	_finish_offer()
	return {"ok": true, "error_code": &"", "request_id": str(token["offer_id"]), "runtime_revision": runtime_revision, "message": "Não há aprimoramentos elegíveis. Escolha consumida."}

func build_offer(encounter_active: bool, rng: RandomNumberGenerator) -> Array[AugmentDefinition]:
	var result := open_offer(encounter_active, rng)
	var definitions: Array[AugmentDefinition] = []
	if result["ok"]:
		definitions.assign(result["definitions"])
	return definitions

func confirm(augment_id: StringName, encounter_active: bool) -> bool:
	return confirm_offer(offer_token(), augment_id, encounter_active)["ok"]

func _offer_dto() -> Dictionary:
	var definitions: Array[AugmentDefinition] = []
	for id: StringName in _offer_ids:
		definitions.append(_effect_catalog.get_definition(&"augment", id) as AugmentDefinition)
	var result := offer_token()
	result.merge({"ok": true, "error_code": &"", "request_id": str(_offer_id), "ids": _offer_ids.duplicate(), "definitions": definitions, "empty": _offer_ids.is_empty()})
	return result

func _validate_offer_token(token: Dictionary, encounter_active: bool) -> Dictionary:
	if transaction_locked:
		return BuildEffectCatalog.failure(&"save_in_progress")
	if encounter_active:
		return BuildEffectCatalog.failure(&"encounter_active")
	if not _offer_open or _choice_ids.is_empty() or pending_choices <= 0:
		return BuildEffectCatalog.failure(&"offer_not_open")
	if token.get("choice_id", -1) != _choice_ids[0] or token.get("offer_id", -1) != _offer_id:
		return BuildEffectCatalog.failure(&"stale_offer")
	if token.get("runtime_revision", -1) != _offer_revision or runtime_revision != _offer_revision:
		return BuildEffectCatalog.failure(&"stale_revision")
	return {"ok": true, "error_code": &"", "request_id": str(_offer_id)}

func _finish_offer() -> void:
	pending_choices -= 1
	_choice_ids.pop_front()
	_offer_ids.clear()
	current_offer.clear()
	_offer_open = false
	runtime_revision += 1

func _augment_candidate(id: StringName, before: Dictionary) -> Dictionary:
	var definition := _effect_catalog.get_definition(&"augment", id) as AugmentDefinition
	if definition == null:
		return BuildEffectCatalog.failure(&"unknown_definition")
	var stacks := int(augment_stacks.get(id, 0))
	if stacks >= definition.max_stacks:
		return BuildEffectCatalog.failure(&"stack_cap")
	if not before.get("ok", false):
		return before
	var state := effect_state()
	state["augment_stacks"][id] = stacks + 1
	var snapshot := build_snapshot.copy_snapshot()
	snapshot.skill_ranks = skill_levels.duplicate(true)
	var after := BuildEffectComposer.compose(snapshot, state, [], _effect_catalog)
	if not after["ok"]:
		return after
	if before["breakdown"].values() != after["breakdown"].values() or _effective_proc_signature(before["procs"]) != _effective_proc_signature(after["procs"]):
		return after
	for skill: StringName in after["skill_rules"]:
		var previous := SkillEffectResolver.capture(skill, int(skill_levels.get(skill, 0)), before)
		var following := SkillEffectResolver.capture(skill, int(skill_levels.get(skill, 0)), after)
		if previous["ok"] and following["ok"] and previous["values"] != following["values"]:
			return after
	return BuildEffectCatalog.failure(&"no_effective_gain")

func describe_progress(definition: AugmentDefinition) -> String:
	var current: int = augment_stacks.get(definition.id, 0)
	var current_value := definition.magnitude_per_stack * float(current)
	var next_value := definition.magnitude_per_stack * float(current + 1)
	return "Atual: %s  →  Próximo: %s" % [_format_effect(definition.effect_id, current_value), _format_effect(definition.effect_id, next_value)]

func reset() -> void:
	skill_levels.clear()
	if build_snapshot != null:
		skill_levels = build_snapshot.skill_ranks.duplicate(true)
	augment_stacks.clear()
	pending_choices = 0
	current_offer.clear()
	card_sockets.clear()
	card_inventory.clear()
	_offer_ids.clear()
	_choice_ids.clear()
	_offer_open = false
	runtime_revision += 1
	effect_ledger.cancel()
	effect_ledger = EffectProcLedger.new(run_id if not run_id.is_empty() else "pilot")

func _pilot_snapshot(selected_class: StringName) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = selected_class
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	for skill_id: StringName in ClassCatalog.skill_ids(selected_class):
		snapshot.skill_ranks[skill_id] = 1
	snapshot.active_slots = ClassCatalog.skill_ids(selected_class)
	snapshot.action_slots = ActionBarLayout.from_legacy(snapshot.active_slots)
	var definition := ClassCatalog.class_definition(selected_class)
	if definition != null and definition.passive_id != &"":
		snapshot.skill_ranks[definition.passive_id] = 1
		snapshot.passive_slots = [definition.passive_id]
	return snapshot

func _format_effect(effect_id: StringName, value: float) -> String:
	if effect_id == &"crit_chance_flat":
		return "+%d p.p." % int(round(value * 100.0))
	if effect_id in [&"fire_spear_count_flat", &"ice_spear_count_flat"]:
		return "+%d lança(s)" % int(round(value))
	return "+%d%%" % int(round(value * 100.0))

func _effective_proc_signature(procs: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for proc: Dictionary in procs:
		var flat := float(proc["flat"])
		var increased := float(proc["increased"])
		var cap := float(proc["limit"])
		if flat <= 0.0 and increased <= 0.0:
			continue
		# Every legal hit has at least one HP damage. At that point a saturated
		# family cannot gain from any extra flat/increased magnitude or provenance.
		if flat + increased >= cap:
			flat = cap
			increased = 0.0
		result.append({"family_id": proc["family_id"], "trigger": proc["trigger"], "axis": proc["axis"], "targets": proc["targets"], "flat": flat, "increased": increased, "limit": cap})
	return result
