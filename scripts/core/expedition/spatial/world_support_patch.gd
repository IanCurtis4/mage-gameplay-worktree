extends RefCounted
## Exact local support union. Triangle seams are openings, not clearance walls.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const HeightGrid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const EPS := 0.00001

static func index(stage: Dictionary) -> Dictionary:
	var cells: Dictionary = {}; var ports: Dictionary = {}; var by_surface: Dictionary = {}; var links: Dictionary = {}; var transitions: Dictionary = {}
	# F10 H2: stretch cells keep a grid view; their steep triangles are closed
	# boundaries inside the outline (see _closed).
	var grids: Dictionary = {}
	for cell: Dictionary in stage.get("surfaces",[]):
		cells[cell.surface_id] = cell; by_surface[cell.surface_id] = []
		if cell.has("height_grid"): grids[cell.surface_id] = HeightGrid.index(HeightGrid.view(cell.height_grid))
	for port: Dictionary in stage.get("connectors",[]):
		ports[port.connector_id] = port
		if by_surface.has(port.surface_id): by_surface[port.surface_id].append(port)
	for link: Dictionary in stage.get("connections",[]):
		if not link.forward and not link.backward: continue
		for pair: Array in [[link.a_connector,link.b_connector],[link.b_connector,link.a_connector]]:
			if not ports.has(pair[0]) or not ports.has(pair[1]): continue
			var a: Dictionary = ports[pair[0]]; var b: Dictionary = ports[pair[1]]
			if Vector3(a.position).distance_to(b.position) > EPS or Vector3(a.outward).dot(b.outward) > -1.0+EPS: continue
			if not links.has(pair[0]): links[pair[0]] = []
			links[pair[0]].append(ports[pair[1]])
			if not transitions.has(pair[0]): transitions[pair[0]] = []
			transitions[pair[0]].append({"other_id":pair[1],"allowed":link.forward if pair[0] == link.a_connector else link.backward,"connection_id":link.connection_id})
	var outlines: Dictionary = {}; var orientations: Dictionary = {}
	for id: String in cells:
		var cell: Dictionary = cells[id]; var edges: Array = []
		for k: int in cell.vertices.size():
			var va: Vector3 = cell.vertices[k]; var vb: Vector3 = cell.vertices[(k+1)%cell.vertices.size()]
			var a := Vector2(va.x,va.z); var b := Vector2(vb.x,vb.z)
			var dx := float(b.x)-float(a.x); var dz := float(b.y)-float(a.y)
			var length := sqrt(dx*dx+dz*dz); var ax := dx/length; var az := dz/length; var openings: Array = []
			for port: Dictionary in by_surface[id]:
				var center := Vector2(port.position.x,port.position.z)
				var normal := Vector2(port.outward.x,port.outward.z)
				var cross := (float(center.y)-float(a.y))*ax-(float(center.x)-float(a.x))*az
				if absf(cross) > EPS+Kernel.horizontal_roundoff(-az,ax,port.position) or absf(float(normal.x)*ax+float(normal.y)*az) > EPS: continue
				for other: Dictionary in links.get(port.connector_id,[]):
					if not cells.has(other.surface_id) or other.kind != port.kind: continue
					var half := minf(float(port.width),float(other.width))*0.5
					var t := (float(center.x)-float(a.x))*ax+(float(center.y)-float(a.y))*az
					var low := clampf(t-half,0,length); var high := clampf(t+half,0,length)
					var tolerance := EPS+Kernel.horizontal_roundoff(ax,az,port.position)
					if low <= tolerance: low = 0
					if length-high <= tolerance: high = length
					if high <= low: continue
					openings.append({"connector_id":port.connector_id,"lo":low,"hi":high,"a":_along(a,b,low,length),"b":_along(a,b,high,length),"neighbor":other.surface_id,"headroom":minf(float(port.headroom),minf(float(other.headroom),float(cells[other.surface_id].headroom)))})
			openings.sort_custom(func(x: Dictionary,y: Dictionary) -> bool: return x.lo < y.lo)
			edges.append({"a":a,"b":b,"ax":ax,"az":az,"length":length,"openings":openings})
		outlines[id] = edges
		orientations[id] = -signf(Kernel._plane(cell.vertices)[1])
	return {"cells":cells,"ports":by_surface,"endpoints":ports,"transitions":transitions,"outlines":outlines,"orientations":orientations,"grids":grids}

static func on_opening(surface_id: String, connector_id: String, point: Vector3, data: Dictionary) -> bool:
	for edge: Dictionary in data.outlines.get(surface_id,[]):
		var x := float(point.x)-float(Vector2(edge.a).x); var z := float(point.z)-float(Vector2(edge.a).y)
		if absf(z*float(edge.ax)-x*float(edge.az)) > EPS+Kernel.horizontal_roundoff(-float(edge.az),float(edge.ax),point): continue
		var along := x*float(edge.ax)+z*float(edge.az)
		var tolerance := EPS+Kernel.horizontal_roundoff(float(edge.ax),float(edge.az),point)
		for opening: Dictionary in edge.openings:
			if opening.connector_id == connector_id and along >= opening.lo-tolerance and along <= opening.hi+tolerance: return true
	return false

static func _along(a: Vector2, b: Vector2, at: float, length: float) -> Vector2:
	if at <= EPS: return a
	if length-at <= EPS: return b
	return a.lerp(b,at/length)

static func _patch(id: String, from: Vector2, to: Vector2, radius: float, height: float, data: Dictionary) -> Dictionary:
	var included := {id:true}; var queue: Array[String] = [id]; var cursor := 0
	# A convex support contains the entire swept disk when it contains both
	# endpoint disks. Neighbor caps cannot touch that interior capsule.
	if _disk_within(id,from,radius,data,true) and _disk_within(id,to,radius,data,true): return included
	while cursor < queue.size():
		var current := queue[cursor]; cursor += 1
		for edge: Dictionary in data.outlines[current]:
			for opening: Dictionary in edge.openings:
				if included.has(opening.neighbor) or opening.headroom+EPS < height: continue
				if segment_distance_squared(from,to,opening.a,opening.b) > (radius+EPS)*(radius+EPS): continue
				included[opening.neighbor] = true; queue.append(opening.neighbor)
	return included

static func _disk_within(id: String, point: Vector2, radius: float, data: Dictionary, strict: bool = false) -> bool:
	for edge: Dictionary in data.outlines[id]:
		var x := float(point.x)-float(Vector2(edge.a).x); var z := float(point.y)-float(Vector2(edge.a).y)
		var distance := (z*float(edge.ax)-x*float(edge.az))*float(data.orientations[id])
		if strict and distance-radius <= EPS: return false
		if distance+EPS < radius: return false
	return true

static func members(id: String, from: Vector2, to: Vector2, radius: float, height: float, data: Dictionary) -> Dictionary:
	return _patch(id,from,to,radius,height,data)

static func _closed(patch: Dictionary, height: float, data: Dictionary, low: Vector2 = Vector2(-INF,-INF), high: Vector2 = Vector2(INF,INF), near: Array = []) -> Array:
	var result: Array = []
	for id: String in patch:
		# F10 H6: for a capsule, only the steep edges within its reach.
		if data.has("grids") and data.grids.has(id): result.append_array(HeightGrid.steep_edges_in(data.grids[id],low,high) if near.is_empty() else HeightGrid.steep_edges_near(data.grids[id],near[0],near[1],near[2]))
		for edge: Dictionary in data.outlines[id]:
			var at := 0.0
			for opening: Dictionary in edge.openings:
				if opening.headroom+EPS < height or not patch.has(opening.neighbor): continue
				if opening.lo > at+EPS: result.append([_along(edge.a,edge.b,at,edge.length),_along(edge.a,edge.b,opening.lo,edge.length)])
				at = maxf(at,opening.hi)
			if edge.length > at+EPS: result.append([_along(edge.a,edge.b,at,edge.length),edge.b])
	return result

static func contains(cell: Dictionary, position: Vector3, radius: float, height: float, data: Dictionary) -> bool:
	if not Kernel.contains(cell,position) or float(cell.headroom)+EPS < height: return false
	if Kernel.contains(cell,position,radius): return true
	var point := Vector2(position.x,position.z)
	var patch := _patch(cell.surface_id,point,point,radius,height,data)
	var clearance := maxf(0,radius-EPS)
	for edge: Array in _closed(patch,height,data,point-Vector2(radius,radius),point+Vector2(radius,radius)):
		if point_distance_squared(point,edge[0],edge[1]) < clearance*clearance: return false
	return true

static func fraction(cell: Dictionary, from: Vector3, to: Vector3, profile: Dictionary, data: Dictionary) -> float:
	return _fraction_prepared(cell,from,to,profile,data,{})

# One ordered segment can reuse the exact members already computed by its sweep.
# This private preparation is never accepted from a public witness/certificate.
static func _fraction_prepared(cell: Dictionary, from: Vector3, to: Vector3, profile: Dictionary, data: Dictionary, members: Dictionary) -> float:
	if not Kernel.contains(cell,from) or not Kernel.contains(cell,to): return 0.0
	var a := Vector2(from.x,from.z); var b := Vector2(to.x,to.z)
	var radius := float(profile.radius); var height := float(profile.height)
	if float(cell.headroom)+EPS < height: return 0.0
	var gridded: bool = data.has("grids") and data.grids.has(cell.surface_id)
	if _disk_within(cell.surface_id,a,radius,data) and _disk_within(cell.surface_id,b,radius,data) and (not gridded or HeightGrid.segment_clear(data.grids[cell.surface_id],a,b,radius,true)): return 1.0
	var patch := members if not members.is_empty() else _patch(cell.surface_id,a,b,radius,height,data)
	var clearance := maxf(0,radius-EPS); var first := 1.0
	var reach := Vector2(radius,radius)
	for edge: Array in _closed(patch,height,data,Vector2(minf(a.x,b.x),minf(a.y,b.y))-reach,Vector2(maxf(a.x,b.x),maxf(a.y,b.y))+reach,[a,b,radius]):
		if segment_distance_squared(a,b,edge[0],edge[1]) >= clearance*clearance: continue
		first = minf(first,_capsule_fraction(a,b,edge[0],edge[1],clearance))
	return first

static func point_distance_squared(p: Vector2, a: Vector2, b: Vector2) -> float:
	# Scalar math avoids an extra f32 rounding at large world coordinates.
	var dx: float = float(b.x)-float(a.x); var dz: float = float(b.y)-float(a.y)
	var px: float = float(p.x)-float(a.x); var pz: float = float(p.y)-float(a.y)
	var length := dx*dx+dz*dz
	var t := clampf((px*dx+pz*dz)/length,0,1) if length > 0 else 0.0
	return (px-dx*t)*(px-dx*t)+(pz-dz*t)*(pz-dz*t)

static func segment_distance_squared(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	var ux: float = float(b.x)-float(a.x); var uz: float = float(b.y)-float(a.y)
	var vx: float = float(d.x)-float(c.x); var vz: float = float(d.y)-float(c.y)
	var wx: float = float(c.x)-float(a.x); var wz: float = float(c.y)-float(a.y)
	var cross := ux*vz-uz*vx
	if cross != 0.0:
		var s := (wx*vz-wz*vx)/cross; var t := (wx*uz-wz*ux)/cross
		if s >= 0 and s <= 1 and t >= 0 and t <= 1: return 0.0
	return minf(minf(point_distance_squared(a,c,d),point_distance_squared(b,c,d)),minf(point_distance_squared(c,a,b),point_distance_squared(d,a,b)))

static func _circle_fraction(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	var dx: float = float(to.x)-float(from.x); var dz: float = float(to.y)-float(from.y)
	var px: float = float(from.x)-float(center.x); var pz: float = float(from.y)-float(center.y)
	var c := px*px+pz*pz-radius*radius
	if c <= 0: return 0.0
	var a := dx*dx+dz*dz; var b := 2.0*(px*dx+pz*dz)
	if a == 0: return 1.0
	var discriminant := b*b-4.0*a*c
	if discriminant < 0: return 1.0
	var at := (-b-sqrt(discriminant))/(2.0*a)
	return at if at >= 0 and at <= 1 else 1.0

static func _capsule_fraction(from: Vector2, to: Vector2, a: Vector2, b: Vector2, radius: float) -> float:
	var first := minf(_circle_fraction(from,to,a,radius),_circle_fraction(from,to,b,radius))
	var ex: float = float(b.x)-float(a.x); var ez: float = float(b.y)-float(a.y)
	var length := sqrt(ex*ex+ez*ez)
	if length == 0: return first
	ex /= length; ez /= length
	var px: float = float(from.x)-float(a.x); var pz: float = float(from.y)-float(a.y)
	var dx: float = float(to.x)-float(from.x); var dz: float = float(to.y)-float(from.y)
	var lo := 0.0; var hi := 1.0
	for slab: Array in [[px*ex+pz*ez,dx*ex+dz*ez,0.0,length],[-px*ez+pz*ex,-dx*ez+dz*ex,-radius,radius]]:
		if absf(slab[1]) < 1e-15:
			if slab[0] < slab[2] or slab[0] > slab[3]: return first
			continue
		var enter: float = (slab[2]-slab[0])/slab[1]; var exit: float = (slab[3]-slab[0])/slab[1]
		lo = maxf(lo,minf(enter,exit)); hi = minf(hi,maxf(enter,exit))
		if lo > hi: return first
	return minf(first,lo)
