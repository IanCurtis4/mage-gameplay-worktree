# Checkpoint compacto da expedição — decisão e contrato de trabalho

Decisão confirmada pelo usuário em 13/11/2026 durante a retomada do P7. Ao
retomar, inimigos vivos voltam ao ponto de origem com vida cheia e sem efeitos.
O personagem conserva posição, HP/SP, recargas e augments. Esta decisão substitui
a conservação exata dos inimigos na [direção de produto](../PRODUCT_DIRECTION.md)
para o novo formato. Expedições antigas usam o formato exato na revisão
compatível. A validação e a sequência do P7 constam no [índice](e08.md).

## Estado durável

- Identidade da expedição, dono, fase, estágio, seed e revisão da composição
  publicada. Reconstruir o mapa pela autoridade de geração e validar a
  identidade da composição antes de instalar o mundo. Uma seed com conteúdo
  diferente pode produzir outro mapa ou outras vagas.
- Posição do personagem com a superfície, orientação, HP/SP, estado,
  recargas e build. Conservar augments, ofertas, RNG de gameplay, último
  portal, objetivos, mácula e relógio de respawn. A ausência do jogador não
  avança os relógios.
- Vagas identificadas pelo ID estável e geração, com estado vivo, morto ou
  aguardando respawn. Recriar os vivos na origem aprovada pelo mapa, com o
  estado inicial da espécie. Vagas mortas não reaparecem até a regra de
  respawn. Evitar gravar posição, vida, ameaça ou efeitos de cada inimigo.
- Tickets pendentes, recibos e progressão mantêm a identidade de cada morte e
  entrega. A confirmação de XP e itens segue o commit durável, com repetição
  idempotente em falha, retomada ou retry.

## Linha de base existente

No candidato C8, a [sonda de release](e08_p7_release.md#candidato-atual-p7-d6004142-c8)
mediu 50,6 s de entrada, 9,1 s de suspensão e 24,7 s de retomada. O diário já
tem gravação em segundo plano no jogo e volta ao checkpoint completo em
algumas situações, como a compactação ao atingir o limite. A coleta automática
também aguarda o fim do combate. Preparação de geometria, caminhos e população
é outra parcela do carregamento, documentada no [estudo F10](../map_editor/studies/f10_loading_options.md).
Os tempos de C8 não isolam essas parcelas nem medem a latência até confirmar
um drop.

Uma sonda nativa adicional no PCK C8 injetou quatro mortes no mesmo quadro,
fora de combate, e observou a gravação pelo fluxo normal. Captura completa
8,02 s e 4.977.352 bytes antes da compressão. A publicação do diário de mortes
foi observada após 1,57 s, e a entrega dos quatro tickets em dois lotes após
5,09 s. O p95 no intervalo foi 30,5 ms, com pico de 212,4 ms. O percurso
terminou com 21/21 verificações funcionais, incluindo suspensão e retomada com
58 dos 62 inimigos. O verificador externo registrou a leitura do repositório
de certificados do Windows como erro de ambiente, embora a sonda offline
tenha retornado 0. Outras verificações concorreram por CPU nesta amostra.
Usar como diagnóstico, com rodada isolada antes de certificar ganhos.
Evidência local em
`.godot/verification/p7/pre_p8_integracao_01/save_c8_native_01/output.log`.

## Contrato da primeira versão

Base inspecionada: `codex/e08`, commit
`b02315692c0f5d7060b138029cd4bc031d68dd65`, checkout
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`, com alterações
P7 em curso. Este documento não aprova esse conjunto nem abre P8. A propriedade
desta rodada documental limita-se a este arquivo. Nomes de APIs compactas abaixo
são propostas, não APIs já implementadas.

### O que já existe e onde começar

`ExpeditionCheckpointCodec` já grava formato 2 comprimido com DEFLATE, hashes dos
bytes comprimidos e descomprimidos e limite lógico de 16 MiB. Formato compacto
significa reduzir o estado representado, não acrescentar compressão ao arquivo.
`SnapshotRegistry.capture` percorre o grafo, valida e retorna também `encoding`;
`pack` e `restore` já aceitam esse encoding para o mesmo envelope imutável.
Não duplicar essa otimização já existente. `ExpeditionService` ainda usa captura,
restauração de staging, recaptura e, em comandos de campanha, segunda restauração.
Esse staging conserva regras da operação no mundo vivo e não pode ser substituído
por uma retomada que cure/reposicione inimigos durante uma coleta ou um portal.

O primeiro delta de C0 reaproveita na retomada a validação concluída por
`ExpeditionCheckpointCodec.unpack`. A fronteira só muda a autoridade externa
para o perfil corrente e `SnapshotRegistry.restore` confere esse vínculo.
Recebimento de checkpoint, verificação de bytes/versões, replay e writer
continuam obrigatórios. O ganho de tempo no Bosque ainda precisa de medição
pareada. Na fixture F4, o trecho de restauração do mesmo grafo de 327.372
bytes passou de 384,5 para 114,0 ms na mediana de seis execuções por caminho,
com ordem alternada. A medição começa após o decode e não inclui I/O, mapa ou
instalação. Evidência
`.godot/verification/p7/pre_p8_integracao_01/resume_cost_local/output.log`.

O journal já evita captura completa em mortes/coletas normais e usa writer em
segundo plano quando solicitado. Ainda prepara candidatos/cópias no quadro;
`journal_collect` exige fim do combate e usa lotes pequenos; o limite de 256
entradas provoca compactação por checkpoint. Separar atraso intencional de
coleta, fila de commits e pausa de CPU. Não mudar a regra de coleta por inferência.

**Primeiro pacote independente da nova regra de retomada:** instrumentar esses
caminhos e eliminar somente cópia/validação/encoding comprovadamente repetidos
sobre o mesmo valor privado imutável e a mesma revisão. A instrumentação pode
iniciar assim que a coordenação registrar dono e base; otimização depende da
medição. Não remover validação em entrada externa, reutilizar prova após mutação,
nem aplicar cache de perfil por mera igualdade de referência. Isso pode reduzir
lag de drops sem resolver preparação fria do mapa. Não prometer ganho antes do
comparativo pareado. Mover serialização pura para o worker só após congelar DTO;
Nodes, Resources mutáveis e consultas ao mundo permanecem no dono da simulação.

### Dados compactos e interfaces

Reservar transporte `format: 3` e `compact_schema: 1`; não reinterpretar formatos
1/2. Um envelope compacto contém apenas valores puros, com limites explícitos,
validação estrita e encoding canônico. A implementação registra limites por
seção antes do consumidor; conservar no máximo os limites atuais de transporte,
sem aumentar memória/bytes automaticamente. Contrato mínimo:

| Seção | Conteúdo obrigatório |
|---|---|
| Identidade | expedition/run/character IDs, lifecycle, revisão, session/last_committed_seq, owner_digest, schema e versão semântica de regras |
| Reconstrução | seed, phase/stage IDs, versão do gerador, revisão e hash da composição publicada, ordem/IDs e escolhas realizadas na montagem |
| Campanha | estágio atual, último portal/âncora, objetivos e portais liberados, mácula, estágios visitados/limpos, relógio/onda, mortes e recibos |
| Vagas | slot_id estável, stage_id, generation, life_state, origem/superfície pela composição e dados de pending/onda; espécie/ocorrência verificáveis |
| Personagem/run | posição 3D/superfície/facing, HP/SP e déficits, recargas, build/augments/ofertas, estados pessoais e durações, RNGs e contadores causais |
| Aquisições | tickets congelados pendentes, entregue/recibos, event_id, sequência e sessão; nenhuma reexecução do sorteio |

Guardar escolhas realizadas quando seed+versão não bastarem para reconstrução
exata. Recursos publicados precisam continuar disponíveis por revisão; não ler
fontes mutáveis do editor nem usar a composição atual em substituição silenciosa.
Revisão indisponível falha sem alterar perfil/slot/backup. Não serializar geometria,
rotas/cache de navegação ou apresentação quando são deriváveis da composição.

Interfaces propostas: `capture_compact(host, barrier)` retorna DTO e encoding
validados ou erro de elegibilidade; `restore_compact(record, facade)` produz
staging desativado ou erro; instalação/ativação continuam subordinadas ao commit
e à reconciliação existentes. Nenhuma referência de objeto atravessa o transporte.
`request_id` identifica intenção; `expected_revision` continua obrigatório.

### Corte seguro, referências e casos ainda não autorizados

A decisão humana cobre vivos na origem, HP cheio e sem efeitos e a conservação
do personagem. Não autoriza cancelar habilidades, invocações, projéteis ou
benefícios pessoais, mudar custos, conceder invulnerabilidade ou deslocar jogador.
A v1 deve ter elegibilidade conservadora explícita, sem perda silenciosa:

- Capturar em barreira, após ordenar eventos de morte/onda e resolver transação
  durável pendente. Nenhum relógio avança durante captura, staging, suspensão ou
  espera por confirmação; não usar relógio de parede para atualizar respawn.
- Uma ação em curso, projétil, área, invocação, construção, canal ou efeito pessoal
  que dependa de inimigo precisa de serializer e política próprios. Até existir
  cobertura, o corte é `compact_cut_unrepresentable`; manter o caminho exato
  vigente para essa operação, identificando o formato efetivamente salvo.
  Isso é rollout parcial seguro, não cumprimento universal da retomada compacta.
- Referências meramente de seleção/mira são descartáveis apenas se não tiverem
  custo, ação ou efeito pendente. Referências persistentes usam slot+generation,
  nunca instance_id; alvo morto ou geração diferente não pode ser redirecionado
  a outro inimigo. Não limpar ledger/claims cuja vida ainda alcance ações salvas.
- Antes de escolher formato 3, provar que posição e corpo do jogador e cada
  origem dos vivos coexistem nas superfícies corretas com ocupação canônica.
  Origem ocupada por jogador, aliado ou outro vivo torna o corte inelegível;
  não usar `spawn_slot(force=true)` para contornar essa prova. Repetir a prova na
  restauração; falha preserva o checkpoint, sem instalação parcial.
- Vivos recompostos conservam slot e generation e voltam ao estado inicial da
  espécie na origem: sem ameaça histórica, alvo, dano ou efeitos anteriores.
  A IA reavalia percepção/aggro normalmente no primeiro tick liberado; retomar
  perto de um inimigo não concede período de segurança. Estado pessoal de combate
  com bloqueios/relógios permanece representado; não zerar recarga de consumível
  ou liberar coleta apenas por limpar ameaça. Se essa distinção não for possível
  no serializer v1, corte inelegível até haver cobertura.

Uma solução que aceite todos os cortes exige decisões adicionais sobre colisão
na origem e entidades/ações dependentes. Opções como inimigo vivo aguardando
origem livre (sem incrementar generation), reposicionamento próximo ou cancelamento
com/sem reembolso alteram produto. **Default seguro enquanto pendente:** conservar
save exato nesses cortes, e erro recuperável se um compacto já existente não
puder ser instalado. Não converter vivo em `respawn_pending`: o estado existente
representa outra geração e outra semântica. Esse default permite iniciar produtor
sem inventar essas escolhas; ampliar cobertura não deve ficar oculto no aceite.

### Morte, journal e atomicidade

Aplicar base mais journal integralmente ao modelo lógico antes de escolher quais
inimigos recriar. Isso impede que morto registrado no journal reapareça vivo por
constar vivo na base. Ordenar mortes antes de ondas conforme serviço atual;
recibos/tickets e RNG pós-evento são efeitos resolvidos, nunca comandos para
sortear de novo. Respawn admitido mantém sua geração registrada; morto pendente
não nasce pela simples retomada; bosses e portais seguem a regra atual.

Manter um writer/ProfileStore e o protocolo existente de candidato privado →
gravação → confirmação → publicação. Resultado incerto mantém staging congelado
e bloqueia nova intenção até reconciliação. Retry conserva request/fingerprint,
IDs, sequência, ticket e payload; não dobra XP, gold, item, carta ou morte.

Compactação do journal grava nova base e zera o journal na mesma transação de
perfil, somente após absorver todos os efeitos do prefixo confirmado. A nova raiz
usa o digest da nova base; nunca anexar uma cauda à raiz antiga nem apagar journal
antes do commit. Falha deixa base+cauda anteriores recuperáveis. Reutilizar codec
de journal apenas se a interpretação dos payloads continuar idêntica; adicionar
versão/adaptador explícito se mudar. Não executar `_journal_replay` em um mundo
que já recebeu os mesmos efeitos pelo modelo compacto.

### Compatibilidade real, sem promessa de migração implícita

`ExpeditionCheckpointCodec.unpack` aceita transporte 1/2, mas chama
`SnapshotRegistry.validate`: engine e mapa de digests de fontes devem coincidir
exatamente, além dos assets. Alterar scripts desta implementação pode invalidar
leitura de um grafo antigo mesmo preservando o decoder. A frase "manter leitura"
significa **na revisão compatível**, não compatibilidade cruzada já disponível.

Não afrouxar o digest para abrir grafos desconhecidos. Default de rollout: perfil
de fixture separado; preservar save e build anteriores para retomada de 1/2.
Sem migração pessoal automática. Conversão exigirá exportação validada pelo build
que entende o grafo antigo e importação por DTO contratado, ou adaptador específico
com fixtures de origem; consumidor deve detectar incompatibilidade e comunicar
recuperação sem substituir a expedição. Novo formato usa versões semânticas de
schema/regras/gerador/composição; isso não permite ignorar incompatibilidade de
conteúdo nem garante migração futura. Decidir a política de distribuição desses
assets antes de prometer saves portáveis entre builds.

### DAG mínimo e propriedade antes do dispatch

| Pacote | Dependência e resultado verificável | Dono proposto / arquivos |
|---|---|---|
| C0 — custo preservando semântica | Base exata do candidato; métricas por etapa, primeiro ganho comprovado sem mudar formato/retomada | Sol; service/registry/profile pipeline e sonda, lista exata registrada antes de editar |
| C1 — produtor compacto | Este contrato e fixtures de cobertura; codec/DTO, elegibilidade, reconstrução desativada e provas de journal/compatibilidade | Sol; novo codec e testes, depois integração sequencial em service/campaign |
| C2 — consumo e release | C1 aprovado e C0 medido; escolha de formato por operação, recuperação, UI de incompatibilidade, comparação nativa | Sol na persistência; Terra somente UI estável; dono único por arquivo |

C0 e desenho/fixtures puros de C1 podem ser independentes; integração em service,
registry/campaign e testes compartilhados é sequencial. C2 aguarda C1, não programa
contra API presumida. Não criar chats, iniciar P8 ou reservar arquivos de outros
executores por esta tabela. Coordenação registra SHA efetivo, alterações P7,
arquivos exclusivos, modelo/esforço e critérios no índice antes do dispatch.
Luna acompanha testes, Sol consolida invariantes; sem gate Astra rotineiro.

Critérios C1/C2: fixture por formato suportado e incompatível; corrupção/truncamento;
seed igual com composição diferente; slot/generation inválidos; vivo/morto/pending;
journal cheio e morte+onda; tickets já entregues e pendentes; retry/resultado
incerto em cada fronteira de commit; colisão na origem e alturas distintas;
corte com habilidade/invocação e efeito pessoal dependente; pausa e relógios;
nenhum reset de HP/SP/CD/build do jogador; instalação falha sem mutação durável.
Instrumentar proporção de cortes inelegíveis: fallback frequente é limitação de
produto e desempenho, não PASS de cobertura compacta universal.

### Plano de medição e limite desta entrega

Na Floresta do Santuário seed 42, perfil descartável e mesmo conteúdo/engine,
medir por operação/request_id: espera por elegibilidade, barreira/captura,
validação/encoding, cópia de perfil, compressão/hash, fila do writer, serialização,
I/O/commit, publicação, decode/replay, geração/geometria/navegação/população e
instalação/apresentação. Registrar wall time e bloqueio da thread principal
separadamente; intervalos assíncronos podem se sobrepor e não devem ser somados
como tempo de quadro. Contar bytes e objetos/vagas/tickets/entradas do journal.

Cenários pareados: frio e quente, entrada, saída/suspensão, retomada, morte com
múltiplos tickets, coleta fora de combate, journal próximo do limite e falha/retry.
Relatar amostras, p50/p95/máximo de quadro e morte→commit→publicação; separar espera
legítima até fim de combate. Linha de base e candidato precisam de SHA e hash dos
inputs efetivos, incluindo alterações locais. Não atribuir preparação fria ao
save nem chamar redução de bytes de ganho de fluidez. O C8 acima é contexto,
não uma medição dessas parcelas. Outros agentes executam as sondas nativas.

A rodada de arquitetura conferiu APIs e links. Os resultados da sonda e do
primeiro delta de C0 estão no [registro de retomada](e08.md). Elegibilidade
parcial e migração entre builds continuam como limites do formato proposto.



## Implementação C1 — estado em 13/11/2026

Retomada da implementação iniciada pelo Codex, no mesmo checkout e base. Nada
foi commitado; o conjunto está na árvore de `codex/e08`.

### O que está implementado

- `scripts/core/expedition/persistence/compact_expedition.gd`: produtor
  (`capture`), envelope (`decode`), preparação da composição (`prepare`/`matches`)
  e reconstrução (`rebuild`/`spawn`). O formato 3 usa transporte próprio em
  `ExpeditionCheckpointCodec.pack_compact`; `unpack` exato recusa o formato 3.
- **Desvio registrado do contrato:** o payload não é um DTO puro com
  `compact_schema`. É o grafo do `SnapshotRegistry` com uma projeção que exclui
  inimigos, geometria, população e manifesto, mais a origem da composição e
  `version: 1`. O personagem continua com os descritores exatos (habilidades,
  estados, RNG, build). Consequência: o formato 3 também depende dos digests de
  scripts e não é portável entre builds, como os formatos 1/2.
- Origem da composição: fase gerada guarda fase, seed, revisão do gerador e hash
  canônico; fase publicada guarda fase, `phase_hash` e os pins de release de cada
  mapa. Composição indisponível ou diferente falha com
  `content_revision_unavailable` antes de qualquer alteração durável.
- Uso: entrada na expedição (com restauração de ensaio antes do commit),
  suspensão no lobby e compactação do diário de recompensas. Corte inelegível
  grava o formato exato vigente.
- Elegibilidade conservadora com motivo em `detail` e contagem por processo em
  `cut_tally`: eventos/fila de nascimento pendentes, projétil ou efeito vivo,
  ação do jogador (cast, dash, invocação pendente), inimigo fora da população,
  geometria temporária, referência do grafo a inimigo e origem de vivo ocupada.
- Retomada: diário aplicado ao modelo lógico antes de recriar vivos; mortos e
  `respawn_pending` não renascem. `spawn_slot` sem `force` repete a prova de
  ocupação da origem; falha descarta o staging sem instalação parcial.

### Correção desta rodada

A captura de fase publicada lia `seed_text`/`generator_revision`, ausentes no
manifesto composto, e gerava erro de script. O jogo caía silenciosamente no save
exato: na Floresta do Santuário o formato 3 nunca era gravado. A origem
publicada agora é `{phase, hash, pins}` e `decode`/`matches` validam cada forma.

### Ensaio antes de gravar (decisão de 13/11)

Decisão do usuário em 13/11: a suspensão e a compactação do diário ensaiam a
retomada antes de substituir a base durável. `ExpeditionService._rehearse_compact`
decodifica o envelope, confere a composição contra o manifesto vivo já validado,
restaura o grafo fora da árvore com reconstrução e spawn, confere sessão e
população e descarta o resultado. Ensaio que falha não grava formato 3: o mesmo
corte é recapturado no formato exato sob a mesma barreira e conta
`rehearsal_failed` em `cut_tally`. A releitura da composição publicada/gerada em
disco continua só na retomada pedida pelo usuário. Desde 14/11, uma fase publicada
já preparada no mesmo processo, com a mesma definição e as mesmas fixações, vem do
cache de sessão de `PhaseRelease.prepare`. Os pacotes fixados são imutáveis por hash,
então o resultado é o mesmo da releitura.

Correção feita junto: o caminho compacto de `checkpoint()` montava a autoridade
do perfil no momento do commit, e um corte capturado antes de outro commit
nunca era recusado como `stale_revision`. A autoridade agora é a registrada na
captura, como no formato exato, e o corte velho é recusado antes do ensaio.

### Limitações conhecidas

- O ensaio usa a composição viva; uma composição em disco alterada ou ausente só
  aparece na retomada, como `content_revision_unavailable` recuperável.
- Cobertura dirigida dos cinco casos em `tests/e08_compact_coverage_test.gd`
  (14/11, 95/95; ver [registro](e08.md)). Limites da cobertura:
  - a Travessia em Ruínas tem uma vaga de lixo por estágio, então a morte gravada
    junto com a onda é a do jogador; morte de inimigo + onda de outra vaga na
    mesma escrita não é reproduzível nessa fase;
  - a falha na entrada é exercitada pelo serviço (`enter` + `reconcile`), não pela
    tela de seleção;
  - os resultados exercitados são os do gravador da fixture F2: falha definitiva
    (`replace`), escrita feita com erro e leitura visível (`after_replace`, confirmada
    na hora) e escrita feita com leitura oculta (`lost_ack`, incerta até o
    `reconcile`). Sem escrita e com leitura oculta, o gravador descarta o pendente
    e o resultado vira definitivo; o `before_unknown` do F4 não existe nessa fixture.
- Medição pareada nativa feita em 14/11 ([registro](e08.md)): perfil 581 → 167 KB,
  suspensão 8,1 → 7,1 s, mas a retomada sobe de 20,7 para 29,6 s com a reconstrução.
  Com o cache de sessão da fase preparada, a retomada no mesmo processo cai para
  18,3 s (C8: 20,9 s). Com o jogo reaberto, ainda paga ~11 s de preparação. O novo
  release integrado continua pendente.
