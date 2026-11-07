# E08 — P4 Personagens

6/11/2026. [Aceite humano P3 e autorização P4](e08_p3_product_acceptance.md).
Executor Terra 6.1, esforço médio, chat próprio P4 conforme plano aprovado.
Base executável/documental recebida: b6cd0184062fbf1c6b0288773ef0344ebd316b1b.
Checkout exclusivo C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5,
branch codex/e08. O commit documental de dispatch será passado com SHA completo.
Principal codex/playtest, suas alterações e saves pessoais ficam preservados.
Quatro .bak sanctuary_woods não pertencem ao pacote.

## Resultado e fronteiras

Completar a revisão/aprimoramento das dez identidades existentes: swordsman,
archer, mage, berserker, defender, hunter, sentinel, elementalist, spiritualist,
geometer; corpos equipáveis, anexos e ícones atuais coerentes com o piloto aceito.
Inspecionar fontes, atlas, consumidor e renderer ANTES de alterar. Registrar
preservar/corrigir/completar por identidade e conjunto de ícones/equipamento;
existência do PNG e mera recoloração não provam leitura. Preservar o que já
funciona, incluindo Mago aprovado. Não exigir raster novo para cada identidade.

Aplicar ragrpg-art e, se houver raster novo, imagegen com fontes/prompts e
proveniência em assets/art/e08_characters. Não sobrescrever fontes históricas.
Pipeline novo é wrapper delimitado dos existentes, sem executar scripts que
reescrevam assets fora da lista. SVG existente pode ser editado diretamente.
Não criar classes, skills, itens, kits, música ou sons neste pacote. Não mudar
mapas, população, geometria, save, fórmulas, UI/layout, áudio ou VFX de kits.
Mundo P5 e feedback P6 permanecem consumidores futuros.

Contrato de animação imutável: 256×512, 32 células 64×64, pivô (32,58),
frente/costas/espelhamento, caminhada por deslocamento, mesmo relógio e estados.
CharacterAnimation/CombatAnimationState e PlayerActor são APIs prontas somente
leitura: configure/observe/play/draw_on/death_copy e set_equipment_visual.
set_body_atlas não serve para jogadores; não contornar sua restrição.
Anexos consomem mesmo frame/direção/transformação e dados de equipamento atuais.
Se faltar API ou houver defeito de produtor, parar o trecho e devolver a P0/Sol
com reprodução; não inventar fronteira paralela. Atlas compartilhado pode afetar
inimigos: enumerar consumidores e conferir regressão de espécies existentes.

## Propriedade exclusiva

Lista EXATA em [e08_p4_files.json](e08_p4_files.json), resolvida da base acima.
Inclui atlas dos dez jogadores, equipamentos/ícones existentes enumerados,
fontes novas com nomes delimitados, wrapper/probe/teste P4 e recibo.
Diretório e08_evidence/p4 exclusivo para evidência mínima (sem fixture completa).
Não é autorização para alterar todos os arquivos; só mudar os necessários.
P0 transfere equipment_attachment_visual.gd, equipment_head_visual.gd e
verify.ps1 apenas no escopo cosmético/registro do teste P4. P1–P3 parados.
Demais scripts e ferramentas históricos somente leitura. Arquivo adicional exige
transferência registrada por P0 antes de escrever. P0 não escreve durante P4.

## Validação e entrega

1. Inventário com consumidor real, decisão e razão; antes/depois por identidade
   alterada e evidência atual para todas as dez. Ícones em escala real na barra,
   inventário e equipamentos, sem mudar IDs/mapeamentos de gameplay.
2. Renderer nativo, piso claro/escuro, frente/costas e flip, idle/caminhada/ação/
   dano/morte; com/sem equipamento, arma/escudo/cabeça/duas mãos já suportadas,
   sem duplicar armas incorporadas ao corpo. Zoom 50/100/160%, UI120%.
   Verificar pés, grip/oclusão, origem, transições e repetição da captura.
3. Recriar UMA fixture pelo bootstrap tools/verify.ps1 -Test e07_f1_import_test
   com engine standard do principal .tools/godot/Godot_v4.7.2-stable_win64.exe;
   a fixture antiga foi removida na limpeza autorizada. Depois -F1Fixture.
   APPDATA isolado, sem save pessoal. Não restaurar cópias antigas.
4. Seleção por impacto: novo e08_characters_test, combat_animation_test,
   equipment_hand_alignment_test, e06_icon_bar_test, e08_pilot_test,
   e08_presentation_test, e08_pilot_ui_test, e08_audio_test,
   e07_f1_presentation_test, e07_f3_lifecycle_test,
   e07_f3_action_matrix_test, e07_f7_presentation_test. Acrescentar testes de
   classe quando seus atlas/anexos mudarem. Não alterar testes antigos/oráculos
   para esconder falha. Se nada mudar num conjunto, registrar inspeção suficiente.
5. Conferir import/export de assets e hashes/fontes/consumidores; usar sondas
   nativas existentes ou probe P4, sem exportar release completo por rotina.
   Comparar custo se houver delta relevante; regressão reproduzível >10% ou
   >16MiB retidos exige diagnóstico Sol. Não alegar 60FPS por teste headless.
6. Commit só dos próprios arquivos e recibo e08_p4_delivery.md com base/candidato,
   inventário, APIs intactas, execução real/exit/erros/timeouts, hashes, capturas,
   limitações e próximos passos. Preservar falhas/tentativas e os quatro backups.
   Evitar cópias volumosas; ZIP mínimo durável e manifesto, sem caches/profiles.

Devolver posse explicitamente a P0 após commit; não iniciar P5, não atualizar
playtest/master/push, não arquivar chat. Luna low supervisiona pacote congelado
quando P0 delimitar, Sol consolida contrato e evidência. Supervisão não é aceite
artístico independente. Som bit-crushed aceito apenas como placeholder; dívida
registrada para acabamento P6, sem bloquear este pacote.
