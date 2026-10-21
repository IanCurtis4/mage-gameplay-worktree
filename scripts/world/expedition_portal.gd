class_name ExpeditionPortal
extends Node2D
## Presentation adapter: all eligibility, geometry and revisions live in the service.
var portal_id := ""
var kind := "travel"
var open := false
var anchor: ExpeditionWorldPoint

func configure(view: Dictionary) -> void:
	portal_id = view["portal_id"]
	kind = view["kind"]
	open = view["open"]
	anchor = ExpeditionPopulationPlanner.point(view["from_anchor"])
	position = ExpeditionGeometryView.project(anchor.position)
	queue_redraw()

func _draw() -> void:
	var color := Color("6ddac2") if open else Color("706b81")
	draw_arc(Vector2(0, -18), 24, PI, TAU, 24, color, 4)
	draw_line(Vector2(-24, -18), Vector2(-24, 10), color, 4)
	draw_line(Vector2(24, -18), Vector2(24, 10), color, 4)
