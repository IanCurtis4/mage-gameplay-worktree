extends ClassBase
## E10a skeleton of the Acólito base module (`acolyte`), delivered empty by T1.
## Owned by T5: attributes, basic attack, library, learning, effects, texts, drawers,
## hooks and the snapshot fragment of this folder. API: docs/epics/e10a/t1_base_seam_api.md.
## The base stays out of character creation until ready_for_play() returns true.

func base_id() -> StringName:
	return &"acolyte"

func display_name() -> String:
	return "Acólito"
