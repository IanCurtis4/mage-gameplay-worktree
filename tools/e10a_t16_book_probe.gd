extends "res://tools/e10a_t8_body_probe.gd"
## E10a T16 native evidence: the reduced prayer book (16x24 logical) on the three Acolyte-family bodies, through the
## same real renderer as the T8 probe (CharacterAnimation + EquipmentAttachmentVisual, body picked by kind), plus the
## per-prop angle of the Priest: the scepter keeps its lean (-0.15 south, -0.25 east) while the book and the reliquary
## the same body holds stay straight. Args: <folder>. Captures (2x, 64 poses, south+north then east+west):
##   book_<kind>_{sn,ew}             prayer_book in the main hand (acolyte, priest, cultist)
##   grip_<kind>_{sn,ew}             the same with grip (red) and finger crop (green) markers
##   scepter_priest_{sn,ew}          halo_scepter on the Priest (angle override of the prop)
##   reliquary_priest_{sn,ew}        eye_reliquary on the Priest (straight)
## Run without --headless: Godot --path . --script res://tools/e10a_t16_book_probe.gd -- <folder>

func run() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	for kind: StringName in KINDS:
		await grid(kind, LOADOUTS["book"], "%s · livro reduzido 16×24 · 64 poses" % kind, "book_" + String(kind))
		await grid(kind, LOADOUTS["book"], "%s · livro reduzido · marcadores de grip (vermelho) e dedos (verde)" % kind, "grip_" + String(kind), true)
	await grid(&"priest", LOADOUTS["scepter"], "priest · cetro (ângulo por prop) · 64 poses", "scepter_priest")
	await grid(&"priest", LOADOUTS["reliquary"], "priest · relicário reto · 64 poses", "reliquary_priest")
	write_json("result_book.json", {"checks": checks, "failures": failures, "captures": captures})
	print("E10a T16 book: %d checks, %d captures, %d failures" % [checks, captures.size(), failures])
	quit(1 if failures else 0)
