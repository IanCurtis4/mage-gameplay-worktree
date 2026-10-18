# E07-F0 — API executável v1

18/10/2026. Base `e30c49bb6442344ce8d937910ca6170effc70c7a`, branch
`codex/e07-f0`. Contrato consumido: [v1](../e07_contract.md),
[despacho](f0_dispatch.md), [mundo](guides/world_geometry.md).
API disponível **nesta branch**, aguardando integração pela coordenação.
D01–D07 continuam propostas pendentes. Nenhuma policy fixture é aprovação de produto.

## Entrada e resultado

`ExpeditionAssembler.build(input: ExpeditionGenerationInput) -> Dictionary`
é puro: valida, copia e monta sem Nodes, catálogo de produção ou save.
Resultado: `ok: bool`, `error_code: StringName`, `request_id: String`,
`revision: int` (envelope v1), `data: Dictionary`. Sucesso contém
`manifest: ExpeditionManifest`, `hash: String` SHA256 e `diagnostic`
com attempts/expansions/seed_text. Falha contém somente `diagnostic`, nunca
manifesto parcial. A validação pré-busca informa zero attempts/expansions.
No esgotamento de expansions, `cause`, `detail` e `obligation` identificam a restrição/slot.
Diagnósticos estruturais não têm cause/obligation quando estes não se aplicam.

GenerationInput é RefCounted com campos tipados. `parts`, `species`, `policies`
e `traversal` referenciam Resources imutáveis por contrato de autoria; o gerador
não altera nenhum deles. As saídas são instâncias separadas, com DTOs copiados.
`to_data()` captura entrada validada; consumidores de dados externos devem usar
`build`/`ExpeditionInputValidator.validate` antes de chamar capturas diretamente.
Não há decoder de save nem migração nesta API.

| Campo obrigatório | Tipo / regra |
|---|---|
| request_id, phase_id, entry_stage_id, catalog_revision | String técnica não vazia; IDs contêm somente `a-z0-9_` |
| seed_text | String decimal canônica de inteiro signed64, incluindo extremos; sem JSON numérico |
| generator_revision | Exatamente `f0_convex_cells_v1`; indisponível falha explicitamente |
| recipe_revision | int positivo |
| parts | Array[ExpeditionPartDefinition], IDs únicos e revisões positivas |
| species | Array[ExpeditionSpeciesDefinition], elegibilidade espacial, sem stats/dano/loot |
| policies | Array[ExpeditionPolicyDefinition], IDs/revisões/domínios/parâmetros explícitos |
| traversal | ExpeditionTraversalProfile: profile_id/revision, radius > 0, height > 0, connector_kinds não vazios |
| generation_policy_id, population_policy_id | Referência obrigatória ao domínio correspondente |
| stages, portals, objectives, population | Array[Dictionary] com schemas fechados abaixo; valores finitos, sem objetos aninhados |

Stage: `{stage_id, biome, entrance, parts}`. `entrance` é `instance/socket`;
`parts` contém `{instance_id, candidates: Array[String], parent,
parent_connector, connector}`. Um root por estágio, com três referências vazias;
demais nós referenciam parent e conectores locais. Pai ausente/ciclo é inválido.
IDs de instância são locais ao estágio. Candidatos não podem estar vazios ou
repetidos. Não há tamanho de fase de produção escolhido implicitamente.

Portal: `{portal_id, from_stage, from_socket, to_stage, to_socket, kind}`.
Sockets usam `instance/socket`; kind deve ser `travel`. São arestas dirigidas
explícitas do grafo de estágios, separadas de conexões navegáveis entre partes.
Retorno exige aresta explícita. Todos os estágios precisam ser alcançáveis de
entry_stage_id. F0 prova caminhos locais sem atravessar portais condicionados à
limpeza e prova a chegada até a entrada do estágio de destino. Não abre portais.

Objective: `{objective_id, revision, stage_id, instance_id, socket_id,
required_tags: Array[String], outcome, required: bool}`. Outcome é `objective`,
`phase_completion` ou `early_exit`, apenas captura, sem conceder conclusão.
Todo objetivo capturado precisa de local/caminho, inclusive o opcional: optional
não significa autorização para descartar a quest silenciosamente.

Population: `{slot_id, species_id, occurrence_category, origin_id, stage_id,
instance_id, socket_id, required_tags: Array[String], respawn_policy_id,
reward_policy_id, blocks_clear: bool}`. Espécie deve existir na entrada e
aceitar bioma/categoria; socket satisfaz tags da receita **e** da espécie.
IDs de slots/objetivos não podem colidir entre si. Todo slot é testemunhado;
não há simulação de ator/geração/onda/limpeza em F0. Origin e políticas ficam
capturados para seus produtores posteriores, sem cálculo por nível do jogador.

## Resources e geometria admitida

`ExpeditionPartDefinition`: part_id/revision, biome_tags, allowed_rotations
(quartos inteiros 0–3 sem repetição), surfaces, connectors, sockets,
solid_volumes e blockers (Array[AABB], extensões positivas).

`ExpeditionSurfaceDefinition`: surface_id, vertices PackedVector3Array de célula
**convexa, planar e sem vértices colineares consecutivos**, headroom positivo.
A projeção x/z tem área e y é contínuo no plano; triangulação em leque é guardada
no manifesto. Superfícies de rampa podem ter alturas distintas nos vértices.
Células não são uma malha côncava arbitrária: autoria precisa decompor essa malha.
Superfícies desconectadas não ganham ligação por proximidade ou projeção.

`ExpeditionConnectorDefinition`: connector_id, surface_id, position/outward
Vector3, width/headroom positivos, kind, tags e direction (`both`, `in`, `out`).
Outward é normal horizontal unitária voltada para fora da borda. Abertura inteira
fica sobre a borda autorada. Encaixe exige posições coincidentes, normais opostas,
mesmo tipo/tags, direção permitida, largura >= 2*radius e altura >= height.
Apenas rotações declaradas e translação horizontal são admitidas: não espelha,
escala ou eleva para reparar conexão. Diferença de nível exige parte/rampa real.
Tolerância técnica absoluta `1e-5` em unidades de mundo, sem degrau jogável.

`ExpeditionSocketDefinition`: socket_id, surface_id, position, kind e tags.
Kinds: entrance, exit, objective, thematic_encounter, population, portal.
Pontos devem estar sobre o suporte; testemunhas exigem folga de raio/altura.
`ExpeditionSpeciesDefinition`: species_id/revision, biome_tags,
occurrence_categories e required_site_tags; não substitui MobCatalog de stats.

`ExpeditionPolicyDefinition`: policy_id/revision/domain/parameters.
Geração exige exatamente `max_attempts: int > 0`, `max_expansions: int > 0`.
O orçamento de expansions é **global à chamada**, incluindo todas as tentativas.
Population, reward e respawn precisam de declarações presentes com os domínios
certos; F0 preserva parâmetros/revisões e não executa suas regras futuras.
Não existe fallback quando uma referência/domínio está ausente.
Na fixture todos esses Resources são construídos explicitamente como artificiais;
32/4096 e perfil 0,5/2,0 não são tuning ou política de produção.

## Algoritmo, manifesto e consultas

Receita/grafo primeiro, depois busca iterativa com backtracking. Enumeração por
ID e rotação, ranqueada por SHA256 de seed/tentativa/estágio/instância/opção em
stream de layout separado, sem RNG global. Mais de uma variante é efetivamente
realizada no corpus. As tentativas não publicam estado intermediário.

Cada instância guarda definição/revisão/hash e transformação. Superfícies,
conectores, sockets, conexões, portais, população, objetivos e testemunhas usam
o espaço realizado. Identidades geométricas são
`stage/instance/surface|connector|socket/local`; conexões são `stage/child`.
Não usam NodePath, ponteiros, get_instance_id ou ordem de criação de Nodes.

`ExpeditionWorldPoint.create(stage: String, surface: String, point: Vector3)`
retorna instância cujo `to_data()` contém stage_id/surface_id/position.
X/z são horizontais, y é altura; projeção visual ainda não existe.

`ExpeditionManifest.to_data() -> Dictionary`, `canonical_hash() -> String`,
`surface(surface_id: String) -> Dictionary`,
`connector(connector_id: String) -> Dictionary`,
`witness(obligation_id: String) -> Dictionary`,
`population_plan() -> ExpeditionPopulationPlan` consultam cópias profundas.
ID desconhecido retorna `{}`; não é aproximação espacial. Campos `_data`/`_slots`
são internos por convenção GDScript; consumidores usam os métodos.

Manifesto v1: manifest_revision/geometry_revision, input completo e input_hash,
stage_ids, stages realizados, portals, objectives, population, witnesses,
traversal. A entrada contém part_hashes, recipe_hash, catalog_hash e todos os
Resources/revisões. Preservar manifesto realizado além da seed. Nunca regenerar
um mundo existente silenciosamente ao alterar algoritmo/conteúdo.

PopulationPlan oferece `slots() -> Array[Dictionary]`,
`find_slot(slot_id: String) -> Dictionary`, `to_data() -> Dictionary`.
Home de cada slot é WorldPoint resolvido. F0 constrói esse plano dentro do
assembler; o planejador independente de ciclo/população permanece para F5.

Testemunhas: chaves `population/<slot_id>`, `objectives/<objective_id>`,
`portal/<portal_id>/from|to`, `arrival/<portal_id>`, `entrance/<stage_id>` e
`exit/<socket_global_id>`. Dados: profile capturado, geometry_revision, points
WorldPoint, nodes, connection_ids e cost (comprimento 3D efetivo).
O grafo une segmentos retos dentro de células convexas, pontos insetados nos
conectores e costura exata. Busca BFS ordenada prova existência, sem prometer
rota de menor distância. Solids/blockers autorados participam do sweep do
volume vertical do ator, com expansão Minkowski. Contato na fronteira usa a
mesma tolerância. Sem caminho não há aproximação/teleporte como sucesso.
Volumes sólidos de partes distintas não podem interpenetrar; suportes não podem
sobrepor interiores na mesma faixa de altura. O teste de overlap de rampas é
conservador: pode rejeitar autoria avançada válida. Não certifica ponte complexa.

Codificação canônica v1 é tipada, com strings prefixadas pelo comprimento UTF-8,
chaves de dicionário ordenadas e floats IEEE754 little-endian exatos (zero
negativo normalizado). Inteiros são decimais sem arredondamento; Vector3/AABB
possuem marcas próprias. Coleções semânticas por ID/tags/rotações/candidatos são
ordenadas, polígonos preservam ordem de vértices. Request_id é transporte e não
altera conteúdo; seed/revisões/parâmetros/objetivos alteram a entrada/hash.
SHA256 é calculado sobre os bytes UTF-8 da codificação, sem hash circular.

Erros: invalid_payload, invalid_identity, invalid_recipe, duplicate_id,
content_revision_unavailable, policy_unresolved, incompatible_connector,
objective_unreachable, population_unreachable, missing_thematic_site,
incompatible_species, generation_exhausted. A falha mais profunda alcançada é
preservada como diagnóstico; se bater o budget de expansions, ela aparece em cause. Ao esgotar tentativas
com busca exaurida, conserva o erro específico. Uma falha
estrutural ocorre antes da busca. Mesmo input/versões reproduzem diagnóstico.

## Verificação e fronteira de F1/F2

O runner mantém todos os checks anteriores intactos e acrescenta:
`e07_f0_import_test`, `e07_f0_generation_test`,
`e07_f0_adversarial_test`, `e07_f0_consumer_test`.
Listar `-Test 'e07_f0_*' -List` e executar os quatro juntos.
O import padrão da base tenta carregar GitPlugin ausente no engine autorizado;
o check F0 cria projeto fixture sem plugin em
`.godot/verification/e07_f0/fixture_project`, copia fontes byte a byte e registra
source_hashes.json/source_root.txt. Executa importação nativa nesse projeto e os
outros três checks usam exatamente essas cópias. Cada teste confere hashes contra
a origem atual e falha se a cópia estiver obsoleta. Filtrar sem import exige
fontes idênticas. Logs/cache são ignorados, nunca um novo conteúdo de produção.

I01–I03 são a cobertura desta entrega: fixture ramificada, raio/altura/rampa,
objetivos/slots/portais, cópias imutáveis, revisões, seed signed64, ordem,
colisões de IDs, exaustão e erros sem fallback. Isso **não** comprova navegação de
atores, renderer, colisão/LoS de ataques, ponte com clique sobreposto, performance,
balanceamento, compatibilidade de save ou D01–D07 aprovadas.
WorldGeometry e adaptação dos kits são F1; perfil/propriedade são F2. Só consumir
esta API após integração explícita e dispatch dos respectivos produtores.
