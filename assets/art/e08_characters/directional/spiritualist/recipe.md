# Receita — Espiritualista direcional em staging

Fontes selecionadas: sul v3, norte v1, leste v2 e oeste v2; referências, prompts e hashes em `provenance.json` e histórico sul em `delivery.md`. Cada prancha fornece 16 poses, na ordem idle4, walk4, action4, hurt2, death2. As vistas são gerações independentes, sem espelhamento.

`tools/prepare_e08_spiritualist_directional.py` utiliza as funções `remove_matte` e `keep_character` do produtor histórico; recorta mecanicamente as células 4×4, usa um único fator de escala (0,17793594306049823 na montagem preliminar), reamostra e aplica alpha binário. O atlas tem 256×1024, células 64×64 e pés alinhados ao pivô (32,58). O corpo sem arma incorporada e weaponless são cópias idênticas em arquivos separados. O wrapper lê `calibration.json` autorado, exige 64 poses e gera o manifesto com hash RGBA canônico. Com calibração ausente, encerra antes de gravar atlas ou manifesto. Não produz a calibração automaticamente.

Execução offline, após a calibração: `python tools/prepare_e08_spiritualist_directional.py`. A geração usa Pillow e numpy. A calibração e a prova no renderer são responsabilidade de Sol; esse procedimento não constitui aceite artístico ou P4 concluído.

## Receita consolidada por Sol

Selecionada somente a célula leste pose6 da fonte v3, substituindo a mão/braço
duplicado da v2; demais15células leste continuam da v2. Demais vistas: sulv3,
nortev1,oestev2. Escala global0,17793594306049823 e centro da célula/pés58;
não ancorar ao pé mais baixo alternado na caminhada de perfil. O ensaio com
âncora de cor de bota deslocava o tronco e foi descartado antes de validar.

Modo --atlas-only é preparação explícita para autoria e não emite manifesto.
Execução padrão exige hashRGBA autorado e ground_y por pose na calibração,
interrompe se o raster mudou. Duas reproduções finais devem conservar bytes de
body/weaponless/presentation. Body e weaponless têm pixels iguais porque esta
unidade não incorpora arma; runtime usa cópia com caminhos no diretório padrão.
Frames de mãos e cabeça foram calibrados por Sol e conferidos no renderer,
inclusive o capacete nas poses de morte. Narrativas preliminares acima são
histórico, não estado vigente. Resultado técnico: docs/epics/e08_p4_art_delivery.md.
