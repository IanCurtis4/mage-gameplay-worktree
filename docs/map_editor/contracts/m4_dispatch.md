# Editor F4 / M4 — contrato executável 1

24/10/2026. EM_EXECUÇÃO. Autorização humana: “F3 foi concluída. Podemos começar F4.”
Base `4c2adf80470d86989742daf426be965f606c5539`, F0–F3 por ancestralidade,
incluindo aceite F3 e pendência temporária M3-NAV-01. Branch `codex/map-editor-m4`,
checkout `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m4`.
Não depende de integração em master/playtest; o checkout deste consumidor integra
os produtores aceitos por ancestralidade. Sol implementa e valida; Luna supervisiona.

## Resultado e fronteira

Documento de encontros separado, com snapshot da composição M3, entrada,
pincéis circulares ancorados numa superfície e abrangendo a mesma camada autorada
da instância, exclusões circulares e slots realizados. Superfícies especiais
mantêm família própria; não pintar acidentalmente no piso sobreposto.
Catálogo canônico carregado sem mutação. Quantidade ou densidade por 10000 unidades²,
peso inteiro por espécie, disperso/concentrado, espaçamento, seed signed64 textual
e rodada explícita. Uma operação oferece diff antes de substituir slots regeneráveis;
slots fixados conservam identidade/home e contam para a quota do brush.
Sem espaço: diagnóstico com solicitado/realizado/déficit, sem pacote parcial.

Densidade utiliza quadratura determinística de células16×16, centros com suporte,
corpo e rota canônicos, descontando exclusões/entrada/aberturas/interações. Área
é estimativa por amostragem, não área contínua exata; quantidade=floor(área*d/10000).
Máximo16 brushes,128 slots totais,64 exclusões/interações, raio512,4096 amostras
por brush. Perfil real inicial radius20/height32 da fase existente; mob usa máximo
entre20 e seu raio canônico. Altura é resolvida no plano da superfície selecionada.
Um ponto que cruza uma célula vizinha da mesma camada resolve a altura naquela
célula. Distâncias editoriais de pincel/grupo/exclusão são horizontais x/z.
Regiões da peça marcadas em protected_regions e com purpose path, route ou
population_exclusion reservam seu polígono com folga do corpo. Proteção de altura
com outro purpose não ganha implicitamente uma proibição de população.
Posição e rota de ida/volta para entrada, separação por raios e espaçamento,
catálogo/categoria/origem e palco explícito para memoráveis são obrigatórios.

Interações: entrada; pares de portais locais no mesmo estágio e saídas
phase_completion/early_exit, parametrizando o manifesto/serviços existentes.
No máximo uma saída phase_completion por mapa: o serviço vigente exige os outros
objetivos obrigatórios antes de concluir; duas saídas terminais required não
podem satisfazer uma à outra. Não inventar semântica de objetivos alternativos.
Sem novo efeito de refúgio, quest, trigger, patrulha, economia ou writer.
Palco de memorável é marcador de autoria, não comportamento novo.
Políticas de slot: referência explícita à fase ruined_crossing (origem trial_stage_N,
EXP10N/8N, trash somente normal) e ciclo e07_initial; não cria balanceamento novo.
Teste descartável usa CampaignState/PopulationPlanner e movimento canônicos;
conferência de morte/limpeza/onda é simulação técnica identificada, sem conceder
bens nem abrir ProfileStore. Integração com atores/serviço é provada por fixture.

## Manifesto nominal / transferência sequencial

Sol F4 possui exclusivamente (cada .gd inclui .gd.uid):

- scripts/map_authoring/population/population_document.gd
- scripts/map_authoring/population/population_compiler.gd
- scripts/map_authoring/population/population_catalog.gd
- scripts/map_authoring/population/population_session.gd
- scripts/map_authoring/population/population_store.gd
- scripts/map_authoring/population/population_panel.gd
- scripts/map_authoring/population/population_canvas.gd
- scripts/map_authoring/population/headless.gd
- scripts/map_authoring/population/population_worker.gd
- scripts/map_authoring/population/worker_headless.gd
- tests/map_editor_population_test.gd
- tests/map_editor_population_ui_test.gd
- tools/map_editor_population/run.ps1
- docs/map_editor/contracts/m4_dispatch.md
- docs/map_editor/delivery/m4.md
- docs/map_editor/README.md (estado/link)
- docs/map_editor/delivery/evidence/m4/author/ e official/

Transferência F3→F4 de scripts/map_authoring/composition/map_panel.gd:
somente abrir a janela de encontros com snapshot; F3 encerrado/aceito.
Nenhuma escrita em compilador/documento/canvas M3, shell/terreno F2, runtime,
catálogo, project.godot ou verify.ps1. Luna possui somente evidence/m4/luna.md
e luna_run/. Testes novos usam runner próprio; verify.ps1 roda seleção existente.
Os dois assets/art/map_authoring/{earth_tile,grass_tile}.png.import foram apenas
normalizados de CRLF para os bytes LF do blob Git, como no produtor M3; nenhum
parâmetro/material mudou e não compõem delta de conteúdo entregue.

A inspeção nativa confirmou Resources de gameplay não-tool como placeholders no
editor. GUI usa processo Godot headless local, com protocolo de dados passivos,
job exclusivo em .godot, cancelamento/timeout e rejeição de erro/incompletude.
O mesmo compilador/catálogo roda nesse processo; nenhum Resource runtime foi
marcado @tool nem sua regra foi copiada para a GUI. O estado técnico de ciclo é
criado pela autoridade no worker e hidratado como DTO para os métodos puros.

## Provas

Roundtrip/histórico/recuperação; disperso/concentrado e seeds0/negativo/extremos;
catálogo/ordenação estáveis, pesos, densidade, pins e diff; quota impossível,
exclusão, entrada, corpo grande, rota estreita, palco inacessível, origem/categoria
inválida; integração Planner/CampaignState/atores, limpeza/respawn/retorno/grants;
publicação imutável/reabertura/rejeição/cancelamento/obsolescência; GUI/headless
equivalentes e captura nativa. Seleção oficial após -List, supervisão congelada
Luna e fechamento Sol. Aceite humano separado; sem push/merge/playtest automático.
