extends "res://scripts/ui/classes/kit_onboarding_base.gd"
## E10a T10: read-only guide of priest (texts from docs/HYBRIDS_56_V3.md and e10a_contract.md).

func identity_id() -> StringName:
	return &"priest"

func guide_title() -> String:
	return "SANTUÁRIO DO SACERDOTE"

func accent_color() -> Color:
	return Color("f4e4a6")

func status_text() -> String:
	return "Curar além da vida cheia gera Graça → o Santuário e o Juízo gastam a Graça."

func help_text() -> String:
	return "Santuário (job 20): círculo de luz no ponto escolhido, um por vez; dentro dele você recebe menos dano, a cura rende mais e os inimigos queimam.
Graça: a cura que passa do máximo vira cargas (até 5); entrar no Santuário com a Graça cheia dá um pulso de cura.
Égide: escudo de luz com um pulso ao ser erguido.
Juízo: gasta a Graça; dentro do Santuário atinge todos os inimigos do círculo.
Exorcista: a luz remove o escudo ou o melhor reforço do inimigo; sem nada a remover, o deixa Exposto.
Selo de Luz: prende o alvo (lentidão no chefe); dano de luz nele gera Graça.
Hora Santa: o Santuário cresce, a cura dobra, a Graça não tem limite e o Juízo não custa SP.
Base: Prece e Escudo Votivo alimentam a Graça; Luz Punitiva fere fora do Santuário."
