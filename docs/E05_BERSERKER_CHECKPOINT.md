# E05 — checkpoint único do Berserker

## Autorização e base — 27/09/2026

Usuário testou Defendente, deu aceite e liberou Berserker, incluindo identidade
visual. Candidato do diretório habitual 1e05a65 integrado em master.
Correções posteriores 6f24322 e atlas 9ddf668 existem apenas na branch E05;
preservar, declarar separadamente e incluir na próxima revisão técnica.
Não afirmar que o playtest anterior validou esses dois deltas.

## Ritmo e observabilidade

Continuar na tarefa E05 existente, conduzida por Sol. Pequenos commits por
skill/comportamento, sem handoff separado por skill nem gate Astra por passo.
Atualizar somente tabela curta neste documento: passo, status, hash, testes,
próximo passo e impedimentos. Antes/depois de cada skill, mensagem concisa ao
usuário identificando o passo. Ao esgotar limite, retomar da primeira linha
pendente; commits concluídos não devem ser refeitos.

Registrar tokens/uso por skill apenas se houver medição atribuível disponível;
caso contrário, informar não disponível e registrar tempo/rodadas, sem estimar
percentual da franquia a partir de linhas, duração ou número de testes.
A autorização permite continuar automaticamente entre skills. Não esperar
aceite nem disparar nova tarefa a cada uma. Um pacote consolidado de aceite
no fechamento da classe; escalar antes somente bloqueio/alteração de contrato.

## Escopo

Implementar cinco ativas e duas passivas Berserker já contratadas em
E05_S2_SP_KIT_CONTRACT.md, com precedência dos esclarecimentos de
REVIEW_E05_S2_SP0_ASTRA.md. Ruptura, Obstinação, Salto Cruento, Execução,
Caça Persistente, Fenda Sangrenta e Arrancar Fôlego. Preservar carteiras,
entrada gratuita não autoequipada, regras de ferida/consumo/custo HP, cura,
procs secundários e interação Fúria/Sede. Não reabrir tuning aprovado sem
motivo concreto. Duas builds legais e boss sem adds no fechamento.

Sequência retomável sugerida: decisão de catálogo/compatibilidade; Ruptura e
ferida; Execução; Obstinação; Salto; Caça; Fenda; Arrancar Fôlego; integração
visual; fechamento. Agrupar testes compartilhados sem agrupar todas as skills
num turno gigante. Sol cuida de estado/custoHP/procs/persistência; Terra integra
composições/visual sobre contratos prontos; Luna configura dados fechados se
houver lote útil. Um dono de escrita por arquivo; sem cadeia obrigatória.

## Identidade visual incluída

Direção inicial: fantasia coreana cartunesca de proporções compactas, atlas
64x64 compatível com pivô de pés e animações existentes. Manter continuidade
do Espadachim por cabelo/traços; distinguir pela arma de duas mãos de lâmina
larga, postura inclinada/agressiva e armadura assimétrica leve de ferro escuro,
couro marrom e tecido vermelho. Sem escudo-pavês. Poucos detalhes grandes,
silhueta legível e sombra assentada; evitar aumento de hitbox por tamanho da arma.

VFX: cortes diagonais curtos e ferida com até três marcas legíveis; indicador
claro de cargas/expiração e da conversão, sem depender só de vermelho. Preview
usa geometria real. Sangramento estilizado discreto, sem gore. Reutilizar
ritmo de animação existente e separar apresentação da aplicação de dano.
Produzir arte original pelo fluxo imagegen quando necessário, lendo a skill;
preparação local de bitmaps está autorizada no histórico. Não copiar sprites
comerciais. Atlas/VFX provisórios completos para teste, não exigir arte final.
Astra revisa visual e integração no fechamento da classe, sem gate por asset.

## Critérios de entrega

R0/R1/R5, limites de cargas, expiração, miss/escudo, custoHP não letal e atômico,
sem cascatas, pause/morte/limpeza, duas builds, menu→evoluir→comprar/equipar→
reload→run→XP job além20. Provar os botões admin e seleção em foco no fluxo.
Migração compatível antes de novos ranks persistíveis, save real nunca fixture.
content_ready de berserker somente após fechamento local; manter demais kits
incompletos indisponíveis. Regressões Defendente e três bases; verify.ps1
integral no fechamento, testes dirigidos entre passos.

Entrega consolidada aqui: hash, síntese, evidências e roteiro curto de playtest,
com imagem do atlas se útil. Parar para revisão Astra; não atualizar playtest
ou master, não iniciar outra classe. Sem monitor/automação recorrente.

## Progresso retomável

| Passo | Status / commit | Testes e evidência | Próximo passo / impedimentos |
|---|---|---|---|
| Catálogo 3→4 | Concluído `23bb710` | Migração aditiva de catálogo 3, preservação de build/XP e backup byte a byte, bloqueio de backup mais novo/estranho; 10 checks dirigidos. `tools/verify.ps1` integral passou no Godot 4.7.2. | Registrar sete skills Berserker com `content_ready=false`; nenhum impedimento. |
| Dados das sete skills | Concluído `09b41ec` | Biblioteca, gates job 20/23/25/28/31/34/37, R1 gratuito de Ruptura e ranks/custos registrados; 57 checks de catálogo e 65 de regressão E05 S1A passaram. `content_ready=false` permanece. | Implementar Ruptura e ferida no runtime; nenhum impedimento. |
| Ruptura e ferida | Concluído `bfb7996` | Criação após HP positivo, até três cargas por alvo, renovação/expiração, detonação secundária contestada, erro/escudo preservam marca, limpeza e pausa; 13 checks dirigidos. `verify.ps1` integral passou após atualizar a expectativa E03 de skills futuras. | Implementar Execução sobre a ferida; indicador/VFX de cargas no fechamento visual. |
| Execução | Concluído `97e53ae` | Custo HP não letal e sem evento de dano, validação atômica de SP/alvo/HP, um golpe direto com cargas anteriores e bônus inclusivo em 35% HP do alvo; miss/escudo preservam ferida. 12 checks dirigidos, 57 de catálogo, 20 de fundação e 73 de build Defendente passaram. | Implementar Obstinação; boss sem adds e VFX ficam para fechamento integrado. |
| Obstinação | Concluído `1313cdf` | R1/R3 aplicam somente ao melee direto com HP ≤50% na emissão, incluindo Execução depois do custo de HP; detonação, gritos e passiva não equipada ficam sem bônus. 17 checks dirigidos; Ruptura, Execução e build Defendente passaram novamente. | Implementar Salto Cruento; sem impedimento. |
| Salto Cruento | Concluído `f915d0a` | Destino/preview usam a mesma navegação segura; um hit direto no primeiro alvo alcançável, sem marca em salto vazio ou erro; cancelamento por Investida e limpeza impedem hit tardio. 15 checks dirigidos; `verify.ps1` integral passou após mudança do deslocamento compartilhado. | Implementar Caça Persistente; sem impedimento. |
| Caça Persistente | Concluído `2bcd892` | SP só em hit melee direto com ferida prévia, uma vez por segundo por jogador; criação inicial, miss, secundário e passiva fora do slot não acionam. Execução positiva pode acionar antes de consumir. 11 checks dirigidos, quatro suítes Berserker anteriores passaram. | Implementar Fenda Sangrenta; sem impedimento. |
| Fenda Sangrenta | Concluído `94cb471` | Faixa direcional 220×44 compartilhada com preview, preparo variável de 0,3 s antes dos atributos, hit direto e bleed físico de 4 s só após HP positivo. Um fluxo por dono/skill/alvo substitui sem empilhar, mantém cadência, coexiste com burn e congela em pausa; ticks secundários não alimentam ferida. 18 checks próprios e `tools/verify.ps1` integral passaram. | Implementar Arrancar Fôlego; sem impedimento. |
| Arrancar Fôlego | Concluído `3a8d214` | Cura só em alvo previamente ferido que sobrevive ao dano real, limitada a 5% do HP máximo e HP faltante; abate usa apenas Sede de Sangue. R0/R1/R5, SP, alcance/parede, erro, absorção e cap cobertos em 16 checks, três reruns dirigidos e `tools/verify.ps1` integral. | Fechamento integrado: builds legais, boss sem adds, fluxo menu→run, indicador/VFX e atlas exclusivo; sem impedimento. |
| Atlas e leitura da ferida | Concluído `ec2af70` | Dois sheets originais 4×4 transparentes gerados com `imagegen` a partir do Espadachim e reduzidos a um atlas 32×64×64; `CharacterAnimation` escolhe Berserker sem alterar a identidade de regras. Ferida mostra 1–3 marcas, arco de expiração e cortes breves, não só vermelho; testes dirigidos de animação (39) e Ruptura/indicador (16) passaram. | Validar builds/fluxo/boss, abrir `content_ready` somente após fechamento local e executar `verify.ps1` integral. |
| Fechamento integrado | Concluído `2fbf2e3` | `content_ready=true` só para Berserker; duas builds legais 13/19 base e 16/20 ou 15/20 evolução, boss solo com marca→cura→Execução (76 checks), menu→evolução→+1.000 XP job→compra/equipamento→reload→run→recompensa (16 checks). `tools/verify.ps1` integral passou no Godot 4.7.2 com as regressões Defendente e das três bases. | Revisão técnica consolidada de Astra; não mover playtest/master antes dela. |
| Gate de HP de Execução na UI | Concluído `f6c555c` | O mesmo predicado de custo HP do runtime agora informa HUD, card, mira e status: quando falta HP, exibe `HP INSUFICIENTE` em vez de `PRONTO`. A suíte dirigida de Execução passou com 16 checks, incluindo cena real; `tools/verify.ps1` integral passou novamente no Godot 4.7.2. | Revisão técnica concluída; preparar candidato de playtest. |

Tokens por passo: medição atribuível não disponível; não inferir uso semanal.
O schema e o ruleset não mudam. Catálogos 1/2/3 migram ao 4 somente após
validação completa; a migração transacional guarda o original no backup.
Nenhum save real foi usado como fixture ou regravado.

## Revisão técnica consolidada e entrega para playtest

Base aprovada por Astra: `codex/e05-evolutions` em `71a111c`.
Os commits Defendente `6f24322` e `9ddf668` também estão apenas nesta branch;
não foram cobertos pelo aceite de playtest anterior do usuário. Astra revisou
esses deltas conjuntamente com Berserker e não identificou bloqueios. Contratos de
persistência mantêm schema e ruleset; catálogo 4 é migração aditiva com backup.
O gate de Execução segue a clarificação de contrato HP atual > custo: mesmo
quando o HP é fracionário, o custo não pode zerá-lo. Isso difere da redação
anterior que dizia restar pelo menos 1 HP; não há mudança de regra neste
checkpoint. O achado de UX sobre `PRONTO` com HP insuficiente foi corrigido.
Astra reproduziu os 16 checks de Execução no candidato aprovado e inspecionou
os atlases estaticamente. A regressão integral após a correção passou na
execução do condutor; Astra reproduziu de modo independente a execução integral
anterior à correção. Aprovação técnica não substitui playtest ou aceite de produto.

Arte gerada pelo modo embutido `imagegen`, editando a folha original do
Espadachim para manter grade/poses/pivôs. Prompt resumido: evolução de fantasia
cartunesca compacta, cabelo reconhecível, espada larga de duas mãos, postura
agressiva, ferro escuro assimétrico, couro e tecido vermelho; fundo transparente,
sem escudo, gore ou cópia de franquia. Fontes finais:
`assets/art/animation_sources/berserker.png` e `berserker_extra.png`;
atlas integrado: `assets/art/animations/berserker.png`.

Roteiro manual de playtest após revisão técnica: evoluir um Espadachim no
job 20; um clique em `+1.000 XP job` deve mostrar job 22 e dois pontos livres,
mas Obstinação continua exigindo job 23. Ganhar mais XP, comprar/equipar a
passiva e Ruptura, salvar/reabrir e iniciar run com o personagem focado.
Conferir a silhueta de espada larga e as 1–3 marcas/expiração em combate;
num boss sem adds, abrir ferida, curar com Arrancar Fôlego em alvo sobrevivente
e converter com Execução. Testar também Fenda em alvo protegido por escudo.

Limitações: ainda não houve playtest humano deste candidato nem merge. A
inspeção estática e os testes automatizados não comprovam legibilidade durante
combate, sensação, balanceamento ou FPS; o boss automatizado não representa
uma partida humana completa. `master` permanece inalterada até aceite explícito
do usuário sobre o candidato testado.
