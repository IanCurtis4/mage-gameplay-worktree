# F10 Q5 — revisão integrada do editor e da fase

4/11/2026. Autorização humana: “Vamos para Q5 então”. Mesmo checkout
`.tools/map-editor-m5`, branch `codex/map-editor-f10`, base
`34bf16511019e88bf34ddfabfab624e533d7c20d`. Não abre outro épico.

## Resultado

Fechar as lacunas contratadas e revisar os 11 itens de `f10_final_review.md`,
confrontando a matriz F9 e os recibos F0–F8 com operações existentes. Evidência
recebida de F9, reprodução F10, supervisão Luna e aceite humano são separados.
Aceite humano permanece pendente até a decisão da pessoa sobre o candidato.

## Continuação sobre o checkpoint15

Autorização humana: “Vamos continuar Q5.” Base documental
`d49dc1603ca6ab0e380054c45b0adcaecb3a10ab`, código `8bbfb6c3`.
Mesmo worktree/fixture; quatro backups locais preservados. O CLI de retomada
continua ausente; diagnóstico por Git/checkpoint, sem inventar tooling.

Fatia UI Terra: propriedade exclusiva de
`scripts/ui/expedition/{expedition_presentation,expedition_status_panel}.gd`,
`scripts/world/{expedition_portal,expedition_geometry_view}.gd` (somente rótulos),
`addons/ragrpg_map_editor/shell.gd`,
`scripts/map_authoring/terrain/terrain_panel.gd`,
`scripts/map_authoring/workflow/workflow_bar.gd`,
`tests/e07_f7_presentation_test.gd` e `tests/map_editor_q5_usability_test.gd`
(novo). Nomes visíveis vêm da referência publicada já fixada na fase; IDs,
manifesto, elegibilidade e estado não mudam. Reduzir controles antes da prévia
sem perder descoberta, foco, roteiro ou ações AX. Medir área realmente visível
e provar que dobrar controles/alternar modo não altera a fonte. Sol integra UIDs
e runners. Sem engine enquanto houver escritores de fonte.

Sol: propriedade de `scripts/map_authoring/preview/gameplay_candidate.gd`,
`scripts/map_authoring/release/{map_release,phase_release}.gd`,
`tests/map_editor_forest_phase_test.gd`, testes dirigidos de preparação existentes
e runners. O perfil usa a etapa ForestPhase já existente. Primeiro medir os blocos da preparação sobre
os mesmos pacotes/perfis; depois reduzir trabalho repetido sem retirar prova
de ida/volta, alterar a primeira falha relatada ou reutilizar mundo vivo.
Métricas são locais da operação, fora de manifesto/snapshot. Não muda transação,
writer, barreira, conteúdo da floresta ou política de compatibilidade.
O perfil inicial localizou a maior parcela na leitura/validação fria dos
pacotes (147 s dos 179 s). Sol recebe também
`scripts/map_authoring/patrol/patrol_compiler.gd` para detalhar validação interna
versus admissão de população, com log diagnóstico opt-in, sem cache de estado vivo.
Sonda dirigida em `tools/map_editor_completion/profile_package.gd` e respectivo
UID/etapa PackageProfile; usa o mesmo primeiro mapa publicado, sem gerar conteúdo.

O detalhamento mediu 114 s na admissão fria: construção de grafo 22 s e
fechamentos completos de ida/volta 90 s para 62 destinos. Sol recebeu
`scripts/core/expedition/spatial/world_connectivity_batch.gd` e
`tests/map_editor_height_grid_navigation_test.gd`. A tentativa de limitar a
busca aos destinos passou nas invariantes, mas não reduziu o custo real
(118,77 s → 121,27 s no carregamento); foi descartada, restaurando o algoritmo
da base. As novas provas de consulta curta seguida de destinos novos, corte,
sentido único, cancelamento e invalidação permanecem.

Sol assume `scripts/core/expedition/spatial/world_height_grid.gd` e
`tests/map_editor_height_grid_test.gd` para eliminar projeções XZ repetidas:
coordenadas idênticas às dos Vector3 standard, sem carregar alturas inúteis,
e projeções dos triângulos íngremes preparadas no índice antes de compartilhá-lo.
São dados geométricos imutáveis; não retêm ator, mundo vivo ou resultado de
travessia. Comparar as duas diagonais em várias escalas/origens e os vereditos
de disco/cápsula com e sem índice, mantendo todos os orçamentos e testemunhos.
Essa segunda tentativa passou 17/17 provas geométricas e 16/16 de navegação,
mas mediu 127,55 s no mesmo carregamento, sem ganho confirmado. Também foi
descartada, incluindo o teste específico de projeções. Os dois arquivos do
núcleo voltaram exatamente à base; a continuidade desta entrega consolida as
correções visuais, a instrumentação e a evidência, sem anunciar redução de tempo.

Luna assume engine/fixture somente após transferência e congelamento explícitos.
Após o perfil inicial, a implementação volta a Sol e é congelada novamente antes
da validação. Sol mantém documentação fora dos inputs durante o lote.

## Propriedade sequencial

- Terra: `scripts/map_authoring/terrain/{brush,terrain_canvas,terrain_panel}.gd`
  e `tests/map_editor_manual_brush_test.gd` (novo). Pode propor um helper no
  mesmo diretório, registrando o caminho antes de usá-lo. Não toca runners,
  autoridades de persistência, outros testes ou documentação compartilhada.
  Entrega código/testes e instruções a Sol; não executa engine enquanto Sol
  usa a única fixture para inspeção GUI da base. Sol integra e transfere a
  propriedade de volta antes do lote congelado. UID novo fica com Sol.
- Sol: matriz/relatório/guias Q5, persistência/diário/drops se necessário,
  testes próprios dessas fronteiras, runners e release. Controla a inspeção
  GUI na fixture da base até a integração da fatia Terra. Não edita os arquivos
  Terra durante a transferência. Mantém fonte e fixture identificadas.
- Luna: supervisão dos lotes congelados, somente evidência; não muda fontes ou
  expectativas. Uma fixture compartilhada, usada sequencialmente.

Transferências delimitadas adicionais: Luna é autor exclusivo de
`tests/map_editor_journal_capacity_test.gd` até entregar a Sol, sem engine
durante escrita. Terra também entrega `tests/map_editor_manual_brush_native_test.gd`.
Sol recebe `scripts/map_authoring/release/{map_release,phase_release}.gd`,
`scripts/world/map_package_view.gd`, `scripts/core/expedition/snapshot/snapshot_registry.gd`,
`data/map_authoring/candidate_preview.gd`, `tools/map_editor_release/phase_release_probe.gd`,
`tests/map_editor_phase_presentation_test.gd`, `tests/map_editor_forest_play_test.gd`
e runners M8/completude para fechar a apresentação na fase e no release.

Transferência em 4/11: Terra entregou os três arquivos de pincel e os testes
`map_editor_manual_brush{,_native}_test.gd` e `map_editor_terrain_ui_test.gd`
a Sol e encerrou escrita. Luna deixou a versão do teste de capacidade com a
fixture persistida/instalada; a rodada terminou por limite de uso antes da
conferência final. Sol assume esse teste, `scripts/main.gd` e `tools/verify.ps1`
para reproduzir/corrigir a compactação. Toda engine é sequencial, com inputs
congelados. Após renovar sua disponibilidade, Luna conferiu os recibos do
primeiro lote e recebeu a engine exclusiva para Core, nativos e release.
Sol mantém apenas os documentos fora dos inputs durante esse lote final.
Inclui a fonte documental `skills/ragrpg-mapdelivery/SKILL.md` e
`docs/DELIVERY_SKILLS.md`: correção da precedência de limpeza/objetivo nas
repetições e referência ao consumo visual Q5. Nenhuma cópia instalada é escrita.

Os chunks visuais de até 16×16 células são só a prévia manual do editor;
preservam todas as amostras/diagonais e permitem atualizar o halo de normais
localmente. Não mudam o particionamento publicado ou a colisão.
O pick temporal usa as alturas da prévia já esculpida; o domínio do raio é
expandido só pelas amostras tocadas e restaurado ao cancelar. O novo oráculo
nativo distingue o relevo vivo da fonte original, que continua intacta.

## Apresentação da fase (lacuna encontrada na revisão)

`SnapshotRegistry.install` construía a vista técnica, mesmo para os mapas
autorados da floresta. A prévia de mapas usa `AuthoredExpeditionView`, mas o
fluxo do lobby não a selecionava. A composição deve levar por estágio apenas
a referência passiva da publicação (os oito campos do registro, com hashes),
sem duplicar o pacote visual no snapshot. A instalação resolve essa referência
imutável sem depender da revisão atual da lista e usa a vista compartilhada.
Referência inválida, ausente ou adulterada é recusada, preservando o save.

O renderer continua validando o pacote original e comparando superfícies,
volumes e massas com o mundo. Para o mesmo mapa renomeado pela composição,
somente os campos de referência ao nome do próprio estágio são religados na
cópia usada para comparação; nenhuma coordenada, corpo, material ou colisão
é alterada. O pacote e seu hash ficam intactos. Entrada, viagem e retomada
devem provar a apresentação autorada e produzir captura; o release inclui
os registros JSON de fases e usa o fluxo de jogo com perfil descartável.

## Pincel manual

Aplicação progressiva sob o ponteiro em ticks limitados, inclusive parado;
entrada de mouse só registra intenção. Usar a matemática canônica de Brush,
sem replicá-la na UI. Não reprocessar todo o caminho nem serializar a fonte
inteira por evento. A sessão só recebe uma transação no release, com um undo;
Escape, saída da área ou perda de foco descartam o traço. Camada travada,
regiões protegidas, marcador que segue o relevo e diagnóstico permanecem.
Rampas preservam o gesto de dois extremos. O contrato AX/CLI existente de
`Brush.stroke` (uma aplicação por polilinha) não muda; nova autoria temporal
precisa de entrada explícita, mesma autoridade e replay determinístico.
Força/unidade de tempo ficam claras na UI. Medir peça pequena e campo amplo.

## Demais provas Q5

Fluxo GUI das tarefas 1–9 do roteiro F9 sobre cópias descartáveis; terreno,
objetos, contexto/raros, montagem manual e seed/pins, variação regional,
recuperação/stale/conflitos, proposta de skill rejeitada/aplicada no escopo,
publicação revisada e consumo. Inspeção de rampa/ponte/rota inferior/corpo/LoS,
UX/AX e continuidade. Verificar diário cheio, compactação e vários drops sem
duplicar bens, medir pausas. Export release da fase atual e abertura em
ambiente limpo com perfil descartável, sem fonte/editor disponível.

Consolidar matriz por requisito com evidência, falha ou dependência humana
explícita. Falha dentro do contrato é corrigida; promessa faltante não vira
opcional. Registrar limites de escala e desempenho. Sem master/push; playtest
somente depois da aprovação técnica conforme WORKFLOW. Não apagar fixture
ativa ou arquivos pessoais; limpeza de gerados somente ao fechamento seguro.
