# E00.3 — Catálogo, runtime, save e migração

Contrato candidato v1, 13/09/2026. Não implementa persistência ou combate.
Depende do [ADR](ADR_E00_01_CHARACTER_PROGRESSION.md) e da
[matemática](E00_02_STATS_CONTRACT.md). IDs em inglês/snake_case; textos em pt-BR.

## Catálogos imutáveis

| Tipo futuro | Campos obrigatórios / invariantes |
|---|---|
| `ClassDefinition` | `id`, nome, vetor inicial com seis primários/soma 30, skills iniciais gratuitas, auto, restrições de equipamentos |
| `EvolutionDefinition` | `id`, `origin_class_id`, `branch_kind`, `affinity_class_id` opcional, requisitos base/job, skills próprias, ranks gratuitos, definição intrínseca; origem != afinidade |
| `SkillDefinition` | ID global, nome/descrição, dono de carteira, targeting, categoria ativa/passiva, lista explícita de ranks; não conter tecla física fixa |
| `SkillRankDefinition` | rank contínuo 1..5 ou 1..3, custo 1 por incremento não gratuito, job mínimo, dependências, SP, cast fixo/variável, pós-cast, cooldown, alcance, poder/pesos/tags/efeitos; sem números inferidos pela UI |
| `IntrinsicDefinition` | ID, tipo de estado, comandos permitidos, limites/custos, dependências e descarte; sem rank comprado, sem biblioteca de passivas ocultas |
| `EquipmentDefinition` / `CardDefinition` | ID, slot/restrição, modificadores/efeitos tipados; carta só aceita encaixe da run |
| `AugmentDefinition` | ID, identidade/tag de elegibilidade, limite de stacks, handler tipado, valores atual/próximo; não guarda stacks |
| `ProgressionDefinition` | versão do contrato, curvas e tetos do ADR, requisitos de evolução; matemática central consome essa definição |

Catálogo registra `catalog_version` (inteiro inicial 1) e `ruleset_id=e00_v1`;
ambos diferentes do formato do save. Novas versões exigem migração explícita das
alocações se custos, IDs, ranks ou limites mudarem. Não usar nome traduzido como ID.
Híbridas preservam `sp_mg`, `mg_sp`, `sp_ar`, `ar_sp`, `mg_ar`, `ar_mg`.
Renomear Arqueiro Arcano para Geômetra não troca `mg_ar` nem exige respec.

Skills homônimas têm IDs distintos: `sp_mg_rewrite` e `mg_ar_rewrite`, por exemplo.
Catálogos não contêm Node, callable de script arbitrário ou código em string.
Handlers são implementações enumeradas e registradas. Validar duplicatas, pesos,
requisitos acíclicos, ranks alcançáveis e referências antes de carregar um perfil.
Skill gratuita de entrada é job 20 (ver ajuste explícito do PDF no contrato de
híbridas); não deixar personagem evoluído sem acesso à própria interação.

## Objetos e operações

`ProfileState` possui personagens e coleção. `CharacterState` possui identidade,
XP, alocações e seleção persistente. `RunState` referencia o ID de origem, mas
recebe cópias por valor dos mapas/arrays de build; não armazena referência mutável
ao personagem ou Resources. `HealthState`, `ResourceState`, `CooldownState`,
`EffectState` e `IdentityRuntime` são componentes pertencentes à run/atores.

`BuildSnapshot`: `ruleset_id`, `catalog_version`, `character_id`, `base_class_id`,
`evolution_id`, `base_level`, `job_level`, `attribute_allocations`, `skill_ranks`,
slots, equipamentos e versão da build. Campos de XP/conta não são mutados pelo ator.
Troca permitida de equipamento cria versão nova; uma emissão já criada conserva
os valores capturados. Cópias profundas também valem para lista de ranks/efeitos.

Caso extremo de troca sem cura: se o novo máximo de HP for menor ou igual ao
déficit atual, ou o novo máximo de SP for menor que o déficit atual, rejeitar a
troca inteira antes do save, com aviso para recuperar recursos. Não truncar o
déficit e depois devolver recursos ao reequipar. Mudanças involuntárias de máximo
(buff expirando) conservam o déficit num ledger runtime, mesmo acima do novo teto;
regeneração/cura reduz esse déficit, dano real o aumenta, morte encerra a run.
Isso impede recuperar SP repetindo remoção de item com SP quase vazio.

Serviços futuros expõem operações tipadas, com `request_id`, revisão esperada e
resultado `ok/error_code/new_revision`. Falha não altera parte do estado.

| Operação | Pré-condição / resultado |
|---|---|
| `create_character` | Menu, limite 8, classe disponível; novo ID, XP0, ranks gratuitos, starter loadout válido |
| `allocate_attributes` / `learn_skill` | Menu sem run, revisão atual, custo e requisitos válidos; recalcular carteira pela origem dos pontos |
| `respec` / `change_evolution` | Menu, mesma origem, regras do ADR; reembolso exato e normalização de presets atômicos |
| `start_run` | Loadout válido, nenhum save pendente; reserva run_counter em disco antes de entregar snapshot |
| `grant_reward` | Sessão ativa correspondente, seq exata, origem fixa; XP/coleção/recibo no mesmo commit |
| `equip_between_encounters` | Encontro encerrado, item desbloqueado/legal; preferência salva e nova cópia runtime; HP/SP sem cura |
| `end_run` | Fecha sessão de recompensas uma vez, descarta runtime, grava resultado quando aplicável |
| `derive_stats` / `preview_skill` / `resolve_damage` | Operações puras; RNG explicitamente fornecido ao resolver; UI usa os mesmos resultados |

Erros mínimos: `stale_revision`, `invalid_catalog`, `invalid_origin`,
`insufficient_points`, `requirements_unmet`, `run_active`, `invalid_reward_sequence`,
`save_failed`, `unsupported_schema`. Texto humano é traduzido pela UI, não usado
como chave de controle. Nenhuma operação do personagem é disparada por desenhar UI.

## Formato persistente proposto: schema 2

Primeiro save real de personagens usa `schema_version=2`, para não confundir com
o v1 planejado do piloto. `format_id=ragrpg_character_profile` é obrigatório.
Arquivo final `user://profile.json`, backup `profile.backup.json`, temporário
`profile.pending.json`. `controls.cfg` permanece independente até migração de
preferências explicitamente implementada; E00 não escreve em nenhum desses arquivos.

Campos da raiz:

- `format_id`, `schema_version`, `catalog_version`, `ruleset_id`;
- `profile_id` UUID, `revision` inteiro >=0, `next_character_counter` e
  `next_run_counter` inteiros crescentes nunca reutilizados;
- `selected_character_id` nullable; `equipment_collection` como IDs únicos;
- `characters` como array; `settings` tipados e `lifetime_stats` inteiras >=0;
- `reward_session` null ou `{run_id, character_id, last_committed_seq}`;
- `legacy_loadouts` e `unresolved_legacy` somente para preservar migração conhecida.

Cada personagem: `character_id` derivado do UUID do perfil + contador monotônico,
`display_name` (1–24 caracteres Unicode, sem controles), `base_class_id`,
`evolution_id` nullable, `base_xp_total`, `job_xp_total`, `attribute_allocations`
com as seis chaves, `purchased_skill_ranks` (incrementos além dos ranks gratuitos),
`equipped` (arma/armadura/acessório), `presets` (2 seleções de slots/equipamentos),
`selected_preset` em 0..1. Rank aprendido efetivo = gratuito do catálogo ativo +
incrementos comprados, limitado ao teto. Pontos, níveis e derivados não são salvos
em duplicidade; derivá-los após validar XP/alocações evita saldos divergentes.

Coleção contém também starters desbloqueados ao criar cada base; escolher um preset
revalida restrições da identidade e itens possuídos. JSON contém somente escalares,
arrays e objetos conhecidos; no máximo 8 personagens, IDs<=64 caracteres, contadores
<=2^53−1, arquivo<=4 MiB. Números de XP/ranks/contadores devem ser inteiros exatos,
não bool, negativos ou NaN. Ultrapassar limite falha com cópia preservada.
Não truncar histórico válido para caber no teto silenciosamente.

Neste formato inicial, `settings={}` reserva extensões sem duplicar `controls.cfg`;
preferências novas exigem campos/versionamento documentados em E02/E08.
`lifetime_stats` aceita `runs_started`, `runs_completed`, `deaths`, `kills` e
`equipment_unlocked`, todos inteiros >=0, ausentes equivalem a0. Chaves desconhecidas
ficam preservadas para migração, sem serem executadas/interpretadas como código.
`display_name` não é caminho de arquivo nem argumento de shell.

Repetições de comandos de menu conservam `request_id` e a revisão esperada original;
depois de commit, a mesma revisão fica obsoleta e impede uma segunda concessão.
Não atualizar a revisão automaticamente e reenviar a mesma criação/respec como se
fosse nova intenção. Após resultado incerto, reler estado e mostrar o resultado.

Nunca salvar HP/SP, cooldowns, efeitos, recursos de identidade, run snapshot,
augments, cartas, vértices, rastros, traps, inimigos, RNG ou ofertas. A pequena
sessão de recompensas é recibo de durabilidade, não permite retomar combate.

## Escrita, recuperação e idempotência

Um escritor por perfil, fila serializada. Copiar estado, validar, incrementar
revision, serializar temporário no mesmo diretório, flush/fechar e reler/validar.
Preservar versão anterior íntegra como backup antes de substituir o principal.
Usar substituição atômica suportada pelo filesystem; E01 deve provar o mecanismo
Windows com testes de interrupção. Não implementar “apagar principal e escrever”.
Somente publicar novo estado em memória/confirmar recompensa após commit em disco.

Leitura: validar principal; se íntegro, usá-lo. Se ausente/corrompido, validar
backup e recuperar com aviso, preservando o corrompido. Temporário isolado nunca
é promovido automaticamente: pode ser uma transação não confirmada. Principal
com schema/versão futura não é corrupção: bloquear escrita e pedir versão do jogo
compatível, sem recuar ao backup e sobrescrever progresso novo. Se nenhum arquivo
existir, criar perfil vazio; se arquivos existirem mas todos forem inválidos,
oferecer recuperação/criação explícita sem destruir os originais.

`run_id = profile_id + next_run_counter`, reservado em commit antes do início.
Sessão guarda origem e maior sequência confirmada. Recompensas usam seq 1,2,3…:
seq=cursor+1 aplica; seq<=cursor retorna `already_applied`, sem mutação;
seq>cursor+1 falha e exige completar o evento anterior. Conteúdo da recompensa
vem do resolver local, não de valores arbitrários da UI. Repetição deve conservar
o payload original; a fila mantém pedido enquanto não recebe confirmação.

No mesmo commit, atualizar XP/itens/estatísticas e cursor. Nenhum prêmio pode ser
aplicado a outro personagem. Sessão inexistente ou run_id diferente rejeita todos
os eventos, mesmo se seq 1. Encerrar run salva `reward_session=null`; IDs nunca são
reutilizados, logo replays de runs encerradas não exigem ledger infinito.

Ao reabrir, uma sessão salva é fechada antes de permitir nova run. Mantém XP/itens
confirmados, descarta combate e não cria recompensa de fim; se a gravação falhar,
não iniciar nova sessão. Crash depois de commit mas antes do retorno: leitura do
cursor impede duplicação. Falha antes de commit: memória publicada e cursor antigos
permanecem. Backup após corrupção pode recuperar revisão anterior com perda do último
commit; isso deve ser informado, não apresentado como recuperação sem perdas.

## Migração suportada e alteração dos contratos atuais

| Origem | Destino / comportamento |
|---|---|
| Só `controls.cfg`, sem perfil (situação atual) | Perfil schema 2 vazio; manter controles; pedir criação de personagem; não importar níveis transitórios |
| v1 planejado do piloto, se encontrado | Só migrar envelope reconhecido com schema 1, equipment_collection/equipped por classe, settings/lifetime_stats válidos. União de equipamentos reconhecidos para coleção; seleções antigas em legacy_loadouts; characters vazio. Backup original, conversão única para schema 2 |
| ID de item antigo desconhecido na migração v1 | Preservar em unresolved_legacy, informar; nunca conceder item substituto aleatório |
| Schema 2 com catálogo incompatível/ID de identidade ausente | Bloquear personagem afetado sem reescrever/perder alocações; exigir mapa de migração de catálogo |
| Versão futura / formato desconhecido | Não converter, não sobrescrever, manter original para recuperação |

Migração v1 não inventa personagens/XP. Na criação explícita de uma base, oferecer
legacy_loadout compatível como seleção; validar posse/restrições. Não migrar cartas
run-only para a coleção. IDs traduzidos não viram IDs técnicos automaticamente.

Em E03, `physical_attack` atual passa a `melee_attack` + `precision_attack`;
`defense` separa física/mágica; `hit_chance` vira resolver HIT/FLEE; mana interna
será `current_sp/max_sp/sp_regen` com adaptação de todos os consumidores no mesmo
passo; `cast_multiplier` vira cast fixo/variável. Não sustentar dois nomes como
fontes independentes. Catálogo, CombatMath, HUD e testes migram juntos.
`RunState.reset()` deixa de aprender todas as skills em rank 1: recebe snapshot
de CharacterState e limpa só o transitório. E01 fornece persistência/fachada;
E03 implementa progressão/stats. Não liberar E02/E04 com APIs parciais inferidas.

## Fixtures e aceitação futura

[e00_reference.json](fixtures/e00_reference.json) guarda vetores numéricos,
limiares de XP, payload mínimo schema 2 e cenários negativos. O verificador
[verify_e00_contract.py](../tools/verify_e00_contract.py) valida o contrato
isoladamente, sem importar o runtime ou abrir saves reais. Não constitui uma
implementação alternativa de gameplay.

O perfil de fixture é um exemplo estrutural de menu com equipamentos vazios,
não um loadout pronto para iniciar combate. A validação do exemplo não substitui
a futura validação integral de skills/coleção/versão por E01.

E01/E03 devem consumir as mesmas fixtures contra a implementação e provar:
cópias profundas sem vazamento entre alts/Resources; rejeição sem mutação de
identidade errada; respec conservando cada carteira; morte/fechamento sem reset de
XP; replay antes/depois de restart; falha de escrita em cada etapa; recuperação
principal/backup/temporário; versão futura intacta; migração v1 idempotente;
UI/combate com o mesmo número; limites de dano/cast/ASPD/CC e loops secundários.
Testes somente em diretório temporário explicitamente fornecido; nenhum default
de teste resolve para `user://profile.json` do jogador.

O formato e casos estão especificados; a durabilidade real e migração executada
só poderão receber aceite de implementação em E01/E03. E00 não afirma tê-las testado.
