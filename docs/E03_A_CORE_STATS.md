# E03-A — Core Stats API

Estado deste pacote: **implementado, aguardando verificação local**.

Base de implementação planejada: E02 aceito / `codex/playtest`.

## Escopo

Este pacote cria a autoridade matemática prevista em `E00_02_STATS_CONTRACT.md`.
Ele **não migra ainda** `PlayerActor`, menu, HUD, `HealthState` ou o pipeline de dano.
Essa migração é E03-C1 e deve consumir esta API sem duplicar fórmulas.

Arquivos novos:

- `scripts/core/stat_breakdown.gd`
- `scripts/core/stat_calculator.gd`
- `tests/e03_stat_calculator_test.gd`

`tools/verify.ps1` passa a executar o teste E03-A.

## API pública congelada para consumidores

### `StatCalculator.calculate(...)`

```gdscript
var breakdown := StatCalculator.calculate(
    initial_attributes,
    attribute_allocations,
    base_level,
    modifier_sources
)
```

Retorna `StatBreakdown` ou `null` se a entrada for inválida.

Para entradas que podem ser inválidas, usar:

```gdscript
var result := StatCalculator.try_calculate(...)
if result["ok"]:
    var breakdown: StatBreakdown = result["breakdown"]
else:
    var error_code: StringName = result["error_code"]
```

### Modificadores

A entrada é uma lista de fontes identificadas:

```gdscript
[
    {
        "source_id": &"equipment:training_sword",
        "label": "Espada de treino", # opcional
        "primary_flat": {&"str": 2.0},
        "flat": {&"max_hp": 20.0},
        "increased": {&"melee_attack": 0.15},
    }
]
```

Regras:

- `primary_flat` aceita somente `str/agi/vit/int/dex/luk`;
- primários não aceitam porcentagem;
- `flat` e `increased` usam IDs derivados canônicos;
- percentuais de fontes somam antes de uma única multiplicação;
- `attack_speed_index` não aceita modificador direto: ele é `100 * attacks_per_second`
  **já efetivo**;
- IDs desconhecidos, valores não finitos e buckets inválidos falham explicitamente.

### `StatBreakdown`

```gdscript
breakdown.value(&"max_hp")
breakdown.primary_value(&"dex")
breakdown.values()
breakdown.primary_detail(&"dex")
breakdown.derived_detail(&"max_hp")
breakdown.sources()
```

Detalhe primário:

```text
initial / allocated / flat / effective / minimum / maximum
```

Detalhe derivado:

```text
raw / flat / increased / effective / minimum / maximum
```

Isso permite que menu/tooltips mostrem parcelas sem reproduzir matemática.

## IDs derivados canônicos

- `max_hp`, `max_sp`
- `hp_regen`, `sp_regen`
- `melee_attack`, `precision_attack`, `magic_attack`
- `physical_defense`, `magic_defense`
- `hit_rating`, `flee_rating`
- `crit_chance`, `crit_multiplier`, `crit_resistance`
- `attacks_per_second`, `attack_speed_index`
- `move_speed`
- `variable_cast_multiplier`, `fixed_cast_reduction`
- `after_cast_reduction`, `cooldown_reduction`
- `physical_cc_resistance`, `magic_cc_resistance`
- `damage_dealt_multiplier`

`damage_dealt_multiplier` é incluído porque o contrato E00 o define como o
multiplicador ofensivo contextual único, raw 1 e limitado a 0–4. O pipeline de dano
ainda não o consome neste pacote.

## Helpers compartilhados

A mesma autoridade também expõe:

```gdscript
StatCalculator.contested_hit_chance(hit, flee)
StatCalculator.effective_crit_chance(crit, resistance)
StatCalculator.effective_cast_time(fixed_s, variable_s, breakdown)
StatCalculator.effective_after_cast(base_s, breakdown)
StatCalculator.effective_cooldown(base_s, breakdown)
```

Assim E03-C1 não deve reconstruir essas fórmulas no ator ou UI.

## Compatibilidade temporária

`RpgStats` permanece intacto por enquanto. E03-A apenas cria a nova autoridade.
E03-C1 fará a migração explícita dos consumidores e decidirá a remoção/adapter do
legado depois que igualdade de menu/snapshot/runtime estiver coberta por testes.

Isso evita mudar gameplay enquanto a API matemática ainda está sendo certificada.

## Gate para liberar E03-L1 / E03-C1 / E03-B

Executar no checkout que contém este pacote:

```powershell
pwsh -NoProfile -File .\tools\verify.ps1 `
  -GodotPath '.\.tools\review-engine\Godot.exe'
```

ou o PowerShell compatível já validado localmente.

Além da suíte inteira, deve aparecer:

```text
E03 StatCalculator: PASS (39 checks)
```

Somente depois desse PASS marcar E03-A como DONE e liberar consumidores.
