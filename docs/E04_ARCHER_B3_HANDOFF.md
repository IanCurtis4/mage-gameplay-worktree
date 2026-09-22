# E04-AR-B3 — handoff da Flecha Perfurante

Base: `f3a3f08`. Escopo: somente `piercing_arrow` e política perfurante.

## Entrega

- `ClassCatalog` materializa R1–R5 com dano/custo crescentes e até três impactos
  fixos; `ProfileCatalog` conhece a segunda ativa sem liberar a classe.
- `PlayerProjectile` percorre impactos em ordem geométrica no mesmo frame, não
  repete ator e respeita parede, alcance e limite explícito.
- `PlayerActor`, controller, handler, HUD e preview direcional compartilham a mesma
  definição; auto, Disparo Duplo e Mago continuam com um impacto por projétil.

## Evidência e limite

`tests/e04_archer_piercing_arrow_rank_integration_test.gd` cobre tabela, R1/R5,
snapshot, dano, custo, recarga, rank inválido, limite, ordem, não repetição,
parede, HUD, preview, dispatch e regressão de um impacto. Resultado final de
import headless e `tools/verify.ps1`: 35 suítes, 1.407 checks; a suíte nova
responde por 44 checks.

Próximo pacote: Chuva de Flechas, somente após liberação separada.
