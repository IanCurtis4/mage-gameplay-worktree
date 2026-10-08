# Atributos por faixas — contrato de implementação v1

## Autorização, base e precedência

Pedido humano de 07/10/2026 no chat Astra `01a08e78-172d-7281-a8ca-19761da1c572`,
turno `01a11965-e98e-7700-9c8a-ed1a8eb77b14`: mais pontos por nível, custo crescente,
ganhos contínuos com bônus em marcos e incentivo a investimentos secundários.
Delegação a Sol conferida contra a mensagem humana original, não apenas o encaminhamento.

Branch `codex/stat-thresholds`, base `628f68e3a953d17771daedfb2874cbceebb289c3`.
Checkout d066 reaproveitado depois de confirmar limpo e sem escritor ativo.
`codex/skill-icons` preservada em `35901f6`; não entra neste delta. O cabeçalho
histórico de Defendente em AGENTS/WORKFLOW não autoriza nem identifica este pacote.
Esta autorização específica substitui somente custos/ganhos e os raw derivados
abaixo de [E00.2](E00_02_STATS_CONTRACT.md), [ADR](ADR_E00_01_CHARACTER_PROGRESSION.md)
e [E03-B](E03_B_PROGRESSION.md). Demais contratos continuam válidos.

Não alterar XP, níveis 30/40, job gates, identidades/vetores iniciais, skill wallets,
ranks, poderes de catálogo, equipamentos, mapas, mecânica de crítico ou resolver.
Sem ícones/tooltips de skills, publicação do playtest, merge ou save pessoal.
Revisão integrada por Astra ao fechamento; correções internas não criam gates por função.

## Referência e adaptação original

[iRO Wiki Classic — Stats](https://irowiki.org/classic/Stats), consultada 07/10/2026,
é referência **secundária de design**, não autoridade do nosso runtime. Descreve
custos crescentes por dezenas, pontos por nível crescentes, bônus de FOR/DES em
10 e de INT em 5/7, além de regeneração em 6. Não afirmamos reprodução de RO.
Aqui não há dano mágico aleatório mínimo/máximo, ASPD por arma, peso, perfect dodge
ou crítico ignorando defesa. Permanecem as categorias e os limites próprios do demo.

## Carteira e custo permanente

Ao alcançar nível base `L`, `2 <= L <= 30`, conceder `13 + floor(L/5)` pontos.
`B(L) = sum(13 + floor(n/5), n=2..L)`, `B(1)=0`. O saldo continua derivado de XP,
não armazenado. Cruzar vários níveis/reload/evoluir não concede pontos por evento.

Para aumentar **permanente** `b = inicial + investido` de `b` para `b+1`:
`C(b) = 2 + floor((b-1)/10)`, `1 <= b < 60`. Não usar bônus de equipamento,
passiva, postura, buff ou atributo efetivo para cobrar. Origem determina o inicial;
evolução não muda a cobrança. Custos de destino 2..11=2, 12..21=3, 22..31=4,
32..41=5, 42..51=6, 52..60=7. O teto de investimento permanece 60.

`spent = sum_attr sum(C(inicial_attr+k), k=0..alocação_attr-1)`.
Lote cobra a soma exata dos passos atravessados: 9→12 custa `2+2+3=7`;
10→12 custa `2+3=5`. Validar todos IDs, quantidades inteiras positivas, aliases,
caps e carteira antes de alterar qualquer campo. Falha não compra parte do lote.
Respec gratuito elimina investimentos e devolve exatamente esse custo canônico.

| Nível | Recebido ao chegar | Orçamento | Antigo |
|---|---:|---:|---:|
| 5 | 14 | 53 | 12 |
| 10 | 15 | 124 | 27 |
| 15 | 16 | 200 | 42 |
| 20 | 17 | 281 | 57 |
| 30 | 19 | 458 | 87 |

Os pontos agora são moeda, não quantidade de incrementos. O orçamento elevado
é necessário para compatibilidade de builds antigas especializadas. Duas propostas
mais baixas foram rejeitadas pela prova: `11+2*floor(n/5)` por transição faltava
em L17 (Espadachim custo221/orçamento218); `12+floor((n+2)/5)` também faltava
(221/219). A proposta final acima é crescente e comporta todas as alocações antigas.
Não aumentar caps nem resetar personagem para contornar esses casos.

## Derivados: ganhos contínuos + bônus

`q_p(X)=floor(max(0,X)/p)`. Usar primários **efetivos**, depois de todas as fontes
flat e clamp 0..120. A fração permanece no termo contínuo; somente o contador
de marcos usa floor. Somar o bônus no raw; aplicar flat/increased de derivados
uma vez e os mesmos clamps do StatCalculator. ASPD continua 100×APS **já efetivo**.

As fórmulas E00 ficam intactas exceto por **adicionar**:

| Primário | Bônus somado ao raw canônico |
|---|---|
| FOR | ATQ corpo `q10(FOR)^2` |
| AGI | FLEE `2*q10(AGI)`; APS `0.02*q10(AGI)` |
| VIT | HP `20*q10(VIT)`; DEF `2*q10(VIT)`; HP/s `0.2*q5(VIT)` |
| INT | ATQM `0.25*(q5(INT)^2+q7(INT)^2)`; SP `5*q10(INT)`; DEFM `2*q10(INT)`; SP/s `0.2*q6(INT)` |
| DES | ATQ precisão `q10(DES)^2`; HIT `2*q10(DES)`; cast variável `-0.01*q10(DES)` |
| SOR | crítico e resistência crítica `0.002*q5(SOR)` cada |

SOR mantém HIT/FLEE e crítico contínuos anteriores; não muda drops, dano crítico
ou passa a ignorar DEF/HIT. Sua utilidade ofensiva menor em magia sem crítico é
explicitada, não escondida por um novo scaling. AGI não afeta movimento ou cast.
VIT/INT mantêm resistência a CC contínua, sem nova família de controle.
Nenhum atributo zera seu ganho entre marcos; aumentos primários são sempre efetivos,
embora derivados já no clamp possam ficar constantes.

Skills que usam ATQ/ATQM recebem derivados novos pelo mesmo caminho. Fórmulas
locais de Sentinela continuam INT-only (Rede/Explosivo) ou INT+DES (Perfurante),
sem bônus de ATQM/crit/ASPD indevido. Seus coeficientes/ranks/CD local não mudam.
Os ganhos de INT nos marcos não são forçados dentro dessas fórmulas específicas.

## Simulação reproduzível e conclusões

`python tools/simulate_stat_thresholds.py` produz as tabelas; `--check` é somente
leitura. Oracle independente de design, não um calculador paralelo carregado no jogo.
[Níveis](fixtures/stat_threshold_levels.csv), [custos](fixtures/stat_threshold_costs.csv),
[marcos antes/no/depois](fixtures/stat_threshold_milestones.csv),
[builds antigas/novas](fixtures/stat_threshold_builds.csv),
[marginais por ponto gasto](fixtures/stat_threshold_marginals.csv),
[limites exatos de migração](fixtures/stat_threshold_migration.csv),
[100 fixtures numéricas](fixtures/stat_threshold_reference.json).

200 linhas com 4 papéis × 5 níveis (5/10/15/20/30) × 5 distribuições × 2 regras.
Sem equipamentos/passivas para isolar os efeitos; incluir integrações com essas
fontes na implementação. Concentrada=um atributo estrito (sobra orçamento ao cap);
dois=70/30; splash3=70/20/10; splash4=60/20/10/10; equilibrada=seis iguais.
Distribuir incrementos por menor `investido/peso`, desempate por ordem do papel;
não equalizar dinheiro gasto. Não são builds ótimas nem recomendação ao jogador.
Todos custos/sobras são explícitos: comparar dano de um especialista capado com
uma build que gastou mais dinheiro **não** prova eficiência ofensiva de splash.

Exemplo L30 (FOR/AGI/VIT/INT/DES/SOR): melee dois `60/5/54/2/5/2`
tem HP972; splash4 `60/21/40/2/22/2` HP812, mas ganha cadência/precisão e
ATQ corpo174.8 contra168. Mago dois `2/5/5/60/54/2` tem ATQM203.6/HP382;
splash3 `2/5/25/60/45/2` tem ATQM200/HP622. Sentinela crítica dois tem
DES60/SOR53, crítico25.9%; splash4 DES60/SOR37/VIT22/AGI24 tem crítico20.5%,
mais HP/ASPD. Caster dois INT60/DES53 preserva dano INT-only; splash3
INT60/DES45/VIT23 preserva esse dano, ganha HP, mas perde parte do CD local/HIT.
Equilibrada retém flexibilidade/sobrevivência ao custo de poder principal.

Marginais: FOR59→60 custa7 e ganha13 ATQ (1.857/ponto); FOR58→59 custa7
e ganha2 (0.286/ponto). DES5→6 custa2 e ganha0.4 ATQ corpo (0.2/ponto), além
de HIT/cast/precisão. VIT8→9 custa2 e ganha10HP/2DEF; VIT9→10 custa2 e
ganha30HP/4DEF. SOR4→5 custa2 e ganha0.5p.p. crítico/0.2p.p. resistência.
Um marco principal pode ser a melhor compra; fora dele, secundários baixos têm
vantagens por moeda em outros canais. Thresholds **não impedem** concentração.

Tabelas incluem ATQ/ATQM/HP/SP/regen/DEF/DEFM/HIT/FLEE/crítico/ASPD/cast e
poder bruto R1 de Corte/Bola/Cabeça/Perfurante/Rede/Explosivo, CD local e custo
de recursos. São potenciais por emissão e capacidade/tempo teórico de recuperação
sem gasto simultâneo; não são DPS, TTK, encontro medido ou aceite de gameplay.
Fixtures de skills usam coeficientes R1 do catálogo vigente, a conferir contra
o engine no teste; disponibilidade por job não é removida para jogar tais tabelas.

## Migração sem reset e política de escrita

Novo par `catalog_version=7 / ruleset_id=stat_thresholds_v1`, schema2 mantido.
Conhecer explicitamente catálogos1/e00_v1 e2..6/e04_learn_from_zero_v1; rejeitar
pares desconhecidos/futuros sem sobrescrever/recuar destrutivamente ao backup.
Migração primeiro valida o saldo sob a **regra antiga** (máximo3*(L-1)), inclusive
vetores/caps/ranks/IDs/gates. Não usar o orçamento maior para certificar um save
antigo adulterado. Depois mantém investimentos e todos os outros campos, mudando
somente o envelope conhecido e materializando direitos legados onde já previsto.
Não conceder crédito armazenado, dívida, ranks ou reset. Aviso e backup pelo store.

Prova exata por programação dinâmica (knapsack limitado, seis atributos/cap60),
não amostra aleatória: **90 casos**, todos níveis1..30 × três origens, maximizando
custo novo para cada orçamento antigo. A maximização cobre qualquer distribuição
com menos pontos porque todo custo é positivo. Em L17 Arqueiro o pior custo231
cabe em232; L18 custo247 cabe em248. Em L30 piores387/387/391 cabem em458.
Portanto, todas alocações antigas legais cabem sem respec compulsório.

Carregar novamente após conversão usa envelope novo e não reconcede saldo;
reembolso/reequipar/reload não cria pontos. Continua preservar backup de linhagem,
pending não confirmado, perfis futuros, contador/revisão e escrita única.
Testar tudo com store em fixtures isoladas, nunca user:// pessoal.

## Consumidores, donos e aceitação

Sol: ProgressionRules/StatCalculator/CharacterProgression; codec/store/fachada;
API de preview de atributo e auditoria de todos spent/available/refund/fixtures/admin.
Luna pode auditar simulação sem escrever fórmulas; Terra pode montar UI **após** API
pronta. Sem cadeia obrigatória ou dois escritores no mesmo arquivo.

Painel lê uma projeção autoritativa por atributo: permanente/efetivo, custo do
próximo+1, próximo(s) marco(s), ganho atual→próximo, saldo e motivo de bloqueio.
Não esconder o custo no hover apenas; botão desabilitado individualmente quando
saldo menor que seu custo ou cap. Preview usa StatCalculator, incluindo passivas
dependentes de alocação, nunca fórmula ou custo refeito pela UI. Lotes API atômicos.

Aceitar invariantes: custo batch=unitário; x9/x0/x1 e11→12; cap; negativas/bool/
frações/IDs/aliases; sem mutação em falha; respec/retry idempotentes; migration
antes/depois/futuro/backup/pending/primeiro commit; três carteiras e gates; buffs
cruzando marcos sem cura/SP/CD; concordância preview/snapshot/ator/HUD; exclusivos
sem vazamento. Não atualizar snapshots cegamente: cada expectativa mudou por
custo ou raw contratual explícito. Suíte dirigida + `tools/verify.ps1` + CLI all
final. Evidência do implementador não substitui reprodução/aceite Astra.
