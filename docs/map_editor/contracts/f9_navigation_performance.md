# F9 — terreno orgânico e custo da autoridade de navegação

Continuação autorizada F9-02/04/10, fontef21709ae0065b34a534d40d5eeeff0742e07dea9,
mesmo checkout/branch/fixture. Sol escreve código/testes; consulta excepcional
Astra delimitada astra_navigation_cost, medium, somente leitura. O motivo foi
concreto: corpo/forma corretos com custo de54s/256MiB e preservação de custo,
EPS e desempate da consulta individual. A consulta não rodou Godot nem testes.
Não é novo gate, auditoria semântica independente ou nova escolha de produto.

## Reprodução preservada

[Probe e logs](../delivery/evidence/f9/author/organic_baseline/probe.output.log):
Gauss220/sigma180 em domínio1200², uma peça.9x9/128 apoios: terreno399ms,
mapa6403ms e preparo do corpo20/32 8918ms PASS.17x17/512 apoios: terreno2944ms
PASS; mapa54288ms falha navigation_budget_exceeded em witnesses. Contabilidade
268436124 contra268435456, snapshot21823716,512 estados,1022 pares diretos,
2 expansões e35296 pontos de testemunha. Não é uma medição de heap/RSS.
Não adaptar essa amostra ou aumentar caps/timeout para fazê-la passar.
A consulta individual densa anteriormente174671ms continua exigida na frente10.

## Prova ALL_DIRECT compartilhada

Mantém a API/envelope do [lote](f9_navigation_batch.md), limites e predicados.
Revisão interna2. Ida/volta continuam chamadas separadas ao _navigation_direct,
a mesma autoridade do fast path individual, no shadow/perfil capturados.
Conferir endpoints exatos (estágio/superfície/posição), recomposição integral e
predecessor orientado diretamente ao root usando a própria aresta aceita.
Root coincidente/duplicado conserva sua validação inicial e índices. Rota
unitária só pode representar esse caso deduplicado; não pode virar aresta entre
terminais distintos. Prova privada/transitória, sem flag público confiável.

Em ALL_DIRECT, a sequência reconstruída é idêntica à rota já aceita pela
autoridade: compartilhar essa prova evita reconstruir/revalidar milhares de
pontos outra vez na publicação. Fora dele, conservar a validação anterior.
witness() público sempre reconstrói/revalida geometria, assinatura e perfil
atuais; adulterar o certificado não ganha confiança. Polling/revisão/configuração/
assinatura final, cancelamento e falha sem certificado parcial continuam.

Cobrar conteúdo retido de via uma vez, com containers/referências separados;
graph/incoming/previous compartilham a aresta. Cobrar também o pico temporário
do resultado direto e sua cópia, liberando scratch no final da vida útil.
Não reduzir multiplicadores indiscriminadamente nem aumentar o limite.

## Consulta individual — produtor por superfície

Preservar Dijkstra/heap, relaxação route_cost+EPS, candidatos/ordinais/IDs,
ordem de vizinhos, custos e reconstrução. Gerar cada superfície antes da primeira
expansão: todas as conexões incidentes (ambas as pontas/sentidos), landmarks
e terminais; ordenar by_surface pelos mesmos IDs do produtor eager. O filtro
limita geração e nunca substitui _stage: predicados veem o mundo inteiro.
Conexão já gerada não pode zerar incidências, duplicar arestas ou trocar dados.
Superfície completa não recebe candidato novo depois. Negativo só após fechar a
fila com todas as superfícies alcançadas completas. Índices por consulta seguem
a ordem original e não persistem cache por mero epoch/revisão.

A* não entra nesta correção: melhorias menores/iguais aEPS são rejeitadas pelo
algoritmo atual e custo zero altera descoberta; admissibilidade não prova o
mesmo desempate. Se lazy for insuficiente, medir geração/predicados e compartilhar
preparação/provas locais com chaves exatas e ordenadas, inclusive perfil/candidato.
Não declarar a frente10 resolvida sem repetir o cenário denso.

## Validação por Sol

Lote34 existente e novos casos diretos com transições, contato estacionário,
duplicados/root, direção, perfil real, stale/cancel/budget/adulteração. Gauss17/512
conservada, testemunhas públicas e movimento canônico em verificação separada
do benchmark de publicação. Diferencial eager/lazy de pontos/conexões/custo/erro,
custo zero, diferenças abaixo/em/acima deEPS, unilaterais, candidato e negativos;
conteúdo/ordem das superfícies materializadas. Medir frio/quente e fases, sem
FPS inferido. Core/oficiais por impacto; Luna permanece responsável pela supervisão
automatizada quando disponível, atualmente sem quota. Nenhuma entrega F9 integral,
playtest pessoal, master/push ou novo marco por este contrato.

## Delta dirigido após primeira medição individual

A geração por superfície passou24 diferenciais após corrigir o perfil sintético
inválido de raio0 para0,25 (primeira falha preservada; nenhuma expectativa de
custo/desempate mudou). A repetição exata da fonte densa9x9/6x6 passou publicação
real, sem bypass, em40,611s. Consulta com desvio150,297s; construção6,079s,
155 superfícies/8955 estados/8683 expansões/524360 testes. Perfil histórico2/12,
não o Player20/32 usado na amostra orgânica. Essa redução isolada é insuficiente.

Conforme a consulta Astra já delimitada, compartilhar resultados dos predicados
ponto/corpo, sweep e fração de suporte apenas dentro da mesma consulta síncrona.
Chaves exatas e ordenadas por superfície e Vector3; estágio/configuração completa,
perfil e candidato são fixos pelo contexto privado dessa consulta. Nada persiste
entre consultas ou é autorizado por mera revisão/epoch. Ida/volta não compartilham
um resultado por suposição de simetria. Dijkstra/relaxação/ordem não mudam.
Máximo32768 resultados retidos; saturação continua calculando sem armazenar mais,
sem falha ou mudança de rota. O limite não modifica o orçamento de lote; lote
continua sem esse memo. Registrar hits/misses/entradas para medir.

Arestas de visibilidade local são necessárias somente durante a expansão de seu
estado, que ocorre uma vez. Os predecessores mantêm as arestas aceitas por
referência. Sol pode liberar o restante após a mesma relaxação ordenada, conservando
arestas de portal para futuras materializações; o produtor eager de referência
continua sem esta liberação. Diferencial integral de resultado, teste denso e
regressão por impacto exigidos antes de consolidar.

### Medição e seleção conservadora de massas

O primeiro memo sem reciclagem preservou os digests das duas rotas, mas custou
161,388s:32768 entradas saturadas,6695 hits e1104299 misses. Não é ganho e
permanece como tentativa autoral, sem PASS de desempenho inferido do funcional.
Liberar arestas não selecionadas reduziu retenção observada; a amostra isolada
não é teto de memória/RSS. Reciclar memo quando todos os estados de uma superfície
completa já expandiram evita reter dados que não serão consultados novamente.

O índice global de massas é conservado. Depois de completar o bin de estados de
uma superfície, selecionar uma vez o conjunto conservador de massas de seu envelope
finito: mínimo/máximo componente a componente dos próprios endpoints Vector3,
sem recomposição de AABB que introduza arredondamento. O mesmo perfil expande esse
envelope na broadphase canônica. Cada segmento local futuro tem ambos os extremos
no envelope, logo seus candidatos originais estão contidos nesse conjunto.

Criar índice local dessa subsequência, mantendo ordem relativa original. Cada par
continua passando por spatial_candidates e pelo MESMO sweep/predicados/exclusões;
volumes AABB, temporários, segmentos e candidato continuam avaliados normalmente.
O contexto só é fornecido a arestas locais entre estados do bin completo, nunca
à geração de seam/inset ou a uma consulta arbitrária. Não substituir _stage,
SupportPatch ou massa física por geometria resumida. Contexto transitório termina
na consulta e não adiciona membro a WorldGeometry/snapshot.

Nova prova dirigida usa terreno Gauss5 real e corpo20/32: compara arrays de
candidatos com ordem, envelopes/sweeps completos, temporário/candidato, rota eager
integral e movimento. A primeira rodada de integração scope_lazy_01 encontrou
acesso ao contexto opcional ausente no produtor eager; erro preservado e corrigido
com leitura vazia explícita, sem mudar oráculo. As medições dense e diferenciais
subsequentes têm evidência própria. Não declarar responsividade integral a partir
desta otimização isolada.

### Preparação do mesmo segmento e volumes fixos

O profiling dirigido preservou os dois digests, mas registrou170,037s:
clear99,065s (members26,392s), support59,337s, construção7,093s. Instrumentação
é opcional, apenas quando trace.enabled; não é medição de FPS. A seleção só de
massas/reciclagem não havia melhorado o total (160,713s), portanto não é declarada
como ganho suficiente.

Para cada par ordenado local, um registro privado novo pode receber exatamente
os members calculados por ground_sweep e fornecê-los à fração de suporte que
vem imediatamente depois. Fonte/superfície/endpoints/perfil/candidato não mudam
entre as chamadas. Em cache hit sem esse registro, a fração calcula normalmente.
Registro nunca cruza pares ou consultas nem vem de testemunha pública. A função
pública fraction mantém a mesma rotina com preparação vazia. Kernel.contains,
EPS, headroom, suporte e narrowphase não são dispensados. O produtor eager usado
como oráculo fica sem registro compartilhado e sem seleção regional.

Além das massas, selecionar índices de volumes autorados cujo envelope expandido
possa interceptar o envelope finito do bin. Comparar limites como escalares f64,
usando position+size, raio/altura e EPS conservador. Isso inclui todos os volumes
que sweep_box poderia acertar para qualquer par do bin. Conservar índices/ordem
originais, inclusive desempate por último contato de fração igual. Cada volume
selecionado ainda passa pelo MESMO sweep_box. Todos os temporários atuais são
acrescentados após os índices autorados; supporting_slabs permanece no caminho
completo. Esta preparação também não altera estágio nem catálogo.

A primeira prova prepared_context_01 preservou os resultados integrais, mas seus
pontos válidos do grafo não acertavam de fato os volumes introduzidos. Falhou nos
dois oráculos que exigiam impacto. A rodada02 conserva esses oráculos e acrescenta
uma âncora ocupada geometricamente válida, com envelope próprio, para exigir
impacto exato em dois AABBs sobrepostos e depois no temporário. Não confundir
essa prova de narrowphase com permissão para o ator nascer no obstáculo.

## Resultado autoral dirigido atual

prepared_context_02:11/11; prepared_lazy_02:24/24; prepared_dense_02:5/5.
Desvio denso100730,692ms, mesmos8683 estados expandidos/524360 testes e mesmo
route_digest aabbaf78bc22e649b2b6318eb4c31d192084a925f8298cab88af18e60bab5ade
que navigation_dense_01/150296,593ms. Construção6562,905ms, clear58162,722ms,
support31940,769ms. Redução funcionalmente conferida; responsividade completa
segue obrigatória em F9-10. Perfil histórico2/12, não representa o Player20/32.
Comparação integral adicional com produtor eager, regressão e conferência de
inputs ainda serão executadas antes da consolidação. Suíte orgânica15 manteve
Gauss17/512 e corpo20/32,1024 testemunhas públicas + movimento, com pico
contabilizado105254480 no orçamento original268435456. Não é teto de RSS.
