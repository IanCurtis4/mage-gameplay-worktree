class_name SnapshotIdentityRoles
extends RefCounted
## Closed roles for existing gameplay identities. Ordinary numeric values, RNG,
## ranks, emissions, construction counters and tickets are never guessed as IDs.
const VALUES := ["source_id","target_id","owner_id","actor_id","caster_id","summoner_id","marked_target_id","marked_trigger_target_id","observed_target_id","_active_cast_target_id","_spiritualist_echo_number_target_id","_hunter_fan_target_id","zone_id","victim_id","carrier_id"]
const ARRAYS := ["targets","carriers","spiritualist_marks","spiritualist_veil_members"]
const KEYED := ["targets","carriers","_hit_actor_ids","_hit_ids","_credited_kills","_defender_slowed_enemies","_spiritualist_veil_members","_world_companion_attempts","_world_pending_companions","_mob_actors","_foliage_shelters","_world_shelters","berserker_wounds","elementalist_focus_history","elementalist_resonance_history","_openings","marks","_watched_walkers","_world_walkers","_victim_ready","_projectile_components","_actors","_previous_positions","_world_previous","_points","_last_points","_inside","_cooldowns","_excluded"]
const STRINGS := ["root_event_id","ancestor_root_id","_world_id","occurrence_id","enemy_id","event_id","_occupant_id"]

static func value_role(field: String) -> String:
	if field in ["spiritualist_drain_caster_id","spiritualist_drain_target_id","spiritualist_focus_caster_id"]: return "entity"
	if field in VALUES: return "entity"
	if field in ARRAYS: return "entities"
	if field in STRINGS: return "identity_string"
	return "value"

static func key_role(field: String) -> String:
	if field in ["spiritualist_mark_remaining","spiritualist_pending_remaining","spiritualist_weakened"]: return "entity"
	if StringName(field) in AttributeDebuffState.LIMITS: return "identity_string"
	if field in KEYED or field in ["_pending","_temporary_segments","_activations","eligible","scheduled","shown_targets"]: return "entity"
	if field in ["burn_streams","bleed_streams","claims","_roots","pairs","_events","events","_occurrence_actors","_occupancy","_segments","_temporary"]: return "identity_string"
	return "value"
