# E03-B — Progressão e transações de build

Estado: **aceito tecnicamente por Astra em `690d092`; E03-C1 liberado separadamente**.

Base do pacote: `fa8f966`. Implementação inicial: `f217d9954c895dc3e24c7095a5b78e49de454088`.
Correções de catálogo solicitadas por Astra: `4c24ec44912b5232ad29e03492fc0faff9a66ce8`.
Este documento não libera E03-C1/C2, E04 ou E05.

## Resultado e propriedade

`CharacterState` continua guardando somente XP e investimentos persistentes.
Níveis, pontos concedidos e saldos são derivados das curvas de `ProgressionRules`;
nenhum saldo é salvo em duplicidade. `CharacterProgression` aplica as regras puras
a cópias candidatas, enquanto `ProfileFacade` e `ProfileStore` mantêm revisão,
commit durável, retry e recuperação de resultado incerto.

As três carteiras são independentes:

- atributos: 3 por base level ganho;
- skills base: 1 por job level de 2 a 20;
- skills de evolução: 1 por job level de 21 a 40.

Investimento de atributo respeita `initial + allocated <= 60`. Rank comprado custa
um ponto da carteira declarada; ranks gratuitos não entram no save nem no reembolso.
Respec de skills é completo, devolve cada carteira separadamente e remove de ambos
os presets somente referências que deixaram de ter rank efetivo.

## API pública para os próximos consumidores

Consultas de `ProfileFacade`, sem escrita:

```gdscript
facade.progression_summary(character_id)
facade.build_preview(character_id, modifier_sources)
```

`progression_summary` retorna níveis, elegibilidade/bloqueio de evolução, pontos
concedidos/gastos/livres nas três carteiras e ranks efetivos. `build_preview`
retorna um `BuildSnapshot` por valor e um `StatBreakdown` novo produzido pela
autoridade `StatCalculator`; erros de modificadores são propagados sem escrever.

Transações de menu, todas com `request_id`, `expected_revision` e personagem:

```gdscript
facade.allocate_attributes(request_id, revision, character_id, increments)
facade.learn_skill(request_id, revision, character_id, skill_id)
facade.respec_attributes(request_id, revision, character_id)
facade.respec_skills(request_id, revision, character_id)
```

Elas falham durante uma run e publicam estado somente depois do commit em disco.
Retry de falha definida usa a mesma revisão; sucesso já confirmado torna a revisão
anterior obsoleta. Respec sem investimento é `already_applied` e não cria revisão.

`BuildSnapshot.stat_breakdown(...)` e `try_stat_breakdown(...)` recalculam pela
mesma autoridade. Cada chamada devolve uma instância isolada. `StatBreakdown`
permanece mutável por convenção: consumidores usam `values`, `primary_detail`,
`derived_detail` e `sources`, que retornam cópias, e não escrevem nos dicionários.

## Requisitos de rank e catálogo

`ProfileCatalog.add_skill` aceita `rank_requirements` indexado pelo rank efetivo:

```gdscript
{
    1: {
        "job_level": 5,
        "skill_ranks": {&"slash": 3},
    },
}
```

Chaves de rank aceitam inteiro ou string decimal canônica. Declarar os dois aliases,
rank fora de `1..max_rank`, chave desconhecida ou campo desconhecido invalida a
construção; nada é descartado silenciosamente antes da validação. Ausência legítima
usa defaults: job 1 para carteira base, job 20 para evolução e pré-requisitos vazios.
Campos conhecidos omitidos em um rank declarado usam os mesmos defaults.

O catálogo também rejeita IDs duplicados, ciclos, dependência ausente, rank de
pré-requisito impossível, base dependente de evolução e dependência entre evoluções
incompatíveis. Após `seal`, tentativas de escrita retornam `false` sem alterar
conteúdo ou validade. Resources e cópias de metadata continuam somente de leitura.

O codec revalida ranks, requisitos, carteiras e caps ao carregar; perfil que tenta
contornar a transação não é certificado.

## Erros de controle

Além dos erros existentes do store (`stale_revision`, `save_failed`,
`save_in_progress`, `result_uncertain`), as operações usam:

- `invalid_character_id`, `run_active`;
- `invalid_attribute_allocations`, `attribute_cap_reached`, `insufficient_points`;
- `invalid_skill_id`, `requirements_unmet`, `rank_cap_reached`;
- erros estruturados de `StatCalculator` no preview.

Textos pt-BR pertencem à UI futura; esses IDs permanecem chaves técnicas.

## Evidências

Godot 4.7.2 standard, verificação completa no commit de correção:

```powershell
./tools/verify.ps1 -GodotPath `
  'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe'
```

Resultado: importação, 18 suítes e smoke PASS; 923 checks, sendo 42 da suíte
`E03 progressão/transações` e 275 da matriz de stats. O verificador do contrato
E00 passou 4.630 checks. O probe isolado da revisão passou a reportar catálogo
selado ainda válido e catálogo malformado inválido.

## Limites preservados

- Não há operação de selecionar/trocar evolução; E03-B apenas calcula elegibilidade
  e valida estado já evoluído. Evolução efetiva permanece E05.
- Não há tabelas de poder/custo/efeito por rank nem conteúdo final das árvores;
  esses dados pertencem a E04/E05.
- Consumidores do piloto (`RpgStats`, ator, combate, HUD e menu) não foram migrados;
  igualdade preview/runtime é E03-C1 e UI é E03-C2.
- Nenhum schema novo, push, merge ou atualização de `codex/playtest`/`master` foi feito.
