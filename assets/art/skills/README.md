

## Ícones de habilidades E06

Lote original de 89 símbolos vetoriais em 64×64, gerados por `tools/prepare_skill_icons.py`. A API de runtime consome `res://assets/art/skills/<skill_id>.svg`. Cada asset usa fundo e silhueta em duas cores; passivas usam contorno. Motivos são desenhados por primitivas SVG e diferenciados por skill e classe.

`manifest.json` registra ID, categoria, classe, paleta e SHA-256 do conteúdo SVG. Para reproduzir, execute o gerador na raiz do repositório; `--check` confere catálogo e cobertura sem gravar. Os IDs vêm do ClassCatalog e das listas Sentinel/Hunter; os IDs de ItemSkillAdapters reutilizam os motivos catalogados.
