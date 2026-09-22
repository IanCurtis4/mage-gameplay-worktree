# E04-AR-B8 — handoff da Armadilha Explosiva

Base: `55a3f79`. Escopo: `explosive_trap` R1–R5 e explosão física em área.

## Entrega

- `ClassCatalog` e `ProfileCatalog` publicam dano/custo por rank sem ampliar os
  cinco slots; a classe permanece bloqueada pela ausência de passiva.
- `ExplosiveTrap` especializa o runtime existente, captura o request no commit,
  escolhe o gatilho deterministicamente e emite impactos independentes em área.
- Player, controlador, preview, HUD e pipeline de dano compartilham colocação,
  geometria, defesa física e crítico canônicos.
- O seletor de gatilho comum foi movido para `PlayerTrap` e continua atendendo o
  Laço sem alterar seu comportamento.

## Evidência e limite

`tests/e04_archer_explosive_trap_rank_integration_test.gd` cobre tabela R1/R5,
snapshot, custo, recarga, rank inválido, posição bloqueada, Mira Estendida,
armação, contato, borda da área, mortos, ordem, cópias por alvo, ausência de
controle, substituição/limpeza sem detonação, cinco slots, preview, HUD e dano
integrado. Resultado final de import headless e `tools/verify.ps1`: 40 suítes,
1.669 checks; a suíte nova responde por 56 checks.

Flecha Entorpecente, ocultação e passivas permanecem ausentes. Próximo pacote:
Flecha Entorpecente, somente após liberação separada.
