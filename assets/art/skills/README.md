

## Ícones de habilidades E06

Lote original de 89 símbolos vetoriais em 64×64, gerados por `tools/prepare_skill_icons.py`. A API de runtime consome `res://assets/art/skills/<skill_id>.svg`. Cada asset usa fundo e silhueta em duas cores; passivas usam contorno. Motivos são desenhados por primitivas SVG e diferenciados por skill e classe.

`manifest.json` registra ID, categoria, classe, paleta e SHA-256 do conteúdo SVG. Para reproduzir, execute o gerador na raiz do repositório; `--check` confere catálogo e cobertura sem gravar. Os IDs vêm do ClassCatalog e das listas Sentinel/Hunter; os IDs de ItemSkillAdapters reutilizam os motivos catalogados.

## Ícones das híbridas E09

28 ícones SVG 64×64 das quatro híbridas (Paladino `paladin_`, Taumaturgo `thaumaturge_`, Duelista `duelist_`, Lâmina Arcana `arcane_blade_`; IDs do contrato `docs/epics/e09_contract.md`), gerados pelo mesmo script. Paletas de duas cores por classe, a partir das fichas; passivas com contorno. Enquanto o `ClassCatalog` não registra essas skills, o gerador e o `--check` as cobrem pela lista explícita `HYBRID_SKILLS`. Um ícone pintado que vier depois substitui o SVG pelo mesmo ID. Prancha de revisão: `docs/epics/e09/t3_icons_review.png`.
