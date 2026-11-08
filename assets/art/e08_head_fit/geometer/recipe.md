# Receita — cabelo base Geômetra

Quatro folhas 4×4 de imagegen integrado removem o capuz azul-violeta; cada entrada foi uma ampliação mecânica 4× da vista original. A fonte sul v2 remove faixa residual; norte v2 contribui apenas a pose 15, para distinguir cabelo da roupa. Prompts, referências e hashes em `provenance.json`; fontes por pose em `calibration.json`.

Reproduzir: `python tools/prepare_e08_bare_head_body.py geometer`. O compositor valida o RGBA original, recorta e normaliza fontes e aplica regiões, proteções e deslocamentos autorados por pose; body 256×1024, pivô (32,58). Âncoras cranianas e ângulos por pose constam da calibração. O corpo e manifesto originais não são alterados. RGBA da variante `6f9b3212a701b779d6c8553810965c008c63145b5e4879173fad457985efe8a8`.

A verificação offline confirmou 64 grounds, pixels fora das máscaras e 112 crops de dedos vivos byte idênticos; repetição gerou PNG idêntico. `contact_sheet.png` é composição aproximada de cabelo/elmo/maçã/ovo, quatro vistas e repouso/dano/mortes em 1× e 4×. Não substitui renderer: conferir olhos, costuras, braços e orientação dos acessórios em mortes.
