class_name EffectProcLedger
extends RefCounted
## Run-owned weak registry. Root claims live exactly as long as their envelopes.
## No TTL can reopen a claim while any projectile/timer/result still holds it.

const LEGACY_APPLICATION_CAP := 16
const APPLICATION_CAP := LEGACY_APPLICATION_CAP # Historical fixture compatibility only.
const LIVE_ROOT_CAP := 512
class RootBudget extends RefCounted:
	var root_event_id := ""
	var ancestor_root_id := ""
	var owner_id := 0
	var next_event_id := 1
	var used := 0
	var application_limit := LEGACY_APPLICATION_CAP
	var plan: Dictionary = {}
	var families: Dictionary = {}
	var targets: Dictionary = {}
	var carriers: Dictionary = {}
	var echo_bound := false
	var claims: Dictionary = {}
	var applied: Dictionary = {}
	var cancelled := false

var _roots: Dictionary = {}
var _serial := 0
var _run_id := "run"
var _cancelled := false

func _init(run_id: String = "run") -> void:
	_run_id = run_id

func live_roots() -> int:
	for id: String in _roots.keys():
		if (_roots[id] as WeakRef).get_ref() == null:
			_roots.erase(id)
	return _roots.size()

func can_create_root() -> bool:
	return not _cancelled and live_roots() < LIVE_ROOT_CAP

func new_root(owner_id: int, secondary: bool = false, ancestor: String = "", intrinsic: bool = false, plan: Dictionary = {}) -> CombatEventContext:
	if owner_id <= 0 or not can_create_root():
		return null
	var checked := validate_plan(plan)
	if not checked["ok"]:
		return null
	_serial += 1
	var budget := RootBudget.new()
	budget.root_event_id = "%s:%d:%d" % [_run_id, owner_id, _serial]
	budget.ancestor_root_id = ancestor
	budget.owner_id = owner_id
	budget.plan = plan.duplicate(true)
	if not plan.is_empty():
		for family: StringName in plan["families"]:
			budget.families[family] = true
		for target: int in plan["targets"]:
			budget.targets[target] = true
		for carrier: int in plan["carriers"]:
			budget.carriers[carrier] = true
		budget.application_limit = (budget.families.size() + budget.carriers.size()) * budget.targets.size()
	_roots[budget.root_event_id] = weakref(budget)
	var context := CombatEventContext.new()
	context._ledger = weakref(self)
	context._budget = budget
	context.secondary = secondary
	context.depth = 1 if secondary else 0
	context.intrinsic = intrinsic
	return context

func claim_batch(context: CombatEventContext, candidates: Array[Dictionary]) -> Array[Dictionary]:
	return _claim(context, candidates, false)

func claim_intrinsic(context: CombatEventContext, candidates: Array[Dictionary]) -> Array[Dictionary]:
	# Only explicitly emitted kit components/ticks, never a proc child.
	return _claim(context, candidates, true)

func _claim(context: CombatEventContext, candidates: Array[Dictionary], allow_intrinsic: bool, echo_carrier: int = 0, kit_recovery: bool = false) -> Array[Dictionary]:
	var accepted: Array[Dictionary] = []
	if context == null or not context.is_active() or context.ledger() != self or (context.secondary and not (kit_recovery or (allow_intrinsic and not context.proc_child and context.event_id == 0))):
		return accepted
	var ordered := candidates.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if String(a.get("family_id", "")) != String(b.get("family_id", "")):
			return String(a.get("family_id", "")) < String(b.get("family_id", ""))
		if String(a.get("source_id", "")) != String(b.get("source_id", "")):
			return String(a.get("source_id", "")) < String(b.get("source_id", ""))
		return int(a.get("target_id", 0)) < int(b.get("target_id", 0)))
	var budget: RootBudget = context._budget
	for candidate: Dictionary in ordered:
		var family := StringName(candidate.get("family_id", &""))
		var source := StringName(candidate.get("source_id", &""))
		var target := int(candidate.get("target_id", 0))
		if family.is_empty() or source.is_empty() or target <= 0:
			continue
		if allow_intrinsic and context.event_id == 0 and not context.proc_child and budget.families.has(family):
			_admit_target(context, target, true)
		if not budget.plan.is_empty() and (not budget.targets.has(target) or (not budget.families.has(family) if echo_carrier <= 0 else not budget.carriers.has(echo_carrier))):
			continue
		var key := "%s:%d" % [family, target]
		if echo_carrier > 0:
			key = "spiritualist_echo:%d:%d" % [echo_carrier, target]
		if budget.claims.has(key) or budget.used >= budget.application_limit:
			continue
		budget.claims[key] = true
		budget.used += 1
		var child := context.copy_context()
		child.parent_event_id = context.event_id
		child.event_id = budget.next_event_id
		budget.next_event_id += 1
		child.secondary = true
		child.depth = 1
		child.intrinsic = allow_intrinsic
		child.proc_child = not allow_intrinsic
		child.family_id = family
		child.source_id = source
		child.target_id = target
		var payload := candidate.duplicate(true)
		payload["context"] = child
		accepted.append(payload)
	return accepted

func apply_once(context: CombatEventContext) -> bool:
	if context == null or not context.is_active() or context.ledger() != self or context.event_id <= 0:
		return false
	var budget: RootBudget = context._budget
	if budget.applied.has(context.event_id):
		return false
	budget.applied[context.event_id] = true
	return true

func applications(context: CombatEventContext) -> int:
	return context._budget.used if context != null and context._budget != null else 0

func cancel() -> void:
	_cancelled = true
	for reference: WeakRef in _roots.values():
		var budget := reference.get_ref() as RootBudget
		if budget != null:
			budget.cancelled = true
	_roots.clear()

func claim_kit_recovery(context: CombatEventContext, family: StringName, source: StringName, target: int) -> bool:
	# Explicit E05 exceptions: intrinsic drain healing and kill healing from DoT.
	if family not in [&"blood_thirst", &"spiritualist_drain_heal"] or context == null or context.proc_child:
		return false
	return not _claim(context, [{"family_id": family, "source_id": source, "target_id": target}], true, 0, true).is_empty()

func claim_echo_pair(context: CombatEventContext, carrier_id: int, target_id: int) -> CombatEventContext:
	# Human E06-T1 exception (09/10): finite E05 carriers share their frozen root plan.
	# This API neither schedules carriers nor re-arms marks. EchoState owns that set.
	if carrier_id <= 0 or context == null or context.secondary or context.proc_child or not context.is_active() or context.ledger() != self:
		return null
	if not context._budget.plan.is_empty() and (not context._budget.echo_bound or not context._budget.carriers.has(carrier_id)):
		return null
	_admit_target(context, target_id, false, true)
	var claims := _claim(context, [{"family_id": &"spiritualist_echo", "source_id": &"spiritualist_echo_curse", "target_id": target_id}], false, carrier_id)
	return claims[0]["context"] if not claims.is_empty() else null

static func take_result_claim(result: Dictionary, family: StringName, target: int) -> CombatEventContext:
	for claim: Dictionary in result.get("_effect_claims", []):
		if claim["family_id"] == family and claim["target_id"] == target and not claim.get("taken", false):
			claim["taken"] = true # Before the consumer can call any listener.
			return claim["context"]
	return null

static func projectile_slots_available(tree: SceneTree, needed: int) -> bool:
	if tree == null or needed < 1:
		return false
	var active := 0
	for group: StringName in [&"player_projectiles", &"enemy_projectiles"]:
		for node: Node in tree.get_nodes_in_group(group):
			if not node.is_queued_for_deletion():
				active += 1
	return active + needed <= 128

static func validate_plan(plan: Dictionary) -> Dictionary:
	if plan.is_empty():
		return {"ok": true}
	if plan.size() != 3:
		return BuildEffectCatalog.failure(&"invalid_causal_plan")
	for key: String in ["families", "targets", "carriers"]:
		if not plan.get(key) is Array:
			return BuildEffectCatalog.failure(&"invalid_causal_plan")
		var seen: Dictionary = {}
		for value: Variant in plan[key]:
			if seen.has(value):
				return BuildEffectCatalog.failure(&"invalid_causal_plan")
			if key == "families":
				if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME] or not IdentityIds.is_technical_id(String(value)):
					return BuildEffectCatalog.failure(&"invalid_causal_plan")
			elif typeof(value) != TYPE_INT or value <= 0:
				return BuildEffectCatalog.failure(&"invalid_causal_plan")
			seen[value] = true
	for carrier: int in plan["carriers"]:
		if carrier not in plan["targets"]:
			return BuildEffectCatalog.failure(&"invalid_causal_plan")
	return {"ok": true}

func application_limit(context: CombatEventContext) -> int:
	return context._budget.application_limit if context != null and context._budget != null else 0

func _admit_target(context: CombatEventContext, target: int, intrinsic_emitter: bool = false, echo_emitter: bool = false, hunter_fan_emitter: bool = false) -> bool:
	# Called only after a producer has validated its actual collision/occurrence.
	# Generic callbacks cannot extend the domain with arbitrary candidates.
	if context == null or not context.is_active() or context.ledger() != self or target <= 0 or context.proc_child or (context.secondary and not intrinsic_emitter) or (context.event_id > 0 and not echo_emitter and not hunter_fan_emitter):
		return false
	var budget: RootBudget = context._budget
	if budget.plan.is_empty(): return true # Historical cap16 remains unchanged.
	if not budget.targets.has(target):
		budget.targets[target] = true
		budget.plan["targets"].append(target)
		_recompute_limit(budget)
	return true

func admit_hunter_fan(result: Dictionary, target: int) -> bool:
	# Closed producer: main validates nearest living enemy and line of sight first.
	var context: CombatEventContext = result.get("context")
	if context == null or not context.is_active() or context.secondary or context.proc_child or context.ledger() != self or context.event_id <= 0 or context.target_id != int(result.get("target_id", 0)) or int(result.get("source_id", 0)) != context._budget.owner_id or not bool(result.get("can_trigger_effects", false)) or float(result.get("actual_damage", 0.0)) <= 0.0 or StringName(result.get("skill_id", &"")) != &"hunter_covering_shot" or not bool(result.get("effect_snapshot", {}).get("kit_policies", {}).get(&"hunter_covering_fan", false)): return false
	return _admit_target(context, target, false, false, true)

func bind_echo_carriers(context: CombatEventContext, carriers: Array[int]) -> bool:
	if context == null or not context.is_active() or context.ledger() != self or context.secondary or context.proc_child:
		return false
	var admitted: Dictionary = {}
	for carrier: int in carriers:
		if carrier <= 0 or admitted.has(carrier): return false
		admitted[carrier] = true
	var budget: RootBudget = context._budget
	if budget.echo_bound: return budget.carriers == admitted
	budget.echo_bound = true
	if budget.plan.is_empty(): return true
	budget.carriers = admitted
	budget.plan["carriers"] = carriers.duplicate()
	for carrier: int in carriers:
		if not budget.targets.has(carrier):
			budget.targets[carrier] = true
			budget.plan["targets"].append(carrier)
	_recompute_limit(budget)
	return true

func _recompute_limit(budget: RootBudget) -> void:
	budget.application_limit = (budget.families.size() + budget.carriers.size()) * budget.targets.size()
