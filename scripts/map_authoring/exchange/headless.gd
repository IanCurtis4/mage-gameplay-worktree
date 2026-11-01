extends SceneTree
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var result: Dictionary = Exchange.fail("usage")
	if args.size() == 5 and args[0] == "export":
		var source := Exchange.load_json(args[2]); var permissions := Exchange.load_json(args[3])
		result = source if not source.ok else permissions
		if source.ok and permissions.ok: result = Exchange.fail("exchange_invalid_type")
		if source.ok and permissions.ok and source.data is Dictionary and permissions.data is Dictionary:
			result = Exchange.export_bundle(args[1],source.data,permissions.data,"Pedido headless")
			if result.ok:
				var saved := Exchange.save_json(args[4],result.bundle)
				if not saved.ok: result = saved
	elif args.size() in [5,6] and args[0] == "merge":
		# Checkpoint45 (P3c): merge <pedido> <proposta> <atual> <saída.json> [<escolhas.json>]
		# writes the reviewed (three-way) source to a NEW file; nothing else is written.
		var request := Exchange.load_json(args[1]); var next := Exchange.load_json(args[2]); var current := Exchange.load_json(args[3])
		var chosen := Exchange.load_json(args[5]) if args.size() == 6 else {"ok":true,"data":{}}
		result = Exchange.fail("exchange_invalid_type")
		for loaded: Dictionary in [request,next,current,chosen]:
			if not loaded.ok: result = loaded
		if request.ok and next.ok and current.ok and chosen.ok and request.data is Dictionary and next.data is Dictionary and current.data is Dictionary and chosen.data is Dictionary:
			result = Exchange.prepare(request.data,next.data,current.data,Callable(),chosen.data)
			if result.ok:
				var saved := Exchange.save_json(args[4],result.source)
				result["written"] = saved.ok
				if not saved.ok: result = saved
		result.erase("source")
	elif args.size() in [4,5] and args[0] == "review":
		var request := Exchange.load_json(args[1]); var next := Exchange.load_json(args[2]); var current := Exchange.load_json(args[3])
		var chosen := Exchange.load_json(args[4]) if args.size() == 5 else {"ok":true,"data":{}}
		result = Exchange.fail("exchange_invalid_type")
		for loaded: Dictionary in [request,next,current,chosen]:
			if not loaded.ok: result = loaded
		if request.ok and next.ok and current.ok and chosen.ok and request.data is Dictionary and next.data is Dictionary and current.data is Dictionary and chosen.data is Dictionary:
			result = Exchange.prepare(request.data,next.data,current.data,Callable(),chosen.data)
	elif args.size() == 4 and args[0] in ["propose","review"]:
		var request := Exchange.load_json(args[1]); var next := Exchange.load_json(args[2])
		result = request if not request.ok else next
		if request.ok and next.ok: result = Exchange.fail("exchange_invalid_type")
		if request.ok and next.ok and request.data is Dictionary and next.data is Dictionary:
			if args[0] == "propose":
				result = Exchange.propose(request.data,next.data)
				if result.ok:
					var saved := Exchange.save_json(args[3],result.bundle)
					if not saved.ok: result = saved
			else:
				var current := Exchange.load_json(args[3]); result = current
				if current.ok: result = Exchange.fail("exchange_invalid_type")
				if current.ok and current.data is Dictionary: result = Exchange.prepare(request.data,next.data,current.data)
	result.erase("package"); result.erase("bundle")
	print("MAP_EXCHANGE_RESULT "+JSON.stringify(result,"",true,true)); quit(0 if result.ok else 1)
