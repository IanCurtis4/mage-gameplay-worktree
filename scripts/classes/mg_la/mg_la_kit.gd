extends ClassKit
## E09 K4 — Lâmina Arcana (`mg_la`): Mago → Ladino (Elementalista + Assassino).
## Contract with the numbers: docs/epics/e09/k4_contract.md. Seam: T1/T1.1/T1.2
## (docs/epics/e09/t1_kit_seam_api.md). Costas/ocultação/Sentença: T6 (FlankAuthority).
## The Lâmina vanishes bending the light (own concealment), appears behind the marked
## victim through a teleport validated by the world geometry and cuts it with a crystal
## blade that alternates fire, ice and lightning; the three on the victim give +2
## Sentence and a prismatic reaction. The Sentença Prismática is the C3 execution with
## magic amounts. Every kit request is marked by the authority. Data methods are pure;
## the variables below are run state (scripts/classes/mg_la/snapshot_manifest.json).

const MARK := &"arcane_blade_refracted_mark"
const EDGE := &"arcane_blade_enchanted_edge"
const REFRACTION := &"arcane_blade_refraction"
const LEAP := &"arcane_blade_prismatic_leap"
const FRACTURE := &"arcane_blade_light_fracture"
const SENTENCE := &"arcane_blade_prismatic_sentence"
const SPECTER := &"arcane_blade_prism_specter"
const SKILLS: Array[StringName] = [MARK, EDGE, REFRACTION, LEAP, FRACTURE, SENTENCE, SPECTER]
const PASSIVES: Array[StringName] = [EDGE, FRACTURE]

## Blade elements in order (fire → ice → lightning), the same ids as the base spells.
const ELEMENTS: Array[StringName] = [&"fire", &"ice", &"lightning"]
const ELEMENT_KEY := "arcane_blade_element"
const REACTION_KEY := "arcane_blade_reaction"
const MARK_BONUS_KEY := "arcane_blade_mark_bonus"
const REFLECTION_KEY := "arcane_blade_reflection"
const SPECTER_MARK := &"arcane_blade_specter"
## Sentence sources counted for kit requests and base hits (back, opening, direct).
const COUNTED := {&"back": true, &"concealment": true, &"direct": true}

# --- Numbers (k4_contract §3) ----------------------------------------------------------
const MARK_SP: Array[float] = [8.0, 8.0, 7.0, 7.0, 6.0]
const MARK_COOLDOWN: Array[float] = [4.0, 3.5, 3.0, 2.5, 2.0]
const MARK_RANGE: Array[float] = [420.0, 440.0, 460.0, 480.0, 500.0]
const MARK_BONUS: Array[float] = [0.05, 0.07, 0.09, 0.11, 0.13]
const EDGE_POWER: Array[float] = [1.00, 1.10, 1.20]
const EDGE_REACTION: Array[float] = [0.80, 1.00, 1.20]
const EDGE_RANGE := 50.0
const REFRACTION_SP: Array[float] = [14.0, 14.0, 13.0, 13.0, 12.0]
## Canonical cooldown of the skill (anti double tap); the real recharge is the kit charge.
const REFRACTION_COOLDOWN := 1.0
const REFRACTION_DURATION: Array[float] = [3.0, 3.5, 4.0, 4.5, 5.0]
const REFRACTION_RECHARGE: Array[float] = [14.0, 13.0, 12.0, 11.0, 10.0]
const REFRACTION_MAX_CHARGES := 1
const LEAP_SP: Array[float] = [16.0, 17.0, 18.0, 19.0, 20.0]
const LEAP_COOLDOWN: Array[float] = [8.0, 7.5, 7.0, 6.5, 6.0]
const LEAP_RANGE: Array[float] = [300.0, 320.0, 340.0, 360.0, 380.0]
const LEAP_POWER: Array[float] = [1.30, 1.45, 1.60, 1.75, 1.90]
## Extra teleport reach beyond the cast range: bodies + T6 back gap + this margin.
const LEAP_MARGIN := 8.0
const FRACTURE_SP: Array[float] = [0.08, 0.12, 0.16]
const SENTENCE_SP: Array[float] = [18.0, 19.0, 20.0, 21.0, 22.0]
const SENTENCE_COOLDOWN := 7.0
const SENTENCE_RANGE := 80.0
const SENTENCE_POWER: Array[float] = [1.60, 1.80, 2.00, 2.20, 2.40]
const SPECTER_SP: Array[float] = [36.0, 38.0, 40.0, 42.0, 44.0]
const SPECTER_COOLDOWN: Array[float] = [50.0, 48.0, 46.0, 44.0, 42.0]
const SPECTER_RADIUS := 320.0
const SPECTER_POWER: Array[float] = [0.90, 1.00, 1.10, 1.20, 1.30]
const SPECTER_REFLECTIONS := 3
const SPECTER_STAGGER := 0.20
const SPECTER_MARK_DURATION := 3.0
## Base Teleport exit (k4_contract §3, base interactions).
const EXIT_RADIUS := 220.0
const EXIT_SIGHT := FlankRules.SIGHT_BREAK_DURATION
const TRIAD_KEY_MEMORY := 32

# --- Run state (scripts/classes/mg_la/snapshot_manifest.json) ----------------------------
## Costas/ocultação/Sentença family authority (T6): concealment, victim, Sentence, execution.
var flank := FlankAuthority.new()
## Element of the next crystal blade strike (index into ELEMENTS).
var blade_index := 0
## Victim serial (FlankAuthority.victim_serial) the landed elements belong to.
var triad_serial := 0
## Elements landed on the current victim since the last reaction.
var triad_landed: Array[StringName] = []
## Event keys already counted for the sequence (retry guard), bounded.
var triad_keys: Array[String] = []
## The three elements landed: the prismatic reaction strikes on the next tick.
var reaction_pending := false
var reaction_serial := 0
## Refração charges of the kit and the seconds until the next one (limitation 2 of T6).
var refraction_charges := REFRACTION_MAX_CHARGES
var refraction_recharge := 0.0
## Espectro de Prisma: serial of the current cast and reflections still to strike.
var specter_serial := 0
var specter_pending := 0
## Ground position at the last kit tick (departure of a world Teleporte).
var last_ground := Vector3.ZERO
var has_last_ground := false
var fracture_total := 0

# --- Catalog data (pure) ------------------------------------------------------------

func kit_id() -> StringName:
	return &"mg_la"

func ready_for_play() -> bool:
	return true

func display_name() -> String:
	return "Lâmina Arcana"

func skill_definitions() -> Array[SkillDefinition]:
	var result: Array[SkillDefinition] = []
	result.append(_active(MARK, "Marca Refratada", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.DEFENSIVE, &"arcane", MARK_SP, MARK_COOLDOWN, MARK_RANGE, MARK_BONUS, _fill(0.0), [&"flank_victim", &"see_through", &"kit_damage_on_victim"]))
	result.append(_passive(EDGE, "Lâmina Encantada", &"arcane", EDGE_POWER, EDGE_REACTION, [&"crystal_melee_basic", &"fire_ice_lightning", &"triad_reaction"]))
	result.append(_active(REFRACTION, "Refração", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.DEFENSIVE, &"light", REFRACTION_SP, _fill(REFRACTION_COOLDOWN), _fill(0.0), REFRACTION_DURATION, REFRACTION_RECHARGE, [&"own_concealment", &"kit_charge"]))
	var leap := _active(LEAP, "Salto Prismático", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.OFFENSIVE, &"arcane", LEAP_SP, LEAP_COOLDOWN, LEAP_RANGE, LEAP_POWER, _fill(FlankRules.BACK_GAP), [&"concealed_only", &"teleport_behind", &"back_strike"])
	leap.can_crit = true
	result.append(leap)
	result.append(_passive(FRACTURE, "Fratura de Luz", &"light", FRACTURE_SP, _fill(1.0, 3), [&"execution_kill_refraction_charge", &"execution_kill_sp"]))
	var sentence := _active(SENTENCE, "Sentença Prismática", SkillDefinition.Targeting.SINGLE_TARGET, SkillDefinition.ActionKind.OFFENSIVE, &"light", SENTENCE_SP, _fill(SENTENCE_COOLDOWN), _fill(SENTENCE_RANGE), SENTENCE_POWER, _fill(FlankRules.EXECUTION_PER_CHARGE), [&"flank_execution", &"spend_sentence", &"tricolor"])
	sentence.can_crit = true
	result.append(sentence)
	result.append(_active(SPECTER, "Espectro de Prisma", SkillDefinition.Targeting.SELF, SkillDefinition.ActionKind.OFFENSIVE, &"light", SPECTER_SP, SPECTER_COOLDOWN, _fill(SPECTER_RADIUS), SPECTER_POWER, _fill(float(SPECTER_REFLECTIONS)), [&"three_reflections", &"back_point", &"execution_chain"]))
	return result

func learning_entries() -> Array[Dictionary]:
	return [
		{"skill_id": MARK, "category": &"active", "free_rank": 1, "max_purchased_rank": 4, "job_level": 20},
		{"skill_id": EDGE, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 23, "prerequisites": {}},
		{"skill_id": REFRACTION, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 25, "prerequisites": {}},
		{"skill_id": LEAP, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 28, "prerequisites": {REFRACTION: 1}},
		{"skill_id": FRACTURE, "category": &"passive", "free_rank": 0, "max_purchased_rank": 3, "job_level": 31, "prerequisites": {}},
		{"skill_id": SENTENCE, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 34, "prerequisites": {EDGE: 1}},
		{"skill_id": SPECTER, "category": &"active", "free_rank": 0, "max_purchased_rank": 5, "job_level": 37, "prerequisites": {LEAP: 3}},
	]

## Light recipes use `arcane`: FeedbackRecipeCatalog.ELEMENTS has no `light` (the rule
## element is SkillDefinition.element, A2).
func feedback_recipes() -> Dictionary:
	return {
		MARK: [&"buff", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		EDGE: [&"melee", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		REFRACTION: [&"buff", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		LEAP: [&"teleport", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		FRACTURE: [&"buff", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		SENTENCE: [&"impact", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
		SPECTER: [&"summon", &"arcane", &"", FeedbackRecipeCatalog.COMMIT],
	}

func basic_attack_recipe() -> Array:
	return [&"melee", &"arcane", &"", 0]

func skill_texts() -> Dictionary:
	var texts := {
		MARK: {"flavor": "A luz já escolheu quem vai partir.", "effect": "Marca a vítima: ela acumula Sentença, fica visível através de obstáculos e sofre mais dano dos golpes da Lâmina. Marcar outro inimigo apaga a marca anterior.", "combo": "Marque oculta: a Marca não revela a Refração.", "mechanics": "Uma vítima por vez; Sentença até 5."},
		EDGE: {"flavor": "O cajado guarda uma lâmina que ninguém vê chegar.", "effect": "Conjura uma lâmina de cristal no cajado: o ataque básico vira um golpe corpo a corpo mágico que alterna fogo, gelo e raio. Os três elementos na vítima dão +2 de Sentença e uma reação prismática.", "combo": "A Lança de Gelo na vítima conta como o gelo da sequência.", "mechanics": "Passiva automática; alcance corpo a corpo; a sequência recomeça quando a vítima muda."},
		REFRACTION: {"flavor": "Um prisma onde havia uma silhueta.", "effect": "Dobra a luz e some: os inimigos perdem a Lâmina. Atacar revela; o primeiro golpe ao sair dá +2 de Sentença.", "combo": "Oculta, use o Salto Prismático para aparecer nas costas da vítima.", "mechanics": "Ocultação própria com carga: a carga volta com o tempo ou com a Fratura de Luz."},
		LEAP: {"flavor": "A luz atravessa; a lâmina chega junto.", "effect": "Só oculta: teleporta às costas da vítima marcada e golpeia. Conta como golpe pelas costas e como o primeiro golpe saindo da ocultação.", "combo": "Depois do salto, a lâmina de cristal segue cortando a vítima.", "mechanics": "Ponto às costas validado pelo chão; recusado sem vítima, visível ou sem espaço atrás."},
		FRACTURE: {"flavor": "O que se quebra também refrata.", "effect": "Uma execução que mata (Sentença Prismática ou reflexo do Espectro) devolve a carga da Refração e SP.", "combo": "Mate com a Sentença e some de novo para a próxima vítima.", "mechanics": "Passiva automática; uma vez por abate."},
		SENTENCE: {"flavor": "Três cores, um único corte.", "effect": "Golpe tricolor de perto que gasta toda a Sentença do alvo; o dano cresce com cada carga. Com a Sentença cheia e o alvo ferido abaixo do limiar da categoria, é morte certa. No chefe, só dano muito alto.", "combo": "Se matar, a Fratura de Luz devolve a Refração.", "mechanics": "Execução: % do ATQ mágico × (1 + 0,40 por carga)."},
		SPECTER: {"flavor": "A luz se divide, e cada parte encontra alguém.", "effect": "Três reflexos de cristal, um por elemento, aparecem nas costas de três inimigos diferentes e executam cada um. Na vítima, o reflexo gasta a Sentença.", "combo": "Uma corrente de execuções: cada abate por reflexo aciona a Fratura de Luz.", "mechanics": "A vítima primeiro, depois os mais próximos; um reflexo a cada 0,2 s."},
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
		MARK:
			return "R%d: %s SP, recarga %ss, alcance %d, +%d%% de dano da Lâmina na vítima" % [rank, _num(MARK_SP[i]), _num(MARK_COOLDOWN[i]), roundi(MARK_RANGE[i]), roundi(MARK_BONUS[i] * 100.0)]
		EDGE:
			return "R%d: lâmina %d%% do ATQ mágico, reação %d%%" % [rank, roundi(EDGE_POWER[i] * 100.0), roundi(EDGE_REACTION[i] * 100.0)]
		REFRACTION:
			return "R%d: %s SP, oculta por %ss, carga volta em %ss" % [rank, _num(REFRACTION_SP[i]), _num(REFRACTION_DURATION[i]), _num(REFRACTION_RECHARGE[i])]
		LEAP:
			return "R%d: %s SP, recarga %ss, alcance %d, golpe %d%% do ATQ mágico" % [rank, _num(LEAP_SP[i]), _num(LEAP_COOLDOWN[i]), roundi(LEAP_RANGE[i]), roundi(LEAP_POWER[i] * 100.0)]
		FRACTURE:
			return "R%d: abate por execução devolve a Refração e %d%% do SP máximo" % [rank, roundi(FRACTURE_SP[i] * 100.0)]
		SENTENCE:
			return "R%d: %s SP, %d%% do ATQ mágico, × 3 com 5 cargas" % [rank, _num(SENTENCE_SP[i]), roundi(SENTENCE_POWER[i] * 100.0)]
		SPECTER:
			return "R%d: %s SP, recarga %ss, 3 reflexos de %d%% do ATQ mágico" % [rank, _num(SPECTER_SP[i]), _num(SPECTER_COOLDOWN[i]), roundi(SPECTER_POWER[i] * 100.0)]
	return ""

func vfx_effects() -> Dictionary:
	return {
		&"arcane_blade_mark_prism": {"skill_id": MARK, "kinds": [&"effect_start"], "size": 72.0},
		&"arcane_blade_crystal_swing": {"skill_id": EDGE, "kinds": [&"effect_start"], "size": 72.0},
		&"arcane_blade_triad_burst": {"skill_id": EDGE, "kinds": [&"impact"], "size": 88.0},
		&"arcane_blade_refraction_veil": {"skill_id": REFRACTION, "kinds": [&"effect_start"], "size": 96.0},
		&"arcane_blade_leap_flash": {"skill_id": LEAP, "kinds": [&"effect_start"], "size": 80.0},
		&"arcane_blade_leap_strike": {"skill_id": LEAP, "kinds": [&"impact"], "size": 80.0},
		&"arcane_blade_light_fracture": {"skill_id": FRACTURE, "kinds": [&"effect_start"], "size": 96.0},
		&"arcane_blade_sentence_gather": {"skill_id": SENTENCE, "kinds": [&"effect_start"], "size": 72.0},
		&"arcane_blade_sentence_tricolor": {"skill_id": SENTENCE, "kinds": [&"impact"], "size": 104.0},
		&"arcane_blade_specter_summon": {"skill_id": SPECTER, "kinds": [&"effect_start"], "size": 140.0},
		&"arcane_blade_specter_strike": {"skill_id": SPECTER, "kinds": [&"impact"], "size": 88.0},
	}

const FIRE := Color(0.98, 0.36, 0.20)
const ICE := Color(0.42, 0.78, 1.00)
const BOLT := Color(1.00, 0.88, 0.30)
const CRYSTAL := Color(0.88, 0.94, 1.00)
const LEAD := Color(0.16, 0.17, 0.21)
const TRICOLOR: Array[Color] = [FIRE, ICE, BOLT]

func draw_vfx(effect_id: StringName, canvas: CanvasItem, pulse: Dictionary, position: Vector2, t: float) -> bool:
	var fade := clampf(1.0 - t, 0.0, 1.0)
	var dir: Vector2 = pulse.get("dir", Vector2.RIGHT) if pulse.get("dir") is Vector2 else Vector2.RIGHT
	if dir.is_zero_approx(): dir = Vector2.RIGHT
	dir = dir.normalized()
	var chest := position + Vector2(0.0, -26.0)
	var across := dir.orthogonal()
	match effect_id:
		&"arcane_blade_mark_prism":
			# A small prism over the victim line: triangle with the three colours on its edges.
			var size := 10.0 + 8.0 * minf(1.0, t * 3.0)
			var top := chest + Vector2(0.0, -22.0)
			var points: Array[Vector2] = [top + Vector2(0.0, -size), top + Vector2(size * 0.87, size * 0.5), top + Vector2(-size * 0.87, size * 0.5)]
			for k: int in 3: canvas.draw_line(points[k], points[(k + 1) % 3], Color(TRICOLOR[k], fade), 2.0)
			canvas.draw_circle(top, 2.5, Color(CRYSTAL, fade))
		&"arcane_blade_crystal_swing":
			# Curved crystal halberd arc in front of the staff; a white core over the three hues.
			var radius := 22.0 + 14.0 * minf(1.0, t * 2.5)
			var sweep := 1.6 * minf(1.0, t * 3.0)
			for k: int in 3:
				canvas.draw_arc(chest + dir * 6.0, radius - 3.0 * k, dir.angle() - 0.8, dir.angle() - 0.8 + sweep, 14, Color(TRICOLOR[k], 0.85 * fade), 3.0 - 0.6 * k)
			canvas.draw_line(chest, chest + dir.rotated(-0.8 + sweep) * radius, Color(CRYSTAL, fade), 2.0)
		&"arcane_blade_triad_burst":
			# Three shards converge and burst on the victim.
			for k: int in 3:
				var angle := TAU * k / 3.0 + t * 1.5
				var shard := chest + Vector2.from_angle(angle) * (30.0 * fade + 4.0)
				canvas.draw_line(shard, shard + Vector2.from_angle(angle + PI) * 10.0, Color(TRICOLOR[k], fade), 3.0)
			canvas.draw_circle(chest, 6.0 + 18.0 * t, Color(CRYSTAL, 0.5 * fade))
		&"arcane_blade_refraction_veil":
			# The silhouette folds into a prism of light: shrinking rainbow ring and a glint.
			var radius := 34.0 * fade + 6.0
			for k: int in 3: canvas.draw_arc(chest, radius + 3.0 * k, 0.0, TAU, 28, Color(TRICOLOR[k], 0.6 * fade), 2.0)
			canvas.draw_line(chest - across * 12.0 * fade, chest + across * 12.0 * fade, Color(CRYSTAL, fade), 2.0)
			canvas.draw_circle(chest, 4.0 * fade + 1.0, Color(LEAD, 0.6 * fade))
		&"arcane_blade_leap_flash":
			# Departure: a split beam where the Lâmina was.
			for k: int in 3:
				var offset := across * (float(k) - 1.0) * 5.0
				canvas.draw_line(chest + offset, chest + offset + dir * 46.0 * minf(1.0, t * 3.0), Color(TRICOLOR[k], fade), 2.0)
			canvas.draw_circle(chest, 10.0 * fade, Color(CRYSTAL, 0.4 * fade))
		&"arcane_blade_leap_strike":
			# Arrival behind the victim: a crystal cut across the back.
			canvas.draw_line(chest - across * 22.0 - dir * 8.0, chest + across * 22.0 + dir * 8.0, Color(CRYSTAL, fade), 4.0 * fade + 1.0)
			for k: int in 3: canvas.draw_circle(chest + across * (float(k) - 1.0) * 14.0, 3.0, Color(TRICOLOR[k], fade))
		&"arcane_blade_light_fracture":
			# Light cracks outward from the kill: three rays, one per element.
			for k: int in 6:
				var angle := TAU * k / 6.0
				canvas.draw_line(chest + Vector2.from_angle(angle) * 6.0, chest + Vector2.from_angle(angle) * (14.0 + 30.0 * t), Color(TRICOLOR[k % 3], fade), 2.0)
		&"arcane_blade_sentence_gather":
			# The three colours gather on the blade before the final cut.
			for k: int in 3:
				var angle := TAU * k / 3.0 - t * 4.0
				canvas.draw_circle(chest + dir * 18.0 + Vector2.from_angle(angle) * 20.0 * fade, 3.5, Color(TRICOLOR[k], fade))
		&"arcane_blade_sentence_tricolor":
			# Tricolor final cut with the Sentence charges closing in.
			for k: int in 3:
				var offset := across * (float(k) - 1.0) * 4.0
				canvas.draw_line(chest - dir * 30.0 + offset, chest + dir * 30.0 + offset, Color(TRICOLOR[k], fade), 3.0)
			for k: int in 5:
				var angle := TAU * k / 5.0 + t * 2.0
				canvas.draw_circle(chest + Vector2.from_angle(angle) * (26.0 * fade + 6.0), 3.0, Color(CRYSTAL, fade))
		&"arcane_blade_specter_summon":
			# Three crystal reflections rise around the Lâmina, one per element.
			for k: int in 3:
				var spot := position + Vector2.from_angle(TAU * k / 3.0 - PI * 0.5) * (24.0 + 26.0 * minf(1.0, t * 2.0))
				var color := Color(TRICOLOR[k], 0.8 * fade)
				canvas.draw_line(spot, spot + Vector2(0.0, -40.0), color, 6.0)
				canvas.draw_circle(spot + Vector2(0.0, -46.0), 5.0, color)
		&"arcane_blade_specter_strike":
			# A reflection appears behind the target and cuts.
			canvas.draw_line(chest + Vector2(-16.0, -16.0), chest + Vector2(16.0, 16.0), Color(CRYSTAL, fade), 3.0)
			canvas.draw_line(chest + Vector2(-16.0, 16.0) * fade, chest + Vector2(16.0, -16.0) * fade, Color(TRICOLOR[int(pulse.get("seed", 0)) % 3 if pulse.get("seed") is int else 0], fade), 3.0)
		_:
			return false
	return true

# --- Hooks ----------------------------------------------------------------------------

func on_tick(player: PlayerActor, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	flank.tick(player, delta)
	if refraction_charges < REFRACTION_MAX_CHARGES:
		refraction_recharge = maxf(0.0, refraction_recharge - delta)
		if refraction_recharge <= 0.0:
			refraction_charges += 1
			refraction_recharge = _refraction_recharge(player) if refraction_charges < REFRACTION_MAX_CHARGES else 0.0
	if reaction_pending: _strike_reaction(player)
	if specter_pending > 0: _advance_specter(player)
	var ground := FlankRules.ground_position(player)
	if ground.is_finite():
		last_ground = ground
		has_last_ground = true

func can_cast(player: PlayerActor, cast: Dictionary) -> Dictionary:
	match StringName(cast.get("skill_id", &"")):
		REFRACTION:
			if flank.concealment_armed: return _refuse(&"arcane_blade_already_concealed")
			if refraction_charges <= 0: return _refuse(&"arcane_blade_refraction_recharging")
		LEAP:
			if not player.kit_concealed(): return _refuse(&"arcane_blade_not_concealed")
			var target := cast.get("target") as CombatActor
			if not flank.is_victim(player, target): return _refuse(&"arcane_blade_not_victim")
			var point := flank.back_point(player, target)
			if not point["ok"]: return _refuse(StringName(point["error_code"]))
		SPECTER:
			if _specter_candidates(player, cast).is_empty(): return _refuse(&"arcane_blade_no_reflection_target")
	return {"ok": true, "error_code": &""}

func on_cast_confirmed(player: PlayerActor, cast: Dictionary) -> void:
	if StringName(cast["skill_id"]) == REFRACTION and refraction_charges > 0:
		refraction_charges -= 1
		if refraction_recharge <= 0.0: refraction_recharge = _refraction_recharge(player)

## T1.2 (A13): the base Teleporte is the exit. Every living enemy near the departure loses
## sight of the Lâmina. Never called for refused casts or the basic attack.
func on_base_skill_committed(player: PlayerActor, skill_id: StringName, context: Dictionary) -> void:
	if skill_id != &"teleport" or not is_instance_valid(player): return
	var departure := FlankRules.ground_position(player)
	if bool(context.get("world", false)) and has_last_ground: departure = last_ground
	for enemy: CombatActor in _nearby_actors(player):
		if not enemy.is_alive(): continue
		var offset := FlankRules.ground_position(enemy) - departure
		offset.y = 0.0
		if offset.length() <= EXIT_RADIUS: flank.break_sight(player, enemy, EXIT_SIGHT)

func resolve_cast(player: PlayerActor, cast: Dictionary) -> bool:
	var skill := StringName(cast["skill_id"])
	var values := _rank_values(player, skill, int(cast["rank"]))
	if values == null: return false
	match skill:
		MARK:
			var target := cast.get("target") as CombatActor
			if not is_instance_valid(target) or not target.is_alive(): return false
			return bool(flank.mark_victim(player, target)["ok"])
		REFRACTION:
			return flank.enter_concealment(player, values.power)
		LEAP:
			return _resolve_leap(player, cast, values)
		SENTENCE:
			var target := cast.get("target") as CombatActor
			if not is_instance_valid(target) or not target.is_alive(): return false
			var executed := flank.execute(player, target, SENTENCE, 0.0, _magic(player) * values.power, {"emit": false})
			if not bool(executed["ok"]): return false
			player.kit_emit_hit(_apply_mark_bonus(player, executed["request"], target), target)
			return true
		SPECTER:
			return _resolve_specter(player, cast)
	return false

func basic_attack_profile(player: PlayerActor) -> Dictionary:
	return {"range": EDGE_RANGE, "delivery": &"direct"} if _edge_rank(player) > 0 else {}

## The crystal blade replaces the Mage bolt once the Lâmina Encantada is learned: a new
## magic melee request with the element of the sequence. Every basic attack is marked.
func compose_basic_attack(player: PlayerActor, target: CombatActor, request: DamageRequest) -> DamageRequest:
	var rank := _edge_rank(player)
	if rank <= 0 or request == null: return _mark(player, request, target)
	var element := ELEMENTS[posmod(blade_index, ELEMENTS.size())]
	blade_index = posmod(blade_index + 1, ELEMENTS.size())
	var blade := player.kit_make_request(target, request.skill_id, 0.0, _magic(player) * EDGE_POWER[rank - 1], request.accuracy_mode, request.can_crit)
	blade.effect_snapshot[ELEMENT_KEY] = element
	player.presentation_fact.emit(&"skill_committed", EDGE, player.gameplay_facing(), 0.0)
	return _mark(player, blade, target)

func on_damage_dealt(player: PlayerActor, result: Dictionary) -> void:
	var snapshot: Variant = result.get("effect_snapshot", {})
	var data: Dictionary = snapshot if snapshot is Dictionary else {}
	if bool(data.get(REACTION_KEY, false)): return # the reaction itself never feeds the Sentence
	flank.record_hit(player, result, COUNTED)
	_record_element(player, result, data)

func on_kill_confirmed(player: PlayerActor, result: Dictionary) -> void:
	var kill := flank.on_kill_confirmed(player, result)
	if not bool(kill["first"]) or not bool(kill["execution"]): return
	var rank := player.skill_rank(FRACTURE)
	if rank <= 0: return
	fracture_total += 1
	refraction_charges = mini(REFRACTION_MAX_CHARGES, refraction_charges + 1)
	if refraction_charges >= REFRACTION_MAX_CHARGES: refraction_recharge = 0.0
	player.recover_sp(player.max_sp * FRACTURE_SP[clampi(rank, 1, 3) - 1])
	player.presentation_fact.emit(&"skill_committed", FRACTURE, player.gameplay_facing(), 0.0)

func on_death(player: PlayerActor) -> void:
	flank.on_death(player)
	reaction_pending = false
	triad_landed.clear()
	specter_pending = 0
	for actor: CombatActor in _nearby_actors(player):
		if actor.marks.owner_of(SPECTER_MARK) == player.get_instance_id(): actor.marks.remove(SPECTER_MARK)

func concealment_active(_player: PlayerActor) -> bool:
	return flank.concealment_active()

func on_reveal(player: PlayerActor, duration: float) -> void:
	flank.on_reveal(player, duration)

## Pending reflections are temporary entities: the compact cut is ineligible meanwhile.
func snapshot_compact_blocker(_player: PlayerActor) -> String:
	return "arcane_blade_prism_specter_reflections" if specter_pending > 0 else ""

# --- HUD (E12 H2, contract §5) ----------------------------------------------------------

## Pure read for the HUD (ragrpg_kit_hud_v1): the Refração charge with its own recharge
## (closes limitation 1 of K4), the concealment deadline, the Sentence pips on the living
## victim, the badges of the pending Espectro reflections and the kit readiness of the
## Refração (same code as can_cast). Values come from the FlankAuthority and the kit state.
func hud_state(player: PlayerActor) -> Dictionary:
	var charges := clampi(refraction_charges, 0, REFRACTION_MAX_CHARGES)
	var charge := {"id": &"arcane_blade_refraction", "label": "Refração", "kind": &"charges", "value": charges, "max": REFRACTION_MAX_CHARGES, "element": &"arcane"}
	var refraction := _hud_readiness(can_cast(player, {"skill_id": REFRACTION}))
	refraction["charges"] = charges
	refraction["max_charges"] = REFRACTION_MAX_CHARGES
	if charges < REFRACTION_MAX_CHARGES and refraction_recharge > 0.0:
		var total := maxf(_refraction_recharge(player), refraction_recharge)
		charge["remaining"] = refraction_recharge
		charge["total"] = total
		refraction["recharge_remaining"] = refraction_recharge
		refraction["recharge_total"] = total
	var resources: Array[Dictionary] = [charge]
	var described := flank.describe(player)
	if bool(described["concealment_armed"]) and float(described["concealment_remaining"]) > 0.0:
		var rank := clampi(player.skill_rank(REFRACTION), 1, 5) if is_instance_valid(player) else 1
		var remaining := float(described["concealment_remaining"])
		resources.append({"id": &"flank_concealment", "label": "Ocultação", "kind": &"timer", "remaining": remaining, "total": maxf(REFRACTION_DURATION[rank - 1], remaining), "element": &"arcane"})
	var marks: Array[Dictionary] = []
	var victim_mark := FlankAuthority.hud_victim_mark(described)
	if not victim_mark.is_empty(): marks.append(victim_mark)
	if specter_pending > 0:
		for enemy: CombatActor in _nearby_actors(player):
			if not enemy.is_alive() or enemy.marks.owner_of(SPECTER_MARK) != player.get_instance_id(): continue
			var value: Variant = enemy.marks.value(SPECTER_MARK)
			if not value is Dictionary or int(value.get("serial", -1)) != specter_serial: continue
			var element := StringName(value.get("element", ""))
			marks.append({"target_id": enemy.get_instance_id(), "key": SPECTER_MARK, "kind": &"badge", "element": element if element in ELEMENTS else &""})
	return {
		"schema": KitHudState.SCHEMA, "kit_id": kit_id(), "resources": resources,
		"skills": {REFRACTION: refraction}, "target_marks": marks,
	}

## A6 of E12: the readiness of a kit skill is the kit's own can_cast answer (same code).
static func _hud_readiness(answer: Dictionary) -> Dictionary:
	if bool(answer.get("ok", false)): return {"ready": true, "reason": &""}
	return {"ready": false, "reason": StringName(answer.get("error_code", &""))}

# --- Queries --------------------------------------------------------------------------

func sentence(player: PlayerActor) -> int:
	return flank.sentence(player)

func next_element() -> StringName:
	return ELEMENTS[posmod(blade_index, ELEMENTS.size())]

# --- Internals --------------------------------------------------------------------------

## Every kit request: side and opening at commit (T6), then the Marca bonus on the victim.
func _mark(player: PlayerActor, request: DamageRequest, target: CombatActor) -> DamageRequest:
	flank.mark_request(player, request, target)
	return _apply_mark_bonus(player, request, target)

func _apply_mark_bonus(player: PlayerActor, request: DamageRequest, target: CombatActor) -> DamageRequest:
	var rank := player.skill_rank(MARK)
	if request == null or rank <= 0 or not flank.is_victim(player, target): return request
	var bonus := 1.0 + MARK_BONUS[clampi(rank, 1, 5) - 1]
	request.damage_dealt_multiplier *= bonus
	request.effect_snapshot[MARK_BONUS_KEY] = bonus
	return request

func _resolve_leap(player: PlayerActor, cast: Dictionary, values: SkillRankDefinition) -> bool:
	var target := cast.get("target") as CombatActor
	if not flank.is_victim(player, target): return false
	var bodies := player.collision_radius + target.collision_radius
	if player.world_motion != null and target.world_motion != null:
		bodies = float(player.world_motion.profile()["radius"]) + float(target.world_motion.profile()["radius"])
	var moved := flank.teleport_behind(player, target, values.range + bodies + FlankRules.BACK_GAP + LEAP_MARGIN)
	if not moved["ok"]: return false
	# Limitation 3 of T6: the public pursue command drops a pending flat path and engages
	# the victim with the blade, so the old route does not continue after the teleport.
	player.pursue(target)
	var request := player.kit_make_request(target, LEAP, 0.0, _magic(player) * values.power, DamageRequest.AccuracyMode.GEOMETRY, true)
	player.kit_emit_hit(_mark(player, request, target), target)
	return true

## The three elements on the current victim: +2 Sentence (combo) at once, the reaction
## strike on the next tick (never inside the damage callback that completed the triad).
func _record_element(player: PlayerActor, result: Dictionary, data: Dictionary) -> void:
	if _edge_rank(player) <= 0 or not bool(result.get("landed", false)) or float(result.get("damage", 0.0)) <= 0.0 or bool(result.get("secondary", false)): return
	var element := StringName(data.get(ELEMENT_KEY, &""))
	if element.is_empty() and StringName(result.get("skill_id", &"")) == &"ice_spear": element = &"ice"
	if element not in ELEMENTS: return
	var target := instance_from_id(int(result.get("target_id", 0))) as CombatActor
	if not flank.is_victim(player, target): return
	var key := FlankAuthority.event_key(result)
	if key.is_empty() or key in triad_keys: return
	triad_keys.append(key)
	while triad_keys.size() > TRIAD_KEY_MEMORY: triad_keys.pop_front()
	if triad_serial != flank.victim_serial:
		triad_serial = flank.victim_serial
		triad_landed.clear()
	if element not in triad_landed: triad_landed.append(element)
	if triad_landed.size() < ELEMENTS.size(): return
	triad_landed.clear()
	reaction_serial += 1
	flank.gain(player, target, FlankRules.SOURCE_COMBO, "triad:%d" % reaction_serial)
	reaction_pending = true

func _strike_reaction(player: PlayerActor) -> void:
	reaction_pending = false
	var target := flank.victim(player)
	var rank := _edge_rank(player)
	if target == null or not target.is_alive() or rank <= 0: return
	var request := player.kit_make_request(target, EDGE, 0.0, _magic(player) * EDGE_REACTION[rank - 1], DamageRequest.AccuracyMode.GEOMETRY, false)
	request.effect_snapshot[REACTION_KEY] = true
	player.kit_emit_hit(_mark(player, request, target), target)

func _resolve_specter(player: PlayerActor, cast: Dictionary) -> bool:
	var candidates := _specter_candidates(player, cast)
	if candidates.is_empty(): return false
	specter_serial += 1
	var placed := 0
	for enemy: CombatActor in candidates:
		if placed >= SPECTER_REFLECTIONS: break
		if not flank.back_point(player, enemy)["ok"]: continue
		var value := {"serial": specter_serial, "order": placed, "due": player.kit_time + SPECTER_STAGGER * placed, "element": String(ELEMENTS[placed % ELEMENTS.size()])}
		if enemy.marks.set_mark(SPECTER_MARK, player.get_instance_id(), value, SPECTER_MARK_DURATION): placed += 1
	specter_pending = placed
	if placed > 0: _advance_specter(player)
	return placed > 0

## Victim first (when inside the radius), then the nearest living enemies; distinct actors.
func _specter_candidates(player: PlayerActor, cast: Dictionary) -> Array[CombatActor]:
	var origin := FlankRules.ground_position(player)
	var found: Array[CombatActor] = []
	var distances: Array[float] = []
	var pool: Array = cast.get("actors", [])
	if pool.is_empty(): pool = _nearby_actors(player)
	for candidate: Variant in pool:
		var enemy := candidate as CombatActor
		if not is_instance_valid(enemy) or not enemy.is_alive() or enemy == player or found.has(enemy): continue
		var offset := FlankRules.ground_position(enemy) - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance > SPECTER_RADIUS: continue
		if flank.is_victim(player, enemy): distance = -1.0
		var index := 0
		while index < distances.size() and distances[index] <= distance: index += 1
		found.insert(index, enemy)
		distances.insert(index, distance)
	return found

## One due reflection per tick (one execution per commit key of T6): an execution from
## the reflection point behind its target. Missing marks (death, expiry) are dropped.
func _advance_specter(player: PlayerActor) -> void:
	var pending := 0
	var struck := false
	for enemy: CombatActor in _nearby_actors(player):
		if enemy.marks.owner_of(SPECTER_MARK) != player.get_instance_id(): continue
		var value: Variant = enemy.marks.value(SPECTER_MARK)
		if not value is Dictionary or int(value.get("serial", -1)) != specter_serial:
			enemy.marks.remove(SPECTER_MARK)
			continue
		if struck or float(value.get("due", 0.0)) > player.kit_time + 1.0e-6 or not enemy.is_alive():
			pending += 1
			continue
		enemy.marks.remove(SPECTER_MARK)
		struck = true
		_strike_reflection(player, enemy, StringName(value.get("element", "fire")))
	specter_pending = pending

func _strike_reflection(player: PlayerActor, enemy: CombatActor, element: StringName) -> void:
	if not is_instance_valid(enemy) or not enemy.is_alive(): return
	var rank := clampi(player.skill_rank(SPECTER), 1, 5)
	var point := flank.back_point(player, enemy)
	var executed := flank.execute(player, enemy, SPECTER, 0.0, _magic(player) * SPECTER_POWER[rank - 1], {"emit": false})
	if not bool(executed["ok"]): return
	var request: DamageRequest = executed["request"]
	var flags: Dictionary = request.effect_snapshot[FlankRules.SNAPSHOT_KEY]
	if point["ok"]:
		# The reflection strikes from its own point behind the target, not from the Lâmina.
		var side := FlankRules.side_of(enemy, point["ground"])
		flags["side"] = side["side"]
		flags["cos"] = float(side["cos"])
	request.effect_snapshot[REFLECTION_KEY] = String(element)
	player.kit_emit_hit(_apply_mark_bonus(player, request, enemy), enemy)

func _refraction_recharge(player: PlayerActor) -> float:
	var rank := clampi(player.skill_rank(REFRACTION), 1, 5) if is_instance_valid(player) else 1
	return REFRACTION_RECHARGE[rank - 1]

func _edge_rank(player: PlayerActor) -> int:
	return clampi(player.skill_rank(EDGE), 0, 3) if is_instance_valid(player) else 0

func _magic(player: PlayerActor) -> float:
	return player.stat_breakdown.value(&"magic_attack")

static func _refuse(code: StringName) -> Dictionary:
	return {"ok": false, "error_code": code}

func _nearby_actors(player: PlayerActor) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	if not is_instance_valid(player): return result
	var parents: Array[Node] = [player]
	if player.get_parent() != null: parents.append(player.get_parent())
	for parent: Node in parents:
		for child: Node in parent.get_children():
			if child is CombatActor and child != player and not result.has(child): result.append(child)
	return result

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

static func _active(id: StringName, name: String, targeting: SkillDefinition.Targeting, kind: SkillDefinition.ActionKind, element: StringName, costs: Array[float], cooldowns: Array[float], ranges: Array[float], powers: Array[float], secondary: Array[float], effects: Array[StringName]) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.KIT
	definition.targeting = targeting
	definition.action_kind = kind
	definition.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	definition.element = element
	definition.range = ranges[0]
	for index: int in 5:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.sp_cost = costs[index]
		values.cooldown = cooldowns[index]
		values.range = ranges[index]
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.magic_weight = 1.0
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition

static func _passive(id: StringName, name: String, element: StringName, powers: Array[float], secondary: Array[float], effects: Array[StringName]) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.id = id
	definition.display_name = name
	definition.category = SkillDefinition.Category.PASSIVE
	definition.handler_id = SkillDefinition.Handler.KIT
	definition.targeting = SkillDefinition.Targeting.SELF
	definition.action_kind = SkillDefinition.ActionKind.DEFENSIVE
	definition.element = element
	for index: int in 3:
		var values := SkillRankDefinition.new()
		values.rank = index + 1
		values.power = powers[index]
		values.secondary_power = secondary[index]
		values.magic_weight = 1.0
		values.effect_ids = effects.duplicate()
		definition.ranks.append(values)
	return definition
