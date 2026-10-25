@tool
extends RefCounted
## Optional editor metadata. Publishing never makes a physical object invisible.
static func empty() -> Dictionary: return {"version":1,"groups":[],"states":[]}

static func validate(value: Variant, placements: Array, schema: GDScript) -> Dictionary:
	var errors: Array = []
	schema._shape(value,{"version":"number","groups":"array","states":"array"},"objects",errors)
	if not errors.is_empty(): return schema.result(false,"object_metadata_invalid",errors)
	if value.version != 1 or value.groups.size() > 128 or value.states.size() > 4096: return schema.result(false,"object_metadata_invalid")
	var groups := {}; var states := {}; var ids := {}
	for placement: Dictionary in placements: ids[placement.placement_id] = true
	for group: Variant in value.groups:
		schema._shape(group,{"group_id":"id","name":"string","locked":"bool","hidden":"bool"},"objects.groups",errors)
		if not errors.is_empty(): return schema.result(false,"object_metadata_invalid",errors)
		if groups.has(group.group_id): return schema.result(false,"object_duplicate_group")
		groups[group.group_id] = true
	for state: Variant in value.states:
		schema._shape(state,{"placement_id":"id","group_id":"string","locked":"bool","hidden":"bool"},"objects.states",errors)
		if not errors.is_empty(): return schema.result(false,"object_metadata_invalid",errors)
		if states.has(state.placement_id) or not ids.has(state.placement_id) or (state.group_id != "" and not groups.has(state.group_id)): return schema.result(false,"object_metadata_reference")
		states[state.placement_id] = true
	return schema.result(true)

static func state(source: Dictionary, id: String) -> Dictionary:
	var result := {"placement_id":id,"group_id":"","locked":false,"hidden":false}
	for item: Dictionary in source.get("objects",{}).get("states",[]):
		if item.placement_id == id: result = item.duplicate(true); break
	for group: Dictionary in source.get("objects",{}).get("groups",[]):
		if group.group_id == result.group_id:
			result.locked = result.locked or group.locked
			result.hidden = result.hidden or group.hidden
	return result

static func locked(source: Dictionary, placement: Dictionary) -> bool:
	if state(source,placement.placement_id).locked: return true
	var layer_id: String = placement.surface_id
	for surface: Dictionary in source.special_surfaces:
		if surface.surface_id == layer_id: layer_id = surface.layer_id; break
	for layer: Dictionary in source.layers:
		if layer.layer_id == layer_id: return layer.locked
	return true

static func duplicate_metadata(source: Dictionary, remap: Dictionary, new_id: Callable) -> void:
	if not source.has("objects"): return
	var groups := {}
	var states: Array = source.objects.states.duplicate(true)
	for state: Dictionary in states:
		if not remap.has(state.placement_id): continue
		var copy := state.duplicate(true); copy.placement_id = remap[state.placement_id]
		if state.group_id != "":
			if not groups.has(state.group_id):
				for group: Dictionary in source.objects.groups.duplicate(true):
					if group.group_id != state.group_id: continue
					var duplicate := group.duplicate(true)
					duplicate.group_id = new_id.call(state.group_id); duplicate.name += " (cópia)"
					groups[state.group_id] = duplicate.group_id; source.objects.groups.append(duplicate); break
			copy.group_id = groups[state.group_id]
		source.objects.states.append(copy)
