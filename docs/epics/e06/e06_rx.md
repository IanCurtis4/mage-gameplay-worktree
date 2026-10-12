# E06 — revisão independente RX da fundação ampliada

12/10/2026. **RX REJECTED nesta rodada: RX-F01/P1 e RX-F02/P2 abertos.** Autor deve corrigir e devolver o delta à mesma revisão. Integral ainda não iniciada; R1 histórica permanece fechada/intacta.

## Candidato e responsabilidade

Revisor independente único Astra/high, mesma tarefa retomada de R1, sem autoria de runtime. Escopo TX1–TX3 conforme itemization_execution.md/e06_tx_api.md e decisões humanas. HEAD `380eb06098ad794977b80f4748d88c1238a14ec1`; árvore Git SHA-1 `57f55c6ef5fda178be18676cb849f9f6cb923e52`; código `94ae228fee41fc1b71a568d75c86255c25aa5e49`; base do delta `54e6fad47763310afb307d990759c874c33fd1d3`. Branch `codex/e06-inventory`, checkout `C:/Users/João Pedro/.codex/worktrees/e06-inventory/RagRPG`.

Inspeção do delta crítico e consumidores: identidade/exemplares, codec e migração, regras de 14 posições/encaixes, composição/capacidades/conjuntos/grants, uso de arma, planos causais/HealthState, mob/base/ocorrência/IA e resolver/tickets de loot. Recibos TX1/2/3 foram consultados como evidência recebida do autor; não representam execução independente nesta rodada.

## RX-F01 — P1: reforço perde o sangramento de armadilha já plantada

Local principal: `scripts/core/effect_proc_ledger.gd:95`. O produtor em `scripts/actors/player_actor.gd:2980` congela somente IDs de atores vivos presentes no lançamento; `CombatEventContext.scheduled_tick` herda esse plano sem admitir a vítima posterior. Entretanto, `HunterTrap.track_target` e `_spawn_enemy` continuam admitindo reforços que nasceram depois de plantar a armadilha.

Reprodução própria `tests/e06_rx_causal_late_test.gd`: plantar Espinhos pela ação paga, depois criar reforço pela API real de spawn e colocá-lo junto de uma vítima antiga. Ambos recebem o dano primário e um stream de bleed. Avançar o mesmo tick canônico: **vítima antiga perde 9 HP; reforço perde 0 HP**. Resultado: **5 checks, 1 falha**, exit 1. O erro não é falta de alvo, recurso, skill, stream ou dano primário; o claim do tick rejeita a vítima ausente do plano antigo.

Impacto: regressão de comportamento E05 preservado pelo contrato. Alvos rastreados validamente por mecanismos persistentes não podem perder componentes de dano por terem surgido após a emissão. O teste autoral que rejeita alvo tardio abstrato no ledger não prova o consumidor real e não autoriza essa perda. Correção deve conservar snapshot, plano finito, dedupe antes de callbacks, anti-cascata e limites dos kits; auditar consumidores adjacentes de campos/ticks/reforços. Não alterar a expectativa do probe para aceitar dano suprimido.

## RX-F02 — P2: IA para fora do alcance da skill declarada

Local principal: `scripts/actors/enemy_actor.gd:139`, em conjunto com a validação de alcance em `:299`. Movimento do arquétipo archer continua usando a faixa fixa 150..390; a skill aceita usa seu alcance canônico próprio.

Reprodução própria `tests/e06_rx_mob_ai_test.gd`: espécie legal archer com fire_spear rank 1, alcance 360; alvo a 375. **300 passos normais de `_process` a 60 Hz: movimento 0 e emissões 0**, sem obstáculo/CC ou falta de SP. Ao colocar o mesmo ator dentro do alcance da magia, `_process` emite normalmente. Resultado: **4 checks, 1 falha**, exit 1.

Impacto: há uma faixa válida de combate em que o novo mob para e nunca ataca nem se aproxima. As provas autorais chamam diretamente a preparação da magia e não cobrem a decisão de movimento. A correção deve alinhar movimento/parada/ação à skill realmente utilizável, preservando targeting, custo, cast e cooldown.

## Evidência independente e limites

Godot `4.7.2.stable.official.ed1daf0bf`; SHA-256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`. Probes executados diretamente por `--headless --path . --script res://tests/e06_rx_*.gd`, sem writer de save pessoal. Logs em `.godot/verification/e06_rx/causal_late.{engine,output}.log` e `mob_ai.{engine,output}.log`; cada execução e hash está no [recibo](e06_rx_reviewer_validation.json), junto do manifesto completo dos inputs não documentais e hashes dos recibos recebidos.

Não houve edição de runtime, runner, Resources, testes autorais nem expectativas dos probes R1. Não houve importação nesta rodada nem alteração incidental em `.import`. Os únicos novos inputs executáveis são os dois probes próprios. Conferência final: nenhum diff rastreado em scripts/resources/scenes/assets/tools/project.godot.

CLI externo autorizado menu-tabs, origem `0c008d4843d13f772aa2b69be22d24d2300b80a1`/SHA-256 `e642dbe882cd7ea3cd687da51ed978bdecc93675fbb31d08d26626a0b40a1bae`, produziu pacote `review` com base 54e6fad em `.godot/verification/e06_rx/review_package.json`. Pacote é diagnóstico. `validate/approve` antigos continuam incompatíveis com Add-GodotCheck; instalação não alterada e nenhum approve fabricado. Decisão independente manual é REJECTED.

A integral contratada de 190 etapas fica para o fechamento, após remover bloqueios conhecidos; não iniciada nesta rodada. As demais fronteiras inspecionadas ainda dependem desse fechamento e da reprodução proporcional ao delta corretivo; ausência de outro achado aqui não é aprovação parcial/implícita. Sem nova inspeção visual, FPS/balanceamento, playtest, produto, commit, push ou merge.

## Retomada

Sol recebe os achados para correção em runtime/runner/testes autorais conforme propriedade registrada no checkpoint. O congelamento pode ser suspenso somente para esse pacote corretivo. Probes `tests/e06_rx_*`, este relatório e recibo permanecem do revisor; autor pode executá-los, preservando suas expectativas. Após entrega do hash/delta/provas autorais, retomar a mesma RX, conferir os dois consumidores e fronteiras adjacentes antes de uma única integral. Preservar logs ignorados antes de remover a worktree.
