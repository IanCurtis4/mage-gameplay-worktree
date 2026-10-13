# E06 — contrato simples da extensão de gameplay

13/10/2026. Astra planejou com contexto mínimo (resposta limitada a 700 palavras e complemento a 180). Base `d4d67fbb44fb17e34e619b4e64b70651d9ae1624`. O usuário autorizou implementar este pacote antes do playtest. E07 não foi iniciado.

## Comportamento

Gel original nas cinco categorias: normal < raro < elite < elite raro < chefe. Tamanho, contorno, nome e cor diferenciam os tiers. HP × 1 / 1,5 / 2,2 / 3 / 6; dano × 1 / 1,10 / 1,20 / 1,30 / 1,50, pela autoridade central. Demais stats preservados. Velocidades constantes: Gel 154, Mestre 143, animal 176 px/s; jogador de referência 220 sem penalidades. Nível fixo por origem, sem acompanhar o jogador.

Mestre raro ou superior invoca uma vez ao adquirir alvo: um animal exatamente uma categoria abaixo, sem reposição ou recursão. Ambos usam a origem do mestre. Companheiro não concede loot, carta, XP, ticket ou crédito independente; não bloqueia conclusão e some com o mestre. Vida perdida e convocação consumida permanecem após retorno.

Aquisição natural a 420 px com linha de visão; dano pode provocar perseguição. Leash de 850 px da origem, aplicado tanto ao mob como ao alvo; quatro segundos sem visão também forçam retorno sem atacar. Provocar, Caçadora e controles permanecem funcionais dentro desses limites. Retorno obrigatório não é cancelado por novos ataques/taunt. Disengage não conclui encontro nem abre recompensa.

## Exposição

Três áreas de 2600 × 1700, duas etapas em cada uma, quatro ou cinco obstáculos, corredores de pelo menos 240 px, entrada segura e câmera acompanhando. Grupos separados e posições variáveis por seed, sempre alcançáveis pela navegação.

| Etapa | Nível novo | Composição final | XP Base/Job |
|---|---:|---|---|
| 1 | 2 | 8 normais | 100/80 |
| 2 | 4 | 6 normais + Gel raro | 150/100 |
| 3 | 6 | 7 normais + Gel elite + piloto elite | 200/140 |
| 4 | 9 | 6 normais + Mestre raro | 250/180 |
| 5 | 12 | 6 normais + Gel elite raro + Mestre elite + piloto elite | 300/220 |
| 6 | 15 | 4 normais + Mestre elite raro + Gel chefe | 400/280 |

Duas posições normais de cada etapa usam as quatro espécies piloto compatíveis; echo/ember ocupam as duas posições elite adicionais. Pilotos mantêm cartas e ilvl 1. Gel/Mestre/animal são explicitamente sem carta: nenhum efeito novo de carta neste pacote. São 46 mobs principais e até três animais finitos. Uma escolha de augment por etapa, IDs únicos de recompensa e curvas/schema de XP existentes. Tabelas de equipamento/carta/encaixe preservadas. Treino e fixtures antigos conservam o roteiro legado.

## Autoridades e validação

`MobDefinition.origin_levels = {}` preserva `fixed_level`; mapa preenchido exige origem conhecida e nível inteiro 1–30, sem fallback. `MobCatalog.level_for_occurrence` é compartilhado por stats e loot. `MobTierRules` calcula as fontes de tier; ajusta increased por `(1 + increased_original) × (fator − 1)` antes dos caps, sem fórmula no ator. Valores neutros dos novos campos não alteram o digest das receitas históricas; valores efetivos sempre participam da assinatura.

`PlaytestGameplay` possui exposição/origens/recompensas. `EnemyActor` possui `idle/engaged/returning`, origem e convocação consumida. `Main` cria/remove animais, conta mobs principais, controla áreas/câmera e integra recompensas. Catálogos permanecem imutáveis; só cópias runtime dos pilotos recebem aggro/leash e velocidade. O menu normal ativa o roteiro em sessão persistente; fixtures programáticos optam explicitamente por ele. Nenhum campo novo no save.

Verificar origem/nível/tiers, multiplicadores com bônus existentes, aggro/visão/leash/retorno, Hunter/taunt/controles, invocação inferior finita sem recompensas, morte do mestre, seis encontros/IDs/XP/augments/retry, navegação, legado e leitura nativa. Sol implementa/consolida; Luna supervisiona a bateria por impacto. Astra não faz auditoria de capítulo. Os valores são calibração inicial para avaliação humana.

Correção factual antes dos consumidores: o planejamento inicial recebeu referência 260; Sol confirmou 220 em `StatCalculator` e manteve as proporções 70/65/80%, sem alterar o jogador. A integração acrescentou os dois pilotos elite porque suas categorias originais não permitem normal. Os 85 Resources anteriores e 69 receitas permanecem preservados.
