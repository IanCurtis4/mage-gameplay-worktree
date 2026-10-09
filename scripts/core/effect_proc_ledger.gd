class_name EffectProcLedger
extends RefCounted
## Run-owned weak registry. Root claims live exactly as long as their envelopes.
## No TTL can reopen a claim while any projectile/timer/result still holds it.

const APPLICATION_CAP := 16
const LIVE_ROOT_CAP := 512
class RootBudget extends RefCounted:
	var root_event_id := ""
	var ancestor_root_id := ""
	var owner_id := 0
	var next_event_id := 1
	var used := 0
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

func new_root(owner_id: int, secondary: bool = false, ancestor: String = "", intrinsic: bool = false) -> CombatEventContext:
	if owner_id <= 0 or not can_create_root():
		return null
	_serial += 1
	var budget := RootBudget.new()
	budget.root_event_id = "%s:%d:%d" % [_run_id, owner_id, _serial]
	budget.ancestor_root_id = ancestor
	budget.owner_id = owner_id
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
		var key := "%s:%d" % [family, target]
		if echo_carrier > 0:
			key = "spiritualist_echo:%d:%d" % [echo_carrier, target]
		if budget.claims.has(key) or budget.used >= APPLICATION_CAP:
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
	if family not in [&"blood_thirst", &"spiritualist_drain_heal"] or context == null:
		return false
	return not _claim(context, [{"family_id": family, "source_id": source, "target_id": target}], true, 0, true).is_empty()

func claim_echo_pair(context: CombatEventContext, carrier_id: int, target_id: int) -> CombatEventContext:
	# Human E06-T1 exception (09/10): finite E05 carriers share the original cap16.
	# This API neither schedules carriers nor re-arms marks. EchoState owns that set.
	if carrier_id <= 0 or context == null or context.secondary:
		return null
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
