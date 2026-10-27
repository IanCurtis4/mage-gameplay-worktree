@tool
extends Control
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const WorldProjection = preload("res://scripts/world/expedition_geometry_view.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Partition = preload("res://scripts/map_authoring/compiler/terrain_partition.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const World = preload("res://scripts/core/expedition/spatial/world_geometry.gd")
const Motion = preload("res://scripts/core/expedition/spatial/world_actor_motion.gd")
const Point = preload("res://scripts/core/expedition/model/world_point.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_view.gd")
const CanvasOrder = preload("res://scripts/world/world_canvas_order.gd")
const GroundShadow = preload("res://scripts/world/ground_shadow.gd")
const TerrainTopology = preload("res://scripts/map_authoring/compiler/terrain_topology.gd")
const BorderCatalog = preload("res://scripts/map_authoring/composition/border_profile_catalog.gd")
signal selected(instance_id: String)
signal status(message: String)
var package: Dictionary = {}
var geometry: World
var motion: Motion
var testing := false
var contact_shadows_enabled := true
var selected_instance := ""
var selected_surface := ""
var _scale := 1.0
var _origin := Vector2.ZERO
var _meshes: Node2D
var _overlay: Node2D
var _object_sprites: Array[Sprite2D] = []
var _object_volumes: Array[AABB] = []
func _ready() -> void:
	custom_minimum_size = Vector2(600,360); size_flags_vertical = Control.SIZE_EXPAND_FILL; size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true; mouse_filter = Control.MOUSE_FILTER_STOP
	_meshes = Node2D.new(); add_child(_meshes)
	_overlay = Node2D.new(); _overlay.z_index = 4090; add_child(_overlay); _overlay.draw.connect(_draw_world)
	resized.connect(fit)
func clear() -> void:
	stop_test(); package = {}; geometry = null
	_object_sprites.clear(); _object_volumes.clear()
	if _meshes != null:
		for child: Node in _meshes.get_children(): child.free()
		for key: String in ["canvas_order_cache","canvas_order_bindings"]:
			if _meshes.has_meta(key): _meshes.remove_meta(key)
	redraw()
func set_package(value: Dictionary) -> void:
	if not Compiler.validate_package(value): status.emit("O pacote é inválido ou suas dependências mudaram."); return
	clear(); package = value.duplicate(true)
	geometry = World.new(); geometry.configure(Compiler.manifest(package),"map_preview"); geometry._ensure_support_index()
	var heights: Array = []
	for instance: Dictionary in package.render_instances:
		for layer: Dictionary in instance.layers:
			for height: float in layer.heights: heights.append(height+float(instance.translation.y))
		for visual: Dictionary in instance.visuals:
			for point: Vector3 in visual.vertices: heights.append(point.y+float(instance.translation.y))
		for object: Dictionary in instance.get("objects",[]): heights.append(object.position.y)
	for face: Dictionary in package.border_geometry.faces+package.border_geometry.water:
		for point: Vector3 in face.vertices: heights.append(point.y)
	for object: Dictionary in package.border_geometry.props: heights.append(object.position.y)
	var depth_domain := Objects.depth_domain(heights)
	for instance: Dictionary in package.render_instances:
		for layer: Dictionary in instance.layers:
			for region: Dictionary in Partition.build(layer):
				var arrays := Materials.arrays(layer,region,instance.rotation_quarters,instance.translation)
				var view := MeshInstance2D.new(); view.mesh = Materials.from_arrays(arrays); view.material = Materials.material()
				CanvasOrder.tag_grid(view,int(region.width)+1,int(region.height)+1)
				_meshes.add_child(view)
		for visual: Dictionary in instance.visuals:
			if not visual.special: continue
			_attach_face(visual.vertices,visual.material_weights,Vector3.ZERO,instance,depth_domain)
		for side: Dictionary in instance.exposed_sides: _attach_face(side.vertices,[],side.outward,instance,depth_domain)
		_object_sprites.append_array(Objects.attach(_meshes,instance.get("objects",[]),false,[],depth_domain,geometry._support_index))
		for object: Dictionary in instance.get("objects",[]):
			if object.has("body_volume"): _object_volumes.append(object.body_volume)
	var border_material := Materials.material(); border_material.shader = load(BorderCatalog.BORDER_SHADER)
	for k: int in Materials.IDS.size(): border_material.set_shader_parameter(Materials.IDS[k]+"_tile",load(Materials.PATHS[k]))
	border_material.set_shader_parameter("tile_units",Materials.TILE_UNITS)
	for face: Dictionary in package.border_geometry.faces: _attach_border_face(face,border_material,depth_domain)
	if not package.border_geometry.water.is_empty():
		var water_material := ShaderMaterial.new(); water_material.shader = load(BorderCatalog.WATER_SHADER)
		water_material.set_shader_parameter("water_tile",load(BorderCatalog.WATER_PATH)); water_material.set_shader_parameter("tile_units",Materials.TILE_UNITS)
		for face: Dictionary in package.border_geometry.water: _attach_border_face(face,water_material,depth_domain)
	var border_faces: Array = []
	if not package.border_geometry.props.is_empty():
		for mass: Dictionary in package.border_geometry.solid_prisms:
			border_faces.append({"face_id":mass.volume_id,"source_id":mass.volume_id,"vertices":mass.top.duplicate(),"headroom":1.0,"walkable":TerrainTopology.is_walkable(mass.top),"special":false,"bottom_y":mass.bottom_y})
	var border_index := GroundShadow.index_from_topology(border_faces,TerrainTopology.build(border_faces)) if not border_faces.is_empty() else {}
	_object_sprites.append_array(Objects.attach(_meshes,package.border_geometry.props,false,[],depth_domain,border_index))
	for object: Dictionary in package.border_geometry.props:
		if object.has("body_volume"): _object_volumes.append(object.body_volume)
	for volume: AABB in package.manifest.stages[0].volumes:
		if volume not in _object_volumes: _attach_volume(volume,depth_domain)
	set_contact_shadows(contact_shadows_enabled)
	update_canvas_order()
	fit()
func _attach_volume(box: AABB, _domain: Vector2) -> void:
	var group := Node2D.new(); _meshes.add_child(group); CanvasOrder.tag_box(group,box)
	var p := box.position; var e := box.end; var material := Materials.material()
	var faces: Array = [
		{"vertices":[Vector3(e.x,p.y,p.z),Vector3(e.x,p.y,e.z),Vector3(e.x,e.y,e.z),Vector3(e.x,e.y,p.z)],"normal":Vector3.RIGHT},
		{"vertices":[Vector3(e.x,p.y,e.z),Vector3(p.x,p.y,e.z),Vector3(p.x,e.y,e.z),Vector3(e.x,e.y,e.z)],"normal":Vector3.BACK},
		{"vertices":[Vector3(p.x,e.y,p.z),Vector3(e.x,e.y,p.z),Vector3(e.x,e.y,e.z),Vector3(p.x,e.y,e.z)],"normal":Vector3.UP}]
	# The camera looks from positive X/Y/Z: an opaque AABB exposes these three
	# faces. Its canonical volume and legacy dimensions remain unchanged.
	for face: Dictionary in faces:
		var view := MeshInstance2D.new(); view.mesh = Materials.from_arrays(Materials.face_arrays(face.vertices,[],face.normal)); view.material = material; group.add_child(view)
func update_canvas_order() -> Dictionary:
	var ordered := CanvasOrder.apply(_meshes)
	if not ordered.ok: status.emit("A prévia precisa de revisão na ordem de desenho: "+str(ordered.code))
	return ordered
func set_contact_shadows(enabled: bool) -> void:
	contact_shadows_enabled = enabled
	for sprite: Sprite2D in _object_sprites:
		var shadow := sprite.get_node_or_null("ContactShadow") as CanvasItem
		if shadow != null: shadow.visible = enabled
func _attach_border_face(face: Dictionary, material: ShaderMaterial, domain: Vector2) -> void:
	var view := MeshInstance2D.new(); view.mesh = Materials.from_arrays(Materials.face_arrays(face.vertices,face.get("material_weights",[]),face.get("outward",Vector3.ZERO))); view.material = material
	var height := 0.0
	for point: Vector3 in face.vertices: height += point.y
	view.z_index = Objects.depth_order(height/face.vertices.size(),domain); view.set_meta("border_face_id",face.face_id); _meshes.add_child(view)
func _attach_face(vertices: Array, paint: Array, normal: Vector3, instance: Dictionary, domain: Vector2) -> void:
	var view := MeshInstance2D.new(); view.mesh = Materials.from_arrays(Materials.face_arrays(vertices,paint,normal,instance.rotation_quarters,instance.translation)); view.material = Materials.material()
	var height := 0.0
	for point: Vector3 in vertices: height += point.y
	view.z_index = Objects.depth_order(height/vertices.size()+float(instance.translation.y),domain); _meshes.add_child(view)

func fit() -> void:
	if package.is_empty(): return
	var bounds := Rect2(); var first := true
	for instance: Dictionary in package.render_instances:
		for face: Dictionary in instance.visuals+instance.exposed_sides:
			for original: Vector3 in face.vertices:
				var point := WorldProjection.project(Kernel.rotate(original,instance.rotation_quarters)+Vector3(instance.translation))
				if first: bounds = Rect2(point,Vector2.ZERO); first = false
				else: bounds = bounds.expand(point)
	for face: Dictionary in package.border_geometry.faces+package.border_geometry.water:
		for original: Vector3 in face.vertices:
			var point := WorldProjection.project(original)
			if first: bounds = Rect2(point,Vector2.ZERO); first = false
			else: bounds = bounds.expand(point)
	for sprite: Sprite2D in _object_sprites:
		var rect := Rect2(sprite.position+sprite.get_rect().position*sprite.scale,sprite.get_rect().size*sprite.scale)
		bounds = rect if first else bounds.merge(rect); first = false
	for box: AABB in package.manifest.stages[0].volumes:
		if box in _object_volumes: continue
		for i: int in 8: bounds = bounds.expand(WorldProjection.project(box.get_endpoint(i)))
	_scale = minf((size.x-80)/maxf(1,bounds.size.x),(size.y-100)/maxf(1,bounds.size.y))
	_scale = clampf(_scale,0.01,5); _origin = size*0.5-bounds.get_center()*_scale
	_meshes.scale = Vector2.ONE*_scale; _meshes.position = _origin; redraw()
func screen(point: Vector3) -> Vector2: return WorldProjection.project(point)*_scale+_origin
func start_test() -> Dictionary:
	if package.is_empty(): return {"ok":false}
	stop_test(); motion = Motion.new()
	var cell: Dictionary = package.manifest.stages[0].surfaces[0]
	var start := Compiler._walkable_point(geometry,cell,package.profile)
	if start == null: motion = null; return {"ok":false,"code":"route_unreachable"}
	var result := motion.configure(geometry,start,package.profile,"discardable_editor_actor")
	testing = result.ok; redraw(); return result
func stop_test() -> void:
	if motion != null: motion.release(); motion = null
	testing = false; redraw()
func _process(delta: float) -> void:
	if _meshes != null and not package.is_empty():
		for child: Node in _meshes.get_children():
			if child.has_method("world_point"): update_canvas_order(); break
	if testing and motion != null and motion.has_route():
		var result := motion.advance(minf(delta,0.05)*60.0)
		if not result.ok: motion.cancel(); status.emit("Movimento bloqueado pela geometria.")
		redraw()
	if motion != null and motion.point() != null: reveal_object_occlusion(motion.point().position)

func reveal_object_occlusion(position: Vector3) -> void:
	Objects.reveal_actor(_object_sprites,position)
func pick(at: Vector2) -> Dictionary:
	if geometry == null: return {"ok":false}
	var ray := WorldProjection.ray((at-_origin)/_scale)
	var ids: Array[String] = []
	for cell: Dictionary in package.manifest.stages[0].surfaces:
		if selected_surface.is_empty() or selected_surface == cell.surface_id: ids.append(cell.surface_id)
	return geometry.resolve_surface(ray.origin,ray.direction,ids,geometry.geometry_revision)
func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	var hit := pick(event.position)
	if not hit.ok: status.emit("Sem superfície visível nesta posição."); return
	var point := Point.create("map_preview",hit.data.point.surface_id,hit.data.point.position)
	selected_instance = point.surface_id.get_slice("/",0); selected.emit(selected_instance)
	if testing:
		var route := motion.plan(point,geometry.geometry_revision)
		status.emit("Caminhando pelo mapa de teste." if route.ok else "Não há rota para esse ponto.")
	redraw()
func redraw() -> void:
	queue_redraw()
	if _overlay != null: _overlay.queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("17242b"))
	if package.is_empty():
		draw_string(ThemeDB.fallback_font,Vector2(20,40),"Compile o mapa para visualizar emendas e perímetro.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE); return
func _draw_world() -> void:
	if package.is_empty(): return
	for cell: Dictionary in package.manifest.stages[0].surfaces:
		if cell.surface_id.begins_with(selected_instance+"/"):
			var outline := PackedVector2Array()
			for point: Vector3 in cell.vertices: outline.append(screen(point))
			outline.append(outline[0]); _overlay.draw_polyline(outline,Color("e7c77a"),2)
	for port: Dictionary in package.get("logical_ports",[]): _overlay.draw_circle(screen(port.position),4,Color("77e4cc"))
	if motion != null and motion.point() != null:
		var at := screen(motion.point().position)
		_overlay.draw_circle(at,5,Color("ffe4a8")); _overlay.draw_line(at,screen(motion.point().position+Vector3.UP*12),Color("fff2da"),5)
