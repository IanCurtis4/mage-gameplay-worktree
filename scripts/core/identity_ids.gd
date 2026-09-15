class_name IdentityIds
extends RefCounted
## Stable technical IDs accepted by E00. Display names never participate in saves.

const SWORDSMAN: StringName = &"swordsman"
const MAGE: StringName = &"mage"
const ARCHER: StringName = &"archer"

const DEFENDER: StringName = &"defender"
const BERSERKER: StringName = &"berserker"
const ELEMENTALIST: StringName = &"elementalist"
const SPIRITUALIST: StringName = &"spiritualist"
const SENTINEL: StringName = &"sentinel"
const HUNTER: StringName = &"hunter"

const SP_MG: StringName = &"sp_mg"
const MG_SP: StringName = &"mg_sp"
const SP_AR: StringName = &"sp_ar"
const AR_SP: StringName = &"ar_sp"
const MG_AR: StringName = &"mg_ar"
const AR_MG: StringName = &"ar_mg"

static func base_class_ids() -> Array[StringName]:
	return [SWORDSMAN, MAGE, ARCHER]

static func pure_evolution_ids() -> Array[StringName]:
	return [DEFENDER, BERSERKER, ELEMENTALIST, SPIRITUALIST, SENTINEL, HUNTER]

static func hybrid_evolution_ids() -> Array[StringName]:
	return [SP_MG, MG_SP, SP_AR, AR_SP, MG_AR, AR_MG]

static func attribute_ids() -> Array[StringName]:
	return [&"str", &"agi", &"vit", &"int", &"dex", &"luk"]

static func equipment_slots() -> Array[StringName]:
	return [&"weapon", &"armor", &"accessory"]

static func is_technical_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64:
		return false
	for index: int in value.length():
		var code := value.unicode_at(index)
		var is_lowercase := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not is_lowercase and not is_digit and code != 95:
			return false
	return true

static func initial_attributes(base_class_id: StringName) -> Dictionary[StringName, int]:
	match base_class_id:
		SWORDSMAN:
			return {&"str": 8, &"agi": 5, &"vit": 8, &"int": 2, &"dex": 5, &"luk": 2}
		MAGE:
			return {&"str": 2, &"agi": 5, &"vit": 5, &"int": 9, &"dex": 7, &"luk": 2}
		ARCHER:
			return {&"str": 3, &"agi": 7, &"vit": 5, &"int": 2, &"dex": 10, &"luk": 3}
	return {}

static func is_base_class(identity_id: StringName) -> bool:
	return identity_id in base_class_ids()

static func is_evolution(evolution_id: StringName) -> bool:
	return evolution_id in pure_evolution_ids() or evolution_id in hybrid_evolution_ids()

static func evolution_belongs_to(evolution_id: StringName, base_class_id: StringName) -> bool:
	if not is_evolution(evolution_id) or not is_base_class(base_class_id):
		return false
	return evolution_origin(evolution_id) == base_class_id

static func evolution_origin(evolution_id: StringName) -> StringName:
	match evolution_id:
		DEFENDER, BERSERKER, SP_MG, SP_AR:
			return SWORDSMAN
		ELEMENTALIST, SPIRITUALIST, MG_SP, MG_AR:
			return MAGE
		SENTINEL, HUNTER, AR_SP, AR_MG:
			return ARCHER
		_:
			return &""

static func character_id(profile_id: String, counter: int) -> String:
	assert(not profile_id.is_empty())
	assert(counter > 0)
	return "%s_%d" % [profile_id, counter]

static func run_id(profile_id: String, counter: int) -> String:
	assert(not profile_id.is_empty())
	assert(counter > 0)
	return "%s_%d" % [profile_id, counter]

static func new_profile_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
