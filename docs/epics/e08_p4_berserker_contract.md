# E08 P4 — Berserker direcional

7/11/2026. Continuação autorizada dos sprites definitivos P4. Base de API
0b8c962c1efde0c37962eb20aeb6df7c00570193, mesmo checkout codex/e08. O commit
ativo deste contrato será passado com SHA completo antes da escrita. Modelo
Terra6.1 médio; [arquivos exatos](e08_p4_berserker_files.json), só esses arquivos.
Sol integra outras identidades/renderer em arquivos separados; não tocar neles.

Preservar o desenho existente do Berserker: traje vermelho escuro/carvão, couro e ferro escuro, diagonais de uma evolução agressiva; sem inventar VFX, arma ou kit. Inspecionar
atlas/fonte e hand_rigs atuais. As duas laterais novas devem manter essa mesma
identidade, e não ser uma versão retintada do Mago ou de outra classe.
Aplicar ragrpg-art e imagegen integrado, transparência real, fontes e prompts
com hashes. E/W em4×4: idle4,walk4,ação/golpe4,hurt2,death2; gestos adequados à
classe, mãos/luvas vazias para props separados, dois braços apenas, dano e
morte de perfil coerentes. Não espelhar uma vista nem adicionar VFX/itens/skills.

Preservar S/N byte a byte de berserker_weaponless.png sem reamostragem:
S:[0,1,2,3,4,5,6,7,8,9,10,11,24,25,28,29].
N:[16,17,18,19,12,13,14,15,20,21,22,23,26,27,30,31].
Recipe de tools/prepare_e08_directional_art.py somente leitura:
actor_kind berserker, target_height50; views.south/north {source:
res://assets/art/animations/berserker_weaponless.png,native_cells:true,grid:[4,8],
indices:...}; east/west source local PNG4×4 e overrides opcionais por pose.
Modo --atlas-only prepara para autoria; padrão exige calibration.json com
actor_kind,authored_rgba_sha256 e64frames no schema do produtor. Atlas256×1024,
64células64×64, pivô32,58. Body/weaponless iguais intencionalmente sem props.

Calibração faz parte da unidade: palmas/crops S/N remapeados de hand_rigs.json,
mão principal e ângulos/depth legados conservados. E/W56grips vivos autorados
nas luvas/palmas reais;112grips vivos no total e64heads. Conferir source/raster
ampliado e alpha em ambos corpos; não escolher roupa opaca como mão. Head.flip
é toggle adicional ao mirror automático oeste: false para capacete normal
inclusive W; slots de arma têm flip local independente. Itens mortos serão
apoiados no chão pelo renderer como V1; dados conservam X/ângulos autorados.

Somente geração/preparação offline, PYTHONDONTWRITEBYTECODE=1. Sem alterar
ferramenta compartilhada, runtime, testes, fixture, outros conjuntos ou docs
alheios. Não Godot/importação/commit/chat/automação. Pedir ajuda por defeito
concreto, preservar fontes e continuar partes independentes; não encerrar com
toda calibração faltando. Entregar atlas+manifesto+calibração/receita/proveniência/
delivery, conferir32células nativas e112grips, devolver posse explicitamente a
Root para posterior handoff Sol. Staging não é produto aceito/P4 completo;
P5/master/push fora do escopo, habitual e saves preservados.
