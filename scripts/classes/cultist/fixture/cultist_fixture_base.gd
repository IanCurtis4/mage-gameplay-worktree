extends "res://scripts/classes/fixture/fixture_base.gd"
## E10a T7 test stand-in for the Acólito base (T5) under the Cultista: the T1 fixture base
## plus the Madness family authority in the field `madness`, forwarded as the T4 API asks
## of the creating module (configure, tick, death, build change, compact blocker; never the
## Ecstasy hooks, which only the Cultista forwards). Base skills as the sheet says:
## Selo Sombrio (slot 3) and Sussurro (slot 4) add Madness, Prece heals and Escudo Votivo
## grants a shield. Never listed in ClassBaseRegistry.MODULES: tests install it with
## ClassBaseRegistry.install_fixture(&"acolyte", ...) until the real base (T5) is composed.

const WHISPER_RADIUS := 160.0
const SHIELD_FRACTION := 0.20
const PRAYER_FRACTION := 0.15

var madness := MadnessAuthority.new()
## Madness of the Selo Sombrio and of the Sussurro per target and commit.
var base_madness := 25.0
var whisper_serial := 0

func on_attach(player: PlayerActor) -> void:
	super(player)
	madness.configure(player, {"stat_source_id": &"acolyte_ecstasy"})

func on_tick(player: PlayerActor, delta: float) -> void:
	super(player, delta)
	madness.tick(player, delta)

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	var event := MadnessHelpers.cast_event(cast, player.kit_time)
	match skill:
		&"acolyte_shadow_seal":
			var victim := cast.get("target") as CombatActor
			var resolved := super(player, cast)
			if MadnessHelpers.is_live(victim): madness.add(victim, base_madness, event, player)
			return resolved
		&"acolyte_disturbing_whisper":
			_log("resolved:" + String(skill))
			whisper_serial += 1
			for candidate: Variant in MadnessHelpers.enemies_of(player, cast.get("actors", [])):
				var enemy := candidate as CombatActor
				if MadnessHelpers.is_enemy(enemy) and MadnessHelpers.is_live(enemy) and MadnessHelpers.distance(player, enemy) <= WHISPER_RADIUS: madness.add(enemy, base_madness, event, player)
			return true
		&"acolyte_prayer":
			_log("resolved:" + String(skill))
			player.heal_player(player.health.max_hp * PRAYER_FRACTION, skill)
			return true
		&"acolyte_votive_shield":
			_log("resolved:" + String(skill))
			return player.health.grant_shield(player.health.max_hp * SHIELD_FRACTION)
	return super(player, cast)

func on_death(player: PlayerActor) -> void:
	super(player)
	madness.on_death(player)

func on_build_changed(player: PlayerActor) -> void:
	super(player)
	madness.on_build_changed(player)

func snapshot_compact_blocker(player: PlayerActor) -> String:
	var own := super(player)
	return own if not own.is_empty() else madness.compact_blocker(player)
