# Receita — cabelo base do Mago

Quatro folhas 4×4 de imagegen integrado removem o chapéu do atlas existente; cada entrada de geração foi uma ampliação mecânica 4× da vista correspondente. Prompt integral, referências e SHA-256 das fontes em `provenance.json`.

Executar `python tools/prepare_e08_mage_bare_head.py`. A ferramenta verifica o RGBA canônico do corpo original, normaliza cada folha a células64×64, aplica deslocamentos registrados e copia apenas as regiões da cabeça listadas em `calibration.json`, excluindo proteções de mãos, dedos, braços levantados e trechos de rosto. Cada pose registra âncora e ângulo para cabeça. A variante tem pivô (32,58) e tamanho 256×1024; o corpo original permanece externo e intacto. RGBA canônico da variante: `ce94ffabe8c1dcd02538bf5264584a916ef7a54b098fbb90eaffe547685e63f8`.

O produtor confere 64 limites de chão, alterações fora da máscara e igualdade byte a byte dos 112 recortes de dedos vivos. `contact_sheet.png` é uma composição offline aproximada dos três acessórios disponíveis, nas quatro vistas e em repouso/queda/cadáver, com 1× e 4×; não substitui o renderer real nem estabelece o tamanho final do acessório.
