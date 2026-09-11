# Revisão técnica e playtest — Marco 1

## Identificação

- Implementador: Sol, tarefa `01a08e8a-bbc3-7391-9e4f-a84cc18e4e3a`.
- Branch da tarefa: `codex/m1-arena-combat`.
- Entrega inicial: `dd8a4a0`, sobre a fundação `41ff198`.
- Base do fluxo fixo de playtest: `26e0263` em `codex/playtest`.
- Candidato corrigido aprovado por Astra: `218387b`.
- Candidato de gameplay após rebase: `97cbde6`, disponível em `codex/playtest`.
- Backup anterior ao rebase: `codex/backup-m1-before-playtest-rebase` → `218387b`.
- Status: aprovação técnica concluída; aguardando playtest e aceite do usuário.

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
