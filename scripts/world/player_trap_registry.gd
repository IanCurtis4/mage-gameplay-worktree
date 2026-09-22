class_name PlayerTrapRegistry
extends Node2D
## Per-owner FIFO registry shared by every player trap type.

signal trap_registered(trap: PlayerTrap)
signal trap_removed(trap: PlayerTrap, reason: StringName)

const MAX_TRAPS_PER_OWNER := 3

var _traps: Array[PlayerTrap] = []
var _next_registration_order := 1

func register_trap(trap: PlayerTrap) -> bool:
	if trap == null or not is_instance_valid(trap) or not trap.is_configured() or not trap.is_active() or trap.get_parent() != null:
		return false
	_prune_invalid()
	var owned := active_traps(trap.owner_id)
	if owned.size() >= MAX_TRAPS_PER_OWNER:
		owned[0].expire(PlayerTrap.REASON_REPLACED)
	trap.registration_order = _next_registration_order
	_next_registration_order += 1
	trap.removed.connect(_on_trap_removed)
	trap.tree_exiting.connect(_on_trap_tree_exiting.bind(trap))
	add_child(trap)
	trap.add_to_group("player_traps")
	trap.add_to_group("player_effects")
	_traps.append(trap)
	trap_registered.emit(trap)
	return true

func active_traps(owner_id: int = 0) -> Array[PlayerTrap]:
	_prune_invalid()
	var result: Array[PlayerTrap] = []
	for trap: PlayerTrap in _traps:
		if trap.is_active() and (owner_id == 0 or trap.owner_id == owner_id):
			result.append(trap)
	result.sort_custom(func(first: PlayerTrap, second: PlayerTrap) -> bool: return first.registration_order < second.registration_order)
	return result

func active_count(owner_id: int = 0) -> int:
	return active_traps(owner_id).size()

func clear_owner(owner_id: int, reason: StringName = PlayerTrap.REASON_CLEANUP) -> int:
	var owned := active_traps(owner_id)
	for trap: PlayerTrap in owned:
		trap.expire(reason)
	return owned.size()

func clear_all(reason: StringName = PlayerTrap.REASON_CLEANUP) -> int:
	var active := active_traps()
	for trap: PlayerTrap in active:
		trap.expire(reason)
	return active.size()

func _on_trap_removed(trap: PlayerTrap, reason: StringName) -> void:
	if trap not in _traps:
		return
	_traps.erase(trap)
	trap_removed.emit(trap, reason)

func _on_trap_tree_exiting(trap: PlayerTrap) -> void:
	if trap not in _traps:
		return
	_traps.erase(trap)
	trap_removed.emit(trap, &"external")

func _prune_invalid() -> void:
	for index: int in range(_traps.size() - 1, -1, -1):
		if not is_instance_valid(_traps[index]):
			_traps.remove_at(index)
