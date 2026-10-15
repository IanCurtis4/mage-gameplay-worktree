class_name ActionBarLayout
extends RefCounted
## Organization only. Learning, stats, cooldowns and combat never belong here.

const SLOT_COUNT := 24

static func empty() -> Array[Variant]:
	var slots: Array[Variant] = []
	slots.resize(SLOT_COUNT)
	return slots

static func from_legacy(slots: Array) -> Array[Variant]:
	var result := empty()
	var seen: Dictionary[StringName, bool] = {}
	for index: int in mini(slots.size(), SLOT_COUNT):
		if slots[index] == null:
			continue
		var id := skill_id(slots[index])
		if not seen.has(id):
			result[index] = id
			seen[id] = true
	return result

static func skill_id(value: Variant) -> StringName:
	if value is String or value is StringName:
		return StringName(value)
	if value is Dictionary and (value.get("skill_id") is String or value.get("skill_id") is StringName):
		return StringName(value["skill_id"])
	return &""

static func selected_rank(value: Variant) -> int:
	if not value is Dictionary:
		return 0
	var rank: Variant = value.get("rank")
	if rank is int:
		return rank
	if rank is float and is_finite(rank) and absf(rank) <= 9007199254740991.0:
		return int(rank)
	return -1

static func entry(id: StringName, rank: int = 0) -> Variant:
	return null if id.is_empty() or rank < 0 else ({"skill_id": id, "rank": rank} if rank > 0 else id)

static func valid(slots: Array, learned: Array[StringName], retained_item_refs: Array[StringName] = []) -> bool:
	if slots.size() != SLOT_COUNT:
		return false
	var seen: Dictionary[String, bool] = {}
	for value: Variant in slots:
		if value == null:
			continue
		var id := skill_id(value)
		var rank := selected_rank(value)
		if value is Dictionary:
			if value.size() != 2 or not value.has("rank") or not (value["rank"] is int or value["rank"] is float) or float(value["rank"]) != rank or rank <= 0 or not SkillCastRank.supports(id):
				return false
		elif not (value is String or value is StringName):
			return false
		var definition := ClassCatalog.skill_definition(id)
		if id.is_empty() or (definition != null and definition.category != SkillDefinition.Category.ACTIVE) or (rank > 0 and (definition == null or definition.rank_definition(rank) == null)):
			return false
		var key := "%s:%d" % [id, rank]
		if (id not in learned and id not in retained_item_refs) or seen.has(key):
			return false
		seen[key] = true
	return true

static func assign(slots: Array[Variant], skill: StringName, destination: int, rank: int = 0) -> Array[Variant]:
	var result: Array[Variant] = slots.duplicate(true)
	if result.size() != SLOT_COUNT or destination < 0 or destination >= SLOT_COUNT:
		return result
	if rank < 0 or (rank > 0 and (not SkillCastRank.supports(skill) or ClassCatalog.skill_definition(skill).rank_definition(rank) == null)):
		return result
	if skill.is_empty():
		result[destination] = null
		return result
	var old := -1
	for index: int in result.size():
		if skill_id(result[index]) == skill and selected_rank(result[index]) == rank:
			old = index
			break
	if old >= 0:
		return move(result, old, destination)
	result[destination] = entry(skill, rank)
	return result

static func move(slots: Array[Variant], source: int, destination: int) -> Array[Variant]:
	var result: Array[Variant] = slots.duplicate(true)
	if result.size() != SLOT_COUNT or source < 0 or source >= SLOT_COUNT or destination < 0 or destination >= SLOT_COUNT:
		return result
	var previous: Variant = result[destination]
	result[destination] = result[source]
	result[source] = previous
	return result

static func for_character(character: CharacterState) -> Array[Variant]:
	if not character.action_slots.is_empty():
		return character.action_slots.duplicate(true)
	return from_legacy(character.presets[character.selected_preset]["active_slots"])
