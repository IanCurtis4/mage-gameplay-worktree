extends RefCounted
## Read-only per-occurrence palette and catalog-driven species body (E08 P5 A1).
## Never alters shared atlas resources and adds no actor/save/snapshot field:
## everything is derived from occurrence.mob_base_id + the installed atlas path.
const Species = preload("res://scripts/presentation/species_presentation_catalog.gd")

# Test-only seam (visual_id -> explicit manifest path). Always empty in the game;
# lets tests point a species at a fixture without writing into assets/.
static var _manifest_overrides: Dictionary = {}

static func has_species_presentation(mob_base_id: StringName) -> bool:
	return Species.has(mob_base_id)

static func manifest_path(visual_id: StringName) -> String:
	var override: Variant = _manifest_overrides.get(visual_id)
	return String(override) if override is String else DirectionalAnimationSet.default_path(visual_id)

static func set_manifest_override_for_tests(visual_id: StringName, path: String) -> void:
	if path.is_empty(): _manifest_overrides.erase(visual_id)
	else: _manifest_overrides[visual_id] = path

static func install_forest_atlas(actor: Variant) -> bool:
	if actor.occurrence == null or actor.character_animation == null: return false
	var id: StringName = actor.occurrence.mob_base_id
	if not Species.has(id): return true
	var path := manifest_path(Species.visual_id(id))
	var legacy := Species.legacy_atlas(id)
	if legacy != null:
		# Species with an own V1 atlas (wolf/boar): specific V2, else complete V1.
		var installed := install_directional_or_legacy(actor.character_animation,path,legacy)
		if installed: actor.queue_redraw()
		return installed
	return _install_species_body(actor,path)

static func install_directional_or_legacy(animation: CharacterAnimation,path: String,legacy: Texture2D) -> bool:
	# The specific species falls back as a complete V1 body, never generic fox art.
	if FileAccess.file_exists(path) and animation.set_directional_manifest(path).ok:return true
	return animation.set_body_atlas(legacy)

## Species without own V1 atlas: the generic body of its animation_kind stays
## untouched unless a complete, valid unit of the same kind exists. Never partial.
static func _install_species_body(actor: Variant, path: String) -> bool:
	var animation: CharacterAnimation = actor.character_animation
	# Reserved visual_id without installed unit: current generic body and tint.
	if not FileAccess.file_exists(path): return true
	var loaded := DirectionalAnimationSet.load_manifest(path)
	if not loaded.ok or (loaded.bundle as DirectionalAnimationSet).actor_kind() != animation.actor_kind:
		push_warning("Species presentation rejected; keeping complete generic body: "+path+" "+str(loaded.get("detail","kind mismatch")))
		return true
	# The body is selected without any player equipment contract, then the NPC
	# projection is derived anew (embedded weapon => none).
	animation.set_equipment_visual({})
	var applied := animation.set_directional_manifest(path)
	if actor.has_method("sync_npc_equipment_visual"): actor.sync_npc_equipment_visual()
	if not applied.ok:
		push_warning("Species presentation rejected; keeping complete generic body: "+path)
		return true
	actor.queue_redraw()
	return true

## True when the animation currently draws the valid V2 unit of this species.
static func owns_species_body(animation: CharacterAnimation, mob_base_id: StringName) -> bool:
	if animation == null or animation.atlas == null or animation.atlas.get_size() != DirectionalAnimationSet.SIZE: return false
	var raw: Variant = Species.ENTRIES.get(mob_base_id)
	if not raw is Dictionary or DirectionalAnimationSet.for_texture(animation.atlas) == null: return false
	return animation.atlas.resource_path.get_base_dir() == manifest_path(StringName(raw["visual_id"])).get_base_dir()

## The installed species body already carries its weapon: no dynamic projection.
static func has_embedded_weapon_body(actor: Variant) -> bool:
	var occurrence: Variant = actor.get("occurrence")
	if occurrence == null: return false
	var id: StringName = occurrence.mob_base_id
	return Species.embedded_weapon(id) and owns_species_body(actor.get("character_animation"),id)

static func forest_tint(actor: Node) -> Color:
	if not actor.has_method("configure_occurrence"): return Color.WHITE
	var occurrence: Variant = actor.get("occurrence")
	if occurrence == null: return Color.WHITE
	var raw: Variant = Species.ENTRIES.get(occurrence.mob_base_id)
	if not raw is Dictionary: return Color.WHITE
	var tint: Color = raw["fallback_tint"]
	# An own painted body is final art: the generic-body palette is not doubled.
	if tint == Color.WHITE or owns_species_body(actor.get("character_animation"),occurrence.mob_base_id): return Color.WHITE
	return tint
