# E05-S1A — catálogo e consulta de evoluções

Estado: **implementado; aguarda gate de Astra antes de S1B**.

Base: `b0900116f92ae1c7b1d1e2b247eed476e1e23973` na branch
`codex/e05-evolutions`. Autoridade: [gate E05-S0](REVIEW_E05_S0_ASTRA.md).

## Resultado

`EvolutionDefinition` é o Resource imutável por convenção de uma identidade
persistente. Ele carrega ID, nome pt-BR, origem, ramo `2-1`/`2-2`/`2-3`, afinidade,
requisitos 10/20, biblioteca exclusiva, ativa gratuita de entrada e a asserção
explícita `content_ready`.

`ProfileCatalog` é o único proprietário dessas definições:

- registra as seis puras e seis híbridas E00 em ordem determinística;
- deriva e valida `origin_class_id` pelo mapa de `IdentityIds`, sem outro mapa de
  origem;
- valida ramo, afinidade, duplicatas, referências de skills, wallet, origem da
  skill e a única ativa gratuita R1/job 20;
- permite referências vazias somente enquanto `content_ready=false`;
- exige a asserção de prontidão além de uma biblioteca coerente: cadastrar uma
  skill isolada não habilita o destino;
- guarda cópias profundas e devolve novas cópias em consultas e em
  `copy_catalog()`.

As 12 definições de produção permanecem `content_ready=false`, sem skill de
entrada ou biblioteca exclusiva. O terceiro argumento opcional de
`ProfileCatalog.pilot` permite somente que fixtures isoladas forneçam essas
referências e simulem prontidão; IDs desconhecidos ou campos inválidos tornam o
catálogo inválido.

## API de leitura

```gdscript
facade.evolution_options(character_id)
```

A consulta exige que a fachada tenha sido aberta explicitamente. Se o estado
ainda não existe, retorna `profile_unavailable`; ela não abre, recupera ou grava
um perfil como efeito colateral.

Resultado superior: `character_id`, `base_class_id`, `current_evolution_id`,
base/job level, estado de run/read-only, revisão observada e `options`.

Cada opção é um dicionário isolado com:

- `evolution_id`, `display_name`, `origin_class_id`, `branch_kind` e
  `affinity_class_id`;
- requisitos, `entry_skill_id` e cópia de `exclusive_skill_ids`;
- flags independentes `is_current`, `requirements_met` e `content_ready`;
- `can_select` e `blocking_reasons`, que podem acumular
  `requirements_unmet`, `content_unavailable`, `run_active`,
  `profile_read_only` e `already_current`.

Assim uma evolução atual mas incompleta continua reportando simultaneamente
`is_current=true` e `content_ready=false`; a identidade persistida não é apagada
nem mascarada.

## Arquivos

- `scripts/data/evolution_definition.gd`: valor de catálogo e cópia profunda;
- `scripts/core/profile_catalog.gd`: propriedade, elenco E00, validação e
  consultas por ID/origem;
- `scripts/core/profile_facade.gd`: projeção somente leitura por personagem;
- `tests/e05_evolution_catalog_test.gd`: 56 checks do contrato;
- `tools/verify.ps1`: registra a nova suíte.

## Evidências

Godot 4.7.2 standard:

```powershell
pwsh -NoProfile -File .\tools\verify.ps1 `
  -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\review-engine\Godot.exe'
```

Resultado final: importação, **66 suítes / 3.026 checks** e smoke aprovados.
A nova suíte passou com **56 checks**. Dentro da execução integral, as
regressões prescritas também passaram:

- `persistent_state`: 33 checks;
- `profile_store`: 90 checks;
- `e03_progression_transactions`: 47 checks.

Os testes usam somente `.godot/verification`. Nenhum save do jogador foi aberto.

## Limites e próximo gate

- Não existe escolha/troca de evolução; `change_evolution` permanece S1B.
- Não houve mudança em codec, schema, ruleset, catalog version, `start_run`, UI,
  ator, controller, skills ou tabelas de rank.
- Um perfil existente com evolução indisponível continua carregável e
  consultável. O bloqueio de `start_run` para esse destino é obrigação explícita
  de S1B, sem apagar identidade ou progresso.
- Defendente/Berserker continua sendo o primeiro par previsto, mas nenhum kit,
  tabela ou destino de produção foi habilitado por este pacote.
- Não houve atualização de `codex/playtest` ou `master`.

Parar para revisão de Astra. S1B não está iniciado.
