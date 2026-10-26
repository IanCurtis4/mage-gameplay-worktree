extends RefCounted
## Passive terrain mass: convex sloping cap over a horizontal base.
## The moving body's conservative envelope uses the same half-space authority.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const SupportPatch = preload("res://scripts/core/expedition/spatial/world_support_patch.gd")
const EPS := 0.00001
const FIELDS := ["volume_id","top","support_surface_id"]
const GRID_UNITS := 32.0
const MAX_ITEM_BUCKETS := 256

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != FIELDS.size()+1 or not data.has_all(FIELDS): return false
	if not data.volume_id is String or data.volume_id.is_empty() or not data.support_surface_id is String: return false
	var base := "bottom_y" if data.has("bottom_y") else "thickness_y" if data.has("thickness_y") else ""
	if base.is_empty() or not (data[base] is int or data[base] is float) or not is_finite(float(data[base])): return false
	if base == "thickness_y" and float(data[base]) <= EPS: return false
	if not data.top is Array or data.top.size() < 3 or data.top.size() > 8: return false
	for point: Variant in data.top:
		if not point is Vector3 or not point.is_finite(): return false
		if base == "bottom_y" and point.y <= float(data.bottom_y)+EPS: return false
	return Kernel.valid_cell({"vertices":data.top,"headroom":1.0})

static func transformed(data: Dictionary, quarter: int, offset: Vector3, volume_prefix: String = "", support_prefix: String = "") -> Dictionary:
	var result := data.duplicate(true)
	result.volume_id = volume_prefix+str(data.volume_id)
	result.support_surface_id = support_prefix+str(data.support_surface_id) if not str(data.support_surface_id).is_empty() else ""
	if data.has("bottom_y"): result.bottom_y = float(data.bottom_y)+float(offset.y)
	for index: int in result.top.size(): result.top[index] = Kernel.rotate(data.top[index],quarter)+offset
	return result

static func prepare(data: Dictionary) -> Dictionary:
	if not valid(data): return {}
	var top: Array = data.top
	var n := Kernel._plane(top)
	var length := sqrt(n[0]*n[0]+n[1]*n[1]+n[2]*n[2])
	var sign_value := 1.0 if n[1] > 0 else -1.0
	for axis: int in 3: n[axis] = n[axis]/length*sign_value
	var origin: Vector3 = top[0]
	var cap := PackedFloat64Array([n[0],n[1],n[2],n[0]*float(origin.x)+n[1]*float(origin.y)+n[2]*float(origin.z)])
	var bottom := PackedFloat64Array([0,-1,0,-float(data.bottom_y)]) if data.has("bottom_y") else PackedFloat64Array([-n[0],-n[1],-n[2],-cap[3]+n[1]*float(data.thickness_y)])
	var planes: Array[PackedFloat64Array] = [cap,bottom]
	var area := 0.0
	for k: int in top.size():
		var a: Vector3 = top[k]; var b: Vector3 = top[(k+1)%top.size()]
		area += float(a.x)*float(b.z)-float(b.x)*float(a.z)
	for k: int in top.size():
		var a: Vector3 = top[k]; var b: Vector3 = top[(k+1)%top.size()]
		var ex := float(b.x)-float(a.x); var ez := float(b.z)-float(a.z)
		var edge_length := sqrt(ex*ex+ez*ez)
		var nx := ez/edge_length*signf(area); var nz := -ex/edge_length*signf(area)
		planes.append(PackedFloat64Array([nx,0,nz,nx*float(a.x)+nz*float(a.z)]))
	var bounds := AABB(origin,Vector3.ZERO)
	for p: Vector3 in top:
		var bottom_y: float = data.bottom_y if data.has("bottom_y") else float(p.y)-float(data.thickness_y)
		bounds = bounds.expand(p); bounds = bounds.expand(Vector3(p.x,bottom_y,p.z))
	return {"volume_id":data.volume_id,"support_surface_id":data.support_surface_id,"planes":planes,"bounds":bounds,"top":top.duplicate()}

static func above_cap(prepared: Dictionary, from: Vector3, to: Vector3) -> bool:
	var cap: PackedFloat64Array = prepared.planes[0]
	for point: Vector3 in [from,to]:
		var signed := cap[0]*float(point.x)+cap[1]*float(point.y)+cap[2]*float(point.z)-cap[3]
		if signed < -EPS-Kernel._support_roundoff(prepared.top,point): return false
	return true

static func blocking_polygon(prepared: Dictionary, cell: Dictionary, radius: float, height: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for vertex: Vector3 in cell.vertices: polygon.append(Vector2(vertex.x,vertex.z))
	var surface := Kernel._plane(cell.vertices); var origin: Vector3 = cell.vertices[0]
	var sx := surface[0]/surface[1]; var sz := surface[2]/surface[1]
	var intercept := float(origin.y)+sx*float(origin.x)+sz*float(origin.z)
	for plane: PackedFloat64Array in prepared.planes:
		var nx := plane[0]-plane[1]*sx; var nz := plane[2]-plane[1]*sz
		var bound := plane[3]+radius*sqrt(plane[0]*plane[0]+plane[2]*plane[2])+height*maxf(0,-plane[1])-EPS-plane[1]*intercept
		var clipped := PackedVector2Array()
		for index: int in polygon.size():
			var a := polygon[index]; var b := polygon[(index+1)%polygon.size()]
			var av := bound-nx*float(a.x)-nz*float(a.y); var bv := bound-nx*float(b.x)-nz*float(b.y)
			if av >= 0: clipped.append(a)
			if (av < 0) != (bv < 0): clipped.append(a.lerp(b,av/(av-bv)))
		polygon = clipped
		if polygon.size() < 3: return PackedVector2Array()
	return polygon

static func sweep(from: Vector3, to: Vector3, prepared: Dictionary, radius: float, height: float) -> Dictionary:
	if prepared.is_empty() or not from.is_finite() or not to.is_finite() or not is_finite(radius) or not is_finite(height) or radius < 0 or height < 0: return {}
	if Kernel.sweep_box(from,to,prepared.bounds,radius,height).is_empty(): return {}
	var enter := 0.0; var exit := 1.0; var normal := Vector3.ZERO
	var dx := float(to.x)-float(from.x); var dy := float(to.y)-float(from.y); var dz := float(to.z)-float(from.z)
	for plane: PackedFloat64Array in prepared.planes:
		var margin := radius*sqrt(plane[0]*plane[0]+plane[2]*plane[2])+height*maxf(0,-plane[1])-EPS
		var distance := plane[0]*float(from.x)+plane[1]*float(from.y)+plane[2]*float(from.z)-plane[3]-margin
		var speed := plane[0]*dx+plane[1]*dy+plane[2]*dz
		if absf(speed) <= 1e-15:
			if distance > 0: return {}
			continue
		var at := -distance/speed
		if speed < 0:
			if at > enter: enter = at; normal = Vector3(plane[0],plane[1],plane[2])
		else: exit = minf(exit,at)
		if enter > exit: return {}
	# Expanded face halfspaces overestimate rounded corners. Intersect with the
	# exact horizontal disk sweep as well: a body outside the cap's footprint
	# cannot hit its mass, including at a concave junction of several supports.
	if radius > 0:
		var a := Vector2(from.x,from.z); var b := Vector2(to.x,to.z)
		var clearance := maxf(0,radius-EPS)
		var first := _footprint_entry(a,b,prepared,clearance)
		if not is_finite(first): return {}
		enter = maxf(enter,first)
		exit = minf(exit,1.0-_footprint_entry(b,a,prepared,clearance))
		if enter > exit: return {}
	return {"fraction":enter,"normal":normal,"volume_id":prepared.volume_id} if exit >= 0 and enter <= 1 else {}

static func _footprint_entry(from: Vector2, to: Vector2, prepared: Dictionary, radius: float) -> float:
	var inside := true
	for k: int in range(2,prepared.planes.size()):
		var plane: PackedFloat64Array = prepared.planes[k]
		if plane[0]*float(from.x)+plane[2]*float(from.y) > plane[3]: inside = false; break
	if inside: return 0.0
	var first := INF
	for k: int in prepared.top.size():
		var va: Vector3 = prepared.top[k]; var vb: Vector3 = prepared.top[(k+1)%prepared.top.size()]
		var a := Vector2(va.x,va.z); var b := Vector2(vb.x,vb.z)
		if SupportPatch.segment_distance_squared(from,to,a,b) <= radius*radius:
			first = minf(first,SupportPatch._capsule_fraction(from,to,a,b,radius))
	return first

static func intersects_patch(prepared: Dictionary, polygon: PackedVector2Array, support: Dictionary, height: float) -> bool:
	# Clip the region extruded upward from its exact support plane against the mass.
	var clipped := polygon
	for plane: PackedFloat64Array in prepared.planes:
		var output := PackedVector2Array()
		for index: int in clipped.size():
			var a := clipped[index]; var b := clipped[(index+1)%clipped.size()]
			var ay := _height(support,a); var by := _height(support,b)
			var bound := plane[3]+height*maxf(0,-plane[1])-EPS
			var av := bound-plane[0]*float(a.x)-plane[1]*ay-plane[2]*float(a.y)
			var bv := bound-plane[0]*float(b.x)-plane[1]*by-plane[2]*float(b.y)
			if av >= 0: output.append(a)
			if (av < 0) != (bv < 0): output.append(a.lerp(b,av/(av-bv)))
		clipped = output
		if clipped.size() < 3: return false
	var area := 0.0
	for index: int in clipped.size(): area += clipped[index].cross(clipped[(index+1)%clipped.size()])
	return absf(area)*0.5 > EPS

static func _height(support: Dictionary, point: Vector2) -> float:
	var origin: Vector3 = support.origin; var n: Vector3 = support.normal
	return float(origin.y)-(float(n.x)*(float(point.x)-float(origin.x))+float(n.z)*(float(point.y)-float(origin.z)))/float(n.y)

static func _grid_range(x0: float, z0: float, x1: float, z1: float, budget: int) -> Array[int]:
	# Avoid integer conversion/huge allocation for a finite but extreme collider.
	if maxf(maxf(absf(x0),absf(z0)),maxf(absf(x1),absf(z1))) > 1e12: return []
	if ((x1-x0)/GRID_UNITS+2.0)*((z1-z0)/GRID_UNITS+2.0) > budget: return []
	return [floori(x0/GRID_UNITS),floori(z0/GRID_UNITS),floori(x1/GRID_UNITS),floori(z1/GRID_UNITS)]

static func spatial_index(items: Array) -> Dictionary:
	var buckets: Dictionary = {}; var global_items: Array[int] = []
	for index: int in items.size():
		var box: AABB = items[index].bounds
		var span := _grid_range(box.position.x,box.position.z,box.end.x,box.end.z,MAX_ITEM_BUCKETS)
		if span.is_empty(): global_items.append(index); continue
		for x: int in range(span[0],span[2]+1):
			for z: int in range(span[1],span[3]+1):
				var key := Vector2i(x,z)
				if not buckets.has(key): buckets[key] = []
				buckets[key].append(index)
	return {"buckets":buckets,"global_items":global_items}

static func spatial_candidates(items: Array, index: Dictionary, from: Vector3, to: Vector3, radius: float, height: float) -> Array:
	var span := _grid_range(minf(from.x,to.x)-radius,minf(from.z,to.z)-radius,maxf(from.x,to.x)+radius,maxf(from.z,to.z)+radius,maxi(1,index.buckets.size()))
	var selected: Dictionary = {}
	if span.is_empty():
		for id: int in items.size(): selected[id] = true
	else:
		for id: int in index.global_items: selected[id] = true
		for x: int in range(span[0],span[2]+1):
			for z: int in range(span[1],span[3]+1):
				for id: int in index.buckets.get(Vector2i(x,z),[]): selected[id] = true
	var result: Array = []; var ids: Array = selected.keys(); ids.sort()
	var low := minf(from.y,to.y)-EPS; var high := maxf(from.y,to.y)+height+EPS
	var min_x := minf(from.x,to.x)-radius-EPS; var max_x := maxf(from.x,to.x)+radius+EPS
	var min_z := minf(from.z,to.z)-radius-EPS; var max_z := maxf(from.z,to.z)+radius+EPS
	for id: int in ids:
		var box: AABB = items[id].bounds
		if float(box.end.y) < low or float(box.position.y) > high: continue
		if float(box.end.x) < min_x or float(box.position.x) > max_x or float(box.end.z) < min_z or float(box.position.z) > max_z: continue
		result.append(items[id])
	return result
