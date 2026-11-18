# E10a · T3 — 22 ícones SVG da família Acólito · recibo

**Base:** `6938db71dc6bd56cce2658bcfbe7af956849ab8c` · **branch:** `claude/e10a-t3-4515a9` ·
**checkout:** `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.claude/worktrees/e10a-t3-4515a9` ·
**commit entregue:** o commit que contém este recibo (`git log -1` na branch). Sem push, sem `master`, sem `codex/playtest`.

## Entregue
- 22 SVG 64×64 em `assets/art/skills/<id>.svg` (8 `acolyte_`, 7 `priest_`, 7 `cultist_`), mesma grade, traço e
  conjunto de molduras dos atuais; 6 passivas com contorno (`acolyte_devotion`, `acolyte_protective_faith`,
  `priest_grace`, `priest_exorcist`, `cultist_ecstasy`, `cultist_open_pupil`).
- `tools/prepare_skill_icons.py`: `E10A_SKILLS`/`E10A_SHAPES`, três paletas, molduras novas; `--check` confere por lista
  exata E09=28 + E10a=22 = **50** (falha se uma lista não tiver o tamanho certo, repetir ID, sobrepor a outra ou faltar no manifesto).
- `manifest.json`: 139 entradas (117 + 22) com SHA-256; `README.md` ganhou a seção E10a (gerada pelo script).
- 22 `.svg.import`, **versionados**, porque o precedente do E09 os versiona (os 210 `.import` atuais estão no Git). Não importei o
  projeto no Godot: gerei-os do modelo de `paladin_oath.svg.import`, com o caminho `.ctex` pelo MD5 do caminho `res://` (fórmula conferida
  contra o arquivo existente) e `uid` determinístico a partir do ID (sem colisão com os `uid://` do repositório).
  Se o Godot regravar o `uid`, é inofensivo (nada os referencia ainda).
- Prancha: `docs/epics/e10a/t3_icons_review.png` (22 ampliados a 192 px e nos tamanhos de 64 px e 40 px), rasterizada pelo
  Godot 4.7.2 (`Image.load_svg_from_string`, 0 falhas) num projeto vazio fora do repositório.

## Paletas e motivos
| Classe | Fundo | Silhueta | Acento | Moldura |
|---|---|---|---|---|
| Acólito | `#3d2a52` ameixa | `#f0cf7f` dourado | — | ladrilho dividido ao meio com as cores trocadas: esquerda dourado sobre ameixa (luz), direita ameixa sobre dourado (sombra) |
| Sacerdote | `#315f95` azul-céu | `#f6efd9` marfim | `#e8cf85` dourado pálido | disco com aro fechado (ativas); passivas no quadrado com filete dourado |
| Cultista | `#0c1426` preto-azulado | `#e64fc3` magenta | `#35d6c6` turquesa | ladrilho de lados côncavos com contorno turquesa |

O acento é um terceiro tom só da moldura (os ícones atuais têm duas cores); o glifo segue numa cor sobre o fundo.
- Acólito: `punishing_light` raio com rastro · `prayer` mãos em prece · `votive_shield` escudo com chama · `shadow_seal` aro com crescente ·
  `disturbing_whisper` cone com ondas · `eldritch_vision` olho com linha pontilhada até um alvo · `devotion` sol e lua com arcos de alternância ·
  `protective_faith` arco com cruz.
- Sacerdote: `sanctuary` figura sobre círculos no chão · `grace` pilha de halos · `aegis` figura em aro fechado com aro tracejado ·
  `judgment` seta de luz caindo sobre o aro do alvo · `exorcist` escudo rachado pela luz · `light_seal` duas meias-luas se fechando sobre um losango ·
  `holy_hour` círculo ampliado e estrela de oito pontas.
- Cultista: `abyss_gaze` olho com pupila em espiral aberta e gotejando · `ecstasy` aro aberto com olhos e sorriso largo ·
  `impossible_idol` estela com um olho · `shared_delirium` três olhos ligados · `open_pupil` olho com pupila dilatada e fendas ·
  `impossible_geometry` espiral quadrada aberta · `revelation` explosão em estrela com olho central.

## Validação
- `python tools/prepare_skill_icons.py --check` → `kit IDs checked by exact list: E09=28 E10a=22 total=50`, `139 icons; active=104; passive=35`, exit 0.
  O gerador roda 2× sem diferença; as 117 entradas anteriores do manifesto continuam idênticas campo a campo.
- Prancha conferida por mim (imagem aberta): 22 distintos entre si e dos 117 anteriores (checagem de motivos únicos do gerador) e legíveis em 64 px;
  a 40 px os mais densos (`sanctuary`, `aegis`, `shared_delirium`, `impossible_geometry`) viram forma e cor, mas ainda se distinguem.
- A suíte de gameplay (`tools/verify.ps1`) **não foi executada**: nenhum runtime foi tocado (só arte vetorial, manifesto e ferramenta).

## SHA-256
Prancha `t3_icons_review.png`: `a5c4bb1935573b1c032fb74c3219897e5b3e29b1618fa0c968cbdf3a5165dbb8`.

| ID | Tipo | SHA-256 do SVG |
|---|---|---|
| `acolyte_punishing_light` | active | `2f6f5a07a7011e7e14a8b05a9c822e38e0910c38bb96fc33a5d16290826d4e97` |
| `acolyte_prayer` | active | `0894b9806591e368c5c05c8236070081b01249e149b71ca8f021a17fb8532e8c` |
| `acolyte_votive_shield` | active | `5271b9afcc69ee84e965fa9a3ca3ccecb029e466a34c8ad07877d8f51a6b8362` |
| `acolyte_shadow_seal` | active | `f28e2eeebd69928a0f62f640b0eb8314af385daec7f81ce9beebd4a35cf529f2` |
| `acolyte_disturbing_whisper` | active | `48c53becd1ea3f6bc8b28b5a70dd426924f4a3be21189c58ad3256475d83bb98` |
| `acolyte_eldritch_vision` | active | `a0ba3ae0d99b2aa83b039b623590948045db2e314d1e9c0463264f052553e92a` |
| `acolyte_devotion` | passive | `dfd8df201f81b13cc2811ac7180cebcea695b4a948ce7160d7ecc6cc87d8a6c2` |
| `acolyte_protective_faith` | passive | `1bcf335e1b518aa6b865df6cd07f394b05e494938c2509b68969aaff6ad3fc47` |
| `priest_sanctuary` | active | `056fca28c435de1f53c2bc62a3f20fd4ddd7a7a589e25cba90871b226742a89e` |
| `priest_grace` | passive | `7a4f7766b6860dcad1f99b7993b02e1189b4965852046ec0831af56042f076c6` |
| `priest_aegis` | active | `2b7f6ef74bb790ba7a7cacae7a4c6d0a9d315e27302cdca752b32604ebfbb610` |
| `priest_judgment` | active | `01edbd60ab591db86cff90c4f05f262c847d221f5e212ba526fdaa6d40bde0a5` |
| `priest_exorcist` | passive | `4105bb8c4bf10d5c12b1cf5a2c4d4a5a4209d46192ed6c9c3c91b317b601423b` |
| `priest_light_seal` | active | `ab00396723a8b7a5ed1a9ff89256840498e58a060c54b78fa1266d738c84808d` |
| `priest_holy_hour` | active | `501097dd9b19129cb335a71ff1fd8a2b852163a045dddeb713c6bba95ad7e626` |
| `cultist_abyss_gaze` | active | `611109d2affd2bbac9becaa8e651e36e8b90cdb8b7e089cc308e1f7cfdead076` |
| `cultist_ecstasy` | passive | `3b06d681885477ab7397764a052a34ebafe3cca7719494dc1f79ae0291a87aef` |
| `cultist_impossible_idol` | active | `afbabc7c80846d0086354bc6166ed47e0aa2bedb9ae629e05b37f759273dc664` |
| `cultist_shared_delirium` | active | `07414ecc8540c3a9eec691e9e72614b6db158732b64c66be55393712b194a8f0` |
| `cultist_open_pupil` | passive | `e387e8282b2963169208defce0a5b9a0659587f153d4b8294a97512b447d2af2` |
| `cultist_impossible_geometry` | active | `cfb07aebd5b193edd725b742e65f69b5df17727fe37b206ae55354d633dd8e24` |
| `cultist_revelation` | active | `2b4ca3b7147ee1bb77c44b553a0d5a824ef9eea8c872d0fab018aed0d3d71657` |

## Limitações
1. Nomes de skill e IDs são os provisórios do contrato; os módulos T5–T7 os referenciam por ID e nada neste commit os consome.
2. O `git status` da worktree mostra os 117 SVG antigos como "M" só por aviso de fim de linha (autocrlf); não têm diff e não entraram no commit.
3. Os `.svg.import` novos têm `uid` calculado, não gerado pelo Godot; ver acima.
4. As 4 skills antigas sem ícone (`PENDING_ICON_IDS`) continuam fora do escopo.
5. Ícones pintados ficam na fila de geração e substituem o SVG pelo mesmo ID em `painted/<id>.png`.
