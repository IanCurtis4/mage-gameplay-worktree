# E05-S0 — auditoria e contrato de decomposição da evolução

Estado: **entrega documental; aguarda gate de contrato de Astra**.

Base auditada: `959745025695e7125e28a3a302a16dd11df6cbdf`, branch
`codex/e05-evolutions`. Autorização: [E05_START.md](E05_START.md). Este passo
não altera runtime, catálogo jogável, schema, save real, `master` ou
`codex/playtest`.

## Contrato preservado

- A origem em `base_class_id` é fixa. A evolução persistida é uma identidade
  separada; uma afinidade ou referência visual nunca reescreve a origem.
- A primeira escolha exige base level 10 e job level 20. Trocas posteriores
  ocorrem somente no menu, sem run ativa, e apenas entre destinos da mesma
  origem. Não se volta ao estado sem evolução no demo.
- O personagem conserva XP, job level, atributos, compras da base e
  equipamentos. A troca remove as compras da evolução anterior, restitui
  exatamente essa carteira, retira seus ranks gratuitos derivados e instala
  uma única vez o rank gratuito da nova identidade.
- Os dois presets são normalizados na mesma transação: somente referências
  ilegais são esvaziadas; não se escolhem substitutas e não se apaga o preset.
  Barra vazia continua válida.
- Evolução não combina duas árvores. A origem mantém sua biblioteca; cada
  destino acrescenta somente a biblioteca exclusiva curada e usa a carteira
  de evolução concedida entre job 21–40; a entrada gratuita ocorre no job 20.
- Catálogos permanecem imutáveis. Estado persistente pertence a
  `CharacterState`; snapshot e recursos intrínsecos da identidade pertencem
  à run. Testes usam diretório isolado, nunca `user://profile.json` real.
- Origem, afinidade e apresentação são três conceitos diferentes. Para as
  direcionais, `sp_mg`, `mg_sp`, `sp_ar`, `ar_sp`, `mg_ar` e `ar_mg` não são
  intercambiáveis; em particular, Geômetra continua `mg_ar`.

Autoridades: [ADR E00.1](ADR_E00_01_CHARACTER_PROGRESSION.md),
[E00.3](E00_03_DATA_SAVE_CONTRACT.md),
[elenco E00](E00_MVP_CLASS_CONTRACT.md),
[E03-B](E03_B_PROGRESSION.md) e
[E04 — aprendizado](E04_LEARNING_AND_ARCHER.md).

## Mapa EXISTENTE

| Fronteira | Implementação existente e reutilizável |
|---|---|
| IDs e origem | `scripts/core/identity_ids.gd` registra as seis puras, as seis híbridas direcionais e `evolution_origin`/`evolution_belongs_to`. |
| Estado persistente | `scripts/core/character_state.gd` já possui `base_class_id` e `evolution_id`; `copy_state` isola a cópia candidata. |
| Formato e validação | `scripts/core/profile_codec.gd` codifica `evolution_id`, rejeita origem incompatível, exige 10/20 e valida ranks e presets contra o ramo ativo. O schema 2 já reserva o campo. |
| Requisitos e carteiras | `scripts/core/progression_rules.gd` contém limiares 10/20, cap job 20 sem evolução e carteira 21–40. `scripts/core/character_progression.gd` deriva elegibilidade e saldos sem persistir pontos duplicados. |
| Skills exclusivas | `scripts/core/profile_catalog.gd` já aceita wallet `evolution`, `required_evolution_id`, rank gratuito, requisitos por rank, dependências acíclicas e filtro por origem/ramo. As entradas atuais de produção são apenas das bases. |
| Fachada e commit | `scripts/core/profile_facade.gd` já fornece revisão esperada, `request_id`, bloqueio durante run, cópia candidata e publicação somente depois do commit de `ProfileStore`. A mesma moldura serve para a futura troca. |
| Persistência robusta | `scripts/core/profile_store.gd` é o escritor único e já cobre pending, backup, substituição, falha definida e resultado incerto. Não criar outro writer. |
| Presets | `CharacterState` já mantém dois presets de 5 ativas/2 passivas. `CharacterProgression._prune_slots` demonstra a regra de retirar slots cujo rank deixou de existir, hoje usada pelo respec completo. |
| Snapshot | `scripts/core/build_snapshot.gd` copia `base_class_id`, `evolution_id`, ranks e slots por valor. `scripts/core/run_state.gd` rejeita troca de classe em run persistente. |
| Consulta de progressão | `ProfileFacade.progression_summary`, `progression_skill_options` e `build_preview` já entregam níveis, carteiras, ramos indisponíveis, ranks e snapshot sem a UI recalcular regras. |
| Menu | `scripts/ui/character_menu.gd` já separa personagem em foco da seleção persistida, desabilita mutações em run/readonly e conserva `request_id` para retry de falha definida. |
| Gameplay das bases | `scripts/data/class_catalog.gd`, `scripts/actors/player_actor.gd` e os fechamentos E04 fornecem as primitivas das três origens. Elas são fundamentos; não constituem kits de evolução. |
| Testes precursores | `tests/persistent_state_test.gd`, `tests/profile_store_test.gd` e `tests/e03_progression_transactions_test.gd` já cobrem origem direcional, limiar 10/20, skill gratuita de ramo, carteiras separadas, respec e reload usando catálogo de fixture. |

## Mapa FALTANTE e incompatibilidades concretas

1. **Não existe `EvolutionDefinition` nem catálogo autoritativo de destinos.**
   `IdentityIds` conhece IDs e origem, mas não representa `branch_kind`,
   `affinity_class_id`, nome, requisitos, skill de entrada, intrínseca, estado
   selecionável ou prontidão do kit.
2. **O codec conhece mais que o catálogo jogável.** Um perfil no limiar pode
   persistir qualquer evolução reconhecida por `IdentityIds` mesmo sem definição
   de produção ou biblioteca exclusiva. Isso não deve virar o mecanismo de
   desbloqueio.
3. **Não existe operação `change_evolution`.** Os testes atuais só conseguem
   exercitar um personagem evoluído alterando a fixture antes de salvar. Nenhum
   caminho público valida destino, reembolsa o ramo anterior, normaliza ambos os
   presets e faz commit atômico.
4. **O respec existente é amplo demais para a troca.**
   `CharacterProgression.respec_skills` apaga compras das duas carteiras. A troca
   precisa retirar somente compras com wallet `evolution`, preservando integralmente
   as compras da base e suas referências legais.
5. **`start_run` não certifica um destino pronto.**
   `ProfileCatalog.build_is_ready` verifica apenas que a origem tem skills base;
   `RunState.class_id` continua sendo a base. Um `evolution_id` sem kit pode,
   portanto, iniciar uma run que joga somente como a base.
6. **Snapshot transporta identidade, mas o runtime ainda não a consome.** Não
   há `IdentityRuntime`, intrínseca de evolução, dispatch ou apresentação por
   destino. Isso pertence aos subépicos de conteúdo, não ao seletor inicial.
7. **O menu somente informa elegibilidade.** Não há consulta de opções,
   nome de evolução atual, confirmação, aviso de slots removidos ou tratamento
   específico dos erros da troca. O roster e o resumo exibem apenas a base.
8. **Não há separação visual em dados.** `PlayerActor` escolhe animação/cor
   por `base_class_id`. A futura aparência não pode trocar a origem para imitar
   a receita visual; deve consumir metadado separado aprovado em E08.
9. **Não há dados de produção das evoluções.** Nenhuma pura possui biblioteca
   exclusiva contratada e nenhuma das seis híbridas possui suas skills registradas
   no `ProfileCatalog`/`ClassCatalog`. As descrições E00 são identidade e limites,
   não tabelas finais de rank.

## Decisões fechadas para a futura API

- Consulta e mutação pertencem à fachada. Desenhar a UI nunca altera perfil.
- A lista de opções deriva do catálogo pelo `base_class_id`; a UI não interpreta
  prefixos como `sp_` nem reconstrói requisitos.
- Definição selecionável precisa ter origem válida, requisitos 10/20, biblioteca
  exclusiva coerente e exatamente uma ativa de entrada gratuita em job 20.
- Primeira escolha e troca usam uma única operação transacional com
  `request_id`, `expected_revision`, `character_id` e `evolution_id`. Falha não
  publica identidade, ranks ou presets parciais.
- O rank gratuito deve continuar derivado do catálogo ativo (`free_rank=1`),
  não ser copiado para `granted_skill_ranks`. Esse mapa permanece reservado a
  direitos legados, evitando concessão duplicada em reload ou troca repetida.
- A resposta de sucesso informa pelo menos destino atual, revisão nova, pontos
  de evolução restituídos e slots esvaziados por preset. `already_applied` não
  grava nem reinstala ranks.
- `invalid_origin`, `requirements_unmet`, `run_active`, `stale_revision`,
  `save_failed` e `invalid_catalog` conservam a semântica existente. Um destino
  conhecido mas ainda não selecionável deve falhar por estado de catálogo, sem
  ser apresentado como escolha jogável.

## Decisões realmente abertas para Astra

1. **Forma do catálogo:** adicionar `EvolutionDefinition` ao `ProfileCatalog` ou
   criar um catálogo imutável adjacente compartilhado pela fachada e pelo runtime.
   A fonte deve ser única; duplicar origem/afinidade em dois catálogos não é
   aceitável.
2. **Representação de prontidão:** recomenda-se registrar as 12 identidades
   aceitas como metadado, mas somente tornar um destino selecionável quando sua
   skill gratuita e o contrato mínimo do kit existirem. Isso evita expor uma
   evolução que inicia a run como base pura.
3. **Versionamento:** infraestrutura e consultas sem novos IDs persistidos não
   exigem mudar schema/ruleset. O primeiro destino de produção deve decidir e
   testar o incremento de `catalog_version`/migração; não antecipar uma migração
   especulativa neste passo.
4. **Primeiro par de conteúdo:** S0 não escolhe Defendente/Berserker,
   Elementalista/Espiritualista, Sentinela/Caçador nem um par híbrido. Astra deve
   aprovar a identidade e a ordem antes de qualquer tabela ou runtime desse par.

## Casos de aceite obrigatórios

### Catálogo e consulta

- As 12 identidades mantêm ID, nome, origem, tipo puro/híbrido e afinidade
  conforme E00; uma cópia retornada não muta o catálogo.
- Um Espadachim nunca recebe `mg_sp`, `ar_sp`, `mg_ar` ou `ar_mg` como opção
  legal. ID desconhecido, origem igual à afinidade, duplicata e skill de entrada
  ausente/pertencente a outro ramo invalidam o catálogo.
- A consulta distingue bloqueada por nível, indisponível por conteúdo, atual e
  selecionável sem escrever no perfil.

### Transação e persistência

- No limite exato base 10/job 20, escolher destino da mesma origem persiste e
  reaparece após reabrir; base/job XP, atributos, compras base e equipamentos
  permanecem idênticos.
- A entrada gratuita aparece uma vez no rank efetivo, não debita carteira e não
  se acumula em retry, reload ou `already_applied`.
- Abaixo de 10/20, destino errado/desconhecido/incompleto, run ativa e revisão
  obsoleta falham sem alterar qualquer campo.
- Ao trocar de ramo em job acima de 20, todas e somente as compras da carteira de
  evolução anterior são removidas; o saldo derivado retorna exatamente. Compras
  e ranks legados da base permanecem.
- Ambos os presets perdem somente skills ilegais do ramo anterior, conservando
  ordem, slots vazios, skills base e equipamentos. O snapshot de uma run já
  iniciada nunca muda, pois a troca durante run é rejeitada.
- Falha em cada etapa do store conserva o estado anterior. Resultado incerto é
  resolvido por releitura; repetir o mesmo pedido nunca alterna duas vezes nem
  duplica restituição.

### UI e integração

- O menu mostra origem, evolução atual, requisitos e somente opções vindas da
  API; desenhar/atualizar a tela não dispara transação.
- Confirmação informa que slots exclusivos podem ser esvaziados e, após sucesso,
  mostra os slots efetivamente normalizados. Falha de save conserva a mesma
  intenção/revisão para retry, como as ações de progressão atuais.
- Um destino incompleto não pode iniciar run. Quando um subépico de conteúdo o
  tornar jogável, preview, snapshot, HUD e runtime devem concordar sobre identidade,
  ranks e stats sem usar a afinidade como nova origem.

## Decomposição proposta

1. **E05-S1A — catálogo e consulta de evoluções (Sol, risco alto, próximo
   pacote proposto).** Um `EvolutionDefinition` imutável e uma consulta
   `evolution_options(character_id)` retornam metadado e estado autoritativos.
   Nenhuma transação, UI, skill ou destino é habilitado. Fixtures de teste
   exercitam um destino selecionável sem alterar o catálogo de produção.
2. **E05-S1B — transação de escolher/trocar (Sol, risco alto).** Implementa
   mutação candidata, reembolso apenas da carteira de evolução, normalização
   de presets, commit/retry/reload e bloqueio de run. Requer aprovação Astra do
   contrato S1A; ainda pode usar fixture sem habilitar kit de produção.
3. **E05-S1C — seletor no menu (Terra, risco médio).** Consome somente as APIs
   aprovadas, cobre estados vazio/bloqueado/atual/erro e não introduz regras.
   O primeiro padrão recebe revisão independente.
4. **Dados fechados (Luna, risco baixo).** Registra nomes, descrições, requisitos
   e tabelas já aprovadas para um único par; validadores provam IDs e referências.
   Não inventa efeitos nem trabalha nos 12 destinos de uma vez.
5. **Subépicos de conteúdo, um par por vez.** Primeiro um par puro de uma origem;
   depois pares direcionais híbridos somente com identidade/regras aprovadas por
   Astra. Mecânicas novas ficam com Sol; composição/UI sobre primitivas prontas
   pode ficar com Terra. Cada par fecha duas builds, fraqueza própria, persistência
   e playtest antes do próximo.

## Próximo pacote delimitado: E05-S1A

Resultado observável: a fachada lista, sem escrever, destinos da origem do
personagem com ID, nome, tipo, afinidade, requisitos e estado
`locked`/`content_unavailable`/`selectable`/`current`. A consulta de uma cópia não
altera catálogo nem perfil.

Arquivos esperados: novo Resource de definição; autoridade de catálogo escolhida
por Astra; `scripts/core/profile_facade.gd`; uma suíte dirigida nova e sua entrada
em `tools/verify.ps1`. Não editar UI, ator, controller, skills E04, save/schema ou
dados de rank de produção.

Verificação proporcional: import headless e a nova suíte dirigida, mais regressões
de `persistent_state`, `profile_store` e `e03_progression_transactions`. A suíte
integral fica para o primeiro delta de runtime/integração; E05-S0 não repete as
65 suítes/2.970 checks do fechamento E04 por ser exclusivamente documental.

Gate: Astra precisa escolher a forma do catálogo, confirmar a regra de prontidão
e liberar S1A. Nenhum pacote posterior é iniciado automaticamente.
