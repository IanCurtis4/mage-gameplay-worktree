> Atualização prevalente de 11/10/2026, após as respostas finais: [itemização e execução após T2](itemization_execution.md). Consolida encaixes 0–4, loot por categoria, incomuns apenas stats, cartas sempre passivas e efeitos interessantes conforme mob base elite+. Autoriza encaminhamento em etapas ao Sol; R1 permanece pendente e antecede TX. O texto abaixo conserva o registro anterior nos pontos não substituídos.

# E06 — requisitos de equipamentos, cartas e loot

11/10/2026. **Contrato E06 atualizado antes de conteúdo/interface; fundação ampliada ainda não liberada para implementação.**

Dono exclusivo deste documento: subagente `equipment_loot_planning`, delegado
para registro e discussão de arquitetura. Autorização humana adicional atribuiu
também os arquivos e06_contract.md e e06_tasks.md a esta rodada documental.
Nenhuma criação de chat, dispatch, implementação ou commit faz parte dela.

Referências locais: [contrato vigente](../e06_contract.md),
[tarefas](../e06_tasks.md), [fluxo](../../WORKFLOW.md),
[MVP histórico](../../MVP.md) e [arquitetura](../../ARCHITECTURE.md).

## 1. Autoridade e relação com a revisão atual

O usuário decidiu atualizar o contrato E06 antes de iniciar conteúdo e interface.
O adendo de 11/10/2026 em [e06_contract.md](../e06_contract.md) incorpora as decisões
recebidas e prevalece sobre os limites v1 incompatíveis; a v1 permanece intacta
como referência histórica da R1 de três slots. O mapa de tarefas agora impede
liberação automática de T3/T4 após essa revisão antiga.

Esta tarefa atualiza somente os três documentos atribuídos. A fundação ampliada
exige fechamento das escolhas estruturais, APIs e pacote de execução antes de
implementação. Não altera o candidato R1, a evidência do revisor, E07, playtest
ou master. As propostas e perguntas deste documento não são respostas humanas.

## 2. Decisões humanas recebidas

| ID | Decisão recebida | Limite de interpretação |
|---|---|---|
| H01 | Equipamentos e cartas mudam skills, características, gameplay e passivos; também podem adicionar habilidades. Acessórios podem conceder habilidades ativas. | Não fixa quais habilidades, ranks, custos, teclas, duração da concessão ou restrições de classe. |
| H02 | Cartas são tematizadas pelo mob-base que as dropa. | Não define uma carta por espécie, variantes, categorias de mob-base ou tabela de drop. |
| H03 | Equipamentos são tematizados pelo lugar do drop. | Não define se lugar significa mapa, região, encontro ou outro agrupamento. |
| H04 | Cartas usam ícone genérico de carta. Armaduras usam ícone conforme subtipo: pano, couro, malha, escamas e placas. | Não decide restrição por classe, progressão defensiva por material ou relação entre subtipo e cada slot. |
| H05 | Armas e armaduras têm raridades iguais às de WoW; drop rate depende do inimigo. Somente raro ou superior possui efeitos secundários interessantes; incomuns têm apenas mais stats. | A lista exata, cores, taxas e presença de efeitos em cada raro não foram fixadas. A aplicação da mesma regra a acessórios precisa de confirmação. |
| H06 | Slots: cabeça, pescoço, ombros, braços (punho + luvas), tronco, capa, calças, pés, main hand, off hand e quatro posições livres de berloques/acessórios, como trinkets e anéis. | São dez posições nomeadas mais quatro livres. Não separa punho e luvas nem impõe duas posições de anel/duas de trinket. Compatibilidades permanecem pendentes; acessórios idênticos foram proibidos na rodada seguinte. |
| H07 | Armaduras não aparecem no personagem, salvo o chapéu, que exige modelos 2D por orientação/pose. Cosméticos com slots próprios são futuro, fora deste escopo. | Não fixa matriz de poses/orientações, produção de assets, visibilidade de outros itens ou quais peças de cabeça contam como chapéu. |
| H08 | Mobs também têm raridade: alguns só existem a partir de certa raridade; outros são exclusivos de uma raridade específica, como um artefato de mapa no estilo WoW. | Não equipara taxonomia de mob e item; o significado preciso de artefato de mapa precisa ser esclarecido. |
| H09 | Drops e cartas seguem a raridade do mob, mas a qualidade da carta não muda com a raridade desse mob: a carta acompanha o mob-base. Mobs de base mais alta têm cartas melhores. | Preserva a distinção mob-base versus raridade da ocorrência. Não decide se raridade altera chance, quantidade, elegibilidade ou uma combinação; não define o eixo de base mais alta. |
| H10 | Referências de poder/estilo: WoW Classic, WoW Forever e equipamentos/cartas de Ragnarok. | Referências não importam automaticamente regras, números, tabelas, taxas, duração da propriedade ou taxonomias. Links de WoW Forever fornecidos pelo usuário constam abaixo; suas regras não puderam ser verificadas na consulta. |
| H11 | Reutilizar habilidades das classes para mobs, equipamentos e cartas; criar efeitos novos pensando também em augments. | Não autoriza duplicar fórmulas, liberar kits indisponíveis ou copiar toda a lógica específica de um ator para outro. |
| H12 | Hierarquia de stackabilidade: augments > cartas > equipamentos. | Inclui cópias repetidas e soma de bônus, sem limite global de efeitos simultâneos. Cartas iguais podem ocupar vários encaixes na mesma peça; equips com mesmo nome de efeito não podem ser usados juntos. Quantidades não fixadas. |
| H13 | Hierarquia de poder: augments > equipamentos > cartas. | Falta definir unidade de comparação: efeito individual, peça inteira ou contribuição total na build. |
| H14 | Hierarquia de dificuldade de acesso: cartas > equipamentos > augments. | Considera chance de drop e frequência de oportunidades em conjunto; números e taxas não fixados. |

Não foi recebida nova decisão sobre persistência de cartas, cópias na coleção,
quantidade de encaixes, retirada de cartas, perda ao morrer, armas de duas mãos
ou restrições dos materiais. Cartas repetidas na mesma peça e veto a acessórios
idênticos estão confirmados; não são mais perguntas abertas.

## 3. Deltas sobre a base histórica v1

| Fronteira histórica v1 | Requisito novo e impacto a contratar |
|---|---|
| §1/§6: weapon, armor e accessory; coleção compartilhada sem cópias; presets por personagem | H06 amplia para 14 posições. Exige correspondência explícita de IDs/slots existentes, validação, presets, migração e UI. Não escolher destino de cada item legado sem contrato. |
| §1/§6: carta única por ID na run, efêmera; um encaixe por equipamento; sem reposição | H12 e a segunda rodada substituem a unicidade e um encaixe de D3 no alvo ampliado: vários encaixes por peça, cartas iguais permitidas na mesma peça. Quantidades pendentes. V1 permanece apenas o contrato da fundação em R1; runtime não foi alterado nesta rodada. |
| §1: raridades excluídas; §8: 12 equipamentos/6 cartas e starters fixados | H02–H05/H08–H09 exigem metadados e conteúdo de origem, qualidade e elegibilidade. Os lotes atuais não garantem cobertura do novo inventário. Contagens e IDs futuros precisam de revisão, preservando aquisições existentes. |
| §4: item não ensina skill; transformações operam em alvos aprendidos e eixos delimitados | H01/H11 pedem concessão de habilidades, adaptação para mobs e novos efeitos. É extensão de domínio/execução, não apenas receita de T3. Exige separar skill aprendida de skill concedida e esclarecer conflitos com o kit. |
| §4: conflitos exclusivos rejeitam a mudança; ordem/origem não criam prioridade oculta | H12–H14 são hierarquias de design. Equipamentos de mesmo nome de efeito rejeitam a combinação inteira; nenhuma prioridade ou supressão silenciosa. Famílias cross-origin ainda precisam de formalização. |
| §7: prêmio por etapa; API demonstrativa; campanha/cadência final pertencem a E07 | H03/H05/H08/H09 relacionam loot a lugar, mob-base e raridade do mob. Precisa decidir se substitui, complementa ou mantém a recompensa por etapa e qual fronteira pertence à expansão de E06. E07 não é liberado por este documento. |
| §8/T3: ícones no pipeline existente, sem arte de personagem; T4 sobre APIs F2 | H04/H07 incluem subtipos e chapéus visíveis. Exigem contrato de apresentação, assets e inspeção de poses/orientações; consumidores afetados dependem de nova API estável. |
| §8: 10 identidades disponíveis, 5 bloqueadas; duas builds por identidade | Referências e reutilização de habilidades não ampliam o roster. A nova cobertura de conteúdo/builds deverá ser declarada; não reduzir a cobertura vigente por suposição. |

Mantêm-se como base a preservar na proposta: catálogo imutável, estado runtime
separado, autoridades únicas de stats/dano/save, snapshots, prevenção de cascatas,
transações/retries idempotentes, troca sem cura, proteção do perfil e texto pt-BR.
Qualquer exceção necessária deve ser um delta explícito, com justificativa e prova.

## 4. Proposta técnica complementar, ainda dependente de contrato executável

Separar cinco informações no domínio: identidade do mob-base, raridade da
ocorrência do mob, origem espacial do equipamento, raridade do equipamento e
identidade da carta. Assim, variar a ocorrência do mesmo mob não cria por acidente
uma versão mais forte de sua carta. A definição do mob-base aponta as cartas
possíveis; a regra de loot consulta os eixos autorizados sem fundi-los num único
número de raridade. Nomes finais de campos e classes só após o contrato.

Representar skills aprendidas e concedidas como fontes diferentes de acesso à
mesma habilidade, quando a semântica permitir. Um catálogo compartilhado de
habilidades/efeitos pode servir classe, mob, item, carta e augment, com adaptadores
explícitos de alvo, recursos, execução e apresentação. Não pressupor que a skill
inteira de qualquer classe seja transplantável sem contrato próprio.

Manter a transação persistente de aquisição/equipamento separada da emissão de
loot e do uso runtime de habilidade. Reutilizar as autoridades existentes, com
migração declarada para os slots e eventuais versões de catálogo/schema; não
criar outro save ou remapear silenciosamente IDs. Não escolher já uma nova versão.

Separar ícone do inventário e apresentação do chapéu no ator. Ambos consomem o
item equipado, mas somente a composição de gameplay altera stats/skills. O
contrato visual deverá declarar âncoras, camadas, poses e orientações compatíveis
com a animação existente antes da produção em lote.

## 5. Respostas recebidas e pendências restantes

Primeira rodada apresentada pela coordenação via pergunta assíncrona:

- **Entrega:** atualizar o contrato E06 antes de iniciar conteúdo e interface.
- **Referências:** o usuário forneceu as três URLs de WoW Forever abaixo; não
  respondeu a lista exata de raridades de itens/mobs nem a unidade de poder.
- **Acúmulo e acesso**, resposta literal:

> Tanto cópias repetidas como soma de bônus. A quantidade de efeitos simultâneos
> é ilimitada. Equips não podem stackar efeitos com o mesmo nome (então nada de
> acessórios iguais, pese em "unique-equipped"). Dificuldade envolve tanto chance
> de drop como frequência de oportunidades.

Segunda rodada apresentada pela coordenação e respondida pelo usuário:

| Decisão | Resposta | Consequência |
|---|---|---|
| Cartas iguais e encaixes | Vários encaixes por peça; cartas iguais podem ocupar a mesma peça | Substitui unicidade por tipo e um encaixe da v1. Quantidade por peça ainda não escolhida. |
| Equipamentos diferentes com mesmo nome de efeito | Impedir equipar os dois juntos | Rejeitar a combinação, sem escolher o maior efeito nem desativar um silenciosamente. Acessórios idênticos já estão proibidos. |
| Limite causal | Manter a proteção, mas revisar o teto de 16 | Preservar anti-cascata; reprojetar orçamento por ação/raiz e validar. Sem número substituto inventado nem autorização de procs infinitos. |

Não confundir efeitos simultâneos ilimitados com infinitas aplicações por ação,
infinitos stacks de uma carta ou slots físicos infinitos. O design não terá teto
global de efeitos ativos; encaixes, cópias por efeito e orçamento causal continuam
eixos próprios. Os 16 atuais são critério histórico de R1, não teto aprovado da
expansão. A soma de efeitos de nomes diferentes não deve ser truncada a 16 fontes.

Pendências de decisão de produto antes dos respectivos consumidores:

- **Fundação:** quantidade/distribuição de encaixes; limites de cópias/stack por
  efeito; compatibilidade das mãos; duração/rank/acesso das habilidades concedidas.
- **Conteúdo:** lista exata de raridades de itens e de mobs; unidade de poder
  (efeito individual, peça ou contribuição total); o que significa mob-base mais
  alto e artefato de mapa; efeito de raridade sobre chance/quantidade/elegibilidade;
  loot por mob versus recompensa por etapa e delimitação do lugar de origem.
- **Apresentação:** cobertura inicial de itens e chapéus, matriz de poses/orientações
  e política dos subtipos. Cosméticos próprios continuam fora do escopo.

Decisões técnicas a preparar de forma revisável, sem transformar propostas em
respostas humanas: chave estável de equivalência de nomes de efeito; famílias
cross-origin; migração de IDs/presets; orçamento causal substituto e suas provas;
semântica de retirada de fonte/cooldown/emissões em voo. Cada escolha de produto
que surgir dessas propostas volta ao usuário; não emitir outra bateria de
perguntas nesta rodada. Persistência efêmera das cartas e coleção compartilhada
não foram alteradas pelo usuário e conservam as regras anteriores nesses pontos.

## 6. Marcos e dependências propostos, sem dispatch

Os nomes abaixo organizam resultados; não são novos épicos autorizados nem
ordens de execução. A escolha humana os inclui no planejamento do E06 antes de T3/T4.

| Marco proposto | Resultado revisável | Dependências e saída |
|---|---|---|
| P1 — fechar escolhas e extensão contratual | Matriz de slots/compatibilidade; raridades; regra mob-base/carta; hierarquias operacionais; habilidades concedidas; limites da entrega | Adendo documental já atualizado; fechar quantidades/semânticas restantes e APIs antes de execução. R1 atual continua somente na base histórica. |
| P2 — fundação ampliada completa | Inventário/presets/migração, acesso a habilidades por fontes, composição e contratos de loot por identidade/origem/raridade | P1 e base técnica exata. Sol, esforço Alto proposto. Rever fronteira crítica completa e respectivas invariantes antes de conteúdo/UI dependentes; sem gate por microtarefa. |
| P3 — conteúdo e apresentação sobre fundação estável | Famílias de drops/cartas e builds demonstrativas; inventário ampliado; ícones e chapéu compatível com animação | P2 validado. Conteúdo e UI/arte podem ser paralelos só com APIs estáveis e donos disjuntos; Terra, esforço Alto proposto. Lote, cobertura e assets a escolher, não contagens inventadas. |
| P4 — candidato integrado e aceite | Loop real de aquisição/uso, migração preservada, comparação de builds e apresentação legível | P3 completo. Integração/revisão proporcional ao risco; playtest após aprovação técnica, merge apenas após aceite humano do candidato. |

A cadência final de campanha continua dependente de contrato/autorização próprios.
O usuário escolheu incorporar a expansão antes do conteúdo/interface; o contrato e
o mapa foram atualizados. A futura execução ainda deve transferir donos
explicitamente e identificar quais evidências antigas são compatíveis e quais
precisam de reprodução independente para a fundação ampliada.

Provas a contratar, sem execução nesta rodada: migração dos slots/presets sem
perda; concessão/remoção de habilidade com cooldown e emissão em voo; conflito
entre fontes; estabilidade da carta ao variar raridade do mesmo mob; elegibilidade
por mob-base/lugar; replay/falha de coleta; hierarquias na unidade escolhida;
renderer do inventário e chapéus nas poses/orientações acordadas.

## 7. Referências e validação documental

Referências fornecidas pelo usuário:
[Blizzard](https://worldofwarcraft.blizzard.com/pt-br/forever),
[Wowhead](https://www.wowhead.com/forever/pt) e
[Warcraft Wiki](https://warcraft.wiki.gg/wiki/World_of_Warcraft:_Forever).
Consulta em 11/10/2026: a página oficial e a wiki retornaram HTTP403; Wowhead
retornou somente uma página dependente de JavaScript, sem regras úteis para
confirmar raridades/equipamentos. Nenhuma regra externa foi inferida dessa falha.
A referência foi identificada pelo usuário; não está mais pendente de nome/link.

Registro baseado nas decisões repassadas pela coordenação nas duas rodadas e
nos deltas do contrato/tarefas. Requisitos confirmados estão no adendo prevalente;
quantidades/tabelas e escolhas ainda abertas não viraram regras executáveis.

Validação documental: referências locais, coerência de precedência e dependências,
base v1 preservada, diff dos três arquivos autorizados. Sem alteração de runtime,
dados de jogo, save, testes ou checkpoint central; nenhuma suíte de gameplay
executada e nenhum parecer técnico R1 fabricado. A consulta à skill de retomada
não encontrou CLI versionado de workflow nem docs/WORKFLOW_TOOLING.md neste
checkout; nenhuma instalação externa foi escolhida.
