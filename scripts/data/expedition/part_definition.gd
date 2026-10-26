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

	for extension: String in ["solid_prisms","internal_connections"]:
		var values: Array = get(extension)
		if values.is_empty(): continue
		var copied := values.duplicate(true)
		copied.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return ExpeditionCanonical.encode(a) < ExpeditionCanonical.encode(b))
		result[extension] = copied
	return result
