extends RefCounted
## Read-only presentation of already committed fields. Nodes live under the skin,
## outside the simulation snapshot graph and share its canvas order.
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")
const Order = preload("res://scripts/world/world_canvas_order.gd")
const Shadow = preload("res://scripts/world/ground_shadow.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
var entries: Dictionary = {}
var last_result: Dictionary = {"ok":true,"fields":0,"fragments":0}

class Fragment extends Node2D:
	var kind := ""
	var base := PackedVector2Array()
	var cap := PackedVector2Array()
	var faces: Array[PackedVector2Array] = []
	var height := 0.0
	var elapsed := 0.0
	var capacity := 6.0
	var seed_index := 0
	var receivers: Array[String] = []
	func _draw() -> void:
		if kind == "fire_wall":
			var flicker := sin(elapsed*13.0+seed_index*1.8)*0.08
			var h := height; var w := height*0.40
			draw_colored_polygon(PackedVector2Array([Vector2(-w*1.18,0),Vector2(-w*0.9,-h*0.38),Vector2(-w*0.2,-h*0.65),Vector2(w*0.14,-h*(1.04+flicker)),Vector2(w*0.85,-h*0.48),Vector2(w*1.18,0)]),Color(1,0.38,0.08,0.18))
			draw_colored_polygon(PackedVector2Array([Vector2(-w,0),Vector2(-w*1.1,-h*0.35),Vector2(-w*0.5,-h*0.68),Vector2(-w*0.2,-h*0.45),Vector2(w*0.12,-h*(0.92+flicker)),Vector2(w*0.6,-h*0.58),Vector2(w,0)]),Color(1,0.27,0.045,0.9))
			draw_colored_polygon(PackedVector2Array([Vector2(-w*0.5,0),Vector2(-w*0.22,-h*0.35),Vector2(w*0.15,-h*0.68),Vector2(w*0.5,0)]),Color(1,0.82,0.22,1))
			draw_colored_polygon(PackedVector2Array([Vector2(-w*0.19,0),Vector2(0,-h*0.28),Vector2(w*0.12,-h*0.42),Vector2(w*0.28,0)]),Color(1,0.96,0.68,0.9))
			return
		var tint: Color = {"lightning_wall":Color("f3d762"),"phantom_barrier":Color("b88af7"),"ice_wall":Color("9ae8ff")}[kind]
		if base.size() < 3: return
		draw_colored_polygon(base,Color(tint,0.12))
		for face: PackedVector2Array in faces: draw_colored_polygon(face,Color(tint,0.27 if kind == "ice_wall" else 0.09))
		draw_colored_polygon(cap,Color(tint,0.40 if kind == "ice_wall" else 0.08))
		var outline := cap.duplicate(); outline.append(cap[0]); draw_polyline(outline,Color(tint,0.75),1.2,true)
		if kind == "lightning_wall":
			var flash := sin(elapsed*19.0+seed_index)*3.0
			draw_polyline(PackedVector2Array([Vector2(-4,0),Vector2(3+flash,-height*0.34),Vector2(-4-flash,-height*0.58),Vector2(3,-height)]),Color("fff4b8"),2.1,true)
		elif kind == "phantom_barrier":
			var brightness := 0.35+clampf(capacity/6.0,0.0,1.0)*0.5
			draw_line(Vector2.ZERO,Vector2(0,-height),Color(tint,brightness),2.5,true)
			draw_circle(Vector2(0,-height*0.55),3.5,Color("eedaff"))
		else:
			draw_polyline(PackedVector2Array([Vector2(-3,0),Vector2(4,-height*0.5),Vector2(0,-height)]),Color("d7f8ff"),1.1,true)

static func current(node: Node, world: WorldGeometry) -> bool:
	if node.is_queued_for_deletion(): return false
	if node is IceWall: return node.world == world and node._world_configuration == world.configuration_revision and world._segments.has(node._world_id)
	return node.world_field != null and node.world_field.geometry == world and node.world_field.is_current()

static func describe(node: Node, world: WorldGeometry) -> Dictionary:
	if node.is_queued_for_deletion(): return {}
	if node is IceWall:
		if node.world != world or node._world_configuration != world.configuration_revision or not world._segments.has(node._world_id): return {}
		var data: Dictionary = world._segments[node._world_id].geometry_record()
		data["kind"] = "ice_wall"; return data
	if node is FireWall or node is LightningWall or node is PhantomBarrier:
		var field: WorldGroundField = node.world_field
		if field == null or field.geometry != world or not field.is_current(): return {}
		var data := field.describe(); data["kind"] = String(data.kind)
		data["axis"] = field._axis; data["support_region"] = field.volume._support_region.duplicate(true) if field.volume != null else {}
		data["centers"] = field._centers.map(func(point: ExpeditionWorldPoint) -> Dictionary: return point.to_data())
		return data
	return {}

static func capsule(anchor: Vector3, axis: Vector3, normal: Vector3, half_length: float, width: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	# Decorative tessellation of the captured capsule, never a collider.
	for end: float in [1.0,-1.0]:
		for index: int in 9:
			var angle := -PI*0.5+PI*float(index)/8.0
			var point := anchor+axis*(half_length*end+cos(angle)*width*end)+normal*(sin(angle)*width*end)
			result.append(Vector2(point.x,point.z))
	return result

static func fragment(kind: String, vertices: Array, anchor: Vector3, height: float, id: String, index: int) -> Fragment:
	var part := Fragment.new(); part.kind = kind; part.height = height; part.seed_index = index
	part.position = ProjectionMath.project(anchor)
	var all: Array = vertices.duplicate()
	for point: Vector3 in vertices:
		part.base.append(ProjectionMath.project(point)-part.position)
		part.cap.append(ProjectionMath.project(point+Vector3.UP*height)-part.position)
		all.append(point+Vector3.UP*height)
	for k: int in vertices.size():
		part.faces.append(PackedVector2Array([part.base[k],part.base[(k+1)%vertices.size()],part.cap[(k+1)%vertices.size()],part.cap[k]]))
	if kind == "fire_wall":
		all.append(anchor+Vector3(-height*0.5,height,0)); all.append(anchor+Vector3(height*0.5,height,0))
	part.set_meta("canvas_order_record",{"id":"field_"+id+"_"+str(index),"kind":"sprite","anchor":anchor,"bounds":Order._bounds(all),"screen":Order._screen(all)})
	part.set_meta("world_vertices",all.duplicate()); return part

static func build(data: Dictionary, world: WorldGeometry, id: String) -> Array[Fragment]:
	var result: Array[Fragment] = []
	var kind: String = data.kind; var height := float(data.height)
	if kind == "fire_wall":
		world._ensure_support_index()
		for center: Dictionary in data.centers:
			var anchor: Vector3 = center.position
			var ground := Shadow.mesh_data(anchor,Vector2.ONE*float(data.half_width),world._support_index,center.surface_id,ProjectionMath.project)
			var vertices: Array = ground.world_vertices if ground.ok else [anchor+Vector3(-data.half_width,0,-data.half_width),anchor+Vector3(data.half_width,0,data.half_width)]
			var part := fragment(kind,vertices,anchor,height,id,result.size()); part.receivers.assign(ground.receivers if ground.ok else [center.surface_id])
			if ground.ok:
				var glow := MeshInstance2D.new(); glow.mesh = Shadow.mesh(ground); glow.texture = glow_texture(); glow.modulate = Color(1,0.5,0.09,0.7); part.add_child(glow); glow.show_behind_parent = true
			result.append(part)
		return result
	var anchor: Vector3 = data.anchor.position; var axis: Vector3 = data.axis; var normal: Vector3 = data.normal
	var half_length := float(data.half_length); var half_width := float(data.half_width)
	var rounded: bool = kind in ["ice_wall","lightning_wall"]
	var extent := half_length+(half_width if rounded else 0.0)
	var full := capsule(anchor,axis,normal,half_length,half_width) if rounded else PackedVector2Array([Vector2(anchor.x,anchor.z)-Vector2(axis.x,axis.z)*extent-Vector2(normal.x,normal.z)*half_width,Vector2(anchor.x,anchor.z)+Vector2(axis.x,axis.z)*extent-Vector2(normal.x,normal.z)*half_width,Vector2(anchor.x,anchor.z)+Vector2(axis.x,axis.z)*extent+Vector2(normal.x,normal.z)*half_width,Vector2(anchor.x,anchor.z)-Vector2(axis.x,axis.z)*extent+Vector2(normal.x,normal.z)*half_width])
	var patches: Array = data.support_region.get("patches",[])
	if patches.is_empty(): patches = [{"surface_id":data.anchor.surface_id,"polygon":full,"origin":anchor,"normal":Vector3.UP}]
	var count := maxi(1,ceili(extent*2.0/30.0))
	for section: int in count:
		var a := -extent+extent*2.0*float(section)/count; var b := -extent+extent*2.0*float(section+1)/count
		var points := PackedVector2Array()
		for pair: Vector2 in [Vector2(a,-half_width),Vector2(b,-half_width),Vector2(b,half_width),Vector2(a,half_width)]:
			var point := anchor+axis*pair.x+normal*pair.y; points.append(Vector2(point.x,point.z))
		for clip: PackedVector2Array in Geometry2D.intersect_polygons(points,full):
			for patch: Dictionary in patches:
				for polygon: PackedVector2Array in Geometry2D.intersect_polygons(clip,patch.polygon):
					if polygon.size() < 3 or WorldSupportRegion.area(polygon) <= WorldGeometry.EPS: continue
					var vertices: Array = []; var center := Vector3.ZERO
					for point: Vector2 in polygon:
						var vertex := Vector3(point.x,WorldSupportRegion.support_y(patch,point),point.y); vertices.append(vertex); center += vertex
					center /= float(vertices.size())
					var part := fragment(kind,vertices,center,height,id,result.size()); part.receivers.append(patch.surface_id); result.append(part)
	return result

static var _glow: GradientTexture2D
static func glow_texture() -> GradientTexture2D:
	if _glow == null:
		var gradient := Gradient.new(); gradient.set_color(0,Color.WHITE); gradient.set_color(1,Color(1,1,1,0))
		_glow = GradientTexture2D.new(); _glow.gradient = gradient; _glow.width = 64; _glow.height = 64; _glow.fill = GradientTexture2D.FILL_RADIAL; _glow.fill_from = Vector2(0.5,0.5); _glow.fill_to = Vector2(1,0.5)
	return _glow

func sync(skin: Node2D, host: Node, world: WorldGeometry, hidden: Array[String] = []) -> Dictionary:
	var started := Time.get_ticks_usec(); var seen := {}; var fragments := 0; var created := 0; var removed := 0; var failures: Array[String] = []
	if is_instance_valid(host):
		for node: Node in host.get_children():
			if not (node is FireWall or node is LightningWall or node is PhantomBarrier or node is IceWall): continue
			if not current(node,world): continue
			var id := str(node.get_instance_id()); seen[id] = true
			if not entries.has(id):
				var parts := build(describe(node,world),world,id); created += parts.size(); entries[id] = {"owner":weakref(node),"parts":parts}
				for part: Fragment in parts: skin.add_child(part)
			if entries[id].parts.is_empty(): failures.append(id)
			for part: Fragment in entries[id].parts:
				var duration := FireWall.DURATION if node is FireWall else (LightningWall.DURATION if node is LightningWall else (PhantomBarrier.DURATION if node is PhantomBarrier else 0.0))
				part.elapsed = duration-float(node.remaining); part.capacity = float(node.remaining_capacity) if node is PhantomBarrier else 6.0
				part.modulate.a = minf(1.0,float(node.remaining)*2.0)
				part.visible = not part.receivers.all(func(receiver: String) -> bool: return receiver in hidden)
				part.queue_redraw(); fragments += 1
	for id: String in entries.keys():
		if seen.has(id): continue
		for part: Fragment in entries[id].parts:
			if is_instance_valid(part): part.free(); removed += 1
		entries.erase(id)
	last_result = {"ok":failures.is_empty(),"code":"" if failures.is_empty() else "field_presentation_empty","fields":seen.size(),"fragments":fragments,"created":created,"removed":removed,"failed_fields":failures,"elapsed_ms":float(Time.get_ticks_usec()-started)/1000.0}; return last_result

func clear() -> void:
	for entry: Dictionary in entries.values():
		for part: Fragment in entry.parts:
			if is_instance_valid(part): part.free()
	entries.clear()
