extends RefCounted
## Complete learned ancestors of an E05 combat snapshot. Pass an ID in
## protected_ids when that rank itself is the subject of a negative case.

static func complete_snapshot(snapshot: BuildSnapshot, protected_ids: Array[StringName] = []) -> void:
	var pending: Array[StringName] = []
	pending.assign(snapshot.skill_ranks.keys())
	var cursor := 0
	while cursor < pending.size():
		var skill_id := pending[cursor]
		cursor += 1
		if snapshot.skill_ranks.get(skill_id, 0) <= 0:
			continue
		var requirements: Dictionary = SkillDependencyRules.REQUIREMENTS.get(skill_id, {})
		for ancestor: StringName in requirements:
			var required_rank: int = requirements[ancestor]
			if snapshot.skill_ranks.get(ancestor, 0) >= required_rank:
				continue
			if ancestor in protected_ids:
				continue
			snapshot.skill_ranks[ancestor] = required_rank
			if not snapshot.library_skill_ids.is_empty() and ancestor not in snapshot.library_skill_ids:
				snapshot.library_skill_ids.append(ancestor)
			pending.append(ancestor)

static func prerequisite_ranks(skill_id: StringName) -> Dictionary[StringName, int]:
	var ranks: Dictionary[StringName, int] = {}
	var pending: Array[StringName] = [skill_id]
	var cursor := 0
	while cursor < pending.size():
		var current := pending[cursor]
		cursor += 1
		var requirements: Dictionary = SkillDependencyRules.REQUIREMENTS.get(current, {})
		for ancestor: StringName in requirements:
			var required_rank: int = requirements[ancestor]
			if ranks.get(ancestor, 0) >= required_rank:
				continue
			ranks[ancestor] = required_rank
			pending.append(ancestor)
	return ranks

static func buy_ancestors(character: CharacterState, catalog: ProfileCatalog, skill_id: StringName) -> Dictionary:
	var requirements: Dictionary = SkillDependencyRules.REQUIREMENTS.get(skill_id, {})
	for ancestor: StringName in requirements:
		var nested := buy_ancestors(character, catalog, ancestor)
		if not nested["ok"]:
			return nested
		var required_rank: int = requirements[ancestor]
		while int(catalog.effective_skill_ranks(character.base_class_id, character.evolution_id, character.purchased_skill_ranks, character.granted_skill_ranks).get(ancestor, 0)) < required_rank:
			var bought := CharacterProgression.learn_skill(character, catalog, ancestor)
			if not bought["ok"]:
				return bought
	return {"ok": true}
