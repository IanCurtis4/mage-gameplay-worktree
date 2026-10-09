class_name CombatEventContext
extends RefCounted
## A value envelope holding a live root budget. Copies never reset ancestry.

var _ledger: WeakRef
var _budget: RefCounted
var event_id: int = 0
var parent_event_id: int = 0
var family_id: StringName = &""
var source_id: StringName = &""
var target_id: int = 0
var secondary: bool = false
var depth: int = 0
var intrinsic: bool = false
var proc_child: bool = false

var root_event_id: String:
	get: return _budget.root_event_id if _budget != null else ""
var ancestor_root_id: String:
	get: return _budget.ancestor_root_id if _budget != null else ""

func ledger() -> EffectProcLedger:
	return _ledger.get_ref() as EffectProcLedger if _ledger != null else null

func is_active() -> bool:
	return _budget != null and not _budget.cancelled and ledger() != null

func copy_context() -> CombatEventContext:
	var result := CombatEventContext.new()
	result._ledger = _ledger
	result._budget = _budget
	result.event_id = event_id
	result.parent_event_id = parent_event_id
	result.family_id = family_id
	result.source_id = source_id
	result.target_id = target_id
	result.secondary = secondary
	result.depth = depth
	result.intrinsic = intrinsic
	result.proc_child = proc_child
	return result

func secondary_prototype() -> CombatEventContext:
	var result := copy_context()
	result.secondary = true
	result.depth = 1
	return result

func impact(victim_id: int) -> CombatEventContext:
	if not is_active():
		return null
	if event_id > 0:
		return copy_context()
	var result := copy_context()
	result.event_id = _budget.next_event_id
	_budget.next_event_id += 1
	result.target_id = victim_id
	return result

func scheduled_tick() -> CombatEventContext:
	var owner := ledger()
	return owner.new_root(_budget.owner_id, secondary, root_event_id, true) if is_active() and owner != null and not proc_child else null
