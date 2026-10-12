class_name RunCardInventory
extends RefCounted
## Each acquisition is a run-only exemplar. All DTOs and candidates are copies.

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

func grant(card_id: StringName, catalog: BuildEffectCatalog, acquisition_id: String = "") -> Dictionary:
	if catalog == null or catalog.get_definition(&"card", card_id) == null:
		return BuildEffectCatalog.failure(&"unknown_definition")
	if not acquisition_id.is_empty() and _grants.has(acquisition_id):
		if _grants[acquisition_id]["definition_id"] != card_id:
			return BuildEffectCatalog.failure(&"replayed_request")
		return {"ok": true, "already_applied": true, "card_instance_id": _grants[acquisition_id]["instance_id"]}
	var id := StringName("card_%d" % _next_counter)
	_instances[id] = card_id
	_next_counter += 1
	if not acquisition_id.is_empty():
		_grants[acquisition_id] = {"definition_id": card_id, "instance_id": id}
	revision += 1
	return {"ok": true, "card_instance_id": id}

func sockets() -> Dictionary:
	return _sockets.duplicate(true)

func preview(intent: Dictionary, equipped: Dictionary, equipment_instances: Dictionary, equipment_definitions: Dictionary) -> Dictionary:
	var copy := copy_inventory()
	for item: Variant in copy._sockets.keys():
		if item not in equipped.values():
			copy._sockets.erase(item)
	var kind := StringName(intent.get("kind", &""))
	if kind in [&"socket", &"unsocket", &"transfer"]:
		var item := StringName(intent.get("equipment_instance_id", &""))
		if item not in equipped.values() or not equipment_instances.has(item):
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
	_sockets.clear()
	_grants.clear()
	revision += 1
