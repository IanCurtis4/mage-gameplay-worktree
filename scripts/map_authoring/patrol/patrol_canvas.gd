@tool
extends "res://scripts/map_authoring/population/population_canvas.gd"
var patrol_source: Dictionary = {}
var selected_route := ""
var actors: Array = []
var player_point: Dictionary = {}
func _draw_world() -> void:
	super._draw_world()
	if package.is_empty(): return
	for route: Dictionary in patrol_source.get("patrols",[]):
		var color := Color("bcebc1") if route.patrol_id == selected_route else Color("b8c5ff")
		var path := PackedVector2Array()
		for i: int in route.waypoints.size():
			var waypoint: Dictionary = route.waypoints[i]
			var at := screen(Population.vector(waypoint.position_xyz)); path.append(at)
			_overlay.draw_circle(at,5,color)
			_overlay.draw_string(ThemeDB.fallback_font,at+Vector2(7,16),"%d · %.1fs"%[i+1,waypoint.wait_seconds],HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
		if path.size() > 1:
			if route.mode == "loop": path.append(path[0])
			_overlay.draw_polyline(path,color,2,true)
	for actor: Dictionary in actors:
		var at := screen(actor.position); _overlay.draw_circle(at,8,Color("f6bc76"))
		_overlay.draw_string(ThemeDB.fallback_font,at+Vector2(10,-10),actor.label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
	if not player_point.is_empty(): _overlay.draw_circle(screen(player_point.position),8,Color("68d9f7"))
