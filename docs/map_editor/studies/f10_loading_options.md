# F10 Q5 — opções para reduzir carregamento

5/11/2026. Pedido humano: analisar pré-compilação, caching, binários maiores,
concorrência e outras alternativas. Base `8c38ea8fd5a15189aece64a9e814d176a3848d58`,
código de produto `d5452650`, worktree `.tools/map-editor-m5`, branch
`codex/map-editor-f10`. É um estudo com sonda isolada, não implementação de
loader, mudança de contrato de save, abertura de marco ou aprovação global Q5.
Fontes e quatro backups preservados. Fluxo: [WORKFLOW](../../WORKFLOW.md);
base e limites: [checkpoint16](../delivery/f10.md).

Código inspecionado: [Store](../../../scripts/map_authoring/patrol/patrol_store.gd),
[validador](../../../scripts/map_authoring/patrol/patrol_compiler.gd),
[planejador](../../../scripts/core/expedition/population/population_planner.gd),
[batch geométrico](../../../scripts/core/expedition/spatial/world_connectivity_batch.gd),
[preparação](../../../scripts/map_authoring/preview/gameplay_candidate.gd),
[serviço](../../../scripts/core/expedition/expedition_service.gd) e
[snapshots](../../../scripts/core/expedition/snapshot/snapshot_registry.gd).

## Conclusão e ordem recomendada

**Pré-calcular caminhos verificáveis é a melhor primeira frente.** O formato
dos mapas já é binário e compilado; o custo dominante é refazer a descoberta
de caminhos ao carregar. A sonda abaixo confirma que conferir caminhos
conhecidos pode ser muito mais barato. Depois, atacar reconstruções duplicadas
na retomada e recursos visuais estáticos. Dois mapas em paralelo são uma opção
complementar, com limite mensurável e cuidados de memória/compartilhamento.

O primeiro consumidor precisa cobrir **todas** as consultas de preparação.
Evitar só a busca dentro de `load_package` pode deslocar os mesmos 115 s para
`Candidate.prepare`, que hoje depende dos fechamentos aquecidos pelo loader.
O estudo não anuncia um carregamento completo de poucos segundos.

## O que os dados existentes permitem afirmar

- Release autorado mais recente: entrada 171,07 s; suspensão 7,02 s; retomada
  26,57 s; pico residente amostrado 1.092.640.768 B. ForestPlay anterior:
  entrada 203,45 s, intervalo final síncrono 26,68 s, portal 38,29 s.
- Preparação histórica isolada: 178,986 s, com mapas de 133,851/36,855/8,173 s.
  Os processos e fronteiras são diferentes; não subtrair 178,986 de 171,07.
- No primeiro campo, a admissão fria gasta cerca de 114–116 s. O perfil atual
  testa 173.648 ligações, constrói 13.387 estados e verifica depois os caminhos
  usados. A descoberta domina o custo, não o transporte de poucos megabytes.
- Os três RPP já somam 8.872.196 B: Terraços 4.385.144, Vales 4.006.948,
  Covil 480.104. Transporte: `RPP1` + SHA256 textual do payload + `var_to_bytes`.
  `patrol_store.gd:56` usa `bytes_to_var`, sem objetos executáveis, e chama
  `PatrolCompiler.validate_package`. Não lê JSON de autoria para jogar.
- Os caches existentes são de processo: oito provas de pacote, 32 admissões
  booleanas e três fechamentos de grafo. Aumentar sua capacidade pode ajudar
  revisitas, mas não cria um acerto na primeira abertura de um processo novo.

## Sonda: caminhos compactos verificados a frio

[Artefatos, script e hashes](../delivery/evidence/f10/reviewer/loading_study_2026_11_05/).
Godot 4.7.2 standard, engine SHA256
`AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
Mesmo computador do checkpoint16; processos headless separados, uma fixture,
perfil descartável e nenhuma fonte de runtime alterada. Uma execução por etapa.
“Frio” significa processo e caches geométricos novos; não cache de disco do SO
esvaziado. O renderer não participou deste experimento.

O coletor carregou `forest_terraces` pela API normal, que validou o pacote
integralmente. Obteve outro certificado pela autoridade existente com o
fechamento já aquecido e guardou apenas os nós/predecessores/via necessários
aos caminhos de 62 homes, em ambos os sentidos. Nenhum booleano de predicado
geométrico foi guardado como autoridade da prova compacta.

| Medida | Resultado |
| --- | --- |
| Loader público frio, coletor | 121.057,190 ms |
| Navegação fria dentro desse loader | 115.214,864 ms |
| Certificado adicional, depois do loader quente | 1.750,080 ms |
| Certificado completo serializado | 20.157.888 B |
| Prova compacta, arquivo real lido pelo verificador | **308.100 B** |
| Mesmos bytes comprimidos em memória com Zstd | **20.633 B**, somente tamanho medido |
| Nós retidos / predecessores de ida / volta | 220 / 215 / 213 |
| Leitura de prova/RPP e conferência do frame | 87,406 ms |
| `Population.validate_package`, processo novo | 3.512,202 ms |
| Configuração do mundo novo | 227,791 ms |
| Verificação geométrica fria dos caminhos | **892,435 ms** |
| Soma dos quatro blocos anteriores | 4.719,834 ms; não é o loader completo |
| Processo verificador inteiro, inclusive inicialização e controles negativos | 11.487,402 ms |

Antes de verificar: zero lattices construídos, `_grid_cache` vazio e
`_navigation_shared` vazio. O verificador usou raiz, homes e perfil atuais,
`route_valid`, `_tree_valid`, memos vazios, reserva de armazenamento e checagem
final da revisão. Contou 1.148 visitas a pontos e 719 a segmentos, com
reutilização de predicados; esses números não são contagens de entidades únicas.
Predecessor removido, intermediário deslocado para fora do chão e conexões
fechadas foram recusados. Ambos os processos terminaram com saída 0, sem erro
de script ou timeout. Revisão somente leitura do script/resultados não encontrou
erro bloqueante no caso conhecido.

O custo extra deste recorte é cerca de 7,03% do RPP de Terraços sem compressão,
ou 0,47% considerando apenas o tamanho Zstd. A prova de **toda a preparação**
terá mais destinos e pode ser maior. O caminho comprimido e seu tempo de
descompressão não foram medidos. Pico residente do coletor 664.870.912 B e do
verificador 370.470.912 B são processos com tarefas diferentes; não comprovam
queda de memória do jogo. A contabilidade conservadora da verificação foi
6.650.368 B, que também não equivale a RSS.

### Limites obrigatórios deste resultado

O verificador privado não é um loader de produção: o vínculo ao pacote depende
da coleta congelada/recibo externo, e os decoders da sonda não têm tetos/shape
suficientes para receber arquivos arbitrários. O hash vindo do próprio arquivo
de prova não estabelece confiança. Não se reaproveita esse mecanismo como API.

O tempo exclui os demais checks de patrulha e por vaga de população
(ocorrência, regras de XP/respawn, witness e políticas), preparação da fase,
snapshot, apresentação e instalação do perfil. A montagem das expectativas e
os controles negativos também não estão individualizados nos quatro blocos.
Não representa “171 s → 4,72 s”, nem um multiplicador de velocidade do jogo.
Não foi repetida a suíte de gameplay; foram executados somente estes dois
processos diagnósticos sobre dados conhecidos.

## Pré-compilação e cache propostos

Hoje `population_compiler.gd:417` guarda `{"point":home}` como witness, sem a
rota. A busca gera as árvores e as descarta como publicação. Um arquivo
auxiliar passivo pode conservar apenas os caminhos positivos. Preferir isso
a serializar o grafo completo de 20 MB ou guardar `ok:true` sem prova.

A publicação/export executaria a autoridade atual, escreveria os caminhos e
fixaria formato/revisão e dependências. O consumo continuaria validando o RPP,
catálogo, políticas, corpos e endpoints; construiria um mundo novo; verificaria
geometria e só então produziria recibos privados de acesso para as consultas
cobertas. Arquivo ausente, incompatível ou inválido volta à busca normal.
Prova inválida não demonstra que o mapa é inacessível.

Chaves/invalidação: hash do pacote exato, revisão do formato/algoritmo e build
da autoridade, geometria/lajes completas, perfil corporal completo, entrada e
destinos exatos. Catálogo/políticas/dependências continuam atuais. Só o nome
do estágio pode ser normalizado como na admissão existente; posições, sentidos,
corpo e colisão não podem ser aproximados.

Não carregar `configuration_revision` efêmera, memos booleanos, mundo, slots,
atores, ocupação, RNG ou recompensas de outro processo. A prova deve ser dado
semântico, não um dump do certificado atual. O arquivo auxiliar evita alterar
o RPP estrito, os oito campos do registro e o save, mas exige resolução por
revisão, export explícito, limite de bytes/descompressão, decoder sem objetos,
gravação atômica e fallback testado. Nada disso foi implementado no produto.

### Cobertura mínima para o ganho chegar ao jogador

| Consumidor atual | O que precisa continuar provado |
| --- | --- |
| `PatrolCompiler.validate_package:90` → `Planner.build` | homes com o corpo real; admissão pede ida, além dos checks atuais de espécie/regra/apoio/witness |
| `Candidate.prepare:85` | ponto walkable de cada superfície com o corpo do jogador, ida e volta |
| `Candidate.prepare:95–98` e `_round_trips:150` | objetivos e ambas as âncoras de portais, ida e volta |
| `Candidate.prepare:102–128` | admissão por perfil de mob, homes ida/volta e patrulhas com seu leash/custo próprios |
| `ExpeditionCampaignState.create:26` | admissão após composição/renomeação dos estágios, com regras e mundos novos |

Uma prova só de homes, como a sonda, **não cobre tudo isso**. Se o primeiro
batch de superfícies continuar sem prova/cache após evitar o loader caro, ele
recria `_closure_base` e pode pagar novamente a busca inteira. O protótipo de
produto deve provar cobertura de todos esses consumidores e medir a entrada
completa, incluindo chamada após a composição. Testemunhos de existência não
substituem menor caminho, rota de movimento ou verificação de leash.

Não preencher `_closures` com uma árvore parcial apresentada como fechamento
completo. Uma união de destinos pode compartilhar árvores, mas cada pedido
precisa conferir cobertura, sentido, duplicatas e ordem. A autoridade de
admissão deve registrar o acerto positivo verificado sob a identidade
normalizada; assim a criação da campanha não volta à descoberta fria.
As três fontes da floresta têm zero patrulhas; para esse primeiro corpus,
preservar o validador de patrulha existente é suficiente.

A busca atual também aquece lattices de terreno. A sonda de prova deixou esses
caches zerados: parte desse trabalho pode reaparecer no primeiro movimento ou
na AI. A aceitação deve acompanhar os primeiros segundos de caminhada/combate,
não apenas o desaparecimento da tela de carga. Registrar fallbacks e criação
de closures/lattices por etapa; eventualmente pré-aquecer derivados estáticos
em trabalho limitado, sem voltar à exploração completa nem transferir a pausa
para o primeiro quadro jogável. Exercitar uma rota com desvio por terreno
íngreme e passagem por emenda/conector a partir de lattices frios, além de
movimento simples: só observar alguns segundos pode não disparar o custo adiado.

Para mapas publicados, gerar junto ao build permite ganho já na primeira
abertura. Para conteúdo editado/seed inédita, a primeira geração continua
executando a autoridade; depois pode armazenar provas revalidáveis em cache
descartável, separado do save. Aumentar somente o cache em RAM não resolve o
caso frio. O cache do compilador de autoria existente não deve virar
automaticamente autoridade do runtime.

## Concorrência: ganho complementar e fronteiras

`PhaseSelectionPanel.start:102` já usa uma thread para preparar a fase;
`PhaseRelease.prepare:56` percorre os mapas em sequência. Com a decomposição
histórica 133,851/36,855/8,173 s, o limite ideal é aproximadamente 133,96 s,
incluindo o restante da preparação: cerca de 25% menos que 178,986 s, sem
overhead. **Dois workers já atingem esse limite ideal de três**, pois os dois
mapas menores cabem atrás de Terraços. Não é previsão do release de 171 s;
depois de bake/cache, a distribuição muda e o limite deve ser recalculado.

Não basta substituir o laço por tarefas: `BuildContentLoader._catalog_cache`
e `ProfileCatalog._default_pilot` têm inicialização/publicação sem mutex.
`WorldGeometry._ensure_support_index`, `_navigation_shared_memo` e
`_navigation_memo_put` alteram dicionários sem sincronização. Isolar mundos e
memos por trabalho, preparar dependências imutáveis com um produtor e reunir
resultados na ordem original. Falhas simultâneas preservam a primeira falha
autorada. Cache protegido pode ainda construir o mesmo miss duas vezes.

As buscas de ida/volta de Terraços consumiram 42,91/47,33 s após 21,91 s de
construção. Dividi-las tem teto ideal de economia de 42,91 s naquele bloco,
mas exige contextos e memos privados, com orçamento agregado da operação.
Orçamentos independentes por worker não podem multiplicar o teto de memória.
É mais arriscado
e pode ser desnecessário para carga de mapas depois das provas pré-calculadas.
Não há 62 trabalhos independentes: os 62 homes da amostra usam um perfil.

Mais tarefas sobrepõem mundos e temporários; 160,7 MB da contabilidade de
navegação e 1,09 GB de RSS do release não permitem calcular pico paralelo por
multiplicação simples. O pool de gameplay já existe, mas o batch de admissão
é síncrono e não usa `NavigationServer`. Aumentar threads desse servidor ou
ligar `navigation_async` não divide essa busca automaticamente.

Para o bake, processos headless isolados podem ser úteis: permitem paralelizar
produção com catálogos privados e devolver só dados. No jogador, somam
inicialização, IPC e memória, portanto não são a primeira opção de carga.
As APIs oficiais exigem cuidado com árvore ativa, Resources compartilhados e
redimensionamento de containers; o pool distribui tarefas que o código
delimitar, não torna a autoridade automaticamente paralela.
[Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html),
[WorkerThreadPool](https://docs.godotengine.org/en/stable/classes/class_workerthreadpool.html).

## Retomada, portais e apresentação: outra frente

A retomada não chama `PhaseRelease.prepare`; um cache de admissão não elimina
automaticamente seus 26,57 s. Em `ExpeditionService.resume:135–138`, o serviço
reconstrói e valida um mundo passivo e o libera. Depois do commit,
`_publish:225–226` restaura novamente. Campanhas já conservam um staged inerte
até confirmação (`:204`), e `_discard_staged:325` conhece seu descarte.
Uma retomada com um único staged validado é uma hipótese delimitada, a medir
com falha definitiva/incerta, reconcile, retry, replay de diário e autoridade.

`CheckpointCodec.unpack` valida e devolve o snapshot; `_restore` altera a
autoridade; `SnapshotRegistry.restore:714` valida/encoda novamente. Pode haver
economia propagando um recibo interno com rebind controlado. Não aceitar
encoding antigo depois de mudar autoridade nem um Dictionary que se declare
validado. `SnapshotRegistry.capture:189` também serializa o envelope só para
`logical_bytes`, usado em diagnóstico/teste, antes da encoding real. Medir
separadamente permite retirar esse custo do caminho normal sem apagar o
oráculo quando solicitado.

A instalação da vista resolve pacote e reconstrói arrays de terreno,
normais/pesos/UVs/índices, meshes, props e ordenação. Pré-cozinhar ou cachear
arrays/recursos estáticos por pacote + revisão visual/material pode trocar
PCK/RAM por menos CPU em entrada/portal/retomada. Seu custo isolado ainda não
foi medido. Instâncias, geometria viva, sombras e ordenação de atores continuam
novas; não cachear Nodes com referências ao mundo anterior.

Referenciar geometria estática no snapshot é uma opção maior: o envelope bruto
tem cerca de 4,96 MB, incluindo `_stage` e `manifest_data`. Exigiria descriptor
e contrato próprios. Não deduplicar containers por igualdade de conteúdo:
identidade/alias dos mutáveis faz parte da persistência. O contrato atual
preserva duas reconstruções na transação de portal; alterá-lo pede invariantes
de durabilidade/causalidade, não uma troca genérica por trabalho assíncrono.

## Binário, antecipação e alternativas de menor prioridade

| Possibilidade | Avaliação |
| --- | --- |
| Aumentar PCK com caminhos ou dados visuais úteis | Recomendado quando elimina trabalho medido; a sonda quantifica um primeiro recorte de navegação |
| Trocar `script_export_mode=2` por 1 | Já usamos tokens binários comprimidos; sem compressão aumenta arquivos e pode reduzir algum custo inicial, mas não elimina loops de navegação |
| Incorporar PCK no exe | Muda empacotamento; não pré-calcula provas nem torna GDScript código de máquina |
| Shader baker | A configuração é Compatibility/OpenGL; o baker documentado atende Forward+/Mobile, não esse renderer nem a certificação headless |
| Preload/background loading de arte | Pode antecipar I/O e melhorar responsividade; não executa nossa certificação geométrica |
| Preparar no lobby antes do clique | Pode esconder espera quando houver tempo livre, mas usa CPU/RAM e pode preparar uma fase nunca escolhida; não reduz custo frio por si só |
| Preparar só o primeiro mapa | Adia trabalho para portais; a campanha atual compõe todos os estágios/regras/relógios antes da entrada. Streaming visual pode preservar isso, mas geração/admissão tardia exige contrato próprio |
| GDExtension/C++ ou engine custom | Potencial em kernels matemáticos se ainda dominarem depois do bake. Não é efeito do modo binário do export; exige fronteira nativa, build/distribuição e testes diferenciais. Fora da fundação atual standard/GDScript sem plugins |

A documentação 4.7 define os modos de tokens e o embed; não há base para
atribuir os 115 s a descompressão de scripts. Shader baker não atende
Compatibility. `load_threaded_get` pode bloquear se chamado antes de terminar;
logo, mover I/O não resolve por si só a instalação síncrona.
[Export de scripts](https://docs.godotengine.org/en/4.7/classes/class_editorexportpreset.html#class-editorexportpreset-method-get-script-export-mode),
[export Windows](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformwindows.html),
[background loading](https://docs.godotengine.org/en/stable/tutorials/io/background_loading.html).

## Próximo pacote proposto, ainda sem consumidor implementado

1. Contratar prova passiva estrita para todas as finalidades/perfis da
   preparação dos três mapas; separar admissão de ida de gates ida/volta e
   patrulhas. Reutilizar verificadores canônicos e preservar primeira falha.
2. Bake no editor/export e leitura limitada com identidade externa atual,
   budgets, decompression bounds, revisão e fallback. Cache verificado apenas
   de derivados estáticos; nenhum ator/mundo/slot/save do processo anterior.
3. Provar que nenhuma etapa posterior reconstrói o fechamento frio evitado.
   Comparar manifestos, RNG, slots, rotas e invariantes negativos. Medir carga
   real completa em release: processos novos e rodada quente identificados,
   tempo por bloco, RSS, tamanho dos dados, intervalo final entre quadros e
   primeiros segundos de caminhada/AI, com contadores de fallback/lattices.
4. Em paralelo de planejamento, perfilar uma retomada/portal por
   unpack/validação/hidratação/writer/vista/instalação; depois delimitar staged
   único no resume e bake visual conforme a parcela encontrada. Só então
   avaliar dois workers contra a nova distribuição de custo.

Este estudo não muda gameplay, compatibilidade, conteúdo, writer ou o aceite
humano pendente. Os ensaios anteriores sem ganho continuam descartados. O
resultado novo é a viabilidade medida da verificação de caminhos conhecidos,
com limites explícitos; a redução integrada do carregamento ainda precisa ser
implementada e demonstrada.
