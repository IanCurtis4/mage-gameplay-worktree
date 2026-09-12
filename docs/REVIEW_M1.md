# Revisão técnica e playtest — Marco 1

## Identificação

- Implementador: Sol, tarefa `01a08e8a-bbc3-7391-9e4f-a84cc18e4e3a`.
- Branch da tarefa: `codex/m1-arena-combat`.
- Entrega inicial: `dd8a4a0`, sobre a fundação `41ff198`.
- Base do fluxo fixo de playtest: `26e0263` em `codex/playtest`.
- Candidato corrigido aprovado por Astra: `218387b`.
- Candidato de gameplay após rebase: `97cbde6`, disponível em `codex/playtest`.
- Backup anterior ao rebase: `codex/backup-m1-before-playtest-rebase` → `218387b`.
- Status: candidato `e70e4d4` aceito pelo usuário em 12/09/2026 ("ficou muito bom")
  e integrado em master por fast-forward, sem trocar a branch do projeto habitual.
  A UI de batalha seguinte tem revisão e aceite próprios em `docs/REVIEW_BATTLE_UI.md`.

## Primeira rodada de revisão

Astra solicitou correções na tarefa original, dentro da autorização do usuário:

- Impedir avanço de encontro antes da coleta e resolução da recompensa.
- Corrigir aplicação de dano com HP restante fracionário e manter morte única.
- Recalcular mana preservando déficit, conforme o contrato de recursos atuais.
- Garantir que os segmentos de navegação, inclusive inicial/final, respeitem obstáculos.
- Tornar flechas direcionais, esquiváveis, bloqueadas por obstáculos e com expiração.
- Preservar título de escolha de augment e verificar bounds da interface.
- Ampliar testes de vitória, reinício e pausa real do runtime.

Reprodução independente em `dd8a4a0`: o segmento (992,544) →
(978.6676,557.6087) atravessa obstáculo inflado pelo raio de 22 unidades.
Um probe determinístico com 3000 pares de pontos encontrou 1 segmento inválido
em 53661 segmentos amostrados. A hipótese de painéis fora do viewport não se
confirmou em 1280×720; o título de escolha ausente foi confirmado na imagem renderizada.

## Checklist do playtest do usuário

No projeto fixo, execute F5 depois da disponibilização do candidato aprovado por Astra:

1. Clique no chão perto das quinas e atrás dos obstáculos; confirme percurso e parada.
2. Clique em um perseguidor, observe aproximação/autoataque e cancele clicando no chão.
3. Use Q e W na direção do cursor; observe gasto de mana, recargas e bloqueio de movimento.
4. Termine o encontro 1, toque no cristal, aperte E e confirme uma escolha.
5. Verifique que o menu pausa o jogo e que o bônus escolhido tem efeito.
6. Inicie o encontro 2 com Espaço; tente esquivar das flechas e usar obstáculos como cobertura.
7. Vença os dois encontros e selecione a recompensa final; reinicie com R.
8. Em outra tentativa, deixe o personagem morrer e confirme que R reinicia sem augments antigos.

Este marco é uma arena técnica com arte provisória. Não contém as três fases,
boss, Mago, equipamentos, cartas ou save. Diversão, dificuldade e desempenho
não são considerados aprovados só porque os testes automatizados passaram.

## Decisão final

Astra aprovou tecnicamente `218387b` após revisão de código, testes independentes
e inspeção das capturas renderizadas da arena e do menu. A navegação corrigida
passou pelo mesmo probe de 3000 pares: 53202 segmentos amostrados, zero atravessamentos.

O rebase sobre `26e0263` produziu `4463542` e `97cbde6`. `git range-diff` confirmou
equivalência dos dois patches originais e rebased, sem conflitos. A branch de
playtest avançou por fast-forward até `97cbde6`; master permaneceu em `41ff198`.

Verificação final no diretório fixo, com Godot 4.7.2:

- Fundação: 11/11.
- Regras do Marco 1: 37/37.
- Fluxo integrado: 24/24.
- Layout: 12/12 em 1280×720 e 1920×1080.
- Importação e smoke da cena principal: aprovados.

Comando: `./tools/verify.ps1 -GodotPath '.tools/review-engine/Godot.exe'`.
A engine de revisão é self-contained e os logs ficam em `.godot/verification/`.
O plugin Git adicionado pelo usuário e sua configuração em `project.godot` foram
preservados como alterações locais não incluídas no commit. A primeira execução
na sandbox falhou por diferença de proprietário no GitPlugin; a execução autorizada
no contexto normal do usuário passou integralmente, incluindo o plugin instalado.

O jogo pode ser testado com F5 no projeto habitual. Se o Godot já estiver aberto,
parar a partida anterior e aceitar o reload de arquivos alterados externamente.
Este relatório não equivale ao aceite do usuário: ainda não houve merge em master,
aprovação de diversão/dificuldade ou medição de FPS.

## Retorno do primeiro playtest

O usuário conseguiu jogar e relatou três problemas: skills deixam de funcionar
após alguns usos; movimento pouco fluido com grid muito rígido; seleção/perseguição
para ataques básicos exige precisão excessiva. A rodada de correção continua em M1.

Diagnóstico independente no candidato anterior:

- Espadachim possui 50 de mana, Q custa 15 e W custa 20; não há regeneração.
  Após três Q, mana fica em 5 e permanece em 5 mesmo após 10 segundos vivo.
  O HUD exibe PRONTO com base só na recarga e omite o bloqueio por mana.
- O segmento caminhável (300,520) → (500,610) retorna 9 waypoints e percorre
  290,35 unidades, contra distância direta 219,32, desvio de aproximadamente 32%.
- Seleção usa raio fixo de 46 e autoataque alcance de centro a centro 62;
  perseguição replana via centros da grade, sem tolerância distinta para manter alcance.

Critérios desta rodada: regeneração com pausa/morte corretas e custo/bloqueio
explícitos no HUD; movimento direto em região livre, simplificação segura ao redor
de obstáculos e orçamento de distância contínuo por frame; seleção tolerante com
prioridade do alvo visual, feedback de alvo e perseguição estável sem ataques através
de paredes. Sol implementa e testa; Astra verifica e prepara novo candidato neste caminho.

Próximo marco só será liberado após resolver este retorno e obter o aceite do usuário.

### Interrupção e revisão independente

A tarefa de Sol foi interrompida pelo limite de uso antes do commit, com dez arquivos
de código/testes modificados. O checkout fixo permaneceu em `355cecf`.
Na cópia independente da implementação em andamento, o percurso aberto já foi
reduzido a um destino e 219,32 unidades, mas o teste de movimento revelou um loop.

Reprodução: posição (512,480), destino (1500,480), velocidade 220 e delta 1/30.
O deslocamento real em Vector2 foi 7,33331298828125, deixando orçamento positivo
0,00002034505208; na iteração seguinte o deslocamento real era zero e nenhum guard
encerrava o loop. Sol recebeu o caso para corrigir consumo/término do orçamento
nos dois atores e verificar frames em 30/60/144 Hz antes de concluir a entrega.

### Aprovação técnica da rodada de feedback

Entrega de Sol: `6e84b3d`, sobre `355cecf`, com worktree limpa. Astra revisou os
laços corrigidos, regeneração, navegação, seleção e alcance; conferiu capturas do
HUD SEM MANA e anel de seleção. A cópia isolada do commit passou 125 verificações
(12 fundação, 63 M1, 32 fluxo, 18 layout), importação e smoke.

O probe independente passou 11 verificações: percurso aberto com um destino,
219,32 unidades; deslocamento consistente em 30/60/144 Hz; desvio contínuo;
regeneração e reutilização da skill; perseguição móvel com três ataques e zero
passos para trás; cancelamento e pausa real.

Backup: `codex/backup-m1-feedback-before-rebase`. Rebase sobre `codex/playtest`
não exigiu mudanças; checkout fixo avançado por fast-forward para `6e84b3d`.
`tools/verify.ps1` repetido no projeto real com GitPlugin: 125 checks, import e
smoke aprovados. Configuração local do plugin e `addons/` preservados e não commitados.

Master permanece sem integração. Sensação de movimento, tolerância de seleção,
balanceamento da mana e FPS real dependem do novo playtest do usuário.

## Segunda rodada de feedback — 12/09/2026

O usuário considerou o movimento mais fluido, pediu aceleração/atrito e relatou que
o auto ainda não alcançava arqueiros. Pediu implementação direta por Astra e passos
commitados separadamente para retomada após interrupções de limite.

Reprodução com a IA real: zero autos em 10 s em todas as seis combinações de
30/60/144 Hz e ordem de atualização. A rota antiga parava em uma posição anterior
do alcance do arqueiro, deixando o jogador a 112–122 unidades (alcance inicial 87).
O teste anterior com alvo artificial lento não cobria esse comportamento.

- `253bdf2`: perseguir a posição do alvo, conferir contato antes/depois do movimento
  e recuperar por 0,14 s após emitir o golpe. Alcance, dano e IA inimiga preservados.
- `1f47418`: impulso vetorial, aceleração, frenagem, curvas, colisão segura e arco do
  auto. Com o peso aplicado, 7–8 autos em 10 s no mesmo teste de arqueiro em fuga.

Revisão técnica do código por Astra; suite completa com 158 checks passou, incluindo
40 rotas com obstáculos/redirecionamento e eliminação dos arqueiros nas duas posições
da arena com uma seleção por alvo. Captura do jogo mostra seleção, golpe e dano.
Plano, retomada e contratos estão em `docs/PLAYTEST_M1_MOMENTUM.md` e ARCHITECTURE.
Preparação do candidato autorizada; master continua aguardando aceite do usuário.

Integração concluída: rebase sem mudanças e fast-forward de `codex/playtest` para
`8562610`; 158 checks, importação e smoke repetidos com sucesso no checkout real.
Master permanece `41ff198`; project.godot e addons locais do usuário preservados.
