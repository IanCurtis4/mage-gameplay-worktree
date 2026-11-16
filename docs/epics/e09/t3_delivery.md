# E09 · T3 — Ícones SVG das 28 skills · recibo

**Entrega:** commit na branch `claude/frosty-tu-a95677` (SHA no fim da mensagem de entrega e em `git log`).
Sem push, sem `master`.

## Base e checkout
- Base: `771a314f78c7a0cb5fda2f1f48d93bc6dc776b68` (documentos do E09). A worktree saiu de `master`
  `acd589eb`; trouxe a base com `git merge --ff-only` (avanço direto, sem merge commit).
- Branch: `claude/frosty-tu-a95677`.
- Checkout: `C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.claude\worktrees\frosty-tu-a95677`.

## O que foi entregue
- 28 SVG 64×64 em `assets/art/skills/<skill_id>.svg`, mais os 28 `.svg.import` (gerados pelo Godot 4.7.2,
  mesma convenção dos atuais: texture, `compress/mode=0`, sem mipmaps).
- `tools/prepare_skill_icons.py`: 28 motivos novos (`HYBRID_SHAPES`), 4 paletas, ids por lista explícita
  (`HYBRID_SKILLS`), moldura própria da Lâmina Arcana (octógono facetado); Paladino reutiliza a moldura
  de escudo, Taumaturgo a de Mago/Elementalista, Duelista a de Espadachim. Passivas com contorno
  (8: `paladin_guard_grace`, `paladin_unshaken_faith`, `thaumaturge_votive_prism`,
  `thaumaturge_elemental_choir`, `duelist_read_opponent`, `duelist_patient_guard`,
  `arcane_blade_enchanted_edge`, `arcane_blade_light_fracture`). Cada motivo é distinto (checagem do gerador).
- `manifest.json`: 117 entradas (89 + 28), com SHA-256 de cada SVG. As 89 antigas ficaram idênticas.
- `assets/art/skills/README.md`: seção "Ícones das híbridas E09" (gerada pelo script).
- Prancha: `docs/epics/e09/t3_icons_review.png` (28 em 192 px, 64 px e 40 px, com 6 ícones da classe de origem).

## Paletas (fundo / silhueta)
| Classe | Fundo | Silhueta | Ficha |
|---|---|---|---|
| Paladino | `#2b4a78` | `#f4e3a8` | azul-céu + prata/dourado |
| Taumaturgo | `#2a3a8c` | `#fff0c2` | azul + branco/dourado |
| Duelista | `#2b1318` | `#d8dde4` | preto/vermelho escuro + prata |
| Lâmina Arcana | `#24272d` | `#8fcfff` | preto/cinza-chumbo + azul de cristal |

O estilo atual é de **duas cores por ícone**; por isso vermelho e amarelo da Taumaturgo e da Lâmina Arcana
(e o dourado da Lâmina) **não aparecem**; a identidade vem do fundo azul, do halo claro e da forma. Se o
usuário quiser acento por elemento (fogo/gelo/raio), é mudança de estilo, não de motivo.

## Motivos (função na ficha → forma)
- Paladino: `paladin_oath` cone sobre escudo · `guard_grace` halo com 5 cargas · `consecrated_impact` coluna sobre
  disco · `oath_aegis` halo quebrando em pulso · `unshaken_faith` cruz · `condemned_seal` aro fechando com 4 cunhas ·
  `oath_hour` sol/círculo completo.
- Taumaturgo: `votive_circle` círculo com chama e 3 nós · `votive_prism` prisma com 3 raios · `healing_refraction`
  cruz com ondas · `altar_shift` setas ⇄ sobre altar · `elemental_choir` fogo+gota+raio sob um arco ·
  `prismatic_judgment` coluna e 3 pulsos · `convergent_dawn` sol nascente.
- Duelista: `parry` lâmina desviando em arco · `read_opponent` olho de fenda · `fatal_riposte` estocada com estrela ·
  `feint` seta curva com trajeto tracejado · `patient_guard` ampulheta · `guarded_retreat` chevrons de recuo com guarda ·
  `duel` duas pontas se encontrando.
- Lâmina Arcana: `refracted_mark` anel de mira com prisma · `enchanted_edge` lâmina de cristal · `refraction` silhueta
  tracejada com luz dobrada · `prismatic_leap` arco pontilhado até as costas · `light_fracture` gema rachada ·
  `prismatic_sentence` lâmina com 3 cortes de cada lado · `prism_specter` losango central com dois reflexos.

## Validação
- `python tools/prepare_skill_icons.py --check` → `117 icons; active=88; passive=29`, exit 0 (89 antigos + 28 por lista).
  Resultado (depois de gerar): conferido; gerador roda 2× sem diferença.
- 89 antigos idênticos: comparação feita em Python entre (a) SHA-256 do arquivo em disco, (b) SHA-256 do arquivo em
  `HEAD`, (c) SHA do manifesto de `HEAD` e (d) SHA do manifesto novo. **0 divergências em 89**; as entradas antigas do
  manifesto são idênticas campo a campo. O `git status` mostra esses 89 como "M" apenas por aviso de fim de linha
  (autocrlf); `git diff` não tem conteúdo e eles **não entram no commit**.
- Rasterização e leitura de todos os 28 no Godot 4.7.2 (`Image.load_svg_from_string`): 0 falhas; revisão visual na
  prancha. Não rodei `tools/verify.ps1` (nenhum runtime tocado; entrega só de arte vetorial e ferramenta).

## Limitações e achados
1. **`--check` já falhava na base.** O `ClassCatalog` tem 4 skills sem ícone, anteriores ao E09:
   `berserker_deep_bleeding`, `berserker_pursuit_cut`, `defender_retreat_guard`, `defender_riposte`
   (93 IDs no catálogo × 89 motivos). Como são fora do escopo das 28, o gerador os trata como lacuna conhecida
   (`PENDING_ICON_IDS`): imprime a lista em toda execução e não gera ícone. **Decisão para a arquitetura:** gerar
   esses 4 num próximo lote ou confirmar que a UI usa fallback. Se T1/K1–K4 passarem a registrar os 28 no catálogo, nada
   muda (a lista explícita é uma união).
2. `Godot_v4.7.2-stable_win64_console.exe` falha aqui com `CreateProcess error 193`; usei o
   `Godot_v4.7.2-stable_win64.exe --headless`. O `--import` do projeto inteiro regravou centenas de `.import`
   alheios e criou `.uid`; descartei tudo (restaurei os rastreados e apaguei os gerados) e mantive só os 28 novos.
   Quem importar de novo deve fazê-lo fora do repositório ou descartar o excedente.
3. Os `.svg.import` novos trazem `uid` gerado nesta worktree; nada os referencia ainda.
4. Os ícones pintados continuam na fila de geração; substituem o SVG pelo mesmo ID.
5. `Refração`, `Salto Prismático` e `Espectro de Prisma` são os mais abstratos; leem melhor ampliados (40 px é o limite).
