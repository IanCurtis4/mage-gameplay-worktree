# Mago — cabelo base em staging

A variante remove o chapéu fixo nas 64 poses usando quatro fontes geradas independentemente. O corpo original é copiado fora das regiões e proteções autoradas; fonte, prompt e hashes estão em `provenance.json`. A reprodução offline confere o original, os 64 limites de chão e a igualdade dos 112 recortes de dedos vivos; RGBA canônico da variante `ce94ffabe8c1dcd02538bf5264584a916ef7a54b098fbb90eaffe547685e63f8`.

`calibration.json` registra por pose região, proteções, deslocamento, âncora craniana e ângulo. A folha de contato compara cabelo, elmo piloto, maçã e ovo nas quatro vistas e em repouso/queda/cadáver, em 1× e 4×. É composição estática aproximada: o encaixe de acessórios, bordas de cabelo/rosto e oclusão dos braços precisam ser conferidos no renderer nativo antes de integração ou aceite. Não foram executados Godot, importação, fixture nem gameplay. O produtor não altera o manifesto nem a seleção do Mago original.
