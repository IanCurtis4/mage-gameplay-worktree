@tool
extends Control
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const WorldProjection = preload("res://scripts/world/expedition_geometry_view.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const World = preload("res://scripts/core/expedition/spatial/world_geometry.gd")
const Motion = preload("res://scripts/core/expedition/spatial/world_actor_motion.gd")
const Point = preload("res://scripts/core/expedition/model/world_point.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_view.gd")
const CanvasOrder = preload("res://scripts/world/world_canvas_order.gd")
const PackageView = preload("res://scripts/world/map_package_view.gd")
const ViewportTools = preload("res://scripts/map_authoring/preview/viewport_tools.gd")
signal selected(instance_id: String)
signal status(message: String)
var package: Dictionary = {}
var geometry: World
var motion: Motion
var testing := false
var contact_shadows_enabled := true
var selected_instance := ""
var selected_surface := ""
var inspection_surface := ""
var _scale := 1.0
var _origin := Vector2.ZERO
var _meshes: PackageView
var _overlay: Node2D
var _object_sprites: Array[Sprite2D] = []
var _object_volumes: Array[AABB] = []
var _navigation_revision := 0
var _viewport_tools: Control
var show_population_overlay := true
var show_routes_overlay := true
func _ready() -> void:
	custom_minimum_size = Vector2(600,360); size_flags_vertical = Control.SIZE_EXPAND_FILL; size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true; mouse_filter = Control.MOUSE_FILTER_STOP; focus_mode = Control.FOCUS_ALL
	_meshes = PackageView.new(); add_child(_meshes)
	_overlay = Node2D.new(); _overlay.z_index = 4090; add_child(_overlay); _overlay.draw.connect(_draw_world)
	resized.connect(fit)
func clear() -> void:
	_navigation_revision += 1
	stop_test(); package = {}; geometry = null
	_object_sprites.clear(); _object_volumes.clear()
	if _meshes != null: _meshes.clear()
	redraw()
func set_package(value: Dictionary) -> void:
	if not Compiler.validate_package(value): status.emit("O pacote é inválido ou suas dependências mudaram."); return
	clear(); package = value.duplicate(true)
	geometry = World.new(); geometry.configure(Compiler.manifest(package),"map_preview")
	var built := _meshes._configure_approved(package,geometry)
	_object_sprites = _meshes.object_sprites; _object_volumes = _meshes.object_volumes
	set_contact_shadows(contact_shadows_enabled)
	if not built.ok: status.emit("A prévia precisa de revisão na ordem de desenho: "+str(built.code))
	fit()
func update_canvas_order() -> Dictionary:
	var ordered := CanvasOrder.apply(_meshes)
	if not ordered.ok: status.emit("A prévia precisa de revisão na ordem de desenho: "+str(ordered.code))
	return ordered
func set_contact_shadows(enabled: bool) -> void:
	contact_shadows_enabled = enabled
	if _meshes != null: _meshes.set_contact_shadows(enabled)

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
	if navigation_input(event): accept_event(); return
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT: return
	grab_focus()
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
	if not is_instance_valid(_viewport_tools):
		for port: Dictionary in package.get("logical_ports",[]): _overlay.draw_circle(screen(port.position),4,Color("77e4cc"))
	if motion != null and motion.point() != null:
		var at := screen(motion.point().position)
		_overlay.draw_circle(at,5,Color("ffe4a8")); _overlay.draw_line(at,screen(motion.point().position+Vector3.UP*12),Color("fff2da"),5)

func camera_state() -> Dictionary: return {"scale":_scale,"offset":_origin,"size":size}
func set_camera(zoom: float, offset: Vector2) -> void:
	if not is_finite(zoom) or zoom < 0.005 or zoom > 8 or not offset.is_finite(): return
	_scale = zoom; _origin = offset
	if is_instance_valid(_meshes): _meshes.scale = Vector2.ONE*_scale; _meshes.position = _origin
	redraw()
func navigation_revision() -> Array:
	return [_navigation_revision,geometry.get_instance_id(),geometry.configuration_revision,geometry.geometry_revision] if geometry != null else [_navigation_revision,0,0,0]
func navigation_snapshot() -> Dictionary: return ViewportTools.map_model(package,geometry)
func redraw_navigation() -> void: redraw()
func navigation_input(event: InputEvent) -> bool:
	return _viewport_tools.handle_input(event) if is_instance_valid(_viewport_tools) else ViewportTools.camera_input(self,event)
func inspection_world() -> WorldGeometry: return geometry if not package.is_empty() else null
func inspection_pick(at: Vector2) -> Dictionary:
	if inspection_world() == null: return ViewportTools.failure("compile_required")
	if inspection_surface.is_empty(): return pick(at)
	return ViewportTools.pick_support(geometry,inspection_surface,WorldProjection.ray((at-_origin)/_scale))
