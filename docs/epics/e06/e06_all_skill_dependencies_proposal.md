# E06 — dependências das dez identidades jogáveis

**PROPOSTA PARA APROVAÇÃO HUMANA — 15/10/2026. Não autoriza consumidores.**
Base `bedee0d0fac15016f2b10cf2fe7e2e40c0443b55`, branch `codex/e06-inventory`, checkout `C:/Users/João Pedro/.codex/worktrees/e06-inventory/RagRPG`. Escopo e propriedade: [lote documental](e06_all_skill_dependencies_scope.md). Norma: [WORKFLOW](../../WORKFLOW.md). Este arquivo propõe somente requisitos e apresentação; não cria habilidades, efeitos, pontos ou alteração de XP.

## Regras e delta de produto

Cada linha abaixo define o antecedente de R1 e dos ranks seguintes; a compra continua sequencial, um ponto por rank, máximo atual de R5 ativa/R3 passiva. Livre significa sem antecedente, conservando identidade, job e saldo. Requisito mede rank permanente: gratuito de catálogo + grant legado legítimo + compras. Item, rank selecionado no atalho e bônus temporário não satisfazem requisitos. Um combo sugerido não vira requisito implícito.

Preservar todos os requisitos aprovados de Defendente/Berserker. A exceção documental nova é substituir a decisão anterior de deixar a base Espadachim inteiramente aberta: agora propomos cachos também nela, conforme pedido retroativo. `dash`, `shield_wall` e `fury` continuam livres, portanto nenhum caminho já aprovado dessas evoluções recebe custo ancestral extra. As demais bases e cinco evoluções recebem os novos cachos abaixo. Raízes independentes permitem cruzar rotas sem tronco geral; cadeias possuem até três nós, inclusive quando atravessam abas.

Não converter skills iniciais em compras: as sete entradas de evolução conservam R1 gratuito. No catálogo atual as bases têm `free_rank=0`; personagens novos não recebem gratuitamente seu antigo kit. Saves históricos conservam grants R1 de Corte/Investida/Resistência e Bola de Fogo/Parede de Fogo/Regeneração de SP. Todos esses nós permanecem livres. Não inventar grants novos para corrigir a progressão.

## Mapa completo (93 IDs)

Os nomes são visíveis; IDs identificam sem ambiguidade cada nó. Nas três bases o job mínimo continua 1 para todos os ranks. Nas evoluções o número da coluna Job permanece igual em todos os ranks. `Grátis` aplica-se somente a R1.

### Espadachim — 13 skills, carteira Base

| Habilidade / ID | Antecedente |
|---|---|
| Corte em cone `slash` | Livre |
| Investida `dash` | Livre |
| Parede de Escudos `shield_wall` | Livre |
| Provocar `provoke` | `shield_wall` R2 |
| Perseverança `perseverance` | `shield_wall` R2 |
| Grito Perfurante `piercing_shout` | Livre |
| Fúria `fury` | Livre |
| Golpe Brutal `brutal_strike` | `slash` R2 |
| Raiva Concentrada `concentrated_rage` | `brutal_strike` R2 |
| Grito Aterrorizante `terrifying_shout` | `piercing_shout` R2 |
| Resistência `swordsman_resistance` | Livre |
| Vigor `vigor` | Livre |
| Sede de Sangue `blood_thirst` | `fury` R2 |

Guarda, mobilidade, pressão e recuperação permanecem entradas distintas. Investir em Fúria para Sede não exige manter o buff ativo.

### Mago — 13 skills, carteira Base

| Habilidade / ID | Antecedente |
|---|---|
| Bola de Fogo `fireball` | Livre |
| Parede de Fogo `fire_wall` | Livre |
| Lança de Fogo `fire_spear` | `fire_wall` R2 |
| Lança de Gelo `ice_spear` | Livre |
| Relâmpago `lightning` | Livre |
| Descarga Elétrica `electric_discharge` | `lightning` R2 |
| Parede de Raios `lightning_wall` | `electric_discharge` R2 |
| Impacto das Almas `soul_impact` | Livre |
| Assombro `haunt` | `soul_impact` R2 |
| Barreira Fantasma `phantom_barrier` | Livre |
| Parede de Gelo `ice_wall` | `ice_spear` R2 |
| Teleporte `teleport` | Livre |
| Regeneração de SP `mage_mana_regeneration` | Livre |

Fogo favorece queimadura; raio oferece uma progressão curta de formatos; gelo e espiritual mantêm entradas próprias. Barreira Fantasma e Teleporte são escolhas defensivas independentes.

### Arqueiro — 11 skills, carteira Base

| Habilidade / ID | Antecedente |
|---|---|
| Disparo Duplo `double_shot` | Livre |
| Flecha Perfurante `piercing_arrow` | `double_shot` R2 |
| Chuva de Flechas `arrow_rain` | `piercing_arrow` R2 |
| Mira Estendida `extended_aim` | Livre |
| Armadilha de Laço `snare_trap` | Livre |
| Armadilha Explosiva `explosive_trap` | `snare_trap` R2 |
| Flecha Entorpecente `slowing_arrow` | Livre |
| Abrigo de Folhagem `foliage_shelter` | Livre |
| Precisão `archer_precision` | Livre |
| Cadência `archer_cadence` | `double_shot` R2 |
| Técnica de Armadilhas `trap_technique` | `snare_trap` R2 |

Disparos, armadilhas, preparação e cobertura não exigem investir uns nos outros.

### Defendente — 9 skills, carteira Evolução; requisitos aprovados preservados

| Habilidade / ID | Job | Antecedente |
|---|---:|---|
| Contraforte `defender_counterstroke` | 20 | Livre; grátis |
| Vigília `defender_watch` | 23 | Livre |
| Marco de Guarda `defender_anchor` | 25 | `shield_wall` R2 (Espadachim) |
| Trava de Linha `defender_line_lock` | 28 | `defender_anchor` R2 |
| Resguardo `defender_guard_return` | 31 | `defender_counterstroke` R2 |
| Avanço de Muralha `defender_wall_advance` | 34 | `dash` R2 (Espadachim) |
| Onda de Represália `defender_reprisal_wave` | 37 | `defender_counterstroke` R3 |
| Rebater `defender_riposte` | 31 | `defender_guard_return` R2 |
| Guarda de Retirada `defender_retreat_guard` | 25 | Livre |

### Berserker — 9 skills, carteira Evolução; requisitos aprovados preservados

| Habilidade / ID | Job | Antecedente |
|---|---:|---|
| Ruptura `berserker_rupture` | 20 | Livre; grátis |
| Obstinação `berserker_obstinacy` | 23 | `fury` R3 (Espadachim) |
| Salto Cruento `berserker_wound_leap` | 25 | `dash` R2 (Espadachim) |
| Execução `berserker_execution` | 28 | `berserker_rupture` R3 |
| Caça Persistente `berserker_pursuit` | 31 | `berserker_rupture` R2 |
| Fenda Sangrenta `berserker_blood_rift` | 34 | Livre |
| Arrancar Fôlego `berserker_breath_steal` | 37 | `berserker_pursuit` R2 |
| Talho de Perseguição `berserker_pursuit_cut` | 31 | `berserker_wound_leap` R2 |
| Hemorragia Profunda `berserker_deep_bleeding` | 37 | `berserker_blood_rift` R3 |

### Elementalista — 7 skills, carteira Evolução

| Habilidade / ID | Job | Antecedente |
|---|---:|---|
| Explosão de Chamas `elementalist_flame_burst` | 20 | Livre; grátis |
| Foco Prismático `elementalist_prismatic_focus` | 23 | Livre |
| Anel Glacial `elementalist_glacial_ring` | 25 | `ice_spear` R2 (Mago) |
| Arco Voltaico `elementalist_lightning_arc` | 28 | `lightning` R2 (Mago) |
| Ressonância Prismática `elementalist_prismatic_resonance` | 31 | `elementalist_prismatic_focus` R2 |
| Trilha de Brasas `elementalist_ember_path` | 34 | `elementalist_flame_burst` R2 |
| Nova Tríplice `elementalist_tri_nova` | 37 | `elementalist_glacial_ring` R2 |

A alternância de elementos continua efeito/combo, sem exigir comprar todos os elementos ou passivas. A rota de Nova tem três nós contando Lança de Gelo; Foco é entrada própria de sustentação.

### Espiritualista — 7 skills, carteira Evolução

| Habilidade / ID | Job | Antecedente |
|---|---:|---|
| Maldição do Eco `spiritualist_echo_curse` | 20 | Livre; grátis |
| Recolhimento `spiritualist_echo_recovery` | 23 | `spiritualist_echo_curse` R2 |
| Drenagem Espiritual `spiritualist_soul_drain` | 25 | Livre |
| Véu Espectral `spiritualist_spectral_veil` | 28 | `phantom_barrier` R2 (Mago) |
| Foco do Além `spiritualist_channel_focus` | 31 | `spiritualist_soul_drain` R2 |
| Procissão de Espectros `spiritualist_procession` | 34 | `soul_impact` R2 (Mago) |
| Rito de Dissipação `spiritualist_dissipation` | 37 | `spiritualist_echo_curse` R3 |

Eco, canalização e proteção formam rotas próprias; Recolhimento não é pedágio para Rito.

### Sentinela — 9 skills, carteira Evolução

| Habilidade / ID | Job | Antecedente |
|---|---:|---|
| Tiro na Cabeça `sentinel_headshot` | 20 | Livre; grátis |
| Observar `sentinel_observe` | 20 | Livre |
| Postura de Precisão `sentinel_precision_stance` | 23 | `extended_aim` R2 (Arqueiro) |
| Tiro Perfurante `sentinel_piercing_shot` | 25 | `piercing_arrow` R2 (Arqueiro) |
| Tiro de Rede `sentinel_net_shot` | 28 | Livre |
| Tiro Explosivo `sentinel_explosive_shot` | 31 | Livre |
| Leitura de Aberturas `sentinel_opening_read` | 31 | `sentinel_observe` R2 |
| Tiro de Concussão `sentinel_concussion_shot` | 34 | `sentinel_net_shot` R2 |
| Foco Absoluto `sentinel_absolute_focus` | 37 | `sentinel_precision_stance` R2 |

Observar permanece opcional para atirar. Precisão/alcance, linha, controle e explosão têm entradas distintas. Tiro Perfurante exige quatro pontos Base no personagem novo: Disparo Duplo2 + Flecha Perfurante2; não só os dois do requisito direto.

### Caçadora — 8 skills, carteira Evolução

| Habilidade / ID | Job | Antecedente |
|---|---:|---|
| Armadilha Congelante `hunter_freezing_trap` | 20 | Livre; grátis |
| Armadilha de Piche `hunter_tar_trap` | 20 | Livre |
| Armadilha de Espinhos `hunter_thorn_trap` | 23 | `hunter_freezing_trap` R2 |
| Marca do Caçador `hunter_mark` | 25 | Livre |
| Disciplina de Tiro `hunter_shooting_discipline` | 28 | `double_shot` R2 (Arqueiro) |
| Tiro de Cobertura `hunter_covering_shot` | 31 | `slowing_arrow` R2 (Arqueiro) |
| Presa Fácil `hunter_easy_prey` | 34 | `hunter_mark` R2 |
| Cobertura Total `hunter_total_cover` | 37 | `foliage_shelter` R2 (Arqueiro) |

Marca não bloqueia as armadilhas; cobertura mantém o orçamento compartilhado existente, sem grant ou recarga nova.

### Geômetra (`mg_ar`) — 7 skills, carteira Evolução

| Habilidade / ID | Job | Antecedente |
|---|---:|---|
| Traçado Elemental `geometer_trace` | 20 | Livre; grátis |
| Teorema de Incidência `geometer_incidence` | 23 | `geometer_trace` R2 |
| Translação `geometer_translation` | 25 | `teleport` R2 (Mago) |
| Triangulação `geometer_triangulation` | 28 | Livre |
| Memória Vetorial `geometer_vector_memory` | 31 | Livre |
| Colapso Geométrico `geometer_collapse` | 34 | `geometer_triangulation` R2 |
| Reescrita `geometer_rewrite` | 37 | `geometer_translation` R2 |

Origem real é Mago: afinidade Arqueiro não concede sua biblioteca, nem Elementalista/Espiritualista/Sentinela. Nenhuma referência exige esses jobs. Traçado gratuito torna Triangulação e Memória úteis sem pedágio artificial. Editar vértices tem rota Teleporte → Translação → Reescrita; resolver figura tem rota independente Triangulação → Colapso.

## Orçamento e exemplos completos

Base recebe `min(job,20)-1`: 0 no job1, 19 no job20 e depois. Evolução recebe `max(job-20,0)`: 0 na entrada20, 3 no23, 5 no25, 8 no28, 11 no31, 14 no34, 17 no37, 20 no40. Observar/Piche têm gate20 mas precisam do primeiro ponto no21; preservar essa distinção. XP e elegibilidade de evolução (base10/job20) não mudam. As rotas cabem nos saldos de seus gates ou podem esperar mais job; não prometer aprendizagem no gate se os pontos foram gastos em outra rota.

Exemplos em personagem novo, sem grants legados, no job20 para bases e job40 para evoluções. Ranks indicados são finais. A coluna Antecessores já integra o total; não somá-la novamente. Entrada gratuita não custa ponto, aumento de R1 para R3 custa dois. Kits são exemplos viáveis de investimento, não promessa de equilíbrio.

| Identidade / rota | Ranks finais da rota | Antecessores incluídos (Base / Evolução) | Total Base /19; Evolução /20 |
|---|---|---|---|
| Espadachim / pressão | Corte2, Golpe Brutal2, Raiva3, Fúria2, Sede2, Investida2 | Corte2 + Golpe2 + Fúria2 = 6 / 0 | 13; 0 |
| Mago / raio e controle | Relâmpago2, Descarga2, Parede de Raios3, Gelo2, Parede de Gelo2, Teleporte2, Regeneração2 | Relâmpago2 + Descarga2 + Gelo2 = 6 / 0 | 15; 0 |
| Arqueiro / área preparada | Duplo2, Perfurante2, Chuva3, Laço2, Técnica2, Mira2, Precisão2 | Duplo2 + Perfurante2 + Laço2 = 6 / 0 | 15; 0 |
| Defendente / corredor e resposta | Parede2; Contraforte3, Marco3, Trava3, Resguardo2, Rebater3, Vigília2 | Parede2 / Contraforte2(1 pago) + Marco2 + Resguardo2 = 5 | 2; 15 |
| Berserker / executar e sustentar | Fúria3; Ruptura3, Execução3, Caça2, Arrancar3, Obstinação2 | Fúria3 / Ruptura3(2 pagos) + Caça2 = 4 | 3; 12 |
| Elementalista / três elementos | Gelo2, Relâmpago2; Explosão3, Foco2, Anel2, Arco3, Ressonância2, Nova3 | Gelo2 + Relâmpago2 / Foco2 + Anel2 = 4 | 4; 14 |
| Espiritualista / eco e canalização | Barreira Fantasma2; Maldição3, Recolhimento2, Drenagem3, Véu2, Foco do Além2, Rito3 | Barreira2 / Maldição3(2 pagos) + Drenagem2 = 4 | 2; 14 |
| Sentinela / linha e alcance | Duplo2, Perfurante2, Mira2; Tiro na Cabeça3, Observar2, Postura2, Tiro Perfurante3, Leitura2, Foco Absoluto3 | Duplo2 + Perfurante2 + Mira2 / Observar2 + Postura2 = 4 | 6; 14 |
| Caçadora / abertura | Duplo2, Entorpecente2; Congelante3, Piche2, Espinhos3, Marca2, Disciplina2, Tiro de Cobertura2, Presa Fácil2 | Duplo2 + Entorpecente2 / Congelante2(1 pago) + Marca2 = 3 | 4; 15 |
| Geômetra / editar e resolver | Teleporte2; Traçado3, Incidência2, Translação2, Triangulação2, Memória2, Colapso3, Reescrita3 | Teleporte2 / Traçado2(1 pago) + Translação2 + Triangulação2 = 5 | 2; 16 |

Para legado, subtrair somente grants efetivamente presentes nos IDs usados; não somar um grant e seu rank gratuito duas vezes. Exemplo: Espadachim da primeira linha com Corte1 e Investida1 legados custa 11 Base; Resistência1 legado não reduz esta build porque não foi comprada nela. Requisitos já aprovados de Marco, Avanço, Salto, Obstinação continuam custando respectivamente 2, 2, 2, 3 Base a partir de zero; Investida2 custa apenas 1 para quem possui grant legítimo R1.

## UI entre jobs, sem árvore duplicada

Na árvore, desenhar linhas somente entre nós da aba atual. Requisito externo recebe um pequeno marcador fixo de vínculo no canto do cartão, com ícone de origem e estado acessível; substituir o texto de nomes sob cada cartão, sem aumentar sua altura. Nenhuma linha cruza abas, nenhuma cópia do nó ancestral aparece na árvore da evolução.

Hover, seleção por clique ou foco de teclado abre o mesmo painel contextual: `Requer Teleporte R2 · aprendido R1 · falta 1 rank · Base`. Mostrar cada condição com texto/ícone além da cor: satisfeita, falta rank, falta job, falta saldo. Explicitar quando requisitos estão satisfeitos mas a compra aguarda pontos ou job. Item disponível não muda o marcador de aprendido. O botão `Ver na origem` abre a aba já possuída, destaca e rola ao nó; `Voltar para Reescrita` restaura aba, seleção e posição anteriores. Sem compra automática ao navegar. Requisito local também pode ser selecionado no painel.

O nome completo do job fica no hover/painel, sem texto permanente adicional nos cartões de92px. O marcador não invade ícone, nome ou controles de rank.

Na lista, usar o mesmo marcador e painel; dispensa linhas. O painel mostra cadeia completa quando há ancestrais, incluindo Teleporte → Translação → Reescrita, sem encher os cartões. Somente abas da biblioteca legal do personagem; referências inválidas são erro contratual, não convite para adquirir outro job.

`Faltam para liberar`: união transitiva dos ranks necessários, tomando o maior rank exigido por ID, descontando permanente atual; contar cada rank ausente uma vez. Separar `Base: 2; Evolução: 2`, e depois `Comprar esta habilidade R1: 1 Evolução`. Pode acrescentar total até comprar `Base: 2; Evolução: 3`, nunca um saldo combinado. Gate de job aparece separado e considera também os ancestrais. Para Colapso a partir da entrada gratuita: 2 Evolução para Triangulação2, mais 1 para Colapso1, job34. Para Tiro Perfurante sem compras: 4 Base para Duplo2/Perfurante2 e 1 Evolução para o destino, job25. Saldo insuficiente numa carteira não é compensado pela outra. Para skills já aprendidas, mostrar custo/requisito do próximo rank e estado máximo quando aplicável.

## Migração recomendada e aprovação pendente

Aplicar migração versionada depois da aprovação e implementação, validando primeiro o save com seu contrato anterior. Reembolsar transitivamente apenas compras que se tornem incompatíveis: remover os ranks comprados ilegais, repetir até ponto fixo, creditar somente os pontos efetivamente gastos na carteira original por redução do gasto contabilizado. Preservar compras legais, XP, identidade, gratuitos e grants permanentes; sem autocompra, conversão de carteiras ou apagar o personagem. Grants desta proposta continuam raízes, evitando conflito novo com sua preservação.

Propor preservar referências de atalhos e ranks escolhidos, deixando indisponíveis os que perderam aprendizado, com explicação e reativação quando legais; nunca executar rank reembolsado. Isso é uma mudança explícita em relação à poda da migração anterior, não comportamento já garantido pelo código. Mensagem deve listar removidos e reembolso por Base/Evolução; o aviso atual fixo de Evolução precisará ser generalizado. Item que por si autorize uma ação mantém sua própria regra, sem transformar a referência em investimento permanente.

Decisão humana solicitada: aprovar (1) estes novos cachos, especialmente os da base Espadachim antes preservada aberta; (2) marcador de origem + painel/navegação e custos por carteira; (3) migração transitiva com atalhos preservados indisponíveis. Até essa decisão, nenhum catálogo, UI, save ou consumidor deve adotar o mapa.

## Evidência e limites

Conferência documental com `scripts/data/class_catalog.gd`, `scripts/core/profile_catalog.gd`, `scripts/core/character_progression.gd`, `scripts/core/progression_rules.gd`, `scripts/ui/skill_copy.gd`, tuning Sentinela/Caçadora e grants em `profile_codec.gd`; contexto vigente de MVP/ARCHITECTURE e [proposta aprovada do Espadachim](e06_swordsman_skill_proposal.md). Cobertura: 37 IDs base + 56 exclusivos = 93, nas dez identidades. Todos os antecessores são da mesma evolução ou de sua origem legal; não há ciclos e as cadeias propostas têm no máximo três nós. Aritmética dos exemplos inclui ancestrais únicos e descontos gratuitos. Nenhum runtime alterado; suíte de gameplay não executada neste lote documental. Sol confirmou separadamente cobertura exata, todos os nomes visíveis, ausência de ciclos, profundidade e aritmética dos exemplos. Balanceamento, renderização e migração real continuam sem validação; implementação futura precisa invariantes de DAG/origem, gratuidade, economia, reembolso por carteira e navegação visual.
