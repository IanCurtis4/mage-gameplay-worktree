# E09 — correções Sol das falhas da composição (17/11/2026)

**Papel e estado**
- Papel: Sol (Claude Opus 5.5), no lugar das tarefas donas, que estão em outra conta.
- Estado proposto: **ENTREGUE** para a T10 mesclar e repetir a suíte e a exportação.
- Branch: `claude/e09-sol-fixes-3ce821`, cortada de `claude/e09-candidato` em `3e65ba25`.
- Ponta das correções: `756a9e44`. Este recibo vem no commit seguinte.
- Sem push e sem `master`. `tools/verify.ps1`, `docs/epics/e09.md` e
  `docs/art/generation_queue.md` não foram tocados.

As falhas estão descritas em [t10_blockers_2026_11_17.md](t10_blockers_2026_11_17.md).

## Commits (um por frente)

| Commit | Frente | Dona | Arquivos |
|---|---|---|---|
| `ed76d2a4` | 1. Passo 26, receitas E08 | T1 (C1), receitas K1, K2 e K4 | `tests/e08_feedback_recipe_test.gd`, `docs/epics/e09_contract.md` (nota em C1) |
| `92b23ca5` | 2. Passo 48, opções de skill | T1 (C1), com K1 e K3 | `tests/e03_progression_transactions_test.gd` |
| `71dec1de` | 3. Passo 250 e sonda do PCK | T8 | `tests/e06_export_content_test.gd`, `tools/export_content_probe.gd` |
| `756a9e44` | 4. Perfil de revisão inválido | T9 | `tools/e09_review_profiles.gd` |

Nenhum arquivo de kit (`scripts/classes/**`) mudou.

## Decisões e justificativa de cada expectativa alterada

### 1. `e08_feedback_recipe_test` (T1/C1)

**Contagem.** Trocar 71 por 91 esconderia de onde vêm as skills. O teste agora separa a origem:
- **Base da E08:** continua com 71 ativas e 22 passivas, a mesma expectativa de antes.
- **Kits:** uma skill é de kit quando `ClassKitRegistry.skill_owner` não é vazio. Os kits são
  contados à parte, com 20 ativas e 8 passivas, exatamente as da tabela `SKILL_IDS` /
  `SLOT_CATEGORIES` dos kits prontos (A15).
- **Prontidão:** o teste exige os 4 kits prontos no catálogo de produção.

**Receita.** Para a base, continua valendo `RECIPES.has(skill)`. Para um kit, valem quatro
condições:
- a receita vem de `ClassKitRegistry.feedback_recipe`;
- família e elemento são os da linha do kit;
- não há assinatura;
- a skill **não** está em `RECIPES`, porque a linha da base esconderia a do kit.

O ataque básico dos 4 kits também passou a fazer parte da cobertura de áudio, com a variante do
kit e o acerto básico.

**As 4 deixas.** Investiguei uma por uma. Nenhuma receita está errada: falta a deixa na paleta
P6. A cadeia é assinatura → família × elemento → família × físico → deixa do tipo, e a paleta
não tem estas deixas:
- `p6.dot.arcane` nem `p6.dot.physical` (`paladin_oath` e `thaumaturge_votive_circle`, pulsos
  periódicos arcanos), que por isso caem em `world.impact`;
- `p6.heal.arcane` nem `p6.heal.physical` (`thaumaturge_healing_refraction`), que fica em
  silêncio;
- `p6.summon.arcane` nem `p6.summon.physical` (`arcane_blade_prism_specter`), que fica em silêncio.

Eu poderia corrigir os kits, mas só deformando a receita:
- trocar o elemento muda a cor dos efeitos em `feedback_vfx_layer`;
- tirar `PERIODIC` troca o som do pulso pelo de impacto cheio.

As duas mudanças seriam escolha de produto. A alternativa, criar a deixa, exige WAV e
`audio_event_catalog.gd`, que estão fora do escopo do E09 (não há áudio no épico) e da minha
propriedade.

Decisão: a regra da E08 continua valendo para os kits, com uma exceção de lista exata, que
documentei em `e09_contract.md` (nota de C1). O teste confere três coisas:
- cada item da lista é de kit e ainda não tem nenhuma deixa planejada;
- a lista vista é igual à registrada: uma lacuna nova reprova o teste;
- quando uma lacuna ganhar deixa, o item precisa sair da lista.

Os outros tipos de evento dos kits seguem a regra "planejada primeiro" sem exceção.

### 2. `e03_progression_transactions_test` (T1, K1 e K3)

Imprimi a lista do Espadachim do `ProfileCatalog.pilot()` com um script temporário fora do
repositório. A causa se confirmou: as evoluções da origem são `defender`, `berserker`, `sp_mg`,
`sp_ar`, `sp_ac` e `sp_la`, e as 7 skills `paladin_*` (K1) e as 7 `duelist_*` (K3) entram nas
opções.

Pelo contrato isso é o certo, e não um vazamento:
- C1.3: um kit pronto registra skills, aprendizado e evolução;
- C1.10: a origem pode ter mais de duas híbridas;
- o próprio check promete "every origin catalog skill … including future evolution entries".

A lista exata ganhou esses 14 IDs, em ordem alfabética, como as demais. Nenhum ID antigo mudou.
O rótulo passou a imprimir a lista real quando falha, o que faltava no diagnóstico da T10.

### 3. `e06_export_content_test` e `tools/export_content_probe.gd` (T8)

Os equipamentos foram de 85 para 89 com `e09_halo_shield`, `e09_buckler`, `e09_rapier` e
`e09_prism_staff`, que são os 4 `.tres` acrescentados desde `a033dcb8`. É a mesma atualização
A15 que o recibo da T8 fez nos outros legados, mas que não chegou a estes dois.

### 4. `tools/e09_review_profiles.gd` (T9)

Corrigi o gerador, e não o nome da build. A nova `review_display_name(build_name)` escolhe o
nome assim:
- usa `"E09 " + nome` quando cabe em 24 caracteres;
- senão, usa o nome da build sozinho;
- senão, corta o nome com reticências;
- se o nome for vazio, usa `"E09"`.

Assim, qualquer build gera no máximo 24 caracteres. O limite espelha
`ProfileCodec._valid_display_name`. Se o codec mudar, o commit do perfil continua sendo a
autoridade e reprova.

## Validação

- **Motor:** `.tools/godot/Godot_v4.7.2-stable_win64.exe` (o exe GUI, chamado pelo PowerShell).
- **Importação:** `--headless --editor --import --quit`, com saída 0. Só apareceu o erro conhecido
  do `GitPlugin`.
- **`.import`:** os modificados só por fim de linha foram restaurados (0 diferenças com
  `--ignore-cr-at-eol`), assim como a DLL do plugin que o editor apaga. Os arquivos não
  rastreados gerados pela importação ficaram fora dos commits.

**Testes na ponta `756a9e44`.** Comando: `tools/verify.ps1 -Test <6 nomes> -CheckTimeoutSeconds
300`, sem `-F1Fixture` (nenhum dos seis lê o mapa F1). A pasta é
`.godot/verification/sol_fixes_756a9e44/`, fora do Git, com `plan.json` registrando a
`source_commit` 756a9e44 e nenhuma alteração rastreada.

| Passo | Teste | Resultado |
|---|---|---|
| 26 | `e08_feedback_recipe_test` | PASS, 1256 checks (antes: 26 falhas em 1224) |
| 48 | `e03_progression_transactions_test` | PASS, 47 checks |
| 108 | `e05_evolution_catalog_test` | PASS, 93 checks |
| 250 | `e06_export_content_test` | 171 checks, 0 falhas |
| 333 | `kit_seam_test` | 268 checks, 0 falhas |
| 334 | `ui_evolution_test` (T9, usa o gerador) | 97 checks, 0 falhas |

SHA256 de `checks.jsonl`: `9685FBD4D1ED18BE5ED64A0FC5A147828C8F842A1D5F79C9557B50F39B3218AC`.

**Gerador de perfis.** Rodei `--script res://tools/e09_review_profiles.gd -- <pasta>` numa pasta
isolada da sessão (scratchpad, fora do save pessoal e do `user://`), sobre o mesmo conteúdo que
foi para `756a9e44`. Resultado: `ok: true`, `invalid: []`, `pending: []` e **8 perfis**, 2 por
kit, todos com `job_xp_total` 17940 (`review_job_xp()`, job 40).

| Kit | Nomes (caracteres) |
|---|---|
| `sp_ac` | "E09 Baluarte da Luz" (19), "E09 Martelo Consagrado" (22) |
| `mg_ac` | "E09 Altar Prismático" (20), "E09 Coro da Aurora" (18) |
| `sp_la` | "E09 Lâmina Paciente" (19), "E09 Arena do Duelo" (18) |
| `mg_la` | "Corrente de Execuções" (21, sem prefixo), "E09 Espectro Prismático" (23) |

Os testes dos kits não rodaram porque nenhum arquivo de kit mudou. A suíte completa é da T10.

## Limitações concretas

1. **Lacunas de áudio dos kits.** No jogo, os pulsos do Juramento e do Círculo Votivo soam com o
   `world.impact` genérico. A Refração Curativa e o Espectro de Prisma não têm som próprio de
   cura e de invocação, mas os outros tipos de evento dessas skills têm deixa. Fechar isso pede
   uma tarefa de áudio, com WAV e `audio_event_catalog.gd`, e cabe ao usuário decidir se e quando.
2. **Nome sem prefixo.** O perfil "Corrente de Execuções" é o único sem "E09 ". Não houve
   ambiguidade, porque cada perfil fica numa pasta própria com o ID da build. Se o prefixo for
   obrigatório, a alternativa é encurtar o nome da build na K4.
3. **Sonda do PCK não rodada.** `tools/export_content_probe.gd` exige o PCK exportado. A T10
   confirma o 89 na próxima exportação.
4. **Teste sem a nova regra de nome.** `ui_evolution_test` é da T9 e não ganhou um check de nome
   com 25 caracteres ou mais. A garantia está no gerador e na rodada isolada acima.
5. **Escopo da validação.** A validação é de contrato e de invariantes, e não uma auditoria
   semântica independente (AGENTS).
