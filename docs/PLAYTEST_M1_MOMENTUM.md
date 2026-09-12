# Rodada Astra: perseguição e peso do movimento

Pedido de 12/09/2026, base `065a2f3`. Implementação direta por Astra, conforme pedido
do usuário. Branch `codex/m1-momentum-pursuit`, worktree `.tools/momentum-worktree`.
O projeto habitual permanece em `codex/playtest` até a validação final.

## Passos e retomada

1. Concluído: reproduzir perseguição usando EnemyActor arqueiro real; corrigir
   aproximação e golpe, com breve recuperação após atacar e alcance/parede respeitados.
2. Concluído: aceleração, frenagem e mudança gradual de direção do jogador, com
   colisões seguras, chegada estável, pausa/morte/dash e perseguição preservados.
3. Revisão e testes concluídos, integração pendente: preparar candidato no diretório
   fixo e registrar resultados. Merge em master depende de novo aceite do usuário.

Cada etapa terá commit próprio para permitir retomada sem repetir trabalho.
Esta rodada conclui o retorno do M1; não inicia o M2.

## Diagnóstico inicial

A perseguição recalcula a cada 0,22 s um ponto a 4 unidades para dentro do alcance,
usando a posição antiga do alvo. O arqueiro percorre até 38,5 unidades nesse intervalo:
o jogador pode alcançar o ponto antigo, parar e repetir sem entrar no alcance real.
O teste anterior usava um alvo artificial a 60 unidades/s; o arqueiro real anda a 175.

O movimento atual aplica velocidade máxima imediatamente e muda a direção em um
frame. A nova rodada acrescentará velocidade runtime, aceleração e frenagem leves.

## Etapa 1 — perseguição

Reprodução em 30/60/144 Hz e duas ordens de atualização: zero autos em 10 s,
mantendo distância de 112–122 para alcance inicial de 87. O alvo artificial da
rodada anterior não detectava o problema. Agora a rota busca a posição real do alvo,
verifica contato antes e depois do movimento e para 0,14 s após emitir um auto.
A perseguição retoma mesmo com cooldown ativo se o inimigo sair do alcance.
Clique no chão cancela a perseguição e essa espera. Não houve aumento de alcance,
redução da velocidade do arqueiro, nem alteração das fórmulas de dano/precisão.

Teste real corrigido: 8–9 autos em 10 s, nas seis combinações de taxa/ordem.
Suíte anterior passou integralmente; nova suíte inclui essa regressão e recuperação.

## Etapa 2 — peso do movimento

Velocidade vetorial runtime, aceleração 1100 e atrito/frenagem 1600 unidades/s²;
integração em passos de até 1/120 s, curvas ao redirecionar, chegada com frenagem e
colisão segura. A velocidade máxima continua 220, derivada em RpgStats. Mudanças de
direção conservam impulso; morte e dash limpam movimento anterior; pausa congela.
O auto firma os pés, tem arco visual curto e continua respeitando alcance e precisão.

Regressões novas: partida gradual, giro, reversão, parada curta, chegada/cliques
pequenos, pausa, dash, morte, consistência em 30/60/144 Hz, 40 rotas com seed 914
incluindo redirecionamentos, e eliminação dos arqueiros nas posições reais da arena.
Com peso, o teste em corredor aberto ainda produziu 7–8 autos em 10 s nas seis
combinações de ordem/taxa. Mantida a IA e velocidade originais dos inimigos.

O teste antigo de clique de 5 unidades agora permite 0,5 s para a chegada; exigir
chegada em 0,1 s contrariava a nova aceleração. O destino exato continua obrigatório.

## Etapa 3 — revisão e entrega

Pontos de retomada: `253bdf2` (perseguição corrigida) e `1f47418` (peso do movimento).
Revisão do código feita por Astra, também implementador desta rodada a pedido do
usuário. Não foi solicitada revisão a outro agente nem iniciada nova tarefa.

`tools/verify.ps1`: 158 verificações aprovadas (12 fundação, 63 M1, 33 perseguição/
inércia, 32 fluxo, 18 layout), importação e smoke. Captura renderizada pelo Godot
em 1280×720 confirma arco do auto, seleção e dano aplicado ao arqueiro; arquivo
ignorado `.godot/verification/archer_auto_momentum.png` na worktree desta rodada.

Reteste: um clique no arqueiro deve aproximar e atacar sem cliques de antecipação;
o inimigo pode fugir durante a recuperação, mas a perseguição deve retomar. No chão,
experimentar uma curva de 90°, inversão de direção e chegada perto de obstáculos.
Os valores atuais são um ponto inicial para o peso desejado; não há aprovação da
sensação ou medição de FPS real por esses testes.
