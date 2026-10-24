extends SceneTree
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var result := Schema.result(false, "arguments_invalid")
	if args.size() >= 2:
		match args[0]:
			"validate", "hash": result = Store.load_source(args[1])
			"create":
				if args.size() == 3: result = Store.save_source(args[1], Document.empty(args[2]), "")
			"copy":
				if args.size() == 4:
					result = Store.load_source(args[1])
					if result.ok: result = Store.save_source(args[2], result.data, "" if args[3] == "absent" else args[3])
			"recover":
				if args.size() == 4:
					result = Store.recover(args[1], args[2])
					if result.ok: result = Store.save_source(args[3], result.data, "")
			"apply":
				if args.size() == 4:
					var original := Store.load_source(args[1])
					result = original
					if original.ok:
						if original.byte_hash != args[3]: result = Schema.result(false, "base_diverged")
						else:
							var proposal := Store.load_source(args[2])
							result = proposal
							if proposal.ok:
								var session := Session.new()
								session.replace(original.data)
								result = session.apply(proposal.data)
								if result.ok: result = Store.save_source(args[1], session.document().to_data(), args[3])
	if result.has("data"): result.erase("data")
	print("MAP_SOURCE_RESULT " + JSON.stringify(result))
	quit(0 if result.ok else 1)
