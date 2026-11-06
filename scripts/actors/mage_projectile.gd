class_name MageProjectile
extends PlayerProjectile
## Mage-specific impact modifiers and presentation over shared projectile collision.

var electrified_bonus_magic_damage := 0.0

func _init() -> void:
	projectile_radius = 6.0

func _prepare_impact(victim: CombatActor) -> void:
	super._prepare_impact(victim)
	if request.skill_id == &"fireball" and victim.is_burning():
		request.force_critical = true
	elif request.skill_id == &"fire_spear" and victim.is_burning():
		request.magic_damage *= 1.5
	elif request.skill_id == &"electric_discharge" and victim.is_electrified():
		request.magic_damage += electrified_bonus_magic_damage

func _draw() -> void:
	if request != null and request.skill_id in [&"lightning", &"electric_discharge"]:
		var bolt := PackedVector2Array([Vector2(-18, -5), Vector2(-8, 2), Vector2(-2, -5), Vector2(5, 3), Vector2(16, 0)])
		draw_polyline(bolt, Color(color, 0.25), 7.0, true)
		draw_polyline(bolt, color, 3.0, true)
		draw_polyline(bolt, Color(1, 1, 1, 0.85), 1.0, true)
		return
	if request != null and request.skill_id in [&"fire_spear", &"ice_spear"]:
		draw_colored_polygon(PackedVector2Array([Vector2(-24, 0), Vector2(-10, -6), Vector2(8, -6), Vector2(20, 0), Vector2(8, 6), Vector2(-10, 6)]), Color(color, 0.20))
		draw_colored_polygon(PackedVector2Array([Vector2(-19, -3), Vector2(5, -4), Vector2(16, 0), Vector2(5, 4), Vector2(-19, 3)]), color)
		draw_line(Vector2(-13, 0), Vector2(9, 0), color.lightened(0.65), 2.0)
		return
	draw_circle(Vector2.ZERO, projectile_radius + 2.0, Color(color, 0.25))
	draw_circle(Vector2.ZERO, projectile_radius, color)
	draw_circle(Vector2(-1, -1), projectile_radius * 0.42, color.lightened(0.7))
	draw_line(Vector2(-15, 0), Vector2(-5, 0), Color(color, 0.45), 3.0)
