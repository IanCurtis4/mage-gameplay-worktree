extends "res://scripts/ui/classes/kit_onboarding_base.gd"
## E10a T10: read-only guide of acolyte (texts from docs/HYBRIDS_56_V3.md and e10a_contract.md).

func identity_id() -> StringName:
	return &"acolyte"

func guide_title() -> String:
	return "FÉ E SOMBRA DO ACÓLITO"

func accent_color() -> Color:
	return Color("c9b8f0")

func status_text() -> String:
	return "Selo Sombrio e Sussurro enchem a Loucura → no limiar o inimigo entra em Delírio."

func help_text() -> String:
	return "Luz Punitiva: projétil de luz em linha.
Prece: cura o próprio Acólito ao longo de alguns segundos.
Escudo Votivo: barreira curta que absorve dano.
Loucura: o Selo Sombrio e o Sussurro Perturbador a enchem em cada inimigo; ela decai sem novos ganhos.
Delírio: no limiar, um inimigo comum passa a atacar o aliado inimigo mais próximo por alguns segundos (no máximo 3 por vez). O chefe não delira: fica desorientado.
Visão Eldritch: o próximo Selo ou Sussurro dá o dobro de Loucura.
Devoção: alternar luz e sombra fortalece a skill seguinte.
No job 20 você evolui para Sacerdote (luz e Graça) ou Cultista (Êxtase e Ídolo)."
