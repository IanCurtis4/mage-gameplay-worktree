# E05 — checkpoint único do Elementalista

## Autorização e base — 27/09/2026

O usuário jogou e aprovou Berserker no candidato `21c7793`; `master` e
`codex/playtest` já apontam para ele. Autorizou Elementalista como próxima
evolução do Mago, incluindo atlas e VFX, com commits pequenos por comportamento
e revisão Astra somente após fechar a classe. Espiritualista e demais classes
não estão liberadas. Tamanhos/alcances e separação baseline versus augment são
balanceamento transversal futuro, não escopo deste kit.

Usar esta branch `codex/e05-evolutions`; não mover playtest/master durante a
implementação. Sol é dono do runtime e persistência; Terra pode ter arquivos
visuais próprios, Luna dados fechados. Um dono de escrita por arquivo. Antes e
depois de cada habilidade, informar brevemente o passo; guardar aqui hash,
testes e próximo passo para retomada. Não inferir tokens por skill sem medição
atribuível disponível. Ao esgotar limite, retomar a primeira linha pendente.

## Base normativa e identidade

E00_MVP_CLASS_CONTRACT fixa origem `mage`, sete exclusivas com gates job
20/23/25/28/31/34/37, entrada R1 gratuita não autoequipada, carteira base
19/evolução20 e limite 5 ativas/2 passivas equipadas. Ranks ativos1–5 e
passivos1–3; rank pago custa um ponto. Mago E04 já tem fogo projétil/parede,
gelo lança/parede sólida, raio marca Eletrizado e Descarga que consome marca
para bônus/chance de stun. Reutilizar DamageRequest, StatCalculator, cast DES,
HardControlState e regras de pausa/limpeza. O brainstorm cita tempestade,
geada e meteoro como inspiração histórica, não números fechados. A linguagem
visual aprovada é cristal/energia, formas prismáticas e radiais, azul/branco
com acentos fogo/raio; continuidade do Mago sem roupa RGB nem cópia de sprites.

## Kit implementável — escolhas locais dentro do contrato

Fogo causa somente dano, sem CC ou queimadura baseline. Gelo causa dano mágico
e slow garantido após dano positivo em alvo sobrevivente, sujeito ao teto
compartilhado de 50%. Raio tem dano adicional no alvo previamente Eletrizado;
consome a marca apenas após dano positivo e faz uma rolagem de 25% para stun
0,6 s, sempre pelo orçamento/resistência de boss de HardControlState. Se não
estava marcado, um acerto positivo em sobrevivente aplica Eletrizado por 4 s.
Nenhum tick secundário dispara passivas, augments ou novas cadeias.

| Gate | Skill / ID | Forma R1 e números iniciais | Papel e distinção da base |
|---|---|---|---|
| 20 ativa gratuita | Explosão de Chamas `elementalist_flame_burst` | Ponto até 380; raio 90; cast DES 0,45 s; SP 20, CD 6 s; 1,30× ATQM | Detonação pontual única, dano puro; não é projétil nem parede. |
| 23 passiva | Foco Prismático `elementalist_prismatic_focus` | Após dois acertos diretos positivos de elementos diferentes no mesmo alvo em até 5 s, restitui 2/3/4 SP por rank; no máximo uma vez/s por jogador e uma vez por emissão. | Incentiva alternar elementos herdados/exclusivos, inclusive no boss; não aciona em DoT/secundário. |
| 25 ativa | Anel Glacial `elementalist_glacial_ring` | Centro no Mago; raio 145; cast DES 0,35 s; SP 19, CD 8 s; 0,90× ATQM; slow 40% por 2,5 s. | Defesa radial de espaço, não lança nem parede sólida; slow após dano positivo. |
| 28 ativa | Arco Voltaico `elementalist_lightning_arc` | Alvo único inicial até 380; salta a até dois outros alvos a 110 do anterior, sem repetir; cast DES 0,35 s; SP 22, CD 8 s; principal 1,10× ATQM, saltos 0,60×; marcado +0,40×. | Acerto direto/único no boss; cadeia finita, saltos secundários sem proc; marca/bônus/stun somente com regra Eletrizado. |
| 31 passiva | Ressonância Prismática `elementalist_prismatic_resonance` | Três elementos distintos com dano direto positivo no mesmo alvo em até 6 s: o terceiro golpe ganha +0,25/0,35/0,45× ATQM por rank antes da mitigação e reinicia sequência. | Payoff de sequência sem nova barra de recurso; não proca em acertos secundários, misses ou dano zero. |
| 34 ativa | Trilha de Brasas `elementalist_ember_path` | Direção até 240; três círculos de raio 55 a 80/160/240 do Mago, com 0,15 s entre erupções; cast DES 0,50 s; SP 24, CD 10 s; 1,10× ATQM no máximo uma vez/alvo/emissão. | Dano puro em progressão espacial; não é Fire Wall persistente nem a detonação pontual de job20. |
| 37 ativa | Nova Tríplice `elementalist_tri_nova` | Centro no Mago; raio 170; cast DES 0,65 s; SP 30, CD 16 s; três pulsos a 0/0,25/0,50 s: fogo 0,70×, gelo 0,55× + slow, raio 0,60× + regra Eletrizado. | Assinatura das três formas. Só primeiro pulso é raiz de procs; demais são secundários, sem cascata. |

Ranks superiores crescem com margens decrescentes e custo SP moderado, sem
alterar geometria/alcance silenciosamente. Passivas só funcionam equipadas.
Passivas reconhecem fogo (Bola/Lança de Fogo e exclusivas), gelo (Lança de Gelo
e exclusivas) e raio (Relâmpago/Descarga e exclusivas); paredes/ticks passivos
não alimentam sequência. Combos não exigem kills ou adds. Fraqueza deliberada:
exposição durante conjuração e custo SP alto se não alternar elementos.

## Critérios e progresso

Migrar catálogo 4→5 de modo aditivo antes de salvar novos IDs; schema/ruleset
não mudam, backup preservado. Nenhum save real como fixture. Habilitar
`content_ready` somente após sete skills, atlas/VFX, duas builds legais,
menu→evolução→XP job→compra/equipamento→reload→run→recompensa, boss solo,
rank R0/R1/R5, SP/cast DES, colisão/áreas, pausa/cleanup e regressões de
Mago/Defendente/Berserker/bases. Executar `tools/verify.ps1` integral.

| Passo | Status / commit | Evidências | Próximo passo / bloqueio |
|---|---|---|---|
| Catálogo 4→5 e dados | Concluído `7b62c8f` + `cc2b2ab` | 99 checks de dados; migração 4→5 em 11 checks, regressões das migrações 2/3 em 13/10. `tools/verify.ps1` integral passou no Godot 4.7.2 após atualização de expectativa S1A; schema/ruleset iguais, backup exato, `content_ready=false`. | Implementar Explosão de Chamas. |
| Explosão de Chamas | Concluído `d0855df` + VFX `63b8c00` | 10 checks: cast DES cancelável, sem SP no cancelamento/posição bloqueada, raio real 90, não atravessa obstáculo, request direto por alvo; indicadores passaram 7 checks. | Implementar Foco Prismático. |
| Foco Prismático | Concluído `5b1e3a1` + `7130053` | 15 checks: alternância por alvo, janela 5 s, gate 1 s e uma restituição/emissão mesmo em hit tardio, ranks R1/R3, somente equipada, callback de dano real, pausa, limpeza e teto SP; Explosão regressão 10 checks. | Revisão consolidada. |
| Anel Glacial | Concluído `b90187d` | 11 checks: cast/cancelamento/SP, área/obstáculo, slow positivo garantido, absorção, teto compartilhado, pausa/expiração, R0/R5; Explosão regressão 10 checks. | Implementar Arco Voltaico. |
| Arco Voltaico | Concluído `c7f2ebb` | 14 checks: cast/SP/request contested, três alvos sem repetição, saltos secundários, marca/bônus/absorção, boss solo e teto/budget stun, alcance/obstáculo. Cadeia só continua após dano positivo (inclui raiz); sem alvo válido termina. Anel regressão 11 checks. | Implementar Ressonância Prismática. |
| Ressonância Prismática | Concluído `845db52` | 14 checks: três distintos, janela desde primeiro golpe, bônus bruto copiado/pré-mitigação, absorção preserva sequência, terceiro positivo reinicia, secundário excluído, pausa/expiração/limpeza, R1/R3/equipamento; Foco 13, Relâmpago 66, Descarga 69 regressões. | Implementar Trilha de Brasas. |
| Trilha de Brasas | Concluído `156b5f1` | 11 checks: círculos 80/160/240, intervalos 0,15, centro capturado, um hit/alvo mesmo sobreposto, pausa, raio, truncamento antes de parede, bloqueio atômico, cancelamento por morte e R5; Anel 11 regressão. | Implementar Nova Tríplice. |
| Nova Tríplice | Concluído `900483d` | 12 checks: cast/SP, componentes 0,70/0,55/0,60, só raiz fogo, pulsos 0/0,25/0,50, centro capturado, slow/marca, sem auto-procs, pausa/raio/R0/R5; Trilha 11, Arco 14 regressões. Sequências são descartadas em morte e fim da run/encontro. | Revisão consolidada. |
| Atlas e VFX | Atlas `11bb421`; previews/impactos `2bc8676` + `63b8c00` + runtimes acima | Atlas original 256×512, teste visual 3 checks, importação 4.7.2; `PlayerActor` seleciona pelo `evolution_id`. Cinco previews/impactos ligados; indicadores 9 checks incluem preview truncado da Trilha usando a geometria real. Geração entregou seis linhas distintas úteis, com poses compatíveis reutilizadas nas demais células; pivô/hitbox preservados. | Aprovação visual depende de Astra e playtest; não alegar 32 poses únicas. |
| Fechamento integrado | Concluído `7130053` + `1921857`; revisão Astra pendente | `content_ready=true` somente Elementalista; teste produção 33 checks: confirmação/XP pelos botões reais, gates/carteiras, duas builds (pura e herdadas), reload, cena/HUD/atlas/snapshot R5, boss solo/dano real, recompensa e reload final. `tools/verify.ps1` integral com importação Godot 4.7.2 passou (exit 0, 101 scripts de teste) após ajuste final de deduplicação por emissão; `git diff --check` e worktree limpa. | Entrega única para Astra; candidato só vai ao diretório habitual após aprovação técnica. Merge depende do aceite explícito do usuário. |

Tokens por passo: medição atribuível indisponível nesta tarefa; não estimar
consumo semanal a partir de tempo ou número de testes.

Contrato crítico para Astra: `DamageRequest.prismatic_resonance_damage` é um
campo runtime opcional (default 0) e copiado, capturado com ATQM/rank no commit
da ação. No impacto, apenas o alvo com dois elementos diretos distintos e a
passiva equipada recebe esse valor somado ao componente mágico antes de
CombatMath; misses/absorção/secundários não consomem a sequência. Não muda
serialização, catálogo, fórmulas nem o comportamento do Mago base.

`DamageRequest.emission_id` (default 0) identifica runtime a conjuração do
Elementalista; é copiado por projéteis/pulsos e ecoado no resultado de
CombatMath sem interferir no dano. Foco registra as emissões já restituídas
até limpeza do encontro/run, além do cooldown global de 1 s; isso evita uma
segunda restituição de projétil/erupção tardia da mesma conjuração.

Limites concretos: testes headless não provam diversão, balanço de raios,
FPS nem legibilidade em combate real. Atlas tem poses reaproveitadas; VFX são
formas nativas provisórias. Balanceamento transversal e augments novos não
foram iniciados. Nenhum save real é fixture; nenhum master/playtest foi movido.

## Entrega técnica — 27/09/2026

Base aceita `21c7793` (master/playtest); runtime final `1921857` sobre
`7130053`. As sete exclusivas, catálogo aditivo 4→5, atlas, cinco previews e
impactos, persistência/menu/run/recompensas estão fechados. Revisar a classe
integrada, especialmente campos runtime novos de DamageRequest, precisão e
marca/budget de boss, emissão única, pausa/limpeza e fonte de geometria.
Se houver achados, corrigir neste escopo e repetir testes afetados; não
liberar Espiritualista nem iniciar balanceamento transversal. Aprovação
técnica não equivale a aceite do produto.
