# E08 P4 — Espadachim, laterais próprias e vistas existentes preservadas

7/11/2026. Continuação autorizada da produção de sprites definitivos P4.
Base6beb01cb4cd03d6e6133e7ac2a961aa151020875, mesmo checkout codex/e08.
A primeira Espiritualista foi consolidada; Elementalista e Mago estão sob Sol
em staging. Correção Sol de itens V2 na morte está em trabalho separado, sem
alterar o schema artístico ou os inputs desta produção. Arquivos exatos:
[e08_p4_swordsman_files.json](e08_p4_swordsman_files.json). Terra6.1 médio.

Preservar a identidade atual: cabelo castanho, túnica azul/teal e creme,
proteção simples de aço no ombro, couro marrom. Inspecionar fonte/atlas de
Espadachim e não redesenhar como Mago/Elementalista. Sem novo kit/VFX/item/skill.
Aplicar ragrpg-art e imagegen integrado; fontes transparentes/prompt/hashes
preservados. Gerar somente E/W4×4: idle4,walk4,ação de golpe4,hurt2,death2.
Mãos vazias prontas para arma separada, anatomia de dois braços, perfis reais,
traje/escala/luz consistentes. Não espelhar nem retintar frente para produzir lado.

S/N copiados byte a byte de swordsman_weaponless.png, sem reamostragem:
S:[0,1,2,3,4,5,6,7,8,9,10,11,24,25,28,29].
N:[16,17,18,19,12,13,14,15,20,21,22,23,26,27,30,31].
Recipe da ferramenta genérica readonly: actor_kind swordsman,target_height50,
views.south/north {source:res://assets/art/animations/swordsman_weaponless.png,
native_cells:true,grid:[4,8],indices:...}; views.east/west source PNG local4×4,
overrides por pose para selecionar correção sem trocar quadros bons.

Usar tools/prepare_e08_directional_art.py swordsman --atlas-only para autoria;
padrão exige calibration.json com actor_kind,authored_rgba_sha256,frames64 no
schema produtor. Atlas256×1024,64células64×64,pivô32,58. Dois corpos sem arma
embutida em paths distintos; arma real continua anexo do equipamento.

Conservar S/N palmas/crops do hand_rigs.json remapeados e orientação legada,
respeitando o main do desenho existente. Autor E/W56grips vivos nas palmas,
cranium/head, dedos/depth/ângulos/flip em todas64poses. head.flip é toggle
ADICIONAL ao espelhamento automático oeste: para capacete normal false também
no oeste; slots de arma têm mirror local independente. Itens mortos serão
apoiados no chão pelo produtor como V1, conservando X/ângulos; não tentar
simular por um Y universal de palma que atravesse o piso. Sol validará isso.

Não editar outros conjuntos/ferramentas/runtime/testes/fixture/índices. Nenhum
Godot/importação/commit/chat/automação. Executar só geração/preparação offline,
conferir32células nativas e112grips vivos em ambos atlas. Pedir diagnóstico de
defeito real persistente, sem encerrar com toda calibração faltando. Devolver
posse explícita com fontes/receita/calibração/atlas/manifesto/delivery completos.
Staging não é produto aceito/P4 inteiro; P5/master/push fora do escopo.
