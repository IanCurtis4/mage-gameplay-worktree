class_name StableEntityRegistry
extends RefCounted
## Run-owned bijection. Surviving entities retain identity across consecutive
## cuts. Local engine IDs never enter the captured envelope.
const SCOPE_META := &"_expedition_snapshot_identity_service"
const MAX_IDENTITIES := 1000000
var _by_local: Dictionary[int, String] = {}
var _by_stable: Dictionary[String, WeakRef] = {}
var _tombstones: Dictionary[String, int] = {}
var _generations: Dictionary[String, int] = {}
var _tombstone_nodes: Array[Node] = []
var _next := 1

func register(entity: Object, stable_id: String = "", generation: int = -1) -> Dictionary:
	if not is_instance_valid(entity): return failure(&"dangling_entity_reference")
	if generation < -1 or (not stable_id.is_empty() and not _valid_id(stable_id)): return failure(&"invalid_identity")
	var local := entity.get_instance_id()
	if _by_local.has(local):
		if generation >= 0 and generation != _generations.get(_by_local[local],0): return failure(&"stale_generation")
		return {"ok":true,"stable_id":_by_local[local]} if stable_id.is_empty() or stable_id == _by_local[local] else failure(&"duplicate_stable_id")
	if stable_id.is_empty():
		if _next > MAX_IDENTITIES: return failure(&"snapshot_too_large")
		stable_id = "entity_%06d" % _next
		_next += 1
	if _by_stable.has(stable_id) or _tombstones.has(stable_id): return failure(&"duplicate_stable_id")
	_by_local[local] = stable_id
	_by_stable[stable_id] = weakref(entity)
	_generations[stable_id] = maxi(0,generation)
	_next = maxi(_next,int(stable_id.trim_prefix("entity_"))+1)
	return {"ok":true,"stable_id":stable_id}

func stable_for(local: int) -> String:
	return _by_local.get(local, "")

func resolve(stable_id: String) -> Object:
	var reference: WeakRef = _by_stable.get(stable_id)
	return reference.get_ref() if reference != null else null

func local_for(stable_id: String) -> int:
	var entity := resolve(stable_id)
	return entity.get_instance_id() if entity != null else int(_tombstones.get(stable_id, 0))

func tombstone(local: int) -> String:
	if _by_local.has(local): return _by_local[local]
	if _next > MAX_IDENTITIES: return ""
	var id := "entity_%06d" % _next
	_next += 1
	_by_local[local] = id
	_tombstones[id] = local
	_generations[id] = 0
	return id

func restore_tombstone(id: String, local: int, generation: int = 0) -> Dictionary:
	if not _valid_id(id) or local == 0 or generation < 0: return failure(&"invalid_identity")
	if _by_stable.has(id) or _tombstones.has(id) or _by_local.has(local): return failure(&"duplicate_stable_id")
	_by_local[local] = id
	_tombstones[id] = local
	_generations[id] = generation
	_next = maxi(_next,int(id.trim_prefix("entity_"))+1)
	return {"ok":true}

func allocate_tombstone(id: String, generation: int) -> Dictionary:
	# Actor IDs must remain positive in the existing finite-plan API. Godot
	# RefCounted IDs carry a high bit and become negative in a signed int.
	# An inert detached Node reserves a positive, collision-free local token.
	var token := Node.new()
	var result := restore_tombstone(id,token.get_instance_id(),generation)
	if result["ok"]: _tombstone_nodes.append(token)
	else: token.free()
	return result

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for token: Node in _tombstone_nodes:
			if is_instance_valid(token): token.free()

func tombstone_ids() -> Array:
	return _tombstones.keys()

func generation_for(id: String) -> int:
	return _generations.get(id,0)

func is_tombstone_local(local: int) -> bool:
	return _by_local.has(local) and _tombstones.has(_by_local[local])

func next_serial() -> int:
	return _next

func reserve_serial(serial: int) -> void:
	_next = maxi(_next,serial)

func _valid_id(id: String) -> bool:
	var serial := int(id.trim_prefix("entity_"))
	return serial > 0 and serial <= MAX_IDENTITIES and id == "entity_%06d" % serial

static func failure(code: StringName, detail: String = "") -> Dictionary:
	return {"ok":false,"error_code":code,"detail":detail}
