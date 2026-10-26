# F9 — conectores autorais com fragmentos físicos

25/10/2026. Contrato de engenharia fechado para implementação por Sol em F9;
**não é recibo de implementação, auditoria do delta nem aprovação de produto**.
Consulta Astra delimitada por Sol: o refino orgânico transforma uma abertura
real de 80 em várias bordas de 12,5; o mapeamento atual 1:1 rejeita autoria válida.
Base lida: `50ba51ac03960e4eba3cc92729fd557c80290e5d`, com delta F9 de massa
em andamento, branch `codex/map-editor-f9`, checkout `.tools/map-editor-m5`.
Dono exclusivo desta nota registrado em [propriedade](f9_ownership.json).

Precedência: [WORKFLOW](../../WORKFLOW.md), [F9](f9_completion.md),
[semântica de peça](terrain_piece_semantics.md),
[emendas](map_composition_and_seams.md) e [arquitetura](../architecture.md).
Não há escolha nova de produto: largura real, relevo contínuo e autoria por IDs
já estão autorizados. A solução abaixo fecha sua representação técnica.

## Decisão e autoridade

Um conector lógico corresponde a uma abertura contínua da peça autorada e pode
produzir vários endpoints físicos, cada qual pertencente a uma superfície de
suporte convexa/plana real. A divisão é detalhe de compilação; não cria peças,
não aparece como conectores que o usuário deva vincular separadamente.

Manter endpoints canônicos por superfície. Não criar endpoint virtual com área
fictícia, ampliar a superfície de suporte, achatar o relevo, reduzir a abertura,
usar só o fragmento central ou aumentar EPS para fazer o caso passar.
`WorldGeometry` continua a autoridade de corpo, suporte, sweep, path e testemunhas.
O grupo lógico é metadado passivo para resolver identidade e alinhamento; não
substitui geometria nem entra em `stage.connectors` como endpoint adicional.

## Dados compilados e compatibilidade

`source_schema` v1 e documento de composição permanecem iguais: links referem
os IDs autorais; `surface_id` da fonte identifica camada/superfície especial,
nunca a subdivisão técnica. Preservar fonte, SourceHash, undo e referências.
O pacote novo de terreno usa `format_version: 4`, `map_terrain_v4`; a composição
usa `format_version: 3`, `map_composition_v3`. Não emitir formato antigo com
semântica nova. Revisão do assembler e dependências/cache mudam na implementação.

`package.authored_ports: Array[Dictionary]`, ordenado por `connector_id`, contém:

| Campo | Tipo / regra |
|---|---|
| `connector_id` | String: ID da fonte, único na peça |
| `port_id` | String: ID lógico canônico `port_` + SHA256(ID fonte), prefixo20 já usado |
| `surface_id` | String: camada/special da fonte; somente proveniência |
| `position`, `outward` | Vector3: âncora autoral e normal horizontal unitária |
| `width`, `headroom` | float finito positivo: largura XZ e folga autorais |
| `kind`, `tags`, `direction` | Semântica autoral atual; tags canônicas sem duplicação |
| `fragments` | Array de `{connector_id: String, span_id: String, t0: float, t1: float}` |

`t` é distância horizontal assinada a partir da âncora, na tangente
`T = (-outward.z, 0, outward.x)`. Domínio `[-width/2, +width/2]`.
Fragmentos ordenados por `(t0,t1,connector_id)` cobrem esse domínio uma única
vez, sem buraco, sobreposição positiva ou largura zero. Pontas compartilhadas
não são sobreposição. Todos os números e referências são validados, inclusive
em pacote importado; hash consistente sozinho não prova validade geométrica.

`part.connectors` conserva o schema físico existente. Cada fragmento tem posição
no ponto médio de seu intervalo, com y avaliado no plano de sua superfície;
`width = t1-t0`. Normal/kind/tags/direction vêm do lógico. Sua folga é
`min(headroom autoral, headroom garantido da superfície)`; nunca inflar folga.
Folga variável deve usar o menor valor garantido no intervalo. Obstáculos reais
continuam verificados por WorldGeometry, sem inferir passagem da folga declarada.

Um único fragmento conserva `port_id` como `connector_id` físico. Vários usam
IDs derivados de `port_id`, identidade estável do span e limites canônicos do
recorte; verificar colisões. Não usar índice de enumeração, seed ou ordem do array.
A geometria/revisão nova pode mudar IDs físicos; IDs lógicos não mudam por refino.
`boundaries.openings` referencia somente fragmentos físicos daquele span.

Para geração, `ExpeditionPartDefinition` recebe extensão opcional
`connector_groups: Array[Dictionary]`. Registro fechado:
`{connector_id, position, outward, width, headroom, kind, tags, direction,
fragments:[{connector_id,t0,t1}]}`. O ID do grupo é `port_id`; demais valores
vêm do registro autoral acima. O adaptador faz essa projeção sem inventar IDs
nem escolher um representante. `span_id` e superfície autoral ficam no pacote,
pois não são superfícies canônicas da entrada de geração.

Grupos vazios são omitidos por `to_data()`, como `solid_prisms` e
`internal_connections`. Definições antigas sem extensão preservam bytes
canônicos/semântica de `to_data()`. Quando existe grupo com ID igual ao seu
único endpoint, resolução de attachment prefere o grupo; o endpoint não é
candidato adicional. Endpoints de grupo não podem ser escolhidos isoladamente
por receita. Adjacências internas não pertencem a grupos autorais.

## Compilar uma abertura

1. Selecionar somente bordas externas da camada/special indicado. Recortar a
   projeção de cada borda contra o intervalo autoral; exigir colinearidade em XZ,
   normal externa compatível e extensão positiva. Não aceitar quina em planta
   como uma abertura reta. Descartar apenas interseção de medida zero.
2. Avaliar y em ambas as pontas e no centro autoral quando aplicável, nos planos
   reais. A âncora autoral deve coincidir com o suporte no centro. A borda pode
   variar em y ao longo de t, inclusive mudar gradiente entre fragmentos.
   Pontas adjacentes devem concordar em altura; múltiplos pisos disputando o
   mesmo intervalo são ambiguidade, não desempate pelo primeiro array.
3. Conferir cobertura completa e exclusiva. Buraco, trecho não caminhável,
   normal errada, camada errada ou folga insuficiente para o perfil requerido
   invalidam a abertura inteira com diagnóstico do conector e intervalo.
4. Validar cada endpoint contra sua superfície e fronteira. Largura mínima de
   corpo aplica-se à abertura/união útil, nunca a cada fragmento isolado.
   Validar alcance real do perfil na união local, preservando obstáculos e
   conexões internas. O filtro legado `fragment.width >= 2*radius` não pode
   excluir adjacência nem decidir conectividade no compilador/testemunha.

A publicação para um perfil exige suas provas geométricas reais. `PROFILE` do
editor não torna o pacote transitável para qualquer mob: perfis maiores são
revalidados pelo consumidor. Recusar folga insuficiente não autoriza alterá-la.

## Vincular 1:1, 1:N e N:M

Resolver IDs lógicos antes de qualquer expansão. Uma abertura autoral participa
de no máximo um link; reservar o grupo inteiro de modo atômico. Duplicação ou
falha não pode deixar metade dos fragmentos usada.

Alinhamento usa âncoras/normal lógicas, respeitando placement manual e rotações
permitidas. Não alinhar pelo primeiro fragmento. Mantêm-se proibições de escala,
espelho e correção automática de y. Para grupos do editor, preservar a regra
atual de emenda: mesma largura/folga autoral, kind igual, ao menos uma tag comum
e sentido compatível. A folga efetiva é o mínimo físico dos dois lados.
O caminho de geração desses grupos usa o mesmo predicado; endpoints legados
sem grupos conservam suas regras existentes, inclusive tags/compatibilidade.

Projetar ambos os lados transformados no eixo t do lado A; a tangente do lado
B se inverte quando as normais são opostas. Ordenar a união dos pontos de corte
A/B. Para cada intervalo positivo dessa partição comum:

- Exigir exatamente um fragmento A e um B cobrindo todo o intervalo.
- Conferir coincidência XZ e altura nas **duas pontas** usando os respectivos
  planos; igualdade somente dos centros não basta. Planos lineares entre essas
  pontas garantem coincidência no interior. Descontinuidade em um nó falha.
- Recortar ambos os endpoints para o intervalo comum e emitir uma conexão
  física coincidente, com flags forward/backward derivadas dos sentidos lógicos.
- Substituir os endpoints originais consumidos pelos recortes no manifesto
  realizado e atualizar todas as referências físicas de openings/uso. Não
  conservar endpoints fantasmas nem uma conexão por inteiro mais suas filhas.

Os pacotes de origem não são mutados. Recortes pertencem à realização do mapa;
IDs determinísticos derivam do link, fragmentos originais e intervalo canônico.
Sem divisão, conservar o ID físico/connection_id simples existente quando possível.
Preservar proveniência da realização para diagnóstico e seleção do link lógico.

Usar o mesmo operador puro de partição/compatibilidade na composição e no
assembler (API interna a concretizar por Sol: `resolve_port`, `partition_link`,
`validate_port_group`). Resultado contém `ok`, diagnóstico e, no sucesso,
endpoints/conexões/remapeamento completos. Falha não publica dados parciais.
Não copiar matemática em UI, adaptador ou testemunha. `validate_port_group`
revalida cobertura e referências recebidas, sem confiar no compilador anterior.

O assembler precisa transportar **todas** as conexões externas, além das
`internal_connections`. O campo singular de placement atual não pode descartar
filhas. O adaptador e flatten do manifesto devem ser atualizados juntos;
manifesto de runtime continua tendo endpoints físicos e lista de conexões.
Conexões/solids/catálogo são imutáveis; nenhum estado da run volta à definição.

## Fechamento, corpo e precisão

Fechamento subtrai a união dos intervalos físicos vinculados de cada boundary,
na mesma parametrização; distinguir largura XZ de comprimento 3D inclinado.
Fragmentos vizinhos não geram paredes nos nós. Trechos restantes continuam
fechados, com dono único e apresentação correspondente. Abertura lógica sem
link continua erro de publicação de composição, mesmo com N fragmentos.
O recorte não elimina massa de terreno nem cria suporte sobre vazio.

Disco que cobre vários fragmentos cruza se cabe na união local real e respeita
sentido, suporte, folga, obstáculos e limites externos. Não somar larguras de
fragmentos desconectados nem exigir disco contido em um só. Testemunha de grafo
não substitui path/sweep do corpo. Conexões estreitas não são licença para
atravessar fenda, parede, degrau incompatível ou direção proibida.

Projeções/interseções e comparação de cortes usam cálculos escalares f64 antes
de conversão a Vector3. Manter tolerância numérica justificada e domínio vigente;
não fazer snap geométrico que una gaps reais ou altere SourceHash. Distinguir
ponto compartilhado de intervalo positivo pequeno; se resolução não permite
representá-lo, emitir diagnóstico, nunca apagar trecho silenciosamente.

Códigos estáveis mínimos: `connector_invalid`, `connector_ambiguous`,
`connector_coverage`, `connector_reused`, `opening_unlinked`, `seam_position`,
`seam_dimensions`, `seam_orientation`, `seam_direction`, `seam_tags`,
`insufficient_headroom`, `geometry_precision_limit`. Diagnóstico traz ID lógico,
span/intervalo e localização quando disponíveis, com mensagem pt-BR.

## Migração e provas obrigatórias dentro de F9

1. Implementar/validar DTOs e operador comum, depois terrain compiler e
   composição, depois PartDefinition/validator/assembler/adaptador. Registrar
   propriedade nominal de arquivos novos antes de editá-los. Não liberar
   consumidor parcial que usa somente o primeiro fragmento.
2. Fonte v1 não precisa de migração. Recompilar fonte para pacote novo com
   revisão/hash novos, mantendo revisão antiga imutável. Pacote antigo sem
   fonte só pode ser lido por caminho legado explícito ou recusado com versão
   incompatível; não converter silenciosamente nem reutilizar cache antigo.
   Expedições realizadas existentes não são recompiladas/reescritas.
3. Testar abertura80 sobre subdivisões12,5 (inclusive pontas parciais), 1:1,
   1:N e N:M com cortes diferentes, plano inclinado e borda por trechos com
   gradientes diferentes que coincidem. Oráculo independente de intervalos e
   alturas; largura total deve continuar80 em todos os caminhos.
4. Negativos: gap no meio, sobreposição, referência/camada errada, alias de
   grupo/endpoint malformado, normal invertida, alturas iguais no centro mas
   diferentes nas pontas, folga insuficiente, link repetido e abertura órfã.
   Tags/sentidos permitidos e proibidos exercitam as duas autoridades consumidoras.
5. Path e sweep fora do centro, cruzando nós, corpo maior que cada fragmento e
   menor que a abertura; corpo grande demais, obstáculo central/lateral, limite
   externo, sentido único e ponte sobre camada inferior. Conferir barreiras,
   sólidos e clique/suporte no mapa realizado, sem alterar fixture para passar.
6. Reordenar arrays de fonte, spans e candidatos sem mudar resultado; mesma
   seed/revisões geram mesmo manifesto/hash. Salvar/reabrir, undo/redo, GUI/AX,
   bundle/export e jogo preservam IDs lógicos e comportamento. Provar que
   referências físicas não vazam para links autorais e que legacy `to_data()`
   permanece idêntico sem extensões. Export release deve executar o pacote real.
7. Sol seleciona regressão por impacto via `tools/verify.ps1`; Luna supervisiona
   execução/erros/hashes na fixture sequencial. Registrar orçamento real de
   fragmentos/conexões e falha explícita se excedido, sem truncar. Amostra visual
   verifica emenda inteira, acabamento e ausência de barreiras duplicadas.

## Evidência e limites desta consulta

Conferidos contratos acima, propriedade e fronteiras atuais em terrain_compiler,
map_compiler, assembler_adapter, PartDefinition, input_validator, assembler e
`fixture_geometry.connector_valid`. A API física atual já avalia largura em XZ
e suporte no plano; não requer superfície virtual para esta representação.
As APIs comuns propostas nesta nota ainda não existem e precisam de implementação.

Entrega exclusivamente documental: nenhum runtime, teste, runner, amostra ou
save alterado; Godot e suíte de gameplay não executados. As evidências anteriores
informadas por Sol não foram auditadas nesta consulta. Não certifica desempenho,
terreno orgânico, export ou F9 completo; não resolve faces >45°, catálogo visual,
WFC, natação/salto ou renderer. Esses requisitos conservam seus contratos próprios.
Não há decisão humana nova bloqueando esta fronteira técnica.
