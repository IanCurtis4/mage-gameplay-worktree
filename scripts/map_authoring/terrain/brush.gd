@tool
extends RefCounted
## A stroke is a distance field over a polyline, applied once to a frozen source.
## Extra collinear pointer events and repeated events cannot accumulate strength.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")

static func stroke(source: Dictionary, layer_id: String, points: Array, options: Dictionary, preview_only: bool = false) -> Dictionary:
	if points.size() > 4096: return Schema.result(false, "brush_limit_exceeded")
	# UI previews receive structurally checked session snapshots; still validate semantics.
	var read := {"ok":true,"valid":Schema.validate(source).is_empty(),"data":source.duplicate(true),"output_hash":""} if preview_only else Schema.read(JSON.stringify(source, "", true, true).to_utf8_buffer())
	if not read.ok or not read.valid: return Schema.result(false, "source_invalid")
	var data: Dictionary = read.data
	var selected: Dictionary = {}
	for layer: Dictionary in data.layers:
		if layer.layer_id == layer_id: selected = layer
	if selected.is_empty(): return Schema.result(false, "source_reference_missing")
	if selected.locked: return Schema.result(false, "layer_locked")
	var mode: String = options.get("mode", "raise")
	var radius: float = options.get("radius", 32.0)
	var strength: float = options.get("strength", 8.0)
	var hardness: float = options.get("hardness", 0.5)
	if mode not in ["raise", "lower", "flatten", "smooth", "material", "ramp", "rounded_hill"] or not is_finite(radius) or radius <= 0 or not is_finite(strength) or strength < 0 or not is_finite(hardness) or hardness < 0 or hardness > 1 or points.is_empty(): return Schema.result(false, "brush_invalid")
	for point: Variant in points:
		if not point is Vector2 or not point.is_finite(): return Schema.result(false, "brush_invalid")
	if options.get("shape", "circle") not in ["circle", "square"]: return Schema.result(false, "brush_invalid")
	var target: float = options.get("target", 0.0)
	var end_height: float = options.get("end_height", target)
	if not is_finite(target) or not is_finite(end_height): return Schema.result(false, "brush_invalid")
	if mode == "ramp" and (points.size() != 2 or points[0].distance_to(points[1]) < 0.00001): return Schema.result(false, "brush_invalid")
	var original: Array = selected.heights.duplicate()
	var material: String = options.get("material", "earth")
	if mode == "material":
		if material not in Materials.IDS: return Schema.result(false, "material_unsupported")
		for id: String in selected.material_masks:
			if id not in Materials.IDS: return Schema.result(false, "material_unsupported")
	var changed := 0
	var bounds := Rect2(points[0],Vector2.ZERO)
	for point: Vector2 in points: bounds = bounds.expand(point)
	bounds = bounds.grow(radius)
	var origin := Vector2(selected.origin_xz[0],selected.origin_xz[1])
	var min_x := clampi(floori((bounds.position.x-origin.x)/selected.sample_spacing),0,int(selected.columns)-1)
	var max_x := clampi(ceili((bounds.end.x-origin.x)/selected.sample_spacing),0,int(selected.columns)-1)
	var min_z := clampi(floori((bounds.position.y-origin.y)/selected.sample_spacing),0,int(selected.rows)-1)
	var max_z := clampi(ceili((bounds.end.y-origin.y)/selected.sample_spacing),0,int(selected.rows)-1)
	for z: int in range(min_z,max_z+1):
		for x: int in range(min_x,max_x+1):
			var index: int = z * int(selected.columns) + x
			var at := Vector2(selected.origin_xz[0], selected.origin_xz[1]) + Vector2(x,z) * float(selected.sample_spacing)
			if protected(data, selected, at): continue
			var distance := INF
			if points.size() == 1: distance = _distance(at - points[0], options.get("shape", "circle"))
			else:
				for i: int in range(1, points.size()):
					var nearest := Geometry2D.get_closest_point_to_segment(at, points[i-1], points[i])
					distance = minf(distance, _distance(at-nearest, options.get("shape", "circle")))
			if distance > radius: continue
			var weight := 1.0 if distance <= radius*hardness or hardness == 1.0 else (radius-distance)/(radius*(1.0-hardness))
			if mode == "rounded_hill":
				# A smooth radial shoulder, with optional flat core controlled by hardness.
				var u := 0.0 if hardness == 1.0 else clampf((distance / radius - hardness) / (1.0 - hardness), 0.0, 1.0)
				weight = pow(1.0 - u * u, 3.0)
			if weight <= 0: continue
			var value: float = original[index]
			match mode:
				"raise", "rounded_hill": value += strength * weight
				"lower": value -= strength * weight
				"flatten": value = lerpf(value, target, minf(strength, 1.0)*weight)
				"ramp":
					var a: Vector2 = points[0]; var b: Vector2 = points[1]
					var along := clampf((at-a).dot(b-a)/(b-a).length_squared(), 0.0, 1.0)
					value = lerpf(value, lerpf(target, end_height, along), minf(strength, 1.0)*weight)
				"smooth":
					var total := 0.0; var count := 0
					for nz: int in range(maxi(0,z-1), mini(int(selected.rows),z+2)):
						for nx: int in range(maxi(0,x-1), mini(int(selected.columns),x+2)):
							total += float(original[nz*int(selected.columns)+nx]); count += 1
					value = lerpf(value, total/count, minf(strength,1.0)*weight)
				"material":
					var previous: Array[float] = Materials.weights(selected,index)
					var alpha := minf(strength,1.0)*weight
					var next := previous.duplicate()
					var selected_index: int = Materials.IDS.find(material)
					for k: int in next.size(): next[k] = previous[k]*(1.0-alpha)+(alpha if k == selected_index else 0.0)
					if previous != next:
						for k: int in next.size():
							var id: String = Materials.IDS[k]
							var implicit := 1.0 if id == "grass" else 0.0
							if not selected.material_masks.has(id) and next[k] != implicit:
								var values: Array = []; values.resize(original.size()); values.fill(implicit)
								selected.material_masks[id] = values
							if selected.material_masks.has(id): selected.material_masks[id][index] = next[k]
						changed += 1
			if not is_finite(value): return Schema.result(false, "source_non_finite")
			if value != original[index]: changed += 1
			selected.heights[index] = value
	var output := Schema.result(true)
	output.data = data; output.changed = changed; output.input_hash = read.output_hash
	output.output_hash = "" if preview_only else Schema.semantic_hash(data)
	return output

static func _distance(delta: Vector2, shape: String) -> float:
	return maxf(absf(delta.x), absf(delta.y)) if shape == "square" else delta.length()

static func protected(data: Dictionary, layer: Dictionary, at: Vector2) -> bool:
	for region: Dictionary in data.regions:
		if region.region_id not in layer.protected_regions: continue
		var polygon := PackedVector2Array()
		for vertex: Array in region.polygon_xz: polygon.append(Vector2(vertex[0],vertex[1]))
		if Geometry2D.is_point_in_polygon(at, polygon): return true
	for connector: Dictionary in data.connectors:
		if connector.surface_id == layer.layer_id and at.distance_to(Vector2(connector.position_xyz[0],connector.position_xyz[2])) <= connector.width*0.5 + layer.sample_spacing: return true
	return false
