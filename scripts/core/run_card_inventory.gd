class_name RunCardInventory
extends RefCounted
## Profile-owned collection; the run observes a projection. Candidates are copies.

var _projection_owner: String = ""
var _owners: Dictionary[StringName, String] = {}
var _instances: Dictionary[StringName, StringName] = {}
var _sockets: Dictionary = {}
var _grants: Dictionary = {}
var _next_counter := 1
var revision := 0

func describe() -> Dictionary:
	var owned: Array[StringName] = []
	owned.assign(_instances.keys())
	owned.sort()
	var free := owned.duplicate()
	for socket_list: Array in _sockets.values():
		for card: Variant in socket_list:
			if card != null:
				free.erase(StringName(card))
	return {"owned": owned, "free": free, "instances": _instances.duplicate(true), "sockets": _sockets.duplicate(true), "inventory_revision": revision}

func copy_inventory() -> RunCardInventory:
	var copy := RunCardInventory.new()
	copy._projection_owner = _projection_owner
	copy._owners = _owners.duplicate()
	copy._instances = _instances.duplicate(true)
	copy._sockets = _sockets.duplicate(true)
	copy._grants = _grants.duplicate(true)
	copy._next_counter = _next_counter
	copy.revision = revision
	return copy

func owns(card_instance_id: StringName) -> bool:
	return _instances.has(card_instance_id)

func definition_id(card_instance_id: StringName) -> StringName:
	return _instances.get(card_instance_id, &"")

func grant(card_id: StringName, catalog: BuildEffectCatalog, acquisition_id: String = "", owner_character_id: String = "") -> Dictionary:
	# A scoped runtime inventory has an explicit owner captured by for_character.
	if owner_character_id.is_empty() and not _projection_owner.is_empty(): owner_character_id = _projection_owner
	if catalog == null or catalog.get_definition(&"card", card_id) == null:
		return BuildEffectCatalog.failure(&"unknown_definition")
	if not acquisition_id.is_empty() and _grants.has(acquisition_id):
		if _grants[acquisition_id]["definition_id"] != card_id or owner_of(_grants[acquisition_id]["instance_id"]) != owner_character_id:
			return BuildEffectCatalog.failure(&"replayed_request")
		return {"ok": true, "already_applied": true, "card_instance_id": _grants[acquisition_id]["instance_id"]}
	if _next_counter < 1 or _next_counter >= EquipmentRules.MAX_EXACT_INTEGER: return BuildEffectCatalog.failure(&"invalid_card_counter")
	var id := StringName("card_%d" % _next_counter)
	_instances[id] = card_id
	_owners[id] = owner_character_id
	_next_counter += 1
	if not acquisition_id.is_empty():
		_grants[acquisition_id] = {"definition_id": card_id, "instance_id": id}
	revision += 1
	return {"ok": true, "card_instance_id": id}

func sockets() -> Dictionary:
	return _sockets.duplicate(true)

func preview(intent: Dictionary, equipped: Dictionary, equipment_instances: Dictionary, equipment_definitions: Dictionary) -> Dictionary:
	var copy := copy_inventory()
	var kind := StringName(intent.get("kind", &""))
	if kind not in [&"equip", &"unequip", &"socket", &"unsocket", &"transfer"]:
		return BuildEffectCatalog.failure(&"invalid_intent")
	if kind in [&"socket", &"unsocket", &"transfer"]:
		var item := StringName(intent.get("equipment_instance_id", &""))
		if not equipment_instances.has(item):
			return BuildEffectCatalog.failure(&"socket_item_not_equipped")
		var instance: EquipmentInstance = equipment_instances[item]
		if not EquipmentRules.allows_sockets(equipment_definitions.get(instance.definition_id, {})) or instance.socket_capacity == 0:
			return BuildEffectCatalog.failure(&"socket_not_allowed")
		if typeof(intent.get("socket_index")) != TYPE_INT or intent["socket_index"] < 0 or intent["socket_index"] >= instance.socket_capacity:
			return BuildEffectCatalog.failure(&"invalid_socket_index")
		var index: int = intent["socket_index"]
		var target: Array = copy._sockets.get(item, [])
		if target.is_empty():
			target.resize(instance.socket_capacity)
		if target.size() != instance.socket_capacity:
			return BuildEffectCatalog.failure(&"invalid_socket_capacity")
		if kind == &"unsocket":
			if target[index] == null:
				return BuildEffectCatalog.failure(&"socket_empty")
			target[index] = null
		else:
			var card := StringName(intent.get("card_instance_id", &""))
			if not copy.owns(card):
				return BuildEffectCatalog.failure(&"card_instance_not_owned")
			if target[index] != null:
				return BuildEffectCatalog.failure(&"socket_occupied")
			if kind == &"transfer":
				var from_item := StringName(intent.get("from_equipment_instance_id", &""))
				if typeof(intent.get("from_socket_index")) != TYPE_INT or not copy._sockets.has(from_item):
					return BuildEffectCatalog.failure(&"invalid_transfer")
				var from_index: int = intent["from_socket_index"]
				if from_index < 0 or from_index >= copy._sockets[from_item].size() or copy._sockets[from_item][from_index] != card:
					return BuildEffectCatalog.failure(&"invalid_transfer")
				if from_item == item and from_index == index:
					return BuildEffectCatalog.failure(&"no_change")
				copy._sockets[from_item][from_index] = null
			elif card not in copy.describe()["free"]:
				return BuildEffectCatalog.failure(&"card_instance_already_socketed")
			target[index] = card
		copy._sockets[item] = target
	for host: Variant in copy._sockets.keys():
		if not copy._sockets[host].any(func(value: Variant) -> bool: return value != null):
			copy._sockets.erase(host)
	copy.revision += 1
	return {"ok": true, "inventory": copy}

func clear() -> void:
	_instances.clear()
	_owners.clear()
	_sockets.clear()
	_grants.clear()
	revision += 1

func active_sockets(equipped: Dictionary) -> Dictionary:
	var result := {}
	for host: Variant in _sockets:
		if host in equipped.values(): result[host] = _sockets[host].duplicate()
	return result

func effect_state(equipped: Dictionary) -> Dictionary:
	return {"card_instances": _instances.duplicate(), "card_sockets": active_sockets(equipped)}

func to_record() -> Dictionary:
	var instances := {}; var sockets := {}; var grants := {}
	for id: StringName in _instances: instances[String(id)] = String(_instances[id])
	for host: Variant in _sockets:
		var values: Array = []
		for card: Variant in _sockets[host]: values.append(null if card == null else String(card))
		sockets[String(host)] = values
	for acquisition: String in _grants: grants[acquisition] = {"instance_id":String(_grants[acquisition]["instance_id"]),"definition_id":String(_grants[acquisition]["definition_id"])}
	return {"instances":instances,"sockets":sockets,"next_counter":_next_counter,"grants":grants,"revision":revision}

static func from_record(raw: Variant, equipment: Dictionary, definitions: Dictionary, known_cards: Array[StringName]) -> Dictionary:
	if not raw is Dictionary or raw.size() != 5 or not raw.get("instances") is Dictionary or not raw.get("sockets") is Dictionary or not raw.get("grants") is Dictionary or not EquipmentRules.exact_integer(raw.get("next_counter"),1) or not EquipmentRules.exact_integer(raw.get("revision"),0):
		return BuildEffectCatalog.failure(&"invalid_card_inventory")
	var inventory := RunCardInventory.new()
	inventory._next_counter = int(raw["next_counter"])
	inventory.revision = int(raw["revision"])
	for id: Variant in raw["instances"]:
		if typeof(id) not in [TYPE_STRING,TYPE_STRING_NAME] or typeof(raw["instances"][id]) not in [TYPE_STRING,TYPE_STRING_NAME]: return BuildEffectCatalog.failure(&"invalid_card_inventory")
		var name := String(id)
		var number := name.trim_prefix("card_").to_int()
		if name != "card_%d" % number or number < 1 or number >= inventory._next_counter or StringName(raw["instances"][id]) not in known_cards: return BuildEffectCatalog.failure(&"invalid_card_inventory")
		inventory._instances[StringName(id)] = StringName(raw["instances"][id])
	var seen := {}
	for host: Variant in raw["sockets"]:
		if typeof(host) not in [TYPE_STRING,TYPE_STRING_NAME] or not equipment.has(StringName(host)) or not raw["sockets"][host] is Array: return BuildEffectCatalog.failure(&"invalid_card_inventory")
		var item: EquipmentInstance = equipment[StringName(host)]
		var sockets: Array = raw["sockets"][host]
		if not EquipmentRules.allows_sockets(definitions.get(item.definition_id,{})) or sockets.size() != item.socket_capacity or item.socket_capacity == 0: return BuildEffectCatalog.failure(&"invalid_card_inventory")
		var copied: Array = []
		for card: Variant in sockets:
			if card == null: copied.append(null); continue
			if typeof(card) not in [TYPE_STRING,TYPE_STRING_NAME] or not inventory._instances.has(StringName(card)) or seen.has(StringName(card)): return BuildEffectCatalog.failure(&"invalid_card_inventory")
			seen[StringName(card)] = true; copied.append(StringName(card))
		inventory._sockets[StringName(host)] = copied
	var receipted_instances := {}
	for acquisition: Variant in raw["grants"]:
		var grant: Variant = raw["grants"][acquisition]
		if not acquisition is String or acquisition.is_empty() or acquisition.length()>160 or not grant is Dictionary or grant.size()!=2 or typeof(grant.get("instance_id")) not in [TYPE_STRING,TYPE_STRING_NAME] or typeof(grant.get("definition_id")) not in [TYPE_STRING,TYPE_STRING_NAME]: return BuildEffectCatalog.failure(&"invalid_card_inventory")
		var instance := StringName(grant["instance_id"])
		if inventory.definition_id(instance) != StringName(grant["definition_id"]) or not inventory.owns(instance): return BuildEffectCatalog.failure(&"invalid_card_inventory")
		if receipted_instances.has(instance): return BuildEffectCatalog.failure(&"invalid_card_inventory")
		receipted_instances[instance] = true
		inventory._grants[acquisition] = {"instance_id":instance,"definition_id":StringName(grant["definition_id"])}
	return {"ok":true,"inventory":inventory}

func owner_of(id: StringName) -> String:
	return _owners.get(id, "")

func owner_records() -> Dictionary:
	var result := {}
	for id: StringName in _instances: result[String(id)] = owner_of(id)
	return result

func for_character(character_id: String, equipment: Dictionary) -> RunCardInventory:
	var copy := copy_inventory()
	copy._projection_owner = character_id
	for id: StringName in copy._instances.keys():
		if copy.owner_of(id) != character_id:
			copy._instances.erase(id)
			copy._owners.erase(id)
	for host: Variant in copy._sockets.keys():
		if not equipment.has(host): copy._sockets.erase(host)
	for grant_id: Variant in copy._grants.keys():
		if not copy._instances.has(copy._grants[grant_id]["instance_id"]): copy._grants.erase(grant_id)
	return copy

func merge_character_projection(projection: RunCardInventory, character_id: String, equipment: Dictionary) -> RunCardInventory:
	var copy := copy_inventory()
	for host: Variant in copy._sockets.keys():
		if equipment.has(host) and equipment[host].owner_character_id == character_id: copy._sockets.erase(host)
	for id: StringName in projection._instances:
		if projection.owner_of(id) != character_id: return null
		if copy._instances.has(id) and (copy.owner_of(id) != character_id or copy.definition_id(id) != projection.definition_id(id)): return null
		copy._instances[id] = projection._instances[id]
		copy._owners[id] = character_id
	for acquisition: Variant in projection._grants:
		if copy._grants.has(acquisition) and copy._grants[acquisition] != projection._grants[acquisition]: return null
		copy._grants[acquisition] = projection._grants[acquisition].duplicate(true)
	copy._next_counter = maxi(copy._next_counter, projection._next_counter)
	for host: Variant in projection._sockets:
		if not equipment.has(host) or equipment[host].owner_character_id != character_id: return null
		copy._sockets[host] = projection._sockets[host].duplicate()
	copy.revision = projection.revision
	return copy
