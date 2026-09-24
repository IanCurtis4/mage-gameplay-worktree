# Gate Astra — E05-S2-SP0

Proposta e92b7c5 aprovada como contrato inicial de implementação, com os
esclarecimentos abaixo prevalecendo sobre trechos ambíguos da proposta.
Cinco ativas e duas passivas por destino, quatro builds e orçamento conferidos:
13/19 base, 15 ou 16/20 evolução, cinco ativas/dois passivos em cada build.
Tuning inicial aceito para implementação e posterior playtest; não é evidência
de balanceamento. Nenhum kit ou destino foi habilitado por este gate.

## Contratos fechados

- Contraforte aprovado como golpe e janela frontal de 1,2 s. Guarda e Avanço
  usam arco de 130 graus; direção capturada na ativação, nunca gira para
  acompanhar o mouse durante a janela. Contraforte: cone de golpe de 90 graus,
  raio 120, com geometria compartilhada por preview/hit-test e obstáculos.
- Token único é mecanismo do Contraforte aprendido na identidade Defendente,
  não passiva global gratuita para outras classes. Funciona mesmo com a entrada
  fora da barra; só Contraforte/Onda equipados podem gastá-lo. Resguardo exige
  sua própria passiva equipada. Eventos secundários, custo de HP e escudo sem
  origem frontal válida não concedem token/SP. Uma ocorrência conta uma vez.
- Avanço de Muralha causa dano: classificar como OFENSIVA e encerrar Parede
  antes do movimento validado, como Salto Cruento. A mitigação própria de 20%
  dura apenas o deslocamento. Marco é defensivo; Trava, Contraforte e Onda são
  ofensivos. Movimento comum e Investida base conservam o contrato E04.
- Marco concede DEF nas duas defesas, mas nenhuma mitigação direta global.
  Onda: se há Marco ativo, emitir apenas no Marco; sem Marco, no jogador.
  Uma zona por dono, limpeza no fim de encontro/morte/run. Não duplicar pulso.
- Ferida pertence à Ruptura aprendida na identidade Berserker; uma por dono/alvo.
  Sem Ruptura aprendida, passivas não criam marca. Dano melee direto pode
  alimentar a marca existente; dano secundário jamais cria/renova/alimenta.
- Reativação Ruptura captura cargas/poder no commit e resolve um único pedido
  físico secundário com precisão CONTESTED. Se actual_damage for positivo,
  remover a marca uma vez; erro/absorção total preservam marca e prazo original.
  Recursos comprometidos não são devolvidos. Execução captura cargas anteriores
  no poder do único golpe direto; só consome após HP positivo, sem adicionar
  carga. Nenhum segundo pedido de dano para o bônus da Execução.
- Custo da Execução = max(1, ceil(0,03 * max_hp efetivo)), exige HP atual maior
  que esse custo. Cobrança no commit após validar todos os recursos/alvo; não
  atravessa HealthState como dano nem dispara procs. Os percentuais de HP do
  alvo usam estado imediatamente anterior ao impacto; limiar inclusivo 35%.
- Knockbacks de normais propostos: 35 unidades, validados pela navegação,
  sem atravessar obstáculos. Boss conserva dano e não desloca. Não inventar
  imunidade global nova nem orçamento CC paralelo ao existente.
- Custos, ranks e recargas da proposta são tuning inicial. Fenda usa preparo
  variável 0,3 s; demais novas ativas inicialmente instantâneas. Pausa congela
  timers; morte, fim de encontro/run limpam estados transitórios.

## Próximo pacote autorizado: SP1 — Sol

Implementar apenas a fronteira mínima de identidade de evolução nos catálogos
 e consultas usadas por preview/snapshot/HUD/runtime. Primeiro auditar o que
já transporta evolution_id; reutilizar e evitar IdentityRuntime genérico.
Deixar content_ready=false em produção. Nenhuma skill, token, ferida, UI nova
ou mudança de combate neste pacote. Fixtures isoladas provam a resolução de
biblioteca base + biblioteca exclusiva correta, sem herdar outra origem.

Antes de persistir IDs novos de produção, registrar decisão de versionamento
com evidência de leitura dos saves existentes. Metadados sem novos ranks
persistíveis não exigem migração; não reescrever saves reais nem elevar schema
por precaução. Mudança semântica futura exige migração explícita e revisão.

Entregar commit, handoff SP1 com API concreta, testes positivos/negativos de
identidade, paridade de consumidores afetados e regressões pertinentes.
Executar verify.ps1 para delta de runtime. Parar no gate antes de SP2.
SP3/SP5 devem ser subdivididos por habilidade/comportamento; não são autorização
para implementar quatro skills de uma vez. Luna só recebe tabelas já fechadas.

Revisão documental: contrato E00/E05 e handoffs SW1/SW5 conferidos; aritmética
das quatro builds revisada. Não executar Godot por este parecer documental.
