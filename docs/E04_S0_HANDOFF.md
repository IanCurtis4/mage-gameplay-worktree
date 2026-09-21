# E04-S0-A — fronteira mínima de rank e dispatch

Pacote documental autorizado sobre `64bf90a`. Este checkpoint não implementa
gameplay, não escolhe balanceamento e não libera S0-B. Autoridades: [E00.3](E00_03_DATA_SAVE_CONTRACT.md),
[progressão E00.1](ADR_E00_01_CHARACTER_PROGRESSION.md), [classes do MVP](E00_MVP_CLASS_CONTRACT.md)
e [E03-B](E03_B_PROGRESSION.md).

## Estado encontrado e lacunas

- O caminho persistente de rank está pronto: `CharacterState.purchased_skill_ranks`
  guarda apenas incrementos comprados; `ProfileCatalog` valida carteira, teto e
  requisitos; `BuildSnapshot.skill_ranks` recebe ranks efetivos por valor; e
  `RunState.reset()` copia esse mapa para `skill_levels`. Investimentos posteriores
  ao início da run afetam somente a próxima run, como exige E00.
- `SkillDefinition` ainda descreve uma única linha fixa de custo, cooldown, cast,
  poder, alcance e projétil. Não há `SkillRankDefinition`, descrição/categoria,
  pós-cast, pesos/tags/efeitos por rank nem consulta validada. `ClassCatalog` e
  `ProfileCatalog` repetem IDs, mas hoje não provam que metadado de aprendizado e
  definição de combate concordam.
- O rank chega ao runtime, porém quase não é consumido: custo, cast, cooldown,
  alcance e poder leem os valores fixos. A exceção é `RunState.projectile_count`,
  que transforma rank em quantidade para lanças; portanto rank 2 de `slash`, por
  exemplo, persiste e entra no snapshot sem alterar o golpe.
- O dispatch está dividido entre `_execute_skill()` por cadeia de IDs em `main.gd`
  e métodos específicos de `PlayerActor`. Isso é aceitável como handlers explícitos,
  mas o catálogo não declara qual handler cada skill usa; adicionar uma skill hoje
  exige manter manualmente catálogo, dispatch e ator em sincronia.

## Contrato mínimo para S0-B/S0-C

1. `SkillDefinition` é dado imutável e identifica categoria, targeting e um
   `handler_id` enumerado/validado. Ele expõe uma lista contínua de ranks e uma
   consulta `rank_definition(rank)` que retorna somente uma definição existente;
   rank zero, acima do teto ou buraco é erro de catálogo, nunca fallback para R1.
2. `SkillRankDefinition` é um valor imutável com os parâmetros de execução daquele
   rank: SP, cast fixo/variável, pós-cast, cooldown, alcance, poder/pesos e efeitos
   tipados que a skill realmente usa. Requisitos de compra continuam autoritativos
   em `ProfileCatalog` nesta migração curta; duplicá-los no runtime é proibido.
   A convergência futura dos dois catálogos exige um pacote próprio.
3. O rank efetivo vem exclusivamente do `BuildSnapshot/RunState`; preview e commit
   consultam a mesma definição. Uma emissão captura seus valores antes de criar
   dano/projétil. Resource não recebe cooldown, contagem, alvo ou outro estado.
4. `handler_id` seleciona um handler escrito e conhecido em `match`/registro
   fechado. Não contém `Callable`, caminho de script ou código em string. O handler
   recebe contexto + definição do rank e continua dono da geometria/comportamento
   específico; este contrato não cria engine universal de efeitos.
5. S0-B introduz somente definição, validação e consulta, preservando os campos e
   consumidores legados. S0-C migra uma skill piloto de ponta a ponta; só depois
   os campos fixos podem ser removidos com todos os consumidores adaptados juntos.

## OPEN — não inferir

- **OPEN-DESIGN:** qual skill será o piloto de S0-C e quais valores de R1–R5 para
  SP, cast/pós-cast, cooldown, alcance, poder/pesos e efeitos. Os valores atuais
  são apenas baseline do piloto; E00 delegou explicitamente essas tabelas a E04.
- **OPEN-DESIGN:** requisitos e tabela completa das demais skills das três bases,
  incluindo quais ranks mudam comportamento em vez de só números.
- **OPEN-CONTRATO posterior:** schema tipado de efeitos compostos e convergência
  `ClassCatalog`/`ProfileCatalog`. S0-B não deve resolver isso com dicionário livre.

## Próximo pacote proposto: S0-B (aguarda liberação)

Arquivos permitidos: `scripts/data/skill_rank_definition.gd`,
`scripts/data/skill_definition.gd`, um teste dirigido novo e sua linha em
`tools/verify.ps1`. Não editar `ClassCatalog`, `ProfileCatalog`, `RunState`, ator,
controller, UI ou saves. O teste constrói uma fixture local sem números de produção.

Aceite: (a) definição ativa 1–5 e passiva 1–3 aceita ranks contínuos e devolve
cópias/valores sem mutar catálogo; (b) ID de handler desconhecido, rank duplicado,
buraco, zero, teto excedido ou valor estrutural inválido rejeita o catálogo;
(c) consulta fora do intervalo falha explicitamente; (d) campos legados continuam
compilando e a regressão atual não muda. Verificação dirigida da nova suíte e import
headless; `tools/verify.ps1` completo apenas se a integração do teste o exigir.
