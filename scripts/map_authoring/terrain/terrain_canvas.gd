@tool
extends Control
const WorldProjection = preload("res://scripts/world/expedition_geometry_view.gd")
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
const Partition = preload("res://scripts/map_authoring/compiler/terrain_partition.gd")
const TerrainMaterial = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_view.gd")
signal stroke_finished(points: Array, options: Dictionary)
signal cancelled
signal object_pressed(hit: Dictionary)
var object_edit_mode := ""
var object_surface_id := ""
var selected_objects: Array[String] = []
var _object_records: Array = []
var source: Dictionary = {}
var selected_layer := ""
var options: Dictionary = {}
var hidden_layers: Array[String] = []
var package: Dictionary = {}
var _preview: Dictionary = {}
var _points: Array = []
var _active_options: Dictionary = {}
var _dragging := false
var _scale := 1.0
var _pan := Vector2.ZERO
var _origin := Vector2.ZERO
var _cursor := Vector2.ZERO
var wire_overlay := false
var _mesh_root: Node2D
var _overlay: Node2D
var _height_bounds: Dictionary = {}

func _ready() -> void:
	custom_minimum_size = Vector2(480,300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL; size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true; focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(cancel_stroke)
	get_window().focus_exited.connect(cancel_stroke)
	resized.connect(queue_redraw)
	_mesh_root = Node2D.new(); add_child(_mesh_root)
	_overlay = Node2D.new(); _overlay.z_index = 4090; add_child(_overlay)
	_overlay.draw.connect(_draw_overlays)

func set_source(data: Dictionary, layer_id: String) -> void:
	cancel_stroke()
	source = data.duplicate(true); selected_layer = layer_id; package = {}
	redraw_terrain()

func fit() -> void:
	var bounds := Rect2(); var first := true
	for layer: Dictionary in source.get("layers",[]):
		if layer.layer_id in hidden_layers or layer.heights.size() != int(layer.rows)*int(layer.columns): continue
		for z: int in int(layer.rows):
			for x: int in int(layer.columns):
				var vertex := Partition.point(layer,x,z)
				var point := WorldProjection.project(vertex)
				if first: bounds = Rect2(point,Vector2.ZERO); first = false
				else: bounds = bounds.expand(point)
	for special: Dictionary in source.get("special_surfaces",[]):
		for xyz: Array in special.vertices_xyz:
			var vertex := Vector3(xyz[0],xyz[1],xyz[2])
			var point := WorldProjection.project(vertex)
			if first: bounds = Rect2(point,Vector2.ZERO); first = false
			else: bounds = bounds.expand(point)
	if first: _scale = 1.0; _pan = Vector2.ZERO; _origin = size*0.5
	else:
		_scale = clampf(minf((size.x-100)/maxf(1,bounds.size.x),(size.y-90)/maxf(1,bounds.size.y)),0.005,8)
		_origin = size*0.5-bounds.get_center()*_scale; _pan = Vector2.ZERO
	queue_redraw()

func screen(point: Vector3) -> Vector2: return WorldProjection.project(point)*_scale+_origin+_pan

func _triangles(data: Dictionary) -> Array:
	var triangles: Array = []
	if data.is_empty(): return triangles
	if not preview_supported(data): return triangles
	for layer: Dictionary in data.layers:
		if layer.layer_id in hidden_layers: continue
		if layer.heights.size() != int(layer.rows)*int(layer.columns): continue
		for z: int in range(int(layer.rows)-1):
			for x: int in range(int(layer.columns)-1):
				var indices := [z*int(layer.columns)+x,z*int(layer.columns)+x+1,(z+1)*int(layer.columns)+x+1,(z+1)*int(layer.columns)+x]
				for tri: Array in [[0,1,2],[0,2,3]]:
					var vertices: Array = []; var weights: Array = []
					for k: int in tri:
						var index: int = indices[k]
						vertices.append(Vector3(layer.origin_xz[0]+(index%int(layer.columns))*layer.sample_spacing,layer.heights[index],layer.origin_xz[1]+floori(float(index)/int(layer.columns))*layer.sample_spacing))
						var earth: float = layer.material_masks.earth[index] if layer.material_masks.has("earth") and layer.material_masks.earth.size() > index else 0.0
						var grass: float = layer.material_masks.grass[index] if layer.material_masks.has("grass") and layer.material_masks.grass.size() > index else 1.0
						weights.append(earth/maxf(0.00001,earth+grass))
					triangles.append({"vertices":vertices,"weights":weights,"source_id":layer.layer_id,"special":false})
	for special: Dictionary in data.special_surfaces:
		if special.layer_id in hidden_layers: continue
		for i: int in range(1,special.vertices_xyz.size()-1):
			var vertices: Array = []
			for k: int in [0,i,i+1]:
				var xyz: Array = special.vertices_xyz[k]; vertices.append(Vector3(xyz[0],xyz[1],xyz[2]))
			triangles.append({"vertices":vertices,"weights":[0.0,0.0,0.0],"source_id":special.surface_id,"special":true})
	triangles.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var ay: float = (a.vertices[0].y+a.vertices[1].y+a.vertices[2].y)/3.0
		var by: float = (b.vertices[0].y+b.vertices[1].y+b.vertices[2].y)/3.0
		return ay < by)
	return triangles

static func preview_supported(data: Dictionary) -> bool:
	var count := 0
	for layer: Dictionary in data.get("layers",[]):
		count += (int(layer.rows)-1)*(int(layer.columns)-1)
		if count > 65536: return false
	return count <= 65536

func pick(at: Vector2) -> Dictionary:
	if not preview_supported(source): return {"ok":false}
	var result := {"ok":false}; var highest := -INF
	for layer: Dictionary in source.layers:
		if layer.layer_id != selected_layer or layer.layer_id in hidden_layers or not _height_bounds.has(layer.layer_id): continue
		var ray := WorldProjection.ray((at-_origin-_pan)/_scale)
		var low: Vector3 = ray.origin+ray.direction*((_height_bounds[layer.layer_id].x-ray.origin.y)/ray.direction.y)
		var high: Vector3 = ray.origin+ray.direction*((_height_bounds[layer.layer_id].y-ray.origin.y)/ray.direction.y)
		var spacing: float = layer.sample_spacing
		var x0 := clampi(floori((minf(low.x,high.x)-layer.origin_xz[0])/spacing)-1,0,int(layer.columns)-2)
		var x1 := clampi(ceili((maxf(low.x,high.x)-layer.origin_xz[0])/spacing)+1,0,int(layer.columns)-2)
		var z0 := clampi(floori((minf(low.z,high.z)-layer.origin_xz[1])/spacing)-1,0,int(layer.rows)-2)
		var z1 := clampi(ceili((maxf(low.z,high.z)-layer.origin_xz[1])/spacing)+1,0,int(layer.rows)-2)
		for z: int in range(z0,z1+1):
			for x: int in range(x0,x1+1):
				var quad: Array = [Partition.point(layer,x,z),Partition.point(layer,x+1,z),Partition.point(layer,x+1,z+1),Partition.point(layer,x,z+1)]
				for triangle: Array in [[0,1,2],[0,2,3]]:
					var vertices: Array = [quad[triangle[0]],quad[triangle[1]],quad[triangle[2]]]
					var a := screen(vertices[0]); var b := screen(vertices[1]); var c := screen(vertices[2])
					var denominator := (b-a).cross(c-a)
					if absf(denominator) < 0.00001: continue
					var v := (at-a).cross(c-a)/denominator; var w := (b-a).cross(at-a)/denominator; var u := 1-v-w
					if minf(u,minf(v,w)) >= -0.00001:
						var point: Vector3 = vertices[0]*u+vertices[1]*v+vertices[2]*w
						if point.y >= highest:
							highest = point.y; result = {"ok":true,"point":Vector2(point.x,point.z),"position":point,"surface_id":layer.layer_id}
	return result

func redraw_terrain() -> void:
	if not is_instance_valid(_mesh_root): return
	for child: Node in _mesh_root.get_children(): child.free()
	_height_bounds.clear()
	var data := _preview if not _preview.is_empty() else source
	if data.is_empty() or not preview_supported(data): queue_redraw(); return
	for layer: Dictionary in data.layers:
		if layer.layer_id in hidden_layers or layer.heights.is_empty() or int(layer.columns) < 2 or int(layer.rows) < 2 or layer.sample_spacing <= 0 or layer.heights.size() != int(layer.columns)*int(layer.rows): continue
		_height_bounds[layer.layer_id] = Vector2(layer.heights.min(),layer.heights.max())
		var regions := Partition.build(layer)
		if regions.size() > 1024: regions = [{}] # Invalid complex drafts remain visible; bake reports its logical budget.
		for region: Dictionary in regions:
			var mesh := MeshInstance2D.new()
			mesh.mesh = TerrainMaterial.mesh(layer,region)
			mesh.material = TerrainMaterial.material(true)
			var x: int = region.get("x",0); var z: int = region.get("z",0)
			var width: int = region.get("width",int(layer.columns)-1); var height: int = region.get("height",int(layer.rows)-1)
			mesh.z_index = clampi(floori((Partition.point(layer,x,z).y+Partition.point(layer,x+width,z+height).y)*2),-4000,4000)
			_mesh_root.add_child(mesh)
	for special: Dictionary in data.special_surfaces:
		if special.layer_id in hidden_layers or special.vertices_xyz.size() < 3: continue
		var polygon := Polygon2D.new(); var points := PackedVector2Array(); var y := 0.0
		for xyz: Array in special.vertices_xyz:
			var point := Vector3(xyz[0],xyz[1],xyz[2]); points.append(WorldProjection.project(point)); y += point.y
		polygon.polygon = points; polygon.color = Color("889295"); polygon.z_index = clampi(floori(y/special.vertices_xyz.size()*4),-4000,4000)
		_mesh_root.add_child(polygon)
		for i: int in special.vertices_xyz.size():
			var av: Array = special.vertices_xyz[i]; var bv: Array = special.vertices_xyz[(i+1)%special.vertices_xyz.size()]
			var a := Vector3(av[0],av[1],av[2]); var b := Vector3(bv[0],bv[1],bv[2])
			if not is_equal_approx(a.y,b.y): continue
			var side := Polygon2D.new(); side.polygon = PackedVector2Array([WorldProjection.project(a),WorldProjection.project(b),WorldProjection.project(b-Vector3.UP*4),WorldProjection.project(a-Vector3.UP*4)])
			side.color = Color("3d505d"); side.z_index = polygon.z_index-1; _mesh_root.add_child(side)
	_object_records = Objects.source_records(data) if not data.get("placements",[]).is_empty() else []
	var hidden_surfaces := hidden_layers.duplicate()
	for special: Dictionary in data.special_surfaces:
		if special.layer_id in hidden_layers: hidden_surfaces.append(special.surface_id)
	_object_records = _object_records.filter(func(object: Dictionary) -> bool: return object.source_surface_id not in hidden_surfaces)
	Objects.attach(_mesh_root,_object_records,true,hidden_surfaces)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("111b24"))
	if is_instance_valid(_mesh_root):
		_mesh_root.scale = Vector2.ONE*_scale; _mesh_root.position = _origin+_pan
	if is_instance_valid(_overlay): _overlay.queue_redraw()

func _draw_overlays() -> void:
	var data := _preview if not _preview.is_empty() else source
	if not preview_supported(data):
		_overlay.draw_string(get_theme_default_font(),Vector2(20,35),"A prévia excede o orçamento de amostras visuais desta sessão.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ffe298")); return
	if wire_overlay:
		for layer: Dictionary in data.get("layers",[]):
			if layer.layer_id in hidden_layers or not _height_bounds.has(layer.layer_id): continue
			for z: int in int(layer.rows):
				var points := PackedVector2Array()
				for x: int in int(layer.columns): points.append(screen(Partition.point(layer,x,z)))
				_overlay.draw_polyline(points,Color(1,1,1,0.18),1,true)
			for x: int in int(layer.columns):
				var points := PackedVector2Array()
				for z: int in int(layer.rows): points.append(screen(Partition.point(layer,x,z)))
				_overlay.draw_polyline(points,Color(1,1,1,0.18),1,true)
	if not package.is_empty():
		for boundary: Dictionary in package.boundaries:
			if wire_overlay or boundary.kind == "opening": _overlay.draw_line(screen(boundary.a),screen(boundary.b),Color("f1c778") if boundary.kind == "opening" else Color("354e3e"),2,true)
	for connector: Dictionary in data.get("connectors",[]):
		var xyz: Array = connector.position_xyz; var center := screen(Vector3(xyz[0],xyz[1],xyz[2]))
		var normal: Array = connector.normal_xyz; var direction := Vector3(normal[0],normal[1],normal[2])
		var tangent := Vector3(-direction.z,0,direction.x)*float(connector.width)*0.5
		_overlay.draw_line(screen(Vector3(xyz[0],xyz[1],xyz[2])-tangent),screen(Vector3(xyz[0],xyz[1],xyz[2])+tangent),Color("ffe298"),3,true)
		_overlay.draw_line(center,screen(Vector3(xyz[0],xyz[1],xyz[2])+direction*24),Color("ffe298"),2,true)
	for area: Dictionary in data.get("context",{}).get("areas",[]):
		for region: Dictionary in data.get("regions",[]):
			if region.region_id != area.region_id or region.layer_id != selected_layer or selected_layer in hidden_layers: continue
			var points := PackedVector2Array()
			for xz: Array in region.polygon_xz: points.append(_stroke_screen(Vector2(xz[0],xz[1])))
			if points.size() < 3: continue
			var color := Color("c998ee") if not area.reserved.is_empty() else Color("8adeb0")
			_overlay.draw_colored_polygon(points,Color(color,0.15)); points.append(points[0]); _overlay.draw_polyline(points,color,2,true)
			_overlay.draw_string(get_theme_default_font(),points[0]-Vector2(0,8),("Reserva · " if not area.reserved.is_empty() else "Encontro · ")+region.region_id,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
	for i: int in range(1,_points.size()):
		_overlay.draw_line(_stroke_screen(_points[i-1]),_stroke_screen(_points[i]),Color("ffe298"),2,true)
	if has_focus(): _overlay.draw_arc(_cursor,8,0,TAU,24,Color("ffe298"),1,true)
	for object: Dictionary in _object_records:
		if object.placement_id in selected_objects:
			_overlay.draw_arc(screen(object.position),maxf(6,float(object.definition.footprint_radius)*_scale),0,TAU,40,Color("ffe298"),2,true)
			_overlay.draw_string(get_theme_default_font(),screen(object.position)+Vector2(8,16),object.definition.name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffe298"))

func object_pick(at: Vector2) -> Dictionary:
	if object_surface_id.is_empty() or object_surface_id == selected_layer: return pick(at)
	var previous := selected_layer
	for layer: Dictionary in source.layers:
		if layer.layer_id != object_surface_id: continue
		selected_layer = object_surface_id
		var found := pick(at); selected_layer = previous; return found
	for special: Dictionary in source.special_surfaces:
		if special.surface_id != object_surface_id or special.layer_id in hidden_layers: continue
		for i: int in range(1,special.vertices_xyz.size()-1):
			var vertices: Array[Vector3] = []
			for k: int in [0,i,i+1]:
				var xyz: Array = special.vertices_xyz[k]; vertices.append(Vector3(xyz[0],xyz[1],xyz[2]))
			var a := screen(vertices[0]); var b := screen(vertices[1]); var c := screen(vertices[2])
			var determinant := (b-a).cross(c-a)
			if absf(determinant) < 0.00001: continue
			var v := (at-a).cross(c-a)/determinant; var w := (b-a).cross(at-a)/determinant
			if minf(1-v-w,minf(v,w)) < -0.00001: continue
			var point := vertices[0]*(1-v-w)+vertices[1]*v+vertices[2]*w
			return {"ok":true,"position":point,"point":Vector2(point.x,point.z),"surface_id":special.surface_id}
	return {"ok":false}

func _stroke_screen(point: Vector2) -> Vector2:
	for layer: Dictionary in source.get("layers",[]):
		if layer.layer_id != selected_layer or not _height_bounds.has(layer.layer_id): continue
		var local := (point-Vector2(layer.origin_xz[0],layer.origin_xz[1]))/float(layer.sample_spacing)
		var x := clampi(floori(local.x),0,int(layer.columns)-2); var z := clampi(floori(local.y),0,int(layer.rows)-2)
		var u := clampf(local.x-x,0,1); var v := clampf(local.y-z,0,1)
		var a := Partition.point(layer,x,z); var b := Partition.point(layer,x+1,z); var c := Partition.point(layer,x+1,z+1); var d := Partition.point(layer,x,z+1)
		var y := a.y+(b.y-a.y)*u+(c.y-b.y)*v if u >= v else a.y+(c.y-d.y)*u+(d.y-a.y)*v
		return screen(Vector3(point.x,y,point.y))
	return screen(Vector3(point.x,0,point.y))

func cancel_stroke() -> void:
	var redraw := not _preview.is_empty()
	if _dragging: cancelled.emit()
	_dragging = false; _points.clear(); _preview = {}; queue_redraw()
	if redraw and is_instance_valid(_mesh_root): redraw_terrain()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_stroke(); accept_event(); return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var previous := _scale
			_scale = clampf(_scale*(1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/1.15),0.005,8.0)
			_pan = event.position-_origin-(event.position-_origin-_pan)*(_scale/previous)
			queue_redraw(); accept_event(); return
		if event.button_index != MOUSE_BUTTON_LEFT: return
		if object_edit_mode != "":
			if event.pressed:
				grab_focus()
				var hit := object_pick(event.position)
				hit["placement_id"] = Objects.pick(_object_records,event.position,screen,_scale)
				object_pressed.emit(hit)
			accept_event(); return
		if event.pressed:
			grab_focus()
			var hit := pick(event.position)
			if not hit.ok: return
			_dragging = true; _points = [hit.point]; _active_options = options.duplicate(true)
			_update_preview()
		else:
			if not _dragging: return
			if not Rect2(Vector2.ZERO,size).has_point(event.position): cancel_stroke(); return
			var points := _points.duplicate(); var active := _active_options.duplicate(true)
			if active.get("mode") == "ramp" and points.size() > 1: points = [points[0],points[-1]]
			_dragging = false; _points.clear(); _preview = {}
			stroke_finished.emit(points,active); queue_redraw()
		accept_event()
	if event is InputEventMouseMotion:
		_cursor = event.position
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			_pan += event.relative; queue_redraw(); accept_event(); return
		if _dragging:
			var hit := pick(event.position)
			if hit.ok and _points[-1].distance_to(hit.point) > 0.01:
				if _points.size() >= 4096: cancel_stroke(); return
				_points.append(hit.point); _update_preview()
		queue_redraw()

func _update_preview() -> void:
	var points := _points
	if _active_options.get("mode") == "ramp":
		if points.size() < 2: return
		points = [points[0],points[-1]]
	var proposal := Brush.stroke(source,selected_layer,points,_active_options,true)
	if proposal.ok: _preview = proposal.data; redraw_terrain()
