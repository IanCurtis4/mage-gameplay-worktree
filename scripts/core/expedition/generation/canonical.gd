class_name ExpeditionCanonical
extends RefCounted
## Typed, length-delimited canonical encoding. No locale, pointer, dictionary insertion order or JSON integer loss.
static func encode(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL: return "n"
		TYPE_BOOL: return "b1" if value else "b0"
		TYPE_INT: return "i%s;" % str(value)
		TYPE_FLOAT:
			var bytes := PackedByteArray()
			bytes.resize(8)
			bytes.encode_double(0, 0.0 if value == 0.0 else value)
			return "f" + bytes.hex_encode()
		TYPE_STRING, TYPE_STRING_NAME:
			var string := String(value)
			return "s%d:%s" % [string.to_utf8_buffer().size(), string]
		TYPE_VECTOR3: return "v" + encode([value.x, value.y, value.z])
		TYPE_AABB: return "a" + encode([value.position, value.size])
		TYPE_ARRAY:
			# F10 H4: join once; repeated += copied the whole prefix per item, which
			# made a 26 000-sample height list take ~15 s. Same bytes as before.
			var parts := PackedStringArray(["["])
			for item: Variant in value: parts.append(encode(item))
			parts.append("]")
			return "".join(parts)
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort()
			var parts := PackedStringArray(["{"])
			for key: Variant in keys: parts.append(encode(key)); parts.append(encode(value[key]))
			parts.append("}")
			return "".join(parts)
	return "unsupported"

static func valid(value: Variant, depth: int = 0) -> bool:
	if depth > 64: return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_VECTOR3: return value.is_finite()
		TYPE_AABB: return value.position.is_finite() and value.size.is_finite()
		TYPE_ARRAY:
			for item: Variant in value:
				if not valid(item,depth+1): return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String or not valid(value[key],depth+1): return false
			return true
	return false

static func digest(value: Variant) -> String:
	return encode(value).sha256_text()
