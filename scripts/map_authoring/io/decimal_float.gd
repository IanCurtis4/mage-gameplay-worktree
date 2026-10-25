@tool
extends RefCounted
## Correct nearest-even decimal conversion around Godot's approximate String.to_float.
## Exact comparisons use integer decimal strings only on the uncommon unstable path.
static var _cache: Dictionary = {}
static var _cache_mutex := Mutex.new()

static func parse(token: String) -> float:
	_cache_mutex.lock()
	if _cache.has(token):
		var cached: float = _cache[token]
		_cache_mutex.unlock()
		return cached
	_cache_mutex.unlock()
	var approximate := token.to_float()
	if not is_finite(approximate): return approximate
	if JSON.stringify(approximate,"",true,true) == token: return approximate
	var negative := token.begins_with("-")
	var decimal := _decimal(token.trim_prefix("-"))
	if decimal.digits == "0": return -0.0 if negative else 0.0
	var bytes := PackedByteArray(); bytes.resize(8); bytes.encode_double(0,absf(approximate))
	var bits := bytes.decode_s64(0)
	var low: int = 0; var high: int = 0x7fefffffffffffff
	for attempt: int in 66:
		var lower := 1 if bits == 0 else _compare(decimal,_midpoint(bits-1,bits))
		var upper := _compare(decimal,_midpoint(bits,bits+1))
		var odd := (bits & 1) != 0
		if (bits == 0 or lower > 0 or (lower == 0 and not odd)) and (upper < 0 or (upper == 0 and not odd)):
			bytes.encode_s64(0,bits)
			var rounded := bytes.decode_double(0)
			if negative: rounded = -rounded
			_cache_mutex.lock()
			if _cache.size() < 8192: _cache[token] = rounded
			_cache_mutex.unlock()
			return rounded
		if lower < 0 or (lower == 0 and odd): high = bits-1
		else: low = bits+1
		if low > high: break
		# Usually one neighboring value suffices; bounded binary search handles extremes.
		if attempt == 0: bits += -1 if lower < 0 or (lower == 0 and odd) else 1
		else: bits = low+((high-low)>>1)
	return NAN # Refuse a value whose exact rounding could not be established.

static func _decimal(token: String) -> Dictionary:
	var parts := token.to_lower().split("e")
	var power := int(parts[1]) if parts.size() == 2 else 0
	var body := parts[0]; var dot := body.find(".")
	if dot >= 0: power -= body.length()-dot-1; body = body.replace(".","")
	return _normalize(body,power)

static func _normalize(digits: String, power: int) -> Dictionary:
	var first := 0
	while first < digits.length()-1 and digits[first] == "0": first += 1
	digits = digits.substr(first)
	while digits.length() > 1 and digits.ends_with("0"): digits = digits.left(-1); power += 1
	return {"digits":digits,"power":power}

static func _binary(bits: int) -> Dictionary:
	var exponent := (bits>>52)&2047
	return {"mantissa":(bits&0xfffffffffffff)+(0 if exponent == 0 else 0x10000000000000),"power":-1074 if exponent == 0 else exponent-1075}

static func _midpoint(a: int, b: int) -> Dictionary:
	var first := _binary(a); var second := _binary(b)
	var power: int = mini(first.power,second.power)
	var mantissa: int = (int(first.mantissa)<<(int(first.power)-power))+(int(second.mantissa)<<(int(second.power)-power))
	power -= 1
	var digits := str(mantissa)
	for i: int in absi(power): digits = _multiply(digits,2 if power >= 0 else 5)
	return _normalize(digits,0 if power >= 0 else power)

static func _multiply(digits: String, factor: int) -> String:
	var output := PackedByteArray(); output.resize(digits.length()+1)
	var carry := 0
	for i: int in range(digits.length()-1,-1,-1):
		var value := (digits.unicode_at(i)-48)*factor+carry
		output[i+1] = 48+value%10; carry = value/10
	output[0] = 48+carry
	return output.slice(1 if carry == 0 else 0).get_string_from_ascii()

static func _compare(a: Dictionary, b: Dictionary) -> int:
	var al: int = a.digits.length()+int(a.power); var bl: int = b.digits.length()+int(b.power)
	if a.digits == "0": return 0 if b.digits == "0" else -1
	if b.digits == "0": return 1
	if al != bl: return -1 if al < bl else 1
	var width: int = maxi(a.digits.length(),b.digits.length())
	var left: String = a.digits+"0".repeat(width-a.digits.length()); var right: String = b.digits+"0".repeat(width-b.digits.length())
	return 0 if left == right else (-1 if left < right else 1)
