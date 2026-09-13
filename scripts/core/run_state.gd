class_name RunState
extends RefCounted
## Mutable run-only state. AugmentDefinition entries are catalog data only.

const DEFAULT_CLASS_ID: StringName = &"swordsman"

var class_id: StringName = DEFAULT_CLASS_ID
var skill_levels: Dictionary[StringName, int] = {}
var augment_stacks: Dictionary[StringName, int] = {}
var pending_choices: int = 0
var current_offer: Array[AugmentDefinition] = []
var _catalog: Array[AugmentDefinition] = []

func _init(selected_class: StringName = DEFAULT_CLASS_ID) -> void:
	_catalog = [
		_create_augment(&"vitality", "Vitalidade", "+20% de Vida Máxima", &"max_hp_increased", 0.20),
		_create_augment(&"keen_edge", "Fio Preciso", "+5 pontos percentuais de crítico", &"crit_chance_flat", 0.05),
		_create_augment(&"battle_rhythm", "Ritmo de Batalha", "+15% de velocidade de ataque", &"attack_speed_increased", 0.15),
		_create_augment(&"extra_spear", "Lança Duplicada", "+1 lança de fogo e gelo", &"spear_count_flat", 1.0, &"mage"),
	]
	select_class(selected_class)

func select_class(selected_class: StringName) -> bool:
	if ClassCatalog.class_definition(selected_class) == null:
		return false
	class_id = selected_class
	skill_levels.clear()
	for skill_id: StringName in ClassCatalog.skill_ids(class_id):
		skill_levels[skill_id] = 1
	reset()
	return true

func queue_choice() -> void:
	pending_choices += 1

func can_open_choice(encounter_active: bool) -> bool:
	return pending_choices > 0 and not encounter_active

func build_offer(encounter_active: bool, rng: RandomNumberGenerator) -> Array[AugmentDefinition]:
	if not can_open_choice(encounter_active):
		return []
	if not current_offer.is_empty():
		return current_offer.duplicate()
	var eligible: Array[AugmentDefinition] = []
	for definition: AugmentDefinition in _catalog:
		if definition.is_eligible(class_id, augment_stacks.get(definition.id, 0)):
			eligible.append(definition)
	while not eligible.is_empty() and current_offer.size() < 3:
		var index := rng.randi_range(0, eligible.size() - 1)
		current_offer.append(eligible.pop_at(index))
	return current_offer.duplicate()

func confirm(augment_id: StringName, encounter_active: bool) -> bool:
	if not can_open_choice(encounter_active):
		return false
	for definition: AugmentDefinition in current_offer:
		if definition.id != augment_id:
			continue
		var stacks: int = augment_stacks.get(augment_id, 0)
		if not definition.is_eligible(class_id, stacks):
			return false
		augment_stacks[augment_id] = stacks + 1
		pending_choices -= 1
		current_offer.clear()
		return true
	return false

func get_modifiers() -> Dictionary:
	var flat: Dictionary = {}
	var increased: Dictionary = {}
	flat["crit_chance"] = 0.05 * float(augment_stacks.get(&"keen_edge", 0))
	increased["max_hp"] = 0.20 * float(augment_stacks.get(&"vitality", 0))
	increased["attacks_per_second"] = 0.15 * float(augment_stacks.get(&"battle_rhythm", 0))
	return {"flat": flat, "increased": increased, "spear_count": 1 + augment_stacks.get(&"extra_spear", 0)}

func describe_progress(definition: AugmentDefinition) -> String:
	var current: int = augment_stacks.get(definition.id, 0)
	var current_value := definition.magnitude_per_stack * float(current)
	var next_value := definition.magnitude_per_stack * float(current + 1)
	return "Atual: %s  →  Próximo: %s" % [_format_effect(definition.effect_id, current_value), _format_effect(definition.effect_id, next_value)]

func reset() -> void:
	augment_stacks.clear()
	pending_choices = 0
	current_offer.clear()

func _create_augment(augment_id: StringName, display_name: String, description: String, effect_id: StringName, magnitude: float, required_class: StringName = &"") -> AugmentDefinition:
	var definition := AugmentDefinition.new()
	definition.id = augment_id
	definition.display_name = display_name
	definition.description = description
	definition.class_id = required_class
	definition.max_stacks = 3
	definition.effect_id = effect_id
	definition.magnitude_per_stack = magnitude
	return definition

func _format_effect(effect_id: StringName, value: float) -> String:
	if effect_id == &"crit_chance_flat":
		return "+%d p.p." % int(round(value * 100.0))
	return "+%d%%" % int(round(value * 100.0))
