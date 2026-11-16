extends "res://scripts/ui/classes/kit_onboarding_base.gd"
## E09 T9: read-only guide of the mg_ac kit (text from docs/HYBRIDS_56_V3.md).

func identity_id() -> StringName:
	return &"mg_ac"

func guide_title() -> String:
	return "CÍRCULO DO TAUMATURGO"

func accent_color() -> Color:
	return Color("f0cf8a")

func status_text() -> String:
	return "Círculo Votivo → o primeiro feitiço dentro define o elemento → alternar elementos gera Graça."

func help_text() -> String:
	return "Círculo Votivo (job 20): fogo queima mais, gelo dá DEF e lentidão, raio recupera SP.\nPrisma Votivo: feitiço de elemento diferente, de dentro do círculo, gera Graça.\nRefração Curativa: gasta a Graça, cura e solta uma onda do elemento.\nMudança de Altar: troca o elemento e solta um pulso do antigo.\nCoro dos Elementos: três elementos em sequência deixam o círculo tricolor.\nJuízo Prismático: coluna em três pulsos (fogo, gelo, raio).\nAurora Convergente: círculo enorme, Graça sem limite, feitiços a metade do SP.\nFraqueza: sair do círculo perde tudo."
