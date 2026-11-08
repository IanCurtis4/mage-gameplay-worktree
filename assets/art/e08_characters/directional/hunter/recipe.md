# Caçadora direcional — receita

S/N usam native_cleaned.png: 29 células originais sem reamostragem e mortes nativas 28/30/31 corrigidas por ImageGen. A fonte 2×2 foi normalizada pelo pipeline existente: bbox, altura e piso legados, LANCZOS, alpha128 e centralização x32. Célula29 original preservada. Fontes e hashes estão em provenance.json.

E usa v1 com overrides 6/7 v2; W usa v2 com overrides vivos 0–13 v3. Preparar offline: `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py hunter`. O manifesto só é produzido com o hash RGBA da calibração.

## Correção S15 — 8/11
A célula nativa29 foi corrigida após confirmação de arco sob o rosto; as 28
outras nativas e as mortes28/30/31 já limpas permanecem intactas. A fonte v2
é edição ImageGen da v1; usa-se exclusivamente o quadrante superior direito.
Extrair metade superior direita (627,0,1254,627), aplicar `remove_matte` e
`keep_character` da ferramenta existente, recortar bbox (32,269,579,554),
redimensionar LANCZOS para 58x31 (largura/altura do bbox legado29), alpha >=128,
centralizar x32 e assentar em y58: posição (3,27). Gravar somente native29 no
`native_cleaned.png`; as outras mortes continuam da v1. O original é somente leitura.
Em seguida executar o packer direcional com calibração/hash atualizado.
