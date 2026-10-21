# E07-F5 — ciclo de expedição

21/10/2026. EM_EXECUÇÃO; decisões consumidas aprovadas. Executor Sol/Alto,
chat `01a150a6-a9f0-7753-afa5-0081569879a9`.
Aval humano: “F4 terminou. Podemos começar F5.”

Base real `ee76b442c336c5818ee90b8e9d7478cdd739d593`, fechamento F4;
runtime F4 `cdda02f9cfcec52a6f27646711e4dadedce1a63b`.
F0/F1/F2/F3 são ancestrais da composição entregue e validada tecnicamente.
Não equivale a integração operacional no playtest ou aceite de produto.
Branch `codex/e07-f5`, checkout exclusivo
`C:/Users/João Pedro/.codex/worktrees/e07-f5/RagRPG`.
CLI de workflow/WORKFLOW_TOOLING ausentes; diagnóstico por Git/contratos,
conforme recibos F2–F4. Não usar instalação externa presumida.

## Decisões humanas desta liberação

D03 APROVADA: onda a cada 900 segundos ativos; normais/elites explicitamente
trash são elegíveis; bosses/raros/memoráveis únicos. Fatores por geração g:
EXP 0.70^g, gold 0.60^g, equipamento/carta 0.50^g. Inteiros para baixo, sem piso;
geração inicial intacta. EXP por abate substitui a EXP fixa de etapa em E07;
valores por origem explícitos na amostra. Resposta “Aprovar essa proposta”.
Não cria gold por mob nem altera ilvl/qualidade. Recompensa congelada antes do sorteio.

D04 regras gerais APROVADAS: retorno à chegada do último portal atravessado,
ou entrada inicial; 50% HP/25% SP; augments/cooldowns/bens conservados; efeitos
temporários removidos; ações emitidas canceladas sem reembolso. Penalidade120s
uma vez por morte; zero dispara uma onda; antes da primeira limpeza não há dívida.
Resposta “Aprovar essas regras gerais”. [Tabela por classe](f5_death_policy_proposal.md)
APROVADA em seguida: “Aprovar a tabela proposta”. Recargas e claims conservados.

D06 mínimo APROVADO: saída após5s sem vínculo hostil real de aggro/dano de jogador
ou companheiro; autoridade usada em ofertas/trocas/coleta/regen, com pausa/snapshot.
Resposta “Aprovar 5 segundos”. Não inclui ledger completo de ameaça de F6.

D02 já consumida: uma pendência/personagem com locks F2; ações locais de estágios
ausentes congelam, relógio global ativo continua; suspensão total congela tudo (F3).
Quest antecipada APROVADA: “Aprovar suspensão sem bônus”; marcar objetivo,
suspender a mesma expedição e permitir continuidade sem limpar mácula/augments.
D07 APROVADA: “Aprovar a amostra proposta”; quatro estágios ramificados, ramo
opcional com retorno, memorável temático e destino final, fase inicial aberta
nível1 sem custo/chave. Bônus de teste100gold/300EXP Base/200EXP Job, sem item.
Densidade e EXP por origem serão explícitas na amostra, sem catálogo extenso F5.
Contrato v1/guides, com deltas humanos acima, regem F5; propostas não são defaults.

Delta de troca ativa APROVADO: “Aprovar esse delta transacional”, conforme
[proposta concreta](f5_build_delta_proposal.md). Perfil, build e mundo na mesma
transação, fora de combate; sem cura/reset, com retry/reconciliação. Locks de
lobby/suspensão preservados. Adendo de propriedade inclui a proposta e teste
e07_f5_build_test.gd, nos serviços e fronteiras já atribuídos abaixo.

## Propriedade exclusiva antes da edição

Transferência sequencial de produtores entregues, sem escritores paralelos:
- scripts/main.gd; scripts/core/expedition/expedition_service.gd;
  scripts/core/run_reward_service.gd; scripts/core/run_state.gd;
  scripts/core/run_build_service.gd; scripts/core/profile_reward_resolver.gd;
  scripts/core/mob_occurrence.gd, mob_catalog.gd, mob_loot_resolver.gd;
  scripts/actors/player_actor.gd, enemy_actor.gd.
- Fronteira durável: scripts/core/profile_facade.gd, profile_store.gd,
  profile_codec.gd, profile_state.gd;
  scripts/core/expedition/ownership/expedition_asset_lock.gd,
  character_assets.gd; scripts/core/expedition/persistence/expedition_checkpoint_codec.gd.
  Somente lifecycle/recibos/conclusão atômicos pelo writer existente; nenhum
  fork de serialização ou descarte de compatibilidade/recibos.
- Snapshot: scripts/core/expedition/snapshot/runtime_manifest.json,
  snapshot_registry.gd. Registrar campos/kinds novos e validação explícita;
  preservar captura/restauração passiva F3. Não omitir estado de campanha/combate.
- tools/verify.ps1: transferência sequencial F4, registro/seleção F5.
- Novos scripts/core/expedition/population/*.gd,
  scripts/core/expedition/campaign/*.gd,
  scripts/core/expedition/combat/combat_participation.gd,
  scripts/world/expedition_portal.gd; respectivos .uid.
- Novos tests/e07_f5_*.gd/.uid, tests/fixtures/e07/f5/**;
  data/expedition/policies/** somente tabelas aprovadas.
- Este despacho, f5_api.md, f5_death_policy_proposal.md, delivery/f5.md e
  f5_checkpoint.md e seção F5 de docs/epics/e07.md. Contratos arquiteturais permanecem intactos.

Outros arquivos exigem adendo nominal antes da edição. Proprietário F5 não
modifica checkout dos produtores nem playtest. Correções permanecem neste chat.

## Resultado, validação e exclusões

API enter/travel/record_death/revive/finish, planner e relógio global,
primeiras entradas/claims, limpeza completa em dados, retornos e conclusão;
integração com geometria F1, snapshot F3, writer F4 e loot canônico.
Critérios I06–I09/I11–I14: ticket/grant único, boss não repõe, memo obrigatório,
slot vivo não duplica, estágio não limpo não repõe, pending único e chegada segura,
ondas com delta grande equivalentes, morte/revive/restart idempotentes,
quest sem bônus, entrada não repete augment e unload não cura/limpa estado.
Participação usa eventos reais, não cleared_once ou quantidade de Nodes.

Testes por impacto via tools/verify.ps1, Godot4.7.2 standard, fixtures isoladas;
novas regras com invariantes, falhas de commit/retry/reconciliação e continuidade.
Supervisão Luna delimitada após candidato; Sol corrige/consolida. Renderer/portal
requer inspeção visual pertinente. Não alegar FPS/escala/diversão por checks.
Sem catálogo extenso, economia/quests completas, ameaça completa F6 ou UI F7.
Sem save pessoal, push, master, avanço do playtest, arquivamento ou E08+.
