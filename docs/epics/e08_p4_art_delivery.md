# E08 P4 — primeira unidade artística direcional

7/11/2026. **Espiritualista V2 integrada tecnicamente no candidato; P4 continua em execução.**
Usuário autorizou produzir sprites definitivos. Base28c5ebc777e72b96f4363d1bff2b48e666acd854,
checkout C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5, codex/e08.
O pacote independente de autoria Elementalista foi preparado em0ddad09ff0c6dd8d816863eb0018b3fb444a18fb;
seus arquivos não pertencem à fixture/prova congelada desta primeira identidade.
[Contrato e propriedade](e08_p4_art_contract.md), [lista](e08_p4_art_files.json).

## Resultado observável

Espiritualista ganhou cabelo prateado/coque e traje ritual cinza/carvão com
silhueta própria do estudo apreciado pelo usuário. Quatro desenhos S/N/E/W,
64poses de repouso/caminhada/magia/dano/morte, sem espelhar uma frente para fingir
lateral. Corpo40–52px, célula64, pivô32,58, atlas256×1024. Armas continuam anexos
separados; body/weaponless iguais intencionalmente porque não há arma embutida.
As demais identidades ainda usam seus assets atuais; isto não encerra P4.

Fontes geradas/editadas com imagegen integrado por Terra; fontes históricas
preservadas. [Prompts/proveniência](../../assets/art/e08_characters/directional/spiritualist/provenance.json),
[receita](../../assets/art/e08_characters/directional/spiritualist/recipe.md) e
[calibração](../../assets/art/e08_characters/directional/spiritualist/calibration.json).
Sol assumiu64poses/112grips vivos, crops de dedos, profundidade/ângulos/cabeça,
integração e validação. Pontos são palmas reais; norte23 tem palma distante
pequena e sombreada, conferida no atlas/captura, não escolhida numa roupa opaca.
Capacete piloto segue o mesmo corpo/retrato e foi calibrado inclusive na morte.

Runtime descobre a unidade em assets/art/animations/directional/spiritualist.
Staging preservado em assets/art/e08_characters/directional/spiritualist. Nenhum
campo/schema de save, autoridade de combate, classe/skill/item ou algoritmo de
navegação mudou. Mago e fontes/atlas legados permanecem. Testes V1 agora fixam
explicitamente os mesmos arquivos de32células e seus rigs; oráculos de alpha,
transformação, escala e chão foram conservados. Testes do consumidor deliberado
exigem paths/64células exatos da Espiritualista e restauram a unidade real.

## Evidência

- tools/verify.ps1:21/21etapas selecionadas,17.440checks,0falhas/erros/timeouts.
  Não foram repetidas todas316etapas. Conteúdo novo3.293, rigsV1 4.593,
  aparência real206, animação/produtor/inventário/áudio/piloto e fronteiras
  snapshot/continuation/action_matrix/lifecycle incluídas.
- Renderer nativo:447checks,15PNGs,0falhas.64poses, duas cores de piso,
  sete chaves cosméticas existentes (a matriz não muda elegibilidade),
  grips/oclusão e morte, Camera2D50/100/160 com UI120 independente.
  Perfil descartável Espiritualista, staff inicial e capacete concedido/equipado/
  removido pela autoridade real; mundo/retrato usam descoberta automática V2.
  Barra preenchida por comandos administrativos legais, não por compra normal.
- Movimento:64frames PNG do renderer no mesmo relógio visual em passos0,1s;
  préviaGIF6,4s,26frames codificados (iguais consecutivos reunidos preservando
  durações), paleta compartilhada256cores sem dithering. Não mede FPS de mapa.
- PCK Windows com engine4.7.2standard: exportPASS; conteúdo3.293 e produtor814
  no pacote exatoPASS. JSON de staging/fixtures incluído só no preset do harness;
  filtro de produção já inclui o manifesto do diretório runtime.

[Galeria](e08_evidence/p4_art/spiritualist_four_views.png),
[animação](e08_evidence/p4_art/spiritualist_motion.gif),
[inventário](e08_evidence/p4_art/spiritualist_inventory.png),
[contagens](e08_evidence/p4_art/verification_summary.json),
[medidas](e08_evidence/p4_art/performance_summary.json).

Custo no mesmo runtime/engine/fixture,96atores equipados,3janelas de3s por estado,
redesenho forçado: controleV1 mediana/p95 móvel13,384/17,008ms; V2 real13,717/
18,071ms (+2,49%/+6,25%). Parado14,249/22,411→13,624/18,822. CPU do draw móvel
8,443/10,904→8,660/11,724ms; parado8,946/14,804→8,607/12,488. Retenção incremental
estática -42.712bytes contra controle. Não houve limiar agregado de triagem>10%
ou>16MiB; isso não mede RSS/VRAM, vazamento ou FPS real da fase. Arte real foi
medida além da fixture geométrica anterior, sem inferir ganho universal.

## Histórico e limites concretos

Os resíduos vermelhos percebidos inicialmente eram RGB com alpha≤5, sem pixel
opaco; limiar existente os remove mecanicamente. Sulv3 corrigiu mãos nas poses
de dano. Leste v2 tinha terceiro braço/mão em walk6: corrigido com imagegen e
selecionada somente essa célula da v3, preservando as demais da v2. Vistas oeste
foram corrigidas para manter dano em perfil. Nenhuma dessas falhas foi promovida.

A primeira regressão herdou APPDATA padrão do Windows:132checks do áudio foram
executados, com falhas ao salvar preferências na pasta de fixture; não foi PASS.
Corrigiu-se somente o lançamento com APPDATA/LOCALAPPDATA dentro do workspace,
repetindo as21etapas: áudio132PASS, sem alterar código/expectativas de áudio.
A guarda de shell após sync1 usou LASTEXITCODE antigo e interrompeu antes do
import; sincronização estava concluída, import não foi executado por aquela
chamada. Execuções reais posteriores e seus exits estão conservados. A primeira
prancha de autoria cortou a última linha por content_scale; viewport explícito
corrigido antes das provas finais. Ensaio de ancorar o pé mais baixo por cor de
bota deslocava o tronco no perfil e foi descartado; receita mantém suporte
centrado. A primeira montagem GIF assumiu64frames codificados; o encoder reuniu
quadros iguais, e verificou-se corretamente duração total6,4s sem regenerá-lo.

Somente quatro arquivos de narrativa/proveniência/calibração autoral receberam
consolidação depois das execuções; frames, hashesRGBA, PNGs, manifesto de runtime,
testes e ferramentas executados permanecem iguais. Manifesto testado/delta final
preservados no ZIP, com byte-identidade da reprodução e distinção de inputs.
Não houve rerun de gameplay por essa consolidação documental.

Inspeção Sol é validação técnica/visual autoral, não auditoria artística
independente. Luna conferirá integridade/execução congeladas, sem rerun rotineiro.
Sem campanha humana jogada, certificação de todos os mapas/oclusões ou aceite de
produto. O teste F1 cobre projeção/oclusão já existentes; não é revisão artística
de todo relevo da fase. Equipamentos/ícones continuam os atuais do piloto.

## Continuação autorizada

Elementalista está em produção Terra em arquivos separados pelo
[contrato](e08_p4_elementalist_contract.md). Restam as demais identidades e corpos/
overrides de inimigos do escopo P4, com preservar/corrigir/completar explícito e
provas reais antes de declarar quatro direções. Uma identidade concluída não
substitui esse restante. P5/P6/P7 não iniciados nesta rodada. Habitual codex/playtest,
seus216registros locais, piloto aceito e saves preservados; sem master/push.

## Freeze de evidência para Luna

[ZIP portátil](e08_evidence/p4_art/evidence.zip):275membros,10.399.499bytes,
SHA2568de2e58e008db7496408ee79ec64ffcb3e712857add44af42ae5596d1192db9e.
[Manifesto](e08_evidence/p4_art/hashes.json) confere2.377inputs declarados
em origem/fixture, fontes originais no Git, engine, quatro backups e PCK.
O ZIP contém logs/planos/deltas, versões de ferramentas e capturas, sem perfis/
saves/cache/builds; não é uma cópia inteira executável do repositório.
A ferramenta genérica e fontes Elementalista são pacote independente, fora
desses2.377inputs congelados. O custo foi medido antes da ativação automática
para preservar o controle V1; mudanças posteriores do probe foram só na galeria/
UI/preview, conservando branch de custo/draw e dados de arte. Deltas preservados.

Depois do commit deste freeze, Luna é única escritora de
e08_evidence/p4_art/luna_supervision.md e luna_hashes.json. Inputs desta unidade
ficam somente leitura até handback. Produção de outros conjuntos pode continuar
em arquivos disjuntos, sem alterar este corpo, teste, ferramenta ou manifesto
da fixture enquanto Luna confere. Supervisão não concede aceite de produto.

## Handback Luna da Espiritualista — 7/11/2026

Candidato a195c8de29ce436520548a44268d412df69f6b49 conferido por Luna:275/275
membros,2.377inputs em origem/fixture, engine/backups/PCK,21/17.440checks,
nativo447/15, pacote3.293+814 e movimento64PNG/GIF6,4s. Devolveu posse, sem
rerun ou aceite artístico/produto. [Conferência](e08_evidence/p4_art/luna_supervision.md).
Removido somente o PCK temporário83.157.672bytes após conferir seu hash/tamanho;
fontes/fixture/evidência/piloto/save preservados. [Consolidação](e08_evidence/p4_art/consolidation.json).
A narrativa de espera por Luna acima é histórica. Espiritualista tecnicamente
consolidada; Elementalista em staging sob inspeção Sol e Mago preparado como
próximo pacote em arquivos disjuntos. P4 continua aberto, P5 bloqueado.
