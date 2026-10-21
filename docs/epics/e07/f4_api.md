# E07-F4 — API de checkpoint durável

21/10/2026. Contrato de execução: [despacho](f4_dispatch.md).
Consome [snapshot F3](f3_api.md) e [posse F2](f2_api.md).
Não entrega UI de lobby, entrada/ondas/morte/conclusão de produção (F5/F7).

## Autoridade e formato

ProfileStore permanece o único writer: primary/pending/backup, revisão otimista,
validação antes do rename e reconciliação por igualdade do candidato completo.
O envelope raiz continua schema8/catalog14/stat_thresholds_v1. A reserva F2 de
cinco campos permanece legível; a extensão de sete campos adiciona checkpoint e
receipts tipados. Leitores F2 anteriores rejeitam essa extensão como
invalid_expedition_slot e preservam os bytes. Não há conversão de bens ou migração
pessoal. O formato interno do checkpoint é1 e rejeita versões futuras.

ExpeditionCheckpointCodec transporta o envelope F3 com var_to_bytes, DEFLATE e
base64 no mesmo JSON do perfil; não mantém um serializador de atores paralelo.
Inteiros64/RNG e tipos Variant não passam por números JSON. A decodificação de
objetos nativos permanece desabilitada. Tamanho descomprimido explícito limitado
a4 MiB, digest SHA256 e base64 canônico são conferidos antes da restauração.
O perfil inteiro conserva o limite4 MiB; exceder falha sem cortar mundo/recibos.
Não existe arquivo independente confirmando bens e mundo em ordens distintas.

O checkpoint contém sessão/cursor e digest dos bens/personagem do dono. Alts
podem avançar a revisão global durante uma suspensão. Retomar exige identidade,
digest e compatibilidade e só então religa a autoridade externa/revisão atual
consumida por SnapshotRegistry; o grafo e seus claims não são reescritos. Runtime,
conteúdo e engine precisam satisfazer a matriz exata de versões de F3. Uma
revisão indisponível não cria run nova nem descarta o checkpoint.

## Operações

`ExpeditionService.new(facade)` coordena o writer existente.

- `checkpoint(controller, barrier, expedition_id, phase_id, request_id,
  expected_revision, suspend=false)`: exige corte coerente com barreira F3;
  captura e valida todo o grafo e grava o mesmo candidato que os recibos.
  A primeira chamada anexa uma sessão existente à reserva tipada; criação da
  expedição/campanha é F5. Identidade/fase não podem mudar numa pendência.
- `commit_cut(controller, snapshot, expedition_id, phase_id, request_id,
  expected_revision, suspend=false)`: consome o corte congelado obtido de F3.
  Não autoriza fabricar estado externo ou capturar no meio do tick.
- `collect(controller, barrier, ticket_id, request_id, expected_revision)`:
  consome exclusivamente ticket emitido pela autoridade RunRewardService.
  Prepara bens pela mesma rotina pura usada pelo grant legado e aplica o claim
  numa cópia passiva do grafo. Persiste perfil, cursor, mundo pós-coleta e recibo
  juntos; só depois aplica ao host e emite reward_confirmed. O collector legado
  retorna checkpoint_required se houver expedição, impedindo commit separado.
- `resume(expedition_id, character_id, request_id, expected_revision)`:
  valida/reconstrói passivamente antes de gravar active e selecionar o dono.
  Entrega root/registry/snapshot para install/activate explícitos de F3. O
  consumidor assume a propriedade da raiz e descarta uma restauração rejeitada.
- `reconcile(request_id)`: resolve somente a intenção incerta retida pela mesma
  instância do serviço. Outro comando permanece bloqueado. Se confirmado,
  publica o mesmo claim uma vez; se conhecido não gravado, libera retry do corte.

Requests são persistidos com operação/fingerprint/revisão; retry igual não
repete o grant, payload/operação/expedição diferente retorna request_conflict.
Recibos não são truncados. Perfil/lock/dono e sessão são revalidados em cada
fronteira; controle de UI não substitui essa autoridade.

Suspender conserva o grafo e retira apenas a sessão global ativa, liberando os
alts. O dono continua bloqueado para mutações do lobby. Abrir um perfil com
checkpoint ativo preserva reward_session em vez de encerrar como abandono.
end_run/grant legados não podem apagar ou pagar uma expedição à parte.

`RunController.request_durable_suspend(...)` agenda o corte no fim do tick pela
barreira F3 e mantém o host congelado. Falha não troca cena nem afirma save.
Uma suspensão confirmada é substituída pela raiz restaurada; release não pode
reativar o host antigo suspenso. Em falha incerta, o resultado conserva
transaction_service para reconciliar sem perder o contexto. Navegação/UI são F7.

## Crash e recuperação

Antes do rename, primary é o corte durável. Depois dele, é o candidato completo.
Falha de acknowledgment não é prova de rollback. Reconciliation compara o
candidato inteiro e conserva comandos bloqueados enquanto a gravação é incerta.

Reabertura com pending não confirmado entra em recovery_required.
`ProfileFacade.recover_expedition_pending()` usa o mesmo ProfileStore: exige
primary/pending válidos, mesma identidade, revisões consecutivas e transição
válida; arquiva os bytes exatos em profile.uncommitted.<sha256>.json antes de
retirar pending e selecionar o primary. Não promove pending sem commit nem
inventa confirmação de loot. Evidência divergente/ilegível permanece protegida.
Uma intenção ainda incerta no processo usa reconcile; não chama esse recovery.

Backup recupera um corte completo. Schema/versão de checkpoint futura, erro de
posse/digest/estrutura/limite preservam primary em leitura/recuperação, sem cair
silenciosamente para corte material mais antigo. Mudança de conteúdo detectada
na restauração também conserva dados. Não há relógio de parede nem avanço offline.

## Política e limites

Checkpoints são explícitos e transacionais. Não se definiu intervalo periódico,
redução de precisão ou orçamento de autosave: a captura F3 custa segundos nas
fixtures. O último corte confirmado é o ponto recuperável após crash; frames
posteriores não gravados podem ser perdidos. F5 deve usar essa fronteira ao
publicar fontes/recompensas e mudanças de mundo. Nada aqui cria ondas, revive,
quests, bônus ou política nova de gameplay. Compatibilidade entre builds/export
release exige revisão própria; não se promete migração de grafo desconhecido.

Erros incluem tick_barrier_required, checkpoint_incomplete, invalid_checkpoint,
checkpoint_version_unavailable, checkpoint_assets_mismatch,
checkpoint_reload_required, content_revision_unavailable, snapshot_too_large,
profile_too_large, not_owner, invalid_session, expedition_conflict,
stale_revision, request_conflict, save_in_progress e recovery_required.
