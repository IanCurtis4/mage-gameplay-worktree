# Sentinela direcional — receita

S/N usam 32 células nativas sem reamostragem. E usa v2 com overrides de pose9 v4 e pose10 v3; W usa v1 com override de pose7 v2. A fonte E v1 foi preservada mas não selecionada pois retornou grade maior que 4×4. Prompts e hashes constam em provenance.json.

Preparar offline: `PYTHONDONTWRITEBYTECODE=1 python tools/prepare_e08_directional_art.py sentinel`. O manifesto exige hash RGBA da calibração; body e weaponless são iguais sem props.
