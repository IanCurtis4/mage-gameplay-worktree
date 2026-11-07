# Espiritualista — fontes preliminares sul

Duas tentativas com imagegen integrado, referenciando `docs/epics/e08_evidence/p4/elementalist_spiritualist_concept.png` (linha inferior). Não são atlas de produção.

- `south_source_v1.png`: SHA-256 `ecdf35d5d94fb29733f5fd1372a3c39d3e56456048bfe471dcb6964fc19c2ac6`.
- `south_source_v2.png`: SHA-256 `2ed9b38d5774b8b590e580cd554ee07bc31d8ecc09362966350c23eebd84e4f7`.

Prompt v1: Use case: stylized-concept. Asset: production 2D game character animation sprite sheet. Reference image: use ONLY the silver-haired female spiritualist in the lower row as identity and pixel-art style reference. Create a 4 by 4 perfectly regular grid of 16 separate full-body sprites, all facing directly SOUTH/front, each centered within its own equal cell, generous transparent gap between sprites, no grid lines. Row 1: four subtle idle breathing poses. Row 2: four clearly different walk-cycle poses. Row 3: four ritual casting/action poses, empty hands. Row 4: two distinct hurt poses followed by two distinct collapsed death poses. Preserve the same silver hair and bun, asymmetric charcoal gray and silver layered ritual costume, blue eyes, proportions and lighting across all frames. Each living pose has two anatomically believable empty hands with visible fingers; no weapons, shields, objects, magical effects, shadows, captions or text. Pixel-art game sprites, consistent pixel scale, crisp edges. Genuine transparent background.

Prompt v2: Use case: precise-object-edit. Game animation source sheet. Revise image 1, retaining all 16 front-facing poses, consistent identity and regular 4x4 arrangement, matching lower-row silver-haired spiritualist of image 2. Fix both hands in EVERY living pose (rows 1–3 and first two cells of row 4): both empty hands fully visible, separated from clothing and each other, anatomically plausible fingers, suitable for placing separate weapons later. Ensure all sprites including fallen poses fit entirely inside their own cell without overlapping adjacent cells. Remove colored red/magenta fringe or shadows; preserve genuine transparent background. No props, text, magic, grid lines or ground. Keep crisp pixel art and same scale.

V2 usa v1 como imagem 1 e o conceito como imagem 2. A inspeção visual identificou que ambas as poses de dano não mostram as duas mãos e resíduos vermelhos/magenta permanecem nas bordas. Não há prova de transparência e recorte adequados em todas as células, nem calibração ou teste em jogo. Não foram geradas vistas norte/leste/oeste. Sem atlas, manifesto ou integração; preservadas para revisão e eventual retomada. Não se declara P4 concluído ou arte aceita.

## Continuação — diagnóstico e fontes adicionais

Sol examinou o alpha dos resíduos previamente apontados em v1/v2: alpha ≤5, sem pixels acima127. O limiar do produtor remove esses resíduos; a afirmação anterior de bordas coloridas visíveis não estava comprovada. A v3 sul corrige as duas poses de dano. Também foram geradas fontes independentes norte, leste e oeste, com ajustes direcionados na caminhada leste e dano oeste. Os prompts e SHA-256 das novas fontes estão em `provenance.json`.

Foi preparado atlas preliminar com escala global 0,17793594306049823, sem retinta/espelhamento, com cópia idêntica para body e weaponless. Inspeção ampliada revelou mãos com poucos pixels nos perfis; os 112 grips vivos e as 64 cabeças ainda exigem calibração e verificação em renderer. A propriedade de `calibration.json` e `presentation.json` foi transferida a Sol, que fará a calibração e a reprodução integral. O wrapper final exige esse arquivo e falha antes de gravar se ausente; essa falha foi verificada. O wrapper ainda não foi executado com calibração real. Sem importação, teste nativo, prova de equipamento ou aceite artístico nesta etapa.

## Correção da caminhada leste

Sol identificou três mãos na pose índice 6 de `east_source_v2.png`. Foi gerada `east_source_v3.png` por edição direcionada: a inspeção da fonte mostra duas mãos, uma atrás e outra à frente, com o braço central duplicado removido. Prompt integral e SHA-256 em `provenance.json`. A célula corrigida é candidata para seleção isolada por Sol; os demais quadros devem continuar da v2 devido a possível deriva da geração. Atlas, calibração e teste no renderer não foram alterados ou executados nesta correção.

## Consolidação Sol — 7/11/2026

Após o handback, Sol selecionou a correção isolada leste6 e autorou as64poses/
112grips vivos, dedos, cabeça e profundidade. Recortes/atlas foram reproduzidos
pelo wrapper, importados e copiados ao caminho direcional padrão da Espiritualista.
Conteúdo3.293checks, seleção21/17.440, nativo447/15PNGs e64frames de movimento
passaram; PCK3.293+814PASS. Provas e limites no recibo P4 artístico. A afirmação
preliminar de ausência de calibração/teste está superada por esta etapa Sol.
Não há aceite humano ou entrega do restante do elenco por efeito deste registro.
