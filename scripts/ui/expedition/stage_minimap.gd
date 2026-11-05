class_name StageMinimap
extends PanelContainer

signal zoom_requested(step: int)
signal zoom_reset_requested

const MAP_SIZE := 216.0
const MARGIN := 10.0

class MapBackground extends Control:
	var bounds := Rect2()
	var surfaces: Array[PackedVector2Array] = []
	var obstacles: Array[PackedVector2Array] = []
	var terrain_mesh: ArrayMesh

	func set_terrain(value: Dictionary) -> void:
		terrain_mesh = null
		var vertices: PackedVector2Array = value.get("vertices",PackedVector2Array())
		var colors: PackedColorArray = value.get("colors",PackedColorArray())
		if vertices.size() < 3 or vertices.size() != colors.size(): return
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_COLOR] = colors
		terrain_mesh = ArrayMesh.new()
		terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("161e26"))
		if terrain_mesh != null:
			var extent := maxf(bounds.size.x,bounds.size.y)
			var factor := maxf(0.0,minf(size.x,size.y)-2.0*StageMinimap.MARGIN)/maxf(0.000001,extent)
			draw_set_transform(StageMinimap.map_point(bounds,Vector2.ZERO,size),0.0,Vector2.ONE*factor)
			draw_mesh(terrain_mesh,null)
			draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
		else:
			for polygon in surfaces: _draw_shape(polygon, Color("667b74"))
		for polygon in obstacles:
			_draw_shape(polygon, Color("303b42"))

	func _draw_shape(polygon: PackedVector2Array, color: Color) -> void:
		if polygon.size() < 3:
			return
		var points := PackedVector2Array()
		for point in polygon:
			points.append(StageMinimap.map_point(bounds, point, size))
		draw_colored_polygon(points, color)

class MapMarkers extends Control:
	var bounds := Rect2()
	var player := Vector2.ZERO
	var heading := Vector2.UP
	var enemies := PackedVector2Array()
	var has_player := false

	func _draw() -> void:
		for point in enemies:
			var center := StageMinimap.map_point(bounds, point, size)
			draw_circle(center, 4.0, Color("111820"))
			draw_circle(center, 2.7, Color("ff4848"))
		if has_player:
			var center := StageMinimap.map_point(bounds, player, size)
			var direction := heading.normalized()
			var side := Vector2(-direction.y, direction.x)
			var triangle := PackedVector2Array([center + direction * 8.0, center - direction * 5.0 + side * 5.0, center - direction * 5.0 - side * 5.0])
			draw_colored_polygon(triangle, Color("ffd65a"))
			draw_polyline(PackedVector2Array([triangle[0], triangle[1], triangle[2], triangle[0]]), Color("101820"), 2.0, true)

var _background: MapBackground
var _markers: MapMarkers
var _zoom_out: Button
var _zoom_reset: Button
var _zoom_in: Button
var _zoom_enabled := true

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = "Mapa"
	column.add_child(title)
	var centering := CenterContainer.new()
	column.add_child(centering)
	_background = MapBackground.new()
	_background.name = "Map"
	_background.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_background.clip_contents = true
	_background.tooltip_text = "Mapa inteiro. Verde: terreno caminhável; cobre: íngreme; escuro: bloqueio.\nRelevo claro indica maior altura. Passagens ainda dependem do corpo e da rota.\nVermelho: inimigos vivos; dourado: você. Roda sobre o cenário: zoom."
	centering.add_child(_background)
	_markers = MapMarkers.new()
	_markers.name = "Markers"
	_markers.mouse_filter = Control.MOUSE_FILTER_STOP
	_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.add_child(_markers)
	var legend := Label.new()
	legend.text = "▲ Você   ● Inimigos"
	legend.add_theme_font_size_override("font_size", 12)
	column.add_child(legend)
	var terrain_legend := Label.new()
	terrain_legend.text = "Verde: chão · Cobre: íngreme"
	terrain_legend.add_theme_font_size_override("font_size",11)
	column.add_child(terrain_legend)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(controls)
	_zoom_out = _make_button("−", "Afastar câmera", controls)
	_zoom_reset = _make_button("100%", "Restaurar zoom da câmera", controls)
	_zoom_reset.custom_minimum_size.x = 88.0
	_zoom_in = _make_button("+", "Aproximar câmera", controls)
	_zoom_out.pressed.connect(func() -> void: zoom_requested.emit(-1))
	_zoom_reset.pressed.connect(func() -> void: zoom_reset_requested.emit())
	_zoom_in.pressed.connect(func() -> void: zoom_requested.emit(1))

func _make_button(caption: String, hint: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = caption
	button.tooltip_text = hint
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(42.0, 32.0)
	parent.add_child(button)
	return button

# Uniformly fits the complete bounds, including degenerate axes, within the square.
static func map_point(bounds: Rect2, point: Vector2, canvas_size: Vector2) -> Vector2:
	var rect := bounds.abs()
	var side := maxf(0.0, minf(canvas_size.x, canvas_size.y))
	var extent := maxf(rect.size.x, rect.size.y)
	var scale_factor := maxf(0.0, side - 2.0 * MARGIN) / extent if extent > 0.000001 else 0.0
	return canvas_size * 0.5 + (point - rect.get_center()) * scale_factor

func configure_map(bounds: Rect2, surfaces: Array[PackedVector2Array], obstacles: Array[PackedVector2Array], terrain: Dictionary = {}) -> void:
	_background.bounds = bounds
	_background.surfaces = surfaces.duplicate(true)
	_background.obstacles = obstacles.duplicate(true)
	_background.set_terrain(terrain)
	_markers.bounds = bounds
	_markers.enemies = PackedVector2Array()
	_markers.has_player = false
	_markers.heading = Vector2.UP
	_background.queue_redraw()
	_markers.queue_redraw()

func update_markers(player_point: Vector2, player_heading: Vector2, enemies: PackedVector2Array) -> void:
	_markers.player = player_point
	if player_heading.length_squared() > 0.000001:
		_markers.heading = player_heading.normalized()
	_markers.enemies = enemies.duplicate()
	_markers.has_player = true
	_markers.queue_redraw()

## Temporary geometry changes replace only the obstacle overlay. The terrain
## mesh remains the same GPU resource until the stage is reconfigured.
func update_obstacles(obstacles: Array[PackedVector2Array]) -> void:
	_background.obstacles = obstacles.duplicate(true)
	_background.queue_redraw()

func set_camera_zoom(value: float) -> void:
	_zoom_reset.text = "%d%%" % roundi(value * 100.0)

func set_zoom_enabled(value: bool) -> void:
	_zoom_enabled = value
	_zoom_out.disabled = not value
	_zoom_reset.disabled = not value
	_zoom_in.disabled = not value
