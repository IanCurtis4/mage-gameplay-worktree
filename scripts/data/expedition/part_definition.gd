class_name ExpeditionPartDefinition
extends Resource
@export var part_id: String = ""
@export var revision: int = 0
@export var biome_tags: PackedStringArray = PackedStringArray()
@export var allowed_rotations: Array[int] = []
@export var surfaces: Array[ExpeditionSurfaceDefinition] = []
@export var connectors: Array[ExpeditionConnectorDefinition] = []
@export var sockets: Array[ExpeditionSocketDefinition] = []
@export var solid_volumes: Array[AABB] = []
@export var blockers: Array[AABB] = []
@export var solid_prisms: Array[Dictionary] = []
@export var internal_connections: Array[Dictionary] = []
@export var connector_groups: Array[Dictionary] = []

func to_data() -> Dictionary:
	var surface_data: Array[Dictionary] = []
	var connector_data: Array[Dictionary] = []
	var socket_data: Array[Dictionary] = []
	for surface: ExpeditionSurfaceDefinition in surfaces:
		if surface == null: return {}
		surface_data.append(surface.to_data())
	for connector: ExpeditionConnectorDefinition in connectors:
		if connector == null: return {}
		connector_data.append(connector.to_data())
	for socket: ExpeditionSocketDefinition in sockets:
		if socket == null: return {}
		socket_data.append(socket.to_data())
	surface_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["surface_id"] < b["surface_id"])
	connector_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["connector_id"] < b["connector_id"])
	socket_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["socket_id"] < b["socket_id"])
	var tags := Array(biome_tags)
	tags.sort()
	var rotations := allowed_rotations.duplicate()
	rotations.sort()
	var solids := Array(solid_volumes)
	var obstacles := Array(blockers)
	for volumes: Array in [solids, obstacles]:
		volumes.sort_custom(func(a: AABB, b: AABB) -> bool: return ExpeditionCanonical.encode(a) < ExpeditionCanonical.encode(b))
	var result := {"part_id": part_id, "revision": revision, "biome_tags": tags, "allowed_rotations": rotations,
		"surfaces": surface_data, "connectors": connector_data, "sockets": socket_data,
		"solid_volumes": solids, "blockers": obstacles}

	for extension: String in ["solid_prisms","internal_connections","connector_groups"]:
		var values: Array = get(extension)
		if values.is_empty(): continue
		var copied := values.duplicate(true)
		if extension == "connector_groups":
			for group: Dictionary in copied:
				if group.get("fragments") is Array: group.fragments.sort_custom(_fragment_before)
		copied.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return ExpeditionCanonical.encode(a) < ExpeditionCanonical.encode(b))
		result[extension] = copied
	return result

static func _fragment_before(a: Variant, b: Variant) -> bool:
	var valid_a: bool = a is Dictionary and (a.get("t0") is int or a.get("t0") is float) and (a.get("t1") is int or a.get("t1") is float) and is_finite(float(a.t0)) and is_finite(float(a.t1))
	var valid_b: bool = b is Dictionary and (b.get("t0") is int or b.get("t0") is float) and (b.get("t1") is int or b.get("t1") is float) and is_finite(float(b.t0)) and is_finite(float(b.t1))
	if valid_a != valid_b: return valid_a
	if valid_a:
		if a.t0 != b.t0: return a.t0 < b.t0
		if a.t1 != b.t1: return a.t1 < b.t1
	return ExpeditionCanonical.encode(a) < ExpeditionCanonical.encode(b)
