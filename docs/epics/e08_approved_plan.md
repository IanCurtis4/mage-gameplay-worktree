# E08 — plano aprovado e autorização de execução

Decisão humana em 5/11/2026 nesta conversa de arquitetura: implementar o plano
E08 apresentado, com chats Sol/Terra e supervisão Luna. Este documento registra
a decisão posterior ao brief `e08_opening_2026_11_05.md`; WORKFLOW rege a execução.

## Base e limites

Base inspecionada: `c8b80b13d29c468afb7f2ad7ba75eec838e7df32`, contendo o runtime
F10 aceito `2ff1c00f923e3811b0aa7ebcbeddafe7731d640f`. Checkout de execução:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
Reutilizar este checkout na branch de composição `codex/e08`, após preservar
estado e os quatro backups locais de autoria. Não criar terceiro checkout.
Principal, alterações locais e saves pessoais permanecem preservados.

Execução autorizada até o piloto P3; P4–P6 dependem do aceite visual humano de
P3. Planejar e registrar todos os pacotes agora; despachar somente quando suas
dependências estiverem satisfeitas. E09+, master/push, novas classes, economia,
multiplayer, migração de saves e cenário 3D não estão autorizados por este plano.

## Arquitetura aprovada

- Aprimorar linguagem visual e renderer existentes, sem substituição geral.
- Manter CharacterAnimation/CombatAnimationState, 32 células de 64×64,
  pivô-base (32,58), frente/costas e espelhamento; caminhada por deslocamento,
  anexos de equipamento e relógio exclusivamente visual.
- VFX consome eventos confirmados e geometria/altura/alvo/duração canônicos.
  Adaptadores somente onde faltar informação; sem dano, fórmula, hitstop de
  simulação ou alteração de timing de combate na apresentação.
- Cenário preserva geometria, rotas, populações e encontros. Republicação
  necessária usa compilador existente e nova revisão imutável.
- Áudio: serviço de apresentação, catálogo de eventos, canais Geral/Efeitos/
  Interface/Ambiente; sem música. Sem duplicação por reconexão/retomada.
  Pausa congela efeitos/ambiente do mundo, mantendo interface; troca de estágio
  encerra sons anteriores; retomada reinicia ambiente sem impactos históricos.
  Volumes em configuração local separada do save de gameplay.
- Definições imutáveis; instâncias por ator/estágio. Proveniência, licença,
  fontes, consumidores e import/export rastreáveis. Limites cosméticos nunca
  ocultam indicadores essenciais de perigo, alvo ou área.

## Pacotes e delegação autorizada

| ID | Executor | Esforço | Resultado / propriedade inicial | Dependência |
|---|---|---|---|---|
| P0 | Sol Integração | Médio | Contratos, inventário, índices, runner, embalagem, comparação de custo e coordenação operacional | Aprovação registrada aqui |
| P1 | Sol Apresentação | Alto | Adaptadores, ciclo de vida, pausa/retomada, componentes comuns e ligações em atores/controlador, testes próprios | P0 |
| P2 | Sol Áudio | Alto | Serviço, catálogo, canais, vozes, configuração local, eventos e testes | P1 |
| P3 | Terra Piloto | Alto | Mago, inimigos comuns/chefe da floresta, cenário, VFX e primeiros sons; assets/receitas e comparação visual | P2 |
| P4 | Terra Personagens | Médio | Dez identidades, anexos, equipamentos e ícones existentes | Aceite humano P3 |
| P5 | Terra Mundo | Médio | Espécies dos mapas publicados, materiais, props e ambiente do Bosque/floresta | P4 |
| P6 | Terra Feedback | Alto | Receitas e consumidores estabilizados de VFX/áudio para kits atuais | P5 |
| P7 | Sol Integração, mesmo chat P0 | Alto | Consolidação, correções, medições, release e playtest | P6 |

Usar Sol 6.1, Terra 6.1 e Luna com os esforços acima/baixo para supervisão.
Esforço é estimativa de raciocínio por risco, não medição de horas/tokens.
P0 é explicitamente o coordenador operacional autorizado a criar/despachar
os chats delimitados P1–P3 sequencialmente e preparar P4–P7 para o gate humano.
Não criar chats consumidores ainda bloqueados apenas para reservá-los.
Luna supervisiona testes nos checkpoints P1/P2, piloto e candidato final:
conclusão, erros, timeouts e hashes. Falhas retornam ao Sol responsável.
Sem alteração de expectativas para ocultar falhas nem auditoria Astra rotineira.

Antes de cada dispatch, P0 registra SHA completo, contrato, branch, checkout,
lista exata de arquivos permitidos, dono exclusivo, APIs, testes e aceites.
Compartilhamento de arquivo é sequencial com transferência registrada. Terra
devolve mudança de contrato a Sol Apresentação. Usar uma fixture reutilizável.
Registrar entregas e hashes integrados; arquivamento só após validação/integração.

## Inventário, piloto e aceites

P0 registra fonte, consumidor, evidência e classificação preservar/corrigir/
completar. Existência do arquivo não comprova qualidade visual. Fechar lacunas
dentro do escopo; preservar assets adequados. Aplicar ragrpg-art nas entregas;
imagegen quando houver produção raster autorizada, conservando fontes.

Piloto Mago cobre equipamento, caminhada, conjuração, projétil, área e teleporte,
em piso claro/escuro, rampa, ponte, vegetação, grupo e chefe existentes.
P3 entrega candidato jogável e comparação antes/depois para aceite humano.
Sem nova aprovação por asset após padrão aceito; mudança de produto/linguagem
retorna ao chat de arquitetura.

## Validação

- tools/verify.ps1 por impacto; novas regras com invariantes. Animação, anexos,
  pausa, cancelamento, morte/revive, troca de estágio e suspensão/retomada.
- Apresentação/áudio não alteram dano, alcance, LoS, cooldown, recompensas/save.
- Renderer real: zoom 50/100/160%, UI 120%, sobreposição e equipamentos.
- Áudio: mute/volumes persistentes, deduplicação, limpeza e vozes limitadas.
- Frio/quente, mediana/p95/picos/memória no mesmo hardware/roteiro. Comparar
  controles F10 de atores/floresta; corrigir regressões reproduzíveis de E08.
- Release Windows/PCK com assets/sons, perfil descartável e proveniência.

Dívidas F10 de carregamento/portais/picos permanecem explícitas; sem promessa
de resolução integral. Sol conclui validação técnica e prepara playtest.
Master exige aceite explícito do candidato; sem push automático.

Registro inicial exclusivamente documental: leitura de código/contratos e
estado Git, sem nova execução de gameplay. Inventário visual completo e
medições pertencem à execução; não estão certificados por este documento.
