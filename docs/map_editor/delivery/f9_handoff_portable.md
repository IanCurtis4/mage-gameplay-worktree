# RagRPG — handoff portátil de F9

<!-- f9-patrol-gameplay-active -->
## Checkpoint51 — área final: auditoria técnica e roteiro de aceite (P7)

1/11/2026. Mesmo checkout/branch/fixture. Base 09cbff50; código e documentação
em commits próprios. Papéis inalterados. Roteiro: delivery/f9_acceptance_script.md.

- Pedido humano: seguir para o P7.
- Amostra de aceite conferida no Bosque commitado e no pacote publicado
  (AreaAcceptance13): clareira com dois materiais e caminho curvo, platôs com
  rampas, ponte sobre a passagem inferior, bifurcação no bosque oeste e passagem
  inferior sem saída, santuário com pilares e conclusão, emenda entre as duas
  peças, arbustos de decoração, rochas que bloqueiam e árvores que ocluem,
  encontros espalhados, grupo, patrulha com slot fixo, entrada e objetivo
  existentes. Proposta de skill numa cópia da clareira: revisada, aplicada uma vez
  e recusada fora do escopo, sem tocar nas fontes.
- Em cópias da área (AreaVariants6): geração por seed com a passagem fixa, pelo
  mesmo compilador; pincel com duas espécies 3:1 realizado no Bosque; o sorteio
  canônico deu 3007/993 em 4000.
- Cópia de aceite `.tools/f9_aceite` (fora do git) e
  `.tools/claude_bridge/abrir_editor_aceite.ps1`: copia a fixture sem sessões,
  probes e drivers de teste, liga o editor de mapas, usa perfil descartável próprio;
  abre sem erros.
- Roteiro humano com as 8 tarefas da amostra, o roteiro entre telas, a conferência
  visual do Bosque e a tabela de registro.

Pendente: aceite humano pelo roteiro (P7); P8 (recibo e limpeza).
<!-- /f9-patrol-gameplay-active -->

## Histórico checkpoint50 — publicar pelo roteiro, oclusão no jogo e nativos antigos (P6b–P6d)

1/11/2026. Mesmo checkout/branch/fixture. Base 8fcce595; código e documentação
em commits próprios. Papéis inalterados. Contratos: contracts/f9_guided_flow.md e
contracts/f9_occlusion.md; consumption.md atualizado.

- P6b: etapas "Teste" (pronta quando o jogo real abre com o pacote da revisão) e
  "Publicação". "Publicar no jogo…" pede identificador e nome, diz se é mapa novo
  ou nova revisão (pacote anterior → novo) e, depois de "Publicar", grava em
  segundo plano `<id>.<hash12>.rpp` (a revisão anterior fica em disco), a fonte
  `<id>.patrol.json` e a entrada da lista de mapas, só se a lista ainda é a
  revisada (`map_release.gd` `plan_publication`/`publish`; AX
  `<tela>/workflow/publish`).
- P6c: árvores, rochas e pilares com oclusão de câmera esmaecem no jogo enquanto o
  jogador ou um inimigo está atrás (mesma regra da prévia do editor, agora com a
  condição de estar à frente do ator); arbustos de decoração nunca esmaecem.
  Provado no Bosque publicado.
- P6d: M3Native24 migrado para o teste no jogo real pelos comandos da tela; os
  nativos antigos de M2 (malhas do exemplo grande com as faces laterais), M4
  (simulação canônica pelo teste técnico do canvas), M5 (teste de patrulhas no
  jogo real, suspenso e retomado) e M8 (seção "Variação regional") atualizados.
- WorkflowNative28, OcclusionNative12, Workflow12, ReleaseApi11, BiomePropsNative,
  ShadowsNative, CanvasOrder, GameplayNative e runners nativos M2–M5/M8 PASS. O
  nativo do M3 abre o jogo real e passou a ter os 300 s dos outros runners
  nativos (antes 60 s); as travas deixadas pela rodada morta no limite antigo
  foram liberadas, sem apagar sessões.

P6 fechado. Próximo: P7, iniciado no checkpoint51.

## Histórico checkpoint49 — roteiro guiado entre as telas (P6a)

1/11/2026. Mesmo checkout/branch/fixture. Base 36ca0f52; código e documentação
em commits próprios. Papéis inalterados. Contrato: contracts/f9_guided_flow.md.

- Pedido humano: seguir para o P6; manter o instalador `.tools/godot.zip`.
  Escolhas humanas: barra de etapas nas telas; publicar no jogo como etapa final
  com confirmação (P6b); levar o esmaecimento de oclusão ao jogo (P6c).
- Faixa "Roteiro do mapa" no topo das telas de terreno, composição, encontros e
  patrulhas: Peça, Mapa, Encontros, Patrulhas e Teste com estado (pronta, a
  fazer, desatualizada, a revisar, em andamento, com problema, aguarda a
  anterior, não aberta, opcional) e "Próximo passo" pelos produtores de cada tela
  (compilar, abrir a próxima tela, começar o mapa com a peça aberta, preparar e
  aplicar o plano, testar). Fora dos menus; visível em UX e AX.
- Levar uma etapa adiante (`workflow/carry_forward.gd`), em segundo plano e com
  revisão: a peça atual troca seus snapshots no mapa; o mapa atual entra nos
  encontros com cada marcador seguindo sua posição do mapa e assentando no novo
  chão, plano reconferido com os mesmos slots; os encontros atuais entram nas
  patrulhas com as rotas e os pontos seguindo. Aplicar é um desfazer e só vale
  sobre a base revisada.
- Diagnóstico no fluxo: posição removida, camada perdida ou slot ausente nomeiam o
  marcador ou a rota; "Mostrar o problema" abre a tela dona e foca a entidade.
- AX `<tela>/workflow/{state,next,apply,discard,show,open}` sobre o mesmo modelo.
- Workflow12, WorkflowNative23 e as etapas das telas (job 211) PASS; runners M2–M7
  headless e M6/M7 nativos PASS. Os nativos antigos de M2, M4, M5 e M8 falham
  igual na base 36ca0f52 (jobs 213/215): expectativas defasadas, migradas no P6d.

Próximo: P6b–P6d, feitos no checkpoint50.

## Histórico checkpoint48 — release com o Bosque e ponto de consumo (P5)

1/11/2026. Mesmo checkout/branch/fixture. Base 40b50290; código e documentação
em commits próprios. Papéis inalterados. Guia: consumption.md.

- Pedido humano: seguir para o P5.
- Pacote do Bosque publicado e commitado: `data/map_authoring/sanctuary_woods.rpp`
  (1,4 MB, pacote f3cdb460…, fonte 58df5d63…), compilado pela CLI do produtor sem
  cache em ~3 min; os bytes são idênticos aos do pacote de 31/10 (compilação
  determinística).
- Lista de mapas publicados `data/map_authoring/release_packages.json` (formato
  fechado, pinos de pacote/fonte/revisão) e o ponto de consumo
  `scripts/map_authoring/release/map_release.gd`: `packages`, `entry`,
  `load_package`, `manifest`, `prepare` (só no jogo) e `freshness` (autoria).
  Pacote diferente do fixado, adulterado ou entrada insegura são recusados com
  diagnóstico em português.
- Release limpo: a etapa `Release` do candidato copia o executável e o `.pck` para
  uma pasta nova fora do projeto, com perfil novo e diretório de trabalho nela, e
  abre o Bosque pela API: pacote fixado, 7 atores reais, patrulha, preparação de
  gameplay pelas autoridades do jogo e caminhada até o santuário
  (`release_bosque` 8/8, ~2 min; `release` representativo 6/6). O jogo só criou
  cache de shaders no perfil novo.
- ReleaseApi 11/11 (lista, pinos, frescor da fonte, manifesto como cópia,
  adulteração, publicação por hash sem sobrescrita, export, preparação).

Próximo: P6 (UX guiada entre telas, diagnóstico localizado, oclusão), iniciado no checkpoint49.

## Histórico checkpoint47 — assets no intercâmbio, fontes de skills e segunda limpeza (P4)

1/11/2026. Mesmo checkout/branch/fixture. Base 42ca1c38; código e documentação
em commits próprios. Papéis inalterados. Guia: exchange.md.

- Pedido humano: seguir para o P4 e fazer uma segunda limpeza de itens defasados.
- Limpeza (~0,7 GB; 8,7 → 9,4 GB livres): fixture gerada do M1 (318 MB), rascunhos
  grandes do teste de documento e verificações antigas dentro da fixture (177 MB),
  evidências de rodadas substituídas nunca commitadas, rascunhos de probes na raiz
  de `.godot`, patches já aplicados, jobs e saídas antigas da ponte, cópia
  aposentada de probe; objetos soltos do git empacotados (`git gc`, sem expirar
  reflog). Preservados: `RagRPG/build` (versões do jogo), `.tools/godot.zip`, os
  `.bak` das fontes do Bosque, sessões de jogo e o livro de revisões.
- Bundle de intercâmbio v2 (`map_exchange_v2`): `source.json`, `report.json` e
  `assets.json`, o manifesto passivo de cada asset que o pacote compilado usa
  (caminho, hash, tipo, base de direitos e registro de origem; sprites e catálogo
  dos props inclusos; encontros e patrulhas declaram os assets do mapa). Nenhum
  arquivo viaja. Fora da área de assets do editor ou de formato não permitido é
  `unsafe_asset`; manifesto que não cobre o relatório é adulteração; antes de
  compilar, asset ausente ou diferente no projeto que recebe é nomeado. Pacotes v1
  são recusados (reexportar). Revisões reais dos compiladores (terreno v5,
  composição v5) no lugar de `map_terrain_v2`/`map_composition_v1`.
- Fonte da skill `ragrpg-mapdelivery`: seção do editor F9 (bundle v2, assets só
  declarados, máscara comum, três vias com escolhas, `merge`, variação regional e
  recibos). Sem instalar cópias.
- ExchangeAssets12; ExchangeMerge, ExchangeMergeNative e M7 headless/nativo PASS.

Próximo: P5 (release com o Bosque e API de consumo), feito no checkpoint48.

## Histórico checkpoint46 — recibos e replay das variações (P3d; fecha o P3)

1/11/2026. Mesmo checkout/branch/fixture. Base 99dff335; código e documentação
em commits próprios. Papéis inalterados. Contrato:
contracts/f9_regional_synthesis.md (seção "Estado").

- Pedido humano: seguir para o P3d.
- Toda proposta de variação leva um recibo na raiz (peça, mapa, encontros ou
  patrulhas, nunca dentro de um snapshot): o pedido fechado, os hashes da base,
  das dependências (catálogos, manifesto de assets, revisões dos compiladores e
  do algoritmo) e do resultado sem os recibos. O hash integral é calculado depois
  de inserir o recibo e não fica dentro dele; fontes antigas sem recibo mantêm o
  hash. No máximo 32 recibos por documento (os mais antigos saem).
- Ao aplicar, a base vai para um livro passivo de revisões
  (`.godot/map_authoring/ledger`, só cópias, no máximo 64 arquivos/128 MB) e o
  recibo pode ser reproduzido: mesmo pedido sobre a mesma base dá o mesmo hash.
  Edições posteriores e dependências mudadas aparecem no resultado; base ausente
  é diagnóstico, resolvido com o pacote de replay (recibo + base, passivo).
- Telas: lista "Recibos das variações aplicadas" nas ferramentas de variação
  (terreno, mapa, encontros, patrulhas), "Reproduzir recibo", "Exportar recibo e
  base…", "Reproduzir de um pacote…". AX `<tela>/synthesis/{receipts,replay,
  replay_bundle,replay_import}`; CLI `replay` e `bundle`.
- SynthesisReceipts11, RegionalSynthesisNative16 e RootSynthesisNative11 (GUI,
  AX e CLI reproduzem o mesmo recibo); suítes de documento, terreno, composição,
  encontros, patrulha, geração e intercâmbio PASS.

Próximo: P4 (assets no bundle e fontes de skills), feito no checkpoint47.

## Histórico checkpoint45 — intercâmbio de três vias (P3c)

1/11/2026. Mesmo checkout/branch/fixture. Base a183b845; código e documentação
em commits próprios. Papéis inalterados. Contratos:
contracts/f9_regional_synthesis.md (seção "Estado") e exchange.md.

- Pedido humano: começar o P3c.
- Fonte que mudou depois do pedido exportado não é mais recusada inteira: base,
  versão atual e proposta são comparadas por identidade, campo e amostra (alturas
  e mistura de materiais uma a uma). Mudanças disjuntas se combinam; a mesma
  mudança dos dois lados vale uma vez; o resto é conflito com escolha explícita
  ("manter a atual" ou "usar a proposta") e nova validação. Proteção nova da
  versão atual prevalece; remoção contra edição e referência rompida recusam.
  A fonte combinada é validada e compilada; a proposta continua conferida contra
  o próprio relatório.
- Máscara comum com a variação regional: região protegida guarda a grade da
  camada, a lista de proteções, as amostras cuja influência a toca (altura e
  mistura) e os objetos que a tocam; antes travava a camada inteira.
- Encontros: depois da combinação o plano é reconferido sem sortear (escopo do
  P3b); `plan_hash` só muda depois de validado.
- Tela de intercâmbio: conflitos com base/atual/proposta, escolha por conflito,
  "Revalidar com as escolhas" e resumo da combinação. AX
  `<tela>/exchange/{export,review,apply}`; CLI `merge` (fonte combinada num
  arquivo novo) e `review` com escolhas.
- ExchangeMerge13 e ExchangeMergeNative10 (editor real: GUI, AX e CLI com o
  mesmo hash, um undo). M7 headless e nativo PASS; o check de base divergente
  passou a esperar `exchange_conflict` (o mesmo campo mudado dos dois lados).

Próximo: P3d (recibo e replay), feito no checkpoint46.

## Histórico checkpoint44 — variação regional no mapa, nos encontros e nas patrulhas (P3b)

1/11/2026. Mesmo checkout/branch/fixture. Base c95f1a3c; código e documentação
em commits próprios. Papéis inalterados. Contrato:
contracts/f9_regional_synthesis.md (seção "Estado").

- Pedido humano: seguir para o P3b.
- `synthesis/root_synthesis.gd`: a variação de uma peça vale para uma posição do
  mapa, com o mapa, os encontros ou as patrulhas abertos. A peça variada vira um
  snapshot novo e só aquela instância troca de `piece_hash`; as outras posições da
  mesma peça, vínculos, bordas e contexto ficam. Snapshot sem uso sai.
- Encontros e rotas: entrada, saídas, slots e trechos de patrulha da camada
  protegem o chão sob eles. Depois da variação, cada marcador é religado ao piso
  novo da mesma camada e posição (nunca ao piso mais próximo); corpo que mudaria
  de altura recusa a proposta apontando o marcador; centros de pincel são
  reassentados e aparecem no diff.
- "Redistribuir os soltos dentro da região": o planejador reserva todos os slots
  que ficam (fixos, de patrulha, fora da região) e só sorteia o que falta dentro
  da seleção. Em "preservar", o plano é só reconferido no mapa novo. O
  `plan_hash` muda só depois do plano final validado; a raiz inteira é compilada
  antes da prévia.
- Telas de mapa, encontros e patrulhas: "Variação regional…" (janela própria,
  prévia em segundo plano com a peça variada e o resumo da reconciliação). AX
  `<tela>/synthesis/*`; o CLI aceita peça, mapa, encontros ou patrulhas.
- RootSynthesis12 (duas salas com a mesma peça) e RootSynthesisNative10 (editor
  real: GUI, AX e CLI com o mesmo hash, um undo). RegionalSynthesis(Native),
  PopulationPlanner, EncounterAuthoring(Native), CompositionAX(Native),
  MapBiomeNative, LibraryNative e GameplayEditorNative PASS. Bosque real (patrulhas abertas, relevo na região woods_clearing da clareira, sem cache): proposta em 320 s; só 1 amostra pôde mudar porque os 3 slots da região e o raio conservador ocupam quase toda a área; 3 slots religados ao piso novo e 1 centro de pincel reassentado.

Próximo: P3c (intercâmbio de três vias), feito no checkpoint45.

## Histórico checkpoint43 — variação regional dentro de uma peça (P3a)

1/11/2026. Mesmo checkout/branch/fixture. Base 81ab8ddf; código e documentação
em commits próprios. Papéis inalterados. Contrato:
contracts/f9_regional_synthesis.md (seção "Estado").

- Pedido humano: registrar as pendências menores para F10 e começar o P3.
  Registradas na matriz ("Movidos para F10") e em contracts/f10_final_review.md:
  `start()` do teste, cache regional, compactação do diário, coleta de vários
  drops, `RoundedResume` encadeado.
- Serviço novo `scripts/map_authoring/synthesis/regional_synthesis.gd`: pedido
  passivo fechado (revisão, seed, base, camada, região ou polígono, canais
  terreno/materiais/objetos com "preservar" ou receita, preservações).
  `prepare()` monta a fonte inteira numa cópia, compila e devolve proposta e diff;
  `apply()` confere o hash e faz uma única `session.apply` (um undo).
- Máscara: a amostra só muda se toda a sua influência estiver dentro da seleção e
  longe de regiões protegidas ou preservadas, aberturas de conexão e do footprint
  de todo objeto que fica. Objeto que cruza a borda ou toca proteção fica inteiro;
  travados e preservados nunca saem.
- Receitas: relevo por seed com transição até a borda, manchas de material (mesma
  mistura do pincel) e espalhar objetos, opcionalmente trocando os soltos de
  dentro, assentados no terreno novo.
- Tela de terreno: ferramenta "Variação regional" (prévia em segundo plano com
  progresso e cancelamento, aplicar, descartar). AX `terrain/synthesis/*`. CLI
  `synthesis/headless.gd` (não grava a entrada nem sobrescreve a saída).
- RegionalSynthesis12 (Bosque, clareira) e RegionalSynthesisNative14 (editor
  real: GUI, AX e CLI com o mesmo hash, um undo, cancelamento e prévia velha sem
  mutação). LibraryNative, AuthoringNative e Authoring PASS.

Próximo: P3b (instância de mapa, encontros e patrulhas), feito no checkpoint44.

## Histórico checkpoint42 — responsividade do editor (P2)

1/11/2026. Mesmo checkout/branch/fixture. Base a08d0185; código e documentação
em commits próprios. Papéis inalterados. Contrato:
contracts/f9_editor_responsiveness.md.

- Pedido humano: seguir com o P2 e limpar o que ocupava o HD. Limpeza: ~1,4 GB
  de artefatos gerados (fixtures antigas, export de teste, sessões de 27–30/10,
  patches já aplicados); 8,3 → 9,7 GB livres.
- Medido: a compilação dos encontros do Bosque levava 165 s e a das patrulhas
  180 s, no limite de 180 s do processo de trabalho do editor. Cada lote de
  conectividade reconstruía os predicados de navegação do zero.
- Lote de conectividade usa o memo de predicados do mundo (mesmos valores):
  lotes seguintes de ~11,5 s para ~2,3 s.
- Cache verificável de mapa e encontros (opt-in, ligado pelo plugin do editor;
  testes compilam de verdade): encontros 96,5 s na primeira vez e 4,8 s sem
  mudança; patrulhas 9,8 s quando só a rota muda.
- Intercâmbio: prévia da base e aplicação compilam fora da thread da interface.
  Jobs de trabalho não deixam mais sobras em .godot/map_authoring/jobs.
- CompileCache10 novo; navegação/população, GameplayNative, AssetManifest e
  runners M3–M7 PASS.

Próximo: P3 (síntese regional e reconciliação). `start()` do teste movido para
F10 por decisão humana no checkpoint43.

## Histórico checkpoint41 — matriz de fechamento, regressão de base e release

31/10/2026. Mesmo checkout/branch/fixture. Base 0ce15143; código, testes e
documentação em commits próprios. Papéis inalterados.

- Pedido humano: seguir para a matriz do editor ("pode ver você mesmo o que
  falta"). Resultado em `f9_closure_matrix.md`: o jogo do Bosque avançou, mas o
  editor não está perto do fim. Faltam síntese regional, reconciliação,
  transporte de assets no intercâmbio, responsividade do editor, release com o
  Bosque e o fluxo humano guiado (pacotes P2–P8).
- Regressão de base: 56/58 etapas F9 e M2–M8 Core PASS. Corrigidos: dois checks
  de `LibraryNative` que contavam comandos AX antigos; a fixture isolada do M1;
  o release M8, que recusava o pacote (pacote de 25/10 e validação que lia PNGs
  crus ausentes no export). Manifesto de assets no build (AssetManifest7),
  pacote representativo recompilado. Release PASS.
- `RoundedResume` continua encadeado ao `RoundedNative` (precisa da sessão).

Próximo: P2 (responsividade do editor e do teste), depois P3 (síntese regional
e reconciliação).

## Histórico checkpoint40 — diário J3: ondas, respawn e mortes gravadas na hora

31/10/2026. Mesmo checkout/branch/fixture. Base 65bb6ce2; código e documentação
em commits próprios. Papéis inalterados.

- Pedido humano: seguir com F9 fechando o diário antes da matriz do editor.
- Ondas: entrada `wave` (relógio, slots esperando respawn, nascimentos admitidos)
  em vez da transação completa; o retorno também leva e admite nascimentos.
  Ao vivo, os nascimentos entram numa fila e nascem um por quadro.
- Mortes de mob: gravadas na hora fora de combate e no máximo a cada 2 s em
  combate (antes só no fim do combate, perdidas se o jogo fechasse). Se o diário
  recusar em combate, esperam o fim do combate, nunca a transação completa.
  Eventos que chegam durante uma gravação vão logo depois dela.
- Drops: pool elegível memorizado no `MobLootResolver` (~28 ms por morte antes).
- Bosque em janela: 7 mortes de uma vez sem quadro acima de 40 ms na gravação
  (antes 214 ms); a onda que traz os 7 de volta, 42 ms de pior quadro (antes
  ~11 s de transação completa). Base + diário reaplicado igual ao vivo.
- Teste novo `e07_f5_waves_journal_test` (36), CampaignJournal22, GameplayNative63
  (morte gravada durante o combate, pior quadro 14 ms) e legados E06/E07 PASS.

Pendente: compactação do diário perto do limite (256 entradas); ~60–75 ms na
coleta automática de muitos drops; matriz do editor F9-01..12; aceite humano.

## Histórico checkpoint39 — morte sem trava, retorno sem pose de morto, fundo com a arte do bioma

31/10/2026. Mesmo checkout/branch/fixture. Base 4edafa3a; código e documentação
em commits próprios. Papéis inalterados.

- Pedido humano: a morte ainda travava a tela por segundos; ao voltar, o
  personagem aparecia com o sprite de morto; o fundo saía azul-acinzentado em vez
  de um bosque. Respondeu também os conflitos do estudo de fase.
- Morte e retorno: `player_death` entra numa entrada de mortes do diário e o
  retorno vira uma entrada `revive` (relógio depois da penalidade); ambos gravam
  em segundo plano no mesmo host. Probe com janela no Bosque: morte 20,8 ms de
  pior quadro (485 ms até a gravação durável), retorno 20,0 ms (639 ms), host
  mantido, jogo pausado em recuperação e solto depois do retorno.
- Pose: `CombatAnimationState.revive()` limpa o estado `dead`; o retorno chama e
  redesenha.
- Fundo: `ExpeditionBackdrop` pinta o chão com a textura do bioma e duas camadas
  de props da biblioteca (carvalhos, arbustos, pedras; pilares em ruína; cactos
  no deserto) em parallax, com névoa e bordas escuras.
- Decisões de fase registradas em `contracts/f10_phase_architecture.md`
  (boss como estrutura mínima, término antecipado com bônus proporcional,
  limpeza total só na primeira jogada, desbloqueios por personagem, fundo por
  mapa/dungeon, mapas grandes ≥ metade da área dos campos do RO).
- GameplayNative63, CampaignJournal19, demais etapas e 38 legados E06/E07 PASS.

Pendente: gravar cada morte de mob na hora; J3 (ondas/respawn, inclusive retorno
com respawn pendente); contrato de F10; aceite humano.

## Histórico checkpoint38 — gravação em segundo plano, coleta automática, leash e fundo temático

31/10/2026. Mesmo checkout/branch/fixture. Base 3a12a2a4; código e documentação
em commits próprios. Papéis inalterados.

- Pedido humano: gravar o perfil em segundo plano; recompensas (drops e XP)
  automáticas; inimigos fora do leash recuperam HP aos poucos ignorando aggro;
  fundo em parallax com o tema do mapa; estudo de arquitetura de fase (respondido
  no chat para validação, sem contrato ainda).
- Gravação: o perfil é escrito numa tarefa do WorkerThreadPool; o efeito do diário
  é publicado quando o resultado durável chega. Pior quadro na gravação das
  mortes 43,6 ms (antes 382–433 ms).
- Coleta: entrada `collect` no diário (tickets entregues, sessão e digest de
  posses depois); `main._auto_collect` coleta tudo fora de combate; regras de
  posse aceitam essa entrada como registro material.
- Leash: mob voltando para casa (aggro já ignorado) ou parado ferido recupera o
  HP total em 4 s (`EnemyActor.LEASH_RECOVERY_SECONDS`). O teste E06 que fixava
  "o retorno preserva o dano" foi atualizado para a nova regra.
- Fundo: `ExpeditionBackdrop` (CanvasLayer -100, fora do snapshot) desenha céu e
  três faixas em parallax por bioma (forest, ruin, desert, meadow).
- GameplayNative63, CampaignJournal16, demais etapas e legados E06/E07 PASS.

Pendente: validação humana do estudo de fase; gravar mortes na hora; J3
(ondas/respawn); aceite humano.

## Histórico checkpoint37 — rampa sob a saída final e diário de campanha (J1–J2)

31/10/2026. Mesmo checkout/branch/fixture. Base bdb8657d; código e documentação
em commits próprios. Papéis inalterados.

- Pedido humano: reproduziu o sumiço sob a rampa abaixo da saída final (jogador
  e árvore ao lado) e liberou o diário; o lag do meio do mapa sumiu.
- Rampa: ciclo nas restrições de ordem do canvas (árvore de borda enraizada
  dentro da projeção da rampa → rampa → jogador → árvore) fazia `apply` recusar e
  manter os z antigos. Corpo que atravessa uma tampa não é mais "sob a tampa";
  a apresentação ao vivo quebra ciclos em vez de congelar a ordem. Probe: 0
  ordens recusadas (antes 103/576 passos). CanvasOrder46.
- Diário J1–J2 (contracts/f9_campaign_journal.md): mortes do combate gravadas
  como uma entrada encadeada no perfil, com o efeito resolvido (tickets, RNG); o
  host não é restaurado nem trocado; restaurar = base + reaplicação. Pior quadro
  na gravação 433 ms (antes 11,5–13,3 s). Ondas/respawn seguem no caminho
  completo (J3); o adiamento até o fim do combate fica até a escrita ser
  assíncrona.
- CampaignJournal13 novo, GameplayNative59, regressões e legados E07 PASS;
  LibraryNative falha em 2 checks de contagem de comandos AX (arquivo de teste
  de 28/10, código não tocado aqui; a confirmar como anterior).

Pendente: tirar os ~0,4 s restantes (escrita assíncrona ou cache da validação
do checkpoint inalterado); J3; aceite humano.

## Histórico checkpoint36 — rotas em segundo plano

31/10/2026. Mesmo checkout/branch/fixture. Base e8d6532a; código e documentação
em commits próprios. Papéis inalterados. Contrato:
contracts/f9_navigation_async.md.

- Pedido humano: 1 s de travada ainda é visível; calcular aos poucos, só as rotas
  pedidas.
- Fatias por quadro não bastavam (busca quente ainda ~80 ms). A mesma busca de
  `WorldGeometry.path` roda numa thread do WorkerThreadPool sobre uma vista
  congelada da geometria, com memo próprio; o quadro principal só checa a linha
  direta, enfileira e recebe. Desligado em headless/testes/editor
  (`RAGRPG_SYNC_NAVIGATION=1` força o síncrono).
- Clique no chão, perseguição do jogador e IA dos inimigos (perseguição, recuo,
  volta para casa) pedem a rota em segundo plano; o ator segue a rota anterior e
  a resposta é emendada onde ele está, com o teste de aresta local do grafo.
- Bosque: clique na emenda deixa de travar 0,76 s; pior quadro 76 ms e a rota
  chega 0,79 s depois (personagem parado, "Calculando caminho…"). Combate igual
  com e sem (p50 ~15 ms).
- A gravação do fim do combate (11,5–13,3 s) é agora o maior travamento medido.
- NavigationAsync18 novo; navegação, gameplay e legados E07 PASS.
- Diário: compactação só em pontos seguros até a gravação ser assíncrona; estado
  dos inimigos após queda levado ao tester.

Pendente: diário de campanha (J1–J2 primeiro, para tirar a gravação do fim do
combate); captura da rampa; aceite humano.

## Histórico checkpoint35 — grafo de navegação reutilizável

31/10/2026. Mesmo checkout/branch/fixture. Base 11c67b2a; código e documentação
em commits próprios. Papéis inalterados. Contrato:
contracts/f9_navigation_graph.md.

- Pedido humano: o lag no cruzamento dos mapas tornava o teste injogável; grafo
  de navegação antes do diário.
- `WorldGeometry` guarda os predicados exatos de navegação entre consultas
  (memo por revisões, epoch de mutação e perfil; consulta especulativa fica de
  fora). A busca passou a A* com a distância reta (consistente: arestas custam a
  corda ou mais), com volta ao Dijkstra se um grafo violar isso. Arestas locais
  que a relaxação já rejeitaria pulam sweep e suporte.
- Bosque: casa→entrada 57,9 s → 1,18 s fria e 0,10 s repetida; emenda
  clareira→viaduto no clique 1,61 s → 0,76 s na primeira vez e ~0,08 s depois.
  Custos idênticos aos do Dijkstra.
- O snapshot exige declarar toda variável nova: os dois campos derivados entram
  em `omitted` do runtime_manifest.json.
- NavigationAstar18 novo; navegação, gameplay e 32 legados E07 PASS (presentation
  com a falha conhecida).

Pendente: aquecer superfícies em segundo plano (0,5 s na primeira emenda);
decisões do contrato do diário (J1–J4); captura da rampa; aceite humano.

## Histórico checkpoint34 — fim de fase, emenda do mapa e gravação incremental proposta

31/10/2026. Mesmo checkout/branch/fixture. Base 2262b8c3; código e documentação
em commits próprios. Papéis inalterados.

- Fim de fase recusado: o estado salvo do usuário tem os 7 slots mortos e
  `cleared_once` verdadeiro. A recusa vinha de `_at_point` (até 48 unidades do
  ponto exato do marco), com a mesma mensagem da limpeza. Agora o painel diz qual
  é o caso e o mapa desenha o círculo de 48 unidades no marco.
- Lag no meio do mapa: cruzar a emenda clareira→viaduto custa 1,6 s por
  `WorldGeometry.path`, e o clique calculava a mesma rota duas vezes (3,3 s).
  `WorldActorMotion.adopt_route` reaproveita a rota já calculada (clique e
  dash). O custo restante é a busca longa (grafo reutilizável).
- Atalho de teste: o Godot agora escreve só em arquivo. Um clique no console
  (modo de seleção do Windows) pausava o processo até apertar uma tecla.
- Gravação incremental: contrato proposto em contracts/f9_campaign_journal.md
  (checkpoint base + diário de eventos), aguardando decisão humana.
- Rampa abaixo do marco final: pendente de captura de tela do usuário.

Pendente: decisões do contrato do diário; grafo de navegação reutilizável;
captura da rampa; aceite humano.

## Histórico checkpoint33 — travamento em combate: gravação por morte adiada e aliviada

31/10/2026. Mesmo checkout/branch/fixture. Base 006a42ca; código a416be84 e
686bc304; commit documental posterior. Papéis inalterados.

- Pedido humano: inimigos amontoados impossíveis de clicar; Augments a ~0,1 FPS.
  Medido: a seleção funciona (2095 amostras empilhadas, 0 falhas). A causa era a
  transação completa da expedição a cada morte de inimigo (17–19 s; captura
  2,4 s, restauração 2,2 s, pack 1,1 s, pele 5,8 s) com troca de host.
- Decisão humana "Adiar + aliviar": mortes pendentes até o fim do combate, uma
  gravação com aviso "Salvando a expedição…"; captura sob barreira reaproveitada
  e pele autorada reaproveitada no host restaurado. Bosque: 3 mortes sem quadro
  longo e uma gravação de 11,2 s no fim.
- Também: pré-filtro exato de distância antes de consultas `ground_connected`
  (recompensa/áreas), sem polling em combate, aviso de Augments fora de combate,
  empate de corpos empilhados resolvido para o da frente.
- WorldRewardPoll10 novo, GameplayNative53 e demais etapas/legados PASS.
  Consolidação: evidence/f9/author/deferred_commit/consolidation.md.

Pendente: ~11 s ao fim do combate (par de restaurações do ExpeditionService,
invariante E07 F5, exige contrato Astra); mortes de uma luta não terminada se
perdem se o jogo fechar; grafo de navegação reutilizável; aceite humano.

## Histórico checkpoint32 — portão "Iniciar teste", diagnóstico de lag e mira no mundo

30/10/2026. Mesmo checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
Base 7452c2fc; um commit de código por checkpoint (31, 32) e um documental.
Papéis inalterados: Sol/Astra = Claude Opus, Terra = Claude Sonnet, Luna =
Claude Haiku. Executor de arquivos `RagRPG/.tools/claude_bridge` como no 30.

- Checkpoint31, a pedido humano (tela travada carregando, personagem já morto,
  "Reiniciar" preto): carregamento em thread e portão `held` com botão "Iniciar
  teste"; `begin` no protocolo; `restart` assíncrono; `timings.json` e
  `metrics.jsonl` por janela. GameplayGate24 novo PASS, e Window33, Cli18,
  Controls29, Native52, EditorNative22 e CandidateBatch18 PASS. Bosque: prepare
  93,5 s em thread, `start()` 31,8 s ainda na principal, 18–24 FPS ativo.
  Consolidação: evidence/f9/author/gameplay_gate/consolidation.md.
- Diagnóstico: não é o debug (release ≤1,3×). `WorldGeometry.path` em rota longa
  pela emenda leva 55–87 s e não tem reuso; a IA replaneja a cada 0,45/1 s.
  Opções em contracts/f9_runtime_navigation.md. Decisão humana: grafo de
  navegação reutilizável (opção 1), em fatias com contrato antes de código.
- Checkpoint32, a pedido humano ("difícil dar target"): o mundo usava um círculo
  de 32 px sem a "Trava inteligente" do modo plano. Agora a seleção usa o corpo
  desenhado (`pick_body_rect`, só apresentação; `collision_radius` intacto) mais
  a assistência de 68 px e a trava de 80 px do modo plano, só para alvo único, e
  respeita a opção. WorldTargeting16 novo PASS. GameplayNative desliga a trava
  só no clique de chão. Consolidação:
  evidence/f9/author/world_targeting/consolidation.md.

Pendente: aceite humano da mira e do Bosque; grafo reutilizável (contrato
Astra, depois fatias Sol/Terra com diferenciais); `start()` na principal;
validação duplicada no `prepare`; worker GUI 180 s; demais linhas da matriz. Sem
playtest/save pessoal/master/push/F10. Atalhos: `claude_bridge/Jogar Bosque -
novo teste.cmd` (abre parado em "Iniciar teste") e `… - retomar.cmd`.

## Histórico checkpoint30 — patrulha autorada; Bosque abre e roda no jogo

30/10/2026. Mesmo checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
Base 0bef9d53; conteúdo e5fddf84; código 01ffd228; commit documental posterior.
Papéis por decisão humana desta data: Sol e Astra = Claude Opus; Terra = Claude
Sonnet; Luna = Claude Haiku (ver WORKFLOW). Escopo humano desta rodada: patrulha
e mapa jogável para checagem humana; demais itens da matriz seguem abertos.

Execução no Windows por executor de arquivos fora do Git em
`RagRPG/.tools/claude_bridge` (watcher PowerShell; jobs `inbox/*.ps1`, logs
`outbox/`). Engine/fixture únicos de sempre, SHA AB1824F8…; pwsh para o runner.
Consolidação: evidence/f9/author/patrol_gameplay/consolidation.md.

- compile_02 Terra AX (fonte do checkpoint29): PASS 234,363s, pacote 543a1256….
- `demo_chaser` tem aggro_radius 0 → `patrol_unsupported`. `alley_guard` e o
  brush `alley_patrol` passaram a `pilot_bulwark_species`/normal/trial_stage_1,
  opção já existente no catálogo. Prévia 167,725s: diff 7 preservados, nenhum
  adicionado/alterado/removido; apply+save 161,708s; fonte 1404da19….
- Patrulha `sanctuary_woods.patrol.json` via AX (43,021s): `alley_watch`
  ping_pong, alley_north [1640,0,840] 2,5s, alley_south [1640,0,1100] 2,0s.
  patrol/compile AX PASS 211,333s, pacote f3cdb460…. Mapa/peças intactos.
- Sol: `GameplayCandidate.prepare` trocou `_both` (path individual ida/volta) por
  `connectivity_batch` agrupado por estágio/perfil inteiro, mesmo relato do
  primeiro item falho; `_both` mantido como referência. Luna criou
  CandidateBatch18; CandidateBatch18, GameplayWindow33, GameplayCli18,
  GameplayControls29, GameplayNative52 PASS, 2063 inputs iguais entre etapas.
- Bosque no jogo (AX nativo, HEAD 01ffd228): open+compile+launch 308,673s;
  janela `ready` 107,6s e `active` 138,4s após o retorno; log limpo. 7 inimigos
  vivos; guarda saiu de z960 e chegou ao primeiro ponto z840 (patrulha real).
- Achado: personagem parado na entrada morreu em ~2min; os 3 Guerreiros da
  clareira (sem aggro, perseguição legada) partem de 140–280 da entrada. É
  conteúdo/espécie, não erro de engine; decisão de produto pendente.

Pendente: aceite humano do Bosque; worker GUI editor180s para compilar
população/patrulha (inline AX ~200s); busca individual (f9_navigation_relaxation);
tempo de preparação ~108–138s; FPS não medido; reconciliação, síntese regional,
assets/export/release, UX final e demais linhas da matriz. Sem playtest/save
pessoal/master/push/F10. Atalhos de teste humano: `claude_bridge/Jogar Bosque -
retomar.cmd` e `Jogar Bosque - novo teste.cmd`.

<!-- f9-terra-consumer-active -->
## Histórico checkpoint29 — Bosque compila; retorno ao AX resolvido no checkpoint30

Produção43a6a0c3f636da4b09cbba10c54e34b6c92375e8, validação
611324c19baca71bc479c1d08e8135e7c62f8669. Mesmo checkout/branch. Recibo:
evidence/f9/author/encounter_authoring/planner_consolidation.md e
planner_audit_01.json. Fonte de população real salva APENAS via Terra AX,
data/map_authoring/sanctuary_woods.population.json,55.703B,
SHA2563debc7674a1770702639e8bb33b1e6598c52929e9230395ccfbf505c1ed04889,
semântico3af0a91b949012dc5acd0e37c1864d0f2df860ffd926baae78970b9692b22c9e.
Receita/guarda preservados,6novos slots/7total, quotas3/3/1. Mapa/peças idênticos.

Core Planner também refazia geometry.path por slot (leitura inicial incompleta).
Sonda compile01 terminou editor159,533s e travou Planner atéguard300. Sol trocou
só existência por lote stage/perfil, mantém regra sóida e custos/movimento/leash.
Cancel/stale/budget propagados sem parcial; métricas fora do pacote/save.
Luna20dirigidos+Context315+GameplayNative52+verify6/299(350checks) PASS;
2059/2053inputs auditados sem divergências. Pacote pequeno da regressão idêntico.
Compilação integral real sonda02:183,971s,exit0,7slots,sem mutação/erro/timeout,
pacote543a125634b45cfa426b3340adee22349bb401586d6a18bc95c3f8b0e1cd0854.

Próximo Terra: repetir compile por AX em receita/saída nova, mesmo source salvo;
se PASS, patrulha viaAX. Compile_01 AX histórico foi timeout360,557s, não PASS.
Não escrever produto manualmente, reduzir fonte/corpo/quota ou ampliar guards.
Todos os jobs anteriores terminaram; fixture liberada neste checkpoint, confirmar
estado real antes de iniciar algo. Não reiniciar handles antigos.

Sem Bosque App/percurso/combate/FPS, patrulha ou pacote AX final aprovado ainda.
Worker editor180s exige medição/otimização, não PASS inferido do ensaio183,971s.
GameplayCandidate._both ainda faz path na preparação; consulta individual e
outros itens da matriz F9 abertos. Fonte da skill/guia, geração regional,
reconciliação, assets/release/UX restantes não passam para F10 por esse checkpoint.
Sem playtest/save pessoal/master/push/F10; meta integral F9 ativa.
<!-- /f9-terra-consumer-active -->


<!-- f9-population-batch -->
## Histórico checkpoint28 — alcance de população validado

Candidato validado9c8185c6cedbfd1ef48dfa88821268fb9afb0677; produção956d38dd,
branch codex/map-editor-f9 no checkout .tools/map-editor-m5. Detalhes/recibos:
evidence/f9/author/encounter_authoring/population_consolidation.md e
population_audit_01.json. Luna27dirigidos + Context53/91/58/113 PASS;
verify2/299 (import/população F5) PASS.2056/2050inputs auditados, zero divergências.

Fonte AX real original inteira concluiu geração em157,130s, exit0/sem timeout,
sem mutação,7slots, quotas3/3/1. Prova do santuário15,472s; mapa33,156s;
pools78/316/165pontos em28,087/2,571/50,569s. Corpo20x32, mapa, pontos, guards
AX300s/editor180s e caps canônicos inalterados. Não afirmar fator preciso contra
timeout anterior ou performance in-game/FPS. Ainda NÃO houve aplicação AX ou
compilação das fontes finais de população/patrulha. Fixture liberada, engine0.

Próximo Terra: abrir rascunho via AX, preview, conferir proposta/diff, aplicar com
hashes exatos e salvar população; compile em processo separado, depois patrulha.
Fonte de produto sempre via editor. Sol integra, sem novo gate humano para esse
consumo autorizado. Guards não aumentam; falhas preservam draft/diagnóstico.
PopulationCompiler usa lote só para existência; path individual/custos/leash
inalterados. Revisão map_population_v2 e intercâmbio v2, fontes antigas aceitas,
pacotes v1 exigem recompilação sem sobrescrita. `_path` original mantido para
diferenciais. Falhas de sonda/parser, tipo do teste, referência e protocolo do
runner preservadas;27oráculos não foram enfraquecidos.

F9 integral ativo, sem aceite de produto/playtest/master/push/F10. Restam mapa
final em jogo, performance individual/preparação, geração regional, reconciliação,
UX/AX/publicação, assets/export/release/guias e demais itens da matriz.
<!-- /f9-population-batch -->


<!-- f9-population-active -->
## Histórico do bloqueio — geração resolvida no checkpoint28

Base atual bc52103eee28072d70243b42a002056bc0bf90fa, mesmo checkout/branch.
Produtor AX do checkpoint27 continua validado; o consumo no mapa real encontrou
custo de navegação. Fonte final de população/patrulha ainda NÃO existe.

Terra executou query_02 por AX:4/4, exit0,46,346s; forest/84apoios/catalog/socket
reais retornados. Depois nove ações criaram e salvaram por AX o rascunho:
evidence/f9/terra/area_encounters/population_draft_01.json,
SHA2564d64d6ffbce706a2917b2a1ad436decfd362b96575a7a4b4bbd001ededdb7cb1,
fontef7a6b516a76703c1d46419d052e112997de11db31b42f1a6633cceec0a50a19c.
Quotas3/3/1, espécie demo_chaser normal trial_stage_1; fixoalley_guard e objetivo
shrine_completion. Entrada[160,0,640], grupo[1580,0,1080], fixo[1640,0,960],
santuário[2336,128,192]. Apoios reais constam na fonte/consulta, não inferir IDs.

Décima ação plan/preview retornou compile_timeout. Wrapper encerrou após
360,562s com timed_out=true/exit_code=null; processo externo terminou1. Plano não
aprovado/aplicado, sem pacote válido; request/result/receipt/logs e attempt_02.md
preservados na pasta Terra. Todos os engines terminaram; fixture liberada.
Não reiniciar o processo antigo nem contar timeout como PASS.

Primeiro intento foi só confirmation_required por confirm_discard=false na
sessão inicialmente dirty. Essa confirmação já é autorizada nesta autoria;
usar true em trocas intencionais com preservação de draft, sem perguntar ao humano.
Sol criou wrapper síncrono run_ax_request.py em author/encounter_authoring para
capturar exit/env/argv/logs e aguardar o processo real. Limites internos AX300s e
worker editor180s não foram alterados. Mapa/duas peças protegidos permaneceram
idênticos; não tocar playtest/save pessoal/master/push.

Próximo Sol: instrumentar a mesma entrada/destinos para localizar o custo em
PopulationCompiler.prepare/_path/pool, depois adotar prova de alcance canônica
compartilhada onde só existência é exigida, conforme f9_navigation_batch.md.
API connectivity_batch já retorna flags por terminal/sentido e testemunhas,
max_targets4096/256MiB/240s. Não confundir testemunha BFS com menor custo; path
individual/custos/leash e gameplay continuam exigidos. Leitura inicial do Planner foi incompleta: ele também chama geometry.path por slot
na admissão canônica, conforme diagnóstico de compilação01; PopulationCompiler.prepare interações,
placement_code/pool e validação de slots chamam path ida/volta repetidamente.
Reproduzir a fonte inteira original; sem reduzir mapa/corpo/quotas ou aumentar
timeout/caps. Cancel/budget/stale não são negativos geométricos. Não há novo
runtime implementado para esse gargalo ainda. F9 integral permanece ativo.
<!-- /f9-population-active -->

<!-- f9-current-ax -->
## Checkpoint 27 — AX de encontros e patrulhas validado

Runtime5a97f7d7e095b36d65795140bae82a7178b73d6b; validação e fixtures
3a5bff35a573cce3ac76439d68d59eaed87c7974. Branch codex/map-editor-f9 no checkout
C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5.
O commit documental sucede3a5. Meta integral F9 ativa, sem aceite de produto,
playtest pessoal, master/push ou abertura F10.

Sol entregou PopulationOperations/PatrolOperations compartilhados entre GUI/AX,
documentos/Stores com conflito por bytes lidos, entrada/brushes/espécies/pesos/
exclusões/interações/slots fixos, prévia assinada com base/diff/hash/confirm,
rotas/pontos/ordem/espera/slots exclusivos e consultas de catálogo/apoios/sockets.
Não há setter de fonte completa. Workers/compiladores canônicos preservam
corpo, suporte, origem/recompensa e leash. Cliente abre janelas reais e retorna
population_snapshot/patrol_snapshot; hashes por ação usam a sessão correta.
Import_map evita uma compilação duplicada por repasse síncrono do pacote validado,
sem cache persistente ou fechamento de F9-10.

Luna27/25, Gameplay52, Candidate53/Population91/Patrol58/Exchange113 e
verify editor_import (1 ID de299) PASS. CLI real passou em5processos:
preview2/2, headless12/12, nativo12/12, reabertura4/4 e negativo2/3 com exit1
esperado, sem salvar após falha. Fontes/pacotes/bytes iguais entre modos.
Dados originais descartáveis intactos; nenhuma fonte do produto criada aqui.

Primeiro Native24/25 foi preservado. Diagnóstico manteve25oráculos: UI tinha
passo0,1 e recebeu1,75, armazenando1,8; GUI/AX e demais flags eram iguais.
Produção não mudou. Fixture UI passou a1,8 exato; modelo e CLI cobrem1,75
fracionário exato. Não houve relaxamento de corpo/rota/caps nem erros ocultados.
Consolidação: evidence/f9/author/encounter_authoring/consolidation.md.
Recibos: evidence/f9/luna/encounter_authoring e author/encounter_authoring/cli_01.

Auditoria Sol:2054inputs completion/CLI,2048Context, diferença dos6imports de props;
10imports conferidos e zero divergências source/fixture/manifest. Quatro UIDs
geradas pelo engine. Nenhum engine/handle ativo; fixture liberada.
Fixture única --path:
C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/.godot/verification/e07_f1/fixture_project.
Engine C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe.
SHA256 AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424.
APPDATA/LOCALAPPDATA privados na fixture; não usar source checkout como --path.
SkipImport não é sync geral. Três backups locais preservados, fora do Git.

Bosque de produto ainda é o mapa do checkpoint26, conteúdo86359e3d:
data/map_authoring/sanctuary_woods.map.json,45.615B,
arquivo8e3f1c3c47709d204eeaf3061e3d98beabb0dfa987ed09ff24ad2ec79e6a631f,
fonte8a9051f8a416a58890365e1b262cea309053ff52c5ce20725d0598ef7875ed55,
pacote098aa6b630015504ec47abfa45257fb0c7b571efabad590016dcc34acfc71fdc.
2peças/47props/84apoios/131conexões/35spans forest; corpo20x32 preparado.
Sem sanctuary_woods.population.json ou .patrol.json ainda, sem App/caminhada/
combate/objetivo/FPS do Bosque. Custos canônicos anteriores28,5s/30,4s continuam
pendência de runtime, não apenas sobrecarga de testes.

Próximo autorizado: Terra executar autoria de encontros/patrulhas/phase_completion
pelo AX real, consultando catálogo/apoios e respeitando contexto/body/leash.
Plano passivo em evidence/f9/terra/area_encounters. Não escrever fonte JSON pronta.
Medir preparação/geração e caminhos reais; PopulationCompiler.pool ainda chama
path individual por candidato e pode exigir otimização comprovada por impacto.
Sem aumentar timeout/caps ou reduzir mapa/corpo para fazê-lo passar.

Continuam integrais: reconciliação de revisões; síntese/regeneração regional e
proteções; assets/bundles/ambiente limpo/export/release; recuperação, progresso,
cancelamento/cache/invalidação integral; UX final; gameplay real e medição
representativa in-game; área final e toda matriz F9. M3Native24 histórico precisa
migração/retirada com cobertura atual preservada. Nada foi movido para F10.
CLI de workflow e WORKFLOW_TOOLING.md ausentes nesta worktree; não inventar instalação.
<!-- /f9-current-ax -->

<!-- f9-checkpoint26-history -->
Nota histórica preservada: o checkpoint27 acima rege a retomada.
## Checkpoint 26 — 29/10: bioma e bordas florestais integrados

Código 4e3a3788878c7520552c7815d0c2915301857f5f; conteúdo
86359e3ddc33ff3dd5ef5a9f009dd7bc0ca306f2, branch codex/map-editor-f9.
Checkout: C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5.
O commit documental deste checkpoint sucede o conteúdo. Meta integral F9 ativa;
este incremento não fecha F9 nem libera F10, master, push ou aceite de produto.

Sol corrigiu o bioma do manifesto a partir do contexto de autoria, mantendo
fallback ruin e recusando pacotes incoerentes sem regravá-los. Bordas em lote
compartilham Session/GUI/AX/CLI, com hash esperado, rollback integral e um undo;
limite 529 derivado de 32 instâncias, 496 transições e uma flag. O inspector
agora tem rolagem e botão para aplicar perfil a todas as peças. Formato/revision
5 mantidos como correção de campo existente. Contrato: f9_ax_authoring.md;
propriedade: f9_ownership.json, pacote map_biome.

Luna: MapBiome15/Native13, Borders93/Native32, GameplayNative52,
Candidate53/Population91/Patrol58/Exchange113 e verify editor_import1/299 PASS.
Source/tests/tools/HEAD ficaram congelados nas execuções; Sol leu o delta,
conferiu os recibos e inspecionou capturas. Supervisão de execução Luna e
consolidação Sol não são auditoria semântica independente.

Terra aplicou forest_rootbank_v1 nas duas instâncias do Bosque pelo editor AX:
4/4 ações e reabertura 2/2, compile antes de save, hashes coincidentes, logs
limpos. Somente borders mudou: dois snapshots, poses, vínculo e 47 props intactos.
Fonte data/map_authoring/sanctuary_woods.map.json, 45.615 bytes:
- arquivo 8e3f1c3c47709d204eeaf3061e3d98beabb0dfa987ed09ff24ad2ec79e6a631f;
- fonte 8a9051f8a416a58890365e1b262cea309053ff52c5ce20725d0598ef7875ed55;
- pacote 098aa6b630015504ec47abfa45257fb0c7b571efabad590016dcc34acfc71fdc.

Após sync/import completo, ForestConsumer12 PASS do arquivo final: runtime
forest, 35 spans florestais sem legado, 84 apoios/131 conexões e corpo canônico
raio20/altura32 com acesso a cada apoio. Marcador autorado [160,0,640] preservado
e comporta o corpo; entrada de preview somente de mapa continua provisória.
A prova não registrou a posição efetiva desse spawn nem escolheu o marcador.
Sem App/caminhada/combate/oclusão/restart/FPS do Bosque nesta fatia.

Uma amostra: mapa28,516s (navegação26,275s), preparo30,441s (navegação24,581s);
autoria AX compilou39,375s. São custos canônicos reais, não apenas sobrecarga
de testes. Responsividade in-game continua pendência F9-10; não inferir FPS.

Auditorias: completion2045 entradas, Context2039 (menos6imports de props);
10imports conferidos à parte. Novo consumidor2046 inclui o backup local do mapa;
sync/import2040 exclui os6imports. Zero diferenças source/fixture/manifest.
HEAD de validação4e; conteúdo com bytes idênticos integrado em86359e3d.
Consolidação: evidence/f9/author/map_biome/consolidation.md.
Recibos: evidence/f9/luna/map_biome e evidence/f9/terra/area_forest_borders.

Fixture única --path:
C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5/.godot/verification/e07_f1/fixture_project.
Engine:
C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe.
SHA256 AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424.
Perfil descartável dentro da fixture. Não usar checkout como --path; SkipImport
não sincroniza o projeto inteiro. Nenhum engine/handle ativo; fixture liberada.
Dois backups de peças e novo .map.json.bak locais preservados, fora do Git.
Tentativa Context com caminho relativo literalF1 foi inválida/interrompida;
cópia preservada em .godot/verification/f9_invalid_literalF1_20261029.
CLI de workflow e WORKFLOW_TOOLING.md ausentes nesta worktree; não adivinhar
instalação nem copiar tooling externo. Playtest/save pessoal intactos.

Próximo autorizado: parametrizar população/patrulha no mesmo fluxo UI/AX/Session/
Store e Terra criar os encontros/objetivo pelo AX; medir e corrigir custos reais
dos produtores/rotas antes do candidato final. Continuam integrais: síntese/
regeneração regional, proteção/reconciliação, assets/bundles/ambiente limpo/
export/release, cancelamento/cache/recuperação e UX final, gameplay real do
Bosque, medição representativa in-game e toda matriz F9. M3Native24 histórico
precisa migrar ou sair do tooling com cobertura atual preservada; sua falha
anterior não conta como PASS. Nada transferido a F10.

Blocos abaixo são históricos; este cabeçalho prevalece para a retomada.
<!-- /f9-checkpoint26-history -->


## Vigente28/10 — emenda corrigida e retomada13 PASS

Código58350cab28da7053eba9151d448911abd5b32a5c; tudo executado na fixture única.
SurfacePick24, Geometry46, Ports92, Native20, Resume13 e2 oficiais isolados PASS.
Sol conferiu2016inputs por etapa, zero diferenças source/fixture/manifest, e viu
captura real. Não há processo/handle ativo. Nova sessão d82baa96dfdc98bcf7e74806
andou no alvo original780/780 após processo novo e re-suspendeu em3.589.468B<4MiB.
Os bloqueios anteriores de snapshot e pick foram corrigidos; seus recibos abaixo
são históricos. [Consolidação](evidence/f9/author/surface_pick/consolidation.md).

App.open/início/retomada ainda custam cerca de49s/31s/30s nesta peça e permanecem
pendência10. Uma rotaNative:46ms para pedido,120frames mediana19,2ms/p9529,4ms,
máximo115,9ms; na retomada só2frames, sem percentis úteis ou FPS geral.
RestanteF9 continua integralmente exigido. Próximo é implementar
[AX parametrizado](../contracts/f9_ax_authoring.md), depois Terra criar o Bosque
pelo editorAX. Síntese/reconciliação/assets/intercâmbio/release/recuperação e área
final não estão fechados. F10 separado; nenhum main/playtest/push/aceite implícito.

Luna executou todas as etapas antes de falhar por limite de uso, sem relatório
final; Sol consolidou a evidência. Terra também foi limitado ao tentar refinar
seu desenho, sem nova alteração ou mapa criado. Não reiniciar testes finalizados.
Código pode avançar porSol; próximos pacotesLuna/Terra retomam quando disponíveis.


## Vigente28/10 — snapshot resolvido; clique de emenda em correção

Código44a0b36439de030ab48a64aff2a26adc856fbadd, testes fac5db2f228d1f5bf11cf31a17e0b89709e730d8.
Encoding exato: checkpoint real3.594.152B dentro dos4MiB préDEFLATE, sem reduzir
colina/corpo/estado. Density33, Native20 e4oficiais(2923checks) PASS. Colina iniciou
no jogo e personagem subiu com corpo20x32. Uma rota: pedido44,128ms;120frames
mediana17,421/p9527,479/máximo136,137ms; nenhuma garantia geral deFPS.

Novo processo restaurou candidato/536apoios/828conexões/posição elevada salva,
mas o alvo seguinteXZ780/780 retorna ambiguous_surface. ResumeFAIL7/9emitidos,
13esperados; não declarar continuidade completa. Próximo: coletarhits e corrigir
WorldGeometry.resolve_surface na emenda, preservando ambiguidades legítimas,
oclusão e pisos. Não deslocar teste nem relaxartolerância. Novo runtime exige
recriar sessãoNative antesdeResume; não adulterar sourcehash do checkpoint antigo.

[Conferência Sol](evidence/f9/author/snapshot_encoding/consolidation.md) e
[relatório Luna](evidence/f9/luna/snapshot_encoding/report.md). Engine/fixture única
preservados;2014inputs atuais source=fixture, sem processos/handles ativos.
Playtest/save pessoal intactos. RestanteF9 ainda exigido: AX parametrizado,
síntese/regeneração/reconciliação, intercâmbio/asset/release/recuperação/fluidez,
mapaTerra noeditorAX e área final. F10 continua separado. Os blocos de snapshot
falho anteriores são históricos e substituídos por este estado vigente.


## Vigente28/10 — T01 integrado, gameplay bloqueado

Meta continua TODO F9 e mapa para testar. Sol código; Terra mapas via editorAX;
Luna testes. [Desenho do Bosque](f9_area_design.md) está pronto, ainda não autorado.
Código diagnóstico82cc23d17eb472f1bc21bdab0591678d4a2c2f4a, branchcodex/map-editor-f9 no mesmo
checkout .tools/map-editor-m5. Aplicação T01 de5e6f6cc; modelo19 PASS em57ffdc2;
provaGUI/menu/AX/undo/relevo nativo passou em82cc23d, mas a etapaNative FALHA:
App.start snapshot_too_large,13/14 checks PASS (20 esperados). Sem caminhada,
picking ou captura gameplay; não declarar T01 jogável nem F9-02/12 concluídos.
Diagnóstico: snapshot10.308.936B >4.194.304B,22.405 containers,634 objetos;
estágio geométrico bruto1.024.396B/536 apoios/828 conexões. Detalhes e próxima
correção no [contrato de densidade](../contracts/f9_snapshot_density.md).
Engine4.7.2 e fixture única preservadas; logs completos rounded_hill/. Não elevar
caps, reduzir33x33/220/420 ou corpo20/32. AX parametrizado ainda falta;
[próxima fatia](../contracts/f9_ax_authoring.md) prepara sua autoridade real.
Luna concluiu biblioteca/oficiais no congelamento0b2d57a; fixture liberada.
Consultar a consolidação no fim deste documento para resultados e hashes. TesteSnapshotDensity ainda rascunho
ignorado, sem UID/import/teste. Não reaplicar propostaTerra antiga nem iniciarF10.


Atualização27/10/2026. Este documento permite continuar em outro modelo/provedor,
sem depender do histórico do chat ou das ferramentas internas do Codex.
Estado: F9 EM EXECUÇÃO; não entregue integralmente e sem aceite de produto.

## O que o usuário autorizou e prioriza

“F8 terminou. Podemos começar F9.” F9 deve fechar todos os pendentes do editor,
conforme seu contrato, sem empurrá-los para F10. Adendo: sombras e acabamento que
melhorem a imersão, aproveitando a engine existente. Nenhum épico E08+ foi aberto.

Em27/10 o usuário esclareceu: duração dos testes não importa por si só. Importam
performance durante o jogo, modo AX que facilite o desenvolvimento agêntico e
mapas robustos consumidos pelo jogo. Não otimizar cronômetro de suíte como meta,
reduzir cobertura ou alterar amostra/corpo/oráculo para aparentar velocidade.
Se a rotina medida também roda no jogo, registrar perfil/escala/fase e comprovar
impacto em gameplay representativo; o tempo de um teste não é FPS.

O usuário prefere incrementos e resumos portáteis para poder trocar de modelo.
Não presumir nem aguardar um reset de cota. Os papéis podem ser assumidos pelos
executores que ele escolher: Terra6.1 implementa fatias pequenas/médias completas;
Sol decompõe, analisa, integra e trata complexidade transversal; Luna pode criar
os testes e gerenciar execução/triagem separadamente. Revisão ampla com Astra só
após terminar o editor, por iniciativa humana. Não criar chats/experimentos por
inferência. O anexo de workflow é referência, não uma ordem para abrir benchmarks.

## Localização, base e preservação

- Checkout de trabalho: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
- Branch: `codex/map-editor-f9`.
- Runtime testado neste incremento: `4642dbf878fab4004f98141c7e2437ee11e22bd5`.
- Principal/playtest: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG`.
  Possui trabalho/imports/exports/save pessoais; NÃO usar como cwd de implementação.
- Engine: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`.
- Engine SHA256: `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Única fixture: `<checkout>/.godot/verification/e07_f1/fixture_project`.
  Reutilizar sequencialmente; sem terceiro checkout/projeto.

Usar SEMPRE o checkout explícito. Não resetar/limpar arquivos do usuário. Não
commitar .godot/.tools/builds. Sem push automático. Merge em master depende de
aceite humano explícito do candidato testado. Um PASS técnico não autoriza produto.
Não encerrar F9 ou iniciar F10 por ter terminado uma fatia.

Este checkpoint documental consolida as mudanças feitas enquanto o runtime estava
congelado; o congelamento foi LIBERADO após conclusão Luna. Seu commit é posterior
ao runtime4642dbf e não representa outra execução de testes. Inclui:
`docs/WORKFLOW.md`, `docs/map_editor/contracts/f9_ownership.json`,
`docs/map_editor/contracts/f9_terra_work_packages.md`,
`docs/map_editor/delivery/f9_resume.md` e este handoff; além do empacotamento da
proposta Terra e recibos novos de Luna. Conferir Git de novo para identificar o commit documental e deltas posteriores. Não tratar essas mudanças como lixo do worktree.

## Fontes contratuais antes de editar

Na raiz do checkout: AGENTS.md, docs/WORKFLOW.md (norma única atualizada),
docs/REVIEW_WORK_PACKAGES.md, docs/MVP.md e docs/ARCHITECTURE.md.
Depois: docs/map_editor/contracts/f9_completion.md, f9_ownership.json,
docs/map_editor/f9_requirements.md e docs/map_editor/delivery/f9.md.
Para a próxima fatia: f9_terra_work_packages.md e terrain_piece_semantics.md.
Para síntese futura: f9_regional_synthesis.md. Para a correção atual de navegação:
f9_navigation_performance.md. Todos os nomes de contratos acima ficam em
`docs/map_editor/contracts/`.

CLI de workflow e WORKFLOW_TOOLING estavam ausentes nesta base. Não adivinhar
instalação nem copiar tooling externo. A retomada foi diagnosticada com Git,
project.godot, contratos e recibos. Godot4.7.2 standard, GDScript tipado, UI pt-BR,
IDs/código inglês; sem plugin externo. Catálogo imutável, estado separado da run.

## O que existe e foi comprovado por componente

Sombras suaves de contato para atores/props; oclusão/ordem por cotas; materiais,
biomas/bordas; biblioteca/presets/favoritos; minimapa/overlays; prévia jogável real
em perfil descartável com restart/continuidade e comandos GUI/AX/CLI. Renderer
compartilhado entre editor e runtime. Campos Fire/Lightning/Phantom/Ice seguem
apoios e ordenação reais. Não generalizar isso para “toda a apresentação pronta”.
O recibo F9 distingue autoria, supervisão e pendência de cada componente.

Último código, checkpoint19: lote ALL_DIRECT compartilha prova privada de rotas
já aceitas pela autoridade, mantendo endpoints exatos, ida/volta independentes,
orçamentos e validação pública. Gauss17/512 original passou publicação no orçamento
original, corpo20/32 e1024 testemunhas públicas/movimento autorais. Pico105254480
unidades contabilizadas contra268435456; não é medição de heap/RSS. Publicação33,8s
e preparo do corpo43,5s são fases de preparação, não tempos por frame.

Consulta individual conserva Dijkstra/heap/relaxaçãoEPS/custos/desempate, completa
superfícies sob demanda, usa preparação privada e seleção conservadora de sólidos.
No cenário denso HISTÓRICO de perfil2/12: eager160389ms, preparado100731ms, mesmo
resultado integral/digest nas duas rotas, mesmos8683 estados expandidos/524360
testes no desvio. Não é o perfil do jogador20/32, nem prova de FPS ou mapa final.
Essa API também é usada pelo runtime: verificar o impacto real em jogo antes de
considerar a prioridade de performance cumprida. Não ignorar um travamento só
porque foi descoberto por teste; não otimizar a suíte por si só.

Provas autorais finais: Context11, Lazy24, Geometry46, Ports92, Batch36, Dense5
preparado e Dense5 eager. Sete recibos com2002 inputs cada,14014 sem divergência;
fixture igual, project.godot somente com VCS desativado. Organic15 é anterior:
4 inputs mudaram e7 testes/UIDs foram adicionados; compatibilidade foi documentada,
sem fingir nova execução de1024 testemunhas no hash atual.
Auditoria: `docs/map_editor/delivery/evidence/f9/author/navigation_audit.json`.
Falhas e tentativas anteriores permanecem; não apagá-las nem atribuir-lhes PASS.

## Validação concluída e reprodução

Caminho: `docs/map_editor/delivery/evidence/f9/luna/navigation_and_fields/`.
Luna concluiu no runtime4642dbf: Core8/639; FieldsNative73; GameplayNative52;
GameplayControls29;12/12 etapas oficiais/3649 checks. Tudo PASS, sem falha, timeout,
parse/script error ou exit não zero. HEAD antes/depois igual. Fonte/fixture:
14014 hashes autorais de cada lado e9998 referências atuais sem divergência.

Relatório `report.md`, SHA256
`EEB082D4CFDF3AF23A86009049773A07F5294DC797DCC7D81C01C0F68A2FF8F5`.
Os recibos autorais preservam seu HEAD f21709ae e inputs; não foram reatribuídos.
Não repetir etapas concluídas com os mesmos inputs apenas por trocar de modelo.
A supervisão não é auditoria semântica independente, FPS ou aceite de produto.

Fixture LIBERADA para a próxima tarefa autorizada. Em nova retomada, conferir se
outro trabalho começou depois deste arquivo. Nunca executar dois runners na mesma
fixture nem encerrar PID opaco/jogo pessoal. Não tocar o principal/playtest.
Os comandos abaixo são referência de reprodução; rodar novamente só por impacto
de novo delta, falha ou evidência insuficiente. Nenhuma dependência de Codex é
necessária para executá-los em PowerShell comum.

Roteiro reproduzível em PowerShell comum (substituir só nomes de evidência por
pastas novas ausentes; não reutilizar/sobrescrever recibos):

```powershell
$f9Root = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5'
$f9Engine = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe'
Set-Location -LiteralPath $f9Root
 git rev-parse --show-toplevel
 git rev-parse HEAD
 git status --short
```

Para uma reprodução justificada dos nativos, sem execução concorrente, usar
`tools/map_editor_completion/run.ps1 -GodotPath $f9Engine -Stage FieldsNative
-EvidenceDirectory <nova pasta absoluta>` com importação normal; depois
GameplayNative e GameplayControls, cada qual com sua pasta nova. `-SkipImport`
só quando source/fixture já importadas e conferidas idênticas. Não é sync geral:
esse modo copia apenas quatro arquivos legados.

A seleção oficial concluída usou `tools/verify.ps1 -GodotPath $f9Engine -F1Fixture
-SkipEditorImport -CheckTimeoutSeconds 300 -VerificationDirectory <nova pasta>
-Test @(...)`, com estes12 IDs exatos:

```text
e07_f1_geometry_test
e07_f1_actor_integration_test
e07_f1_adversarial_test
e07_f1_consumer_test
e07_f1_guard_travel_test
e07_f1_fields_test
e07_f1_ice_test
e07_f1_geometer_trace_test
e07_f1_geometer_full_test
e07_f1_non_planar_test
e07_f1_composition_test
e07_f1_presentation_test
```

Durante verificação, APPDATA e LOCALAPPDATA devem apontar para o perfil descartável
`<fixture>/.godot/discardable_profile`, restaurados por try/finally. Não usar save
pessoal. Ignorar somente linhas vazias em checks.jsonl. SCRIPT ERROR, Parse Error,
ERROR, timeout, contagem incompleta ou input divergente impedem PASS mesmo com exit0.
Se falhar, preservar logs e corrigir causa; não mudar expectativa para escondê-la.
Registrar hashes/HEAD antes/depois e escopo realmente executado. A etapa de teste
pode demorar: não é motivo para enfraquecer a validação.

## Integração atual — F9-T01

Atualização posterior ao checkpoint91dfa48: usuário autorizou a integração.
Terra já aplicou os cinco arquivos reais permitidos, preservando a ordem dos três
presets antigos e acrescentando o quarto. Código ainda não importado/compilado/
testado nesta fatia. Luna prepara dois testes novos e atualização legítima da
biblioteca. Existem mudanças de aplicação e documentos na árvore; conferir Git
antes de aplicar novamente o patch (NÃO reaplicar cegamente). Ownership/contrato
foram atualizados. Aguardar testes prontos, importação/UIDs e congelamento para a
execução coordenada na fixture única. Não há teste em execução até esse ponto.

### Proveniência da proposta inicial (agora aplicada, sem validação ainda)

Terra6.1 entregou rascunho de cinco arquivos; NÃO integrado, compilado, testado ou
aprovado visualmente. A revisão inicial de Sol conferiu localização, preservação
do candidato e que o patch se aplica sem conflito, sem aplicá-lo.

Cópia portátil em
`docs/map_editor/delivery/evidence/f9/author/terra_organic_proposal_01/`:
`manifest.json` com SHA-base/proposto; `delivery.md`; cinco cópias `.gd.txt`; e
`proposal.patch`. Esse pacote não depende da pasta ignorada original
`.godot/f9_shadow_draft/terra_organic/`. Não importar/executar esses textos como
código antes de revisar, conferir que a fixture continua livre e transferir propriedade.

Alvos: terrain/brush.gd, terrain/terrain_panel.gd, terrain/organic_example.gd novo,
library/editor_preferences.gd e library/library_model.gd, sob scripts/map_authoring.
Novo modo rounded_hill com peso(1-u²)^3 e preset; exemplo uma camada33x33/passo50,
domínio1600, centro800/800, raio420, altura220 em DOIS traços110 sem aumentar força
máxima128. Pinta caminho curvo pelo Brush existente. GUI/AX compartilham operação;
aplica uma vez pela Session/undo e recusa documento ocupado. Sem novo shader,
asset obrigatório, schema/compilador/física ou construção manual de polígonos.

Congelamento liberado: conferir SHA-base no manifesto, registrar dono
nominal das fontes/novo .uid, revisar o patch e integrar sem sobrepor mudanças
concorrentes. Gerar/copiar somente UID autorizado pela fixture. Luna cria testes
fechados da fatia, Terra corrige falhas locais e Sol confere cobertura/integração.
A especificação está em delivery.md: perfil/centro/proteções/stroke/preset, conteúdo
ocupado, undo, equivalência GUI/AX, compilação real, apoio/clique/navegação e inspeção
nativa. Não chamar proposta de entrega runtime nem encerrar F9-02/12 só por isso.

## Restante obrigatório e limitações concretas

A matriz F9-01–12 e o contrato continuam íntegros. Ainda falta acabamento orgânico
integrado/humano; síntese regional por seed com máscaras e conservação de entidades;
AX/CLI e UX completos; encontros/reconciliação; bundle/dependências em ambiente
limpo; recuperação/cancelamento; responsividade de gameplay/preparação acionável;
apresentação restante, export release/continuidade e área temática final completa.

Não esquecer: algumas mortes/VFX vinculados ao mundo ainda usam caminhos legados
ou suprimidos; sync de atores pode tornar morto visível de novo. Transações de
checkpoint medidas em8–15s e preparação corporal43s precisam ser avaliadas por
seu efeito perceptível, com feedback/cancelamento e sem travar a partida. São
pendências, não prova de defeito em todo mapa ou autorização de nova mecânica.

Geração regional tem contrato em f9_regional_synthesis.md: proposta sobre a raiz
inteira piece/map/population/patrol, máscara compartilhada, preservação por
influência geométrica/footprint/segmento e clone de peça por instância. Reconciliar
referências sem escolher piso global mais próximo. Receita passiva não executa
na importação. Contrato ainda não entrega consumidores; particionar antes de delegar.

## Próximo incremento e regra de encerramento

1. Conferir o relatório Luna concluído e o Git atual, sem repetir testes sem motivo.
2. Preservar o checkpoint documental e a referência ao runtime4642dbf testado.
3. Transferir propriedade, integrar/verificar F9-T01 e medir o resultado no jogo.
4. Continuar a matriz com fatias delimitadas, sem redefinir falta como opcional.
5. A cada incremento atualizar resumo, base/hash, arquivos, verificações e pendências.

Nenhuma autodeclaração de modelo substitui aceitação verificável. Se um item não
foi implementado ou não foi validado, registrar precisamente e continuar quando
possível. Não inventar PASS, completude, benchmark ou cronograma de reset.


## Meta ativa28/10 e congelamento T01

A meta humana agora é entregar todo o restante de F9 e um mapa para testar.
Sol assume código; Terra cria mapas exclusivamente via editor AX; Luna cria e
supervisiona testes. O limite anterior de mais uma integração foi substituído
pela meta explícita. F10 e aceite/merge humano continuam separados.
T01 importado com Godot4.7.2, sem Script/Parse/ERROR. UID do módulo gerado pela
engine; sidecars dos testes preparados por Luna e aceitos na importação.
Inputs serão congelados no commit desta integração, antes dos testes dirigidos.
Ainda não declarar PASS de modelo/nativo nem conclusão de F9-02/12.


### Consolidação vigente28/10 — lote encerrado, correção estrutural pendente

Último código congelado0b2d57a39a55c84ae2b3380714830f41440c6ce5; o SHA atual de
Git pode ser checkpoint documental posterior. Model19, Library50 e LibraryNative53
PASS; tools/verify selecionou snapshotF3(50), geometriaF1(33) e atorF1(193), todos
PASS, sem erro/timeout. [Relatório Luna](evidence/f9/luna/rounded_hill/report.md)
e [conferência Sol](evidence/f9/author/rounded_hill_consolidation.md). Rehash Sol
confirma fonte/fixture atuais sem divergência nos2008 inputs de cada manifesto;
reuso histórico tem deltas explícitos na conferência. Nenhum processo ativo;
fixture liberada. Não repetir este lote por hábito antes de uma mudança nova.

Runtime T01 ainda não jogável: NativeFAIL snapshot10.308.936B >4MiB antes de
picking/caminhada. Resolver encoding exato do grafo com caps/identidade/ciclos/tipos,
provar roundtrip/continuidade e a mesma App33x33/20x32 antes de consumidores.
Rascunho de17 testes preservado como texto inerte em
[evidência portátil](evidence/f9/author/snapshot_density_draft_01.gd.txt); não rodado.
Depois completar AX parametrizado, autoria Terra do Bosque e TODOS os pendentes
F9-01–12. F10 depende de conclusão e autorização própria; não transferir faltas.
