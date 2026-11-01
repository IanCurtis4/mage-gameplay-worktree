# F9 — síntese interna por região e reconciliação

Contrato técnico em preparação para F9-05/07/08/09/10; nenhuma abertura de épico,
F10, campanha ou nova mecânica. Fonte de produto: [F9](f9_completion.md)
e semântica da peça. Consulta Astra delimitada no subagente astra_navigation_cost,
medium, somente leitura dos contratos/APIs f21709ae0065b34a534d40d5eeeff0742e07dea9;
Sol define os tipos executáveis e implementará. Astra não escreveu arquivos nem
rodou Godot/testes. Não é validação do delta de navegação nem gate adicional.

## Estado (checkpoint43, P3a)

1/11/2026. Implementado só o recorte dentro de uma peça (kind piece):
`scripts/map_authoring/synthesis/regional_synthesis.gd` (revisão `regional_v1`),
a ferramenta "Variação regional" da tela de terreno
(`synthesis/synthesis_section.gd`), AX `terrain/synthesis/{request,preview,apply,discard}`
e o CLI `synthesis/headless.gd`, todos no mesmo serviço.

- Pedido: `algorithm_revision`, `seed_text`, `base_hash`, `target.layer_id`,
  `selection` (`region_id` da camada ou `polygon_xz` local), `channels` com
  terrain (preserve/relief), materials (preserve/patches) e objects
  (preserve/scatter), `preserve` (`entity_ids`, `region_ids`). Chaves fechadas;
  canal ausente é recusado; tudo "preservar" é `synthesis_empty`.
- Máscara: amostra livre só se o quadrado de influência (meio lado = passo) está
  todo dentro da seleção e não toca região protegida da camada, região preservada,
  abertura de conexão nem o footprint de objeto que fica. Polígonos de proteção
  não mudam. Objeto travado, preservado, que cruza a borda ou toca proteção fica
  inteiro; com `replace`, só saem os soltos totalmente dentro.
- Saída: fonte integral, `source_hash`, `compiled_hash` (terreno compilado), diff
  (`terrain_samples`, `material_samples`, `objects_added`, `objects_removed`,
  `selection_hash`) e métricas. `apply()` exige o hash atual igual ao da prévia e
  faz uma única `session.apply`.
- Fora deste recorte: orçamento explícito no pedido, instância compartilhada em
  mapa, encontros e patrulhas, recibo/replay e intercâmbio de três vias (P3b–P3d).

## Autoridade e unidade de aplicação

Serviço de proposta regional sobre a fonte raiz aberta, kind piece/map/population/
patrol. Reutiliza Brush, operações/scatter de objetos, compiladores e geometria
canônica. Gerador WFC de slots continua distinto: trocar peça no slot não satisfaz
síntese interna. Preparar toda a árvore imutável copiada e executar uma única
session.apply após conferir hash e proteções; um undo restaura todos os hashes.
Nunca sequenciar commits de sessões independentes para simular atomicidade.

Outras janelas/arquivos são snapshots independentes. Marcar divergência e permitir
reconciliação explícita; não atualizar silenciosamente todas as cópias.

## Pedido e proposta

prepare(root_kind, source, request, cancellation) -> proposal;
apply(proposal, session, expected_hash) -> result.
Pedido passivo fechado: algorithm_revision, seed_text decimal signed64 canônico,
base_hash, target(instance_id/piece_hash quando cabíveis, layer_id), selection
(region_id/polygon_hash), channels(terrain/materials/objects/encounters/patrols),
preserve(entity_ids/region_masks/pins), parameters tipados e budget.
Cada canal diz preserve ou fornece receita concreta; ausência nunca autoriza.
Proposta: ok/code, base_hash/request_hash, source integral, source_hash,
compiled_hash, diff, diagnostics e metrics. Sem código/cena/script no pedido.

## Máscara e conservação

Uma autoridade editorial comum a síntese e intercâmbio; não decide apoio/navegação.
Região pertence à camada, em coordenadas locais da instância; transformar pelas
rotinas canônicas existentes. Não selecionar apenas por XZ global entre andares.
Locks/pins/proteções prevalecem. Polígonos de proteção não mudam na mesma operação.

- Terreno mantém grade/origem/passo. Preservar amostras cuja influência geométrica
  toca proteção ou exterior: centro isolado não basta para triângulo que cruza a
  fronteira. Mudança exclusivamente dentro da seleção autorizada.
- Objeto/encontro que toca proteção ou atravessa seleção permanece inteiro,
  considerando footprint/corpo, não apenas pivô.
- Patrulha considera segmentos e slots. Rota parcialmente selecionada permanece;
  mudança integral exige seleção explícita. Seus slots são preservados também.
- Contexto, reservas, conectores/sockets/links/transformações, IDs passivos de quest,
  origem/recompensa e exceções manuais mantêm regras canônicas.
- Preservar é manter os dados autorais. Se nova altura invalida apoio de algo
  preservado, falhar apontando entidade/local. Reassentar/mover precisa ser mudança
  explicitamente selecionada e constar do diff.

Região insuficiente produz deficit/contradição, sem diminuir proteção. Cancelar/
budget não significam contradição geométrica. Brush.protected atual é parcial;
Exchange.guards não deve congelar camada inteira só por haver protected_regions.

## Produção e dependências

Receitas de alturas/materiais derivam de Brush.stroke e máscara comum, em ordem
estável sobre snapshot. RNG editorial separado da run e da ordem de eventos UI.
Objetos reutilizam ObjectOperations.propose, inclusão regional e exclusões;
scatter deve cancelar durante tentativas. Compilar peça/composição propostas.

Reconciliar encontros/patrulhas com suporte novo por identidade/contexto autorais;
sem piso global mais próximo. PopulationCompiler deve reservar todos os slots
preservados (também não fixed externos à seleção) antes de regenerar o subconjunto;
quota parcial conta preservados. Não publicar flags fixed artificiais. Slots de
patrulha preservada não podem ser substituídos sem reconciliar a rota na mesma
proposta. plan_hash só atualiza depois de validar o plano final.
Compilar árvore final e conferir proteções antes de oferecer aplicação.

## Instância de peça compartilhada

Editar uma instância cria novo snapshot em map.pieces e troca somente seu
piece_hash; conserva instância, IDs internos e links. Snapshot antigo permanece
se referenciado. Duas variações diferentes produzem snapshots distintos; hashes
idênticos podem compartilhar resultado. Não alterar catálogo/registro compartilhado.

## Persistência e replay

Extensão opcional validada por helper comum somente no documento raiz. Fontes
antigas sem extensão mantêm hash ao abrir. Registrar algoritmo/seed/alvo/máscaras/
parâmetros, hashes de base/dependências e resultado. Nunca embutir a fonte inteira
recursivamente na receita. Mesma base+receita+dependências+algoritmo dá mesmo hash.
Seed isolada não reconstrói edições humanas; base ausente/divergente é diagnóstico.
Nova variação sobre estado atual captura outra base explicitamente.

Evitar auto referência de hash: recibo guarda result_content_hash da projeção que
remove somente a extensão de recibos da raiz. source_hash integral é calculado na
proposta após inserir o recibo e não é gravado dentro dele. A base integral é
identificada por base_hash, mantida em armazenamento passivo imutável/livro de
revisões e transportada quando necessária ao replay; não normalizar metadados ao
abrir uma fonte antiga. Limites de recibos/base/bytes e política de retenção precisam
ser concretizados antes do consumidor, preservando fontes/backups do usuário.

## Intercâmbio e reconciliação

Mesmo diff/compilação local/hash/commit, com máscara compartilhada. Acrescentar
comparação por amostra/região para alturas, hoje substituição de array integral.
Comparar base, atual e proposta por identidade/campo/amostra: alterações disjuntas
podem compor. Valor conflitante, remoção versus edição, referência rompida ou mudança
de proteção exigem diagnóstico/escolha explícita. Recompilar resultado combinado.
A rejeição atual de toda base divergente não é reconciliação completa.

Bundle passivo: receita importada não executa/rerrola. Manifesto de assets contém
hash/tipo/origem/licença e formatos permitidos em área controlada. Relatório externo
não substitui compilação local; scripts/cenas do remetente não são carregados.
Atualizar revisões reais dos compiladores, sem relatar terrain_v2/map_v1 obsoletos.

## Consumos, falhas e provas

Helpers de receita/máscara/proposta; validadores raiz; Brush/TerrainPanel;
ObjectOperations; PopulationCompiler; adaptadores das sessões/painéis; acesso
claramente separado do WFC em GenerationPanel; Exchange/painel/headless.
GUI/AX parametrizado/CLI chamam o mesmo serviço, sem implementações paralelas.

Reusar stale_source, cancelled, budget_exhausted, contradiction, base_diverged e
falhas de compilador; localizar máscara inválida, proteção violada, base ausente e
referência não reconciliada. Nenhuma falha pode aplicar fonte ou certificado parcial.

Provas: alteração interna real numa única peça; mesmo hash GUI/AX/CLI; influência
de triângulo/footprint/segmento cruzando máscara; duas instâncias; ponte/passagem;
reserva/raro fixo; slot referenciado por patrulha; divergência entre revisões;
cancelamento/falha sem mutação; undo único; replay com base ausente; bundle/asset
adulterado rejeitado; medição de preparo/compilação/diff/aplicação preservada.
Este contrato só declara concluído o recorte da seção "Estado".
