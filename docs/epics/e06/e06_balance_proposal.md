> Escolhas humanas recebidas13/10: cadência recomendada2/6/8/16/40%, stats existentes/utilidade fixa, XP atual. Implementação entregue/validada sobre3a6075f; números abaixo representam a calibração inicial aprovada, ainda sem certificação de balanceamento. Detalhes atuais e limites no [escopo](e06_balance_scope.md).

# E06 — proposta inicial de taxas e progressão

13/10/2026. **Registro histórico da proposta anterior à implementação.** Os trechos de escolha aberta abaixo foram resolvidos pelas respostas humanas no cabeçalho; estado atual/recibos no checkpoint. Usuário autorizou este lote e confirmou equipamentos/loot, mantendo XP Base/Job. Base3a6075f0d0596aaf2dee92b7bac11509c63b6ed6; [escopo e donos](e06_balance_scope.md). Sol prepara números e integração; Astra foi consultado somente sobre arquitetura, sem auditoria do capítulo. [Projeção reproduzível](e06_balance_projection.json), gerada por `python tools/content/e06_balance_model.py` com80invariantes verificadas.

## Regras preservadas e estado real

O catálogo integrado possui37equipamentos:11comuns,9incomuns,17raros; todos ilvl1. Nenhum épico ou lendário nominal. Doze receitas antigas e25novas permanecem disponíveis com seus IDs. Carta segue a espécie base, não categoria da ocorrência; só armas/armaduras/escudos têm0–4encaixes. Incomuns/comuns não recebem especiais; raro+ pode tê-los; carta nunca concede ativa. Garantia é um item com qualidade mínima, resultado superior substitui. Loot por mob substitui equipamento/carta da etapa, preservando XP e escolha de augment por encontro. Curvas atuais de XP/pontos/evolução e as dez identidades permanecem.

Hoje quality/ilvl do exemplar não multiplicam seus efeitos: Composer usa a receita da definição. O pool permite uma definição quando suas capacidades cabem na qualidade sorteada, sem comparar qualidade nominal; assim uma receita rara pode sair com rótulo épico/lendário sem ganhar poder nem exclusividade. A nova implementação precisa corrigir essa fronteira; taxas sozinhas não resolvem progressão.

A arena atual contém dois encontros com2+4inimigos normais, todos fixos no nível1. Não possui a exposição nem categorias das projeções abaixo. Os dois mobs demonstrativos não têm carta vinculada; seis espécies piloto têm. Não ativar taxa positiva de carta para uma base sem receita nem inventar um fallback de carta. Não conceder épico/lendário apenas renomeando qualidade, nem inventar um boss para tornar a tabela utilizável.

## Equipamentos: chances por mob

Valores de partida para playtest posterior, não estimativa de balanceamento já medido. Células de qualidade são chances **absolutas por ocorrência**, não chances condicionais a um drop.

| Ocorrência | Sem equipamento | Comum | Incomum | Raro | Épico | Lendário |
|---|---:|---:|---:|---:|---:|---:|
| Normal | 96% | 3,16% | 0,8% | 0,036% | 0,004% | 0% |
| Raro | 0% | 0% | 90% | 9% | 1% | 0% |
| Elite | 88% | 9,48% | 2,4% | 0,108% | 0,012% | 0% |
| Elite raro | 0% | 0% | 0% | 90% | 10% | 0% |
| Boss | 0% | 0% | 0% | 0% | 98% | 2% |

Normal sorteia equipamento em4%dos abates; elite em12%, com a mesma distribuição condicional de qualidades (79/20/0,9/0,1%). A ocorrência aumenta acesso, sem multiplicar novamente os stats ou o ilvl. Raro/elite raro/boss produzem exatamente um item, respeitando pisos incomum/raro/épico. Lendário exige pool explícito exclusivo de boss; recipientes sem uma receita válida devem falhar na configuração, sem degradar qualidade, sortear outro eixo ou quebrar garantia.

No normal, raro aparece em média uma vez a cada2.778abates e épico a cada25.000. São médias geométricas, sem garantia nessa quantidade. No boss, lendário2%significa média50bosses, mediana35e95%de chance de ao menos um depois de149bosses independentes. Sem pity/bad-luck-protection neste primeiro modelo; não acrescentar regra não discutida.

## Cartas: comparar cadências antes de aplicar

Recomendo a coluna que permite experimentar builds durante uma run. Cartas permanecem menos frequentes que equipamentos em cada categoria e não acumulam entre runs.

| Ocorrência | Cadência escassa | Cadência de build — recomendada |
|---|---:|---:|
| Normal | 1% | 2% |
| Raro | 3% | 6% |
| Elite | 3% | 8% |
| Elite raro | 8% | 16% |
| Boss | 20% | 40% |

Chance independe do resultado de equipamento. Uma espécie tem sempre a mesma receita de carta em todas as ocorrências permitidas. Variante elite de base normal só aumenta a chance; não habilita transformação. O ticket congela ambos os resultados e a origem; retry não sorteia de novo. Cada ocorrência gera no máximo uma carta, que só entra na mochila após durabilidade da coleta.

As projeções assumem todas as espécies com carta válida e coleta integral, sem morte/abandono. Cada cenário possui1raro,2elites,1elite raro,1boss e o restante normal. **São cenários hipotéticos de exposição, não mapas/spawns/campanha aprovados.** Seis escolhas de augment são uma premissa comparativa, não mudança dos dois encontros da arena.

| Abates hipotéticos | Equipamentos médios | Cartas escassas / chance de ≥1 | Cartas recomendadas / chance de ≥1 |
|---|---:|---:|---:|
| 20 | 3,84 | 0,52 / 42,23% | 1,08 / 70,38% |
| 60 | 5,44 | 0,92 / 61,35% | 1,88 / 86,80% |
| 120 | 7,84 | 1,52 / 78,85% | 3,08 / 96,07% |

Acessibilidade envolve quantidade de oportunidades: não basta comparar dois percentuais. No cenário de60abates, seis escolhas de augment são mais frequentes e certas que5,44peças e1,88cartas. No stress120, equipamentos superam seis augments; portanto a cadência final deve ser calibrada com exposição real, não alegar hierarquia universal da tabela. Peça útil para determinado slot/identidade/carta de uma espécie é menos provável que receber qualquer drop. Não remover aquisição incompatível silenciosamente, nem introduzir smart loot/duplicata protegida sem contrato.

## Encaixes

Distribuição proposta por equipamento elegível, independente da qualidade e da categoria:0=60%,1=25%,2=10%,3=4%,4=1%. A média é0,61encaixe por peça elegível. Peças com3–4 são5%; quatro aparece em média1a cada100peças elegíveis. Focos/colares/acessórios têm zero sem consumir um segundo sorteio nem criar encaixes proibidos. A média de encaixes total depende da proporção real de armas/armaduras/escudos no pool; não supor que toda peça é elegível. Capacidade entra na comparação de builds completas com cartas, não como um multiplicador escondido de stats nem um custo que subtraia poder da peça sorteada.

## Progressão numérica proposta

Primeira faixa de validação:ilvl1–30, sem novas regiões ou escalonamento pelo jogador. O item carrega ilvl fixo da fonte autorizada (hoje o nível fixo do mob), mesmo que um personagem mais forte volte ao lugar. Ocorrência muda taxas/pisos; não aplica fator adicional. Ilvl/qualidade aumentam apenas campos explicitamente escalares, com uma autoridade nova que fornece fontes canônicas ao Composer/StatCalculator e à comparação.

Curva inicial de **bônus em pontos**: `L(i)=1+0,04×(i−1)`. Coeficientes de qualidade propostos:comum1; incomum1,15; raro1,35; épico1,65; lendário2. Uma receita de referência conserva seu orçamento ilvl1/qualidade nominal: `novo_bônus=bônus_referência×L(ilvl)×Q(qualidade_sorteada)/Q(qualidade_referência)`. Não arredondar cada efeito durante composição; apresentação arredonda, fórmula central usa precisão real.

| Ilvl | Fator de nível | Exemplo: bônus DEF4 de referência raro, novo exemplar raro |
|---|---:|---:|
| 1 | 1,00 | 4,00 |
| 5 | 1,16 | 4,64 |
| 10 | 1,36 | 5,44 |
| 20 | 1,76 | 7,04 |
| 30 | 2,16 | 8,64 |

No ilvl30, esse bônus seria10,56épico e12,8lendário **se a receita daquele tier autorizar esse orçamento**. Isso não transforma a Cota rara atual num lendário elegível. Fatores não podem superar elegibilidade ou criar efeito raro em incomum. Receitas stat-only podem ter variantes declaradas por tier; receitas especiais têm tier mínimo e bônus autorados, não supressão automática do efeito para fabricar um incomum.

Procs, projéteis, alcance, ativa/rank, políticas booleanas, multiplicadores/reduções percentuais, ASPD/índice, limites de famílias, bônus de conjunto, cartas e augments ficam fora da escala automática inicial. A lista de stats em pontos permitidos será fechada por eixo/canal antes de escrever runtime; não basta testar `kind=STAT`. Nenhum percentual passa de limite através desse fator. Sets/conflitos/maior rank/recargas/capturas mantêm semântica vigente.

O exemplo não é unidade universal de poder:DEF,HP,SP,primários que cruzam patamares e utilidade não têm valor equivalente. O modelo não replica StatCalculator nem calcula dano final. Validar ilvls1/5/10/20/30 nas vinte builds A/B com composição/combate reais, mantendo os oráculos e casos sem carta/0–4encaixes. A hierarquia augments>equipamentos>cartas deve ser avaliada em fontes equivalentes e builds completas; não é demonstrada por esses coeficientes isolados.

**Escolha ainda aberta:** escalar somente stats já existentes deixa peças só de ativa/proc sem crescimento numérico; preserva sua utilidade fixa. Acrescentar stats de base aos novos exemplares dessas peças dá progressão numérica, mas exige orçamento explícito por receita e revisão das builds. Recomendo stats existentes para a primeira calibração; novos budgets de utilidade podem ser publicados depois de comparação, sem inventá-los durante loot. Se o usuário preferir, fazer o orçamento adicional neste lote antes de consumidores.

## Preservação e autoridade — recomendação arquitetural

Não inferir idade pelo definition_id nem por ilvl1: TODOS os exemplares existentes, inclusive os25IDs novos e exemplares de fixture com outroilvl/qualidade, precisam conservar os valores atuais. Recomendação Astra/Sol: referência a revisão imutável de receita e ruleset de poder fixadas por exemplar. Não criar um novoID por cada ilvl/qualidade como solução geral: isso alteraria acessórios idênticos, participação em sets e exclusividade hoje ligados a definition_id.

Extensão proposta:instância persiste `recipe_revision_id` e `power_ruleset_id` além dos seis campos. Migração explícita atribui revisão piloto preservada e `legacy_unscaled` a todos os registros antigos, sem perder exemplar/referência/capacidade/preset/atalho. Novas aquisições usam revisão/tabela aprovadas no instante da emissão do ticket. Revisões antigas continuam resolvíveis; não editar curva já referenciada para rebalancear novas aquisições. Um próximo tuning recebe outra revisão, sem buff/nerf retroativo presumido. Identidade lógica estável continua sendo a chave dos acessórios e sets; revisão não autoriza duplicar a mesma peça.

Fonte de poder nova resolve lista autorizada em uma cópia; Resource compartilhado permanece imutável. Não salvar código/payload arbitrário de efeitos. Catálogo e schema atuais10/3 serão versionados explicitamente conforme a extensão definida; preservar migrações conhecidas/pending/backup. Resultado incerto não reaplica migração ou rerrola drops. Preview/combate/tooltip consomem os mesmos valores efetivos; emissões já lançadas conservam captura.

## Próximo pacote de implementação

1. Fechar escolha de cadência de cartas e de stats nas peças de utilidade, adotando ou revisando esta tabela inicial. Nenhuma decisão numérica inferida de uma consulta técnica.
2. Sol implementa resolver central/rulesets/migração preservadora e testes dirigidos. Regras, RNG, floors, socket/base-card e idempotência com oráculos explícitos. Manter83recursos intactos; novos pools/tier recipes separados e rastreáveis.
3. Definir receitas épicas/lendárias e pools válidos (legendária exclusiva de boss), cobertura de identidade/slot e budgets das peças. Sol define mecânicas; Luna nomes/flavor apenas sobre briefs fechados.
4. Calibrar disponibilidade com exposição que o jogo realmente usa e validar comparação/combate das vinte builds. Integração da arena usa contrato explícito; ausência de mob/base/carta/qualidade não vira fallback. Campanha/E07 e curvas deXP continuam fora.
5. Luna supervisiona testes por impacto; Sol fecha resultado e prepara candidato de playtest. Nenhuma auditoria Astra de capítulo automática. Aplicação/merge do candidato atual não são presumidos por iniciar tuning.

80invariantes offline passaram:normalização/finitude/ranges, pisos, lendário sóboss, distribuição conjuntaquality/socket independente, probabilidades de exposição, progressão monotônica e37referênciasilvl1. Sem execução da bateria de gameplay nesta rodada documental/modelagem; não afirmar balanceamento final, performance, clique/UI ou aceite humano. Nenhum recurso ativo ou save pessoal alterado.
