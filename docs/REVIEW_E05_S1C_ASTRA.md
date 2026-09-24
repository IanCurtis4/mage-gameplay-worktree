# Gate Astra — E05-S1C (rodada 1)

Candidato 8d1b848: revisão pendente de correção localizada de UI.
verify.ps1 independente passou integralmente (68 suítes/3095 checks,
importação e smoke). Core e catálogo não foram modificados.

P2: _cancel_evolution_change e mudança de alt limpam apenas _evolution_pending,
mas mantêm _evolution_retries. Reprodução: falhar save de uma escolha; cancelar;
fazer outra operação válida que incremente a revisão; selecionar novamente o
mesmo destino. _confirm_evolution_change ignora a revisão recém-capturada e usa
a revisão antiga do retry cancelado, causando stale_revision indevido.

Correção autorizada no escopo: retry pertence à intenção de confirmação ativa.
Descartar seu cache ao cancelar, mudar de alt ou substituir a intenção por outra;
manter request_id/revision somente no retry da mesma intenção após save_failed.
Uma nova confirmação explícita deve capturar seu próprio contexto. Testar falha,
cancelamento, avanço de revisão e nova escolha; também troca de alt/retorno e
preservação do retry imediato. Não modificar core nem habilitar kits.

Após correção, teste dirigido e regressão do menu bastam para este delta; repetir
suíte integral somente se surgirem outros riscos. Atualizar handoff e parar
para gate. Nenhuma atualização de playtest/master nesta rodada.
