extends RefCounted
## Immutable species presentation catalog (E08 P5 A1), keyed by mob_base_id.
## Code-only on purpose: the export filter does not ship new JSON paths.
## Presentation only: never read by gameplay, never stored in saves/snapshots.
## visual_id: directional unit at DirectionalAnimationSet.default_path(visual_id).
## legacy_atlas: complete V1 body of this exact species ("" = none; then the
##   generic body of MobDefinition.animation_kind remains the fallback).
## fallback_tint: per-occurrence palette applied only while the species does
##   NOT draw its own V2 body (an own painted body never gets a second tint).
## embedded_weapon: the own body already contains its weapon; no projection.

# Preloads keep the V1 species atlases as explicit export dependencies.
const _LEGACY_ATLASES := [
	preload("res://assets/art/animations/e08_forest_wolf.png"),
	preload("res://assets/art/animations/e08_forest_boar.png"),
]

const ENTRIES := {
	&"forest_wolf": {"visual_id": &"e08_forest_wolf", "legacy_atlas": "res://assets/art/animations/e08_forest_wolf.png", "fallback_tint": Color(1.0, 1.0, 1.0, 1.0), "embedded_weapon": false},
	&"forest_boar": {"visual_id": &"e08_forest_boar", "legacy_atlas": "res://assets/art/animations/e08_forest_boar.png", "fallback_tint": Color(1.0, 1.0, 1.0, 1.0), "embedded_weapon": false},
	&"forest_stalker": {"visual_id": &"e08_forest_stalker", "legacy_atlas": "", "fallback_tint": Color(0.58, 0.70, 0.59), "embedded_weapon": false},
	&"forest_canopy_archer": {"visual_id": &"e08_forest_canopy_archer", "legacy_atlas": "", "fallback_tint": Color(0.77, 0.91, 0.73), "embedded_weapon": true},
	&"forest_ancient_warden": {"visual_id": &"e08_forest_warden", "legacy_atlas": "", "fallback_tint": Color(0.69, 0.85, 0.66), "embedded_weapon": false},
}

static func has(mob_base_id: StringName) -> bool:
	return ENTRIES.has(mob_base_id)

## Detached, sorted copy; editing it cannot alter the catalog.
static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in ENTRIES: result.append(id)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result

## Detached deep copy ({} when absent).
static func entry(mob_base_id: StringName) -> Dictionary:
	var raw: Variant = ENTRIES.get(mob_base_id)
	return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}

static func visual_id(mob_base_id: StringName) -> StringName:
	var raw: Variant = ENTRIES.get(mob_base_id)
	return StringName(raw["visual_id"]) if raw is Dictionary else &""

static func legacy_atlas(mob_base_id: StringName) -> Texture2D:
	var raw: Variant = ENTRIES.get(mob_base_id)
	if not raw is Dictionary or String(raw["legacy_atlas"]).is_empty(): return null
	return load(String(raw["legacy_atlas"])) as Texture2D

static func fallback_tint(mob_base_id: StringName) -> Color:
	var raw: Variant = ENTRIES.get(mob_base_id)
	return raw["fallback_tint"] if raw is Dictionary else Color.WHITE

static func embedded_weapon(mob_base_id: StringName) -> bool:
	var raw: Variant = ENTRIES.get(mob_base_id)
	return bool(raw["embedded_weapon"]) if raw is Dictionary else false
