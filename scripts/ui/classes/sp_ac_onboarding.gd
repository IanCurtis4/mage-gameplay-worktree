extends "res://scripts/ui/classes/kit_onboarding_base.gd"
## E09 T9: read-only guide of the sp_ac kit (text from docs/HYBRIDS_56_V3.md).

func identity_id() -> StringName:
	return &"sp_ac"

func guide_title() -> String:
	return "JURAMENTO DO PALADINO"

func accent_color() -> Color:
	return Color("f4d69a")

func status_text() -> String:
	return "Juramento ergue o cone → golpes de frente geram Graça → Impacto Consagrado a gasta."

func help_text() -> String:
	return "Juramento (job 20): cone de luz à frente do escudo; menos dano de frente e inimigos queimam.\nGraça de Guarda: impacto frontal mitigado e cura excedente geram Graça (até 5).\nImpacto Consagrado: gasta a Graça numa coluna de luz no cone.\nÉgide do Juramento: halo que absorve dano e empurra ao quebrar.\nFé Inabalável: dentro do Juramento, controles duram menos e a cura rende mais.\nSelo do Condenado: prende um inimigo ao Paladino; Provocar soma ao Selo.\nParede de Escudos e Perseverança enchem a Graça.\nHora do Juramento: círculo completo, Graça sem limite, Impacto sem SP.\nFraqueza: o flanco e ataques de fora do cone."
