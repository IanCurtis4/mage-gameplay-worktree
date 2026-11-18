# E10a T6 — recibo do kit do Sacerdote (`priest`)

Papel: Terra (Claude Sonnet 5.5). Contrato curto com números e as cinco perguntas:
[t6_contract.md](t6_contract.md). Contrato do épico: [e10a_contract.md](../e10a_contract.md) §4 e §4.2.
API usada: [t1_base_seam_api.md](t1_base_seam_api.md) e o Santuário/Graça do E09
([t5_contract.md](../e09/t5_contract.md)), sem editar `scripts/systems/sanctuary/`.

## Base e checkout

| Item | Valor |
|---|---|
| SHA-base | `c8771d20a3dd3fa9de8f578cb1cc3c0908a608b1` (recibo da T1, ponta de `claude/e10a-t1-ae3f9f`) |
| Como chegou à base | `git merge --ff-only c8771d20…` a partir de `7795f56d` (árvore limpa, antecessor direto): mesmo estado final do `reset --hard` pedido, sem descartar nada |
| Branch | `claude/infallible-mirzakhani-b3eda2` |
| Checkout | `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\infallible-mirzakhani-b3eda2` |
| Commit entregue | o commit que contém este recibo (ponta da branch) |
| Engine | `Godot_v4.7.2-stable_win64.exe` (A7), `-GodotPath`, `-SkipEditorImport` depois de uma importação completa |

Sem push, sem `master`, sem tocar em `codex/playtest` nem no save pessoal. Sem worktree extra.
Perfis e saves só de fixture.

## Entregue

Arquivos, todos dentro do dono exclusivo:

- `docs/epics/e10a/t6_contract.md` (antes do código): números por rank das 7 skills, as cinco
  perguntas, estado/snapshot e efeitos reservados.
- `scripts/classes/priest/priest_kit.gd` (`ready_for_play() = true`), `snapshot_manifest.json`
  (revisão 2, 7 campos) e `review_builds.json`.
- `tests/classes/priest/priest_kit_test.gd` e `priest_boss_combat_test.gd` (com os `.uid`).

### As 7 skills (`priest_*`)

| Skill | Como |
|---|---|
| `priest_sanctuary` | `Targeting.POINT`, alcance 260; `open_zone` círculo, âncora `world` no ponto, papel `sanctuary` |
| `priest_grace` | fração do excedente por rank (12% sem a passiva); pulso de cura ao entrar com Graça cheia (recarga 6 s) |
| `priest_aegis` | `grant_aegis` com a capacidade da Perseverança e pulso de luz único |
| `priest_judgment` | `spend_for_cast` no commit; `judgment_request` por alvo; no círculo, todos os inimigos dentro |
| `priest_exorcist` | D3: remove escudo, senão o buff mais forte, senão deixa **Exposto** (`add_received_damage_source`, dono + `light`); bônus contra mortos-vivos registrado (`UNDEAD_BONUS`) e sem efeito (`undead_bonus_for` = 0) |
| `priest_light_seal` | D3: `seal` do E09 + raiz mágica (não-chefe) ou lentidão (`hard_controls.boss`); luz no marcado dá Graça |
| `priest_holy_hour` | círculo ampliado, cura ×2, Graça sem limite, Juízo sem SP por `skill_cost` |

Prece e Escudo Votivo (módulo da origem) rendem +1 Graça por commit pago via
`on_base_skill_committed`. Efeitos em código (IDs de flipbook reservados): `priest_sanctuary_circle`,
`priest_sanctuary_burn`, `priest_grace_rings`, `priest_judgment_column`, `priest_aegis_halo`,
`priest_aegis_pulse`, `priest_seal_ring`, `priest_holy_hour_circle`. Textos pt-BR de efeito, combo,
mecânica e tooltip por rank (`rank_tooltip`).

### Builds (D6)

`review_builds.json`, `ragrpg_review_builds_v1`: **Bastião da Fé** (`priest_bastion`) e **Inquisição**
(`priest_inquisition`), 19 pontos de base e 20 de evolução, legais pelo `ProfileCatalog`. **As builds
referenciam IDs `acolyte_*` do contrato do E10a (§1); a base real só chega com a T5.** Os testes
usam o módulo de fixture `scripts/classes/fixture/fixture_base.gd` instalado sobre `acolyte`.
O ponto 19 de cada build usa Selo Sombrio 1 (pré-requisito da Devoção e sem outro destino legal).

## Validação

`tools/verify.ps1 -GodotPath … -SkipEditorImport -Test <nome>` por teste, depois de uma importação
completa (`editor_import` em worktree novo estoura os 120 s; precisou de `-CheckTimeoutSeconds 300`
duas vezes). Todos sobre o código desta entrega.

| Teste | Resultado | sha256 da saída |
|---|---|---|
| `priest_kit_test` | PASS, 220 checks | `942D0B90F0B554BAC587E57F161741980BF6F731BF7F1162C11B05821165376F` |
| `priest_boss_combat_test` | PASS, 32 checks (2 builds) | `16BBBC37182E6FCE188BCA2AD7E7209E9581C66D5A45B70D09E79BDE3F97C329` |
| `sanctuary_test` | PASS, 155 | `01B74920641522D9B9004D6B7394D056DA28F6F8E2D352E04113B0B605F13A6F` (igual ao da T5 do E09) |
| `kit_seam_test` | PASS, 276 | `60643509690EB7E2D61089293F064B839EEB322B92DAD5C671E0581CD81A6C2F` |
| `kit_seam_hooks_v2_test` | PASS, 38 | `5182F32B62DE14BE5938AF67C615BFBC0CBB6BDF062A64EDB08131758CF6FA5A` |
| `enemy_target_test` | PASS, 88 | `61C1F89F787761EA763AB1D6030CE5487CF3031B5C8FE17958A06BF3AA89FEC4` |
| `sp_ac_kit_test` / `sp_ac_boss_combat_test` | PASS, 170 / 25 | `2229F2DCD6DD2B0F97F05008FDB8F7FD8B119F08B9D2CFEC83B2FE442B6456A7` / `269571175CE4E29BCE0FFE76F032F348A6F9E9773BF33C82E3B7C81FA0719DA6` |
| `mg_ac_kit_test` / `mg_ac_boss_combat_test` | PASS, 177 / 29 | `814D744C0A070565A8852188C85964CDC1B45BC5093AE152BC3E794C3EE152B5` / `66AC49C680CB0D1B0D3010F43033B57F4F4256DCB7215D1DBA5A250CADF8C0FF` |
| `sp_la_kit_test` / `sp_la_boss_combat_test` | PASS, 217 / 31 | `D2DC91B266E2E5A55FB39150B5059A8D34BBB2D46CA2B5BF7157F0614114F697` / `4F9C0F3FB7B9919FBBF80D612971B572ACE39A23BBCFB2D361E14CA22AE698CE` |
| `mg_la_kit_test` / `mg_la_boss_combat_test` | PASS, 231 / 33 | `B480859D5403B1E855CD3190E92F1D4227967A9F3594A99B0EB38E7E93BEF95D` / `6710C89EC58026EC2087DACAE4E531374CC5B5EB4EBCBD8181C5ADAC0684F98D` |
| `ui_evolution_test` | PASS, 97 | `DF7B1619F114033B0C05563E933F5A06170AC0D0EEF1A886AA5C45F28C7369EF` |
| `e05_identity_boundary_test` | PASS, 18 | `BB7A24E201BB8F3FE049E9AE7AF9CEC15C5387C3B627DA8098AE6E50A7AA0953` |
| `e06_skill_dependencies_test` | PASS, 228 | `A53B9C316094AC87E2B408A91F5E454D270592DE3BF95C0F68E9A7841A9F39BB` |
| `e06_all_skill_migration_test` | PASS, 36 | `0576EEFDF088C3D13DE5644B4570873863A73E9A194DC1CAE8181896D061D287` |
| `skill_allocation_test` | PASS, 44 | `4BBF4DE594BE8F142DB94129FC154393A17EBD463F30E86A1BDBB35A500317A8` |
| `e06_icon_bar_test` | PASS, 24 | `EB3F9ABDAF6F6B129E2FE140E29916FCDDECD3E077141BF2FE525A5703A692AA` |

Busca por `SCRIPT ERROR` e `still in use` nas saídas dos testes que passam: **0 ocorrências**. O
combate integrado mostra, por build (log do motor): Bastião 19,5 s, chefe a 0/6000, 4 Juízos, 1 Hora
Santa, 2 Santuários, Graça +31 (máx. 15); Inquisição 16,5 s, 3 Juízos, 2 Selos (lentidão 36%, nunca
raiz), chefe Exposto, Graça +39 (máx. 27). O dano vem em boa parte da Luz Punitiva da base de
fixture, que não é a base real (T5): é prova de laço, não de balanceamento.

### Ajustes em testes legados (decisão A9 da arquitetura, regra A15 do E09)

`ready_for_play() = true` muda enumerações exatas de outros arquivos. Pela A9 (`0c157d47` em
`claude/e10a-arquitetura-a413a1`), quem liga `ready_for_play` atualiza só os checks que contam ou
afirmam kits prontos, com número exato e sem enfraquecer outro check. Os dois arquivos entraram na
minha posse só para isso:

| Arquivo | Ajuste | Resultado depois |
|---|---|---|
| `tests/e10a/base_seam_test.gd` (loop de esqueletos, ~linha 125) | o Sacerdote passa a ser verificado como kit pronto com 7 skills (`validate` ok, `ready_for_play`, 7 definições); o Cultista continua esqueleto vazio e não pronto | PASS, 171 checks, sha256 `83E3C22E78D21A6C9EDC81ACF01599A30F1F4D0795ECAF4668097594536A9BEA` |
| `tests/e08_feedback_recipe_test.gd` linha 98 | kits prontos: 4 → 5 (mensagem atualizada) | idem abaixo |
| `tests/e08_feedback_recipe_test.gd` linha 99 | **contagem inalterada, 20 ativas e 8 passivas**: o catálogo de produção só publica as skills de um kit puro quando a base Acólito está pronta (regra da T1), e ela ainda é esqueleto; só a mensagem diz isso. Não usei 25/10, que o catálogo não expõe hoje | idem |
| `tests/e08_feedback_recipe_test.gd` `_expected_kit_skills()` (linha 100) | a tabela esperada ignora kits puros cuja base registrada não está disponível (`IdentityIds.is_registered_base` + `ProfileCatalog.base_class_is_available`), igual à regra de oferta | PASS, 1309 checks, 0 falhas, sha256 `AA05DF9D217F6F82C1B2B476BC1ECA42F0D94252AC09AF34FE2A96B18D22E54F` |

Quando a T5 deixar a base pronta, as contagens de ativas e passivas da linha 99 sobem e o filtro do
ajudante deixa de excluir o Sacerdote; essa atualização é de quem ligar a base (T5) e do Cultista (T7).

**Decisão A10 (`1378115a`):** `tests/e05_evolution_catalog_test.gd` entra na posse da T6 só para isso:
- linha acrescentada ao `KIT_METADATA`: `&"priest": ["Sacerdote", &"acolyte", &"2-1", &""]`;
- só ela deixava 1 check falhando ("twelve accepted E00 identities"), porque `_ready_kit_ids()` conta
  kits prontos e o catálogo de produção ainda não oferece o Sacerdote (base esqueleto). O ajudante ganhou
  o mesmo filtro de base disponível aceito para `_expected_kit_skills()` (A10 item 2): kit puro só conta
  quando a base registrada está disponível. Nenhuma expectativa foi enfraquecida;
- resultado: PASS, 93 checks, 0 SCRIPT ERROR, sha256 `6B7F3B5BBE61238BDDBAAA633CB0AF8DD4276D4F1E4B833DEBADC01062C87AB2`
  (antes: FAIL com 2 SCRIPT ERROR). Quando a T5 ligar a base, o filtro deixa de excluir o Sacerdote e o
  teste passa a esperá-lo no catálogo.

Última rodada (23 testes, 0 SCRIPT ERROR, 0 "still in use", todos PASS): `.godot/t6_final2.txt`; hashes iguais aos da tabela acima. Dois outros testes falham no ambiente, sem relação com a T6: `e08_feedback_vfx_test` e
`kit_seam_hooks_v3_test` (check "F1 world fixture is current"), por falta de `source_hashes.json` na
worktree (falha conhecida de worktree novo, como o passo 255 da T1). Não rodei a suíte completa:
a T6 não toca arquivos compartilhados.

## Decisões dentro do contrato (para a arquitetura conferir)

- **Selo de Luz mantém `force_target`** (vem do `seal` do E09, o único ajudante com estado do
  Selo): o marcado fica preso ao Sacerdote além de enraizado. Sem efeito no chefe sem adds.
- **Graça pelo Selo conta toda luz** (direta ou queimadura do Santuário), como o Paladino: com o
  Selo, o círculo rende 1 Graça por pulso no marcado. Candidato a ajuste de playtest.
- **Exorcista só com golpe direto** (`secondary` falso): queimadura e pulso da Égide não expõem.
- **"Buff" do inimigo** = fonte de dano recebido < 1 (única estrutura genérica de buff que a C1.7
  define). O conteúdo atual não tem inimigos com buff nem escudo: o caminho existe e está provado
  por fixture, mas só aparece em jogo quando algum mob os produzir.
- **Santuário recusado durante a Hora Santa** (`priest_hour_active`), como o Juramento do Paladino.
- **Juízo gasta no máximo 5 cargas (10 na Hora)**: a Graça sem limite não vira dano infinito.
- **Passiva Graça "liga as cargas"**: sem ela, a Graça rende devagar (12% do HP máx.) e não há
  pulso de entrada.

## Limitações

1. Só o caminho do mapa plano é provado no kit; o mundo da expedição usa `cast_point` e as âncoras do
   E09 (provadas no `sanctuary_test`), sem teste próprio do Sacerdote no mundo.
2. O Sacerdote só aparece no jogo com a base Acólito pronta (T5): enquanto ela for esqueleto, o
   `ProfileCatalog` não o oferece (regra da T1).
3. Passivas (Graça, Exorcista) não emitem evento de feedback; o efeito do Exorcista não tem desenho.
4. Efeitos: os 8 desenhos em código passam pelo `_draw()` real, mas não houve captura nativa
   (esta tarefa não tem parte visual validada por captura).
5. Os números são ajuste de playtest; o balanceamento contra a base real depende da T5.
6. Arquivos `.import` reescritos pelo editor ficaram fora do commit, como nas tarefas anteriores.

## Próximo passo

T13 compõe a entrega; T11 (augments) e T12 (HUD: `hud_state` do Sacerdote passa à T12) dependem dela.
As três correções de teste legado acima entram na composição (T1/T10/T13, conforme a arquitetura
decidir).
