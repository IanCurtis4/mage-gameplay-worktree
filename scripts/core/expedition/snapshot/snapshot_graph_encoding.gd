class_name SnapshotGraphEncoding
extends RefCounted
## Physical encoding of the existing explicit graph, never a second runtime serializer.
## Container IDs remain distinct even when their contents compare equal.
const VERSION := 1
const MAX_BYTES := 4 * 1024 * 1024
const MAX_DEPTH := 96
const W_DICTIONARY := 0
const W_ARRAY := 1
const W_REFERENCE := 2
const W_TYPED_ARRAY := 3
const W_TYPED_DICTIONARY := 4
var _indices: Dictionary[String,int] = {}
var _ids: Array[String] = []
var _error: Dictionary = {}

static func encode_snapshot(snapshot: Dictionary) -> Dictionary:
	return SnapshotGraphEncoding.new()._pack(snapshot)

static func decode_snapshot(bytes: PackedByteArray) -> Dictionary:
	return SnapshotGraphEncoding.new()._unpack(bytes)

func _fail(detail: String, code: StringName = &"invalid_payload") -> Variant:
	if _error.is_empty(): _error = {"ok":false,"error_code":code,"detail":detail}
	return null

func _pack(snapshot: Dictionary) -> Dictionary:
	if not snapshot.get("containers") is Dictionary: return _failure("container table")
	for id: Variant in snapshot.containers:
		if not id is String or not id.begins_with("container_"): return _failure("container identity")
		_indices[id] = _ids.size(); _ids.append(id)
	var table: Array = []
	for id: String in _ids:
		var descriptor: Variant = snapshot.containers[id]
		if not descriptor is Dictionary: return _failure("container descriptor")
		var record: Array = [_id_token(id)]
		record.append_array(_descriptor(descriptor))
		table.append(record)
	var body := snapshot.duplicate()
	# Keep the key's original insertion position for exact envelope roundtrips.
	body.containers = null
	var encoded: Array = [VERSION,_wire(body,0),table]
	if not _error.is_empty(): return _error
	var bytes := var_to_bytes(encoded)
	if bytes.size() > MAX_BYTES:
		return {"ok":false,"error_code":&"snapshot_too_large","detail":"compact envelope byte budget","byte_count":bytes.size()}
	return {"ok":true,"encoding":bytes,"byte_count":bytes.size()}

func _failure(detail: String) -> Dictionary:
	_fail(detail)
	return _error

func _id_token(id: String) -> Variant:
	var suffix := id.trim_prefix("container_")
	if suffix.is_valid_int():
		var serial := int(suffix)
		if serial > 0 and id == "container_%06d" % serial: return serial
	return id

func _descriptor(value: Dictionary) -> Array:
	var array_keys := ["$","items","type","class","script"]
	var dictionary_keys := ["$","items","key_type","key_class","key_script","value_type","value_class","value_script"]
	if value.get("$") == "array" and value.keys() == array_keys and value.items is Array:
		var untyped: bool = value.type == TYPE_NIL and value["class"] == "" and value.script == ""
		var result: Array = [0] if untyped else [1,value.type,value["class"],value.script]
		for item: Variant in value.items: result.append(_wire(item,0))
		return result
	if value.get("$") == "dictionary" and value.keys() == dictionary_keys and value.items is Array:
		var untyped: bool = value.key_type == TYPE_NIL and value.value_type == TYPE_NIL and value.key_class == "" and value.key_script == "" and value.value_class == "" and value.value_script == ""
		var result: Array = [2] if untyped else [3,value.key_type,value.key_class,value.key_script,value.value_type,value.value_class,value.value_script]
		for pair: Variant in value.items:
			if not pair is Array or pair.size() != 2: _fail("dictionary pair"); return []
			result.append(_wire(pair[0],0)); result.append(_wire(pair[1],0))
		return result
	# Preserve nonstandard insertion order and extensions instead of dropping data.
	return [4,_wire(value,0)]

func _wire(value: Variant, depth: int) -> Variant:
	if not _error.is_empty(): return null
	if depth > MAX_DEPTH: return _fail("wire depth",&"snapshot_too_large")
	if typeof(value) in [TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID,TYPE_NODE_PATH]: return _fail("runtime handle")
	if value is Dictionary:
		if value.size() == 2 and value.get("$") == "container" and value.has("id"):
			if not value.id is String or not _indices.has(value.id): return _fail("container reference")
			return [W_REFERENCE,_indices[value.id]]
		if value.get_typed_key_script() != null or value.get_typed_value_script() != null or not String(value.get_typed_key_class_name()).is_empty() or not String(value.get_typed_value_class_name()).is_empty(): return _fail("wire class metadata")
		var typed: bool = value.is_typed()
		var result: Array = [W_TYPED_DICTIONARY,value.get_typed_key_builtin(),value.get_typed_value_builtin()] if typed else [W_DICTIONARY]
		for key: Variant in value:
			result.append(_wire(key,depth+1)); result.append(_wire(value[key],depth+1))
		return result
	if value is Array:
		if value.get_typed_script() != null or not String(value.get_typed_class_name()).is_empty(): return _fail("wire class metadata")
		var result: Array = [W_TYPED_ARRAY,value.get_typed_builtin()] if value.is_typed() else [W_ARRAY]
		for item: Variant in value: result.append(_wire(item,depth+1))
		return result
	return value

func _unpack(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty() or bytes.size() > MAX_BYTES: return {"ok":false,"error_code":&"snapshot_too_large"}
	# Native Object decoding is deliberately disabled, as in the legacy codec.
	var encoded: Variant = bytes_to_var(bytes)
	if not encoded is Array or encoded.size() != 3 or typeof(encoded[0]) != TYPE_INT or encoded[0] != VERSION or not encoded[2] is Array: return _failure("encoding version or shape")
	var table: Array = encoded[2]
	var seen := {}
	for record: Variant in table:
		if not record is Array or record.size() < 2: return _failure("container record")
		var token: Variant = record[0]
		var id := ""
		if typeof(token) == TYPE_INT and token > 0: id = "container_%06d" % token
		elif token is String and token.begins_with("container_"): id = token
		else: return _failure("container identity")
		if seen.has(id): return _failure("duplicate container identity")
		seen[id] = true; _ids.append(id)
	var body: Variant = _unwire(encoded[1],0)
	if not _error.is_empty(): return _error
	if not body is Dictionary or not body.has("containers") or body.containers != null: return _failure("container placeholder")
	var containers := {}
	for index: int in table.size():
		containers[_ids[index]] = _restore_descriptor(table[index])
	if not _error.is_empty(): return _error
	body.containers = containers
	return {"ok":true,"snapshot":body}

func _restore_descriptor(record: Array) -> Variant:
	if typeof(record[1]) != TYPE_INT: return _fail("descriptor tag")
	var tag: int = record[1]
	if tag == 4:
		if record.size() != 3: return _fail("descriptor fallback")
		var value: Variant = _unwire(record[2],0)
		if not value is Dictionary: return _fail("descriptor fallback type")
		return value
	if tag not in [0,1,2,3]: return _fail("descriptor tag")
	var start := 2 if tag in [0,2] else (5 if tag == 1 else 8)
	if record.size() < start or (tag in [2,3] and (record.size()-start)%2 != 0): return _fail("descriptor length")
	var items: Array = []
	if tag in [0,1]:
		for index: int in range(start,record.size()): items.append(_unwire(record[index],0))
		return {"$":"array","items":items,"type":TYPE_NIL if tag == 0 else record[2],"class":"" if tag == 0 else record[3],"script":"" if tag == 0 else record[4]}
	for index: int in range(start,record.size(),2): items.append([_unwire(record[index],0),_unwire(record[index+1],0)])
	return {"$":"dictionary","items":items,"key_type":TYPE_NIL if tag == 2 else record[2],"key_class":"" if tag == 2 else record[3],"key_script":"" if tag == 2 else record[4],"value_type":TYPE_NIL if tag == 2 else record[5],"value_class":"" if tag == 2 else record[6],"value_script":"" if tag == 2 else record[7]}

func _builtin(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= TYPE_NIL and value < TYPE_MAX

func _accepts(value: Variant, type: int) -> bool:
	return type == TYPE_NIL or typeof(value) == type

func _unwire(value: Variant, depth: int) -> Variant:
	if not _error.is_empty(): return null
	if depth > MAX_DEPTH: return _fail("wire depth",&"snapshot_too_large")
	if typeof(value) in [TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID,TYPE_NODE_PATH] or value is Dictionary: return _fail("wire value")
	if not value is Array: return value
	if value.is_empty() or typeof(value[0]) != TYPE_INT: return _fail("wire tag")
	var tag: int = value[0]
	if tag == W_REFERENCE:
		if value.size() != 2 or typeof(value[1]) != TYPE_INT or value[1] < 0 or value[1] >= _ids.size(): return _fail("container reference")
		return {"$":"container","id":_ids[value[1]]}
	if tag in [W_ARRAY,W_TYPED_ARRAY]:
		var start := 1 if tag == W_ARRAY else 2
		if value.size() < start or (tag == W_TYPED_ARRAY and not _builtin(value[1])): return _fail("wire array metadata")
		var type: int = TYPE_NIL if tag == W_ARRAY else value[1]
		var result: Array = Array([],type,&"",null)
		for index: int in range(start,value.size()):
			var item: Variant = _unwire(value[index],depth+1)
			if not _accepts(item,type): return _fail("wire array element")
			result.append(item)
		return result
	if tag in [W_DICTIONARY,W_TYPED_DICTIONARY]:
		var start := 1 if tag == W_DICTIONARY else 3
		if value.size() < start or (value.size()-start)%2 != 0: return _fail("wire dictionary length")
		if tag == W_TYPED_DICTIONARY and (not _builtin(value[1]) or not _builtin(value[2])): return _fail("wire dictionary metadata")
		var key_type: int = TYPE_NIL if tag == W_DICTIONARY else value[1]
		var item_type: int = TYPE_NIL if tag == W_DICTIONARY else value[2]
		var result: Dictionary = Dictionary({},key_type,&"",null,item_type,&"",null)
		for index: int in range(start,value.size(),2):
			var key: Variant = _unwire(value[index],depth+1)
			var item: Variant = _unwire(value[index+1],depth+1)
			if not _accepts(key,key_type) or not _accepts(item,item_type) or result.has(key): return _fail("wire dictionary entry")
			result[key] = item
		return result
	return _fail("wire tag")
