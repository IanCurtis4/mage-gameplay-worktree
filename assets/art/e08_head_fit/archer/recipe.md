# Arqueiro — receita de cabelo sem capuz

Quatro folhas `*_source_v2.png` são extrações mecânicas do corpo original,
sem alterações, ampliadas 4x; as folhas `*_source_v1.png` são edições ImageGen
integrado das respectivas referências. A sequência de sufixos distingue entrada
e saída, não indica seleção de uma versão mais recente. Prompts e hashes em
`provenance.json`. O corpo original permanece somente leitura.

`calibration.json` define 64 recortes, proteções locais para dedos e aljava,
âncora e ângulo por pose. A composição substitui exclusivamente região de cabeça
com fonte correspondente. Reprodução: `PYTHONDONTWRITEBYTECODE=1 python
tools/prepare_e08_bare_head_body.py archer`; wrapper/compositor são somente leitura.
A folha de contato é composição offline aproximada, com nu/elmo/maçã/ovo em
quatro vistas e idle/hurt/duas mortes, 1x/4x. Os estudos não criam item/drop.
