@tool
extends RefCounted
## Closed source transactions shared by the inspector, AX and headless editing.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Catalog = preload("res://scripts/map_authoring/composition/border_profile_catalog.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const LEGACY := "ruin_envelope_v1"
# One update for every supported instance/transition and the decoration flag.
const MAX_COMMANDS := 32+496+1

static func empty() -> Dictionary:
	return {"version":1,"instances":[],"transitions":[],"decorations":true}

static func validate(settings: Variant, instances: Array) -> Dictionary:
	var errors: Array = []
	Schema._shape(settings,{"version":"int","instances":"array","transitions":"array","decorations":"bool"},"borders",errors)
	if not errors.is_empty() or settings.version != 1 or settings.instances.size() > 32 or settings.transitions.size() > 496: return Catalog.fail("profile_invalid")
	var available := {}; var selected := {}; var pairs := {}
	for instance: Dictionary in instances: available[instance.instance_id] = true
	for entry: Variant in settings.instances:
		Schema._shape(entry,{"instance_id":"id","profile_id":"id"},"border_instance",errors)
		if not errors.is_empty() or not available.has(entry.instance_id) or selected.has(entry.instance_id): return Catalog.fail("profile_invalid")
		selected[entry.instance_id] = true
	for entry: Variant in settings.transitions:
		Schema._shape(entry,{"a_instance":"id","b_instance":"id","profile_id":"id"},"border_transition",errors)
		if not errors.is_empty() or entry.a_instance == entry.b_instance or not available.has(entry.a_instance) or not available.has(entry.b_instance): return Catalog.fail("profile_invalid")
		var pair: Array = [entry.a_instance,entry.b_instance]; pair.sort()
		var key := Canonical.digest(pair)
		if pairs.has(key): return Catalog.fail("profile_invalid")
		pairs[key] = true
	return {"ok":true}

static func normalized(settings: Dictionary) -> Dictionary:
	var copy := settings.duplicate(true)
	copy.instances.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	for entry: Dictionary in copy.transitions:
		if entry.a_instance > entry.b_instance:
			var previous: String = entry.a_instance; entry.a_instance = entry.b_instance; entry.b_instance = previous
	copy.transitions.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.a_instance < b.a_instance or (a.a_instance == b.a_instance and a.b_instance < b.b_instance))
	return copy

static func apply(source: Dictionary, command: Dictionary) -> Dictionary:
	var copy := source.duplicate(true); var settings: Dictionary = copy.get("borders",empty()).duplicate(true)
	var errors: Array = []
	match command.get("operation"):
		"set_instance_profile":
			Schema._shape(command,{"operation":"id","instance_id":"id","profile_id":"id"},"border_command",errors)
			if not errors.is_empty(): return Catalog.fail("profile_invalid")
			settings.instances = settings.instances.filter(func(entry: Dictionary) -> bool: return entry.instance_id != command.instance_id)
			settings.instances.append({"instance_id":command.instance_id,"profile_id":command.profile_id})
		"clear_instance_profile":
			Schema._shape(command,{"operation":"id","instance_id":"id"},"border_command",errors)
			if not errors.is_empty() or not source.instances.any(func(entry: Dictionary) -> bool: return entry.instance_id == command.instance_id): return Catalog.fail("profile_invalid")
			settings.instances = settings.instances.filter(func(entry: Dictionary) -> bool: return entry.instance_id != command.instance_id)
		"set_transition":
			Schema._shape(command,{"operation":"id","a_instance":"id","b_instance":"id","profile_id":"id"},"border_command",errors)
			if not errors.is_empty(): return Catalog.fail("profile_invalid")
			settings.transitions = settings.transitions.filter(func(entry: Dictionary) -> bool: return not (entry.a_instance in [command.a_instance,command.b_instance] and entry.b_instance in [command.a_instance,command.b_instance]))
			settings.transitions.append({"a_instance":command.a_instance,"b_instance":command.b_instance,"profile_id":command.profile_id})
		"set_decorations":
			Schema._shape(command,{"operation":"id","enabled":"bool"},"border_command",errors)
			if not errors.is_empty(): return Catalog.fail("profile_invalid")
			settings.decorations = command.enabled
		_:
			return Catalog.fail("profile_invalid")
	var checked := validate(settings,source.instances)
	if not checked.ok: return checked
	copy["borders"] = normalized(settings)
	return {"ok":true,"data":copy,"diff":_diff(source,copy.borders)}

static func apply_batch(source: Dictionary, commands: Array) -> Dictionary:
	if commands.is_empty() or commands.size() > MAX_COMMANDS: return Catalog.fail("profile_invalid")
	var working := source.duplicate(true)
	for command: Variant in commands:
		if not command is Dictionary: return Catalog.fail("profile_invalid")
		var proposed := apply(working,command)
		if not proposed.ok: return proposed
		working = proposed.data
	return {"ok":true,"data":working,"diff":_diff(source,working.borders),"command_count":commands.size()}

static func _diff(source: Dictionary, settings: Dictionary) -> Dictionary:
	var before: Variant = source.get("borders",null)
	return {"before":before.duplicate(true) if before is Dictionary else before,"after":settings.duplicate(true)}

static func remove_references(source: Dictionary, instance_id: String) -> Dictionary:
	var copy := source.duplicate(true)
	if copy.has("borders"):
		copy.borders.instances = copy.borders.instances.filter(func(entry: Dictionary) -> bool: return entry.instance_id != instance_id)
		copy.borders.transitions = copy.borders.transitions.filter(func(entry: Dictionary) -> bool: return instance_id not in [entry.a_instance,entry.b_instance])
	return copy
