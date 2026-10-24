@tool
extends RefCounted
const MAX_BYTES := 16 * 1024 * 1024
const MAX_DEPTH := 32
const MAX_STRING := 65536
const MAX_TOKENS := 2000000
var _text: String
var _pos := 0
var _tokens := 0
var _error := ""
var _number_pattern := RegEx.new()

func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > MAX_BYTES: return {"ok": false, "code": "source_limit_exceeded"}
	if not _valid_utf8(bytes): return {"ok": false, "code": "source_parse_error"}
	_text = bytes.get_string_from_utf8()
	if _text.to_utf8_buffer() != bytes: return {"ok": false, "code": "source_parse_error"}
	_pos = 0
	_tokens = 0
	_error = ""
	_number_pattern.compile("^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$")
	var value: Variant = _value(0)
	_space()
	if _pos != _text.length() and _error.is_empty(): _error = "source_parse_error"
	return {"ok": _error.is_empty(), "code": _error, "value": value}

func _space() -> void:
	while _pos < _text.length() and _text[_pos] in [" ", "\t", "\r", "\n"]: _pos += 1

func _value(depth: int) -> Variant:
	_tokens += 1
	if depth > MAX_DEPTH or _tokens > MAX_TOKENS:
		_error = "source_limit_exceeded"
		return null
	_space()
	if _pos >= _text.length():
		_error = "source_parse_error"
		return null
	var c := _text[_pos]
	if c == '"': return _string()
	if c == "{" or c == "[":
		_pos += 1
		var object: Dictionary = {}
		var array: Array = []
		var closing := "}" if c == "{" else "]"
		_space()
		if _pos < _text.length() and _text[_pos] == closing:
			_pos += 1
			return object if c == "{" else array
		while _error.is_empty():
			if c == "{":
				_space()
				var key: Variant = _string()
				if not _error.is_empty(): return null
				if object.has(key):
					_error = "source_duplicate_key"
					return null
				_space()
				if _pos >= _text.length() or _text[_pos] != ":": break
				_pos += 1
				object[key] = _value(depth + 1)
			else: array.append(_value(depth + 1))
			_space()
			if not _error.is_empty(): return null
			if _pos >= _text.length(): break
			if _text[_pos] == closing:
				_pos += 1
				return object if c == "{" else array
			if _text[_pos] != ",": break
			_pos += 1
		_error = "source_parse_error" if _error.is_empty() else _error
		return null
	var start := _pos
	while _pos < _text.length() and not _text[_pos] in [",", "]", "}", " ", "\t", "\r", "\n"]: _pos += 1
	var token := _text.substr(start, _pos - start)
	if token == "true": return true
	if token == "false": return false
	if token == "null": return null
	if _number_pattern.search(token) == null:
		_error = "source_parse_error"
		return null
	if token.is_valid_int() and token.length() < 19: return token.to_int()
	var number := token.to_float()
	if not is_finite(number): _error = "source_non_finite"
	return number

func _string() -> Variant:
	if _pos >= _text.length() or _text[_pos] != '"':
		_error = "source_parse_error"
		return null
	var start := _pos
	_pos += 1
	while _pos < _text.length():
		var c := _text[_pos]
		_pos += 1
		if c == '"':
			var parser := JSON.new()
			if parser.parse(_text.substr(start, _pos - start)) != OK:
				_error = "source_parse_error"
				return null
			var value: String = parser.data
			if value.length() > MAX_STRING: _error = "source_limit_exceeded"
			return value
		if c == "\\":
			if _pos >= _text.length(): break
			var escape := _text[_pos]
			_pos += 1
			if not escape in ['"', "\\", "/", "b", "f", "n", "r", "t", "u"]: break
			if escape == "u":
				if _pos + 4 > _text.length(): break
				for digit in _text.substr(_pos, 4):
					if not digit in "0123456789abcdefABCDEF": _error = "source_parse_error"
				if not _error.is_empty(): return null
				var unit := _text.substr(_pos, 4).hex_to_int()
				_pos += 4
				if unit >= 0xd800 and unit <= 0xdbff:
					if _text.substr(_pos, 2) != "\\u" or _pos + 6 > _text.length(): break
					var low_text := _text.substr(_pos + 2, 4)
					for digit in low_text:
						if not digit in "0123456789abcdefABCDEF": _error = "source_parse_error"
					if not _error.is_empty(): return null
					var low := low_text.hex_to_int()
					if low < 0xdc00 or low > 0xdfff: break
					_pos += 6
				elif unit >= 0xdc00 and unit <= 0xdfff: break
		elif c.unicode_at(0) < 32: break
	_error = "source_parse_error"
	return null

func _valid_utf8(bytes: PackedByteArray) -> bool:
	var index := 0
	while index < bytes.size():
		var lead := bytes[index]
		index += 1
		if lead < 0x80: continue
		var count := 0
		var scalar := 0
		var minimum := 0
		if lead >= 0xc2 and lead <= 0xdf:
			count = 1
			scalar = lead & 0x1f
			minimum = 0x80
		elif lead >= 0xe0 and lead <= 0xef:
			count = 2
			scalar = lead & 0x0f
			minimum = 0x800
		elif lead >= 0xf0 and lead <= 0xf4:
			count = 3
			scalar = lead & 7
			minimum = 0x10000
		else: return false
		if index + count > bytes.size(): return false
		for offset: int in count:
			var byte := bytes[index + offset]
			if byte < 0x80 or byte > 0xbf: return false
			scalar = (scalar << 6) | (byte & 0x3f)
		if scalar < minimum or scalar > 0x10ffff or (scalar >= 0xd800 and scalar <= 0xdfff): return false
		index += count
	return true
