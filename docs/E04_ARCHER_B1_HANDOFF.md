# E04-AR-B1 — handoff do autoataque de precisão

Base: `2f3936d`. Escopo: projétil compartilhado, classe mínima e auto do Arqueiro.

## Entrega

- `PlayerProjectile` centraliza colisão contínua, geometria, expiração e limite de
  impactos; `MageProjectile` preserva efeitos e visual específicos por herança.
- O auto do Arqueiro captura `precision_attack` como dano físico, direção, HIT,
  crítico e cadência; `melee_attack` não participa.
- `ClassCatalog` conhece o Arqueiro sem skills. Perfil/menu continuam indisponíveis
  até o gate de duas ativas e uma passiva funcionais.

## Evidência e limite

`tests/e04_archer_precision_projectile_test.gd` cobre catálogo mínimo, indisponibilidade
do perfil, emissão, snapshot de dano, direção fixa, primeiro impacto, obstáculo,
esquiva, alcance, pausa, wiring do controller e regressão da especialização do
Mago. Import headless e `tools/verify.ps1` passaram: 33 suítes, 1.326 checks; a
suíte nova responde por 17 checks.

Próximo pacote: E04-AR-B2, Disparo Duplo, somente após liberação separada.
