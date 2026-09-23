# E04 — Espadachim: pacotes aprovados

23/09/2026. Usuário aprovou a dualidade Defendente/Berserker e autorizou
encaminhamento ao Sol, com execução granular como no Mago.
Base de trabalho: playtest 00de812, com integração visual do Impacto das Almas.
Este envio não declara MGI concluído nem libera E05.

## Biblioteca e progressão

Preservar Corte, Investida e Resistência existentes. Acrescentar oito ativas
e duas passivas: biblioteca final de dez ativas e três passivas, com cinco
slots ativos e dois passivos. Manter R0 inicial, equipagem manual, 19 pontos
base, ativas R1–R5 e passivas R1–R3. Não invalidar saves/presets existentes.
Ranks melhoram principalmente um eixo; custos seguem autoria côncava para
skills de dano. Valores concretos devem constar na tabela de cada pacote.

## Parede de Escudos — contrato fechado

Barreira curta e curva, frontal, acompanha a posição do personagem com
orientação fixada ao ativar. Movimento livre, sem redução de velocidade.
Bloqueia projéteis frontais enquanto tiver resistência e reduz dano frontal;
flancos permanecem vulneráveis. Não altera navegação nem bloqueia passagem.

Postura puramente defensiva: permite Provocar e Perseverança. Reativar a
própria habilidade desliga sem custo adicional, inclusive quando a recarga
impediria uma nova ativação. Ação ofensiva válida, incluindo autoataque,
encerra a postura antes da execução. Falha por SP, recarga, alvo ou requisito
não a cancela. Ao iniciar a postura, limpar intenção automática de ataque
anterior para evitar cancelamento imediato; uma nova ordem ofensiva válida
pode encerrá-la. Definir classificação explícita de ações, não inferir de nomes.
Investida continua mobilidade sem dano; permiti-la sem girar a orientação fixa.

No pacote, documentar duração/resistência, custo e início da recarga, arco e
mitigação frontal. Essas magnitudes são tuning de implementação; não reabrir
as decisões de movimento livre/toggle/cancelamento aprovadas acima.

## Debuffs por atributo — contrato crítico

Efeitos distintos coexistem: DEF, FLEE, velocidade de movimento, ASPD,
dano causado e dano recebido são canais separados. Reduções do mesmo
atributo não somam entre si: prevalece a mais forte, independentemente da skill.
Cada aplicação/fonte mantém duração própria; ao expirar a mais forte,
uma mais fraca ainda ativa volta a valer sem herdar duração da outra.
Reaplicar a mesma fonte renova somente sua própria instância, sem stacks.

Aplicar a mesma política aos aumentos de dano recebido e revisar os debuffs
existentes do Mago onde houver sobreposição. Não combinar maior magnitude
de uma fonte com maior duração de outra. Fixar limites por atributo e manter
mitigação válida: debuffs não podem remover toda defesa por empilhamento.
Usar StatCalculator/pipeline canônico; não duplicar fórmulas em atores/UI.
DoT, marcas e orçamento de hard CC continuam seus contratos próprios.

## Ordem de execução

| Pacote | Habilidade | Escopo e critério principal |
|---|---|---|
| SW1 | Parede de Escudos | Postura, arco frontal, interceptação e mitigação; toggle e transição para ofensiva válidos, movimento preservado. |
| SW2 | Provocar | Alvo único força temporariamente perseguição/auto contra o jogador; arqueiros deixam de fugir. Reduz DEF e FLEE em canais distintos. Inclui infraestrutura mínima de debuffs por fonte/atributo e regressão das sobreposições existentes. Não cancela ataques emitidos nem padrões especiais de boss. |
| SW3 | Perseverança | Pequeno escudo pessoal temporário com base útil e contribuição de VIT e INT. Rank aumenta absorção. Definir duração/reaplicação e consumo antes do HP, sem duplicar cálculo de dano. |
| SW4 | Grito Perfurante | Pulso ao redor: baixo dano físico, slow e redução de ASPD. Rank prioriza duração limitada. |
| SW5 | Fúria | Janela curta de ATQ corpo/ASPD altos e penalidade de DEF/resistência mágica. Rank melhora benefício ofensivo, penalidade fixa; restaurar fontes corretamente ao expirar. |
| SW6 | Golpe Brutal | Melee alvo único, preparo perceptível, dano alto; redução de DEF depois do impacto, não beneficia o próprio golpe. Rank prioriza dano. |
| SW7 | Raiva Concentrada | Estocada skillshot em faixa estreita atingindo todos os alvos; firma os pés durante o golpe, sem substituir Investida. Rank prioriza dano. |
| SW8 | Grito Aterrorizante | Fear curto em área e aumento temporário do dano recebido pelo alvo; sem dano direto relevante. Rank prioriza duração limitada; usar orçamento/imunidades existentes. |
| SW9 | Vigor | Passiva aumenta regeneração de HP somente fora de combate, usando a regra atual. |
| SW10 | Sede de Sangue | Passiva dá ATQ adicional a partir da VIT investida sem consumir VIT e pequena cura por abate atribuído ao jogador. Sem cura duplicada por múltiplos impactos/DoTs; bônus de ATQ útil contra boss sem adds. |
| SWI | Fechamento | Duas builds com compras/presets/save/reload/menu/run, melee/ranged, postura/debuffs/escudos e regressão Mago/Arqueiro. |

Builds de referência, não presets gratuitos:

- Defendente: Corte, Parede, Provocar, Perseverança, Grito Perfurante;
  Resistência e Vigor.
- Berserker: Investida, Fúria, Golpe Brutal, Raiva Concentrada,
  Grito Aterrorizante; Sede de Sangue e Vigor.

## Checkpoints e responsabilidade

Executar **somente SW1 na primeira resposta**, entregar commit, tabela,
validação e handoff curto e parar. Cada comando de continuidade autoriza
executar o próximo pacote já listado; não encadear várias skills na mesma
resposta. Se uma primitiva crítica exceder o pacote, separar um checkpoint
explícito com o que falta, sem alegar conclusão da skill.

Sol implementa contratos novos. Terra/Luna podem cuidar de lotes independentes
de dados/UI sobre contrato pronto, com dono único por arquivo; evitar overhead
de delegação sem benefício. Astra revê contratos críticos e fechamento integrado,
sem gate obrigatório para cada mudança rotineira. Não alterar master/playtest.

Cada skill deve aparecer com nome correto no menu, aprendizagem, slots e HUD,
com mira/VFX provisórios legíveis. Reusar padrões existentes e preservar o
cast por DES quando aplicável. Testar R0/inválido, R1/R5, SP, cancelamento,
snapshot, pausa, morte e limpeza; acrescentar invariantes específicas de
postura/debuff/escudo conforme o pacote. Executar tools/verify.ps1 no Godot
4.7.2 antes da entrega. Saves de teste isolados, sem mexer nos perfis do usuário.
