extends RefCounted
## Read-only per-occurrence palette; never alters shared atlas resources.
const WOLF = preload("res://assets/art/animations/e08_forest_wolf.png")
const BOAR = preload("res://assets/art/animations/e08_forest_boar.png")

static func install_forest_atlas(actor: Variant) -> bool:
	if actor.occurrence == null or actor.character_animation == null: return false
	var texture: Texture2D
	var id := ""
	match actor.occurrence.mob_base_id:
		&"forest_wolf": texture = WOLF;id="e08_forest_wolf"
		&"forest_boar": texture = BOAR;id="e08_forest_boar"
		_: return true
	var installed := install_directional_or_legacy(actor.character_animation,DirectionalAnimationSet.default_path(StringName(id)),texture)
	if installed: actor.queue_redraw()
	return installed

static func install_directional_or_legacy(animation: CharacterAnimation,path: String,legacy: Texture2D) -> bool:
	# The specific species falls back as a complete V1 body, never generic fox art.
	if FileAccess.file_exists(path) and animation.set_directional_manifest(path).ok:return true
	return animation.set_body_atlas(legacy)

static func forest_tint(actor: Node) -> Color:
	if not actor.has_method("configure_occurrence"): return Color.WHITE
	var occurrence: Variant = actor.get("occurrence")
	if occurrence == null: return Color.WHITE
	match occurrence.mob_base_id:
		&"forest_stalker": return Color(0.58, 0.70, 0.59)
		&"forest_canopy_archer": return Color(0.77, 0.91, 0.73)
		&"forest_ancient_warden": return Color(0.69, 0.85, 0.66)
	return Color.WHITE
