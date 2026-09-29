# E05 — checkpoint único do Elementalista

## Aceite de produto — 29/09/2026

O usuário jogou o candidato visual `ce87065`, aprovou o Elementalista e liberou
o Espiritualista como próxima classe do Mago. Astra integrou o candidato aceito
em `master`; o usuário exige playtest do Espiritualista antes das classes do
Arqueiro. O balanceamento transversal de tamanho/alcance das skills e a divisão
entre baseline e augments permanecem futuros, sem reabrir o kit aceito aqui.

## Ajuste visual solicitado no playtest — 28/09/2026

Usuário reprovou a simplicidade/ausência percebida dos VFX e a apresentação do
sprite no candidato `dd94ffb`. Autorizou esta correção apenas do Elementalista:
fogo crepitante visível, raio estilizado trepidante e gelo cristalino protuberante.
O pedido de pacote visual das outras classes será feito separadamente pelo usuário;
não foi iniciado. Aprovação anterior não cobre automaticamente este delta.

Diagnóstico: atlas anterior repetia poses e usava caminhada de frente na linha
de caminhada de costas. Nova fonte imagegen preserva identidade azul/branco/cajado,
com passos alternados e orientações corretas. Preparação mecânica reproduzível por
`tools/prepare_elementalist_atlas.gd`, fonte e prompt em
`assets/art/animation_sources/elementalist_visual_polish.*`. Pivô medido nas botas
na resolução final, contato y=58 e recortes inteiros explícitos de 64×64; offsets
também preservados em cópia de morte. Teste cobre todas as 32 regiões, chão, centro
das botas e distinção de passos/orientações. Não afirmamos que divisão fracionária
era a causa: extração explícita é proteção/testabilidade do recorte de runtime.

VFX code-native: Explosão produz erupção radial de línguas preenchidas com núcleo
amarelo, flicker e brasas; Trilha conserva seus três centros sequenciais, com focos
compactos de fogo. Anel tem espinhos verticais facetados distribuídos radialmente,
crescimento e estilhaços. Arco liga cajado→alvo→saltos com descargas multicamada,
jitter por tempo de simulação e ramificações, além dos três impactos independentes.
Nova mantém sua emissão fogo/gelo/raio a 0/0,25/0,50 s e respectivas leituras.
Foco exibe prisma no jogador somente após SP realmente recuperado; Ressonância
exibe prisma no alvo no terceiro elemento direto positivo elegível. Cabeçalho da
run agora diz Elementalista, mantendo origem de gameplay `mage`.

Nenhum dano, alcance, SP/cooldown, gate, seleção de alvo, marca, stun, RNG de combate,
perfil ou migração alterado. Caudas exclusivamente visuais: impactos 0,65 s,
links 0,40 s, prismas 0,45 s. Três filas independentes com cap 64 cada (máximo
192 registros), pausa, finitude e expiração. Não são persistências de dano/CC.

Validação local: `tools/verify.ps1` integral com importação no Godot 4.7.2, exit 0,
103 scripts PASS. Após acabamento final de desenho/normalização, repetir testes
dirigidos e renderer, e submeter o delta consolidado a Astra antes de playtest.
Capturas pelo OpenGL Compatibility real: três tempos 0,10/0,35/0,60 s e arena/HUD
real com escala nativa; helper `tools/elementalist_visual_review.gd`, resultados
locais ignorados em `.godot/verification/elementalist_visual/`. Prancha selecionada
em `docs/art/elementalist_visual_polish.png`. A arena usa fixture isolada, não save
do usuário, e os VFX são injetados para inspeção visual; os testes dirigidos cobrem
callbacks reais. Não é evidência de FPS, áudio, satisfação visual ou partida humana.

Estado: Astra aprovou tecnicamente o delta runtime `8970733` em 29/09/2026,
sem bloqueios, após `tools/verify.ps1` integral no Godot 4.7.2 (103 scripts,
exit 0). Parecer: `docs/REVIEW_E05_ELEMENTALIST_VISUAL_ASTRA.md`. O único
acréscimo posterior ao runtime é documentação de revisão/preparação.
Preparação concluída em 29/09: `codex/playtest` estava limpo em `dd94ffb`,
ancestral do candidato. A referência
`codex/e05-elementalist-playtest-before-visual-dd94ffb` preserva o estado
anterior. Após o parecer de Astra, `codex/playtest` avançou por fast-forward
até `4085a5b` (runtime `8970733` mais documentação). No diretório habitual do
Godot, importação e testes dirigidos passaram: animação7, visuais8, integração
visual6, indicadores13, Arco16, fechamento integrado34 e smoke exit0. Este
registro final é apenas documental e será incluído no mesmo candidato, sem
alteração adicional do runtime aprovado. `master` permanece `21c7793`, sem
merge/push. Cabe ao usuário aceitar o novo candidato após playtest. Outras
classes não foram iniciadas.

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

### Parecer Astra — classe integrada aprovada

Revisão independente do delta `21c7793..52ea1b5`: aprovação técnica sem
bloqueios remanescentes. O P2 de impactos simultâneos do Arco foi corrigido
em `52ea1b5`: cada pulso conserva centro, elemento e prazo próprios, com
limite de 64 instâncias, pausa e expiração; a correção não altera dano.

Astra revisou catálogo/migração e backup, carteiras/gates, cópia e propagação
de `emission_id`/bônus de Ressonância, precisão/Eletrizado, limites de procs,
sequências finitas, limpeza e integração menu→run. Reproduziu de forma
independente `tools/verify.ps1` integral após a correção, com importação no
Godot 4.7.2, exit 0 e todos os 101 scripts passando. Entre eles: migração11,
catálogo99, indicadores13, Arco15, Foco15, Ressonância14, integrado33 e
regressões das bases, Defendente e Berserker. `git diff --check` limpo.

Atlas inspecionado estaticamente e aceito como apresentação provisória:
continuidade do Mago, azul/branco/cristal e silhueta própria. As poses
reaproveitadas e VFX nativos continuam limitações declaradas; não há evidência
de FPS, sensação, balanceamento ou legibilidade em partida humana. O boss
automatizado é um ator com perfil de boss, não uma partida completa.

Preparação de playtest autorizada pelo workflow após este parecer; aceite
de produto e merge em master continuam dependentes do usuário. Espiritualista
e demais classes não foram liberados.

### Preparação do diretório habitual

Ambos os worktrees estavam limpos. Base `master`/`codex/playtest` verificada
em `21c7793`; backup `codex/e05-elementalist-pre-playtest-d2a131c` criado
em `d2a131c` antes do rebase. A base já era ancestral: rebase sem alterações
ou conflitos. `codex/playtest` avançou por fast-forward até `d2a131c`.
Neste diretório, importação Godot 4.7.2, fechamento integrado33, Arco15 e
indicadores13 passaram novamente. O ajuste seguinte é apenas este registro
documental, sem mudança do runtime aprovado `52ea1b5`.

Projeto de playtest: `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/project.godot`.
Editor existente preservado; aceitar reload de arquivos se solicitado e usar
F5. Nenhum merge em master ou push foi executado. `master` continua `21c7793`.
O candidato final pode incluir este registro documental; conferir o HEAD de
`codex/playtest` na entrega. Atlas importado sem delta de conteúdo; worktrees
limpos ao concluir a preparação.

Roteiro curto: evoluir Mago no job20, confirmar entrada gratuita sem autoequip,
ganhar XP job pelos controles de playtest e equipar exclusivas/herdadas.
Reabrir perfil e iniciar a build focada. Alternar fogo/gelo/raio num alvo,
observar SP/ressonância e os três impactos do Arco; testar Trilha junto a
obstáculos, Nova em movimento, pausa e morte. Avaliar silhueta e VFX no jogo.

Base aceita `21c7793` (master/playtest); runtime final `1921857` sobre
`7130053`. As sete exclusivas, catálogo aditivo 4→5, atlas, cinco previews e
impactos, persistência/menu/run/recompensas estão fechados. Revisar a classe
integrada, especialmente campos runtime novos de DamageRequest, precisão e
marca/budget de boss, emissão única, pausa/limpeza e fonte de geometria.
Se houver achados, corrigir neste escopo e repetir testes afetados; não
liberar Espiritualista nem iniciar balanceamento transversal. Aprovação
técnica não equivale a aceite do produto.

## Rodada Astra — correção de impactos simultâneos

Astra identificou sobrescrita visual no Arco: três chamadas síncronas do
impacto usavam um único registro, escondendo os dois primeiros alvos antes
do frame. BattleIndicators agora mantém até 64 pulsos independentes,
desenha todos e expira cada um em tempo de simulação; nenhuma regra de dano
mudou. Testes dirigidos após correção: indicadores Elementalista 13, Arco15
(inclui três centros pelo handler real), Nova12, Trilha11, indicadores
Defendente11 e fluxo integrado33, todos PASS. Astra conduz a execução
integral independente e o parecer final antes de preparar playtest.
