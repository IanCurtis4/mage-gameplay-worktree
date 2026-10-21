class_name ExpeditionRewardPolicy
extends RefCounted
## Exact floor(amount * (digit/10)^generation). Decimal integer arithmetic avoids
## 100 * 0.7^2 becoming 48 through binary floating point error. No repeated floors.
static func scale_integer(amount: int, generation: int, digit: int) -> int:
	if amount < 0 or generation < 0 or digit < 0 or digit > 9: return -1
	var number := str(amount)
	for step: int in generation:
		var carry := 0
		var product := ""
		for index: int in range(number.length() - 1, -1, -1):
			var value := (number.unicode_at(index) - 48) * digit + carry
			product = str(value % 10) + product
			carry = value / 10
		if carry > 0: product = str(carry) + product
		number = product.lstrip("0")
		if number.length() <= step + 1: return 0
	return int(number.substr(0, number.length() - generation))
