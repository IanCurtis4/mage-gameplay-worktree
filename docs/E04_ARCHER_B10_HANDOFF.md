# E04-AR-B10 — handoff do Abrigo de Folhagem

Base: `e731278`. Escopo: `foliage_shelter` R1–R5 e ocultação por área.

## Entrega

- `ClassCatalog` e `ProfileCatalog` publicam duração/custo por rank sem ampliar
  os cinco slots; a classe permanece bloqueada pela ausência de passiva.
- `FoliageShelter` captura centro, raio e duração, congela em pausa e remove sua
  fonte de ocultação uma vez ao expirar, limpar ou perder o dono.
- Player e inimigos possuem estado explícito de ocultação, revelação, aquisição,
  perda e retorno do alvo; inimigo na mesma área continua elegível.
- Ação ofensiva revela por 1,25 s; buffs, falhas e dano recebido não revelam.
  Projéteis emitidos, dano, colisão e movimento permanecem independentes.
- Colocação, preview, HUD e os cinco atalhos consomem o mesmo alcance efetivo.

## Evidência e limite

`tests/e04_archer_foliage_shelter_rank_integration_test.gd` cobre tabela R1/R5,
snapshot, custo, recarga, rank inválido, posição bloqueada, Mira Estendida,
duração, pausa, expiração, morte, aquisição externa/interna, perda/retenção,
revelação ofensiva, buff/falha, projétil em voo, cinco slots, preview e HUD.
Resultado final de import headless e `tools/verify.ps1`: 42 suítes, 1.785 checks;
a suíte nova responde por 62 checks.

As três passivas e o fechamento integrado do Arqueiro permanecem ausentes.
Próximo pacote: Precisão, somente após liberação separada.
