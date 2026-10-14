extends RefCounted
## Closed E06 equipment and set authoring batch; the production loader registers these Resources.
static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Array in [[&"equipment", "res://resources/e06_inventory_content/equipment/"], [&"set", "res://resources/e06_inventory_content/set/"]]:
		var origin: StringName = row[0]
		var directory := DirAccess.open(String(row[1]))
		if directory == null: continue
		var names: Array[String] = []
		directory.list_dir_begin()
		var name := directory.get_next()
		while not name.is_empty():
			if not directory.current_is_dir() and name.ends_with(".tres"):
				names.append(name)
			name = directory.get_next()
		directory.list_dir_end()
		names.sort()
		for file_name: String in names:
			var definition := load(String(row[1]) + file_name)
			var purpose := "Receita de equipamento E06; metadados e efeitos estão descritos no próprio Resource."
			if origin == &"set": purpose = "Conjunto E06 com thresholds declarados no Resource."
			result.append({"origin": origin, "definition": definition, "purpose": purpose})
	return result
