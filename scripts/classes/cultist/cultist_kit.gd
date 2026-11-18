extends ClassKit
## E10a skeleton of the Cultista kit (`cultist`, pure evolution of the Acólito), delivered
## empty by T1. Owned by T7: skills, learning, effects, texts, drawers, hooks and the
## snapshot fragment of this folder. APIs: docs/epics/e10a/t1_base_seam_api.md and
## docs/epics/e09/t1_kit_seam_api.md. The evolution stays unavailable until
## ready_for_play() returns true.

func kit_id() -> StringName:
	return &"cultist"

func display_name() -> String:
	return "Cultista"
