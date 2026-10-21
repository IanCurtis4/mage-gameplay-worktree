# E07-F6 — API de ameaça e participação

21/10/2026. Contrato aprovado e manifesto de propriedade em [f6_dispatch.md](f6_dispatch.md).
Validação final em andamento. Sem UI nova, rede ou novas habilidades.

## Autoridade e entradas

Cada EnemyActor possui um ThreatService próprio; fonte, dono e grupo têm strings
estáveis dentro da expedição, separadas da identidade local de Node. O jogador
real usa player/player/local_party. Companheiros hostis existentes são inimigos
com ledger próprio, não cópias da ameaça do mestre. Fontes adicionais são provas
sintéticas; F6 não introduz pet aliado ou segundo jogador jogável.

ThreatService.register(id, owner, group) fixa identidade sem criar vínculo hostil.
engage(source) registra o grupo realmente adquirido; linked(group) consulta esse
vínculo enquanto houver participante vivo. eligibility(id, alive, visible) controla
alvo, sem apagar valores/recibos. Grupos não relacionados não entram em combate
por terem sido cadastrados. disengage() encerra vínculo/fixação após leash;
conserva valores/claims e não cura ninguém. Suspender/descarregar não chama essa API.

observe(event, kind, source, effective, divisor=1, parameter=0, immune=false)
aceita damage, heal, taunt e reduce. O evento estável é claimado antes da mutação;
replay idêntico retorna already_applied e não avança revision; payload divergente
retorna request_conflict. Fonte inválida, número negativo/não finito, divisor zero,
parâmetro fora do contrato ou soma não representável falham sem claim/mutação.
Regra desconhecida falha unsupported_threat_rule, sem coeficiente inventado.

Dano usa HP efetivamente removido (1x), incluindo cada DoT/efeito secundário
confirmado. Cura usa HP efetivamente restaurado (0,5x/divisor); overheal gera zero.
HealthState permanece a autoridade: EffectProcLedger já impede reaplicação causal;
a sequência local de aplicação confirmada identifica o evento de ameaça. As
sequências entram no snapshot e não reiniciam no revive. A cura atual é própria
nas habilidades existentes; o sinal healed transporta valor real/sequência. O
controller congela a lista de inimigos vivos engajados do grupo local antes de
dividir. Cura fora dessa lista não abre vínculo por inferência.

EnemyActor registra a aplicação no próprio callback de HealthState, antes dos
consumidores do controller; o ledger funciona também em ator isolado. Fonte pet
mantém valor individual e owner separado, sem duplicar o crédito no dono. DoT
já emitido conserva crédito/claim após morte da fonte; fonte morta não é alvo.

## Alvo, provocar e redução

Troca normal somente acima de110% do valor atual. Igualdade conserva atual;
sem atual, maior ameaça elegível e desempate pela string estável. Elegibilidade
usa a mesma geometria de alcance/oclusão e aquisição/ocultação existentes. Perder
visão conserva lista; AI mantém perseguição/sight timeout/leash existentes.
Ameaça não calcula dano, não altera alcance e não concede bônus de altura.

Provocar usa o caster real registrado, eleva ao maior valor e fixa pelo parâmetro
de duração. O caller mantém custo, alcance, LoS e imunidades já contratados;
o parâmetro immune permite a prova de veto, sem inventar imunidade de boss.
A habilidade atual não tinha nova imunidade de taunt a ser adicionada em F6.
Pausa/estágio ausente/suspensão congelam a duração. Expiração volta ao limiar.
Troca efetiva atualiza o alvo do EnemyActor e cancela cast preparado, sem
redirecionar o request já capturado, reembolsar custo ou limpar cooldown.

reduce aplica a fração parameter no intervalo[0,1]; não remove vínculo do grupo.
Não há botão/habilidade nova consumindo essa regra: prova por fixture. Morte
remove elegibilidade/fixação da fonte nos estágios, preservando crédito/claims.

## Participação, DTO e persistência

CombatParticipation claim_event registra o evento confirmado antes do fan-out de
cura, inclusive fora de combate, congelando a decisão de destinatários. Replay
não renova o atraso nem atribui uma cura antiga a inimigos engajados depois.
Eventos de dano recebido/aplicado usam as sequências de HealthState e a identidade
estável do inimigo; recibos de participação entram no mesmo snapshot.

CombatParticipation conserva vínculos reais e cinco segundos sem vínculo/dano.
Alvo atual, ameaça zero e estágio limpo são consultas distintas. encounter_active
continua a adaptação única para ofertas, trocas, coleta e regeneração de HP,
conservando os locks transacionais e exceções treino/admin já existentes.

view() retorna ThreatView novo: enemy_id, current_id, forced_id, forced_remaining,
engaged, revision, switch_threshold e entradas ordenadas com id/owner/group,
amount/alive/eligible. Alterar o DTO não muda gameplay. UI F7 deverá consumir
esse DTO; nenhuma UI de ameaça é entregue por F6.

O manifesto F3 enumera ledger, grupos, valores, fontes/atores, sequência de
provocar, duração, claims e sequências de HealthState. SnapshotRegistry valida
estruturas/valores/referências antes de capturar e após reconstruir. Referências
de ator são remapeadas pelo registry; IDs estáveis de participante conservam-se.
Writer F4 confirma o mesmo corte de mundo/perfil/recibos. Revisões exatas e limite
4MiB permanecem: não truncar ledger para caber, nem prometer migração entre builds.
Claims crescem com os eventos da expedição, sem reset por viagem/suspensão.

Compatibilidade de prova legada: enemy_id e recibos outgoing de trial/demo
seguem gramáticas fechadas de identidade do registry, como occurrence_id.
IDs locais são substituídos por referências estáveis no envelope e remapeados
na reconstrução; contadores/sequências e IDs de expedição de produção não são
interpretados como Node IDs. A prova exige ausência do ID local no snapshot e
replay inerte do recibo reconstruído.

Provocar aceito notifica participação no mesmo callback, antes de ofertas/trocas/
coleta; não aguarda o tick seguinte. Falha de aplicação não publica debuffs.
O recibo taunt usa a identidade estável do inimigo e a sequência já capturada.
