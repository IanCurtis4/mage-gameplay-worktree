extends RefCounted
## At most two independent lanes. Each owns its result array; callers observe
## only joined results in source order. No SceneTree or gameplay state here.
const MAX_LANES := 2

static func run(items: Array, prepare: Callable, requested_lanes: int = MAX_LANES) -> Dictionary:
	if items.is_empty(): return {"rows":[],"lanes":0}
	var lanes := mini(items.size(),clampi(requested_lanes,1,MAX_LANES))
	lanes = mini(lanes,maxi(1,OS.get_processor_count()))
	var rows: Array
	if lanes == 1:
		rows = _lane(items,prepare,0,1)
	else:
		var worker := Thread.new()
		# Failed creation uses the identical serial path. Always join before
		# returning, including failures of individual maps.
		if worker.start(_lane.bind(items.duplicate(true),prepare,1,2)) != OK:
			rows = _lane(items,prepare,0,1); lanes = 1
		else:
			rows = _lane(items,prepare,0,2)
			var other: Array = worker.wait_to_finish()
			rows.append_array(other)
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.index) < int(b.index))
	return {"rows":rows,"lanes":lanes}

static func _lane(items: Array, prepare: Callable, ordinal: int, stride: int) -> Array:
	var rows: Array = []
	for index: int in range(ordinal,items.size(),stride):
		var started := Time.get_ticks_usec()
		var built: Dictionary = prepare.call(items[index])
		rows.append({"index":index,"built":built,"prepare_ms":(Time.get_ticks_usec()-started)/1000.0})
	return rows
