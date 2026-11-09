class_name AudioEventCatalog
extends RefCounted
## Definitions are private constant data. Callers receive copies, never mutable catalog state.
const CHANNELS: Array[StringName] = [&"general", &"effects", &"interface", &"ambience"]
const LIMITS := {&"effects":24, &"interface":4, &"ambience":4}
const EVENTS := {
	&"world.cast_start":{"kind":&"cast_start", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/world_cast_start.wav"},
	&"world.cast_cancel":{"kind":&"cast_cancel", "channel":&"effects", "priority":30, "path":"res://assets/audio/e08/world_cast_cancel.wav"},
	&"world.projectile_launch":{"kind":&"projectile_launch", "channel":&"effects", "priority":10, "path":"res://assets/audio/e08/world_projectile_launch.wav"},
	&"world.impact":{"kind":&"impact", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/world_impact.wav"},
	&"world.area_start":{"kind":&"area_start", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/world_area_start.wav"},
	&"world.area_end":{"kind":&"area_end", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/world_area_end.wav"},
	&"world.teleport":{"kind":&"teleport", "channel":&"effects", "priority":50, "path":"res://assets/audio/e08/world_teleport.wav"},
	&"world.death":{"kind":&"death", "channel":&"effects", "priority":60, "path":"res://assets/audio/e08/world_death.wav"},
	&"world.revive":{"kind":&"revive", "channel":&"effects", "priority":60, "path":"res://assets/audio/e08/world_revive.wav"},
	&"ui.confirm":{"kind":&"ui_confirm", "channel":&"interface", "priority":50, "path":"res://assets/audio/e08/ui_confirm.wav"},
	&"ui.cancel":{"kind":&"ui_cancel", "channel":&"interface", "priority":50, "path":"res://assets/audio/e08/ui_cancel.wav"},
	&"ambience.stage":{"kind":&"stage_enter", "channel":&"ambience", "priority":0, "path":"res://assets/audio/e08/ambience_stage.wav"},
	## Biome bed: selected by `ambience_for_biome`, never by an event kind.
	&"ambience.forest":{"kind":&"stage_enter_forest", "channel":&"ambience", "priority":0, "path":"res://assets/audio/e08/ambience_forest.wav"}
}
const BIOME_AMBIENCE: Array[StringName] = [&"ambience.forest"]
## E08 P6 planned family x element and signature cues (Sol defines, Terra synthesizes).
## Kept out of ids() until their WAV exists, so format/sample tests that require every
## ids() WAV keep holding; selection falls back to the EVENTS cue of the kind meanwhile.
const PLANNED := {
	&"p6.cast.arcane":{"kind":&"cast_start", "family":&"cast", "element":&"arcane", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/cast_arcane.wav"},
	&"p6.cast.blood":{"kind":&"cast_start", "family":&"cast", "element":&"blood", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/cast_blood.wav"},
	&"p6.cast.fire":{"kind":&"cast_start", "family":&"cast", "element":&"fire", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/cast_fire.wav"},
	&"p6.cast.geometry":{"kind":&"cast_start", "family":&"cast", "element":&"geometry", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/cast_geometry.wav"},
	&"p6.cast.ice":{"kind":&"cast_start", "family":&"cast", "element":&"ice", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/cast_ice.wav"},
	&"p6.cast.lightning":{"kind":&"cast_start", "family":&"cast", "element":&"lightning", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/cast_lightning.wav"},
	&"p6.cast.nature":{"kind":&"cast_start", "family":&"cast", "element":&"nature", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/cast_nature.wav"},
	&"p6.cast.physical":{"kind":&"cast_start", "family":&"cast", "element":&"physical", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/cast_physical.wav"},
	&"p6.cast.spirit":{"kind":&"cast_start", "family":&"cast", "element":&"spirit", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/cast_spirit.wav"},
	&"p6.projectile.arcane":{"kind":&"projectile_launch", "family":&"projectile", "element":&"arcane", "channel":&"effects", "priority":10, "path":"res://assets/audio/e08/p6/projectile_arcane.wav"},
	&"p6.projectile.fire":{"kind":&"projectile_launch", "family":&"projectile", "element":&"fire", "channel":&"effects", "priority":10, "path":"res://assets/audio/e08/p6/projectile_fire.wav"},
	&"p6.projectile.geometry":{"kind":&"projectile_launch", "family":&"projectile", "element":&"geometry", "channel":&"effects", "priority":10, "path":"res://assets/audio/e08/p6/projectile_geometry.wav"},
	&"p6.projectile.ice":{"kind":&"projectile_launch", "family":&"projectile", "element":&"ice", "channel":&"effects", "priority":10, "path":"res://assets/audio/e08/p6/projectile_ice.wav"},
	&"p6.projectile.lightning":{"kind":&"projectile_launch", "family":&"projectile", "element":&"lightning", "channel":&"effects", "priority":10, "path":"res://assets/audio/e08/p6/projectile_lightning.wav"},
	&"p6.projectile.nature":{"kind":&"projectile_launch", "family":&"projectile", "element":&"nature", "channel":&"effects", "priority":10, "path":"res://assets/audio/e08/p6/projectile_nature.wav"},
	&"p6.projectile.physical":{"kind":&"projectile_launch", "family":&"projectile", "element":&"physical", "channel":&"effects", "priority":10, "path":"res://assets/audio/e08/p6/projectile_physical.wav"},
	&"p6.melee.blood":{"kind":&"melee_swing", "family":&"melee", "element":&"blood", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/melee_blood.wav"},
	&"p6.melee.physical":{"kind":&"melee_swing", "family":&"melee", "element":&"physical", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/melee_physical.wav"},
	&"p6.impact.arcane":{"kind":&"impact", "family":&"impact", "element":&"arcane", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/impact_arcane.wav"},
	&"p6.impact.blood":{"kind":&"impact", "family":&"impact", "element":&"blood", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/impact_blood.wav"},
	&"p6.impact.fire":{"kind":&"impact", "family":&"impact", "element":&"fire", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/impact_fire.wav"},
	&"p6.impact.geometry":{"kind":&"impact", "family":&"impact", "element":&"geometry", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/impact_geometry.wav"},
	&"p6.impact.ice":{"kind":&"impact", "family":&"impact", "element":&"ice", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/impact_ice.wav"},
	&"p6.impact.lightning":{"kind":&"impact", "family":&"impact", "element":&"lightning", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/impact_lightning.wav"},
	&"p6.impact.nature":{"kind":&"impact", "family":&"impact", "element":&"nature", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/impact_nature.wav"},
	&"p6.impact.physical":{"kind":&"impact", "family":&"impact", "element":&"physical", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/impact_physical.wav"},
	&"p6.impact.spirit":{"kind":&"impact", "family":&"impact", "element":&"spirit", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/impact_spirit.wav"},
	&"p6.dot.blood":{"kind":&"impact", "family":&"dot", "element":&"blood", "channel":&"effects", "priority":15, "path":"res://assets/audio/e08/p6/dot_blood.wav"},
	&"p6.dot.fire":{"kind":&"impact", "family":&"dot", "element":&"fire", "channel":&"effects", "priority":15, "path":"res://assets/audio/e08/p6/dot_fire.wav"},
	&"p6.dot.geometry":{"kind":&"impact", "family":&"dot", "element":&"geometry", "channel":&"effects", "priority":15, "path":"res://assets/audio/e08/p6/dot_geometry.wav"},
	&"p6.dot.nature":{"kind":&"impact", "family":&"dot", "element":&"nature", "channel":&"effects", "priority":15, "path":"res://assets/audio/e08/p6/dot_nature.wav"},
	&"p6.area.arcane":{"kind":&"area_start", "family":&"area", "element":&"arcane", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/area_arcane.wav"},
	&"p6.area.blood":{"kind":&"area_start", "family":&"area", "element":&"blood", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/area_blood.wav"},
	&"p6.area.fire":{"kind":&"area_start", "family":&"area", "element":&"fire", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/area_fire.wav"},
	&"p6.area.geometry":{"kind":&"area_start", "family":&"area", "element":&"geometry", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/area_geometry.wav"},
	&"p6.area.ice":{"kind":&"area_start", "family":&"area", "element":&"ice", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/area_ice.wav"},
	&"p6.area.lightning":{"kind":&"area_start", "family":&"area", "element":&"lightning", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/area_lightning.wav"},
	&"p6.area.nature":{"kind":&"area_start", "family":&"area", "element":&"nature", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/area_nature.wav"},
	&"p6.area.physical":{"kind":&"area_start", "family":&"area", "element":&"physical", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/area_physical.wav"},
	&"p6.area.spirit":{"kind":&"area_start", "family":&"area", "element":&"spirit", "channel":&"effects", "priority":20, "path":"res://assets/audio/e08/p6/area_spirit.wav"},
	&"p6.trap.fire":{"kind":&"trap_trigger", "family":&"trap", "element":&"fire", "channel":&"effects", "priority":45, "path":"res://assets/audio/e08/p6/trap_fire.wav"},
	&"p6.trap.ice":{"kind":&"trap_trigger", "family":&"trap", "element":&"ice", "channel":&"effects", "priority":45, "path":"res://assets/audio/e08/p6/trap_ice.wav"},
	&"p6.trap.nature":{"kind":&"trap_trigger", "family":&"trap", "element":&"nature", "channel":&"effects", "priority":45, "path":"res://assets/audio/e08/p6/trap_nature.wav"},
	&"p6.buff.blood":{"kind":&"effect_start", "family":&"buff", "element":&"blood", "channel":&"effects", "priority":30, "path":"res://assets/audio/e08/p6/buff_blood.wav"},
	&"p6.buff.nature":{"kind":&"effect_start", "family":&"buff", "element":&"nature", "channel":&"effects", "priority":30, "path":"res://assets/audio/e08/p6/buff_nature.wav"},
	&"p6.buff.physical":{"kind":&"effect_start", "family":&"buff", "element":&"physical", "channel":&"effects", "priority":30, "path":"res://assets/audio/e08/p6/buff_physical.wav"},
	&"p6.heal.blood":{"kind":&"heal", "family":&"heal", "element":&"blood", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/heal_blood.wav"},
	&"p6.heal.spirit":{"kind":&"heal", "family":&"heal", "element":&"spirit", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/heal_spirit.wav"},
	&"p6.movement.blood":{"kind":&"movement", "family":&"movement", "element":&"blood", "channel":&"effects", "priority":30, "path":"res://assets/audio/e08/p6/movement_blood.wav"},
	&"p6.movement.physical":{"kind":&"movement", "family":&"movement", "element":&"physical", "channel":&"effects", "priority":30, "path":"res://assets/audio/e08/p6/movement_physical.wav"},
	&"p6.summon.nature":{"kind":&"summon", "family":&"summon", "element":&"nature", "channel":&"effects", "priority":55, "path":"res://assets/audio/e08/p6/summon_nature.wav"},
	&"p6.charge.nature":{"kind":&"charge_start", "family":&"charge", "element":&"nature", "channel":&"effects", "priority":55, "path":"res://assets/audio/e08/p6/charge_nature.wav"},
	&"p6.charge.physical":{"kind":&"charge_start", "family":&"charge", "element":&"physical", "channel":&"effects", "priority":55, "path":"res://assets/audio/e08/p6/charge_physical.wav"},
	&"p6.teleport.arcane":{"kind":&"teleport", "family":&"teleport", "element":&"arcane", "channel":&"effects", "priority":50, "path":"res://assets/audio/e08/p6/teleport_arcane.wav"},
	&"p6.sig.mage_fireball":{"kind":&"impact", "family":&"signature", "element":&"fire", "signature":&"mage_fireball", "channel":&"effects", "priority":45, "path":"res://assets/audio/e08/p6/sig_mage_fireball.wav"},
	&"p6.sig.mage_teleport":{"kind":&"teleport", "family":&"signature", "element":&"arcane", "signature":&"mage_teleport", "channel":&"effects", "priority":55, "path":"res://assets/audio/e08/p6/sig_mage_teleport.wav"},
	&"p6.sig.swordsman_slash":{"kind":&"melee_swing", "family":&"signature", "element":&"physical", "signature":&"swordsman_slash", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/sig_swordsman_slash.wav"},
	&"p6.sig.swordsman_terrifying_shout":{"kind":&"effect_start", "family":&"signature", "element":&"physical", "signature":&"swordsman_terrifying_shout", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/sig_swordsman_terrifying_shout.wav"},
	&"p6.sig.archer_arrow_rain":{"kind":&"area_start", "family":&"signature", "element":&"physical", "signature":&"archer_arrow_rain", "channel":&"effects", "priority":25, "path":"res://assets/audio/e08/p6/sig_archer_arrow_rain.wav"},
	&"p6.sig.archer_explosive_trap":{"kind":&"trap_trigger", "family":&"signature", "element":&"fire", "signature":&"archer_explosive_trap", "channel":&"effects", "priority":50, "path":"res://assets/audio/e08/p6/sig_archer_explosive_trap.wav"},
	&"p6.sig.defender_reprisal_wave":{"kind":&"effect_start", "family":&"signature", "element":&"physical", "signature":&"defender_reprisal_wave", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/sig_defender_reprisal_wave.wav"},
	&"p6.sig.defender_counterstroke":{"kind":&"melee_swing", "family":&"signature", "element":&"physical", "signature":&"defender_counterstroke", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/sig_defender_counterstroke.wav"},
	&"p6.sig.berserker_blood_rift":{"kind":&"melee_swing", "family":&"signature", "element":&"blood", "signature":&"berserker_blood_rift", "channel":&"effects", "priority":40, "path":"res://assets/audio/e08/p6/sig_berserker_blood_rift.wav"},
	&"p6.sig.berserker_wound_leap":{"kind":&"movement", "family":&"signature", "element":&"blood", "signature":&"berserker_wound_leap", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/sig_berserker_wound_leap.wav"},
	&"p6.sig.elementalist_tri_nova":{"kind":&"effect_start", "family":&"signature", "element":&"arcane", "signature":&"elementalist_tri_nova", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/sig_elementalist_tri_nova.wav"},
	&"p6.sig.elementalist_lightning_arc":{"kind":&"effect_start", "family":&"signature", "element":&"lightning", "signature":&"elementalist_lightning_arc", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/sig_elementalist_lightning_arc.wav"},
	&"p6.sig.spiritualist_dissipation":{"kind":&"effect_start", "family":&"signature", "element":&"spirit", "signature":&"spiritualist_dissipation", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/sig_spiritualist_dissipation.wav"},
	&"p6.sig.geometer_collapse":{"kind":&"effect_start", "family":&"signature", "element":&"geometry", "signature":&"geometer_collapse", "channel":&"effects", "priority":35, "path":"res://assets/audio/e08/p6/sig_geometer_collapse.wav"},
	&"p6.sig.geometer_triangulation":{"kind":&"projectile_launch", "family":&"signature", "element":&"geometry", "signature":&"geometer_triangulation", "channel":&"effects", "priority":15, "path":"res://assets/audio/e08/p6/sig_geometer_triangulation.wav"},
	&"p6.sig.sentinel_explosive_shot":{"kind":&"impact", "family":&"signature", "element":&"fire", "signature":&"sentinel_explosive_shot", "channel":&"effects", "priority":45, "path":"res://assets/audio/e08/p6/sig_sentinel_explosive_shot.wav"},
	&"p6.sig.sentinel_headshot":{"kind":&"projectile_launch", "family":&"signature", "element":&"physical", "signature":&"sentinel_headshot", "channel":&"effects", "priority":15, "path":"res://assets/audio/e08/p6/sig_sentinel_headshot.wav"},
	&"p6.sig.hunter_freezing_trap":{"kind":&"trap_trigger", "family":&"signature", "element":&"ice", "signature":&"hunter_freezing_trap", "channel":&"effects", "priority":50, "path":"res://assets/audio/e08/p6/sig_hunter_freezing_trap.wav"},
	&"p6.sig.hunter_covering_shot":{"kind":&"projectile_launch", "family":&"signature", "element":&"physical", "signature":&"hunter_covering_shot", "channel":&"effects", "priority":15, "path":"res://assets/audio/e08/p6/sig_hunter_covering_shot.wav"},
	&"p6.sig.warden_charge":{"kind":&"charge_start", "family":&"signature", "element":&"nature", "signature":&"warden_charge", "channel":&"effects", "priority":60, "path":"res://assets/audio/e08/p6/sig_warden_charge.wav"},
	&"p6.sig.warden_summon":{"kind":&"summon", "family":&"signature", "element":&"nature", "signature":&"warden_summon", "channel":&"effects", "priority":60, "path":"res://assets/audio/e08/p6/sig_warden_summon.wav"},
}
## Bridge kind -> fallback cue for new P6 kinds that have no EVENTS cue of their own.
## A triggered trap keeps today's sound (area_end cue) at the trigger moment.
const KIND_FALLBACK := {&"trap_trigger":&"world.area_end"}
static func ids() -> Array:
	var result: Array = EVENTS.keys()
	for id: StringName in PLANNED:
		if ResourceLoader.exists(PLANNED[id].path): result.append(id)
	return result
static func planned_cue_ids() -> Array: return PLANNED.keys()
static func definition(id: StringName) -> Dictionary:
	if EVENTS.has(id): return EVENTS[id].duplicate(true)
	return PLANNED.get(id, {}).duplicate(true)
static func ambience_ids() -> Array: return BIOME_AMBIENCE.duplicate()
static func for_kind(kind: StringName) -> StringName:
	for id: StringName in EVENTS:
		if EVENTS[id].kind == kind: return id
	return &""
## Biome-specific ambience. Unknown or empty biomes keep the generic stage bed.
static func ambience_for_biome(biome: String) -> StringName:
	return &"ambience.forest" if biome == "forest" else &"ambience.stage"
## Planned cue family for a bridge kind and recipe; empty when the kind has no family cue.
static func cue_family(kind: StringName, recipe: Dictionary) -> StringName:
	match kind:
		&"cast_start": return &"cast"
		&"projectile_launch": return &"projectile"
		&"impact": return &"dot" if bool(recipe.get("periodic", false)) else &"impact"
		&"area_start": return &"area"
		&"trap_trigger": return &"trap"
		&"melee_swing": return &"melee"
		&"movement": return &"movement"
		&"effect_start": return &"buff" if recipe.get("family") == &"buff" else &"area"
		&"heal": return &"heal"
		&"summon": return &"summon"
		&"charge_start": return &"charge"
		&"teleport": return &"teleport"
	return &""
## Ordered candidates, most specific first: signature -> family x element ->
## family x physical -> current kind cue. Generic (unknown) recipes keep only the kind cue.
static func candidates(kind: StringName, recipe: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	if not recipe.is_empty() and not bool(recipe.get("generic", true)):
		var signature: StringName = recipe.get("signature", &"")
		if not signature.is_empty() and recipe.get("signature_kind") == kind:
			var signature_id := StringName("p6.sig." + String(signature))
			if PLANNED.has(signature_id): result.append(signature_id)
		var family := cue_family(kind, recipe)
		if not family.is_empty():
			for element: StringName in [StringName(recipe.get("element", &"physical")), &"physical"]:
				var id := StringName("p6.%s.%s" % [family, element])
				if PLANNED.has(id) and id not in result: result.append(id)
	var fallback := for_kind(kind)
	if fallback == &"": fallback = KIND_FALLBACK.get(kind, &"")
	if fallback != &"" and fallback not in result: result.append(fallback)
	return result
const WORLD_KINDS: Array[StringName] = [&"cast_start", &"cast_cancel", &"projectile_launch", &"impact", &"area_start", &"area_end", &"teleport", &"death", &"revive", &"melee_swing", &"movement", &"effect_start", &"heal", &"summon", &"charge_start", &"trap_trigger"]
## Copy of every kind's candidate chain for one recipe (exposed through recipes' "audio").
static func recipe_cues(recipe: Dictionary) -> Dictionary:
	var result := {}
	for kind: StringName in WORLD_KINDS:
		var chain := candidates(kind, recipe)
		if not chain.is_empty(): result[kind] = chain
	return result
