# E07-F5 — checkpoint de implementação

21/10/2026. **EM_EXECUÇÃO**, não é entrega nem aprovação técnica.
[Liberação, base, decisões aprovadas e donos](f5_dispatch.md).

Base `ee76b442c336c5818ee90b8e9d7478cdd739d593`, branch `codex/e07-f5`,
checkout `C:/Users/João Pedro/.codex/worktrees/e07-f5/RagRPG`.
Alterações ainda não consolidadas em commit. CLI de workflow ausente; retomada
por Git/contrato, sem instalação alternativa. project.godot confirmado.

D03, D04 geral e tabela das dez identidades, D06 mínimo, quest antecipada D02 e
amostra D07 receberam resposta humana explícita neste chat. Não perguntar de novo.
Delta transacional da troca ativa também aprovado: “Aprovar esse delta
transacional”; implementação em RunBuildService/ExpeditionService com um writer,
sem liberar edição no lobby. Proposta e despacho registram o adendo.
Não inclui F6 completo, UI F7, catálogo extenso, economia, save pessoal ou E08+.

Implementação parcial: planner sobre F0/F1, população por slot/generation,
relógio global, claims de entrada, participação mínima, transações passivas pelo
writer F4, viagens com grafos locais congelados, morte/revive e término.
EXP por abate com redução inteira exata; probabilidades passam pelo loot canônico.

Evidência autoral até este corte, não supervisão Luna nem fechamento Sol:
- import_04:1608 primários idênticos na cópia; population28/campaign26 PASS.
- import_05:1613 primários idênticos; author_03 já concluiu population32,
  recovery27 e fault19 PASS; conclusão/quest ainda em execução neste registro.
- population_01 falhou na rampa artificial escalada; corrigida somente a fixture
  para uma inclinação exatamente representável. Logs preservados.
- author_03: término falhou por acesso a gold no DTO legado que não contém esse
  campo; correção compara gold separado. Ainda aguarda repetição final.
- import_08:1618 primários idênticos. author_04 population38/1 falha:
  teste alterava cópia defensiva de espécie, não catálogo copiado; preparação
  corrigida sem remover a exigência de alcance para o corpo real.
- author_05: erro em death_kits chamando serviço Geômetro inexistente nas outras
  identidades; Luna reportou, Sol interrompeu processo (exit-1, não timeout).
  Preparação restringida à identidade pertinente. Reward/build não executados.
- import_09:1618 primários idênticos; author_06 em execução. Luna acompanha logs,
  sem editar fontes/oráculos; supervisão não é auditoria semântica independente.

Godot4.7.2 standard registrado por F4:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe`.
Logs em `.godot/verification/e07_f5/`; perfis exclusivamente sob fixture_project.
Nenhuma suíte completa repetida; ainda há código/testes novos sem evidência final.

Próximos passos autorizados: concluir testes de término/quest, validar morte das
dez identidades e chances de loot, endurecer validação/continuidade de snapshot,
inspecionar apresentação nativa pertinente e executar regressões por impacto.
Só depois consolidar candidato/evidências. Integração operacional/playtest/master
permanecem separados e inalterados. Não arquivar esta tarefa enquanto pendente.
