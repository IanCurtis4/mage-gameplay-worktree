class_name RunCardInventory
extends RefCounted
## Run-only ownership. All public containers are copies; candidate mutation is isolated.

var _owned: Array[StringName] = []
var _sockets: Dictionary = {}
var revision := 0

func describe() -> Dictionary:
	var free := _owned.duplicate()
	for card: StringName in _sockets.values():
		free.erase(card)
	return {"owned": _owned.duplicate(), "free": free, "sockets": _sockets.duplicate(true), "inventory_revision": revision}

func copy_inventory() -> RunCardInventory:
	var copy := RunCardInventory.new()
	copy._owned = _owned.duplicate()
	copy._sockets = _sockets.duplicate(true)
	copy.revision = revision
	return copy

func owns(card_id: StringName) -> bool:
	return card_id in _owned

func grant(card_id: StringName, catalog: BuildEffectCatalog) -> Dictionary:
	if catalog == null or catalog.get_definition(&"card", card_id) == null:
		return BuildEffectCatalog.failure(&"unknown_definition")
	if owns(card_id):
		return {"ok": true, "error_code": &"", "request_id": "", "already_applied": true}
	_owned.append(card_id)
	_owned.sort()
	revision += 1
	return {"ok": true, "error_code": &"", "request_id": ""}

func sockets() -> Dictionary:
	return _sockets.duplicate(true)

func preview(intent: Dictionary, equipped: Dictionary) -> Dictionary:
	var copy := copy_inventory()
	for item: Variant in copy._sockets.keys():
		if item not in equipped.values():
			copy._sockets.erase(item)
	var kind := StringName(intent.get("kind", &""))
	var item := StringName(intent.get("item_id", &""))
	if kind in [&"socket", &"transfer"]:
		var card := StringName(intent.get("card_id", &""))
		if not copy.owns(card):
			return BuildEffectCatalog.failure(&"card_not_owned")
		if item not in equipped.values():
			return BuildEffectCatalog.failure(&"socket_item_not_equipped")
		if copy._sockets.has(item) and copy._sockets[item] != card:
			return BuildEffectCatalog.failure(&"socket_occupied")
		var old_item: StringName = &""
		for source: Variant in copy._sockets:
			if copy._sockets[source] == card:
				old_item = StringName(source)
		if kind == &"transfer" and (old_item.is_empty() or old_item != StringName(intent.get("from_item_id", &""))):
			return BuildEffectCatalog.failure(&"invalid_transfer")
		if not old_item.is_empty():
			copy._sockets.erase(old_item)
		copy._sockets[item] = card
	elif kind == &"unsocket":
		if not copy._sockets.has(item):
			return BuildEffectCatalog.failure(&"socket_empty")
		copy._sockets.erase(item)
	copy.revision += 1
	return {"ok": true, "inventory": copy}

func clear() -> void:
	_owned.clear()
	_sockets.clear()
	revision += 1
