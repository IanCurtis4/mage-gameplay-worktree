# F9 — prova de conectividade por lote na autoridade canônica

26/10/2026. Contrato técnico para implementação Sol; consulta Astra delimitada
por custo de composição densa, conforme [WORKFLOW](../../WORKFLOW.md).
[F9](f9_completion.md) e [fragmentos](f9_connector_fragments.md) permanecem vigentes.
Base de fundação informada: `270ff3ab78f3a6af299027bdd5ad8e69bd8beba5`;
HEAD documental `8776b051521eb98b14d81d1a4a00b3723c92dbf7`, com delta não congelado.
Branch `codex/map-editor-f9`, checkout `.tools/map-editor-m5`.
Dono exclusivo desta nota: [manifesto](f9_ownership.json).

## Problema e decisão

MapCompiler escolhe um ponto caminhável por suporte e chama `WorldGeometry.path`
de root até cada ponto e de volta. Cada chamada pode reconstruir portais,
insets, cantos e estados de desvio por massa/segmento para todo o estágio.
Amostra real informada: fontes9x9/6x6, até178 suportes triangulares, abertura80
sobre bordas12,5/20, partição N:M com12 intervalos. Timeout300s não localiza
sozinho a etapa cara: medir construção, consulta e validação separadamente.
Não reduzir essa amostra, corpo, fronteiras ou verificações, nem aumentar timeout.

Adotar **uma prova de conectividade por lote em WorldGeometry**, reutilizando
o construtor de estados e os predicados de aresta de `path`. Construir a união
dos grafos necessários aos pares ordenados root→destino e destino→root, e
buscar alcance dirigido de root no grafo e em seu transposto. BFS basta para
existência; não executar Dijkstra por destino quando custo não é o requisito.
O lote não cria autoridade de navegação no editor e não usa apenas topologia,
centros de portais, componentes de superfícies ou soma de larguras.

Extrair primeiro funções compartilhadas sem mudar o resultado de `path`:
preparação do contexto, geração de estados comuns, contribuição de cada par,
validação de aresta e reconstrução de rota. Implementações ficam na autoridade
canônica ou helper interno chamado por ela; UI/MapCompiler apenas fornecem pontos.
Nomes internos podem ser ajustados por Sol; regras abaixo são obrigatórias.

## Contexto, estados e arestas

Contexto de lote é snapshot imutável de estágio, perfil, sólidos, barreiras,
segmentos temporários e configuração, com índice SupportPatch/SolidPrism derivado.
Preservar `_candidate_point`, `_support_segment_fraction`, `_clear_path_segment`
e rotas de contato/transição; não duplicar fórmulas ou tolerâncias.
`SupportPatch` decide união física de apoio; sentido de movimento continua nas
transições dirigidas. União de suporte por si só não prova caminho dirigido.

Separar trabalho compartilhável de trabalho dependente do par:

- Comum: endpoints elegíveis por kind/folga, planos e índices, corners de AABB,
  polígonos de massa cortados pelo plano/perfil do suporte e cantos de segmentos;
  validar cada estado como hoje. Usar envelopes conservadores do suporte para
  landmarks; buckets são aceleração, não definição do conjunto geométrico.
- Por par ordenado: os mesmos resultados de `_portal_candidates(a,b,source,target,...)`,
  incluindo projeções de ambos e interseção da reta source-target com a abertura.
  Acrescentar insets, fallback para seam, pontos `via`, conexão e sentido com
  exatamente os predicados canônicos. Incluir também o par invertido; a hipótese
  de simetria numérica não substitui sua geração.
- Terminais: root e todos os destinos com identidade completa de WorldPoint
  (estágio, superfície e posição), validados. Coincidência XYZ entre pisos não
  permite fusão ou mudança de superfície sem conexão legal.
- Arestas locais: candidatos da mesma superfície, aceitos somente se sweep e
  suporte de todo segmento passam. Arestas de portal preservam seus pontos
  intermediários e flags de direção. Não conectar insets diretamente omitindo seam.

**Rota direta:** `path` atualmente tenta `ground_line_to` antes do grafo. Uma
rota direta bem-sucedida pode não estar representada pelos estados discretos.
Para cada par obrigatório, manter essa possibilidade como aresta composta entre
terminais, com a rota completa e os mesmos rechecks de `_path`. Não substituir
por linha reta XYZ nem inferir retorno de uma ida bem-sucedida. É permitido
adiar a tentativa direta para pares ainda não certificados, desde que um negativo
só seja definitivo após considerar essa possibilidade e o grafo completo.

Deduplicar estados/arestas comuns por identidade e conteúdo exatos canônicos,
com contexto de superfície/transição. Preservar candidatos já selecionados pela
deduplicação interna de cada consulta individual: refazer uma deduplicação EPS
sobre a união pode apagar o representante que sustentava um caminho anterior.
Não usar ordinal local do portal como identidade global: o ordinal muda quando
outro par acrescenta candidatos. Preservar proveniência para testes/diagnósticos.
Se fundir estados idênticos, unir todas as incidências/rotas, sem perder arestas.

Arestas de visibilidade podem ser avaliadas sob demanda e memoizadas por par
**ordenado** de estados e contexto. Ida expande candidatos de saída. Retorno
expande candidatos de entrada: ao visitar v no transposto, testar a aresta
original u→v, não v→u. Para transições, inverter apenas o índice de consulta;
jamais flags ou semântica de travessia. Dois índices (saída/entrada) compartilham
o mesmo registro da aresta original. Não inferir reciprocidade por distância.

## O que a prova garante

Seja Gq o grafo produzido para um par ordenado q, acrescido da rota direta
válida quando houver; seja B a união desses grafos com os terminais. Exigir
mapeamento de cada estado/aresta de Gq para B que preserve ponto, superfície,
sentido, via e validade. Assim, todo sucesso anterior possui caminho em B.
Validações locais adicionais entre estados da união podem acrescentar caminhos
reais; não removem os anteriores. Não exigir igualdade de negativos entre
busca individual limitada a seus candidatos e a união mais rica.

Todo positivo do lote precisa de testemunha contínua reconstruível, composta
exclusivamente de arestas aceitas pelo corpo/perfil/snapshot. Validar a sequência
reconstruída com a mesma autoridade de movimento, incluindo trocas de superfície,
sem executar outra busca global. Compartilhar prova de uma aresta entre várias
testemunhas é permitido. Se surgir positivo novo, prova geométrica é obrigatória;
registrá-lo na comparação diferencial, não ajustar o oráculo silenciosamente.

Negativo após esgotar estados/arestas relevantes significa sem caminho nesse
modelo discreto canônico para aquele terminal/sentido. Não prova impossibilidade
em todo o espaço contínuo. Cancelamento, budget ou mudança de revisão nunca são
negativos geométricos nem sucesso parcial. Parada positiva antecipada é legal
quando todos os terminais têm testemunhas de ida e retorno; negativo exige
completude de construção e busca pertinente, inclusive contribuições de todos
os pares previstos. Construção incremental deve preservar essa distinção.

`path` individual mantém contrato, fast path, candidatos, custo e desempate.
BFS do lote produz certificado de existência, **não menor distância**. A união
pode oferecer rota menor que Gq e BFS pode escolher maior; não usar custo da
testemunha para alcance de ataque, balanceamento, movimento ou substituir
`query_attack(ground_connected)`. Compartilhar o construtor não obriga `path`
a consumir os candidatos de outros pares. Testar custos individuais inalterados.

A prova de composição continua sendo dos mesmos representantes escolhidos por
`_walkable_point`. Não afirma que todo ponto da área de cada suporte é acessível.
Preservar seleção, validação e falha quando não existe representante. Não trocar
ponto difícil por outro para contornar falha do lote. Registrar essa limitação.

## API proposta e integração

`WorldGeometry.connectivity_batch(root: ExpeditionWorldPoint,
targets: Array[ExpeditionWorldPoint], profile: Dictionary, revision: int,
cancellation: Callable = Callable(), budget: Dictionary = {}) -> Dictionary`.
Escopo inicial: snapshot atual, sem candidato especulativo fornecido pelo editor.
Não ampliar API pública de inserção de obstáculos nesta entrega por inferência.

Envelope igual às consultas canônicas: `ok`, `error_code`, `geometry_revision`,
`data`. Em execução concluída, `ok=true` significa consulta válida, e `data`
contém `complete=true`, `all_reachable: bool`, `configuration_revision`,
`profile_hash`, `graph_revision`, lista `targets` com ponto/índice de entrada,
`outward_reachable`, `inward_reachable`, referências às duas testemunhas e
`metrics`. Lista vazia válida certifica somente root validado. Pontos duplicados
podem compartilhar estado, preservando resultados por índice. Stage incompatível,
ponto inválido ou perfil inválido falham antes de emitir certificado.

Testemunhas podem compartilhar tabelas de estados, arestas e predecessores de
ida/retorno; não expandir centenas de cópias de rotas no pacote. Expor reconstrução
para teste/diagnóstico pelo mesmo helper de `path`. Falha operacional retorna
`ok=false`, sem certificado publicável. Códigos: `stale_geometry`,
`invalid_profile`, `invalid_support`, `cancelled`, `navigation_budget_exceeded`;
detalhes contêm fase e contadores, não `all_reachable=true` parcial.

MapCompiler chama o lote uma vez, com todos os representantes originais, depois
do fechamento de barreiras e sólidos. Só publica com `ok && complete &&
all_reachable` e SourceHash/revisões ainda atuais. Resultado negativo completo
vira `route_unreachable` com terminal/sentido e diagnóstico. Cancelamento/budget
permanecem distintos; não mapear indiscriminadamente tudo para inacessível.
Tratar `configure` falho. O certificado derivado fica fora do manifesto/save;
se relatório o conservar, vincular hashes/revisões e não torná-lo autoridade.

## Cache, cancelamento e orçamento

Primeira implementação usa cache **local ao lote**, descartável, sem formato
persistente e sem mutação de catálogo. Chave inclui snapshot efetivo, perfil
inteiro, revisão do construtor, ponto/superfície/estado e sentido quando relevante.
Evitar cache global nesta fronteira: `insert_obstacle` atualmente altera
`_temporary` para testar candidato antes de incrementar `geometry_revision`.
Logo, revisão numérica sozinha pode reutilizar geometria anterior durante um
teste especulativo. Candidato, segmentos, remoções e rollback também importam.

Se futuramente houver reuso entre lotes, exigir fingerprint do estado efetivo
ou token de snapshot imutável que inclua configurações e mutações especulativas,
além de perfil/algoritmo/terminais e pares. `configure` com outro mundo de revisão
aparente igual invalida tudo. Cache frio/quente precisa produzir o mesmo resultado;
cache é acelerador verificável, jamais arquivo de evidência presumido válido.

Capturar snapshots antes de começar; conferir configuração/geometria ao publicar
e após callbacks/yields. Mudança em fonte do editor também invalida o resultado.
Callback de cancelamento consultado em lotes limitados durante landmarks,
portais, testes de aresta, buscas e reconstrução; callback que muda o mundo
invalida o lote. Não chamar apenas entre destinos depois de trabalho global.

Orçamento explícito e contabilizado: estados, candidatos/pares, avaliações de
aresta, expansões, armazenamento e prazo/cancelamento existentes. Não escolher
novos números nesta nota. Sol mede e registra limites técnicos apropriados,
sem reduzir a amostra exigida ou ampliar timeout para esconder o problema.
Exceder orçamento aborta com fase/consumo, sem truncar candidatos ou emitir PASS.
Métricas por fase incluem contagens, acertos de cache e tempo observado; não
entram em hash canônico. Ordem estável de terminais/estados evita variação por
ordem de arrays; manter mapeamento aos índices originais dos resultados.

## Alternativa menor e sequência de implementação

Memoizar só estados comuns e arestas mantendo 2N buscas individuais é alteração
menor e preserva resultados por construção. É aceitável como passo de medição,
ou solução suficiente se a amostra completa concluir com responsividade medida.
Não assumir suficiência: ainda repete buscas e contribuições específicas de par.
Também não presumir que união completa é sempre mais barata: ela aumenta estados
e pode quadratizar visibilidade por superfície. Medir contagens antes/depois.

Sequência recomendada: instrumentar fases; extrair builder/predicados sem alteração
semântica; provar equivalência individual; oferecer lote com memoização e duas
buscas dirigidas; integrar MapCompiler e medir amostra integral. Pode começar com
construção completa e visibilidade lazy; construção incremental é otimização
posterior dentro destas invariantes, se as medições a justificarem. Sem navegador
paralelo, thread adicional obrigatória ou alteração de produto.

## Provas mínimas e entrega

- Comparação de estados/arestas: Gq embutido em B para todos os pares de corpus
  pequeno. Projeção específica, interseção específica e candidatos separados por
  menos de EPS que pertencem a consultas distintas. Rota direta que não depende
  de portal discretizado, inclusive contato estacionário legal.
- Diferencial: todo sucesso individual vira sucesso do lote com testemunha
  validada; custo/pontos/desempates de `path` preservados pela extração. Negativo
  individual/positivo em união requer percurso geométrico demonstrado.
- Direção: conexão somente ida, somente volta, ciclo e componente desconectado;
  comprovar que busca transposta não fabrica retorno. Mesma posição em pisos
  sobrepostos e mudança de superfície sem conector devem falhar.
- Corpo: abertura80 e N:M12, disco maior que fragmento, obstáculo no centro,
  passagem lateral, massa inclinada, rampa400/160 e400/200, folga e barreira
  fechada. Nenhuma passagem por mera vizinhança de triângulos.
- Estado: frio/quente, reorder, perfil diferente, configure repetido, inserir/
  remover obstáculo e segmento, candidato especulativo/rollback quando helper
  for usado por `_path`; nenhum cache contaminado por revisão igual.
- Operação: cancelar em construção/arestas/buscas/reconstrução, stale durante
  callback, budget insuficiente e rejeição de ponto/perfil; nenhuma publicação
  parcial. BFS/rotas determinísticas, sem ciclos de predecessor em aresta zero.
- Amostra densa original completa: marcadores build/query/validation, tempo e
  contagens por fase, resultados/erros/hashes; sem reduzir caso nem aumentar300s.
  Regressão por impacto em `tools/verify.ps1`, supervisão Luna, fechamento Sol.
  Export/editor/jogo devem continuar usando a mesma autoridade canônica.

## Evidência e limites desta consulta

Leitura do código atual de WorldGeometry (`_path`, `_portal_candidates`, ground
line, sweep e mutações temporárias), SupportPatch, SolidPrism e MapCompiler;
WORKFLOW/F9 e contrato de fragmentos conferidos. A otimização lazy, plano/ULP,
índice32, teste58 e demais PASS informados por Sol não foram auditados aqui.
Timeout sem marcadores não foi tratado como prova do ponto exato de gargalo.

Somente esta nota foi escrita; nenhum runtime/teste/runner/evidência alheia mudou.
Godot e suíte de gameplay não executados; fixture não utilizada. A API proposta
não está implementada por esta consulta. Não há meta de tempo inventada,
certificação de performance ou fechamento de F9. **Nenhuma nova decisão humana
de produto é necessária para esta fronteira técnica.**
