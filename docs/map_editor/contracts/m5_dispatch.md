# Editor F5 / M5 — contrato executável 1

25/10/2026. VALIDADA TECNICAMENTE; aceite humano pendente.
[Código470904e, evidências e limpeza concluídos](../delivery/m5.md).
Autorização humana: “F4 terminou, podemos começar F5.”
D5 confirmada explicitamente neste chat: loop/ida e volta, espera, interrupção
por aggro, retorno a waypoint validado e home de leash fixo.
Base F4 `b5ad440b100be7d50da8fc5b84218d0c54a886d2`, código validado
`7a391431fad54e396194ec0c3ce8e6491fbe178e`, F0–F4 por ancestralidade.
Branch `codex/map-editor-m5`; checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
Integração neste consumidor por ancestralidade; sem aceite/merge master inferido.
Sol implementa/valida; Luna supervisiona seleção congelada, sem auditoria semântica.

## Resultado e semântica

Documento de patrulhas separado, versionado/estrito, com snapshot imutável do
documento de encontros M4, rotas identificadas, slots, waypoints por superfície,
loop/ping_pong e espera de 0–300 s. Máximo16 rotas,32 pontos por rota,128 slots.
Cada slot recebe no máximo uma rota, com2–32 pontos. Home é o spawn M4.
Todos os segmentos, home→início e fechamento/volta precisam caber no corpo e
no leash fixo canônicos; inclusive os pontos da rota calculada. Sem travessia
entre estágios, alteração de aggro/recompensas ou Resources de catálogo.

Aggro suspende a patrulha e a espera. O retorno de combate existente vai ao home;
depois o alvo pendente é retomado por path canônico, preservando espera restante.
Chegar a um ponto inicia sua espera; finda, escolhe próximo ponto sem salto.
Bloqueio/revisão invalida o caminho; no máximo uma busca por segundo por ator,
com diagnóstico e espera sem mover se impossível. Tentativas de um tick são
limitadas; não compensa ticks grandes percorrendo vários pontos.
Root/stun congelam deslocamento e espera; medo usa comportamento canônico e
depois recalcula. Pausa/suspensão/estágio inativo não avançam patrulha.
Respawn é nova geração canônica no home, rota reinicia no ponto0/direção+1;
vivos não são recriados. Mortos não percorrem nem concluem espera.

Persistência usa exclusivamente o grafo SnapshotRegistry/CheckpointCodec vigente:
definição, cursor, direção, espera, bloqueio e interrupção são campos explícitos.
Compatibilidade estrita de fontes/build permanece; snapshots de build anterior
falham explicitamente, sem migrar/destruir save. Nenhum novo writer/schema de perfil.
Documento M4 e pacote `.rpe` continuam compatíveis; F5 publica `.rpp` próprio.
O adaptador F5 acrescenta phase_id técnico `editor_patrol_preview` ao manifesto
de teste, exigido pelo serviço canônico. Não registra uma fase de campanha nem
altera o snapshot/pacote do produtor M4.
GUI/headless chamam mesmo compilador; teste local usa atores reais e perfil
descartável. Sem reivindicar navegação final M3-NAV-01 ou corrigir bugs E07.

## Manifesto nominal exclusivo

Sol F5 possui os novos arquivos abaixo; cada `.gd` inclui seu `.gd.uid`:

- scripts/map_authoring/patrol/patrol_document.gd
- scripts/map_authoring/patrol/patrol_compiler.gd
- scripts/map_authoring/patrol/patrol_session.gd
- scripts/map_authoring/patrol/patrol_store.gd
- scripts/map_authoring/patrol/patrol_panel.gd
- scripts/map_authoring/patrol/patrol_canvas.gd
- scripts/map_authoring/patrol/patrol_preview.gd
- scripts/map_authoring/patrol/worker_headless.gd
- scripts/map_authoring/patrol/headless.gd
- scripts/core/expedition/patrol/enemy_patrol.gd
- tests/map_editor_patrol_test.gd
- tests/map_editor_patrol_restart_test.gd
- tests/map_editor_patrol_ui_test.gd
- tools/map_editor_patrol/run.ps1
- docs/map_editor/contracts/m5_dispatch.md
- docs/map_editor/delivery/m5.md
- docs/map_editor/README.md (estado/D5/link)
- docs/map_editor/execution.md e STORAGE.md (decisão humana de armazenamento)
- docs/map_editor/delivery/evidence/m5/author/ e official/
- docs/map_editor/delivery/evidence/m5/cleanup_* (limpeza explicitamente pedida)

Transferências sequenciais autorizadas explicitamente pelo humano25/10, após
conferência dos chats F4 e catálogo sem execução ativa:

- scripts/actors/enemy_actor.gd (+.uid): binding/tick/interrupção de patrulha.
- scripts/core/expedition/campaign/expedition_campaign_runtime.gd (+.uid): spawn.
- scripts/core/expedition/snapshot/runtime_manifest.json: campo patrol do ator.
- scripts/core/expedition/snapshot/snapshot_registry.gd (+.uid): validade de patrol.

A transferência dos dois arquivos de snapshot substitui a reserva anterior do
catálogo imutável apenas nesta fronteira de patrulha; nenhuma correção de lag
é tomada. Base F4 é o consumidor autorizado, sem cherry-pick de E07 em paralelo.
Transferência sequencial F4→F5 de
scripts/map_authoring/population/population_panel.gd (+.uid): somente abertura
da janela Patrulhas com snapshot dos encontros; F4 encerrou escrita/entrega.
Demais produtores/renderer/geometria, project.godot, verify.ps1, catálogo e codec
são só leitura. Luna possui exclusivamente evidence/m5/luna.md e luna_run/.
Não há outros escritores/subagentes de implementação.

## Provas

Schema/IO/undo/recovery e recusa sem mutação; slots inexistentes/duplicados,
NaN/versão futura, leash/corpo/parede/superfície/rampa e loop de fechamento;
loop/ping_pong/espera; aggro durante deslocamento/espera/rampa, retorno bloqueado,
root/stun/pausa/morte/respawn sem duplicação; captura e restart em processo novo
durante espera/bloqueio/combate, incluindo comparação ao tick sem interrupção.
Revisão incompatível falha sem sobrescrita. GUI/headless/hash e inspeção nativa.
Runner próprio F5 e verify.ps1 -List/seleção por impacto F3–F6; logs/hashes,
supervisão Luna, fechamento Sol, limites e roteiro humano no recibo.
Sem início F6+, push, save pessoal, publicação externa ou playtest por inferência.
