# E07-F5 — API em implementação

21/10/2026. **Provisória; aguarda fechamento técnico**.
[Despacho e decisões humanas](f5_dispatch.md), [checkpoint](f5_checkpoint.md).
Consome APIs F0/F1/F3/F4, sem novo writer nem serializador paralelo.

## Campanha e população

ExpeditionPopulationPlanner.build(manifest, mob_catalog, rules) valida as
espécies/origens reais, políticas explícitas por slot e suporte/caminhos F0/F1.
Um slot trash só admite normal/elite. Boss/raros/memoráveis da amostra são únicos.
Não usar Node.get_instance_id na identidade de ocorrência: a tupla canônica
expedition/stage/slot/generation gera um ID técnico de comprimento limitado.

ExpeditionCampaignState conserva manifesto realizado/entradas/revisões, slots,
visited/cleared_once, claims, âncora, objetivos e um ExpeditionWaveClock.
Limpeza considera todo o manifesto, inclusive inimigos de estágio ausente.
Ondas só admitem trash morto de estágio limpo; um bloqueio mantém uma intenção.
Geração muda na admissão efetiva. Boss morto não volta, portal aberto não fecha.

O relógio mede900s ativos, não horário do sistema. Pausa e suspensão congelam;
viagem conserva remaining. Delta grande é equivalente à partição cronológica.
Revive deduplica death_event_id, reduz120s e produz no máximo uma onda por morte.
Sem dívida anterior à primeira limpeza. EXP usa floor(base * (7/10)^g) exato,
com um único arredondamento; chances de equipamento/carta usam0.5^g antes do
sorteio canônico, sem reduzir ilvl/qualidade nem alterar garantias iniciais.
Fator gold0.6^g é reservado; F5 não inventa gold por mob.

## Fronteira transacional

ExpeditionService(facade) conserva checkpoint/collect/resume/reconcile F4 e acrescenta:

- enter(controller, barrier, expedition_id, manifest, rules, request, revision):
  exige sessão real e mundo inicial vazio; não substitui encontro já em curso.
  O consumidor define expedition_entry_mode=true no RunController antes de
  adicioná-lo à árvore; o startup constrói jogador/serviços sem criar o piloto.
  O raio de travessia do manifesto precisa cobrir o corpo real do jogador;
  cada mob é validado com seu próprio raio, incluindo caminho desde a entrada.
- travel(controller, barrier, portal_id, stage_id, request, revision): valida
  aresta/origem/alcance/caminho/destino e flags reais; retorno após travessia
  preserva grafo/HP/SP/recargas, sem novo grant de entrada.
- record_death(controller, barrier, slot_id, generation, event_id, request,
  revision): exige fonte/ator morto e congela ticket, tombstone e limpeza juntos.
- revive(controller, barrier, death_event_id, request, revision): política D04
  aprovada, mesma build, última chegada atravessada ou entrada inicial.
- finish(controller, barrier, outcome, source, request, revision): completed
  exige saída final/objetivos/limpeza válidos e recompensas coletadas. Quest
  early_exit suspende a mesma expedição, sem bônus/limpeza de mácula.
- change_build(controller, barrier, intent): delta aprovado em
  [f5_build_delta_proposal.md](f5_build_delta_proposal.md). RunBuildService mantém
  preview/commit/reconcile, usando composição e inventário canônicos. Somente
  dono/sessão ativos e fora de combate. Perfil (layout e encaixes), déficits,
  cooldowns e checkpoint confirmam juntos. O consumidor mantém sua cena e publica
  a build após confirmação; falha incerta congela até a mesma reconciliação.
  Lobby/suspensão continuam bloqueados; o caminho legado recusa commit separado.

Uma cópia passiva completa recebe a transição e sua serialização é reconstruída
e validada antes da escrita. O ProfileStore confirma perfil,
checkpoint, recibo e consequências materiais no mesmo commit. Só então o serviço
entrega root/registry/snapshot para install/activate F3. A cena anterior não pode
voltar a simular após publicação. Falha incerta conserva a mesma instância de
serviço para reconcile(request), bloqueando novas intenções. Falha conhecida
conserva o corte durável anterior e permite retry da intenção congelada.

RunController adapta eventos reais de morte em uma fila de fim de tick. Grafo
local de estágio ausente permanece desativado no mesmo snapshot, sem reconstrução
por seed ou reset. Build, jogador e RunRewardService são únicos na expedição.
Consultas view/portal_view retornam cópias para o consumidor F7; UI não decide
limpeza, recompensas, recargas ou elegibilidade.

CombatParticipation registra vínculos reais de aggro/dano e5s de saída; main usa
essa autoridade em encounter_active para consumidores existentes de ofertas,
trocas, coleta e regen. Estado/atraso entram no manifesto explícito de snapshot.
Não é ThreatService nem contém as fórmulas opcionais F6.

Limites F3/F4 de4MiB e compatibilidade exata de fontes/engine continuam. Medição,
falhas finais, inspeção nativa e restrições concretas serão consolidadas no recibo.
Não há UI de lobby/migração/campanha F7, promessa de FPS, export release ou aceite
de gameplay nesta API em construção.
