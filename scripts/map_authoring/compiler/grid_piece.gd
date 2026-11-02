@tool
extends RefCounted
## F10 H4 (contracts/f10_height_grid.md): the terrain of a piece whose ground
## layer declares `surface_mode: "height_grid"`. The layer is cut into stretches
## of up to 16x16 quads; each stretch is one support surface carrying its slice
## of the height grid. Neighbouring stretches are joined by seam connectors over
## their shared open spans; the layer outline yields boundaries (walkable runs
## are profile edges, steep ones terrain edges) and exposed sides down to the
## layer's mass base, like an exact-plane layer. Pure and deterministic: the
## compiler and the package validator build the same records from the layer.
const HeightGrid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Topology = preload("res://scripts/map_authoring/compiler/terrain_topology.gd")
const MODE := "height_grid"
const REVISION := "height_grid_v1"
const CHUNK := 16
const HEADROOM := 100.0
const MAX_STRETCHES := 1024

static func uses_grid(source: Dictionary) -> bool:
	for layer: Variant in source.get("layers",[]):
		if layer is Dictionary and layer.get("surface_mode","exact_planes") == MODE: return true
	return false

static func stretch_id(layer_id: String, cx: int, cz: int) -> String:
	return "g_"+layer_id.sha256_text().substr(0,16)+"_%d_%d"%[cx,cz]

## The stretches of one layer, row-major by chunk.
static func stretches(layer: Dictionary) -> Array:
	var columns := int(layer.columns); var qx := columns-1; var qz := int(layer.rows)-1
	var s := float(layer.sample_spacing)
	var result: Array = []
	for cz: int in range(0,qz,CHUNK):
		for cx: int in range(0,qx,CHUNK):
			var w := mini(CHUNK,qx-cx); var h := mini(CHUNK,qz-cz)
			var heights: Array = []
			for z: int in range(cz,cz+h+1):
				for x: int in range(cx,cx+w+1): heights.append(float(layer.heights[z*columns+x]))
			var grid := {"origin_xz":[float(layer.origin_xz[0])+float(cx)*s,float(layer.origin_xz[1])+float(cz)*s],"sample_spacing":s,"columns":w+1,"rows":h+1,"heights":heights}
			result.append({"id":stretch_id(layer.layer_id,cx,cz),"cx":cx,"cz":cz,"grid":grid})
	return result

## Support cells, visuals, seam connectors and joins, outline boundaries and
## exposed sides of one height-grid layer.
static func build(layer: Dictionary, cancellation: Callable = Callable()) -> Dictionary:
	var parts := stretches(layer)
	if parts.size() > MAX_STRETCHES: return {"ok":false,"code":"terrain_limit_exceeded"}
	var base := INF
	for value: Variant in layer.heights: base = minf(base,float(value))
	base -= 4.0
	var by_chunk := {}
	for part: Dictionary in parts: by_chunk[Vector2i(part.cx,part.cz)] = part
	var cells: Array = []; var visuals: Array = []; var connectors: Array = []; var joins: Array = []; var boundaries: Array = []; var sides: Array = []
	var qx := int(layer.columns)-1; var qz := int(layer.rows)-1
	for part: Dictionary in parts:
		if cancellation.is_valid() and cancellation.call(): return {"ok":false,"code":"cancelled"}
		var view := HeightGrid.view(part.grid)
		var corners := HeightGrid.corners(view)
		cells.append({"surface_id":part.id,"headroom":HEADROOM,"vertices":corners,"height_grid":part.grid})
		visuals.append({"face_id":part.id,"surface_id":part.id,"source_id":layer.layer_id,"vertices":corners.duplicate(),"earth_weights":[],"material_weights":[],"special":false,"headroom":HEADROOM,"walkable":true,"bottom_y":base})
		# Seams to the next stretch along x (side 1) and along z (side 2).
		for side: int in [1,2]:
			var next := Vector2i(part.cx+CHUNK,part.cz) if side == 1 else Vector2i(part.cx,part.cz+CHUNK)
			if not by_chunk.has(next): continue
			var other: Dictionary = by_chunk[next]
			var spans := HeightGrid.shared_spans(view,side,HeightGrid.view(other.grid))
			for k: int in spans.size():
				var a: Vector3 = spans[k].a; var b: Vector3 = spans[k].b
				var middle := (a+b)*0.5; middle.y = HeightGrid.support_y_clamped(view,middle.x,middle.z)
				var key := Canonical.digest([part.id,other.id,side,a,b]).substr(0,20)
				var width := Vector2(b.x-a.x,b.z-a.z).length()
				var pa := {"connector_id":"j_ga_"+key,"surface_id":part.id,"position":middle,"outward":HeightGrid.side_outward(side),"kind":"walk","tags":["map_editor"],"width":width,"headroom":HEADROOM,"direction":"both"}
				var pb := {"connector_id":"j_gb_"+key,"surface_id":other.id,"position":middle,"outward":-HeightGrid.side_outward(side),"kind":"walk","tags":["map_editor"],"width":width,"headroom":HEADROOM,"direction":"both"}
				connectors.append(pa); connectors.append(pb)
				joins.append({"connection_id":"join_g_"+key,"a_connector":pa.connector_id,"b_connector":pb.connector_id,"forward":true,"backward":true})
		# Outline of the layer: boundaries in runs of one walkability, sides per segment.
		for side: int in 4:
			var on_outline: bool = (side == 0 and part.cz == 0) or (side == 1 and part.cx+CHUNK >= qx) or (side == 2 and part.cz+CHUNK >= qz) or (side == 3 and part.cx == 0)
			if on_outline: _outline(view,part.id,layer.layer_id,side,base,boundaries,sides)
	if sides.size() > Topology.MAX_SIDES: return {"ok":false,"code":"terrain_side_limit"}
	return {"ok":true,"cells":cells,"visuals":visuals,"connectors":connectors,"adjacency":joins,"boundaries":boundaries,"exposed_sides":sides,"base_y":base}

## Sample points along one side in counter-clockwise order (outward on the right).
static func _side_points(view: Dictionary, side: int) -> Array:
	var points: Array = []
	var count := int(view.qx) if side % 2 == 0 else int(view.qz)
	for k: int in count+1:
		match side:
			0: points.append(HeightGrid.point(view,k,0))
			1: points.append(HeightGrid.point(view,int(view.qx),k))
			2: points.append(HeightGrid.point(view,int(view.qx)-k,int(view.qz)))
			3: points.append(HeightGrid.point(view,0,int(view.qz)-k))
	return points

## Inner triangle of segment k (in the order of _side_points).
static func _segment_walkable(view: Dictionary, side: int, k: int) -> bool:
	var qx := int(view.qx); var qz := int(view.qz)
	match side:
		0: return HeightGrid.triangle_walkable(view,(0*qx+k)*2)
		1: return HeightGrid.triangle_walkable(view,(k*qx+qx-1)*2)
		2: return HeightGrid.triangle_walkable(view,((qz-1)*qx+(qx-1-k))*2+1)
	return HeightGrid.triangle_walkable(view,((qz-1-k)*qx)*2+1)

static func _outline(view: Dictionary, id: String, layer_id: String, side: int, base: float, boundaries: Array, sides: Array) -> void:
	var points := _side_points(view,side)
	var outward := HeightGrid.side_outward(side)
	var run_start := 0
	for k: int in points.size()-1:
		var walkable := _segment_walkable(view,side,k)
		var edge := {"span_id":"gs_"+Canonical.digest([id,side,k]).substr(0,20),"face_id":id,"source_id":layer_id,"walkable":walkable,"a":points[k],"b":points[k+1],"outward":outward}
		var a: Vector3 = points[k]; var b: Vector3 = points[k+1]
		Topology.skin(sides,edge,a,b,Vector3(a.x,base,a.z),Vector3(b.x,base,b.z),"external")
		var last := k == points.size()-2
		if last or _segment_walkable(view,side,k+1) != walkable:
			var run := {"span_id":"gb_"+Canonical.digest([id,side,run_start,k+1]).substr(0,20),"face_id":id,"source_id":layer_id,"walkable":walkable,"a":points[run_start],"b":points[k+1],"outward":outward}
			boundaries.append(Topology.boundary(run,"profile" if walkable else "terrain"))
			run_start = k+1

## The same stretch moved by an instance: translation and a half turn keep the
## renderer's diagonal; a quarter turn would flip it and is refused upstream.
static func transformed(grid: Dictionary, quarter: int, offset: Vector3) -> Dictionary:
	var columns := int(grid.columns); var rows := int(grid.rows); var s := float(grid.sample_spacing)
	var heights: Array = []
	var origin := [float(grid.origin_xz[0])+offset.x,float(grid.origin_xz[1])+offset.z]
	if posmod(quarter,4) == 2:
		origin = [-(float(grid.origin_xz[0])+float(columns-1)*s)+offset.x,-(float(grid.origin_xz[1])+float(rows-1)*s)+offset.z]
		for j: int in rows:
			for i: int in columns: heights.append(float(grid.heights[(rows-1-j)*columns+(columns-1-i)])+offset.y)
	else:
		for value: Variant in grid.heights: heights.append(float(value)+offset.y)
	return {"origin_xz":origin,"sample_spacing":s,"columns":columns,"rows":rows,"heights":heights}
