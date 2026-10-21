class_name SnapshotTickBarrier
extends RefCounted
## Acquire only at a completed tick: a paused tree or detached fixture.
## Live hosts schedule capture with call_deferred, after synchronous tick callbacks.
var _root: WeakRef
var _modes: Dictionary = {}
var held := false

func acquire(root: Node) -> Dictionary:
	if held or not is_instance_valid(root): return StableEntityRegistry.failure(&"snapshot_barrier_busy")
	if root.is_inside_tree() and not root.get_tree().paused: return StableEntityRegistry.failure(&"tick_barrier_required")
	_root = weakref(root)
	_freeze(root)
	held = true
	return {"ok":true}

func _freeze(node: Node) -> void:
	_modes[node.get_instance_id()] = {"node":weakref(node),"mode":node.process_mode}
	for child: Node in node.get_children(): _freeze(child)
	node.process_mode = Node.PROCESS_MODE_DISABLED

func owns(root: Node) -> bool:
	return held and _root != null and _root.get_ref() == root

func saved_mode(node: Node) -> int:
	return int(_modes.get(node.get_instance_id(), {}).get("mode", node.process_mode))

func release() -> void:
	for entry: Dictionary in _modes.values():
		var node: Node = entry["node"].get_ref()
		if is_instance_valid(node): node.process_mode = entry["mode"]
	_modes.clear()
	_root = null
	held = false
