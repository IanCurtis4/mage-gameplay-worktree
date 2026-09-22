# E04-AR-B6 — handoff do runtime de armadilhas

Base: `e93f99d`. Escopo: infraestrutura compartilhada, sem publicar armadilha,
rank, dano ou controle de movimento.

## Entrega

- `PlayerTrap` modela armação, permanência e estados terminais idempotentes,
  com pausa e teste espacial contra ator vivo.
- `PlayerTrapRegistry` aplica limite FIFO de três armadilhas por dono entre
  todos os tipos e distingue disparo, timeout, substituição e limpeza.
- `RunController` cria o registro e limpa suas instâncias no fim do encontro,
  morte e encerramento da run, sem ativar efeitos.

## Evidência e limite

`tests/e04_archer_trap_runtime_test.gd` cobre os quatro estados, frame grande,
pausa, alvo e colisão, idempotência, limite compartilhado por dono, FIFO,
grupos e limpeza integrada. O pacote não adiciona `snare_trap` nem
`explosive_trap` ao catálogo. Resultado final de import headless e
`tools/verify.ps1`: 38 suítes, 1.544 checks; a suíte nova responde por 40
checks.

Próximo pacote: Armadilha de Laço, somente após liberação separada.
