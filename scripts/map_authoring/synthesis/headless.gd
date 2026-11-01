extends SceneTree
## Checkpoint43/44 (F9-05/09): command line for regional synthesis, the same
## service as the editor screens and AX.
##   godot --headless --path <projeto> --script res://scripts/map_authoring/synthesis/headless.gd -- <fonte.json> <pedido.json> [<saída.json>]
## The source is a piece, a map, an encounter document or a patrol document (the
## kind is read from its fields). Prints MAP_SYNTHESIS_RESULT with the proposal
## summary (hashes, diff, metrics). The input is never written; the optional
## output must be a new file (an existing one is refused with io_conflict).
## Checkpoint46 (P3d), receipts:
##   ... -- replay <fonte.json> <índice> [<pacote_replay.json>]   (MAP_SYNTHESIS_REPLAY)
##   ... -- bundle <fonte.json> <índice> <saída.json>             (new file only)
## The index is 1-based, as listed on screen.
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
const Synthesis = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Root = preload("res://scripts/map_authoring/synthesis/root_synthesis.gd")
const Section = preload("res://scripts/map_authoring/synthesis/synthesis_section.gd")
const Receipts = preload("res://scripts/map_authoring/synthesis/receipts.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var result := Synthesis.fail("arguments_invalid")
	if args.size() >= 3 and args[0] in ["replay","bundle"]:
		result = _receipts(args)
		print("MAP_SYNTHESIS_REPLAY " + JSON.stringify(result))
		quit(0 if result.get("ok",false) else 1)
		return
	if args.size() in [2,3]:
		var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1])) if FileAccess.file_exists(args[1]) else null
		var decoded := StrictJSON.new().decode(FileAccess.get_file_as_bytes(args[0])) if FileAccess.file_exists(args[0]) else {"ok":false}
		var kind := Root.kind_of(decoded.value) if decoded.ok and decoded.value is Dictionary else ""
		if not request is Dictionary: result = Synthesis.fail("synthesis_request_invalid")
		elif kind.is_empty(): result = _piece(args,_numbers(request))
		else: result = _root(kind,decoded.value,args,_numbers(request))
	print("MAP_SYNTHESIS_RESULT " + JSON.stringify(result))
	quit(0 if result.get("ok",false) else 1)

func _piece(args: Array, request: Dictionary) -> Dictionary:
	var source := Store.load_source(args[0])
	if not source.ok: return source
	if not source.valid: return Synthesis.fail("source_invalid")
	var proposal := Synthesis.prepare(source.data,request)
	var result := Section.summary(proposal)
	if proposal.ok and args.size() == 3:
		var saved := Store.save_source(args[2],proposal.source,"")
		result["written"] = saved.ok
		if saved.ok: result["ledger"] = Receipts.store("piece",source.data)
		if not saved.ok: result.ok = false; result.code = saved.code
	return result

func _root(kind: String, root: Dictionary, args: Array, request: Dictionary) -> Dictionary:
	var proposal := Root.prepare(kind,root,request)
	var result := proposal.duplicate(true); result.erase("source")
	if not proposal.ok: return result
	result["proposal_hash"] = proposal.source_hash
	if args.size() == 3:
		var written := false
		if not FileAccess.file_exists(args[2]):
			var file := FileAccess.open(args[2],FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(proposal.source,"\t",true,true)); file.close()
				var back := StrictJSON.new().decode(FileAccess.get_file_as_bytes(args[2]))
				written = back.ok and back.value is Dictionary and Root.root_hash(kind,back.value) == proposal.source_hash
		result["written"] = written
		if written: result["ledger"] = Receipts.store(kind,root)
		if not written: result.ok = false; result.code = "io_conflict" if FileAccess.file_exists(args[2]) else "io_failure"
	return result

func _document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return Receipts.fail("io_failure")
	var decoded := StrictJSON.new().decode(FileAccess.get_file_as_bytes(path))
	if not decoded.ok or not decoded.value is Dictionary: return Synthesis.fail("source_invalid")
	var kind := Root.kind_of(decoded.value)
	if kind.is_empty():
		var read := Store.load_source(path)
		if not read.ok or not read.valid: return Synthesis.fail("source_invalid")
		return {"ok":true,"kind":"piece","root":read.data}
	return {"ok":true,"kind":kind,"root":decoded.value}

func _receipts(args: Array) -> Dictionary:
	if not args[2].is_valid_int(): return Synthesis.fail("arguments_invalid")
	var opened := _document(args[1])
	if not opened.ok: return opened
	var index := int(args[2])-1
	if args[0] == "bundle":
		if args.size() != 4: return Synthesis.fail("arguments_invalid")
		var made := Receipts.bundle(opened.kind,opened.root,index)
		if not made.ok: return made
		var saved := Receipts.save_new(args[3],made.bundle)
		return saved if not saved.ok else {"ok":true,"code":"","written":true,"base_hash":made.bundle.receipt.base_hash}
	var base: Dictionary = {}
	if args.size() == 4:
		var decoded := StrictJSON.new().decode(FileAccess.get_file_as_bytes(args[3])) if FileAccess.file_exists(args[3]) else {"ok":false}
		var read := Receipts.read_bundle(decoded.get("value"),opened.kind) if decoded.ok else Receipts.fail("replay_bundle_invalid")
		if not read.ok: return read
		base = read.base
	elif args.size() != 3: return Synthesis.fail("arguments_invalid")
	return Receipts.replay(opened.kind,opened.root,index,Callable(),base)

# JSON numbers arrive as floats; counts in the request are integers.
static func _numbers(request: Dictionary) -> Dictionary:
	var copy := request.duplicate(true)
	var objects: Variant = copy.get("channels",{}).get("objects") if copy.get("channels") is Dictionary else null
	if objects is Dictionary and objects.get("count") is float and objects.count == floor(objects.count): objects.count = int(objects.count)
	return copy
