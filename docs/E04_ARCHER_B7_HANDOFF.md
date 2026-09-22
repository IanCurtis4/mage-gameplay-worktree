# E04-AR-B7 — handoff da Armadilha de Laço

Base: `b8b195c`. Escopo: `snare_trap` R1–R5 e root físico compartilhado.

## Entrega

- `ClassCatalog` e `ProfileCatalog` publicam a quinta ativa do Arqueiro com
  duração por rank; a classe continua bloqueada por não possuir passiva.
- `SnareTrap` especializa o runtime existente com armação, permanência,
  seleção determinística, acionamento sem dano e root capturado no lançamento.
- `HardControlState` centraliza resistência, renovação, pausa, `Unstoppable`,
  teto normal e orçamento compartilhado de boss.
- Player, inimigos, preview, input D, HUD e controlador consomem os mesmos
  contratos de colocação e controle.

## Evidência e limite

`tests/e04_archer_snare_trap_rank_integration_test.gd` cobre tabela R1/R5,
gasto e recarga, posição bloqueada, Mira Estendida, resistência, renovação,
pausa, morte, `Unstoppable`, boss, escolha de alvo, colisão, ausência de dano,
preview, HUD e integração com o registro. Resultado final de import headless e
`tools/verify.ps1`: 39 suítes, 1.613 checks; a suíte nova responde por 69
checks.

Armadilha Explosiva e a passiva do Arqueiro permanecem ausentes. Próximo pacote:
Armadilha Explosiva, somente após liberação separada.
