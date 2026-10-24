@tool
extends Control
const WorldProjection = preload("res://scripts/world/expedition_geometry_view.gd")
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
signal stroke_finished(points: Array, options: Dictionary)
signal cancelled
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

func _ready() -> void:
	custom_minimum_size = Vector2(480,300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL; size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true; focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(cancel_stroke)
	get_window().focus_exited.connect(cancel_stroke)
	resized.connect(queue_redraw)

func set_source(data: Dictionary, layer_id: String) -> void:
	cancel_stroke()
	source = data.duplicate(true); selected_layer = layer_id; package = {}; queue_redraw()

func fit() -> void:
	var triangles := _triangles(source)
	var bounds := Rect2(); var first := true
	for triangle: Dictionary in triangles:
		for vertex: Vector3 in triangle.vertices:
			var point := WorldProjection.project(vertex)
			if first: bounds = Rect2(point,Vector2.ZERO); first = false
			else: bounds = bounds.expand(point)
	if first: _scale = 1.0; _pan = Vector2.ZERO; _origin = size*0.5
	else:
		_scale = clampf(minf((size.x-100)/maxf(1,bounds.size.x),(size.y-90)/maxf(1,bounds.size.y)),0.1,8)
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
	var count: int = data.get("special_surfaces",[]).size()
	for layer: Dictionary in data.get("layers",[]):
		count += (int(layer.rows)-1)*(int(layer.columns)-1)
		if count > 256: return false
	return count <= 256

func pick(at: Vector2) -> Dictionary:
	var triangles := _triangles(source)
	triangles.reverse()
	for triangle: Dictionary in triangles:
		if triangle.source_id != selected_layer: continue
		var vertices: Array = triangle.vertices
		var a := screen(vertices[0]); var b := screen(vertices[1]); var c := screen(vertices[2])
		var denominator := (b-a).cross(c-a)
		if absf(denominator) < 0.00001: continue
		var v := (at-a).cross(c-a)/denominator; var w := (b-a).cross(at-a)/denominator; var u := 1-v-w
		if minf(u,minf(v,w)) >= -0.00001:
			var point: Vector3 = vertices[0]*u+vertices[1]*v+vertices[2]*w
			return {"ok":true,"point":Vector2(point.x,point.z)}
	return {"ok":false}

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("111b24"))
	var data := _preview if not _preview.is_empty() else source
	if not preview_supported(data):
		draw_string(get_theme_default_font(),Vector2(20,35),"Prévia indisponível: reduza a peça para até 256 células de grade.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ffe298"))
		return
	for triangle: Dictionary in _triangles(data):
		if triangle.special:
			for special: Dictionary in data.special_surfaces:
				if special.surface_id != triangle.source_id: continue
				for i: int in special.vertices_xyz.size():
					var av: Array = special.vertices_xyz[i]; var bv: Array = special.vertices_xyz[(i+1)%special.vertices_xyz.size()]
					var a := Vector3(av[0],av[1],av[2]); var b := Vector3(bv[0],bv[1],bv[2])
					if is_equal_approx(a.y,b.y): draw_colored_polygon(PackedVector2Array([screen(a),screen(b),screen(b-Vector3.UP*4),screen(a-Vector3.UP*4)]),Color("43576b"))
		var polygon := PackedVector2Array(); var colors := PackedColorArray()
		for i: int in 3:
			polygon.append(screen(triangle.vertices[i]))
			var tint := Color("768a9d") if triangle.special else Color("568458").lerp(Color("a27b4b"),triangle.weights[i])
			if triangle.source_id != selected_layer: tint = tint.darkened(0.22)
			colors.append(tint)
		draw_polygon(polygon,colors)
		draw_polyline(PackedVector2Array([polygon[0],polygon[1],polygon[2],polygon[0]]),Color(0.8,0.9,1,0.13),1,true)
	if not package.is_empty():
		for boundary: Dictionary in package.boundaries:
			draw_line(screen(boundary.a),screen(boundary.b),Color("f1c778") if boundary.kind == "opening" else Color("354e3e"),2,true)
	for i: int in range(1,_points.size()):
		draw_line(_stroke_screen(_points[i-1]),_stroke_screen(_points[i]),Color("ffe298"),2,true)
	if has_focus(): draw_arc(_cursor,8,0,TAU,24,Color("ffe298"),1,true)

func _stroke_screen(point: Vector2) -> Vector2:
	return screen(Vector3(point.x,0,point.y))

func cancel_stroke() -> void:
	if _dragging: cancelled.emit()
	_dragging = false; _points.clear(); _preview = {}; queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_stroke(); accept_event(); return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var previous := _scale
			_scale = clampf(_scale*(1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/1.15),0.1,8.0)
			_pan = event.position-_origin-(event.position-_origin-_pan)*(_scale/previous)
			queue_redraw(); accept_event(); return
		if event.button_index != MOUSE_BUTTON_LEFT: return
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
	var proposal := Brush.stroke(source,selected_layer,points,_active_options)
	if proposal.ok: _preview = proposal.data
	queue_redraw()
