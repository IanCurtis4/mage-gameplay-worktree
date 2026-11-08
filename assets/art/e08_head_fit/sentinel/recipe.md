# Receita — cabelo base Sentinela

Quatro folhas 4×4 de imagegen integrado removem o capuz cinza-verde; cada entrada foi uma ampliação mecânica 4× da vista original. Prompts, referências e hashes em `provenance.json`. Duas proteções de rosto foram reduzidas nas poses de dano laterais porque preservavam a faixa do capuz; o rosto abaixo do corte permanece original.

Reproduzir com `python tools/prepare_e08_bare_head_body.py sentinel`. O compositor valida o RGBA original, recorta e normaliza as fontes, aplica regiões/proteções/offsets autorados por pose em `calibration.json` e grava body 256×1024, pivô (32,58). A calibração registra âncoras e ângulos de cabeça; o corpo original e seu manifesto não são alterados. RGBA da variante `2f417e4b2cd1e75d53750543c70b45b74ba8194df0e452fa1fde3112bc0a5cc6`.

Verificação offline confirmou 64 grounds, pixels fora das máscaras e 112 recortes de dedos vivos byte idênticos, além de reprodução PNG idêntica. `contact_sheet.png` compara cabelo/elmo/maçã/ovo, quatro vistas e repouso/dano/mortes em 1× e 4×. A composição é aproximada; ângulos de morte e abertura da peça, oclusão e posição de olhos ainda exigem prova no renderer real.
