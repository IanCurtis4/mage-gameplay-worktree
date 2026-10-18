class_name WorldSkillGeometryRules
extends RefCounted
## Audited inventory, not permission to execute a legacy kit in multiple heights.
## Actor adapters cover mobility, the oriented shield and self-only state.
## Shared projectile/area bindings do not by themselves certify a complete skill cast.
const GROUPS := [
	{"rule":&"walk_path","ids":[&"dash",&"defender_wall_advance",&"defender_retreat_guard",&"berserker_wound_leap"],"components":"support path; continuous sweep; hit-on-travel keeps its own emission"},
	{"rule":&"teleport_legal","ids":[&"teleport"],"components":"legal exact destination; 3D range; solid supporting slab; planar obstacle exception"},
	{"rule":&"direct_volume","ids":[&"slash",&"defender_counterstroke",&"defender_riposte",&"defender_line_lock",&"concentrated_rage",&"haunt"],"components":"3D cone/line; per-target solid occlusion"},
	{"rule":&"direct_volume","ids":[&"brutal_strike",&"berserker_rupture",&"berserker_execution",&"berserker_breath_steal",&"berserker_pursuit_cut",&"provoke",&"hunter_mark",&"sentinel_observe"],"components":"target volume; 3D range; solid occlusion; debuff/heal inherits accepted hit"},
	{"rule":&"direct_volume","ids":[&"fireball",&"fire_spear",&"ice_spear",&"lightning",&"electric_discharge",&"double_shot",&"piercing_arrow",&"slowing_arrow",&"sentinel_headshot",&"sentinel_piercing_shot",&"sentinel_concussion_shot",&"hunter_covering_shot"],"components":"continuous 3D projectile sweep; finite piercing/homing/fan; intercept volumes; body offset is presentation only"},
	{"rule":&"ground_connected","ids":[&"arrow_rain",&"snare_trap",&"explosive_trap",&"hunter_freezing_trap",&"hunter_tar_trap",&"hunter_thorn_trap",&"sentinel_net_shot"],"components":"anchored surface; connected ground propagation; resample each volley/trigger; tar/bleed keep causal origin"},
	{"rule":&"ground_connected","ids":[&"fire_wall",&"lightning_wall",&"ice_wall",&"phantom_barrier"],"components":"surface anchor; explicit vertical volume; crossing/interception differs from damage; obstacle revision"},
	{"rule":&"ground_connected","ids":[&"defender_anchor",&"defender_reprisal_wave",&"piercing_shout",&"terrifying_shout",&"berserker_blood_rift",&"elementalist_flame_burst",&"elementalist_glacial_ring",&"elementalist_ember_path",&"elementalist_tri_nova",&"spiritualist_dissipation"],"components":"ground-connected radius/strip; per-pulse range; push follows support; staged emissions retain budget"},
	{"rule":&"direct_volume","ids":[&"elementalist_lightning_arc"],"components":"each jump has source WorldPoint and 3D range/occlusion; no jump across solid slab"},
	{"rule":&"direct_volume","ids":[&"soul_impact",&"spiritualist_echo_curse",&"spiritualist_soul_drain",&"spiritualist_procession"],"components":"locked/following target; pulse/channel commit; echo wave origin may follow carrier or be fixed; propagation requires separate ground query"},
	{"rule":&"ground_connected","ids":[&"foliage_shelter",&"hunter_total_cover",&"spiritualist_spectral_veil"],"components":"support/concealment area anchored to a surface; exit grace follows source policy; lower and upper floors remain separate"},
	{"rule":&"direct_volume","ids":[&"sentinel_explosive_shot"],"components":"captured next projectile; explosion has explicit world center/volume and occlusion, no projected-radius fallback"},
	{"rule":&"ground_connected","ids":[&"geometer_trace",&"geometer_triangulation",&"geometer_translation",&"geometer_rewrite",&"geometer_collapse"],"components":"ground OR actor anchor captured explicitly; trace projectile sweep; walls/triangles use supported edges/interior; moving anchor invalidates geometry; collapse keeps recipe budget"},
	{"rule":&"self_only","ids":[&"perseverance",&"fury",&"extended_aim",&"sentinel_absolute_focus"],"components":"self state only; later attack retains its own geometry and emission"},
	{"rule":&"direct_volume","ids":[&"shield_wall"],"components":"self buff plus oriented interception volume; never intercept projectile solely by sprite overlap"},
	{"rule":&"inherit_parent","ids":[&"swordsman_resistance",&"vigor",&"blood_thirst",&"mage_mana_regeneration",&"archer_precision",&"archer_cadence",&"trap_technique",&"defender_watch",&"defender_guard_return",&"berserker_obstinacy",&"berserker_pursuit",&"berserker_deep_bleeding",&"elementalist_prismatic_focus",&"elementalist_prismatic_resonance",&"spiritualist_echo_recovery",&"spiritualist_channel_focus",&"sentinel_precision_stance",&"sentinel_opening_read",&"hunter_shooting_discipline",&"hunter_easy_prey",&"geometer_incidence",&"geometer_vector_memory"],"components":"stat/self state or causal parent hit; does not emit an independent spatial attack"},
]
static func rule(skill: StringName) -> Dictionary:
	for group: Dictionary in GROUPS:
		if skill in group["ids"]:
			return {"geometry_rule_id":group["rule"],"components":group["components"],"actor_adapter":skill in [&"dash",&"teleport",&"shield_wall"] or group["rule"] == &"self_only"}
	return {}
