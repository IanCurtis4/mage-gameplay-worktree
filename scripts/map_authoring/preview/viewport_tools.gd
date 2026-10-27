@tool
extends VBoxContainer
## Camera and inspection only. Queries delegate to the compiled WorldGeometry.
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")
const Point = preload("res://scripts/core/expedition/model/world_point.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const LABELS := {"height":"Altura","support":"Suporte","blocking":"Bloqueio","connectors":"Conexões","population":"Encontros","routes":"Rotas","probes":"Inspeções"}
var canvas: Control
var screen_id := ""
var model: Dictionary = {}
var overlays := {"height":false,"support":false,"blocking":false,"connectors":true,"population":true,"routes":true,"probes":true}
var mini: Control
var _camera_marker: Node2D
var _world_overlay: Node2D
var _overlay_menu: MenuButton
var _mode: OptionButton
var _query: LineEdit
var _entities: OptionButton
var _radius: SpinBox
var _height: SpinBox
var _probe_fields: HFlowContainer
var _surface: OptionButton
var _notice: Label
var _legend: Label
var _height_domain := Vector2.ZERO
var _token: Variant = null
var _camera: Dictionary = {}
var _focus_y := 0.0
var _mini_bounds := Rect2()
var _mini_scale := 1.0
var _mini_origin := Vector2.ZERO
var _probe_start: Dictionary = {}
var last_probe: Dictionary = {}
var _profile_initialized := false

static func mount(target: Control, id: String) -> Control:
	var parent := target.get_parent(); var index := target.get_index()
	var tools := load("res://scripts/map_authoring/preview/viewport_tools.gd").new() as Control
	parent.add_child(tools); parent.move_child(tools,index); target.reparent(tools)
	tools.bind(target,id); return tools

func bind(target: Control, id: String) -> void:
	name = "ViewportTools"; canvas = target; screen_id = id
	size_flags_horizontal = SIZE_EXPAND_FILL; size_flags_vertical = SIZE_EXPAND_FILL
	canvas.set("_viewport_tools",self); canvas.size_flags_vertical = SIZE_EXPAND_FILL
	set_meta("authoring_command_provider",true)
	var bar := HFlowContainer.new(); add_child(bar); move_child(bar,0)
	var mini_toggle := CheckButton.new(); mini_toggle.text = "Minimapa"; mini_toggle.button_pressed = true; bar.add_child(mini_toggle)
	_overlay_menu = MenuButton.new(); _overlay_menu.text = "Overlays"; bar.add_child(_overlay_menu)
	for key: String in LABELS:
		var popup := _overlay_menu.get_popup(); popup.add_check_item(LABELS[key]); popup.set_item_metadata(popup.item_count-1,key); popup.set_item_checked(popup.item_count-1,overlays[key])
	_overlay_menu.get_popup().hide_on_checkable_item_selection = false
	_overlay_menu.get_popup().id_pressed.connect(func(index: int) -> void:
		var key: String = _overlay_menu.get_popup().get_item_metadata(index)
		set_overlays({key:not overlays[key]}))
	_mode = OptionButton.new(); bar.add_child(_mode)
	for label: String in ["Navegar / editar","Inspecionar folga","Inspecionar linha de visão"]: _mode.add_item(label)
	_mode.tooltip_text = "A inspeção usa o pacote compilado e não altera o terreno. Linha de visão: clique na origem e no destino."
	_mode.item_selected.connect(func(_index: int) -> void: _probe_fields.visible = _mode.selected != 0; _probe_start.clear(); last_probe.clear(); _redraw_dynamic())
	_probe_fields = HFlowContainer.new(); add_child(_probe_fields); move_child(_probe_fields,1); _probe_fields.hide()
	_radius = _number(_probe_fields,"Raio",0.1,512,2); _height = _number(_probe_fields,"Altura",0.1,1024,12)
	_surface = OptionButton.new(); _surface.custom_minimum_size.x = 210; _surface.fit_to_longest_item = false; _surface.clip_text = true; _surface.tooltip_text = "Apoio explícito: seção editorial para inspecionar outro andar. Não muda a oclusão do clique de jogo nem remove corpos."; _probe_fields.add_child(_surface)
	_surface.item_selected.connect(func(index: int) -> void: canvas.inspection_surface = str(_surface.get_item_metadata(index)); _probe_start.clear(); last_probe.clear(); _redraw_dynamic())
	_query = LineEdit.new(); _query.placeholder_text = "Buscar camada, objeto ou rota"; _query.custom_minimum_size.x = 160; bar.add_child(_query)
	_query.text_changed.connect(func(_value: String) -> void: _refresh_entities())
	_entities = OptionButton.new(); _entities.custom_minimum_size.x = 160; _entities.fit_to_longest_item = false; _entities.clip_text = true; bar.add_child(_entities)
	var focus := Button.new(); focus.text = "Focar seleção"; focus.tooltip_text = "Move a câmera. F enquadra tudo quando o desenho está focado."; focus.set_meta("authoring_keep_visible",true); bar.add_child(focus)
	focus.pressed.connect(func() -> void:
		if _entities.selected >= 0: _show(focus_entity(_entities.get_item_metadata(_entities.selected))))
	_notice = Label.new(); _notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(_notice); move_child(_notice,2)
	_legend = Label.new(); _legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(_legend); move_child(_legend,3); _legend.hide()
	mini = Control.new(); mini.name = "AuthoringMinimap"; mini.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas.add_child(mini); mini.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	mini.offset_left = -176; mini.offset_top = -142; mini.offset_right = -8; mini.offset_bottom = -8; mini.z_index = 4092
	mini.draw.connect(_draw_minimap); mini.gui_input.connect(_minimap_input)
	mini_toggle.toggled.connect(func(value: bool) -> void: mini.visible = value)
	_camera_marker = Node2D.new(); mini.add_child(_camera_marker); _camera_marker.draw.connect(_draw_camera)
	_world_overlay = Node2D.new(); _world_overlay.z_index = 4091; canvas.add_child(_world_overlay); _world_overlay.draw.connect(_draw_overlays)
	_refresh(); set_process(true)

func _number(parent: Control, label: String, low: float, high: float, value: float) -> SpinBox:
	var caption := Label.new(); caption.text = label; parent.add_child(caption)
	var input := SpinBox.new(); input.min_value = low; input.max_value = high; input.step = 0; input.custom_arrow_step = 0.1; input.value = value; input.custom_minimum_size.x = 75; parent.add_child(input)
	input.value_changed.connect(func(_value: float) -> void: _display_number.call_deferred(input))
	input.get_line_edit().text_submitted.connect(func(_text: String) -> void: _display_number.call_deferred(input))
	input.get_line_edit().focus_exited.connect(func() -> void: _display_number.call_deferred(input))
	_display_number.call_deferred(input)
	return input

func _display_number(input: SpinBox) -> void:
	if not is_instance_valid(input): return
	var text := JSON.stringify(input.value,"",true,true)
	for decimals: int in 18:
		var candidate := String.num(input.value,decimals)
		if candidate.to_float() == input.value: text = candidate; break
	input.get_line_edit().text = text

func _process(_delta: float) -> void:
	if not is_instance_valid(canvas): return
	if _token != canvas.navigation_revision(): _refresh()
	var state: Dictionary = canvas.camera_state()
	if state != _camera: _camera = state; _redraw_dynamic()

func _refresh() -> void:
	_token = canvas.navigation_revision(); model = canvas.navigation_snapshot()
	var first := true
	for face: Dictionary in model.get("faces",[]):
		for p: Vector3 in face.vertices:
			if first: _height_domain = Vector2(p.y,p.y); first = false
			else: _height_domain = Vector2(minf(_height_domain.x,p.y),maxf(_height_domain.y,p.y))
	if first: _height_domain = Vector2.ZERO
	_probe_start.clear(); last_probe.clear()
	if not _profile_initialized and not canvas.package.is_empty():
		_radius.value = canvas.package.profile.radius; _height.value = canvas.package.profile.height; _profile_initialized = true
	_fit_minimap(); _refresh_entities()
	_refresh_surfaces()
	_notice.text = "Suporte compilado · roda: zoom · botão do meio: mover · F: enquadrar." if model.get("compiled",false) else "Prévia editorial · compile a fonte atual para consultar folga e linha de visão."
	_update_legend(); mini.queue_redraw(); _redraw_dynamic()

func _update_legend() -> void:
	var parts: PackedStringArray = []
	if overlays.height: parts.append("Alturas: azul %.1f a vermelho %.1f; cotas no terreno."%[_height_domain.x,_height_domain.y] if _height_domain.x != _height_domain.y else "Altura única: %.1f."%_height_domain.x)
	if overlays.support: parts.append(("Apoio compilado" if model.get("compiled",false) else "Prévia de apoio")+": verde. Faces sem apoio: rosa.")
	if overlays.blocking: parts.append("Bloqueios: salmão; camadas ocultas conservam seus corpos.")
	_legend.text = " ".join(parts); _legend.visible = not parts.is_empty()

func _refresh_surfaces() -> void:
	var selected: String = canvas.inspection_surface
	_surface.clear(); _surface.add_item("Apoio: visível no clique"); _surface.set_item_metadata(0,"")
	for face: Dictionary in model.get("faces",[]):
		if not face.support or not model.compiled: continue
		_surface.add_item("Apoio: "+str(face.get("label",face.source_id))); _surface.set_item_metadata(_surface.item_count-1,face.id)
		if face.id == selected: _surface.select(_surface.item_count-1)
	canvas.inspection_surface = str(_surface.get_item_metadata(_surface.selected))

func _refresh_entities() -> void:
	if _entities == null: return
	var previous: String = _entities.get_item_metadata(_entities.selected) if _entities.selected >= 0 else ""
	_entities.clear(); var query := _query.text.strip_edges().to_lower()
	for entity: Dictionary in model.get("entities",[]):
		if not query.is_empty() and not query in (str(entity.label)+" "+str(entity.id)).to_lower(): continue
		_entities.add_item(entity.label); _entities.set_item_metadata(_entities.item_count-1,entity.key)
		if entity.key == previous: _entities.select(_entities.item_count-1)

func set_overlays(values: Dictionary) -> Dictionary:
	for key: Variant in values:
		if not key is String or not overlays.has(key) or not values[key] is bool: return failure("arguments_invalid")
	for key: String in values: overlays[key] = values[key]
	for index: int in _overlay_menu.get_popup().item_count:
		var key: String = _overlay_menu.get_popup().get_item_metadata(index); _overlay_menu.get_popup().set_item_checked(index,overlays[key])
	canvas.set("show_population_overlay",overlays.population); canvas.set("show_routes_overlay",overlays.routes)
	_update_legend(); canvas.redraw_navigation(); mini.queue_redraw(); _redraw_dynamic(); return {"ok":true,"overlays":overlays.duplicate()}

func focus_world(point: Vector3, zoom: float = -1.0) -> Dictionary:
	if not point.is_finite() or not is_finite(zoom) or (zoom != -1.0 and (zoom < 0.005 or zoom > 8.0)): return failure("arguments_invalid")
	var state: Dictionary = canvas.camera_state(); var scale: float = state.scale if zoom == -1.0 else zoom
	var offset := canvas.size*0.5-ProjectionMath.project(point)*scale
	if not offset.is_finite(): return failure("arguments_invalid")
	canvas.set_camera(scale,offset); _focus_y = point.y
	_redraw_dynamic(); mini.queue_redraw(); return {"ok":true,"position_xyz":[point.x,point.y,point.z],"camera":canvas.camera_state()}

func focus_entity(id: String) -> Dictionary:
	if _token != canvas.navigation_revision(): _refresh()
	var matches: Array = []
	for entity: Dictionary in model.get("entities",[]):
		if entity.key == id or entity.id == id: matches.append(entity)
	if matches.is_empty(): return failure("focus_target_missing")
	if matches.size() != 1: return failure("focus_target_ambiguous")
	var box: AABB = matches[0].bounds; var screen_bounds := Rect2(ProjectionMath.project(box.position),Vector2.ZERO)
	for index: int in 8: screen_bounds = screen_bounds.expand(ProjectionMath.project(box.get_endpoint(index)))
	var zoom := clampf(minf(canvas.size.x*0.75/maxf(screen_bounds.size.x,40),canvas.size.y*0.75/maxf(screen_bounds.size.y,40)),0.005,8)
	var result := focus_world(box.get_center(),zoom); result["entity_key"] = matches[0].key; return result

static func camera_input(target: Control, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and target.has_focus(): target.fit(); return true
	var state: Dictionary = target.camera_state()
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var zoom := clampf(float(state.scale)*(1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.15),0.005,8)
		target.set_camera(zoom,event.position-(event.position-Vector2(state.offset))*(zoom/float(state.scale))); return true
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		target.set_camera(state.scale,Vector2(state.offset)+event.relative); return true
	return false

func handle_input(event: InputEvent) -> bool:
	if camera_input(canvas,event): return true
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _mode.selected != 0:
		_probe_start.clear(); last_probe.clear(); _mode.select(0); _probe_fields.hide(); _redraw_dynamic(); return true
	if _mode.selected == 0 or not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT: return false
	if not event.pressed: return true
	canvas.grab_focus()
	var hit: Dictionary = canvas.inspection_pick(event.position)
	if not hit.get("ok",false): _show(hit); return true
	var point: Dictionary = hit.data.point
	if _mode.selected == 1: _show(probe_point(point))
	elif _probe_start.is_empty(): _probe_start = point.duplicate(true); _notice.text = "Origem marcada. Clique no destino da linha de visão."; _redraw_dynamic()
	else: _show(probe_los(_probe_start,point)); _probe_start.clear()
	return true

func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not event.ctrl_pressed or event.keycode != KEY_F or not is_visible_in_tree() or not get_window().has_focus(): return
	var owner := get_viewport().gui_get_focus_owner()
	if owner is LineEdit or owner is TextEdit or (owner != null and not is_ancestor_of(owner)): return
	_query.grab_focus(); _query.select_all(); get_viewport().set_input_as_handled()

func profile() -> Dictionary:
	var result: Dictionary = canvas.package.get("profile",{"connector_kinds":["walk"]}).duplicate(true)
	result.radius = _radius.value; result.height = _height.value; return result

func probe_point(data: Dictionary) -> Dictionary:
	if _token != canvas.navigation_revision(): _refresh()
	var world: WorldGeometry = canvas.inspection_world()
	if world == null: return failure("compile_required")
	var point := decode_point(data,world._stage.stage_id)
	if point == null: return failure("arguments_invalid")
	var result := world.position_query(point,profile(),world.geometry_revision)
	last_probe = {"kind":"clearance","from":point.position,"profile":profile(),"result":result.duplicate(true)}
	_redraw_dynamic(); return result

func probe_los(a: Dictionary, b: Dictionary) -> Dictionary:
	if _token != canvas.navigation_revision(): _refresh()
	var world: WorldGeometry = canvas.inspection_world()
	if world == null: return failure("compile_required")
	var start := decode_point(a,world._stage.stage_id); var end := decode_point(b,world._stage.stage_id)
	if start == null or end == null: return failure("arguments_invalid")
	for point: ExpeditionWorldPoint in [start,end]:
		var supported := world.position_query(point,profile(),world.geometry_revision)
		if not supported.ok: return supported
	var offset := Vector3.UP*_height.value*0.5
	var result := world.sweep(start.position+offset,end.position+offset,{"radius":0.0,"height":0.0},world.geometry_revision)
	last_probe = {"kind":"los","from":start.position+offset,"to":end.position+offset,"result":result.duplicate(true)}
	_redraw_dynamic(); return result

static func decode_point(data: Dictionary, stage_id: String) -> ExpeditionWorldPoint:
	# Both canonical WorldPoint dictionaries and passive AX coordinates are accepted.
	if data.size() == 3 and data.has_all(["stage_id","surface_id","position"]) and data.position is Vector3:
		if data.stage_id != stage_id or not data.position.is_finite() or not data.surface_id is String: return null
		return Point.create(stage_id,data.surface_id,data.position)
	if data.size() != 2 or not data.get("surface_id") is String or not vector_valid(data.get("position_xyz")): return null
	return Point.create(stage_id,data.surface_id,vector(data.position_xyz))

static func vector_valid(value: Variant) -> bool:
	return value is Array and value.size() == 3 and value.all(func(n: Variant) -> bool: return (n is int or n is float) and is_finite(float(n)))
static func vector(value: Array) -> Vector3: return Vector3(value[0],value[1],value[2])
static func failure(code: String) -> Dictionary: return {"ok":false,"code":code}

static func pick_support(world: WorldGeometry, id: String, ray: Dictionary) -> Dictionary:
	# Explicit editorial section. The canonical support/body queries remain authoritative;
	# default visible picking and every gameplay click retain resolve_surface occlusion.
	var cell: Dictionary = world._cell(id)
	if cell.is_empty(): return failure("unknown_surface")
	var normal := Kernel.plane_normal(cell.vertices); var denominator: float = normal.dot(ray.direction)
	if absf(denominator) < Kernel.EPSILON: return failure("invalid_ray")
	var t: float = normal.dot(Vector3(cell.vertices[0])-Vector3(ray.origin))/denominator
	if t < 0: return failure("invalid_ray")
	var point: Vector3 = ray.origin+ray.direction*t
	return world.support_at(id,Vector2(point.x,point.z),world.geometry_revision)

func _show(result: Dictionary) -> void:
	if not result.get("ok",false):
		var code := str(result.get("error_code",result.get("code","inspection_failed")))
		_notice.text = {"compile_required":"Compile a fonte atual antes de inspecionar.","invalid_support":"Esse corpo não cabe nesse apoio ou encontra um bloqueio.","occluded_surface":"Outra geometria está à frente. Escolha um apoio explícito para inspecionar esse andar.","ambiguous_surface":"O clique coincide com mais de um apoio. Escolha o apoio na lista.","hidden_or_missing_surface":"Não há apoio visível nessa posição.","focus_target_missing":"A entidade não tem geometria visível para focar.","focus_target_ambiguous":"Há mais de um alvo com esse ID; escolha a categoria na lista.","arguments_invalid":"Confira os parâmetros da inspeção."}.get(code,"Não foi possível concluir a inspeção.")
		_notice.tooltip_text = code; return
	_notice.tooltip_text = ""
	if result.get("data",{}).has("occupants"):
		var occupants: Array = result.data.occupants
		_notice.text = ("Corpo cabe na cota %.1f; "%float(result.data.point.position.y))+("sem ocupantes." if occupants.is_empty() else "ocupado por: "+", ".join(occupants))
	elif result.get("data",{}).has("hit"): _notice.text = "Linha bloqueada por "+str(result.data.get("volume_id","obstáculo"))+"." if result.data.hit else "Linha de visão livre entre os pontos escolhidos."
	else: _notice.text = "Câmera focada."

func _redraw_dynamic() -> void:
	if is_instance_valid(_camera_marker): _camera_marker.queue_redraw()
	if is_instance_valid(_world_overlay): _world_overlay.queue_redraw()

func _fit_minimap() -> void:
	var first := true
	for face: Dictionary in model.get("faces",[]):
		for p: Vector3 in face.vertices:
			var at := Vector2(p.x,p.z)
			if first: _mini_bounds = Rect2(at,Vector2.ZERO); first = false
			else: _mini_bounds = _mini_bounds.expand(at)
	if first: _mini_bounds = Rect2(-50,-50,100,100)
	_mini_scale = minf((mini.size.x-16)/maxf(_mini_bounds.size.x,1),(mini.size.y-36)/maxf(_mini_bounds.size.y,1))
	_mini_origin = Vector2(mini.size.x*0.5,22+(mini.size.y-30)*0.5)-_mini_bounds.get_center()*_mini_scale

func minimap_point(point: Vector3) -> Vector2: return Vector2(point.x,point.z)*_mini_scale+_mini_origin
func minimap_world(at: Vector2) -> Vector3:
	var xz := (at-_mini_origin)/_mini_scale; return Vector3(xz.x,_focus_y,xz.y)
func _minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show(focus_world(minimap_world(event.position))); mini.accept_event()

func camera_footprint() -> Array[Vector3]:
	var points: Array[Vector3] = []; var state: Dictionary = canvas.camera_state()
	for corner: Vector2 in [Vector2.ZERO,Vector2(canvas.size.x,0),canvas.size,Vector2(0,canvas.size.y)]:
		var ray := ProjectionMath.ray((corner-Vector2(state.offset))/float(state.scale))
		points.append(ray.origin+ray.direction*((_focus_y-ray.origin.y)/ray.direction.y))
	return points

func _draw_minimap() -> void:
	mini.draw_style_box(_mini_style(),Rect2(Vector2.ZERO,mini.size))
	mini.draw_string(ThemeDB.fallback_font,Vector2(8,16),"Minimapa · cota %.1f"%_focus_y,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color.WHITE)
	for face: Dictionary in model.get("faces",[]):
		var polygon := PackedVector2Array()
		for p: Vector3 in face.vertices: polygon.append(minimap_point(p))
		if polygon.size() >= 3: mini.draw_colored_polygon(polygon,Color("4a6653") if face.support else Color("5c5865"))
	for entity: Dictionary in model.get("entities",[]):
		if entity.kind == "object": mini.draw_circle(minimap_point(entity.bounds.get_center()),2,Color("dfc987"))
	if overlays.population:
		for slot: Dictionary in model.get("slots",[]): mini.draw_circle(minimap_point(slot.position),2.5,Color("ed859a"))
	if overlays.routes:
		for route: Dictionary in model.get("routes",[]):
			var line := PackedVector2Array()
			for p: Vector3 in route.points: line.append(minimap_point(p))
			if line.size() > 1: mini.draw_polyline(line,Color("b8c5ff"),1,true)

func _mini_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = Color(0.055,0.085,0.11,0.94); style.border_color = Color("8aab99"); style.set_border_width_all(1); return style

func _draw_camera() -> void:
	var polygon := PackedVector2Array(); var clip := PackedVector2Array([Vector2(4,22),Vector2(mini.size.x-4,22),mini.size-Vector2(4,4),Vector2(4,mini.size.y-4)])
	for p: Vector3 in camera_footprint(): polygon.append(minimap_point(p))
	# Clip the marker to the minimap, without changing the true returned footprint.
	for clipped: PackedVector2Array in Geometry2D.intersect_polygons(polygon,clip):
		if clipped.size() < 2: continue
		_camera_marker.draw_colored_polygon(clipped,Color(1,1,1,0.08)); clipped.append(clipped[0]); _camera_marker.draw_polyline(clipped,Color("f6e4a4"),1.5,true)

func _polygon(points: Array, color: Color, fill: bool = true) -> void:
	if points.size() < 3: return
	var line := PackedVector2Array()
	for p: Vector3 in points: line.append(canvas.screen(p))
	if fill: _world_overlay.draw_colored_polygon(line,Color(color,0.17))
	line.append(line[0]); _world_overlay.draw_polyline(line,Color(color,0.7),1,true)

func _draw_overlays() -> void:
	var labels := {}
	if overlays.height or overlays.support:
		for face: Dictionary in model.get("faces",[]):
			var center := Vector3.ZERO
			for p: Vector3 in face.vertices: center += p
			center /= face.vertices.size()
			var fraction := inverse_lerp(_height_domain.x,_height_domain.y,center.y) if _height_domain.x != _height_domain.y else 0.5
			var color := Color.from_hsv(lerpf(0.65,0.0,fraction),0.6,0.9) if overlays.height else (Color("72deb5") if face.support else Color("df84a4"))
			_polygon(face.vertices,color)
			var at: Vector2 = canvas.screen(center)
			var bucket := Vector2i(floori(at.x/96),floori(at.y/48))
			# Sparse labels name their support. Prefer the nearer, higher sample
			# when parallel-projected centers share a label cell across two floors.
			if overlays.height and Rect2(Vector2.ZERO,canvas.size).has_point(at) and (not labels.has(bucket) or center.y > float(labels[bucket].height)):
				labels[bucket] = {"position":at,"height":center.y,"label":str(face.get("label",face.source_id))}
	for label: Dictionary in labels.values(): _world_overlay.draw_string(ThemeDB.fallback_font,label.position,str(label.label)+" · %.1f"%float(label.height),HORIZONTAL_ALIGNMENT_CENTER,-1,12,Color.WHITE)
	if overlays.blocking:
		for box: AABB in model.get("volumes",[]):
			for edge: Array in [[0,1],[0,2],[0,4],[1,3],[1,5],[2,3],[2,6],[3,7],[4,5],[4,6],[5,7],[6,7]]: _world_overlay.draw_line(canvas.screen(box.get_endpoint(edge[0])),canvas.screen(box.get_endpoint(edge[1])),Color("f29b8e"),1.5,true)
		for mass: Dictionary in model.get("prisms",[]):
			_polygon(mass.top,Color("f29b8e"),false)
			for p: Vector3 in mass.top:
				var base: float = mass.bottom_y if mass.has("bottom_y") else float(p.y)-float(mass.thickness_y)
				_world_overlay.draw_line(canvas.screen(p),canvas.screen(Vector3(p.x,base,p.z)),Color("f29b8e"),1,true)
	if overlays.connectors:
		for port: Dictionary in model.get("connectors",[]):
			var side := Vector3(-port.outward.z,0,port.outward.x)*float(port.width)*0.5
			_world_overlay.draw_line(canvas.screen(port.position-side),canvas.screen(port.position+side),Color("ffe298"),3,true)
			_world_overlay.draw_line(canvas.screen(port.position),canvas.screen(port.position+port.outward*24),Color("ffe298"),2,true)
	if not overlays.probes: return
	if not _probe_start.is_empty(): _world_overlay.draw_circle(canvas.screen(_probe_start.position),5,Color("ffe298"))
	if last_probe.is_empty(): return
	var at: Vector2 = canvas.screen(last_probe.from); var result: Dictionary = last_probe.result
	if last_probe.kind == "clearance":
		var radius: float = last_probe.profile.radius; var points := PackedVector2Array()
		for k: int in 49:
			var angle := TAU*k/48.0; points.append(canvas.screen(last_probe.from+Vector3(cos(angle)*radius,0,sin(angle)*radius)))
		_world_overlay.draw_polyline(points,Color("8ee6bb") if result.ok else Color("f28b82"),2,true)
		_world_overlay.draw_line(at,canvas.screen(last_probe.from+Vector3.UP*float(last_probe.profile.height)),Color("d8edff"),2,true)
	else:
		var blocked: bool = result.get("data",{}).get("hit",false)
		_world_overlay.draw_line(at,canvas.screen(last_probe.to),Color("f28b82") if blocked else Color("8ee6bb"),2,true)
		if blocked: _world_overlay.draw_circle(canvas.screen(result.data.position),5,Color("ffe298"))

func authoring_commands() -> Array[Dictionary]:
	var prefix := screen_id+"/viewport/"
	return [{"id":prefix+"inspect","parameters":{}},{"id":prefix+"focus_world","parameters":{"position_xyz":"number[3]","zoom":"number?"}},{"id":prefix+"focus_entity","parameters":{"entity_id":"string"}},{"id":prefix+"set_overlays","parameters":{"layers":"overlay:boolean dictionary"}},{"id":prefix+"search","parameters":{"query":"string"}},{"id":prefix+"set_probe","parameters":{"mode":"navigate|clearance|los","radius":"number","height":"number","surface_id":"string?"}},{"id":prefix+"probe_point","parameters":{"point":"WorldPoint"}},{"id":prefix+"probe_los","parameters":{"from":"WorldPoint","to":"WorldPoint"}}]

func ax_command(id: String, arguments: Dictionary = {}) -> Dictionary:
	var prefix := screen_id+"/viewport/"
	if not id.begins_with(prefix): return failure("action_missing")
	if _token != canvas.navigation_revision(): _refresh()
	match id.trim_prefix(prefix):
		"inspect":
			if not arguments.is_empty(): return failure("arguments_invalid")
			if _token != canvas.navigation_revision(): _refresh()
			return {"ok":true,"camera":canvas.camera_state(),"focus_y":_focus_y,"inspection_surface":canvas.inspection_surface,"overlays":overlays.duplicate(),"model":model.duplicate(true),"probe":last_probe.duplicate(true)}
		"focus_world":
			if not arguments.has("position_xyz") or not arguments.keys().all(func(key: Variant) -> bool: return key in ["position_xyz","zoom"]) or not vector_valid(arguments.position_xyz) or (arguments.has("zoom") and not (arguments.zoom is float or arguments.zoom is int)): return failure("arguments_invalid")
			return focus_world(vector(arguments.position_xyz),float(arguments.get("zoom",-1.0)))
		"focus_entity":
			if arguments.size() != 1 or not arguments.get("entity_id") is String: return failure("arguments_invalid")
			return focus_entity(arguments.entity_id)
		"set_overlays":
			if arguments.size() != 1 or not arguments.get("layers") is Dictionary: return failure("arguments_invalid")
			return set_overlays(arguments.layers)
		"search":
			if arguments.size() != 1 or not arguments.get("query") is String or arguments.query.length() > 256: return failure("arguments_invalid")
			_query.text = arguments.query; _refresh_entities(); return {"ok":true,"count":_entities.item_count}
		"set_probe":
			if arguments.size() < 3 or arguments.size() > 4 or not arguments.keys().all(func(key: Variant) -> bool: return key in ["mode","radius","height","surface_id"]) or arguments.get("mode") not in ["navigate","clearance","los"] or not (arguments.get("radius") is int or arguments.get("radius") is float) or not (arguments.get("height") is int or arguments.get("height") is float): return failure("arguments_invalid")
			if not is_finite(float(arguments.radius)) or not is_finite(float(arguments.height)) or arguments.radius < 0.1 or arguments.radius > 512 or arguments.height < 0.1 or arguments.height > 1024: return failure("arguments_invalid")
			if not arguments.get("surface_id","") is String: return failure("arguments_invalid")
			var surface_id: String = arguments.get("surface_id",""); var surface_index := 0
			if not surface_id.is_empty():
				surface_index = -1
				for index: int in _surface.item_count:
					if _surface.get_item_metadata(index) == surface_id: surface_index = index; break
				if surface_index < 0: return failure("unknown_surface")
			_mode.select(["navigate","clearance","los"].find(arguments.mode)); _probe_fields.visible = arguments.mode != "navigate"; _surface.select(surface_index); canvas.inspection_surface = surface_id; _radius.value = arguments.radius; _height.value = arguments.height; _probe_start.clear(); last_probe.clear(); _redraw_dynamic(); return {"ok":true}
		"probe_point":
			if arguments.size() != 1 or not arguments.get("point") is Dictionary: return failure("arguments_invalid")
			return probe_point(arguments.point)
		"probe_los":
			if arguments.size() != 2 or not arguments.get("from") is Dictionary or not arguments.get("to") is Dictionary: return failure("arguments_invalid")
			return probe_los(arguments.from,arguments.to)
	return failure("action_missing")

static func model_empty(compiled: bool = false) -> Dictionary:
	return {"compiled":compiled,"faces":[],"prisms":[],"volumes":[],"connectors":[],"entities":[],"slots":[],"routes":[],"_entity_index":{}}

static func bounds(points: Array) -> AABB:
	var box := AABB(points[0],Vector3.ZERO)
	for p: Vector3 in points: box = box.expand(p)
	return box

static func add_entity(data: Dictionary, kind: String, id: String, box: AABB, label: String = "") -> void:
	if not data.has("_entity_index"):
		data["_entity_index"] = {}
		for index: int in data.entities.size(): data._entity_index[data.entities[index].key] = index
	var key := kind+"/"+id
	if data._entity_index.has(key):
		var entity: Dictionary = data.entities[data._entity_index[key]]; entity.bounds = entity.bounds.merge(box); return
	var title: String = {"layer":"Camada","object":"Objeto","surface":"Apoio","instance":"Peça","slot":"Inimigo","route":"Rota","connector":"Conexão","volume":"Bloqueio","interaction":"Interação"}.get(kind,kind)
	data._entity_index[key] = data.entities.size()
	data.entities.append({"key":key,"id":id,"kind":kind,"label":str(title)+" · "+(id if label.is_empty() else label),"bounds":box})

static func finish_model(data: Dictionary) -> Dictionary:
	data.erase("_entity_index"); data.entities.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.key < b.key); return data

static func population_model(data: Dictionary, source: Dictionary, patrols: Dictionary = {}) -> Dictionary:
	for slot: Dictionary in source.get("slots",[]):
		var position := vector(slot.position_xyz); data.slots.append({"id":slot.slot_id,"position":position})
		add_entity(data,"slot",slot.slot_id,AABB(position-Vector3(8,0,8),Vector3(16,24,16)))
	for entry: Dictionary in source.get("interactions",[]):
		add_entity(data,"interaction",entry.interaction_id,AABB(vector(entry.position_xyz)-Vector3(8,0,8),Vector3(16,24,16)))
	for route: Dictionary in patrols.get("patrols",[]):
		var points: Array = []
		for waypoint: Dictionary in route.waypoints: points.append(vector(waypoint.position_xyz))
		if points.is_empty(): continue
		add_entity(data,"route",route.patrol_id,bounds(points))
		if route.mode == "loop" and points.size() > 1: points.append(points[0])
		data.routes.append({"id":route.patrol_id,"points":points})
	return finish_model(data)

static func source_hidden(id: String, source: Dictionary, hidden: Array) -> bool:
	if id in hidden: return true
	for special: Dictionary in source.get("special_surfaces",[]):
		if special.surface_id == id: return special.layer_id in hidden
	return false

static func add_object(data: Dictionary, object: Dictionary) -> void:
	var radius: float = object.definition.footprint_radius; var height: float = object.definition.world_height
	var box := AABB(object.position-Vector3(radius,0,radius),Vector3(radius*2,height,radius*2))
	add_entity(data,"object",object.placement_id,box,object.definition.name+" · "+object.placement_id)

static func terrain_model(source: Dictionary, shape: Dictionary, objects: Array, hidden: Array, package: Dictionary) -> Dictionary:
	var data := model_empty(not package.is_empty())
	for visual: Dictionary in shape.get("visuals",[]):
		if source_hidden(visual.source_id,source,hidden): continue
		data.faces.append({"id":visual.surface_id,"source_id":visual.source_id,"vertices":visual.vertices,"support":visual.walkable})
		data.prisms.append(Terrain._mass(visual))
		var box := bounds(visual.vertices)
		var layer_id: String = visual.source_id
		for special: Dictionary in source.get("special_surfaces",[]):
			if special.surface_id == visual.source_id:
				layer_id = special.layer_id; add_entity(data,"surface",special.surface_id,box); break
		add_entity(data,"layer",layer_id,box); add_entity(data,"surface",visual.surface_id,box)
	for object: Dictionary in objects:
		if object.get("editor_state",{}).get("hidden",false) or source_hidden(object.source_surface_id,source,hidden): continue
		add_object(data,object)
	for port: Dictionary in source.get("connectors",[]):
		if source_hidden(port.surface_id,source,hidden): continue
		var position := vector(port.position_xyz); var outward := vector(port.normal_xyz)
		data.connectors.append({"id":port.connector_id,"position":position,"outward":outward,"width":port.width,"headroom":port.headroom,"direction":port.direction})
		var side := Vector3(-outward.z,0,outward.x)*float(port.width)*0.5
		add_entity(data,"connector",port.connector_id,bounds([position-side,position+side,position+Vector3.UP*float(port.headroom)]))
	if not package.is_empty(): data.volumes = package.part.solid_volumes; data.prisms = package.part.solid_prisms
	return finish_model(data)

static func map_model(package: Dictionary, world: WorldGeometry) -> Dictionary:
	var data := model_empty(not package.is_empty() and world != null)
	if not data.compiled: return finish_model(data)
	var stage: Dictionary = world._stage; var supports := {}; var labels := {}
	for instance: Dictionary in package.render_instances:
		for visual: Dictionary in instance.visuals: labels[instance.instance_id+"/"+str(visual.surface_id)] = instance.instance_id+" · "+str(visual.source_id)
	for cell: Dictionary in stage.surfaces:
		var label: String = labels.get(cell.surface_id,cell.surface_id)
		data.faces.append({"id":cell.surface_id,"source_id":cell.surface_id,"label":label,"vertices":cell.vertices,"support":true}); supports[cell.surface_id] = true
		var box := bounds(cell.vertices); add_entity(data,"surface",cell.surface_id,box,label); add_entity(data,"instance",cell.surface_id.get_slice("/",0),box)
	data.prisms = stage.get("solid_prisms",[]); data.volumes = stage.volumes.duplicate()
	for id: String in world._temporary:
		data.volumes.append(world._temporary[id]); add_entity(data,"volume","temporary/"+id,world._temporary[id])
	for mass: Dictionary in data.prisms:
		if not supports.has(mass.support_surface_id): data.faces.append({"id":mass.volume_id,"source_id":mass.volume_id,"vertices":mass.top,"support":false})
		add_entity(data,"volume",mass.volume_id,bounds(mass.top))
	for index: int in data.volumes.size(): add_entity(data,"volume","aabb/"+str(index),data.volumes[index])
	for instance: Dictionary in package.render_instances:
		for object: Dictionary in instance.get("objects",[]): add_object(data,object)
	for object: Dictionary in package.border_geometry.props: add_object(data,object)
	for port: Dictionary in package.get("logical_ports",[]):
		data.connectors.append({"id":port.port_id,"position":port.position,"outward":port.outward,"width":port.width,"headroom":port.headroom,"direction":port.direction})
		var side := Vector3(-port.outward.z,0,port.outward.x)*float(port.width)*0.5
		add_entity(data,"connector",port.port_id,bounds([port.position-side,port.position+side,port.position+Vector3.UP*float(port.headroom)]))
	return finish_model(data)
