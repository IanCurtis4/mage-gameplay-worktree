class_name SentinelProjectile
extends PlayerProjectile
## Kit silhouette only. Continuous collision and damage remain canonical.

func _draw() -> void:
	var id := request.skill_id if request != null else &""
	if id == &"sentinel_headshot":
		draw_line(Vector2(-24, 0), Vector2(14, 0), Color("d7f0de"), 2.0)
		draw_line(Vector2(-9, 0), Vector2(14, 0), Color.WHITE, 1.0)
		draw_polyline(PackedVector2Array([Vector2(5, -3), Vector2(14, 0), Vector2(5, 3)]), Color("d7f0de"), 2.0)
	elif id == &"sentinel_piercing_shot":
		draw_line(Vector2(-32, 0), Vector2(14, 0), Color("a6e3ee"), 2.0)
		draw_line(Vector2(-17, -3), Vector2(6, -3), Color("69a6af"), 1.0)
		draw_line(Vector2(-17, 3), Vector2(6, 3), Color("69a6af"), 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(7, -5), Vector2(10, 0), Vector2(7, 5)]), Color.WHITE)
	elif id == &"sentinel_net_shot":
		draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 16, Color("bddfd1"), 1.5)
		draw_line(Vector2(-6, -6), Vector2(6, 6), Color.WHITE, 1.0)
		draw_line(Vector2(-6, 6), Vector2(6, -6), Color.WHITE, 1.0)
	elif id == &"sentinel_explosive_shot":
		draw_line(Vector2(-20, 0), Vector2(11, 0), Color("ffbf69"), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(13, 0), Vector2(6, -6), Vector2(3, 0), Vector2(6, 6)]), Color("ffda96"))
	elif id == &"sentinel_concussion_shot":
		draw_line(Vector2(-17, 0), Vector2(7, 0), Color("d7f0de"), 2.0)
		draw_circle(Vector2(10, 0), 5.0, Color("eedb9f"))
		draw_arc(Vector2(10, 0), 8.0, -PI * 0.45, PI * 0.45, 12, Color("d7f0de"), 1.5)
	else:
		super._draw()
