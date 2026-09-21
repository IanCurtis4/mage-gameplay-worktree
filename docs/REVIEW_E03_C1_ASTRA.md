# Revisão E03-C1 — Astra

## Nova entrega aprovada

**Aceite técnico concedido a `48a01be`, em 20/09/2026.**
Revisão focalizada confirmou cópias do DamageRequest na parede/aplicação/tick,
preservando componente e multiplicador ofensivos sem duplicação e consultando
defesas atuais. Regeneração de HP ligada ao controller com bloqueios de encontro,
pausa, morte e fim de run, limitada ao máximo. Handoff atualizado está coerente.

Verificação independente: `tools/verify.ps1` em Godot 4.7.2 passou com importação,
952 checks (28 de consumidores) e smoke. Regressões incluem multiplicador zero,
alteração posterior de ofensiva, mudança de defesa e condições de regeneração.
Nenhum bloqueador novo identificado no delta. Não houve teste visual de gameplay.

Liberado E03-C2 com Terra: painel/árvore de progressão sobre APIs aprovadas,
com apoio Luna delimitado para casos/textos de E03-L2 se útil. E03-I e aceite
de gameplay continuam pendentes. Sem merge em master nem integração de código
ao playtest nesta revisão.

## Parecer anterior (resolvido)

Candidato: `21681b2`. Aceite técnico pendente de duas correções.

Handoff `E03_C1_CONSUMERS.md` descreve a migração entregue. O delta centraliza
stats e integra DEF/DEFM, HIT/FLEE, crítico, SP, cooldown e preview/runtime.
Verificação independente com Godot 4.7.2: `tools/verify.ps1` passou com importação,
942 checks (18 de consumidores) e smoke. Não houve playtest visual nesta revisão.

## Pendências

1. **Multiplicador ofensivo perdido na Parede de Fogo/DoT.** O sinal em
   `PlayerActor.use_fire_wall` transmite só `_magic_power`; `FireWall` guarda só
   esse número e `CombatActor.advance_statuses` cria request com multiplicador
   padrão 1. Reprodução isolada `.tools/e03_c1_dot_probe.gd`: emissor com
   `damage_dealt_multiplier=2`, tick com multiplicador 1. Capturar a fonte
   ofensiva no lançamento/aplicação conforme E00, manter durante os ticks e
   consultar defesas atuais no impacto, sem aplicar multiplicador duas vezes.
2. **Regeneração de HP sem consumidor.** E00.2 exige `hp_regen` enquanto vivo,
   fora de encontro e sem pausa. O valor existe no cálculo, mas ator/controller
   só aplicam regeneração de SP. Ligar o valor canônico ao fluxo real e testar
   fora/dentro de encontro, pausa, morte e limite de HP. Não confundir regeneração
   temporal com cura indevida por recálculo.

Solicitadas correções ao Sol na tarefa E03 existente e atualização do handoff.
Não liberar E03-C2 sobre este candidato ainda; sem atualização de código de
playtest/master. Ranks/kits completos e efeitos novos de equipamento continuam
fora deste pacote.
