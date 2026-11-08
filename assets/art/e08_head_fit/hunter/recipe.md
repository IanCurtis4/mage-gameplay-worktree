# Caçadora — base de cabelo

As quatro fontes ImageGen integradas removem o capuz em folhas extraídas mecanicamente do atlas original. Prompts e hashes em provenance.json. `calibration.json` define por pose a fonte, região de cabeça, proteções, âncora e ângulo; S15 protege aljava e as máscaras preservam recortes de dedos. A fonte do corpo original não é alterada.

Reproduzir com `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_bare_head_body.py hunter`. O compositor confere hash original, 64 limites de chão, pixels fora das regiões e 112 crops vivos. A prancha de contato é composição aproximada offline em 1×/4×, não prova nativa.

S15 após 8/11: região [27,20,64,52] deixa o corpo limpo visível sob a cabeça;
o restante da calibração e das fontes foi preservado. A prancha atual compara
as quatro mortes em 1x/3x e não substitui a prova de equipamento no renderer.
