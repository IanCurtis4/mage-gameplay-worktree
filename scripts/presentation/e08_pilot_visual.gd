extends RefCounted
## Read-only per-occurrence palette; never alters shared atlas resources.
static func forest_tint(actor: Node) -> Color:
	if not actor.has_method("configure_occurrence"): return Color.WHITE
	var occurrence: Variant = actor.get("occurrence")
	if occurrence == null: return Color.WHITE
	match occurrence.mob_base_id:
		&"forest_wolf": return Color(0.77, 0.84, 0.90)
		&"forest_boar": return Color(0.75, 0.58, 0.45)
		&"forest_stalker": return Color(0.58, 0.70, 0.59)
		&"forest_canopy_archer": return Color(0.77, 0.91, 0.73)
		&"forest_ancient_warden": return Color(0.69, 0.85, 0.66)
	return Color.WHITE
