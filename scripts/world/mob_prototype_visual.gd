class_name MobPrototypeVisual
extends RefCounted
## Original vector placeholders; no borrowed creature sprites.
var kind: StringName
var category: StringName
static func category_name(id: StringName) -> String:
	return {&"normal":"Normal", &"rare":"Raro", &"elite":"Elite", &"rare_elite":"Elite raro", &"boss":"Chefe"}.get(id, String(id))
func draw_on(actor: CombatActor) -> void:
	var tier := MobCatalog.CATEGORIES.find(category)
	var size := actor.sprite_visual_scale
	var color: Color = [Color("85dab5"), Color("60bde0"), Color("e6ba61"), Color("ba88dc"), Color("eb858f")][tier]
	actor.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * size)
	if kind == &"gel":
		var body := PackedVector2Array([Vector2(-23,-1),Vector2(-26,-14),Vector2(-18,-32),Vector2(-3,-40),Vector2(13,-33),Vector2(25,-13),Vector2(20,-1)])
		actor.draw_colored_polygon(body, Color(color, 0.78))
		var outline := body.duplicate()
		outline.append(body[0])
		actor.draw_polyline(outline, color.lightened(0.35), 1.5 + tier * 0.35, true)
		actor.draw_circle(Vector2(0,-19), 7.0, color.darkened(0.38))
		actor.draw_circle(Vector2(-3,-21), 2.5, Color("effff8"))
		actor.draw_line(Vector2(-15,-25),Vector2(-10,-30),Color("effff8"),2.0,true)
	else:
		actor.draw_circle(Vector2(-7,-15), 16, Color("947660"))
		actor.draw_circle(Vector2(13,-25), 11, Color("b09676"))
		actor.draw_colored_polygon(PackedVector2Array([Vector2(5,-31),Vector2(8,-46),Vector2(16,-33)]),Color("806147"))
		actor.draw_colored_polygon(PackedVector2Array([Vector2(15,-32),Vector2(23,-45),Vector2(23,-29)]),Color("806147"))
		actor.draw_line(Vector2(-23,-17),Vector2(-34,-25),Color("947660"),6,true)
		for x: float in [-14.0, -2.0, 10.0]: actor.draw_line(Vector2(x,-9),Vector2(x+2,0),Color("806147"),5,true)
		actor.draw_circle(Vector2(18,-25),2,Color("151e20"))
	actor.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	actor.draw_string(ThemeDB.fallback_font, Vector2(-36,17), category_name(category), HORIZONTAL_ALIGNMENT_CENTER, 72, 12, color.lightened(0.3))
