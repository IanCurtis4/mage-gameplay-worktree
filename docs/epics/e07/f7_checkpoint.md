# E07-F7 — execução

22/10/2026. EM_EXECUÇÃO. Base 9e457f222b0bc7dbbc67078ec7712eecee1bb353.
Checkout exclusivo: codex/e07-f7. Contrato e arquivos: [despacho](f7_dispatch.md).
Integração F1–F6: [recibo](f1_f6_integration.md).
Autorização humana reiterada pela coordenação; acesso externo por escalonamento.
Próximo passo: concluir testes de fluxo, regressão por impacto e inspeção nativa.
Sem migração pessoal, atualização do playtest, push ou merge.

Adendos humanos neste chat em22/10: autorizadas nominalmente duas consultas
faltantes no core: projeção characters/assets de MigrationPlan.dry_run em
scripts/core/expedition/ownership/migration_plan.gd e next_pending_ticket()
somente leitura em scripts/core/run_reward_service.gd. Propriedade desses dois
arquivos passa a F7 exclusivamente nesse delta, sem novo writer/schema/kind.
Reprodução boundary_01 provou a lacuna original, exit2; não é PASS. A correção
posterior tem teste próprio de destino explícito/digest/arquivo legado.

Delta implementado: migração assistida, seleção/retomada, amostra autorada
Travessia das Ruínas, portais/objetivos, ameaça, coleta, revive e suspensão.
Estado ainda EM_EXECUÇÃO; não é entrega aprovada. Evidência final pendente.
