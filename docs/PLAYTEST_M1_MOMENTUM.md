# Rodada Astra: perseguição e peso do movimento

Pedido de 12/09/2026, base `065a2f3`. Implementação direta por Astra, conforme pedido
do usuário. Branch `codex/m1-momentum-pursuit`, worktree `.tools/momentum-worktree`.
O projeto habitual permanece em `codex/playtest` até a validação final.

## Passos e retomada

1. Concluído: reproduzir perseguição usando EnemyActor arqueiro real; corrigir
   aproximação e golpe, com breve recuperação após atacar e alcance/parede respeitados.
2. Pendente: aceleração, frenagem e mudança gradual de direção do jogador, com
   colisões seguras, chegada estável, pausa/morte/dash e perseguição preservados.
3. Pendente: revisar, executar tools/verify.ps1, preparar candidato no diretório
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
