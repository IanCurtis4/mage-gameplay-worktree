# E08 P4 — Elementalista, Mago e Espadachim

7/11/2026. Integração delimitada de três unidades e apoio dos itens V2 na morte.
**Três unidades e correção comum tecnicamente validadas; P4 permanece aberto.**
Conferência de integridade Luna pendente, coordenada por Root.
Pedido humano: produzir sprites definitivos; retomada pela skill ragrpg-resume.
Entrada0b8c962c1efde0c37962eb20aeb6df7c00570193; contratos disjuntos de Root
avançaram HEAD até276efa9e6313a4d6bbef823adcf83a60f0f2f20f sem mudar os inputs.
Branch codex/e08; checkout C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5.
[Contrato](e08_p4_units_sol_contract.md), [posse](e08_p4_units_sol_files.json).

## Resultado e fronteira

Cada unidade tem64poses em quatro vistas independentes, atlas256×1024,
célula64, pivô32,58. Elementalista consome o conceito aprovado; Mago/Espadachim
preservam32células S/N nativas byte a byte e completam32perfis E/W.
Body/weaponless iguais são intencionais: não há arma embutida nesses corpos.
Armas/escudos/ícones continuam anexos existentes, com elegibilidade real intacta.
A matriz de sete chaves do harness é cosmética e não concede essas peças às classes.

Fontes originais, prompts, receitas e proveniência ficam nos diretórios
assets/art/e08_characters/directional/<kind>. Reprodução mecânica independente
conferiu todos os pixels e os frames do manifesto/calibração, sem alterar o
produtor genérico fechado. Defaults em assets/art/animations/directional/<kind>.
Testes de consumidor enumeram somente Espiritualista e estas três unidades;
as demais identidades mantêm os padrões anteriores. V1 mantém o mesmo atlas/rig
explícito nos testes geométricos e de32células, sem apagar oráculos de alpha,
transformação, botas, clock ou chão.

## Correções semânticas

Palma estática V2 podia colocar a base de um item abaixo do chão na morte.
O ramo V2 de EquipmentAttachmentVisual mede a base rotacionada considerando
flip local. Pose14 conserva a posição autoral se já estiver acima do piso;
se penetrar, levanta somente Y. Pose15 apoia a base no piso. X, ângulo e flip
continuam autorais. Ramo V1 intacto; sem schema/save, clock, AI ou combate novo.
Oráculo separado usa a caixa alpha real do SVG e transforma seus quatro cantos.
Vivos exigem palmas exatas; mortos exigem X e apoio, mais ângulo/flip preservados
nos três conjuntos novos. Espiritualista repete a regressão afetada nesta versão.

Inspeção autoral corrigiu o duplo espelhamento do capacete Mago no oeste,
os crânios e ângulos das oito poses de morte de Mago/Espadachim e os slots mortos
da Elementalista que ainda usavam overrides vivos de cajado/arco. Esses slots
agora soltam as peças horizontais atrás do cadáver. Todos os pixels, palmas
vivas e ângulos S/N vivos foram preservados. Galerias, oclusão, recortes, UI120,
zoom50/100/160 e transações reais equipar/remover capacete foram inspecionados.

## Evidência e limites

tools/verify.ps1:23/317etapas únicas,28.694checks,0falhas/erros/timeouts nas
execuções válidas. Composição explícita:10etapas PASS da cabeça final1 mais13
da cauda final2; só o teste novo recebeu correção de tipagem, sem runtime/arte
ou scripts anteriores diferentes. Não foi executada a suíte inteira de317etapas.
Cada unidade:3.629checks de conteúdo/default/cold restore,661checks nativos e
15PNGs,64frames do renderer e GIF6,4s/26frames codificados com durações preservadas.
Espiritualista corrigida:3.461checks e nova captura447checks/15PNGs, além de814
do produtor e regressões reais. V1hand_alignment4.593, aparência206, snapshot52,
continuation2.743, action_matrix2.004, lifecycle90 e projeção/oclusão F1/39 PASS.

PCKfinal2: exportPASS,10.887(3×3.629)+3.461+814checks no pacote exatoPASS;
100.111.388bytes, SHA256778afecffdead1c060b98105ae6ffedc2a4a38e1706e38a4fd869aace3f2cb6b.
Primeiro PCKpromoted1 passou o harness anterior e permanece como histórico;
o pacote final também exige pixels/64calibrações idênticos e pathdefault no
cold restore. Warnings de exportação VCS/plugin ausente são os existentes da
fixture; não houve ERROR ou falha no pacote executado com engine standard.
Os dois PCKs temporários permanecem fora do Git para conferência Luna; não remover
até orientação Root. ZIP portátil e hashes no rodapé deste recibo.

Custos medidos
antes dos defaults:96atores equipados,3janelas de3s móvel e parado por V1/V2.
Mediana/p95 móvel em ms: Elementalista14,341/19,629→13,398/15,821;
Mago13,543/17,258→13,260/16,014; Espadachim14,015/20,599→13,448/16,417.
Retenção incremental estática: -21.416/-9.448/-9.448bytes respectivamente.
Nenhuma medida agregada de frame/draw CPU cresceu>10%, nem retenção>16MiB.
O custo mediu a mesma arte viva/equipamentos; mudanças posteriores são de
cabeça/morte e enumeração do harness, sem mudança do algoritmo de custo/draw.
Não é medição de RSS/VRAM, vazamento, campanha ou FPS dos mapas.

Tentativas ficam preservadas: Elementalista staging1 teve erro de inferência
Vector2 no teste, corrigido antes de staging2; calibrated1 da nova enumeração
falhou por Array genérico atribuído a Array[StringName] em um ternário e atingiu
timeout120s. Corrigida a construção explícita, sem mudar expectativas.
O fortalecimento final1 encontrou três inferências bool de Dictionary no teste;
parse falhou na etapa19. Tipos explícitos corrigidos e cauda final2 passou13/13;
as10etapas anteriores foram aproveitadas pelos inputs compatíveis.
Não somar tentativas repetidas como cobertura adicional. A interrupção por limite
de uso preservou fonte/logs; Root recebeu posse temporária somente para contratos
disjuntos e a devolveu antes da retomada. Sem processo Godot abandonado.

A inspeção Sol é autoria/validação técnica, sem auditoria artística independente.
O capacete e os desenhos de equipamentos do piloto continuam provisórios:
usuário pediu encaixe menor e redesenho em uma fatia separada de Root, que não
integra esta entrega. Não há aceite de produto ou campanha humana jogada.
P4 continua em execução; os demais conjuntos e P5–P7 não são concluídos aqui.
Habitual codex/playtest, save pessoal e quatro backups preservados; sem master/push.

## Artefatos e próximo passo

[Guia portátil](e08_evidence/p4_units/README.md),
[seleção e composição](e08_evidence/p4_units/verification_summary.json),
[Elementalista](e08_evidence/p4_units/elementalist/four_views.png),
[Mago](e08_evidence/p4_units/mage/four_views.png),
[Espadachim](e08_evidence/p4_units/swordsman/four_views.png).
Cada diretório da unidade contém galeria, inventário coberto/descoberto,
animaçãoGIF, contagens e custo. PNGs são cópias exatas do renderer.

Root recebe a posse da fixture/índice e da lista delimitada após o commit/handback.
Próximo passo autorizado: Luna confere integridade/execução congeladas, sem rerun
rotineiro. Depois Root integra os próximos conjuntos e o redesign de equipamentos;
base de cabelo/rosto e camada de chapéu também pertencem à revisão separada.
A prova desta etapa conserva o capacete piloto provisório e não concede aceite
artístico, de produto, P4 inteiro, P5–P7, merge, push ou playtest habitual.

## Freeze portátil

[ZIP](e08_evidence/p4_units/evidence.zip):657membros,50.670.917bytes,
SHA25659801ad23a11396bdee7f80dd2bca880a0ce19bb49ab1f650aeab11ead4be6e5.
[Hashes](e08_evidence/p4_units/hashes.json) conferem2.431inputs em origem/fixture,
engine, produtor genérico intacto,657membros do ZIP e quatro backups preservados.
Não contém perfis/saves/cache/PCK. Dois pacotes temporários,200.222.440bytes,
permanecem em .godot/verification/p4_units/elementalist/export_promoted1 e
export_final2 para conferência antes de remoção autorizada por Root.

Depois das execuções, apenas documentos/recibos e propriedade receberam
consolidação. Fonte de runtime, PNGs, manifestos, testes e ferramentas
executados permaneceram iguais; não foi repetida a suíte por essa edição
documental. Novos assets/contratos futuros em arquivos disjuntos não entram
nos2.431inputs congelados. Luna recebe esta prova por Root; nenhum rerun ou
aceite de produto foi inferido do freeze.

### Consolidação posterior Root/Luna

Luna conferiu seleção válida, ZIP657,2431inputs e85hashes próprios, sem rerun ou
auditoria visual independente. Recibos adicionais luna_supervision.md
(SHA7ecd8529c5347dc7cf1a20101ac2443d18d290ad2d14c94e7df49cf265739f73)
e luna_hashes.json (SHAa61c70157e04b697e225149aeeb8a58027d3fdedb028c0d3f924c01eae8a13bc)
no diretório de evidência. A checksumJSON foi medida diretamente: a mensagem do
agente continha erro de transcrição, que o guard detectou antes de remover nada.
Após conferir relatório/arquivos, Root removeu somente os2PCKs temporários exatos,
novamente comparando tamanho/SHA/path;200.222.440bytes liberados. Recibo
validation_pack_cleanup.json. ZIP/fontes/logs/fixture/PCK aceito P3/save pessoal
preservados. Presença relatada porLuna é anterior à remoção controlada. Próxima
revisão de equipamento/cabelo terá inputs/recibo próprios.
