# F2 / M2 — fechamento da fundação de terreno

24/10/2026. **F2 FECHADO TECNICAMENTE / VALIDADA.** Autorização humana: “Faça o que
tiver que ser feito agora, com a documentação nova em mente, para fechar F2”.
Candidato executável `163c509de8a47f60523196aeaea76e9b08b3e471`, branch
`codex/map-editor-m2`, checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m2`.
Base anterior `f0a854a39dc6687e2b6a514efa233ec34fd69bfd`; F1/M0 permanecem
integrados por ancestralidade. [Contrato e propriedade](../contracts/m2_closure.md).
Este recibo sucede o [protótipo v1](m2.md), cuja evidência permanece histórica.

## Resultado utilizável

A aba **Mapas** mantém autoria por pincéis, camadas, rampa, ponte, proteção,
trava, ocultação, salvamento, recuperação e undo/redo de F1/F2. Uma célula/peça é
uma área autorada, de uma sala a um campo amplo; grade e suportes gerados não são
peças. Um mapa poderá conter uma ou mais peças de tamanhos diferentes. Não se
monta o chão sobrepondo objetos poligonais pré-desenhados.

**Exemplo de peça grande** cria uma única peça contígua, com 65×65 amostras,
8192×8192 unidades do mundo, campo, subida e platô. São 4096 quadrados de grade
e8192 triângulos visuais; a geometria canônica compacta exatamente as três regiões
coplanares. Esculpir altera as amostras e regenera a partição necessária; não
aproxima alturas para conservar uma quantidade arbitrária de polígonos.
**Exemplo rampa/ponte** conserva a prova de passagem por baixo e por cima.
Os exemplos só entram em peça vazia e preservam terreno existente.

Grama/Terra agora são texturas repetidas em coordenadas do mundo, com mistura
por máscaras, normais suavizadas e mipmaps para o zoom distante. A grade técnica
é opcional. A projeção isométrica aprovada continua sendo a apresentação;
construções, natureza e doodads detalhados pertencem ao consumidor de objetos.
Os dois albedos foram gerados com imagegen integrado (built-in); origem, caminhos
e prompts completos estão em [materiais](../../../assets/art/map_authoring/materials.md).

**Editar pontos de conexão** permite adicionar, selecionar, alterar e remover
posição, camada/piso, orientação, largura, folga e sentido. Uma edição equivale
a uma ação de histórico; camada travada protege criação/alteração/remoção.
Compilar valida a abertura geométrica; formulário não torna uma conexão válida
por aparência. Fonte inválida continua sendo um rascunho salvável.

A referência humana de declive mais escuro/pedregoso já tem indicação derivada
da geometria, sem alterar a pintura salva. A mistura começa em gradiente0,7 e
chega ao material rochoso em1,0; a faixa é parâmetro inicial de apresentação.
Cor não concede nem proíbe suporte. **Faces acima de45° continuam recusadas pelo
compilador F2**; volumes de montanha/taludes não caminháveis exigem o contrato
de bloqueios correspondente. Não se anuncia oclusão de terreno sólido onde só
existe superfície de suporte.

## Contrato técnico e preservação

Schema fonte1, Session e Store preservados. A correção pontual do leitor estrito
resolve a conversão decimal de um ULP revelada pelas máscaras fracionárias;
gramática, limites, detecção de duplicatas e rejeição de não finitos permanecem.
Arredondamento decimal nearest-even com comparação exata nas conversões instáveis;
cache limitado a8192 entradas, protegido por mutex. Não se enfraquece o hash nem
se quantizam alturas/máscaras para ocultar divergência de IO.

Compilador `map_terrain_v2`, pacote format2: part canônica, adjacências internas,
fronteiras/aberturas, render_layers densas, source_hash e package_hash. Cinco
dependências por bytes: dois PNGs, dois parâmetros de importação e shader.
Dependência ausente/adulterada impede validação. GUI e CLI compartilham compile;
CLI distingue piece_count, grid_quads e support_count. Revisão1 não é aceita
como pacote2; a fonte1 pode ser recompilada. Sem promessa de migração de bundles.

A partição coplanar determinística é derivada da grade; quads deformados mantêm
a diagonal da fonte. Divisão de bordas reutiliza vértices originais, evitando
erro de reinterpolação float32 que desconectava relevo editado em coordenadas
maiores. Overlap entre camadas/pisos e folga sob pontes continuam validados.
WorldGeometry, WorldActorMotion e o kernel E07 são consumidos sem edição.

Limites defensivos separados: 65536 quadrados de grade por fonte, 1024 suportes
gerados, 257 amostras por eixo por camada, coordenadas até8192 em módulo,
perfil técnico radius2/height12 e folga padrão100. Acima do orçamento, erro sem
pacote parcial. Não são contagens de peças nem equivalência física com mapas RO.
Relevo arbitrariamente denso pode atingir orçamento antes de atingir área máxima.
Não se certifica toda combinação dos tetos como interativa.

Prévia do brush calcula apenas a região afetada; commit conserva validação
estrita e aplicação atômica. Renderer usa malhas indexadas com UV global;
seleção isométrica consulta a camada escolhida e o relevo efetivo. O traço visual
acompanha altura. Bake segue em worker cancelável, descartando fonte obsoleta.
Não há bake incremental. Preview_manifest consome o grafo interno explicitamente;
o assembler F0 não ganha essa interpretação automaticamente por receber a part.

## Validação e evidências

Sol implementa, corrige e confere contrato/invariantes e imagens. Luna supervisiona
a execução fechada e seus hashes; não é auditoria semântica independente.
Seleção F2:102 checks de terreno,46 de escala/precisão,70 de documento e45 de
UI nativa; importação e quatro processos CLI adicionais. Casos repetidos de
medição não são cenários distintos. Há travessia real de rampa/ponte/passagem
inferior, rejeição de corpo alto e ataque/raio ocluído, clique no platô, conexões,
cancelamento/obsolescência, proteção/trava, undo/redo e IO exato.

Os 4225 pontos da peça grande são conferidos contra suporte canônico, com rota
e avanço real do ator por altura intermediária, sem teleporte. Grade129×129 plana
compila com um suporte; relevo acima do orçamento falha integralmente. Testes
incluem tie nearest-even, valor subnormal, underflow/overflow e preservação binária
de todas as máscaras fracionárias após JSON. Mipmaps são conferidos na textura
importada, não só na configuração textual.

[Supervisão Luna](evidence/m2/closure/luna.md),
[nove etapas](evidence/m2/closure/luna_run/runs.json) e
[inputs/engine/fixture](evidence/m2/closure/luna_run/manifest.json):263/263 checks,
exit0, sem timeout ou SCRIPT ERROR/Parse Error/ERROR.46 inputs atuais e cópias
conferidos por SHA256; HEAD permaneceu163c509 antes/depois. Pares CLI pequeno e
grande coincidem com seus testes-fonte. A UI pequena compara worker e compile
na mesma fonte; a UI grande comprova bake com três suportes e IO/clique/edição.
Não se confunde isso com comparar diretamente fontes nativas de IDs diferentes.

Runner oficial listado com -List antes da seleção. Quatro IDs de299 executados:
e07_f1_import_test, editor_import em F1Fixture, e07_f1_geometry_test (33/33) e
e07_f1_actor_integration_test (193/193). Todos passaram, sem erros/timeouts;
[registros e hashes oficiais](evidence/m2/closure/official/manifest.json).
Importador comprovou1739 arquivos idênticos por bytes; só desativou o autoload VCS
na cópia. Os295 IDs restantes não foram executados; não se anuncia suíte total.

Sol inspecionou as capturas nativas1920×1080: controles acessíveis, campo contínuo
sem linhas de montagem, mistura de terra/grama em detalhe e rampa com material
pedregoso escuro. [Visão da peça](evidence/m2/closure/luna_run/large_terrain.png),
[detalhe dos materiais](evidence/m2/closure/luna_run/terrain_detail.png),
[declive](evidence/m2/closure/luna_run/steep_terrain.png) e
[rampa/ponte](evidence/m2/closure/luna_run/terrain.png). Essa inspeção técnica não
substitui o aceite humano de aparência e uso.

[Tentativas autorais](evidence/m2/closure/author_attempts.json) preservam logs e
hashes de iterações não congeladas, sem atribuí-las ao SHA final. Falhas resolvidas:
inferência de tipo; dependências ausentes na fixture; deadline inicial curto para
o lote de escala; deriva decimal; ponto de borda reinterpolado; underflow no
conversor; WeakRef inferido no scan do editor; captura aguardando quadro ocioso.
Captura passou a solicitar force_draw. Uma repetição diagnóstica com plugin já
ativo gerou erro; a ativação agora é idempotente. Nenhum erro de saída é ignorado
pelo runner, mesmo com checks positivos e exit0.

## Medições e limites de uso

Hardware local: Windows, Intel Core i7-8700 @3,20GHz, NVIDIA GTX1080,
OpenGL3.3 Compatibility; Godot4.7.2.stable.official.ed1daf0bf standard, SHA256
`AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
Perfil APPDATA/LOCALAPPDATA descartável; VCS autoload desativado só na cópia.

As cinco repetições por dimensão acontecem no mesmo processo após testes
funcionais, com cache numérico aquecido. first_compile_ms mede separadamente a
primeira compilação da peça65×65 antes de ler suas máscaras nesse processo;
não inclui boot do engine. Horários dos CLIs medem processo independente completo,
incluindo boot/leitura/compilação, e não são apresentados como tempo puro de bake.
Brush preview e geração dos arrays visuais são medições separadas: sua soma não
é frame time. Não houve aferição de FPS, pico de memória ou latência de cancelamento.

[Valores brutos](evidence/m2/closure/luna_run/terrain_scale_measurements.json) e
[resumo calculado](evidence/m2/closure/measurement_summary.json). Todos os casos
abaixo têm a mesma área8192×8192 e três suportes, com cinco execuções por dimensão.

| Grade | Triângulos visuais | Bake aquecido | Preview brush máximo | Commit brush máximo | Arrays visuais máximo | Bytes pacote |
|---|---:|---:|---:|---:|---:|---:|
|33×33|2048|82,90–99,47ms|0,40ms|40,21ms|5,41ms|35488|
|65×65|8192|292,77–319,69ms|0,85ms|149,46ms|19,79ms|113792|
|129×129|32768|7012,12–8204,46ms|3,35ms|731,88ms|114,01ms|423928|

A primeira compilação65×65 com máscaras ainda não lidas levou1538,61ms.
Os dois CLIs grandes completos levaram6,62s e6,89s, incluindo boot e leitura.
65×65 é o cenário inicial de edição grande demonstrado;129×129 já tem custo
de bake de7–8s. O teto defensivo65536 quadrados não é uma meta de fluidez.

O candidato foi medido com uma peça de terreno sem população/props. Não prova
desempenho de mapa final com simulação, composição ou objetos. Bundle/publicação,
duas peças em F3 e encontro em F4 continuam em seus escopos e dependem da próxima
autorização. Este fechamento não concede aceite humano visual/de uso, integração
em playtest, merge/master, push ou abertura de F3. Checkout habitual e save pessoal
permanecem fora da escrita desta entrega.

Retomada pela skill ragrpg-resume: CLI de status e WORKFLOW_TOOLING.md ausentes
nos dois checkouts conhecidos, conferidos sem instalar/copiar ferramenta externa.
Estado confrontado diretamente por Git e contratos. Checkout habitual continua
em codex/playtest/fba777b3822356a10e7f6e050971e54ab1a9819b; este candidato está
na worktree dedicada. Alterações finais de recibos/evidência são documentais;
conferir seus links/hashes não exige repetir gameplay com os mesmos inputs.

## Retorno humano sobre as capturas —24/10/2026

O usuário considerou bom o gradiente de terrain_detail e boa a diferença de
texturas do declive em steep_terrain. Acrescentou a referência AoM para mistura
gradual entre caminho e penhasco e relevo arredondado nas mudanças de inclinação,
em lugar de planos retos encostados. [Direção e referência preservadas](../contracts/terrain_piece_semantics.md#complemento-visual-após-as-capturas-do-f2-24102026).

Registra retorno positivo parcial, sem converter em aceite humano integral ou
integração. O exemplo técnico atual não prova o acabamento orgânico pretendido.
Essa evolução pertence ao terreno; sua atribuição a pacote será explícita, sem
iniciar F3 por este comentário. Preservados o candidato testado, seus limites e
as evidências. Esta atualização conferiu referências e bytes do anexo; gameplay
não foi repetido, pois não houve alteração executável.
