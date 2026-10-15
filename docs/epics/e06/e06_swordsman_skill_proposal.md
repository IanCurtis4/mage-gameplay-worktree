# E06 — proposta curta de árvore do Espadachim

**APROVADA pelo usuário em14/10/2026 — implementação autorizada no lote.** Base `3b2899940207d556c6d34babbb1560f1bd03e94e`, branch `codex/e06-inventory`. Escopo: [segunda rodada](e06_skill_ux_iteration_scope.md). Usuário aprovou skills/cachos e a política Job + investimento com reembolso dos investimentos incompatíveis. A implementação e os testes seguem o escopo da segunda rodada.

## Regra proposta

Árvore aberta em cachos independentes, com raízes livres e trajetos de um a três passos; sem tronco obrigatório e sem exigir maximizar o antecessor. Requisitos são ranks **aprendidos permanentes**; itens e rank escolhido na barra não substituem investimento. Todos os requisitos de uma célula são cumulativos. Valem desde R1 e continuam nos ranks superiores, junto do rank anterior. Contraforte/Ruptura conservam R1 gratuito sem pré-requisito.

Manter inicialmente os gates de job atuais: 20/23/25/28/31/34/37. Adicionar decisões por pontos sem alterar simultaneamente o ritmo de XP. Cada rank comprado custa 1 ponto na carteira da skill; ativas até R5, passivas até R3. Carteira base: até 19; evolução: job menos 20, até 20. Contraforte/Ruptura R5 custam quatro pontos; demais ativas cinco, passivas três. Não há pontos adicionais, conversão entre carteiras ou limite antigo de cinco ativas/dois passivos: são 24 atalhos e passivas legais automáticas.

## Skills atuais e requisitos propostos para R1

“Livre” significa apenas identidade/job/saldo, sem outro investimento. Job e efeitos desta tabela já existem; requisitos por skills são a proposta. O catálogo usa o mesmo job mínimo em todos os ranks: Resguardo R2 abre no job31, não no34.

| Defendente (`defender`; “Defensor” no pedido) | Job | Requisito proposto | Função e combo atual |
|---|---:|---|---|
| Contraforte | 20 | Livre, R1 grátis | Golpe + guarda frontal; prepara/consome token |
| Vigília | 23 | Livre | Melee direto positivo reduz dano causado pelo alvo |
| Marco de Guarda | 25 | Parede de Escudos2 | Zona de DEF/slow; segura corredor |
| Trava de Linha | 28 | Marco2 | Faixa com root; segura inimigos na zona |
| Resguardo | 31 | Contraforte2 | Evento frontal válido devolve SP |
| Avanço de Muralha | 34 | Investida2 | Realocação ofensiva e mitigação frontal durante avanço |
| Onda de Represália | 37 | Contraforte3 | Converte token em área; usa Marco se ativo, sem exigir comprá-lo |

| Berserker | Job | Requisito proposto | Função e combo atual |
|---|---:|---|---|
| Ruptura | 20 | Livre, R1 grátis | Abre ferida; autos/melee elevam cargas; reativação converte |
| Obstinação | 23 | Fúria3 | Bônus melee direto com HP até 50%; investimento não exige Fúria ativa |
| Salto Cruento | 25 | Investida2 | Aproximação ofensiva; alimenta ferida existente |
| Execução | 28 | Ruptura3 | Consome cargas, custa HP; bônus contra alvo até 35% HP |
| Caça Persistente | 31 | Ruptura2 | SP ao acertar ferida prévia, com intervalo interno |
| Fenda Sangrenta | 34 | Livre | Pressão em faixa e sangramento secundário |
| Arrancar Fôlego | 37 | Caça Persistente2 | Recuperação limitada em ferido sobrevivente; rota longa de sustentação |

A base permanece aberta: Corte, Investida, Parede de Escudos, Provocar, Perseverança, Grito Perfurante, Fúria, Golpe Brutal, Raiva Concentrada, Grito Aterrorizante; Resistência, Vigor e Sede de Sangue. Não acrescentar gates retroativos à base neste pacote.

## Quatro skills novas candidatas

Todas exigem implementação/validação futura; os efeitos são propostas, não APIs prontas. Ranks, SP e recargas abaixo são tuning inicial para avaliação.

| Skill nova / tipo | Job e requisito R1 | Efeito/combinação proposta | Custo e ranks |
|---|---|---|---|
| Rebater / ativa Defendente | 31; Resguardo2 | Golpe frontal curto, exige e consome token; converte resposta defensiva em dano focado, concorrendo com Onda/Contraforte pelo mesmo token | R1–5, 1 ponto evolução/rank; 18–26 SP, 8 s; peso melee 1,3–1,9 |
| Guarda de Retirada / ativa Defendente | 25; livre | Passo curto para trás mantendo frente capturada; guarda frontal breve sem dano. Reposiciona para voltar ao Marco, sem cura/invulnerabilidade | R1–5, 1 ponto evolução/rank; 16–24 SP, 10 s; distância 60–100; guarda 15%, 0,8 s |
| Talho de Perseguição / ativa Berserker | 31; Salto Cruento2 | Corte estreito direto mais forte se alvo já ferido; não cria ferida sozinho, acrescenta apenas a carga comum. Alternativa móvel à Execução | R1–5, 1 ponto evolução/rank; 18–26 SP, 7 s; peso 0,9–1,3, mais 0,3 contra ferido |
| Hemorragia Profunda / passiva Berserker | 37; Fenda Sangrenta3 | Aumenta somente duração do sangramento da Fenda em 0,5/1/1,5 s, preservando cadência e DPS; não cria cargas nem procs secundários | R1–3, 1 ponto evolução/rank; sem SP |

Cachos: Contraforte → Resguardo → Rebater; Parede → Marco → Trava; Contraforte → Onda; Guarda de Retirada isolada. Berserker: Ruptura → Caça → Arrancar; Ruptura → Execução; Investida → Salto → Talho; Fenda → Hemorragia; Fúria → Obstinação. Cruzar cachos continua permitido.

## Builds viáveis no job 40

Ranks efetivos; entradas descontam o R1 gratuito. Pontos não citados ficam livres.

| Build | Base /19 | Evolução /20 |
|---|---|---|
| Corredor | Parede3 + Perseverança3 + Resistência3 = 9 | Contraforte3(2) + Marco4 + Trava3 + Resguardo2 + Rebater3 = 14 |
| Guarda móvel | Investida3 + Vigor3 + Corte3 = 9 | Contraforte3(2) + Avanço4 + Onda4 + Vigília3 + Retirada3 = 16 |
| Executar e sustentar | Fúria3 + Sede3 + Golpe Brutal3 = 9 | Ruptura4(3) + Execução4 + Caça2 + Arrancar3 + Obstinação2 = 14 |
| Perseguir e sangrar | Investida2 + Vigor3 + Raiva3 = 8 | Ruptura2(1) + Salto3 + Talho3 + Fenda4 + Hemorragia3 = 14 |

## Limites e decisões humanas

Preservar Vigor fora de encontros; Sede converte VIT investida e cura por abate único. Auto continua sem slot e alimenta ferida existente. Defendente não ganha cura em combate; Berserker não ganha defesa gratuita. Token não acumula; custo HP de Execução continua não letal. Evitar que passivas automáticas tornem todos os cachos obrigatórios. Números exigem playtest, especialmente duração extra de DoT e mobilidade defensiva.

1. Aceitar os cachos e quatro candidatas? Recomendo Execução via Ruptura3 e Obstinação via Fúria3; Fúria3 para ambas é alternativa mais restritiva.
2. Manter job + pontos inicialmente (recomendado), ou substituir gates de job por investimento? A segunda opção muda acesso antecipado e exige nova análise econômica.
3. Para saves anteriores incompatíveis, aprovar migração versionada com reembolso dos ranks dependentes ilegais, sem compra automática dos antecessores? Recomendado; preservar XP, identidade e pontos, informar remoções e normalizar atalhos. Não aplicar gates novos diretamente ao carregamento legado.

Validação documental: confrontados catálogo/progressão atuais, [kit](../../E05_S2_SP_KIT_CONTRACT.md), [esclarecimentos](../../REVIEW_E05_S2_SP0_ASTRA.md), [barras atuais](../../SENTINEL_ACTION_BARS_PLAN.md), MVP/arquitetura e WORKFLOW. Aritmética das quatro builds conferida. Não executada suíte de gameplay; nenhuma mudança de runtime ou promessa de balanceamento.

