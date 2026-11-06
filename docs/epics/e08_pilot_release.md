# E08 — entrega técnica do piloto Mago/floresta

6/11/2026. Sol P0, sobre o [plano autorizado](e08_approved_plan.md).
Esta entrega é o piloto P3; não conclui P4–P7 nem presume aceite humano.

## Candidato e pacote

Código P3 `3ea5e9086da11c51d81d5a85b8f29d464b04c3d8`; candidato de exportação
`ad09b99d5e70385d4532b478931c85629f5de849`, branch `codex/e08`, checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
P1/P2/P3 foram recebidos, conferidos e integrados na mesma branch, com supervisão
Luna nos checkpoints. [Dispatch/posse](e08_dispatch.md), [P3 final](e08_p3_delivery.md).

Entrega local:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/playtest_e08/pilot_ad09b99d`.
Atalho `Jogar piloto E08.lnk`, EXE e PCK pareados, LEIA-ME e pasta `review`
com roteiro, oito imagens antes/depois, prévia sonora/tempos e proveniência.
Fontes raster originais completas permanecem no repositório; não são apenas
as folhas compiladas. [Roteiro versionado](e08_pilot_route.md).

| Arquivo | Bytes | SHA256 |
|---|---:|---|
| RagRPG-E08-Piloto1.exe | 109127680 | 4a9eaded8955ef789ab02651ed9d2dde80328fbb342bd2a6db4db33e86305668 |
| RagRPG-E08-Piloto1.pck | 125350284 | d91bc71373ec370e744b61032b7aed036f4895620241027b29c0b505c81246e2 |

Nome do aplicativo **RagRPG E08 Piloto1**, com perfil em
`%APPDATA%/Godot/app_userdata/RagRPG E08 Piloto1`. Testes usam APPDATA isolado
dentro da entrega. Não houve migração/copiar save pessoal. O habitual ficou em
`codex/playtest`, `fba777b3822356a10e7f6e050971e54ab1a9819b`, com216alterações
locais; não foi aplicado fast-forward sobre esse trabalho. Sem master/push.
Quatro backups locais preservados. Dois checkouts e uma fixture/cache.

## Comportamento entregue

Ponte observa eventos confirmados sem criar dano/consulta física/tempo de combate;
épocas/dedup/limpeza/pausa e staging impedem replay histórico. Serviço tem32vozes
e canais Geral/Efeitos/Interface/Ambiente, preferências locais fora do save.
Limiter privado protege a soma sem mudar Master, com pico nativo≈0,89026 para
24impactos/32slots e atraso de áudio2,042ms. Não é promessa para toda placa de som.

Piloto preserva corpo/equipamento do Mago e os materiais/geometria/mapas aceitos;
completa halo/núcleo de projétil/parede e pulsos confirmados com cap48 e oclusão
canônica. Lobo/javali recebem atlas próprios256×512,32poses,célula64×64,pivô32/58;
demais espécies/Guardião conservam sprites anteriores com acabamento por consumidor.
UI120% separa painel rolável e barra/rodapé.12WAVs originais sintetizados,
receitas/proveniência, sem música. IA, loot, RNG, regras e schema não mudaram.

## Validação e limites da execução

P3:14/14etapas selecionadas, não a suíte inteira, exit0, sem erros/timeouts;
piloto125headless/126nativo, apresentação2204, áudio132, UI55, animação39,
layout30, Mago52, teleporte29, F7 27, snapshot52, continuation2743, actionmatrix2004,
lifecycle90 e F1 39. [Supervisão Luna](e08_evidence/luna_p3/supervision.md).
ZIP final35membros e2316fontes conferidos. Receita ampliada após testes é exceção
documental explícita; texto/manifesto usados na execução estão no ZIP.

Embalagem: preflight2322fontes, engine standard4.7.2 `ed1daf0bf` com SHA256
`ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`;
template Windows release SHA256
`d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`.
Exportação/inspeção12sons+2atlas/menu persistente/boot do EXE passaram.
Sonda nativa **engine standard + PCK exato** passou20/20checks: floresta publicada
seed42,62inimigos,UI120%,minimapa,limiter,atlas e death_copy, suspensão/retomada,
recursos reconstruídos e ambiente1/efeitos0/interface0 ao retomar.
Nessa amostra entrada50,810s, suspensão8,908s e retomada26,675s.
Essas sondas não são scripts executados dentro do template release.

O primeiro `--script` externo no EXE não executou a sonda e teve timeout;
o boot normal do EXE passou. A primeira prova standard+PCK encontrou um .import
de arbusto abreviado pelo exportador; o template utiliza asset_manifest, portanto
isso não demonstra falha do jogo no EXE. Corrigiu-se a paridade de bytes no
exportador existente: [API oficial](https://docs.godotengine.org/en/stable/classes/class_editorexportplugin.html)
permite `_export_file/skip/add_file`; PNG/.import certificados e os mesmos
dest_files importados seguem juntos, sem republicar mapas. Novo PCK passou a prova.

`verify.ps1` acrescentou registro do teste existente de asset manifest:7/7PASS.
O teste antigo E06 de exportação falhou2/162 (11mobs esperados contra16atuais),
reproduzido no PCK F10 aceito; expectativa intacta. Resultados/falhas históricos
preservados. Binários da primeira exportação foram removidos por caminhos/hashes
conferidos; logs/manifestos ficaram. Não apresentar aquele diretório como release.

## Comparação F10 no mesmo computador

[Dados e cálculos](e08_evidence/p0_release/comparison_summary.json). GTX1080/NVIDIA582.66,
GL Compatibility,1280×720,vsync off,mesmo engine/PCKs e seed42; processos/perfis
separados, execuções sequenciais. Janelas de3s. A tabela usa mediana das medianas
e mediana dos p95 por janela; não é percentil calculado sobre frames agrupados.

| Controle | Janelas | Mediana F10→E08 ms | p95 F10→E08 ms | Máximo F10→E08 ms |
|---|---:|---|---|---|
|96móveis|3|8,717→7,569|12,178→9,166|45,604→16,570|
|96parados|3|4,069→3,644|7,371→4,660|37,679→14,605|
|Floresta,rodada1|3|11,641→12,378|16,920→16,552|32,104→22,957|
|Floresta,repetição|3|11,686→13,086|16,453→21,086|23,515→45,072|
|Floresta,6janelas primárias|6|11,664→12,485|16,563→17,430|32,104→45,072|
|Controle normal da ablação v2|3|11,464→11,600|14,313→14,907|20,954→25,485|

A repetição cruzou o limiar de triagem:mediana+12%,p95+28,2%. Não foi descartada.
Uma terceira execução com controles intercalados e3janelas por modo resultou
normal+1,2%/+4,2%; desabilitar só ponte/feedback, painel ou áudio não isolou
custo E08 persistente>10%. O agregado das6janelas primárias ficou+7,0%/+5,2%.
Há variação de janela/processo; não se atribui a melhora do controle96a otimização
E08 nem se afirma ausência universal de regressão. Sol considera suficiente
para playtest com essa ressalva, sem mudança especulativa de runtime.

Memória é uso estático do alocador Godot, não VRAM/RSS: floresta360,078→367,441MiB;
após limpar221,112→222,036MiB. Incremento retido acima do estado pré-estágio
80,712→80,773MiB, diferença+0,061MiB, abaixo da triagem16MiB. Isso não prova ausência
de vazamento em toda sessão longa. O wrapper registrou PeakWorkingSet64=0 após
encerrar; esse zero é indisponibilidade, não memória zero. Ferramenta passou a
registrar null nesses casos; não se inventou pico RSS.

Preparação primeira chamada/nova instância de processo14,932→15,261s;
segunda chamada no mesmo processo10,853→10,926s. Cache do sistema não foi
esvaziado; não chamar de boot frio do Windows. Digests de manifesto/regras
continuam idênticos ao F10. Entrada real na comparação50,987→47,412s, com outras
amostras44–51s; não é promessa de redução. PCK94.914.128→125.350.284B, +30.436.156B
(+32,1%), incluindo recursos E08 e cópias importadas preservadas na embalagem.
Picos, portais/carregamentos e a meta histórica60FPS permanecem ressalvas.

Tentativas de ablação anteriores ficam excluídas: uma teve variável duplicada;
outra guardou índice de bus antes do descarte de staging e o painel reaparecia
por refresh. A sonda v2 resolve o bus pelo nome no uso, desativa o refresh durante
ocultação e confirma panel_hidden3/3. Só v2 sem erros/timeout entra na conclusão.

## Aceite pendente

Abertura normal do EXE120frames:exit0, sem erro/timeout. A tentativa adicional
pela interface **não foi executada**: node_repl/Sky falhou em criar os assets do
kernel mesmo após reset; cua_repl falhou pelo mesmo erro. O processo exclusivo
do teste foi encerrado deliberadamente (exit−1, não PASS). Não houve interação
no save pessoal nem certificação interativa de combate dentro do EXE.
O usuário recebe o executável, os pares nativos e o roteiro para essa avaliação.
[Registro do impedimento](e08_evidence/p0_release/native_release_ui_attempt.json).

As fotos de poses não certificam cadência; o chefe tem prévia do mapa publicado,
sem campanha jogada até ele nesta validação. Sem audição subjetiva certificada.
Os doze sons precisam ser ouvidos em combate pelo usuário; a prévia sequencial
tem ganho1/ambiente0,3 e não é mix simultânea. Abertura/carregamento/portais/picos
continuam dívidas F10. Sem migração de saves e sem promessa universal de60FPS.
P4–P7 permanecem BLOQUEADOS_ACEITE_P3 até decisão humana explícita sobre este piloto.

## Evidência portátil e conferência final

[ZIP de evidência](e08_evidence/p0_release/evidence.zip):93membros, SHA256
`be2adeb28932a001630ec66e17ba8931582c215889f3c45f635ad42b9cafa949`.
[Hashes/escopo](e08_evidence/p0_release/hashes.json),
[arquivos de jogo e avaliação](e08_evidence/p0_release/delivery_files.json).
Sem perfis/saves pessoais no ZIP.2322inputs do export são reconstruídos a partir
dos2320inalterados e2blobs de ferramentas no commit de exportação, conferindo o
hash da sonda da primeira rodada. O manifesto atual2323adiciona a sonda de custo;
mudanças posteriores são de ferramentas/documentos, sem runtime/asset novo.
Após as execuções, o wrapper passou apenas a representar RSS indisponível como
null; texto usado na execução e texto atual estão separados no arquivo.
As duas versões inválidas da sonda foram reconstruídas e seus hashes bateram
com os registros das tentativas; não entram nas10execuções comparativas válidas.

Registro da conferência final:[Luna](e08_evidence/luna_pilot_release/supervision.md).
A conclusão ali registrada rege seu escopo de execução/hashes; não é auditoria
semântica independente, audição ou aceite de produto. Sol validou contratos,
invariantes e a composição; ressalvas de desempenho e inspeção interativa acima
continuam explícitas. Documentação e anexos de validação não repetem gameplay.

Fechamento6/11: Luna devolveu posse e concluiu PASS no escopo acima, sem divergência
nova. Sol consolida candidato **APROVADO TECNICAMENTE PARA PLAYTEST COM RESSALVAS**.
O próximo passo é exclusivamente o teste/aceite humano do piloto ou correções
nesse mesmo escopo; P4–P7 continuam bloqueados. Não houve nova execução de gameplay
por este fechamento documental.
