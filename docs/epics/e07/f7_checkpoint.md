# E07-F7 — checkpoint consolidado

23/10/2026. ENTREGUE/VALIDADA tecnicamente; não integrada.
Base 9e457f222b0bc7dbbc67078ec7712eecee1bb353.
Checkout exclusivo: codex/e07-f7. Contrato e arquivos: [despacho](f7_dispatch.md).
Integração F1–F6: [recibo](f1_f6_integration.md).
Autorização humana reiterada pela coordenação; acesso externo por escalonamento.
Runtime final: 6a7a31b1303eaa57e6868e4453fc682aee59cea7, após implementação
483be3a5258cc3142ace8e92c5a4cbd081d827d3. [Recibo e roteiro](delivery/f7.md).
Próximo passo permitido: integração operacional designada, com revalidação por
impacto do resultado integrado. F8 exige aval próprio; este chat não é arquivável
antes da integração bem-sucedida. Não há gate Astra rotineiro.
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
20 IDs únicos/565 checks aprovados:8/177 em final_02,12/388 reaproveitados de
final_01 por impacto. Luna confirmou conclusão/erros/timeouts/hashes e1671 fontes
iguais ao runtime final; executor consolidou contrato e inspeção nativa das seeds
42/43 e migração. Não é auditoria semântica independente ou aceite de gameplay.
Evidência durável, hashes e limitações no recibo; não repetir gameplay por edição
documental. Save pessoal e checkout habitual preservados.
