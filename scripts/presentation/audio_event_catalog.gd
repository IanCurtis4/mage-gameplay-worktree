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
	&"ambience.stage":{"kind":&"stage_enter", "channel":&"ambience", "priority":0, "path":"res://assets/audio/e08/ambience_stage.wav"}
}
static func ids() -> Array: return EVENTS.keys()
static func definition(id: StringName) -> Dictionary: return EVENTS.get(id, {}).duplicate(true)
static func for_kind(kind: StringName) -> StringName:
	for id: StringName in EVENTS:
		if EVENTS[id].kind == kind: return id
	return &""
