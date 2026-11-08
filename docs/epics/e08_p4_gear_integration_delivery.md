# P4 — equipamentos pintados e primeiro cabelo base integrado

Entrega Sol em8/11/2026, codex/e08 no checkout .tools/map-editor-m5. Entrada
94d68c98cf1d9e93de23e184cfdf0fd62f85d8ab; fontes do Mago versionadas em
a23a84c2f8fc495303e3091d8f782f68cd19c8c1; base documental final
dc5ada5f83e3213cc4857a63c065704eaf51a810. O commit que contém este recibo
é o candidato entregue. [Contrato](e08_p4_gear_integration_contract.md),
[posse exata](e08_p4_gear_integration_files.json),
[recibo portátil](e08_evidence/p4_equipment/README.md).

## Comportamento entregue

Quatorze IDs existentes de cabeça usam PNGs próprios S/N/E/W, menores que o
elmo anterior. Sete peças pintadas4x mantêm tamanhos/grips lógicos e aparecem
no mundo, retrato e ícones correspondentes. CanvasTexture mantém filtro linear
local às peças; corpo continua nearest. W usa arte própria sem espelho adicional.
O apoio dos itens mortos considera as bordas opacas em unidades lógicas e o
ângulo/flip reais. Perfis, função de encaixe V1 e sete SVGs anteriores preservados;
4.593checks V1 continuam inalterados, com novo oráculo PNG separado para V2.

Opcionais bare_head válidos entram na mesma validação integral do catálogo V2:
path/hash/dimensões/64poses, grips/crops/grounds e exigência de weaponless.
Opcional ausente conserva o anterior; presente inválido rejeita a troca inteira.
A terceira textura é reconhecida pelo próprio path no restore frio, sem campo
novo de save/snapshot/ator. Somente equipamento de cabeça conhecido com textura
válida seleciona a variante. Remover o item restaura exatamente o atlas anterior.
Não houve alteração de clock, dano, elegibilidade, loot, hitbox ou nomes.

Mago é o primeiro consumidor real: corpo bare RGBAce94ffabe8c1dcd02538bf5264584a916ef7a54b098fbb90eaffe547685e63f8,
originalRGBA2defd07b164fa78c9e61292e2d240fdae89dc2eae6549ca57d765fb82f5f10df
preservado. A inspeção nativa exigiu deslocar as64âncoras cranianas autoradas
em[0,+4] uma única vez e corrigir ângulos dos cadáveres15/31/47/63 para
0.1/0.6/0.65/-0.65rad. Vivo e queda mantêm ângulos Terra; corpo, mãos e PNGs não
foram redesenhados por integração. Prova offline conserva112crops de dedos,
64grounds/slots e todos os pixels fora das regiões de cabelo/proteções.

## Validação e tentativas

Seleção tools/verify.ps1:24/318etapas únicas,31.283checks PASS, sem erro de
execução/timeout. Registros em verification_summary.json:22etapas compatíveis de
regression_final1 e os2consumidores repetidos após os4ângulos de cadáver em
regression_pose_final1. Repetições não são somadas. A mudança final só afeta
calibração de cabeça morta; código, PNGs e demais22testes permanecem idênticos.
Inclui inventário/UI/ícones/presentation/áudio/pilot, produtor814, integração84,
Espiritualista3.461, unidades10.887, equipamentos2.589, aparência206,
V1mãos4.593, snapshot/continuation/action_matrix/lifecycle/F1.

Falhas iniciais preservadas: import_initial1 omitiu o novo diretório scripts
na lista de arquivos novos do wrapper; catálogo desconhecido, corrigido no
harness antes dos testes. unit_initial2 teve42falhas por usar catálogo mínimo
BuildEffectCatalog em vez do catálogo de conteúdo real com14definições. Corrigido
somente o setup para BuildContentLoader.pilot; nenhum oráculo foi afrouxado.
Warnings de textura ausente/inválida nos negativos são esperados e observáveis.
native_initial3/fit1 preservam a descoberta de encaixe e a correção final.

Nativo final2:5.568checks/35PNGs,14cabeças e7peças em64poses,4vistas,
pisos claro/escuro, mortes, retrato/mundo reais com equipar/remover, UI120,
zoom50/100/160 e controle Espiritualista. Movimento final2:76checks/64quadros,
prévias GIF6,4s. Sol inspecionou galerias,4calibrações finais, olhos/cabelo/encaixe,
mãos e apoio no piso; não é auditoria visual independente nem aceite humano.

PCKfinal2:101.077.828bytes SHA256
14c9be3e24924c09fe0fa012c1978fb0f906eb216d7c7627f03816776b3e3eb1.
Dentro do pacote real:2.589+10.887+3.461+814checks PASS. PCKfinal1 também
preservado, com os ângulos anteriores e seus próprios logs/hash. Ambos fora do
Git, aguardando conferência Luna e remoção explícita Root após hash/tamanho.

Custos:96atores MagoV2 equipados,3janelas3s por moving/idle, redraw forçado,
mesmo probe e engine standard. Primeiro idleCPU p95 subiu13,92%; repetição quieta
não reproduziu: movingCPU p95+0,48%, idle−10,65%, framep95−12,70%/−30,17%.
Retenção estática incremental−32.544bytes, abaixo do limite16MiB. Históricos,
picos e medianas completos em performance_summary.json. Não certifica RSS/VRAM,
ausência de vazamento, desempenho de mapas ou efeito causal isolado do hardware.

## Preservação, entrega e limites

2.468inputs idênticos em origem/única fixture F1, manifestoSHA256
30978d236f9383d02f802cb08278785a4ea9270bc5e874d99ab1dd07d17893b5.
Somente project.godot difere em VCSautoload=false. Godot4.7.2standardSHA256
ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424;
APPDATA/LOCALAPPDATA isolados. Fontes read-onlyGear/Mago e4backups conferidos.
Novos stages Root posteriores não fazem parte dos inputs congelados.

ZIP mínimo inclui logs/planos/deltas/versões anteriores/hashes/capturas/harnesses;
sem perfis/saves/cache/PCK. Conferência Luna pós-freeze ainda pendente, coordenada
por Root; não há gate Astra rotineiro. Índice/fixture/arquivos devolvidos a Root
com o commit deste recibo; nenhum arquivo Root/artista ou .bak foi incluído.
Documentação final não repetiu gameplay, pois não altera os inputs testados.

P4 continua aberto: outras bases de cabelo, seis jogadores e inimigos em stages
Root precisam integração posterior autorizada. Maçã/ovo são estudos sem ID/drop.
Sem master/push, avanço habitual, save pessoal ou aceite de produto nesta entrega.
