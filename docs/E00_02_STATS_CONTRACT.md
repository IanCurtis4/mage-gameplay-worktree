# E00.2 — Matemática e painel do MVP expandido

Contrato candidato v1, 13/09/2026. Especificação própria inspirada nas categorias
do painel de RO, sem alegação de reproduzir uma versão desse jogo. Substituirá
as fórmulas do piloto somente na implementação E03, após aceite de design.
O [ADR E00.1](ADR_E00_01_CHARACTER_PROGRESSION.md) define níveis e carteiras.

## Ordem de cálculo e donos

`CharacterState` possui XP e investimentos; `BuildSnapshot` copia identidade,
nível base L e investimentos na partida. `StatCalculator` futuro, sucessor de
`RpgStats`, é a única autoridade para derivados. Nenhuma fórmula fica na UI,
no ator ou no Resource. O painel solicita um `StatBreakdown` dessa autoridade.

Para primários: `A = clamp(initial + allocated + sum(flat), 0, 120)`. Os termos
iniciais/alocados são inteiros; bônus podem ser fracionários. Investimento continua
limitado a inicial + alocado <= 60. Primários não aceitam bônus percentuais no
demo; porcentagens pertencem aos derivados, evitando uma segunda multiplicação.

Para cada derivado: `effective = clamp((raw + sum(flat)) *
(1 + sum(increased)), minimum, maximum)`. Fontes percentuais somam;
`increased=0.2` significa +20%. Aplicar uma única vez, depois dos primários.
IDs inválidos, NaN/infinito e valores de catálogo fora de faixa são erros de
validação, sem criar stats silenciosamente. Frações permanecem em double até a
aplicação de dano; arredondar a exibição não altera o combate. `L` é o nível
copiado no início, não o nível que acabou de subir no personagem persistente.

## Todos os valores do painel

S, A, V, I, D, K significam FOR, AGI, VIT, INT, DES, SOR efetivos. Valores de
probabilidade usam frações internas; a UI multiplica por 100 e escreve `%`.

| Campo pt-BR / ID | Fórmula raw ou fonte | Limites / unidade |
|---|---|---|
| FOR/AGI/VIT/INT/DES/SOR / `str/agi/vit/int/dex/luk` | Inicial + alocado + bônus, regra acima | 0–120; mostrar parcelas e efetivo |
| Nível e XP base/job | Curvas/carteiras do ADR, serviço de progressão | Base 1–30, job 1–40 (20 sem evolução); XP inteira |
| Pontos livres de atributos/base/evolução | Total concedido menos custo validado das alocações | Inteiros >= 0; três carteiras distintas |
| HP / `current_hp`, `max_hp` | Atual: `HealthState`; máximo: `100 + 10*V + 8*(L-1)` | Máximo 1–100.000; atual 0–máximo |
| SP / `current_sp`, `max_sp` | Atual: `ResourceState`; máximo: `40 + 5*I + 3*(L-1)` | 0–100.000; SP é o nome exibido da mana |
| Regeneração de HP / `hp_regen` | `0.5 + 0.05*V` | 0–100 HP/s; só vivo, fora de encontro, sem pausa |
| Regeneração de SP / `sp_regen` | `2 + 0.12*I` | 0–100 SP/s; vivo, inclusive combate, sem pausa |
| ATQ corpo a corpo / `melee_attack` | `10 + 2*S + 0.4*D` | 0–10.000 |
| ATQ de precisão / `precision_attack` | `10 + 2*D + 0.4*S` | 0–10.000; não é um terceiro tipo de mitigação |
| ATQM / `magic_attack` | `10 + 2*I + 0.4*D` | 0–10.000 |
| DEF / `physical_defense` | `2*V + 0.5*S` | 0–900; física |
| DEFM / `magic_defense` | `2*I + 0.5*V` | 0–900; mágica |
| HIT / `hit_rating` | `100 + L + 2*D + 0.2*K` | 0–1.000; rating, não porcentagem |
| FLEE / `flee_rating` | `100 + L + 1.5*A + 0.2*K` | 0–1.000; rating |
| Crítico / `crit_chance` | `0.05 + 0.003*K + 0.0005*D` | 0–0.75; chance antes do alvo |
| Dano crítico / `crit_multiplier` | `1.5` | 1–3; multiplicador, 1.5 = 150% |
| Resistência a crítico / `crit_resistance` | `0` + modificadores explícitos | 0–0.5; subtração em pontos percentuais |
| Cadência / `attacks_per_second` | `1 + 0.015*A + 0.005*D` | 0.2–4 ataques/s |
| ASPD / `attack_speed_index` | `100 * attacks_per_second` já efetivo | 20–400; índice próprio, sem modificador adicional |
| Movimento / `move_speed` | `220` | 80–440 unidades de mundo/s; movimento usa este único limite |
| Cast variável / `variable_cast_multiplier` | `1 - 0.003*D - 0.001*I` | 0.25–2; multiplicador do tempo variável |
| Redução de cast fixo / `fixed_cast_reduction` | `0` + modificadores | 0–0.5 |
| Redução de pós-cast / `after_cast_reduction` | `0` + modificadores | -1–0.8 (negativo aumenta duração) |
| Redução de recarga / `cooldown_reduction` | `0` + modificadores | -1–0.8 |
| Resistência a controle físico / `physical_cc_resistance` | `0.002*V` | 0–0.5; reduz duração, não dano |
| Resistência a controle mágico / `magic_cc_resistance` | `0.002*I` | 0–0.5; reduz duração, não dano |
| Escudo / `shield_hp` | `ShieldState`, soma de reservas runtime após expiração | 0–0.5*max_hp; exibir absorção restante |
| Recurso da identidade / `identity_resource` | `IdentityRuntime`, definição por identidade | 0–100 quando escalar; run-only |
| Slots, ranks e requisitos | Catálogo + `CharacterState` / snapshot efetivo | UI não inventa ranks nem custos |

O painel mostra base, bônus e efetivo; projeção de menu identifica a build da próxima
run. Durante partida, valores vêm do snapshot/runtime. HP/SP atuais, escudos,
cast em andamento, pós-cast restante e recargas são valores runtime; não são
salvos no personagem. Efeitos temporários entram como fontes identificadas.
Não exibir peso, Perfect Dodge, WoE Flee, raça, Critical Shield ou resistência
elemental: não têm sistema correspondente no demo. `MRES` do PDF significa DEFM
nas debilitações propostas; não cria outro stat de mitigação mágica.

## HIT/FLEE, crítico e dano

O catálogo declara `accuracy_mode`: `contested` para autos/tiros direcionados ao
alvo; `geometry` para efeitos cuja esquiva depende da colisão/área telegráfica.
Ambos precisam primeiro passar por validade, alcance, linha de visão/colisão e
estado de alvo. `geometry` não atravessa paredes nem atinge alvo banido.

`p_hit = clamp(0.90 + (HIT_attacker - FLEE_target)/200, 0.05, 0.98)` no modo
contested; geometry usa 1. Acerta se `hit_roll < p_hit`, roll em [0,1).
Sem alvo selecionado, mostrar os ratings e “chance depende do alvo”; com alvo,
o mesmo resolver puro fornece a chance efetiva. Erro nunca rola/dispara crítico.

Se a ação permite crítico: `p_crit = clamp(attacker.crit_chance -
target.crit_resistance, 0, 0.75)`. Mesmo RNG explícito para o resultado completo
de uma emissão; crítico se `crit_roll < p_crit`. Crítico não ignora DEF/DEFM/HIT.
Autos podem critar. Skills diretas precisam declarar `can_crit`; padrão falso.
DoT/eco/efeito secundário nunca crita nem faz nova rolagem de HIT.

Cada rank de skill define poder não negativo P, frações `w_melee`, `w_precision`,
`w_magic` cuja soma é 1, e demais custos/tempos. Dano puro não existe neste demo.
Componente físico = `P*(w_melee*melee_attack + w_precision*precision_attack)`;
mágico = `P*w_magic*magic_attack`. O tipo seleciona defesa; o peso seleciona
atributo. Assim, DES serve ao arco e a skills híbridas sem reduzir dano a FOR.
Não somar ATQ/ATQM inteiros e multiplicar de novo pelo “bônus híbrido”.

Penetração percentual por tipo é explícita, 0–0.5. Primeiro aplicar debuffs de
defesa no pipeline comum; soma de reduções percentuais de DEF/DEFM limitada a 50%.
Depois `def_used = clamp(def_effective*(1-penetration), 0, 900)`.
Mitigação por componente = `100/(100+def_used)` (0 DEF = 0%; 100 = 50%; 900 = 90%).
Resistência a CC não entra aqui. Não há defesa negativa/vulnerabilidade infinita.

`raw_damage = (physical_after_def + magical_after_mdef) * critical_factor *
damage_dealt_multiplier * guard_factor`. Guarda frontal válida usa fator 0.5;
guarda perfeita usa 0; fora da janela/direção, 1. O fator não é outro bônus de DEF.
`damage_dealt_multiplier` é um único stat contextual (raw 1, limite 0–4),
com todas as fontes ofensivas somadas antes; não reaplicar bônus de ATQ.
Arredondamento final: `floor(raw_damage + 0.5)`. Se acertou e raw_damage > 0,
mínimo 1; erro ou poder/fator 0 resulta em 0. Não aplicar mínimo 1 por componente.
O valor antes de `guard_factor` mede dano bloqueado e alimenta recursos de guarda
com quota por raiz; não é dano recebido para disparar procs. Barreiras absorvem
antes do HP, por ordem de expiração mais próxima, desempate ID.
Invulnerável/banido recebe 0; `actual_damage` mede só HP perdido; morte emite uma vez.
Roubo de vida/eliminação usam `actual_damage`/`killed`, não dano teórico ou absorvido.

Emissão captura poder, pesos e stats ofensivos. Impacto consulta defesa/estado do
alvo naquele instante. DoT guarda componente bruto e poder no momento de aplicar,
mitiga em cada tick; não captura novamente buffs ofensivos nem repete crítico.
Canalização é uma emissão por tick com orçamento explícito, não um loop de procs.

## ASPD, ações e relógios

Intervalo de auto = `1/attacks_per_second`. Golpe emitido arma esse cooldown; mudar
ASPD não encurta cooldown em curso. Pós-auto visual/movimento <= min(0.14 s,
intervalo); animação nunca cria ataques extras. Não acumular autos durante pause
ou atraso de frame; manter no máximo uma emissão por atualização de ação.

Rank de skill declara `fixed_cast_s`, `variable_cast_s`, `after_cast_s`,
`cooldown_s`, `sp_cost`, targeting/alcance e se canaliza. Todos >= 0, finitos.
Tempo efetivo de cast = `fixed_cast_s*(1-fixed_cast_reduction) +
variable_cast_s*variable_cast_multiplier`. Pós-cast =
`after_cast_s*(1-after_cast_reduction)`; cooldown =
`cooldown_s*(1-cooldown_reduction)`. DES/INT reduzem somente cast variável.
Rank define a tabela de valores, sem fórmula extrapolada pela UI; rank 0 não lança.

No fim do cast revalidar alvo/geometria, SP e locks; descontar SP e armar cooldown
e pós-cast uma vez. Cast interrompido antes do commit não custa SP nem recarga.
Pós-cast bloqueia novas skills e auto, permite movimento; cooldown individual
bloqueia somente aquela skill. Cast bloqueia auto; movimento voluntário cancela
cast normal. Skill instantânea tem cast 0; ainda revalida e respeita pós-cast.
Canalização consome custo inicial no commit e custo por tick antes de cada tick;
falta de SP, movimento, morte ou controle interruptor encerra sem ticks pendentes.
Cancelamento depois do commit não devolve custo nem cooldown.

Cooldown/pós-cast são capturados no commit; buffs posteriores só afetam emissões
futuras. Pause congela todos os relógios de gameplay. UI apresenta tempo e custo
efetivos calculados para a skill, não apenas porcentagens globais.

## Controle e orçamento contra cadeias

Tags de controle: `physical` ou `magic`; duração = `base_duration*(1-resistance)`.
Hard CC = stun, root, fear, banimento. Normais: teto 3 s por aplicação, sem somar
duração da mesma família; renovar pelo maior restante. Boss: teto 1 s, orçamento
compartilhado de 2 s de hard CC a cada janela fixa de 10 s da simulação; ao gastar
o orçamento, novas tentativas falham até a próxima janela. Revalida tempo real
incapacitado, não conta duas vezes controles sobrepostos. Knockback/pull não
desloca boss; debuffs de defesa funcionam dentro dos limites normais.

Boss não é banido/intangível: Banimento converte em slow mágico de 20% por até
2 s. Slow total máximo 50%, nunca torna move_speed negativo; aplicado após o stat
efetivo. Normais banidos ficam imóveis/intangíveis: não causam/recebem dano, não
colidem com tiros, seus DoTs e ações congelam; duração do banimento continua.
Não contam como mortos, continuam mantendo encontro ativo. Fear quebra após o
primeiro dano positivo de HP, inclusive DoT; mitigação/escudo sem perda de HP não.

Unstoppable impede stun/root/fear/pull/knockback durante a janela declarada;
não evita dano, obstáculos ou banimento. Dash valida segmento contra geometria.
Imunidade de boss/Unstoppable é testada antes de cobrar orçamento de CC.

Todo evento leva `root_event_id`, `event_id`, profundidade e flags. Dano secundário
não produz outro dano secundário; família de efeito trata cada alvo no máximo uma
vez por raiz. Limite de 16 aplicações secundárias por raiz, ordem determinística
por ID; excedentes descartados. Efeitos de terreno/transformação têm budgets próprios
no contrato de híbridas. Cada ação/tick tem quota; erros não criam recursão de sinais.

Orçamento global candidato de simulação: até20 inimigos simultâneos (piloto),
128 projéteis ativos e128 instâncias de efeitos de terreno. No teto de projéteis,
adiar a emissão de auto; uma skill que exige slots indisponíveis falha antes de
custo/commit. Não descartar projéteis hostis já emitidos para abrir slot ofensivo.
Objetos cosméticos têm pool próprio e não ampliam esses limites. E07/E08 medirão
custo real; estes tetos não equivalem a uma alegação de FPS.

## Exemplos de referência

| Entrada | Resultado |
|---|---|
| Espadachim L1, vetor 8/5/8/2/5/2, sem bônus | HP 180; SP 50; melee 28; precision 23.2; magia 16; DEF 20; DEFM 8; HIT 111.4; FLEE 108.9; APS 1.1 |
| HIT = FLEE | 90% acerto; igualdade do roll com 0.90 erra |
| HIT-FLEE = +500 / -500 | 98% / 5%, respectivamente |
| Dano 100, DEF 100, crítico 1.5 | 75 de dano antes de escudo/HP |
| S20/I30/D10, P1, pesos 0.6/0/0.4, DEF 100/DEFM 50 | Físico 32.4 e mágico 29.6 brutos; total mitigado 35.9333… → 36 |
| Cast fixo 0.2/variável 0.8, D50/I20, sem bônus | multiplicador 0.83; total 0.864 s; cooldown 4 s permanece 4 s |
| APS 4 | intervalo 0.25 s, ASPD 400 |

Fixtures e teste de propriedades em [E00.3](E00_03_DATA_SAVE_CONTRACT.md).
Valores são candidato de balanceamento; provas numéricas não substituem sensação,
dificuldade ou desempenho em partida.
