# E03-C1 — Migração dos consumidores de stats

Estado: **implementado; aguardando revisão técnica Astra**.

Base do pacote: `690d092`. Este handoff cobre somente E03-C1. Não libera a árvore
e o painel de progressão de E03-C2, kits/ranks de E04, evolução de E05 nem efeitos
de equipamento de E06.

## Resultado

Menu, preview, snapshot de run, atores, HUD e combate usam a autoridade única
`StatCalculator`/`StatBreakdown`. O antigo `RpgStats` e seus IDs paralelos foram
removidos. O vocabulário runtime agora usa HP/SP, ataques corpo/precisão/magia,
DEF/DEFM, HIT/FLEE, crítico e tempos canônicos do E00.

`BuildSnapshot.stat_breakdown(...)` incorpora os modificadores das passivas
equipadas e aceita fontes adicionais da run. `RunState.stat_modifier_sources()`
expõe augments como fontes identificadas. Assim, o mesmo snapshot gera os valores
do preview e do ator; nenhuma cena/UI reproduz fórmula.

O recálculo de um ator troca seu `StatBreakdown` e o recorte defensivo de
`HealthState`, preservando HP e SP faltantes. Cooldowns em andamento não são
reescritos. A UI exibe `SP`, custos em SP e lê os máximos do estado runtime.

## Contrato de combate migrado

`DamageRequest` captura componentes brutos `physical_damage`/`magic_damage`,
`damage_dealt_multiplier`, modo de acerto, HIT, chance e multiplicador crítico.
Não há mais `kind`, `base_damage` nem chance de acerto pré-calculada.

`CombatMath.resolve(...)`:

- usa `StatCalculator.contested_hit_chance` para `CONTESTED` e chance 1 para
  `GEOMETRY`;
- subtrai a resistência crítica atual do alvo;
- mitiga os componentes por DEF e DEFM separadamente;
- soma, aplica multiplicadores e arredonda uma única vez;
- mantém o bloqueio de recursão para dano secundário.

Autos e projéteis direcionados a alvo usam `CONTESTED`; cone, bola direcional,
área e DoT que já dependem de geometria usam `GEOMETRY`. O catálogo atual declara
`accuracy_mode` e `can_crit` por skill. Projéteis e DoTs capturam o poder ofensivo
na emissão, mas consultam as defesas atuais somente no impacto/tick.

## Validação

`tests/e03_consumer_integration_test.gd` acrescenta invariantes para:

- igualdade numérica preview → snapshot → ator runtime;
- valores de HP/SP do HUD iguais ao runtime;
- menu derivado do preview canônico;
- recálculo sem cura, sem recuperar SP e sem reiniciar cooldown;
- HIT/FLEE, resistência/multiplicador crítico, acerto geométrico e dano misto;
- aplicação única do resultado canônico por `HealthState`.

A suíte completa é executada por:

```powershell
./tools/verify.ps1 -GodotPath `
  'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe'
```

Resultado da entrega: **942 verificações headless aprovadas**, importação do editor
e smoke da cena principal em Godot 4.7.2. O verificador numérico independente do
E00 também permanece obrigatório no fechamento.

## Limites concretos

- E03-C1 não cria a UI de investimento/respec de E03-C2.
- Skills ainda usam o conteúdo piloto de poder/custo/tempo; tabelas por rank e
  pesos completos pertencem a E04.
- Não há efeitos de equipamento, evolução, penetração, escudo, guard ou pós-cast
  novos neste pacote.
- A migração altera a matemática do piloto para os valores canônicos do E00;
  balanceamento e sensação continuam dependentes de playtest futuro autorizado.
- Este pacote não atualiza `codex/playtest`/`master` e não faz push.
