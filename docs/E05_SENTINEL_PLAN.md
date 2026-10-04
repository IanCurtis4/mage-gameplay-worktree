# E05 — Sentinela: execução por camadas

## Autorização, base e precedência — 03/10/2026

Usuário autorizou implementação da Sentinela por Sol 6.1, no mesmo formato da
Geômetra: trabalho granular retomável, sem handoff por skill, revisão Astra da
classe completa, seguida de playtest humano. Este contrato prevalece sobre
o kit antigo da Sentinela no E00 e sobre a sugestão anterior de Perfurante
independente do auto. Identidade `sentinel`, origem `archer`.

Continuar no chat E05 existente. Antes de editar, conferir estado e incorporar
o candidato revisado `e103162` (Geômetra + menu + correções Astra) à branch de
trabalho, preservando alterações locais. Geômetra está em playtest, não aceita
em master. Não alterar o diretório habitual/codex-playtest enquanto o usuário
testa, nem integrar Sentinela parcial nele. Sem merge em master, push, Caçador,
expansão do Espiritualista ou novo épico. Não cherry-pickar a branch menu-tabs
inteira: copiar apenas estes dois documentos para a base atualizada.

Ler AGENTS, MVP, ARCHITECTURE, WORKFLOW, REVIEW_WORK_PACKAGES e os contratos
Geômetra como referência de método, não como dependência de gameplay.

## Identidade e duas builds

Atirador que encontra janelas de estabilidade, prepara alvos, acumula Foco e
escolhe um disparo de precisão, linha ou área. Movimento custa oportunidade de
geração, nunca apaga a reserva durante combate. Builds são escolhas de pontos,
atributos e slots, não subclasses exclusivas nem modificadores ocultos.

- Crítica: DES/AGI/SOR; autos, Tiro na Cabeça e Tiro Perfurante.
- Caster: INT/DES/SOR; Rede, Explosivo e Perfurante. INT favorece impacto;
  DES favorece cadência. Sem obrigar o caster a escalar AGI para usar suas skills.

Sete ativas e duas passivas na biblioteca; manter cinco slots ativos e dois
passivos equipados. Esta ampliação da biblioteca é deliberada; não aumentar
slots/carteiras para caber tudo. Preservar 19 pontos base/20 de evolução e os
requisitos atuais de evolução. Só habilitar content_ready quando integrado.

## Foco e estado de combate

Recurso da run, separado de SP: 0–100, início 0, sem persistir em save.
Após 0,5 s sem deslocamento real, gera 10/s durante combate; autos/skills não
interrompem. Movimento/teleporte reinicia preparação, sem apagar Foco. Usar
deslocamento efetivo, com tolerância numérica; virar/mirar não é andar. Não
tratar personagem preso pressionando movimento como deslocamento realizado.

Reutilizar estado canônico de combate; se inexistente, definir em S0 critério
único observável que inclua encontros/boss ativos, sem consultar HP do alvo
selecionado como única fonte. Fora de combate: sem geração; após 3 s perde
10/s até zero. Pausa congela tudo. Morte/fim/reinício limpa Foco, marca, buffs
e preparos. Valores são tuning inicial centralizado, sem ganho por frame.

Observar e Leitura de Aberturas fornecem geração alternativa durante movimento.
Não ganhar Foco de DoT, dano secundário, alvo morto, miss ou dez vítimas do mesmo
tiro como dez eventos. Geração por impacto efetivo; custo por lançamento real.

## Semântica de reset de autoataque — decisão mais recente do usuário

Cabeça, Perfurante e Concussão são disparos ativos que resetam a recuperação
do auto, não casts longos e não meros bônus passivos. Ao confirmar comando
válido, o tiro especial pode sair durante a recuperação do auto anterior.
O tiro especial substitui o próximo disparo; nunca emitir auto comum junto.
Depois dele, começa uma recuperação normal de ataque. Cooldown próprio da
skill impede repetição. É permitido auto → skill → retomada normal dos autos;
não permitir skill + auto gratuito no mesmo frame por ordem de callbacks.

Um comando confirmado, alvo/linha válidos, recursos e skill pronta são necessários.
Não resetar no preview, selecionar, cancelar ou falhar validação. Respeitar
controle duro, pausa, alcance e obstáculos. Não disparar através do mapa para
consumir um preparo. Congelar pedido/atributos/crit no lançamento conforme
pipeline existente; projéteis não ficam mais fortes por mudança de atributo no voo.

Cabeça e Concussão usam smart lock de alvo único. Perfurante mira uma linha
no chão/cursor, inclusive sem alvo, e intercepta corpos ao longo do trajeto;
reset funciona mesmo sendo direcional. Isso é uma correção explícita em
relação à proposta anterior de três autos perfurantes: agora é UM disparo.

Tiro Explosivo prepara o próximo auto comum, não reseta sua recuperação.
Só um preparo de munição ativo. Pode cancelar com devolução da reserva antes
do lançamento; confirmação reserva SP/Foco, disparo consome e inicia CD.
Sem expiração arbitrária durante combate; morte/fim limpa. Troca de alvo válida
é permitida. Cabeça/Perfurante/Concussão não consomem Explosivo nem o somam
ao próprio dano. UI diferencia recursos livres/reservados. Revalidar ao disparar;
alvo que morreu antes do lançamento não consome, após lançamento não há refund.

## Kit e tuning inicial

Todos os números abaixo são ponto de partida de balanceamento. Sem mudanças
globais de atributos/dano/controle. Custos em SP e coeficientes finais são
calibrados por Sol em S0 com tabelas, mantendo estas direções e sem novo gate.
Ranks pagos sempre melhoram algo real, mostrado no menu.

| Skill / ID | Ranks / gate job | Contrato |
|---|---|---|
| Tiro na Cabeça / sentinel_headshot | 5 / 20 | Reset ST físico, DES/ataque de precisão, crítico normal baseado em SOR (sem crítico garantido). Gasta 30 Foco; CD base 6 s. Alto dano por uso; não exige cabeça anatômica nem execução por HP. |
| Observar / sentinel_observe | 5 / 20 | Marca um único inimigo por 8 s, sem dano. Próximos 3 acertos diretos próprios dão 6/7/8/9/10 Foco, cadência compartilhada 0,5 s. Auto ou skill; um tiro com múltiplos impactos conta uma vez. Custa SP, zero Foco; CD 10 s. Outra marca substitui a anterior; morte limpa. |
| Postura de Precisão / sentinel_precision_stance | 3 / 23 | Passiva equipada: depois de 0,75 s parado, +3/+6/+9 DES e +2/+4/+6 SOR efetivos. Remove imediatamente ao andar/teleportar. Uma fonte no StatCalculator, sem alterar atributos comprados ou acumular ao recalcular. Buff não conta a si mesmo para escalar. |
| Tiro Perfurante / sentinel_piercing_shot | 5 / 25 | Reset linear, base baixa e bons coeficientes separados de INT + DES. Um impacto por vítima, atravessa inimigos, para em obstáculo. Gasta 20 Foco; CD base 5 s. Alcance inicial igual ao alcance da skill de arco existente mais próxima; não infinito. |
| Tiro de Rede / sentinel_net_shot | 5 / 28 | Projétil de área mirando chão. Dano médio INT; root 1/1,25/1,5/1,75/2 s. Zero Foco, SP/CD próprios, CD inicial 10 s. Área fixa inicialmente, preparação curta reduzida por DES. Obstáculo intercepta; rede abre no primeiro contato válido, sem atingir através dele. |
| Tiro Explosivo / sentinel_explosive_shot | 5 / 31 | Próximo auto preparado: base boa + somente INT no dano, área radial no impacto. Gasta 25 Foco, CD 7 s. Dano da vítima principal e área não se somam duas vezes nela. Substitui dano do auto, sem embutir ATK/DES físico. |
| Leitura de Aberturas / sentinel_opening_read | 3 / 31 | Passiva equipada: acerto direto crítico OU contra alvo já sob root/stun recupera 2/3/4 Foco. CD interno compartilhado 1 s. Se satisfaz os dois, paga uma vez. AoE paga uma vez por ação. Controle recém-aplicado pelo mesmo impacto não qualifica esse impacto. |
| Tiro de Concussão / sentinel_concussion_shot | 5 / 34 | Reset ST de suporte, dano físico baixo de precisão, stun 0,4/0,5/0,6/0,7/0,8 s e redução de dano causado 10% por 2/2,5/3/3,5/4 s. Custa SP, zero Foco; CD 12 s. Controle/debuff por canais existentes; não knockback. |
| Foco Absoluto / sentinel_absolute_focus | 5 / 37 | Buff 4/4,5/5/5,5/6 s: alcance +20%, geração parado 15/s, dispensa a preparação de 0,5 s da geração (não a da passiva). Movimento permitido, sem geração passiva em movimento. Custa SP, zero Foco; CD 30 s começa ao ativar, sem auto-renovação. |

Tiro na Cabeça R1 grátis ao evoluir segue padrão vigente, sem autoequip.
Demais ranks comprados. Gates duplicados são deliberados para nove skills em
sete patamares; não mudar gates das demais classes. A passiva de Foco não
transforma Rede numa recuperação automática em cada vítima nem causa stun extra.

Rede prende movimento, não ataque/conjuração; não persiste como armadilha no chão.
Root/stun usam HardControlState e resistência/orçamento de boss existentes.
Debuff de Concussão usa canal de dano causado: vale o mais forte, sem somar fontes.
Controle não depende de crítico; crítico nunca alonga root/stun. Falha de controle
no boss não anula dano nem concede um recurso por um controle que não aconteceu.

## Matemática: contratos críticos e duas escalas

Dano, acerto e crítico passam pelo resolver central com DamageRequest; nada de
tirar HP na UI/ator ou duplicar fórmulas. Explosivo/Rede escalam exclusivamente
com INT no componente de atributo: não usar MATK derivado vigente sem correção,
pois ele também inclui DES. Perfurante usa INT e DES efetivos com coeficientes
aditivos explícitos. Cabeça/Concussão usam pipeline físico de precisão existente.
Sol define helper central/data-driven para dano por primários, se necessário,
com teste de isolamento; não mudar MATK global para encaixar duas skills.

Perfurante, Explosivo e Rede: dano direto mágico que pode critar pela SOR via
regra explícita do kit; colisão geométrica resolve acerto, não FLEE adicional.
Cabeça/Concussão mantêm acerto físico canônico. Não inventar múltiplos sorteios
de crítico para a mesma vítima ou transformar explosão em cascata de procs.

Redução de CD por DES apenas em Perfurante, Rede e Explosivo, centralizada:
fator inicial 1 - 0,25 * DES/(DES + 100), com DES efetiva não negativa.
Aplicar uma vez ao CD base e depois o contrato canônico de recarga, respeitando
seus limites. Não globalizar esta regra, nem confundir com redução de cast.
INT aumenta dano por uso, DES pode aumentar DPS por cadência; testar separadamente.

SP por rank cresce de modo sublinear: interpolar endpoints documentados com
sqrt((rank-1)/(max_rank-1)); usar helper existente se compatível. Não cobrar SP
adicional em impacto. Foco fixo por skill inicialmente, sem desconto por rank.
Cada rank ofensivo melhora dano linearmente; demais benefícios estão na tabela.

## Camadas e execução econômica

| Camada | Entrega | Evidência interna antes de avançar |
|---|---|---|
| S0 | Contrato técnico, tuning de dano/SP, responsabilidades, gates, duas builds legais planejadas | IDs existentes reconciliados; fórmulas com unidades; sete ativas/dois passivos sem inflar carteiras; decisões deste plano não reabertas sem motivo |
| S1 | Foco, estabilidade, Observar e Postura de Precisão | 30/60/144 Hz, pausa, movimento, cap, retorno fora de combate, fonte única, ação AoE sem multiplicar geração |
| S2 | Transação comum de reset + Cabeça | Auto→reset→auto; sem duplicação, comando inválido grátis, alvo morto/fora de alcance, custo/CD/crit centralizados |
| S3 | Perfurante e matemática INT/DES | Linha/corpos/obstáculos, uma vítima uma vez, isolamento de stats, redução de CD limitada e sem contaminar outras classes |
| S4 | Rede; depois Explosivo | Root por rank/boss; área/LoS; reserva/cancelar/disparo; principal sem dano duplicado; crit de área sem cascata |
| S5 | Concussão; Leitura de Aberturas; Foco Absoluto, um por vez | Stun/debuff canônicos, proc único com CD interno, buff sem empilhar, sem geração infinita no boneco ou pausa |
| S6 | Progressão/menu/save + duas builds completas | Compra real nas carteiras; equip 5+2; evolução fixada; gates ocultam indisponível; saves antigos; treino sem escrever progresso |
| S7 | Sprite/animações/VFX/onboarding e integração | Boss solo/adds, chão claro/escuro, legibilidade, verify completo, checkpoint único para Astra |

Feedback mínimo e preview acompanham cada skill; S7 finaliza arte e composição,
não adia toda indicação visual. Commits pequenos por skill ou unidade fechada;
checkpoint consolidado com último commit/teste/próximo passo. Sem relatórios
longos por microtarefa, sem pedir aceite para cada camada, sem estimar uso por
skill quando não houver medição real disponível. Ao atingir limite, retomar a
primeira unidade incompleta. Entregar classe completa; não parar em S0 por padrão.

Sol 6.1 conduz sistemas, matemática, transações e revisão interna. Terra pode
integrar UI/VFX sobre APIs prontas; Luna pode preencher textos/ranks/fixtures
fechados. Delegação opcional, dono único por arquivo, sem cadeia obrigatória.
Escalar apenas bloqueio ou mudança importante fora do contrato. Astra revisa
contratos críticos e fechamento completo, não recebe handoff por skill.

## Visual, animação e leitura

Referência existente: docs/references/CODEX_HANDOFF_MVP_2026-09-14/art/extended/
sentinel_sentinela.png. Verde, azul claro, branco e marrom claro; tecido/madeira,
arco longo, silhueta leve de atirador. Distinguir Arqueiro base e Geômetra.
Atlas segue pipeline existente e escala/pivô do personagem, sem sombra quadrada
ou flutuação. Estados de caminhar/mirar/disparar/hurt/morte legíveis, animação
acompanha velocidade real. Sol pode gerar arte original seguindo skill imagegen;
preservar referência/prompt/fonte e alpha; sem recolor improvisado como arte final.
Astra aprova o padrão na revisão integrada; pedir decisão apenas se houver
impedimento real ou mudança estética relevante, sem inventar assets inexistentes.

Foco: medidor simples perto do HUD, marca de recurso reservado e indicadores de
custos relevantes, sem painel permanente de debug. Parado: mira converge;
Observar: retículo preso ao alvo com três marcas consumíveis; Cabeça: trajetória
fina forte e impacto seco; Perfurante: linha clara que atravessa; Explosivo:
munição âmbar preparada e expansão radial; Rede: malha na área e laços nos pés;
Concussão: ponta romba/onda curta e indicação de stun; Absoluto: arco luminoso
discreto e mira aberta. Cor não é o único sinal. Preview = alcance/área reais.
Não cobrir telegraphs/atores com círculos e textos repetidos. VFX limitados por
evento/cena, cleanup com pause/death/restart. Onboarding curto e recolhível.

## Fechamento e playtest

Testar duas builds legais com atributos/pontos equivalentes e equipamento
controlado, não comparar fixtures com poder diferente. Crítica deve destacar
autos/Cabeça; caster Rede/Explosivo e burst; Perfurante útil em ambas. Medir dano
por uso, recarga, consumo SP/Foco e janelas de movimento contra boss e grupos;
não prometer equivalência de DPS nem compensar alvo imóvel com dano infinito.

Testes de invariantes novos, regressões direcionadas por unidade e
tools/verify.ps1 integral no fechamento, Godot 4.7.2 standard. Capturas com
renderer real para atlas/previews/combate denso e menu. Registrar limitações
de balanceamento/performance, sem confundir teste automatizado com aceite humano.
Um único E05_SENTINEL_CHECKPOINT.md; entregar commit limpo + evidências para
Astra. Somente após revisão preparar candidato de playtest; master só após
aceite explícito do usuário. Não atualizar a Geômetra que está sendo testada.
