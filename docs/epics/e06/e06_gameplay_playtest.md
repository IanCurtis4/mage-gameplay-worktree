# E06 — playtest de mobs, mapas e loot

Pacote adicional autorizado em 13/10/2026. O roteiro abaixo avalia a primeira versão das áreas e do comportamento dos mobs. A validação técnica e a aplicação ficam registradas no [checkpoint](e06_pending_checkpoint.md) e no [recibo de entrega](e06_gameplay_playtest_delivery.json). O aceite humano continua pendente.

Abra o projeto habitual `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/project.godot`. Pare a partida antiga, aceite recarregar os arquivos e execute F5. No menu, escolha personagem/build e inicie a run normal. O treino continua separado.

| Etapas | Área | Nível dos novos mobs e ilvl de seu loot |
|---|---|---|
| 1–2 | Campina dos Géis | 2 / 4 |
| 3–4 | Bosque das Feras | 6 / 9 |
| 5–6 | Ruínas do Núcleo | 12 / 15 |

Cada área mede 2600 × 1700, com entrada segura, câmera acompanhando, obstáculos e grupos separados. As posições têm uma pequena variação por run; a composição das etapas permanece fixa. São 46 mobs principais, até três companheiros e seis escolhas de augment por run completa. As espécies piloto com cartas continuam no nível/ilvl 1; o nome sobre cada mob mostra o nível real.

1. **Mobar e kitear:** aproxime-se de um grupo e conduza-o por um corredor aberto. A aquisição natural exige linha de visão e distância até 420 px. Gel/Mestre/animal têm velocidades de 154/143/176 px/s; a referência do jogador sem penalidades é 220. Debuffs podem mudar essa vantagem.
2. **Disengage:** use obstáculos para perder a visão por quatro segundos ou afaste-se mais de 850 px do ponto onde o mob nasceu. Ele retorna sem atacar, conservando a vida perdida. Durante o retorno, novas provocações não anulam esse limite. É preciso derrotar os mobs principais para concluir a etapa.
3. **Tiers:** observe Gel normal, raro, elite, elite raro e chefe ao longo das etapas. Tamanho, contorno, cor e nome distinguem as categorias. As quantidades finais por run são 37 normais, dois raros, quatro elites, dois elites raros e um chefe.
4. **Mestre das Feras:** aparece nas etapas 4, 5 e 6, respectivamente raro, elite e elite raro. Cada um invoca apenas um animal, exatamente um tier abaixo. O animal não deixa loot nem dá crédito independente; não reaparece após morrer ou após o mestre retornar. Matar o mestre remove seu companheiro.
5. **Loot:** confira a recompensa congelada na morte e recolha o cristal após encerrar o encontro. Cada raro garante pelo menos incomum; cada elite raro, raro; o chefe, épico. Uma qualidade superior substitui o piso. Normais têm 4% e elites 12% de chance de equipamento. Novas peças usam o nível fixo da espécie/origem e o crescimento aprovado; exemplares anteriores mantêm seu poder.
6. **Cartas e augments:** há duas oportunidades de carta de piloto normal em cada etapa e uma de piloto elite nas etapas 3 e 5. Gel, Mestre e animal ainda não têm cartas próprias. Com as taxas atuais, cartas podem não aparecer numa run inteira. Resolva uma escolha de augment por etapa e compare builds entre runs. Cartas/augments são efêmeros; equipamentos coletados permanecem na coleção.
7. **Continuidade:** avance pelas seis etapas, confira nome da área/contador, inventário entre encontros e recompensa única. XP total do roteiro completo: 1400 Base / 1000 Job, usando as curvas existentes. Abandonar ou morrer encerra a run pelas regras habituais.

Relate personagem/build, etapa, ação anterior e resultado. O feedback mais útil agora é sobre espaço para reunir mobs, facilidade de kitear/escapar, duração dos encontros e disponibilidade dos drops. Testes automatizados e capturas não medem diversão, equilíbrio ou FPS. A arte dos novos mobs é provisória; não foi criada uma campanha completa nem novos efeitos de carta.
