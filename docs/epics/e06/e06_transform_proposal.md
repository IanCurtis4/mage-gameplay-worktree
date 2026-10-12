# E06 — proposta de transformações do piloto

PROPOSTA DE PRODUTO/ARQUITETURA: usuário aprovou começar SOMENTE por spiritualist_echo_fixed_origin e geometer_ground_anchor em12/10/2026; outros quatro não autorizados. Consulta Astra/low, somente leitura, em12/10/2026; Sol conferiu os pontos de integração nos estados de eco/drenagem, armadilhas/abertura e construção/triângulo existentes. Não é auditoria do capítulo. A base continua985f6bc e os deltas de execução real do piloto; nenhuma receita abaixo foi adicionada ao catálogo.

Objetivo: duas escolhas exclusivas úteis para cada evolução que hoje só tem apoio numérico no piloto — Espiritualista, Caçadora e Geômetra. Manter os augments numéricos existentes, acrescentar as novas receitas somente após decisão humana. Nomes/flavor finais ficam com Luna depois de contrato mecânico fechado. IDs abaixo são técnicos provisórios; números novos são propostas de tuning piloto no ilvl1, sem progressão/rates.

| Receita proposta | Regra concreta | Decisão em combate |
|---|---|---|
| spiritualist_echo_fixed_origin | Eco usa a posição do portador no agendamento; espera0,35s e mantém raio/dano atuais. Portador precisa continuar vivo; vítimas precisam de alcance e visão a partir do centro capturado. | Marcar o ponto que o inimigo atravessou; o eco deixa de acompanhar quem se afasta. |
| spiritualist_drain_inscription | Ao completar os4 ticks de Drenagem, com último impacto positivo e alvo vivo, aplica marca de Maldição por5s nesse alvo. Potência capturada no início da canalização; exige ambas skills aprendidas. Não dispara eco nesse tick. | Terminar a canalização prepara a próxima ofensiva; interromper perde essa preparação. |
| hunter_marked_mechanism | Colocar Congelante/Piche/Espinhos captura o alvo marcado; só esse inimigo dispara a armadilha. Depois, área/vítimas/controles/abertura seguem regras atuais. Sem marca válida, rejeitar antes de custo. | Preservar a armadilha para a prioridade, deixando inimigos menores passar. |
| hunter_covering_fan | Tiro de Cobertura que consome abertura divide a exploração bruta:50% no alvo e50% em um segundo inimigo até80 unidades com visão. Mais próximo, empate por ID; sem segundo,100% no original. | Trocar pressão concentrada por dano distribuído quando alvos estão juntos. |
| geometer_ground_anchor | Impacto de Traçado/Triangulação cria vértice no ponto real do impacto com carrier_id=0. Elemento, duração, gramática e ordem das entregas continuam atuais. | Manter figura no corredor escolhido, sem deformar com movimento dos portadores. |
| geometer_collapse_first_element | Colapso de triângulo válido consome a figura, mas escolhe a resolução pelo elemento de A em vez de C. Corrente elétrica começa em A; paredes não participam. | Escolher o fechamento e a resolução usando elementos distintos da sequência. |

Para todas: augment restrito à evolução e origem corretas;1 aquisição, sem empilhar política. Nenhuma concede skill/ativa. Exigir rank1 das skills envolvidas e os ranks/slots adicionais já exigidos pelo kit; não reduzir gates de Triangulação/Colapso. As duas opções de cada classe podem coexistir porque mudam eixos diferentes; grupos separados de conflito por política, sem teto global de fontes. Cartas normais/raras não passam a receber transformações por este desenho. Extensão inicial recomendada somente para augments, sem inferir publicação de cartas/equips equivalentes.

## Menor primeiro lote recomendado

Eco com origem fixa + vértices no chão. Ambos mudam posicionamento observável, reaproveitam cálculo/cadência existentes e não redistribuem dano nem criam marcas novas. Esse lote entrega uma transformação por Espiritualista/Geômetra; não completa sozinho as duas opções dessas classes, a Caçadora ou as20 direções finais. Os outros quatro continuam propostos até aceite pertinente.

## Fronteira executável necessária

Nenhuma das seis cabe integralmente nos handlers E06 atuais. Acrescentar capacidade tipada de política de kit, com whitelist fechada por adapter; parâmetros/ranks/restrições validados no catálogo e política resolvida no compositor. Capturar por valor junto à ação pertinente, sem consultar build atual no impacto. Não criar dispatcher arbitrário de eventos/código em strings. IDs/tags editoriais não controlam execução.

Espiritualista: capturar política da onda no primeiro gatilho primário; congelar portadores elegíveis e pares únicos conforme contrato atual. Para a origem fixa, capturar posição de cada portador quando realmente agendado, incluindo propagação finita da mesma onda. A morte do portador cancela o seu eco como hoje. Inscrição requer claim único de conclusão e marca para próxima ação, sem iniciar nova cadeia no tick secundário.

Caçadora: filtro de disparador separado do filtro de vítimas/visão; trocar Marca após colocar não redireciona. Se o alvo capturado morrer antes de disparar, a armadilha não adquire outro alvo e expira pelo prazo normal. Na distribuição, somar as parcelas antes das respectivas defesas, sem prometer dano efetivo total igual; ambos secundários, uma abertura e no máximo um passo, sem procs genéricos de filhos. A parcela baseada na abertura e Disciplina segue a autoridade HunterMath/OpeningState, sem fórmula duplicada.

Geômetra: a política é capturada na reserva/disparo, mas a posição vem do impacto confirmado. Entregas aguardando disparos anteriores precisam conservar ponto real e idade do impacto; não substituir por posição posterior do inimigo. Não alterar gramática, SP de manutenção ou ordem de entrega. Colapso roda a cópia dos pontos para a resolução existente, depois do consumo único, sem repetir fechamento ou deixar figura/efeitos ativos.

Arquivos candidatos (não transferidos nem autorizados por esta lista): effect_definition, build_effect_catalog/composer, captura de skill, player_actor/main e adapters dos estados de eco/drenagem, HunterTrap/OpeningState e construção/GeometerCasting/triângulo. Definir arquivos/donos exatos somente para a opção aceita. Sem save/schema, catálogo ativo, nova classe/skill, UI/arte, campanha, loot, playtest/push/merge.

Provas necessárias: lançamentos reais sem/com receita, posições/elementos/vítimas observáveis; morte, pausa, cancelamento, bloqueio, reentrada e retirada após emissão; snapshot imutável, claim antes de callbacks, nenhum secundário genérico encadeado. Seleção Luna após fontes congeladas, correções Sol; sem auditoria Astra automática. Tuning/ranks/sockets atuais preservados fora da receita escolhida.

Estado: PRIMEIRO LOTE ESCOLHIDO PELO USUÁRIO — eco e vértices fixos, conforme e06_spatial_policies.md. Outros quatro efeitos continuam DECISÃO_PENDENTE.
