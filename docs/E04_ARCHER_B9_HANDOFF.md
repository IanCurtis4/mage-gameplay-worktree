# E04-AR-B9 — handoff da Flecha Entorpecente

Base: `64a16c2`. Escopo: `slowing_arrow` R1–R5 e slow por projétil direcional.

## Entrega

- `ClassCatalog` e `ProfileCatalog` publicam duração/custo por rank sem ampliar
  os cinco slots; a classe permanece bloqueada pela ausência de passiva.
- Player e controlador capturam dano físico de precisão, direção, intensidade e
  duração no commit e reutilizam o projétil compartilhado de um impacto.
- O slow de 35% exige dano positivo, preserva a duração R1–R5 e respeita o teto
  global de 50%, pausa, expiração e limpeza na morte.
- Mira Estendida, preview, HUD e os cinco atalhos consomem o mesmo alcance efetivo.

## Evidência e limite

`tests/e04_archer_slowing_arrow_rank_integration_test.gd` cobre tabela R1/R5,
snapshot, custo, recarga, rank inválido, Mira Estendida, emissão, dano, modo
contestado,
slow, teto global, pausa, expiração, morte, cinco slots, preview e HUD.
Resultado final de import headless e `tools/verify.ps1`: 41 suítes, 1.723 checks;
a suíte nova responde por 54 checks.

Ocultação, Abrigo de Folhagem e passivas permanecem ausentes. Próximo pacote:
Abrigo de Folhagem, somente após liberação separada.
