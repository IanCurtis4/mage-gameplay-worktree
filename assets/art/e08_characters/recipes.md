# E08 P4 — receita exploratória da Espiritualista

`python tools/prepare_e08_characters.py` lê apenas `spiritualist_source.png`, divide a folha 4×8 em duas metades e usa `tools/prepare_animation_assets.py` em uma pasta temporária; grava somente `docs/epics/e08_evidence/p4/spiritualist_candidate.png`. Não altera atlas de runtime nem fontes históricas. A origem, referências, prompt e hashes estão em `provenance.json`.

O resultado é uma candidata 256×512 com 32 células e pivô pretendido (32,58). Duas execuções produziram SHA256 `784e307c6c378bd48938bf0bc705c9e938fbe958a21209ea1b25c6aaf20b6963`. Isto não prova animação ou integração: os grips atuais falham em 24/56 posições de poses vivas nesta imagem, e a calibração/oclusão das mãos deve ser refeita e verificada no renderer com cada equipamento pertinente antes de qualquer promoção. A folha ainda não fornece vistas laterais selecionáveis.
