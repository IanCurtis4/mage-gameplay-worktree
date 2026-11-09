class_name FeedbackRecipeCatalog
extends RefCounted
## E08 P6 presentation recipes: skill_id -> delivery family, element, signature and
## planned audio cues. Constant private data; every accessor returns a copy.
## Presentation only: never read by damage, AI, timing, RNG, save or snapshot code.
const Audio = preload("res://scripts/presentation/audio_event_catalog.gd")

const FAMILIES: Array[StringName] = [&"cast", &"projectile", &"melee", &"impact", &"area", &"trap", &"buff", &"heal", &"movement", &"summon", &"charge", &"teleport", &"death", &"revive"]
const ELEMENTS: Array[StringName] = [&"physical", &"fire", &"ice", &"lightning", &"arcane", &"spirit", &"nature", &"geometry", &"blood"]

## Flags (bit field, index 3 of each row).
const COMMIT := 1   ## The bridge publishes `effect_start` when the skill use is committed.
const PERIODIC := 2 ## Repeated damage ticks (DOT/maintenance); audio uses the quieter dot cue.

## [family, element, signature_id, flags]. Signature ids are listed in SIGNATURES.
const RECIPES := {
	# Swordsman
	&"slash": [&"melee", &"physical", &"swordsman_slash", 0],
	&"cone_slash": [&"melee", &"physical", &"swordsman_slash", 0], # Damage id of slash hits.
	&"dash": [&"movement", &"physical", &"", 0],
	&"shield_wall": [&"buff", &"physical", &"", COMMIT],
	&"provoke": [&"buff", &"physical", &"", COMMIT],
	&"perseverance": [&"buff", &"physical", &"", COMMIT],
	&"piercing_shout": [&"buff", &"physical", &"", COMMIT],
	&"fury": [&"buff", &"blood", &"", COMMIT],
	&"brutal_strike": [&"melee", &"physical", &"", 0],
	&"concentrated_rage": [&"melee", &"physical", &"", 0],
	&"terrifying_shout": [&"buff", &"physical", &"swordsman_terrifying_shout", COMMIT],
	# Mage
	&"fireball": [&"projectile", &"fire", &"mage_fireball", 0],
	&"fire_wall": [&"area", &"fire", &"", 0],
	&"fire_spear": [&"projectile", &"fire", &"", 0],
	&"ice_spear": [&"projectile", &"ice", &"", 0],
	&"lightning": [&"projectile", &"lightning", &"", 0],
	&"electric_discharge": [&"projectile", &"lightning", &"", 0],
	&"lightning_wall": [&"area", &"lightning", &"", 0],
	&"soul_impact": [&"impact", &"spirit", &"", COMMIT],
	&"haunt": [&"area", &"spirit", &"", COMMIT],
	&"phantom_barrier": [&"area", &"spirit", &"", 0],
	&"ice_wall": [&"area", &"ice", &"", 0],
	&"teleport": [&"teleport", &"arcane", &"mage_teleport", 0],
	&"burn_tick": [&"impact", &"fire", &"", PERIODIC],
	# Archer
	&"double_shot": [&"projectile", &"physical", &"", 0],
	&"piercing_arrow": [&"projectile", &"physical", &"", 0],
	&"arrow_rain": [&"area", &"physical", &"archer_arrow_rain", 0],
	&"extended_aim": [&"buff", &"physical", &"", COMMIT],
	&"snare_trap": [&"trap", &"nature", &"", 0],
	&"explosive_trap": [&"trap", &"fire", &"archer_explosive_trap", 0],
	&"slowing_arrow": [&"projectile", &"nature", &"", 0],
	&"foliage_shelter": [&"area", &"nature", &"", 0],
	# Defender
	&"defender_counterstroke": [&"melee", &"physical", &"defender_counterstroke", 0],
	&"defender_anchor": [&"buff", &"physical", &"", COMMIT],
	&"defender_line_lock": [&"melee", &"physical", &"", 0],
	&"defender_wall_advance": [&"movement", &"physical", &"", 0],
	&"defender_reprisal_wave": [&"area", &"physical", &"defender_reprisal_wave", COMMIT],
	&"defender_riposte": [&"melee", &"physical", &"", 0],
	&"defender_retreat_guard": [&"movement", &"physical", &"", 0],
	# Berserker
	&"berserker_rupture": [&"melee", &"blood", &"", 0],
	&"berserker_rupture_detonation": [&"impact", &"blood", &"", 0],
	&"berserker_wound_leap": [&"movement", &"blood", &"berserker_wound_leap", 0],
	&"berserker_execution": [&"melee", &"blood", &"", 0],
	&"berserker_blood_rift": [&"area", &"blood", &"berserker_blood_rift", 0],
	&"berserker_blood_rift_tick": [&"impact", &"blood", &"", PERIODIC],
	&"berserker_breath_steal": [&"melee", &"blood", &"", 0],
	&"berserker_pursuit_cut": [&"melee", &"blood", &"", 0],
	&"bleed_tick": [&"impact", &"blood", &"", PERIODIC],
	&"blood_thirst": [&"heal", &"blood", &"", 0], # Passive kill heal (heal source only).
	# Elementalist (pulses may override the element through payload.element)
	&"elementalist_flame_burst": [&"area", &"fire", &"", COMMIT],
	&"elementalist_glacial_ring": [&"area", &"ice", &"", COMMIT],
	&"elementalist_lightning_arc": [&"impact", &"lightning", &"elementalist_lightning_arc", COMMIT],
	&"elementalist_ember_path": [&"area", &"fire", &"", COMMIT],
	&"elementalist_tri_nova": [&"area", &"arcane", &"elementalist_tri_nova", COMMIT],
	# Spiritualist
	&"spiritualist_echo_curse": [&"impact", &"spirit", &"", COMMIT],
	&"spiritualist_soul_drain": [&"impact", &"spirit", &"", 0],
	&"spiritualist_spectral_veil": [&"area", &"spirit", &"", COMMIT],
	&"spiritualist_procession": [&"impact", &"spirit", &"", COMMIT],
	&"spiritualist_dissipation": [&"area", &"spirit", &"spiritualist_dissipation", COMMIT],
	# Geometer (construction edits are casts; vertex elements may override)
	&"geometer_trace": [&"projectile", &"geometry", &"", 0],
	&"geometer_translation": [&"cast", &"geometry", &"", COMMIT],
	&"geometer_triangulation": [&"projectile", &"geometry", &"geometer_triangulation", 0],
	&"geometer_collapse": [&"area", &"geometry", &"geometer_collapse", COMMIT],
	&"geometer_rewrite": [&"cast", &"geometry", &"", COMMIT],
	&"geometer_triangle_maintenance": [&"impact", &"geometry", &"", PERIODIC],
	&"geometer_incidence": [&"impact", &"geometry", &"", 0],
	&"geometer_wall_entry": [&"impact", &"geometry", &"", 0],
	&"geometer_wall_exit": [&"impact", &"geometry", &"", 0],
	# Sentinel
	&"sentinel_headshot": [&"projectile", &"physical", &"sentinel_headshot", 0],
	&"sentinel_observe": [&"buff", &"physical", &"", COMMIT],
	&"sentinel_piercing_shot": [&"projectile", &"physical", &"", 0],
	&"sentinel_net_shot": [&"projectile", &"physical", &"", 0],
	&"sentinel_explosive_shot": [&"projectile", &"fire", &"sentinel_explosive_shot", 0],
	&"sentinel_concussion_shot": [&"projectile", &"physical", &"", 0],
	&"sentinel_absolute_focus": [&"buff", &"physical", &"", COMMIT],
	# Hunter
	&"hunter_freezing_trap": [&"trap", &"ice", &"hunter_freezing_trap", 0],
	&"hunter_tar_trap": [&"trap", &"nature", &"", 0],
	&"hunter_thorn_trap": [&"trap", &"nature", &"", 0],
	&"hunter_mark": [&"buff", &"nature", &"", COMMIT],
	&"hunter_covering_shot": [&"projectile", &"physical", &"hunter_covering_shot", 0],
	&"hunter_total_cover": [&"area", &"nature", &"", 0],
	&"hunter_thorn_bleed": [&"impact", &"nature", &"", PERIODIC],
	&"hunter_exploit": [&"impact", &"physical", &"", 0],
	# Basic attacks: identity-free default; class variants below.
	&"basic_attack": [&"melee", &"physical", &"", 0],
	# Forest enemies (no declared skills: basic claw/arrow, charger burst, companion call).
	&"enemy_claw": [&"melee", &"physical", &"", 0],
	&"enemy_arrow": [&"projectile", &"physical", &"", 0],
	&"enemy_charge": [&"charge", &"physical", &"", 0],
	&"enemy_summon": [&"summon", &"nature", &"", 0],
}

## Identity variants (player class_id or enemy mob_base_id), resolved before the base row.
const VARIANTS := {
	&"basic_attack": {
		&"swordsman": [&"melee", &"physical", &"", 0],
		&"mage": [&"projectile", &"arcane", &"", 0],
		&"archer": [&"projectile", &"physical", &"", 0],
	},
	&"enemy_charge": {&"forest_ancient_warden": [&"charge", &"nature", &"warden_charge", 0]},
	&"enemy_summon": {&"forest_ancient_warden": [&"summon", &"nature", &"warden_summon", 0]},
}

## Signature id -> skill, owner and the one bridge kind that carries its own cue.
const SIGNATURES := {
	&"mage_fireball": {"skill_id":&"fireball", "owner":&"mage", "kind":&"impact"},
	&"mage_teleport": {"skill_id":&"teleport", "owner":&"mage", "kind":&"teleport"},
	&"swordsman_slash": {"skill_id":&"slash", "owner":&"swordsman", "kind":&"melee_swing"},
	&"swordsman_terrifying_shout": {"skill_id":&"terrifying_shout", "owner":&"swordsman", "kind":&"effect_start"},
	&"archer_arrow_rain": {"skill_id":&"arrow_rain", "owner":&"archer", "kind":&"area_start"},
	&"archer_explosive_trap": {"skill_id":&"explosive_trap", "owner":&"archer", "kind":&"trap_trigger"},
	&"defender_reprisal_wave": {"skill_id":&"defender_reprisal_wave", "owner":&"defender", "kind":&"effect_start"},
	&"defender_counterstroke": {"skill_id":&"defender_counterstroke", "owner":&"defender", "kind":&"melee_swing"},
	&"berserker_blood_rift": {"skill_id":&"berserker_blood_rift", "owner":&"berserker", "kind":&"melee_swing"},
	&"berserker_wound_leap": {"skill_id":&"berserker_wound_leap", "owner":&"berserker", "kind":&"movement"},
	&"elementalist_tri_nova": {"skill_id":&"elementalist_tri_nova", "owner":&"elementalist", "kind":&"effect_start"},
	&"elementalist_lightning_arc": {"skill_id":&"elementalist_lightning_arc", "owner":&"elementalist", "kind":&"effect_start"},
	&"spiritualist_dissipation": {"skill_id":&"spiritualist_dissipation", "owner":&"spiritualist", "kind":&"effect_start"},
	&"geometer_collapse": {"skill_id":&"geometer_collapse", "owner":&"mg_ar", "kind":&"effect_start"},
	&"geometer_triangulation": {"skill_id":&"geometer_triangulation", "owner":&"mg_ar", "kind":&"projectile_launch"},
	&"sentinel_explosive_shot": {"skill_id":&"sentinel_explosive_shot", "owner":&"sentinel", "kind":&"impact"},
	&"sentinel_headshot": {"skill_id":&"sentinel_headshot", "owner":&"sentinel", "kind":&"projectile_launch"},
	&"hunter_freezing_trap": {"skill_id":&"hunter_freezing_trap", "owner":&"hunter", "kind":&"trap_trigger"},
	&"hunter_covering_shot": {"skill_id":&"hunter_covering_shot", "owner":&"hunter", "kind":&"projectile_launch"},
	&"warden_charge": {"skill_id":&"enemy_charge", "owner":&"forest_ancient_warden", "kind":&"charge_start"},
	&"warden_summon": {"skill_id":&"enemy_summon", "owner":&"forest_ancient_warden", "kind":&"summon"},
}

## P7-C5: skills that are basic attacks. Their hits get the dry body-hit sound and the white hit burst.
const BASIC_HIT_SKILLS: Array[StringName] = [&"basic_attack", &"enemy_claw"]

static func _build(skill_id: StringName, row: Array, variant: StringName, generic: bool) -> Dictionary:
	var signature: StringName = row[2]
	var recipe := {"skill_id":skill_id, "variant":variant, "family":row[0], "element":row[1],
		"signature":signature, "is_signature":not signature.is_empty(),
		"signature_kind":SIGNATURES[signature].kind if not signature.is_empty() else &"",
		"basic_hit":skill_id in BASIC_HIT_SKILLS, "commit_effect":(int(row[3]) & COMMIT) != 0, "periodic":(int(row[3]) & PERIODIC) != 0, "generic":generic}
	recipe["audio"] = Audio.recipe_cues(recipe)
	return recipe

## Recipe for a skill (and optional identity variant). Unknown ids get the generic
## recipe, which keeps the pre-P6 audio (the cue chosen only by event kind).
static func recipe(skill_id: StringName, variant: StringName = &"") -> Dictionary:
	var variants: Dictionary = VARIANTS.get(skill_id, {})
	if not variant.is_empty() and variants.has(variant): return _build(skill_id, variants[variant], variant, false)
	if RECIPES.has(skill_id): return _build(skill_id, RECIPES[skill_id], &"", false)
	return _build(skill_id, [&"impact", &"physical", &"", 0], &"", true)

## Explicit element from a confirmed payload (Elementalist pulses / Geometer vertices)
## wins over the skill's default element only when it is one of ELEMENTS.
static func element_override(recipe: Dictionary, payload: Dictionary) -> StringName:
	var element := StringName(str(payload.get("element", ""))) if payload.get("element") is String or payload.get("element") is StringName else &""
	return element if element in ELEMENTS else StringName(recipe.get("element", &"physical"))

## Recipe for one confirmed bridge event: identity variant and element override from payload.
static func for_event(event: Dictionary) -> Dictionary:
	var payload: Dictionary = event.get("payload", {}) if event.get("payload") is Dictionary else {}
	var raw_variant: Variant = payload.get("actor_variant", payload.get("source_variant", ""))
	var variant := StringName(str(raw_variant)) if raw_variant is String or raw_variant is StringName else &""
	var skill: StringName = event.get("skill_id", &"") if event.get("skill_id") is StringName else &""
	var result := recipe(skill, variant)
	var element := element_override(result, payload)
	var critical: bool = bool(result.basic_hit) and payload.get("critical") is bool and payload.critical
	if element != result.element or critical:
		result.element = element
		result.critical = critical # P7-C5: a critical basic hit uses the sharp hit cue.
		result.audio = Audio.recipe_cues(result)
	return result

static func known_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in RECIPES: ids.append(id)
	return ids

static func signature_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in SIGNATURES: ids.append(id)
	return ids

static func signature(id: StringName) -> Dictionary:
	return SIGNATURES.get(id, {}).duplicate(true)

static func is_commit_effect(skill_id: StringName, variant: StringName = &"") -> bool:
	return bool(recipe(skill_id, variant).commit_effect)

static func is_melee(skill_id: StringName, variant: StringName = &"") -> bool:
	return recipe(skill_id, variant).family == &"melee"
