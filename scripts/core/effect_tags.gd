class_name EffectTags
extends RefCounted
## Descriptive metadata only; tags never execute rules or create equivalence.
const LABELS := {&"echoing": "Ecoante", &"bleeding": "Sangrento", &"energizing": "Energizante", &"freezing": "Congelante", &"flaming": "Flamejante", &"renewing": "Renovador", &"ethereal": "Etéreo"}
static func valid(tags: Array[StringName]) -> bool:
	var seen: Dictionary = {}
	for tag: StringName in tags:
		if not LABELS.has(tag) or seen.has(tag):
			return false
		seen[tag] = true
	return true
