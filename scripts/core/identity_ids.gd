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

# E09 C1.10: kit hybrids. Kept apart from hybrid_evolution_ids(), whose six-ID list
# is a stable contract; is_evolution()/evolution_origin() accept these as well.
const SP_AC: StringName = &"sp_ac"
const MG_AC: StringName = &"mg_ac"
const SP_LA: StringName = &"sp_la"
const MG_LA: StringName = &"mg_la"
# E10a C1.5: pure kits of the registered Acólito base (origin and branch read from
# ClassKitRegistry, never from a fixed match).
const PRIEST: StringName = &"priest"
const CULTIST: StringName = &"cultist"

# E10a C1: a registered base (ClassBaseRegistry), playable once its module is ready.
const ACOLYTE: StringName = &"acolyte"
# Reserved, non-playable base: affinity label only, never character creation.
const ROGUE: StringName = &"rogue"

## E10a: the registries are reached by path, never by class name. IdentityIds is read by
## almost every script; naming ClassKitRegistry/ClassBaseRegistry here closes script cycles
## (through ClassKit -> PlayerActor) that Godot 4.7.2 does not release at exit.
const _BASE_REGISTRY_PATH := "res://scripts/classes/class_base_registry.gd"
const _KIT_REGISTRY_PATH := "res://scripts/classes/class_kit_registry.gd"

static func _base_registry() -> Script:
	return load(_BASE_REGISTRY_PATH) as Script

static func _kit_registry() -> Script:
	return load(_KIT_REGISTRY_PATH) as Script

## The three E00 bases. Stable contract: registered bases are listed apart
## (registered_base_ids()); is_base_class() accepts both.
static func base_class_ids() -> Array[StringName]:
	return [SWORDSMAN, MAGE, ARCHER]

## E10a C1.1: bases of ClassBaseRegistry, in registry order (whether ready or not).
static func registered_base_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_base_registry().call(&"ids"))
	return result

## E00 bases followed by the registered ones.
static func all_base_ids() -> Array[StringName]:
	var result := base_class_ids()
	result.append_array(registered_base_ids())
	return result

static func is_registered_base(identity_id: StringName) -> bool:
	return bool(_base_registry().call(&"is_base", identity_id))

static func pure_evolution_ids() -> Array[StringName]:
	return [DEFENDER, BERSERKER, ELEMENTALIST, SPIRITUALIST, SENTINEL, HUNTER]

static func hybrid_evolution_ids() -> Array[StringName]:
	return [SP_MG, MG_SP, SP_AR, AR_SP, MG_AR, AR_MG]

## Every kit evolution of ClassKitRegistry: the four E09 hybrids, then the E10a pure kits.
static func kit_evolution_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(_kit_registry().call(&"ids"))
	return result

static func reserved_base_ids() -> Array[StringName]:
	return [ROGUE]

static func is_reserved_base(identity_id: StringName) -> bool:
	return identity_id in reserved_base_ids()

static func is_kit_evolution(evolution_id: StringName) -> bool:
	return evolution_id in kit_evolution_ids()

## Affinity label of a kit hybrid (reserved or registered base); empty for every other
## identity, pure kits included.
static func kit_affinity(evolution_id: StringName) -> StringName:
	return StringName(_kit_registry().call(&"affinity", evolution_id))

static func attribute_ids() -> Array[StringName]:
	return [&"str", &"agi", &"vit", &"int", &"dex", &"luk"]

static func equipment_slots() -> Array[StringName]:
	return [&"head", &"neck", &"shoulders", &"arms", &"torso", &"cloak", &"legs", &"feet", &"main_hand", &"off_hand", &"accessory_1", &"accessory_2", &"accessory_3", &"accessory_4"]

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
	# E10a C1.2: a registered base reads its module (empty while the module has none).
	var registered: Dictionary[StringName, int] = {}
	registered.assign(_base_registry().call(&"initial_attributes", base_class_id))
	return registered

static func is_base_class(identity_id: StringName) -> bool:
	return identity_id in base_class_ids() or is_registered_base(identity_id)

static func is_evolution(evolution_id: StringName) -> bool:
	return evolution_id in pure_evolution_ids() or evolution_id in hybrid_evolution_ids() or evolution_id in kit_evolution_ids()

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
			# E09/E10a: every kit evolution reads its origin from the registry.
			return StringName(_kit_registry().call(&"origin", evolution_id))

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
