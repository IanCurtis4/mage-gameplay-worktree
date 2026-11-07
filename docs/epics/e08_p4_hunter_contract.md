# E08 P4 — Caçadora direcional

Continuação dos sprites definitivos autorizados em7/11. Base executável de API
276efa9e6313a4d6bbef823adcf83a60f0f2f20f, branch codex/e08, checkout fixo .tools/map-editor-m5.
Terra6.1 médio, lista exclusiva e08_p4_hunter_files.json; dispatch passará SHA
versionado antes da escrita. Root/Sol têm outros arquivos/fixture, só leitura.

Identidade: Cabelo claro, capuz verde oliva e marrom, couro de viagem e detalhes vegetais; preservar identidade feminina e aljava de traje, sem arco embutido.
Aplicar ragrpg-art e imagegen integrado, transparência real, fontes/prompts/hashes
preservados. Inspecionar atlas e fontes antes de editar; não redesenhar por código.
Criar E/W independentes em4x4: idle4,walk4,ação4,hurt2,death2, duas mãos vazias
anatomicamente justificáveis, sem arma/escudo/VFX novos. Corrigir defeito localizado
com v2/v3 selecionando só célula afetada, sem troca involuntária das15demais.
Não aceitar o mesmo punho como duas palmas verificadas; oclusão real parcial
precisa ser declarada e posteriormente demonstrada com anexos no renderer.

Manter S/N byte a byte de hunter_weaponless.png:
S:[0,1,2,3,4,5,6,7,8,9,10,11,24,25,28,29].
N:[16,17,18,19,12,13,14,15,20,21,22,23,26,27,30,31].
Antes da cópia, inspecionar especialmente mãos/pose de morte para arma residual
no raster legado; comunicar defeito concreto a Root antes de preservar defeito.
Não alterar células nativas por inferência. Fonte original sempre permanece.

Packer estável tools/prepare_e08_directional_art.py somente leitura:
actor_kind hunter, target_height50; native_cells true grid[4,8] S/N;
E/W source local4x4+overrides por pose. --atlas-only prepara autoria; padrão
requer calibration64frames+authored_rgba_sha256. Atlas256x1024, pivô32,58;
body/weaponless iguais sem props. S/N rigs transpostos de hand_rigs.json,
conservar main/off/crops e orientação legada; E/W56grips vivos no pixel de palma
real.112grips vivos em ambos corpos,64heads com crânio próprio nas mortes.
Head.flip é toggle extra: false inclusiveW para capacete normal. Morte8frames:
slots depth0, ângulos absolutos PI/2 para itens soltos (contas0), sem overrides
vivos que os deixem verticais; chão é resolvido pelo renderer V2 já corrigido.
Não mudar X/clock/AI/regras ou campos persistidos para acomodar arte.

Exclusivamente geração e preparação offline, PYTHONDONTWRITEBYTECODE=1;
sem Godot/importação/commit/fixture/runtime/tests/globals ou ferramentas comuns.
Entregar arquivos completos+recipe/provenance/delivery, conferência32nativas e
112grips/64heads, hashRGBA, limitações. Devolver posse explicitamente. Root/Sol
integra e testa nativo/export, incluindo equipamento/zoom/retrato/mundo. Staging
não equivale a aceite ou P4 concluído. P5/master/push/save pessoal fora do escopo.

## Correção delimitada de morte após inspeção —7/11

Terra identificou arco residual nativo28,30,31; Root autoriza correção localizada
imagegen nessas3células da mesma unidade. Manter29 e28demais byte a byte (29/32
nativas preservadas), salvo prova concreta adicional comunicada. Fontes nativas
originais nunca mudam. Criar native_death_source_v1..v3 e native_cleaned.png256x512
no staging próprio; copiar29células intactas e substituir3por crops normalizados
da nova arte sem arco via pipeline mecânico atual. Nada de apagar/desenhar por
código. Recipe S/N usa cleaned com native_cells; calibrar3heads/grounds alterados,
meta mortos soltos ehashesderived. Não recompensar defeito comafirmação32/32.
É correção de defeito no contrato atual, semnovo consumidor/kit/loop/arma.
