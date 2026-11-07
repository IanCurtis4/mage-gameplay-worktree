# E08 P4 — entrega do produtor de quatro direções

6/11/2026. Sol implementou e validou o escopo técnico autorizado pelo usuário.
**Produtor pronto para consumo artístico; P4 inteiro continua INCOMPLETO.**
Base e10bf71d91d0e9271d9792ed04e211ab8ca17112, checkout exclusivo
C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5, branch codex/e08.
[Contrato/API de autoria](e08_p4_directional_contract.md),
[lista de propriedade](e08_p4_directional_files.json). Terra permanece parado;
a conferência Luna de execução/inputs será incorporada antes da consolidação.

## Comportamento entregue

- CharacterAnimation aceita um conjunto completo por set_directional_manifest,
  ou descobre o padrão por tipo visual.64poses, quatro blocos sul/norte/leste/
  oeste, sem espelhar automaticamente o corpo V2. V1 continua com seus32quadros.
- A fase usa o mesmo CombatAnimationState. A direção é derivada do facing já
  salvo; empate vertical determinístico. Ação mantém direção do lançamento,
  dano não gira, morte conserva vista e cópia independente; cancelamento/revive
  e seleção de equipamento preservam a mesma autoridade de relógio.
- Corpo, mãos/armas, dedos, cabeça e morte usam a seleção comum. Capacete
  pilot_head agora participa de EquipmentAttachmentVisual.describe e do mesmo
  draw_on no ator e no retrato. O antigo nó EquipmentHeadVisual permanece como
  marcador de compatibilidade, sem segundo desenho nem redesenho por tick.
  Outros capacetes não ganham arte de pilot_head por inferência.
- Validação atômica do manifesto/duas texturas, hashes de RGBA visível,64células,
  pés/grips/crops, ângulos/profundidade finitos. Falha não muda a unidade ativa.
  Catálogo derivado pode ser reconstruído pela resource_path após restore frio.
  Campos de CharacterAnimation/CombatAnimationState e runtime_manifest não
  foram ampliados; nenhum formato de perfil/snapshot ou regra de gameplay mudou.
- Inimigos sem anexos desenham só o corpo, usando o MESMO seletor de quadros,
  sem materializar/copiar rig que não será desenhado. Essa correção respondeu
  à regressão real encontrada no primeiro controle sem equipamentos.

As imagens geométricas em tests/fixtures/e08_directional são exclusivamente
fixtures. Nenhum sprite de produto virou quadrado de teste, nenhuma fonte
histórica foi sobrescrita e a candidata Espiritualista não foi promovida.

## Prova final e limites

Verify.ps1: **25/25etapas,13.829checks,0falhas/erros/timeouts**, seleção explícita,
sem repetir315etapas inteiras. Inclui814novos unitários,84integrados, animação,
alinhamento4.593, aparência/inventário, classes com atlas específicos,
apresentação/áudio/piloto e snapshot/continuation/action_matrix/lifecycle.
Os testes legados e suas expectativas permaneceram intactos. Após a correção
de custo repetiu-se a seleção completa afetada; não só o benchmark.

Renderer nativo: **82checks,6capturas,0falhas**, com64poses sintéticas,
Camera2D.zoom50/100/160 e UI120 em CanvasLayer independente; perfil descartável
real, equip confirmado e capacete visível em ator/inventário. HUD e ícones
foram preenchidos por comandos administrativos existentes, explicitamente como
fixture; não é compra normal de todas as skills. [Retrato com capacete](e08_evidence/p4_directional/inventory_helmet.png).
Não é avaliação artística de todas as identidades/poses nem campanha jogada.

Exportação Windows PCK PASS; no pacote exato, unitário814 e integração84 PASS,
sem erro/timeout. A integração usa ProfileFacade real no restore, limpa catálogo
em memória e conserva vista/fase/atlas/rig/cabeça de jogador e inimigo. É engine
standard4.7.2+PCK, não novo EXE nem atualização do habitual/playtest.
O preset de harness inclui JSON das fixtures; filtro de produção inclui só
assets/art/animations/directional/*/presentation.json. PNG fonte não precisa
estar no PCK: hash verifica RGBA8 importado com RGB zerado apenas onde alpha=0.

Manifesto final: **2.352fontes idênticas origem/fixture**, engine4.7.2standard,
quatro backups conferidos. Uma fixture F1 reutilizada; bootstrap e deltas exatos
com fontes anteriores/atuais no ZIP, sem alegar que o manifesto original já tinha
as alterações posteriores. Copiados do importador somente UID/import dos novos
arquivos permitidos; receita geométrica reproduzida byte a byte.

## Custo comparável e triagem

Mesma engine/GTX1080/NVIDIA582.66,1280×720,vsyncdesligado, mesmo script externo e
PCK piloto ad09b99d contra PCK novo.96atores com/sem anexos,3janelas de3s por
movimento/repouso em cada processo, depois repetição. Tabela: mediana das seis
medianas e mediana dos seis p95 por controle; não percentis de uma amostra reunida.
Redesenho forçado inclusive no repouso: não extrapolar como FPS do mapa.

| Caso | Móvel mediana ms | Móvel p95 ms | Parado mediana ms | Parado p95 ms |
|---|---:|---:|---:|---:|
|Piloto aceito, equipado|11.030|15.868|10.825|14.270|
|Novo V1, equipado|7.922|10.189|7.874|10.261|
|V2 sintético, equipado|7.879|10.186|7.936|10.748|
|Piloto aceito, sem anexos|2.014|4.044|1.875|3.606|
|Novo V1, sem anexos|0.999|2.227|0.872|1.769|
|V2 sintético, sem anexos|1.048|2.307|0.990|3.136|

O primeiro controle cost_packed detectou o custo do descritor/rig em corpos sem
anexos; foi corrigido, mantendo a imagem V1 idêntica RGBA a RGBA tanto em Mage
com peças quanto em warrior sem anexos. Paridade repetida nas três rodadas finais.
A rodada exploratória anterior source-versus-PCK fica identificada e não compõe
a tabela empacotada. Todos os grupos e amostras brutas foram preservados.

Algumas janelas de p95 do V2 sintético passaram10% do controle e variaram nas
repetições. Triagem adicional manteve os MESMOS cenários sem cap e mediu CPU
apenas em draw_on, sem substituir o tempo do quadro nem apagar a divergência.
CPU do desenho reduziu mediana/p95 em todos os controles. Exemplo sem anexos,
móvel: CPU piloto1,273/1,865ms; V1novo0,414/0,630; V2sintético0,498/0,756.
No grupo instrumentado, o intervalo p95 do V2 sem anexos foi1,914ms móvel e
2,535ms parado. Isso afasta um aumento persistente de CPU do desenho naquele
controle; não identifica causalmente o jitter restante do quadro inteiro.
A agregação sem instrumentação acima também ficou abaixo do piloto nos p95.
Não prometer ganho universal/60FPS. Arte V2 real e cenário/AI ainda precisam
ser medidos na integração de conteúdo, como o contrato já exige.

Memória registrada é alocador estático nativo antes/carregado/após liberar atores,
não RSS/VRAM nem certificado de ausência de vazamento. Retenção incremental
comparada ao controle ficou abaixo16MiB; valores e máximos de quadro por grupo
estão em performance_summary.json. Não refazer navegação/portal/carregamento F10
por inferência deste benchmark de renderer.

## Histórico preservado

Unit1 rejeitou pivot por comparar array inteiro com números JSON; corrigiu-se
validação numérica. Unit3 detectou hash diferente por RGB invisível corrigido
pelo importador; captura diagnóstica confirmou40.320pixels transparentes e
mesmo hash visível, sem alteração de pixels visíveis. Unit2 parou no preflight
por sincronização não concluída; não foi teste executado/PASS. Preparativos da
integração corrigiram equipment_instance_id e binding de facade no restore,
sem alterar oráculos antigos ou jogo. Native inicial não era prova de HUD
preenchido/CanvasLayer; o harness foi corrigido e recapturado. Logs/deltas
conservados em vez de reclassificar tentativas anteriores como sucesso.

Após o PCK/regressão final só o probe externo de custo e seu wrapper receberam
instrumentação CPU/registro de hash do script. Runtime, testes, texturas e formato
são os mesmos; versões anteriores e manifestos estão no ZIP. A comparação
instrumentada usa o mesmo PCK otimizado e o MESMO script externo nos seis casos.

[Manifesto e limites](e08_evidence/p4_directional/hashes.json),
[verificações](e08_evidence/p4_directional/verification_summary.json),
[medidas](e08_evidence/p4_directional/performance_summary.json),
[ZIP portátil](e08_evidence/p4_directional/evidence.zip).

ZIP385membros,3789595B, SHA256
9d4db9ca485f792803a981c51bf6c3c06b6ada7c556e6584ae746cc1726c4757. Perfis/saves/cache/builds não entram no ZIP.

## Próximo consumidor e preservação

Terra deve produzir primeiro UMA identidade completa em staging, fora do caminho
de ativação automática: corpo/base e sem arma,64poses e calibração de112grips
vivos nos dois corpos, dedos/cabeça/morte, anatomia real em cada vista e fontes/
prompts preservados. Usar set_directional_manifest no probe de conteúdo e revisar
escala real/oclusão/equipamentos. Não converter os32quadros existentes em64
por retinta/espelhamento para declarar as quatro vistas prontas.

Depois Sol recebe a unidade aprovada para integrar o padrão, ampliar a cobertura
real V2 e conservar prova V1; testes de classe que medem representação legada
precisam de migração explícita de fixture/contrato, sem relaxar expectativas para
ocultar defeito. A produção de todo o restante e a entrega P4 permanecem pendentes.
P5 não iniciado, chat Terra não arquivado. Código habitual codex/playtest e seu
status local preservados, saves e quatro .bak intactos. Sem master/push.
