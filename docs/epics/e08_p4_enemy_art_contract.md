# P4 — corpos de inimigos em quatro vistas

7/11/2026. Mesmo pedido autorizado quatro direções personagens/inimigos,
[contrato produtor](e08_p4_directional_contract.md), sem espécie/AI/loot/stats novas.
Base94d68c98cf1d9e93de23e184cfdf0fd62f85d8ab,codex/e08,.tools/map-editor-m5.
Este documento/listas/tool precisa commitversionado e SHA no dispatch antes escrita.
Root é dono do wrapper novo; artista Terra6.1médio assume uma lista EXATA porvez,
sem editar wrapper/frozeninputs/engine/fixture/runtime/testes/consumidores.
Não iniciar todos só por existir reserva. Não criar chat ou iniciarP5.

NPCs existentes são warrior,beast_master,gel,animal_companion e overrides
forestwolf/boar; archer é corpo compartilhado e vem da fatia jogador separada.
Inventário fontes/consumidores em e08_evidence/p4_sol/baseline_inventory.json.
Nomes visual_id/actor_kind e caminho source em cada e08_p4_enemy_<id>_files.json.
Direção estética por visual_id:

- warrior: combatente de cabelo/vermelho e lenço rubro, couro escuro, espada e escudo redondo já embutidos no NPC.
- beast_master: humanoide de capuz verde, couro e arco já embutido; manter identidade original, sem bicho novo.
- gel: geleia dourada redonda com duas folhas verdes, rosto amigável e compressão/alongamento gelatinoso.
- animal_companion: pequena raposa/fennec creme com orelhas grandes e cauda, familiar existente.
- e08_forest_wolf: lobo cinza quadrúpede do piloto, focinho/orelhas/cauda e pelo cinza atuais; não usar raposa retintada.
- e08_forest_boar: javali marrom quadrúpede robusto com presas curtas e cerdas, original do piloto; não usar lobo retintado.

Preservar S/N32células nativas byte a byte, mapeamento padrão:
S:[0,1,2,3,4,5,6,7,8,9,10,11,24,25,28,29];
N:[16,17,18,19,12,13,14,15,20,21,22,23,26,27,30,31].
Equipamento embutido original de NPC warrior/beast_master é intencional, diferente
do corpo jogável weaponless. Não remover suas armas sem consumidor equivalente.
E/Wnovos próprios4x4: idle4,walk4,ataque4,hurt2,death2. Lateral real/não espelho
frontal; quatro patas/coerência de focinho/cauda para animais, gel em perfil com
folhas/rosto/emissão coerentes; não inventar bola de fogo, efeito ou poder.
Tamanho lateral ajustado ao corpo nativo: target_height é mediana das4idleS
nativas, não50fixo para gel. Respeitar largura58/altura56/pivô32,58; produtor
mecânico estável faz crop/matte/packing. IA/colisão permanece igual ao corpoantes.

Aplicar ragrpg-art/imagegenintegrado, inspecionar fontes primeiro; preservar
fontes/prompts/hashes. Só imagem raster autorada, nenhuma síntese procedural.
Overrides v2/v3 por pose afetada, preservar15demais selecionadas, fontesnativas
intactas. Recipe usa visual_id,actor_kind,viewsSouth/North nativas eE/Wfontes.
Wrapper tools/prepare_e08_enemy_directional_art.py é SOMENTE empacotamento de
build_unit existente: nenhuma fórmula/AI/arte inventada. Body256x1024,64frames.
Manifest weaponless:null, pois estas6identidades NÃO equipam arma/capacete via
slots. Metadata de slots não usados/heads invisible é constante de formato e não
alega palmas/crânios autorados.64grounds medidos do raster e hashRGBA canônico.
Não oferecer equipment_visual nesses NPCs para fingir rig real inexistente.

Entregar unidadecompleta body/recipe/manifest/calibration/provenance/delivery,
32nativas exatas/4blocos distintos/64grounds/reprodução, fontes e prompts.
NãoGodot/import/commit/fixture/runtime/testes/outrosarquivos, usar
PYTHONDONTWRITEBYTECODE=1. Devolver posse explícita Root. Arteficastaging
assets/art/e08_enemies/directional/<visual_id>, fora descoberta automática.

Root/Sol integra depois, default para4basekinds; overrideswolf/boar via chamada
explícita set_directional_manifest comactor_kindanimal_companion. Preservar
ocorrênciaswolf/boar e fallbackV1 completo por ocorrência, nunca trocarjavali
porraposa/lobo genérico. Archer inimigo usa arco comconsumer autorizadoseparado
quandoV2weaponlesssharedativo, semnova arma/estado. Sem alterações de população.

Provas posteriores: nativo64poses/direções/diagonal/morte/chão/oclusão/zoom,
consumidores MobDefinition reais e overrides, export/restorecold, custos96atores
V1/V2comparáveis, verifyporimpacto/Luna. Não alegar nativo/headlessPASS porPNG.
P4 permanece aberto enquanto identidades/consumidores estiverem pendentes.
