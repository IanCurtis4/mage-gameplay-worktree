extends ClassKit
## E09 K2 — Taumaturgo (`mg_ac`): Mago → Acólito (Elementalista + Sacerdote).
## Contract with the numbers: docs/epics/e09/k2_contract.md. Seam: T1/T1.1/T1.2
## (docs/epics/e09/t1_kit_seam_api.md). Santuário/Graça: T5 (SanctuaryAuthority).
## The Sanctuary has an element: the first elemental spell cast inside sets the altar,
## alternating elements inside it yields Grace, three in sequence make it tricolor.
## Base fire/ice/lightning spells feed it through on_base_skill_committed (T1.2); the
## Aurora halves spell costs through skill_cost (T1.2, pure). Light = magic damage of a
## skill with element `light` (A2). Data methods are pure; the variables below are run
## state (snapshot fragment).

const CIRCLE := &"thaumaturge_votive_circle"
const PRISM := &"thaumaturge_votive_prism"
const REFRACTION := &"thaumaturge_healing_refraction"
const ALTAR := &"thaumaturge_altar_shift"
const CHOIR := &"thaumaturge_elemental_choir"
const JUDGMENT := &"thaumaturge_prismatic_judgment"
const DAWN := &"thaumaturge_convergent_dawn"
const SKILLS: Array[StringName] = [CIRCLE, PRISM, REFRACTION, ALTAR, CHOIR, JUDGMENT, DAWN]
const PASSIVES: Array[StringName] = [PRISM, CHOIR]

const ROLE := &"votive"
const GRACE_FAMILY := &"thaumaturge_grace"
const ICE_SOURCE := &"thaumaturge_sanctuary_ice"
const SLOW_SOURCE := &"thaumaturge_judgment_ice"
const NONE := &"none"
const FIRE := &"fire"
const ICE := &"ice"
const LIGHTNING := &"lightning"
const TRICOLOR := &"tricolor"
const ELEMENTS: Array[StringName] = [FIRE, ICE, LIGHTNING]
## Spells halved by the Aurora (k2_contract §3): kit actives except the Aurora and the
## Circle (refused during it) plus the origin's spells. The teleport is not a spell.
const DAWN_SPELLS: Array[StringName] = [REFRACTION, ALTAR, JUDGMENT, &"fireball", &"fire_wall", &"fire_spear", &"ice_spear", &"ice_wall", &"lightning", &"electric_discharge", &"lightning_wall", &"soul_impact", &"haunt", &"phantom_barrier"]

# --- Numbers (k2_contract §3) -------------------------------------------------------
const CIRCLE_SP: Array[float] = [18.0, 19.0, 20.0, 21.0, 22.0]
const CIRCLE_COOLDOWN := 12.0
const CIRCLE_DURATION: Array[float] = [8.0, 9.0, 10.0, 11.0, 12.0]
const CIRCLE_RADIUS: Array[float] = [120.0, 125.0, 130.0, 135.0, 140.0]
const CIRCLE_BURN: Array[float] = [0.10, 0.12, 0.14, 0.16, 0.18]
const CIRCLE_ICE_DEFENSE: Array[float] = [0.10, 0.12, 0.14, 0.16, 0.18]
const CIRCLE_LIGHTNING_SP: Array[float] = [0.40, 0.50, 0.60, 0.70, 0.80]
const PRISM_MAGIC: Array[float] = [0.03, 0.06, 0.09]
const PRISM_GRACE: Array[float] = [1.0, 1.0, 2.0]
const REFRACTION_SP: Array[float] = [20.0, 21.0, 22.0, 23.0, 24.0]
const REFRACTION_COOLDOWN := 8.0
const REFRACTION_HEAL: Array[float] = [0.60, 0.70, 0.80, 0.90, 1.00]
const REFRACTION_WAVE: Array[float] = [0.50, 0.60, 0.70, 0.80, 0.90]
const REFRACTION_FALLBACK_RADIUS := 90.0
const LIGHTNING_SP_FRACTION := 0.05
const ALTAR_SP: Array[float] = [16.0, 17.0, 18.0, 19.0, 20.0]
const ALTAR_COOLDOWN: Array[float] = [10.0, 9.5, 9.0, 8.5, 8.0]
const ALTAR_SHOCK: Array[float] = [0.40, 0.50, 0.60, 0.70, 0.80]
const CHOIR_DURATION: Array[float] = [3.0, 4.0, 5.0]
const JUDGMENT_SP: Array[float] = [26.0, 27.0, 28.0, 29.0, 30.0]
const JUDGMENT_COOLDOWN := 9.0
const JUDGMENT_RANGE := 320.0
const JUDGMENT_POWER: Array[float] = [0.50, 0.60, 0.70, 0.80, 0.90]
const JUDGMENT_INTERVAL := 0.3
const JUDGMENT_FIRE_BONUS := 1.25
const JUDGMENT_SLOW := 0.30
const JUDGMENT_SLOW_DURATION := 1.5
const JUDGMENT_SP_FRACTION := 0.03
const JUDGMENT_MAX_CHARGES := 5
const DAWN_SP: Array[float] = [40.0, 42.0, 44.0, 46.0, 48.0]
const DAWN_COOLDOWN: Array[float] = [60.0, 57.0, 54.0, 51.0, 48.0]
const DAWN_DURATION: Array[float] = [6.0, 6.5, 7.0, 7.5, 8.0]
const DAWN_COST_SCALE := 0.5

# --- Run state (scripts/classes/mg_ac/snapshot_manifest.json) ---------------------------
## Santuário/Graça family authority (T5): the votive zone and Grace.
var sanctuary := SanctuaryAuthority.new()
## Altar element of the circle (none until the first elemental spell inside).
var circle_element: StringName = NONE
## Element of the last elemental spell cast inside the circle ("" after one outside).
var last_element: StringName = &""
## Distinct consecutive elements cast inside (last three) for the Coro.
var choir_sequence: Array[StringName] = []
## Remaining seconds of the tricolor Coro (gameplay clock, frozen in pause).
var choir_remaining := 0.0
## Remaining seconds of the Aurora Convergente.
var dawn_remaining := 0.0
## True when the Aurora opened its own wide circle.
var dawn_opened_zone := false
## Grace charges spent by the last committed Refração (read by resolve_cast).
var refraction_charges := 0
## Grace charges spent by the last committed Juízo.
var judgment_charges := 0
## Target of the pending Juízo pulses (instance ID, relinked by the snapshot).
var victim_id := 0
## Pulses of the Juízo still to fall (2: ice then lightning; 0: none pending).
var judgment_pulses_left := 0
## Seconds until the next pending Juízo pulse.
var judgment_delay := 0.0
## Prototype of the later Juízo pulses (amount per pulse, root of the cast).
var judgment_prototype: DamageRequest

# --- Catalog data (pure) ------------------------------------------------------------

func kit_id() -> StringName:
	return &"mg_ac"

func ready_for_play() -> bool:
	return true

func display_name() -> String:
	return "Taumaturgo"

func skill_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	result.append(_active(CIRCLE, "Círculo Votivo", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, CIRCLE_SP, _fill(CIRCLE_COOLDOWN), CIRCLE_RADIUS, CIRCLE_DURATION, CIRCLE_BURN, [&"votive_circle_zone", &"element_from_first_spell", &"light_burn_pulse"]))
	result.append(_passive(PRISM, "Prisma Votivo", PRISM_MAGIC, PRISM_GRACE, [&"magic_attack_increased", &"grace_on_element_alternation"]))
	var refraction := _active(REFRACTION, "Refração Curativa", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.OFFENSIVE, REFRACTION_SP, _fill(REFRACTION_COOLDOWN), _fill(REFRACTION_FALLBACK_RADIUS), REFRACTION_HEAL, REFRACTION_WAVE, [&"spend_grace_up_to_5", &"heal_missing_hp", &"wave_of_circle_element"])
	refraction.can_crit = true
	result.append(refraction)
	result.append(_active(ALTAR, "Mudança de Altar", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.OFFENSIVE, ALTAR_SP, ALTAR_COOLDOWN, _fill(0.0), ALTAR_SHOCK, _fill(0.0), [&"cycle_circle_element", &"pulse_of_old_element"]))
	result.append(_passive(CHOIR, "Coro dos Elementos", CHOIR_DURATION, _fill(3.0, 3), [&"tricolor_after_three_elements"]))
	var judgment := _active(JUDGMENT, "Juízo Prismático", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.OFFENSIVE, JUDGMENT_SP, _fill(JUDGMENT_COOLDOWN), _fill(JUDGMENT_RANGE), JUDGMENT_POWER, _fill(SanctuaryRules.JUDGMENT_PER_CHARGE), [&"spend_grace_up_to_5", &"light_column_three_pulses", &"judgment_per_charge_0_40"])
	judgment.can_crit = true
	result.append(judgment)
	result.append(_active(DAWN, "Aurora Convergente", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, DAWN_SP, DAWN_COOLDOWN, _fill(0.0), DAWN_DURATION, _fill(DAWN_COST_SCALE), [&"wide_tricolor_circle", &"grace_unlimited", &"spells_half_sp"]))
	return result

func learning_entries() -> Array[Dictionary]:
	return [
		{"skill_id": CIRCLE, "category": &"active", "free_rank": 1, "max_purchased_rank": 4, "job_level": 20},
		{"skill_id": PRISM, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 23},
		{"skill_id": REFRACTION, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 25},
		{"skill_id": ALTAR, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 28},
		{"skill_id": CHOIR, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 31},
		{"skill_id": JUDGMENT, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 34},
		{"skill_id": DAWN, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 37},
	]

func passive_modifier_source(skill_id: StringName, rank: int) -> Dictionary:
	if skill_id != PRISM or rank < 1 or rank > PRISM_MAGIC.size(): return {}
	return {"source_id": &"passive_thaumaturge_votive_prism", "label": "Prisma Votivo", "increased": {&"magic_attack": PRISM_MAGIC[rank - 1]}}

func feedback_recipes() -> Dictionary:
	return {
		CIRCLE: [&"area", &"arcane", &"", FeedbackRecipeCatalog.COMMIT | FeedbackRecipeCatalog.PERIODIC],
		PRISM: [&"buff", &"arcane", &"", 0],
		REFRACTION: [&"heal", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		ALTAR: [&"impact", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		CHOIR: [&"buff", &"arcane", &"", 0],
		JUDGMENT: [&"impact", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		DAWN: [&"buff", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
	}

func skill_texts() -> Dictionary:
	var texts := {
		CIRCLE: {"flavor": "Um aro de vitral se acende no chão e espera a primeira cor.", "effect": "Ergue um Santuário em círculo no chão. O primeiro feitiço de fogo, gelo ou raio lançado de dentro define o elemento: fogo faz os inimigos dentro queimarem mais, gelo dá DEF ao Taumaturgo e deixa os inimigos lentos, raio recupera o SP mais rápido.", "combo": "Fique dentro: fora do círculo, os feitiços zeram a sequência de elementos.", "mechanics": "Círculo fixo no chão; pulso de luz a cada 1s."},
		PRISM: {"flavor": "Cada cor nova que atravessa o vitral vira oração.", "effect": "Aumenta o ATQ mágico. Lançar de dentro do círculo um feitiço de elemento diferente do anterior gera Graça.", "combo": "Bola de Fogo, Lança de Gelo e Relâmpago em rodízio enchem a Graça.", "mechanics": "Passiva automática; reserva de até 5 cargas de Graça."},
		REFRACTION: {"flavor": "A luz guardada volta como cura e transborda em cor.", "effect": "Gasta até 5 cargas de Graça: cura o Taumaturgo e solta uma onda do elemento atual do círculo em todos os inimigos dentro dele.", "combo": "Fogo reforça a onda, gelo deixa lento e raio devolve SP; tricolor faz os três.", "mechanics": "Cura limitada ao HP que falta; sem círculo, a onda tem raio 90."},
		ALTAR: {"flavor": "O vitral gira, e a cor antiga se despede num estalo.", "effect": "Troca o elemento do círculo na hora (fogo, gelo, raio) e solta um pulso do elemento antigo nos inimigos dentro.", "combo": "Conta como lançar o elemento novo dentro do círculo: alterna e avança o Coro.", "mechanics": "Exige o círculo ativo."},
		CHOIR: {"flavor": "Três cores juntas cantam mais alto que uma.", "effect": "Três elementos diferentes lançados em sequência dentro do círculo o deixam tricolor por alguns segundos, com os três efeitos juntos.", "combo": "Fogo, gelo e raio em seguida; a Mudança de Altar também conta.", "mechanics": "Passiva automática; a sequência recomeça ao acionar."},
		JUDGMENT: {"flavor": "Uma coluna de luz desce em três cores.", "effect": "Gasta até 5 cargas de Graça: uma coluna de luz cai sobre o alvo em três pulsos, de fogo, gelo e raio. O dano cresce com cada carga gasta.", "combo": "Fogo bate mais forte, gelo deixa lento e raio devolve SP.", "mechanics": "Dano de luz: % do ATQ mágico × (1 + 0,40 por carga), por pulso."},
		DAWN: {"flavor": "O vitral inteiro amanhece de uma vez.", "effect": "Por alguns segundos, o círculo fica enorme e tricolor, a Graça não tem limite, e os feitiços lançados de dentro custam metade do SP.", "combo": "Alterne elementos sem custo e solte Juízos seguidos.", "mechanics": "Sem círculo, abre um ampliado no Taumaturgo; ao fim, a Graça volta ao teto de 5."},
	}
	for skill: StringName in SKILLS:
		var ranks: Array[String] = []
		for rank: int in range(1, (3 if skill in PASSIVES else 5) + 1): ranks.append(rank_tooltip(skill, rank))
		texts[skill]["ranks"] = ranks
		texts[skill]["mechanics"] = String(texts[skill]["mechanics"]) + " " + " · ".join(ranks)
	return texts

## Per-rank tooltip line (pt-BR) of one skill. Pure.
func rank_tooltip(skill_id: StringName, rank: int) -> String:
	var i := rank - 1
	var limit := 3 if skill_id in PASSIVES else 5
	if i < 0 or i >= limit: return ""
	match skill_id:
		CIRCLE:
			return "R%d: %s SP, %ss, raio %d, queima %d%% do ATQ mágico, gelo +%d%% DEF, raio SP +%s" % [rank, _num(CIRCLE_SP[i]), _num(CIRCLE_DURATION[i]), int(CIRCLE_RADIUS[i]), roundi(CIRCLE_BURN[i] * 100.0), roundi(CIRCLE_ICE_DEFENSE[i] * 100.0), _num(CIRCLE_LIGHTNING_SP[i])]
		PRISM:
			return "R%d: ATQ mágico +%d%%, %d Graça por alternância" % [rank, roundi(PRISM_MAGIC[i] * 100.0), int(PRISM_GRACE[i])]
		REFRACTION:
			return "R%d: %s SP, cura %d%% e onda %d%% do ATQ mágico" % [rank, _num(REFRACTION_SP[i]), roundi(REFRACTION_HEAL[i] * 100.0), roundi(REFRACTION_WAVE[i] * 100.0)]
		ALTAR:
			return "R%d: %s SP, recarga %ss, choque %d%% do ATQ mágico" % [rank, _num(ALTAR_SP[i]), _num(ALTAR_COOLDOWN[i]), roundi(ALTAR_SHOCK[i] * 100.0)]
		CHOIR:
			return "R%d: tricolor por %ss" % [rank, _num(CHOIR_DURATION[i])]
		JUDGMENT:
			return "R%d: %s SP, %d%% do ATQ mágico por pulso, até 5 cargas" % [rank, _num(JUDGMENT_SP[i]), roundi(JUDGMENT_POWER[i] * 100.0)]
		DAWN:
			return "R%d: %s SP, recarga %ss, %ss" % [rank, _num(DAWN_SP[i]), _num(DAWN_COOLDOWN[i]), _num(DAWN_DURATION[i])]
	return ""

func vfx_effects() -> Dictionary:
	return {
		&"thaumaturge_votive_circle": {"skill_id": CIRCLE, "kinds": [&"effect_start"], "size": 140.0},
		&"thaumaturge_votive_burn": {"skill_id": CIRCLE, "kinds": [&"impact"], "size": 48.0},
		&"thaumaturge_refraction_wave": {"skill_id": REFRACTION, "kinds": [&"effect_start"], "size": 140.0},
		&"thaumaturge_refraction_hit": {"skill_id": REFRACTION, "kinds": [&"impact"], "size": 56.0},
		&"thaumaturge_altar_pulse": {"skill_id": ALTAR, "kinds": [&"effect_start"], "size": 140.0},
		&"thaumaturge_altar_shock": {"skill_id": ALTAR, "kinds": [&"impact"], "size": 56.0},
		&"thaumaturge_judgment_mark": {"skill_id": JUDGMENT, "kinds": [&"effect_start"], "size": 64.0},
		&"thaumaturge_judgment_column": {"skill_id": JUDGMENT, "kinds": [&"impact"], "size": 150.0},
		&"thaumaturge_dawn_circle": {"skill_id": DAWN, "kinds": [&"effect_start"], "size": 224.0},
	}

const GOLD := Color(1.0, 0.85, 0.40)
const FIRE_COLOR := Color(1.0, 0.42, 0.20)
const ICE_COLOR := Color(0.50, 0.80, 1.0)
const LIGHTNING_COLOR := Color(1.0, 0.92, 0.35)
const GLASS := [FIRE_COLOR, ICE_COLOR, LIGHTNING_COLOR]

func draw_vfx(effect_id: StringName, canvas: CanvasItem, _pulse: Dictionary, position: Vector2, t: float) -> bool:
	var fade := clampf(1.0 - t, 0.0, 1.0)
	match effect_id:
		&"thaumaturge_votive_circle":
			var reach := 130.0 * minf(1.0, t * 2.5)
			canvas.draw_arc(position, reach, 0.0, TAU, 48, Color(GOLD, 0.9 * fade), 3.0)
			for k: int in 3: canvas.draw_arc(position, reach * 0.82, TAU * k / 3.0 + t, TAU * (k + 1) / 3.0 + t - 0.15, 16, Color(GLASS[k], 0.7 * fade), 2.0)
		&"thaumaturge_votive_burn":
			for k: int in 3: canvas.draw_circle(position + Vector2(-6.0 + 6.0 * k, -12.0 - 18.0 * t - 3.0 * k), 3.5 * fade + 1.0, Color(GLASS[k], 0.85 * fade))
		&"thaumaturge_refraction_wave":
			canvas.draw_arc(position, 20.0 + 120.0 * t, 0.0, TAU, 40, Color(GOLD, fade), 4.0 * fade + 1.0)
			canvas.draw_arc(position + Vector2(0.0, -24.0), 16.0 + 6.0 * sin(t * TAU), 0.0, TAU, 20, Color(1.0, 1.0, 0.92, 0.8 * fade), 2.0)
		&"thaumaturge_refraction_hit":
			for k: int in 3: canvas.draw_line(position + Vector2(0.0, -18.0), position + Vector2(0.0, -18.0) + Vector2.from_angle(TAU * k / 3.0 - PI * 0.5) * (10.0 + 14.0 * t), Color(GLASS[k], fade), 2.0)
		&"thaumaturge_altar_pulse":
			var spin := t * TAU * 0.5
			for k: int in 3: canvas.draw_arc(position, 30.0 + 100.0 * t, spin + TAU * k / 3.0, spin + TAU * (k + 1) / 3.0 - 0.2, 14, Color(GLASS[k], fade), 3.0)
		&"thaumaturge_altar_shock":
			canvas.draw_circle(position + Vector2(0.0, -16.0), 10.0 * fade + 2.0, Color(GOLD, 0.7 * fade))
		&"thaumaturge_judgment_mark":
			canvas.draw_arc(position + Vector2(0.0, -20.0), 36.0 * (1.0 - 0.5 * t), 0.0, TAU, 24, Color(GOLD, fade), 2.5)
		&"thaumaturge_judgment_column":
			# Three staggered pulses: fire, ice, lightning (gameplay delay 0.3 s each).
			for k: int in 3:
				var local := clampf(t * 3.0 - k, 0.0, 1.0)
				if local <= 0.0 or local >= 1.0: continue
				var width := 24.0 * (1.0 - 0.5 * local)
				canvas.draw_rect(Rect2(position + Vector2(-width * 0.5, -150.0), Vector2(width, 150.0)), Color(GLASS[k], 0.55 * (1.0 - local)))
				canvas.draw_rect(Rect2(position + Vector2(-width * 0.2, -150.0), Vector2(width * 0.4, 150.0)), Color(1.0, 1.0, 0.92, 0.8 * (1.0 - local)))
		&"thaumaturge_dawn_circle":
			var reach := 224.0 * minf(1.0, t * 2.0)
			for k: int in 3: canvas.draw_arc(position, reach - 6.0 * k, TAU * k / 3.0, TAU * k / 3.0 + TAU, 48, Color(GLASS[k], 0.8 * fade), 3.0)
			for k: int in 12: canvas.draw_line(position, position + Vector2.from_angle(k * TAU / 12.0) * reach, Color(GOLD, 0.3 * fade), 2.0)
		_:
			return false
	return true

# --- Hooks ----------------------------------------------------------------------------

func on_attach(player: PlayerActor) -> void:
	sanctuary.configure(player, GRACE_FAMILY, ICE_SOURCE)

func temporary_stat_sources(player: PlayerActor) -> Array[Dictionary]:
	return sanctuary.temporary_stat_sources(player)

func on_tick(player: PlayerActor, delta: float) -> void:
	sanctuary.tick(player, delta)
	if choir_remaining > 0.0:
		choir_remaining = maxf(0.0, choir_remaining - delta)
		if choir_remaining <= 0.0: _apply_zone_element(player)
	if dawn_remaining > 0.0:
		dawn_remaining = maxf(0.0, dawn_remaining - delta)
		if dawn_remaining <= 0.0: _end_dawn(player)
	if judgment_pulses_left > 0:
		judgment_delay -= delta
		while judgment_pulses_left > 0 and judgment_delay <= 0.0:
			_judgment_pulse(player)
			judgment_delay += JUDGMENT_INTERVAL

func can_cast(_player: PlayerActor, cast: Dictionary) -> Dictionary:
	var skill := StringName(cast.get("skill_id", &""))
	if skill == CIRCLE and dawn_active(): return {"ok": false, "error_code": &"thaumaturge_dawn_active"}
	if skill == ALTAR and sanctuary.zone(ROLE) == null: return {"ok": false, "error_code": &"thaumaturge_no_circle"}
	return {"ok": true, "error_code": &""}

func on_cast_confirmed(player: PlayerActor, cast: Dictionary) -> void:
	match StringName(cast["skill_id"]):
		REFRACTION: refraction_charges = sanctuary.spend_for_cast(player, cast, 1, JUDGMENT_MAX_CHARGES)
		JUDGMENT: judgment_charges = sanctuary.spend_for_cast(player, cast, 1, JUDGMENT_MAX_CHARGES)

## T1.2: during the Aurora, spells cast from inside the circle cost half the SP.
## Pure read of dawn_remaining and the zone presence (the HUD calls it every frame).
func skill_cost(_player: PlayerActor, skill_id: StringName, base_cost: float) -> float:
	if dawn_active() and skill_id in DAWN_SPELLS and owner_inside_circle(): return base_cost * DAWN_COST_SCALE
	return base_cost

## T1.2: origin fire/ice/lightning spells feed the circle (element, alternation, Coro).
## Called once per paid commit; a repeated call of the same commit changes nothing.
func on_base_skill_committed(player: PlayerActor, skill_id: StringName, context: Dictionary) -> void:
	var element := StringName(context.get("element", &""))
	if element not in ELEMENTS: return
	var zone := sanctuary.zone(ROLE)
	if zone == null or not zone.contains(player, player):
		last_element = &""
		choir_sequence.clear()
		return
	if circle_element == NONE:
		circle_element = element
		_apply_zone_element(player)
	_register_element(player, element, "base:%s@%.5f" % [skill_id, player.kit_time])

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	var values := _rank_values(player, skill, int(cast["rank"]))
	if values == null: return false
	match skill:
		CIRCLE:
			var opened := sanctuary.open_zone(player, _circle_config(values.rank, SanctuaryRules.SHAPE_CIRCLE, values.power, SanctuaryAuthority.cast_point(cast)))
			if not opened["ok"]: return false
			circle_element = NONE
			last_element = &""
			choir_sequence.clear()
			choir_remaining = 0.0
			return true
		REFRACTION:
			return _resolve_refraction(player, values)
		ALTAR:
			return _resolve_altar(player, values)
		JUDGMENT:
			return _resolve_judgment(player, cast, values)
		DAWN:
			return _resolve_dawn(player, cast, values)
	return false

func before_hit_mitigation(player: PlayerActor, hit: Dictionary) -> Dictionary:
	return sanctuary.before_hit(player, hit)

func on_shield_broken(player: PlayerActor, hit: Dictionary, result: Dictionary) -> void:
	sanctuary.on_shield_broken(player, hit, result)

func on_heal(player: PlayerActor, requested: float, applied: float, source: StringName) -> void:
	sanctuary.on_heal(player, requested, applied, source)

func on_death(player: PlayerActor) -> void:
	sanctuary.on_death(player)
	circle_element = NONE
	last_element = &""
	choir_sequence.clear()
	choir_remaining = 0.0
	dawn_remaining = 0.0
	dawn_opened_zone = false
	refraction_charges = 0
	judgment_charges = 0
	_clear_judgment()

func on_build_changed(player: PlayerActor) -> void:
	sanctuary.on_build_changed(player)

func snapshot_compact_blocker(_player: PlayerActor) -> String:
	if dawn_active(): return "thaumaturge_dawn"
	if judgment_pulses_left > 0: return "thaumaturge_judgment"
	return sanctuary.compact_blocker()

# --- HUD (E12 H2, contract §5) ----------------------------------------------------------

## Pure read for the HUD (ragrpg_kit_hud_v1): Grace (unlimited with the deadline in the
## Aurora), the Círculo Votivo deadline with the zone's current element (closes limitation
## 1 of K2), the Coro and Aurora deadlines, the votive zone with its element and the kit
## refusals of the Círculo and the Mudança de Altar. Values come from the
## SanctuaryAuthority and the kit state; no formula.
func hud_state(player: PlayerActor) -> Dictionary:
	var dawn_total := DAWN_DURATION[clampi(_hud_rank(player, DAWN), 1, 5) - 1]
	var resources: Array[Dictionary] = [sanctuary.hud_grace(dawn_total)]
	var zone := sanctuary.zone(ROLE)
	if zone != null and zone.duration > 0.0:
		resources.append({"id": &"thaumaturge_votive_circle", "label": "Círculo Votivo", "kind": &"timer", "remaining": minf(zone.remaining, zone.duration), "total": zone.duration, "element": zone.element})
	if choir_active():
		resources.append({"id": &"thaumaturge_elemental_choir", "label": "Coro Elemental", "kind": &"timer", "remaining": choir_remaining, "total": maxf(CHOIR_DURATION[clampi(_hud_rank(player, CHOIR), 1, 3) - 1], choir_remaining), "element": TRICOLOR})
	if dawn_active():
		resources.append({"id": &"thaumaturge_convergent_dawn", "label": "Aurora Convergente", "kind": &"timer", "remaining": dawn_remaining, "total": maxf(dawn_total, dawn_remaining), "element": SanctuaryAuthority.HUD_LIGHT})
	return {
		"schema": KitHudState.SCHEMA, "kit_id": kit_id(), "resources": resources,
		"skills": {CIRCLE: _hud_readiness(can_cast(player, {"skill_id": CIRCLE})), ALTAR: _hud_readiness(can_cast(player, {"skill_id": ALTAR}))},
		"zones": sanctuary.hud_zones(player),
	}

func _hud_rank(player: PlayerActor, skill: StringName) -> int:
	return maxi(1, player.skill_rank(skill)) if is_instance_valid(player) else 1

## A6 of E12: the readiness of a kit skill is the kit's own can_cast answer (same code).
static func _hud_readiness(answer: Dictionary) -> Dictionary:
	if bool(answer.get("ok", false)): return {"ready": true, "reason": &""}
	return {"ready": false, "reason": StringName(answer.get("error_code", &""))}

# --- Queries (pure) ----------------------------------------------------------------------

func dawn_active() -> bool:
	return dawn_remaining > 0.0

func choir_active() -> bool:
	return choir_remaining > 0.0

func grace_charges() -> int:
	return sanctuary.grace.charges

## Presence of the owner in the votive circle (last presence check of T5).
func owner_inside_circle() -> bool:
	var zone := sanctuary.zone(ROLE)
	return zone != null and zone.owner_inside

## Element the zone shows: tricolor in the Coro or the Aurora, else the altar.
func display_element() -> StringName:
	return TRICOLOR if choir_active() or dawn_active() else circle_element

## Altar after a Mudança de Altar: fire -> ice -> lightning -> fire (none -> fire).
static func next_element(element: StringName) -> StringName:
	var index := ELEMENTS.find(element)
	return ELEMENTS[(index + 1) % ELEMENTS.size()] if index >= 0 else FIRE

# --- Internals --------------------------------------------------------------------------

## An element "cast" inside the circle (base spell or Mudança de Altar): alternation
## Grace with the Prisma (one gain per event key) and the Coro sequence.
func _register_element(player: PlayerActor, element: StringName, key: String) -> void:
	var prism := player.skill_rank(PRISM)
	if prism > 0 and not last_element.is_empty() and last_element != element:
		sanctuary.gain({"key": "alt:" + key}, int(PRISM_GRACE[clampi(prism, 1, 3) - 1]))
	last_element = element
	if choir_sequence.is_empty() or choir_sequence.back() != element: choir_sequence.append(element)
	while choir_sequence.size() > 3: choir_sequence.pop_front()
	var choir := player.skill_rank(CHOIR)
	if choir > 0 and choir_sequence.size() == 3 and choir_sequence[0] != choir_sequence[1] and choir_sequence[1] != choir_sequence[2] and choir_sequence[0] != choir_sequence[2]:
		choir_remaining = CHOIR_DURATION[clampi(choir, 1, 3) - 1]
		choir_sequence.clear()
	_apply_zone_element(player)

func _apply_zone_element(player: PlayerActor) -> void:
	var zone := sanctuary.zone(ROLE)
	if zone == null: return
	var wanted := display_element()
	if zone.element != wanted: sanctuary.set_zone_element(ROLE, wanted, player)

func _resolve_refraction(player: PlayerActor, values: SkillRankDefinition) -> bool:
	var matk := player.stat_breakdown.value(&"magic_attack")
	var heal := SanctuaryHelpers.judgment_amount(matk * values.power, refraction_charges)
	var missing := player.health.max_hp - player.health.current_hp
	# Capped at the missing HP: the Refração's own heal never overflows into Grace.
	if missing > 0.0 and heal > 0.0: player.heal_player(minf(heal, missing), REFRACTION)
	var zone := sanctuary.zone(ROLE)
	var element := display_element() if zone != null else NONE
	var targets := SanctuaryHelpers.judgment_targets(player, SanctuaryHelpers.enemies_of(player), _player_point(player), REFRACTION_FALLBACK_RADIUS, zone)
	var amount := SanctuaryHelpers.judgment_amount(matk * values.secondary_power, refraction_charges)
	if SanctuaryRules.has_fire(element): amount *= float(zone.rules["fire_burn_multiplier"])
	for enemy: CombatActor in targets:
		var request := player.kit_make_request(enemy, REFRACTION, 0.0, amount, DamageRequest.AccuracyMode.GEOMETRY, true)
		player.kit_emit_hit(request, enemy)
		if SanctuaryRules.has_ice(element) and is_instance_valid(enemy) and enemy.is_alive():
			enemy.apply_slow(float(zone.rules["ice_slow"]), float(zone.rules["ice_slow_duration"]), SanctuaryRules.SLOW_SOURCE)
	if SanctuaryRules.has_lightning(element): player.recover_sp(player.max_sp * LIGHTNING_SP_FRACTION)
	player.resources_changed.emit()
	return true

func _resolve_altar(player: PlayerActor, values: SkillRankDefinition) -> bool:
	var zone := sanctuary.zone(ROLE)
	if zone == null: return false
	var old := display_element()
	var fresh := next_element(circle_element)
	sanctuary.pulse_now(player, ROLE, old)
	var amount := player.stat_breakdown.value(&"magic_attack") * values.power
	if SanctuaryRules.has_fire(old): amount *= float(zone.rules["fire_burn_multiplier"])
	if amount > 0.0:
		for candidate: Variant in SanctuaryHelpers.enemies_of(player):
			var enemy := candidate as CombatActor
			if not is_instance_valid(enemy) or not zone.contains(player, enemy): continue
			player.kit_emit_hit(player.kit_make_request(enemy, ALTAR, 0.0, amount, DamageRequest.AccuracyMode.GEOMETRY, true), enemy)
	if SanctuaryRules.has_lightning(old): player.recover_sp(player.max_sp * LIGHTNING_SP_FRACTION)
	circle_element = fresh
	if zone.contains(player, player): _register_element(player, fresh, "altar@%.5f" % player.kit_time)
	else: _apply_zone_element(player)
	player.resources_changed.emit()
	return true

func _resolve_judgment(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var victim := cast.get("target") as CombatActor
	if not is_instance_valid(victim) or not victim.is_alive(): return false
	var base := player.stat_breakdown.value(&"magic_attack") * values.power
	var prototype := SanctuaryHelpers.judgment_request(player, victim, JUDGMENT, base, judgment_charges, values.secondary_power, true)
	if prototype == null: return false
	_clear_judgment()
	# Fire pulse at the commit (direct hit of the cast root), +25%.
	for enemy: CombatActor in _column(player, victim, cast.get("actors", [])):
		var hit := prototype.copy()
		hit.target_id = enemy.get_instance_id()
		hit.magic_damage *= JUDGMENT_FIRE_BONUS
		player.kit_emit_hit(hit, enemy)
	# Ice and lightning pulses: scheduled ticks of a prototype captured now.
	prototype.is_secondary = true
	judgment_prototype = prototype
	victim_id = victim.get_instance_id()
	judgment_pulses_left = 2
	judgment_delay = JUDGMENT_INTERVAL
	return true

func _judgment_pulse(player: PlayerActor) -> void:
	var index := 3 - judgment_pulses_left # 1: ice, 2: lightning
	judgment_pulses_left -= 1
	var victim := instance_from_id(victim_id) as CombatActor if victim_id != 0 else null
	var prototype := judgment_prototype
	if judgment_pulses_left <= 0: _clear_judgment()
	if prototype == null or not is_instance_valid(victim) or not victim.is_alive() or not player.is_alive(): return
	var tick := prototype.scheduled_tick()
	if tick.cancelled: return
	for enemy: CombatActor in _column(player, victim, []):
		var hit := tick.copy()
		hit.target_id = enemy.get_instance_id()
		hit.context = tick.context.copy_context() if tick.context != null else null
		player.kit_emit_hit(hit, enemy)
		if index == 1 and is_instance_valid(enemy) and enemy.is_alive(): enemy.apply_slow(JUDGMENT_SLOW, JUDGMENT_SLOW_DURATION, SLOW_SOURCE)
	if index == 2:
		player.recover_sp(player.max_sp * JUDGMENT_SP_FRACTION)
		player.resources_changed.emit()

func _column(player: PlayerActor, victim: CombatActor, actors: Array) -> Array[CombatActor]:
	var listed: Array = actors if not actors.is_empty() else SanctuaryHelpers.enemies_of(player)
	if listed.is_empty(): listed = [victim]
	var point: Variant = victim.world_point() if player.world_motion != null else victim.global_position
	var targets := SanctuaryHelpers.judgment_targets(player, listed, point)
	if victim not in targets and victim.is_alive(): targets.push_front(victim)
	return targets

func _clear_judgment() -> void:
	judgment_pulses_left = 0
	judgment_delay = 0.0
	judgment_prototype = null
	victim_id = 0

func _resolve_dawn(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var duration := values.power
	var zone := sanctuary.zone(ROLE)
	if zone != null and zone.remaining >= duration:
		if not sanctuary.set_zone_shape(ROLE, SanctuaryRules.SHAPE_WIDE_CIRCLE)["ok"]: return false
		dawn_opened_zone = false
	else:
		var circle_rank := maxi(1, player.skill_rank(CIRCLE))
		var radius := CIRCLE_RADIUS[clampi(circle_rank, 1, 5) - 1]
		var opened := sanctuary.open_zone(player, _circle_config(circle_rank, SanctuaryRules.SHAPE_WIDE_CIRCLE, duration, SanctuaryAuthority.cast_point(cast), radius))
		if not opened["ok"]: return false
		if zone == null:
			circle_element = NONE
			last_element = &""
			choir_sequence.clear()
		dawn_opened_zone = true
	dawn_remaining = duration
	sanctuary.begin_unlimited(duration)
	_apply_zone_element(player)
	return true

func _end_dawn(player: PlayerActor) -> void:
	dawn_remaining = 0.0
	var zone := sanctuary.zone(ROLE)
	if zone != null:
		if dawn_opened_zone: sanctuary.end_zone(ROLE, player)
		elif zone.shape == SanctuaryRules.SHAPE_WIDE_CIRCLE: sanctuary.set_zone_shape(ROLE, SanctuaryRules.SHAPE_CIRCLE, zone.base_radius)
	dawn_opened_zone = false
	_apply_zone_element(player)

func _circle_config(circle_rank: int, shape: StringName, duration: float, point: Variant, radius: float = 0.0) -> Dictionary:
	var i := clampi(circle_rank, 1, 5) - 1
	return {
		"role": ROLE, "skill_id": CIRCLE, "shape": shape, "anchor": SanctuaryRules.ANCHOR_WORLD, "point": point,
		"radius": radius if radius > 0.0 else CIRCLE_RADIUS[i], "duration": duration, "element": NONE,
		"rules": {"owner_damage_taken": 1.0, "heal_multiplier": 1.0, "burn_ratio": CIRCLE_BURN[i], "burn_stat": &"magic_attack", "ice_defense": CIRCLE_ICE_DEFENSE[i], "lightning_sp_regen": CIRCLE_LIGHTNING_SP[i]},
	}

func _player_point(player: PlayerActor) -> Variant:
	return player.world_point() if player.world_motion != null else player.global_position

func _rank_values(player: PlayerActor, skill: StringName, rank: int) -> SkillRankDefinition:
	var values := player.skill_rank_definition(skill) if is_instance_valid(player) else null
	if values != null: return values
	var definition := ClassKitRegistry.skill_definition(skill)
	return definition.rank_definition(clampi(rank, 1, definition.ranks.size())) if definition != null else null

# --- Data builders (pure) ------------------------------------------------------------------

static func _fill(value: float, count: int = 5) -> Array[float]:
	var result: Array[float] = []
	for index: int in count: result.append(value)
	return result

static func _num(value: float) -> String:
	return String.num(value, 2).replace(".", ",")

static func _active(id: StringName, name: String, targeting: SkillDefinition.Targeting, kind: SkillDefinition.ActionKind, costs: Array[float], cooldowns: Array[float], ranges: Array[float], powers: Array[float], secondary: Array[float], effects: Array[StringName]) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.KIT
	definition.targeting = targeting
	definition.action_kind = kind
	definition.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	definition.element = &"light"
	definition.range = ranges[0]
	for index: int in 5:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.sp_cost = costs[index]
		values.cooldown = cooldowns[index]
		values.range = ranges[index]
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition

static func _passive(id: StringName, name: String, powers: Array[float], secondary: Array[float], effects: Array[StringName]) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.category = SkillDefinition.Category.PASSIVE
	definition.handler_id = SkillDefinition.Handler.KIT
	definition.targeting = SkillDefinition.Targeting.SELF
	definition.action_kind = SkillDefinition.ActionKind.DEFENSIVE
	definition.element = &"light"
	for index: int in 3:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition
