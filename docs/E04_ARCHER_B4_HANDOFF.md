# E04-AR-B4 — handoff da Chuva de Flechas

Base: `591ac3a`. Escopo: somente `arrow_rain` e área anunciada.

## Entrega

- `ClassCatalog` materializa R1–R5 com dano/custo crescentes e geometria fixa;
  `ProfileCatalog` conhece a terceira ativa sem liberar a classe.
- `ArrowRain` anuncia o centro por 0,45 s, amostra movimento em três saraivadas
  fixas e entrega requests físicos independentes ao pipeline canônico.
- `PlayerActor`, controller, handler, HUD e preview de ponto compartilham alcance
  limitado a 480; pausa e limpeza usam o ciclo normal de `player_effects`.

## Evidência e limite

`tests/e04_archer_arrow_rain_rank_integration_test.gd` cobre tabela, R1/R5,
snapshot, dano, custo, recarga, rank inválido, clamp, aviso, movimento entre
saraivadas, pausa, HUD, preview, dispatch e limpeza. Resultado final de
import headless e `tools/verify.ps1`: 36 suítes, 1.455 checks; a suíte nova
responde por 48 checks.

Próximo pacote: Mira Estendida, somente após liberação separada.
