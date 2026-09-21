# Aceite integrado E03 — 21/09/2026

**Aprovado tecnicamente para playtest**, sem aprovação de produto ou merge em master.
Entrega original `e13bd03`; composição rebaseada `3a1d3cc` sobre playtest
`7fd67d5`. Rebase sem conflitos; diferença para o original somente nos pareceres
documentais preservados. Referência anterior: tag `archive/e03-before-playtest-2026-09-21`.

O pacote cabe no escopo operacional: XP dos dois cristais do piloto, confirmação
durável antes da coleta, retry sem duplicação, investimentos no menu, snapshots
isolados e nova run com os valores investidos. Não introduz tabelas finais E07.

Verificação independente, antes e depois do rebase: Godot 4.7.2, `tools/verify.ps1`
com importação, 992 checks e smoke aprovados. Contrato E00: 4.630 checks aprovados.
Capturas do implementador inspecionadas em 1280×720 e viewport menor: texto legível,
lista de personagens visível e botão iniciar fora da rolagem. Não foi feita
avaliação humana de sensação/balanceamento.

Limites do aceite: ranks persistem, mas não há tabela completa de efeitos por rank
(E04); evoluções ficam em E05; XP é integração provisória por cristal. Não afirmar
que esse candidato entrega todas as habilidades/classes ou a progressão final.

## Playtest

No projeto habitual, F5. Em personagem novo, concluir os dois encontros e coletar
os cristais resulta em 250 XP base, 180 XP job, níveis 3/3, seis pontos de atributo
e dois de skill. Retornar ao menu, investir, iniciar outra run e reabrir o jogo
para conferir persistência. Repetir com outro alt para conferir isolamento.
Perfis com XP anterior somam as recompensas, respeitando os caps.

Roteiro detalhado e limites: `E03_I_INTEGRATION.md`. Usuário dá o aceite do
candidato testado antes de qualquer merge em master. E04 não está liberado.
