# E07 — guia de mundo, montagem e altura

Atualização22/10: as aprovações posteriores e APIs F1–F6 estão indexadas no
[registro de decisões](../e07_decisions.md) e no [recibo integrado](../f1_f6_integration.md).
As propostas e pendências da versão arquitetural abaixo são históricas quando
substituídas por esses registros; não reabrir decisões já respondidas.

Arquitetura v1,18/10/2026. [Contrato](../../e07_contract.md),
[decisão D05](../e07_decisions.md). Interfaces aqui são novas. Regras de combate D05 aprovadas em18/10; apresentação visual ainda pendente.
O registro D05 e o despacho F1 prevalecem sobre as menções históricas a proposta
neste guia. Lógica espacial pode iniciar; integração visual aguarda resposta.

## Evidência e escolha técnica

ArenaNavigation usa AStar2D, Vector2 e Rect2; `get_path`, `is_segment_clear` e
`add_temporary_segment` não identificam superfícies. `RunController._configure_world`
instala os obstáculos predefinidos de PlaytestGameplay. Aumentar BOUNDS não cria
mapa modular, ponte sobre rota nem combate com altura.

Propor WorldGeometry como autoridade lógica independente do renderer. Um ponto
tem stage_id, surface_id e Vector3 (x/z horizontal, y altura). Uma superfície
tem polígono navegável triangulado e altura contínua por triângulo; rampa não é
salto de layer. Pontes têm piso superior e volume sólido, deixando passagem
inferior apenas onde o volume realmente permite. Usar malha/grafo próprio com
consultas tipadas não exige converter o jogo em Node3D.

Mapas planos legados têm adaptador com y=0 e uma surface_id, preservando seus
resultados. Não achatar E07 em Vector2 dentro do ator. A camada de projeção faz
world_to_screen e screen_ray; só ela conhece câmera/desenho. Distâncias de gameplay
nunca são pixels já projetados. A conversão inicial mantém a unidade horizontal
do combate atual; qualquer escala diferente precisa de migração contratada.

## Contrato das partes e montagem

PartDefinition é imutável. Inclui revision/hash, superfícies, blockers sólidos,
conectores e sockets: entrance, exit, objective, thematic_encounter, population.
Cada conector tem ID, posição/orientação local, superfície de origem/destino,
largura útil, altura/extensão vertical livre, sentido de travessia, tipo e tags
de compatibilidade. Exigir continuidade geométrica além de tags iguais.

PartInstance fixa instance_id, definição/revisão e transformação admitida pela
receita. Não espelhar/escalar parte arbitrariamente se a autoria não declarou
suporte. Validador compara conectores transformados com tolerância técnica
documentada (erro numérico, nunca tamanho de degrau jogável), folga para o maior
raio contratado e altura livre. Espaço sobreposto só é legal com superfícies
distintas e volumes sem interpenetração indevida. Porta local é conector navegável,
portal de viagem é aresta de grafo entre estágios; não são intercambiáveis.

Algoritmo inicial proposto: grafo de estágios/obrigações primeiro; busca de encaixe
de partes por restrições depois. Ordenação de candidatos por ID, sorteio em stream
de layout separado, backtracking com orçamento finito. Receita exige max_attempts
e max_expansions; fixtures usam 32/4096 para provar término, sem tratá-los como
tuning de produção. Esgotamento retorna diagnóstico determinístico com seed,
conector/obrigação e contagem; nenhuma substituição silenciosa por arena fixa.

Antes de aceitar a montagem, provar: caminho da entrada a todas as saídas usadas,
slots obrigatórios, memoráveis e objetivos. Percurso de limpeza não pode exigir
atravessar portal que depende da própria limpeza. Ramo opcional pode conter
objetivo de quest, desde que alcançável e sinalizado; rotas mutuamente exclusivas
que impossibilitam um objetivo obrigatório geram erro antes de iniciar expedição.
O manifesto guarda os caminhos testemunha por TraversalProfile (raio, altura,
tipos de conector permitidos) e as entradas/versionamentos completos.

Captura de objetivos é um DTO imutável produzido na entrada, com objective_id,
revision, required_tags, destino e outcome permitido. Sem quest engine pronta,
apenas fixtures técnicas o fornecem. Não capturar quest nova silenciosamente no
meio da expedição; anexar objetivo depois requer contrato próprio.

## API espacial a estabilizar em F0/F1

| Operação | Resultado / regra |
|---|---|
| resolve_surface(ray, visibility_context) | SurfaceHit com ponto e normal; ambiguidade falha, sem escolher o piso pelo y de desenho |
| path(from, to, traversal, geometry_revision) | lista de WorldPoints/conectores + revision + custo real; unreachable não retorna aproximação como sucesso |
| sweep(from, to, collider, mask, revision) | fração de contato, normal e volume/superfície atingidos |
| query_attack(shape, source, target, revision) | range_ok, los_ok, affected_surfaces, hit; regra ligada à habilidade |
| reserve_spawn(slot, occupancy, revision) | posição de origem validada ou deferred/blocked; sem teleporte reparador |
| insert/remove_obstacle(id, volume, revision) | revisão nova e rotas invalidadas; mudança não enclausura atores obrigatórios |
| portal_arrival(portal_id, traversal, occupancy) | âncora válida e segura ou destination_unsafe |

PathResult não autoriza executar segmento velho: revalidar no movimento/commit
quando revision mudar. Obstáculos temporários usam ID estável e volume com altura;
parede no piso inferior não bloqueia automaticamente ponte superior. Clipping
por raio também deve respeitar suportes e conectores. Ocultar teto na câmera
não altera a máscara de colisão/LoS.

## Matriz de interação proposta — sujeita a D05

| Família | Distância, superfície e oclusão |
|---|---|
| Clique/movimento | SurfaceHit visível; rota de chão com conectores/rampas, sem atravessar vãos |
| Melee | alcance 3D entre volumes de interação + segmento sem sólido; piso intermediário bloqueia |
| Projétil | trajetória 3D da emissão, sweep contínuo contra atores/volumes; não acertar por sobreposição de sprite |
| Cone/linha | shape 3D orientado no mundo; alvo só se volume/LoS da política permitir |
| AoE de chão/armadilha | ancorada à superfície; propagação conectada dentro de raio, sem atravessar laje só por projeção |
| Explosão aérea | volume 3D e máscara de oclusão explícitos; não herda regra de chão |
| Dash/push | sweep/rota no suporte permitido; para no primeiro bloqueio, não troca de piso por proximidade |
| Teleporte | preservar travessia de obstáculos planos já testada em E06; destino legal/alcance 3D; bloqueio de laje sólida proposto em D05, sem LoS universal |
| AI/leash | percepção pela geometria; perseguição por rota; home e retorno mantêm superfície |
| Cura/suporte | mesma regra espacial declarada da habilidade; suporte não atravessa laje por ser não ofensivo |

Inventariar TODAS as ativas/efeitos atuais afetados em F1; cada uma recebe geometry_rule_id
e teste representativo. Não liberar mapa multialtura com fallback 2D para Caçadora,
Geômetra, paredes, cones, chuva, summons ou canais. Cálculo de dano permanece canônico.
Se exceção muda produto, registrar delta D05; bug dentro da regra vai a Sol.

## Ativação, escala e prova

Primeira prova integra um estágio inteiro pequeno. Não prometer escala por cap
de atores. Manifesto e população total são residentes em dados; atores/visuais
podem ser ativados por região somente depois de equivalência demonstrada.
Não desativar combate, projétil, área ou alvo causal por distância arbitrária.
Regiões com ações cruzando fronteiras permanecem ativas até resolver/capturar.

Política de estágio sem jogador depende de D02. Em qualquer opção, relógio global
avança enquanto expedição ativa, e ondas escrevem estado dos estágios descarregados.
Descarregar não altera limpeza/HP/loot. Estágio suspenso não usa tempo de parede.

Provar rampa real, ponte com passagem inferior, sobreposição de clique, projétil
bloqueado pelo piso e caminho até memorável. Testar conectores invertidos,
largura insuficiente, ausência de socket, seed adversa, exaustão limitada e parede
temporária. Renderer requer inspeção nativa; grafo conectado não prova leitura.
Medir área percorrível, população total/ativa, tempos de montagem/carga/save e
frame time antes de expandir a amostra. Gate low-poly permanece separado.
