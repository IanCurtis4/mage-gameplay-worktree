# Caçadora direcional — receita

S/N usam native_cleaned.png: 29 células originais sem reamostragem e mortes nativas 28/30/31 corrigidas por ImageGen. A fonte 2×2 foi normalizada pelo pipeline existente: bbox, altura e piso legados, LANCZOS, alpha128 e centralização x32. Célula29 original preservada. Fontes e hashes estão em provenance.json.

E usa v1 com overrides 6/7 v2; W usa v2 com overrides vivos 0–13 v3. Preparar offline: `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py hunter`. O manifesto só é produzido com o hash RGBA da calibração.
