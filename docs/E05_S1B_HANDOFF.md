# E05-S1B — transação de escolher/trocar evolução

Estado: **implementado; aguarda gate de Astra antes de UI ou conteúdo**.

Base: `1a3717b7282c00b7ccac3334c26de70cdf8d44de` na branch
`codex/e05-evolutions`. Autoridade: [gate E05-S1A](REVIEW_E05_S1A_ASTRA.md)
e [contrato auditado em S0](E05_S0_HANDOFF.md).

## Resultado

A fachada agora expõe a única mutação pública de identidade:

```gdscript
facade.change_evolution(request_id, expected_revision, character_id, evolution_id)
```

A operação usa a mesma fronteira transacional das ações de progressão:

- abre/valida contexto, `request_id` e revisão antes de criar a candidata;
- recusa personagem ausente, run ativa, origem incompatível, 10/20 não
  atingido e conteúdo indisponível;
- publica identidade, ranks e presets somente depois do commit único do
  `ProfileStore`;
- resolve resultado incerto por releitura durável e impede repetição com a
  revisão antiga;
- reconhece o destino já atual como `already_applied`, sem gravar nem conceder
  novamente seu rank gratuito.

Destino conhecido, porém sem kit pronto, retorna `content_unavailable`.
Destino desconhecido ou de outra origem conserva `invalid_origin`; os demais
erros preservam `requirements_unmet`, `run_active`, `stale_revision` e
`save_failed`.

## Conservação e normalização

Na primeira escolha ou troca, `CharacterProgression.change_evolution`:

- preserva `base_class_id`, XP base/job, atributos, equipamentos, compras da
  carteira base e grants legados da base;
- remove somente compras cujo metadado pertence à carteira `evolution` e
  informa sua soma exata em `evolution_refund`;
- mantém a entrada gratuita derivada de `free_rank=1`; não escreve em
  `granted_skill_ranks`;
- recalcula ranks efetivos após instalar a nova identidade;
- percorre os dois presets, esvaziando somente referências que perderam rank
  legal e conservando ordem, slots vazios, skills base e equipamentos.

A resposta de sucesso inclui `evolution_id`, `evolution_refund`, `progression`
e `cleared_slots_by_preset`. Cada item deste último contém `preset_index`,
`active_slot_indices` e `passive_slot_indices`, inclusive arrays vazios, para a
futura UI relatar exatamente o que a transação normalizou sem duplicar regras.

## Gate de run e mudança de contrato

`ProfileCatalog.build_is_ready(character)` deixou de significar apenas
“origem base cadastrada” e passou a certificar a build inteira: se houver
`evolution_id`, sua definição deve pertencer à origem e declarar
`content_ready=true`. A checagem fica no proprietário do catálogo e evita que
outros consumidores recriem a regra.

`ProfileFacade.start_run` usa essa autoridade e devolve
`content_unavailable` especificamente para uma identidade persistida cujo kit
não está pronto. O perfil continua carregável, consultável e intacto; somente a
criação da run é recusada. Essa alteração fecha a inconsistência registrada em
S0, na qual uma evolução incompleta podia jogar silenciosamente como a base.

Não houve mudança de schema, ruleset, catalog version ou codec. As 12
identidades de produção continuam `content_ready=false`.

## Testes

`tests/e05_evolution_transaction_test.gd` cobre 50 invariantes:

- primeira escolha exatamente em base 10/job 20, reload e `already_applied`;
- rank gratuito único no perfil, progressão e snapshot de run pronta;
- troca Defendente→Berserker em fixture, reembolso exato, conservação de base,
  atributos, XP e equipamentos;
- limpeza seletiva e relatório dos dois presets;
- limiares base e job independentes, origem errada, ID desconhecido, destino
  incompleto, run ativa e revisão obsoleta sem qualquer escrita;
- falhas nas etapas `write_pending`, `validate_pending`, `backup` e `replace`,
  com estado anterior durável e candidata pendente limpa;
- resultado incerto confirmado por releitura e retry literal sem aplicação
  dupla;
- identidade de produção incompleta carregável, mas impedida de iniciar run.

Validação final em Godot 4.7.2 standard:

```powershell
pwsh -NoProfile -File .\tools\verify.ps1 `
  -GodotPath 'C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.tools\review-engine\Godot.exe'
```

Resultado: importação, **67 suítes / 3.076 checks** e smoke aprovados. A nova
suíte passou com **50 checks**; `persistent_state` (33), `profile_store` (90),
`e03_progression_transactions` (47) e `e05_evolution_catalog` (56) passaram na
mesma execução integral.

## Limites e próximo gate

- Nenhuma identidade de produção foi habilitada e nenhum kit foi criado.
- Não houve UI, texto de confirmação, ator, controller, VFX ou mudança de
  gameplay.
- O par Defendente/Berserker existe apenas como fixture isolada para provar o
  contrato; não é conteúdo jogável do catálogo de produção.
- Não houve atualização de `codex/playtest` ou `master`.

Parar para revisão de Astra. S1C, dados e subépicos de conteúdo não estão
autorizados por esta entrega.
