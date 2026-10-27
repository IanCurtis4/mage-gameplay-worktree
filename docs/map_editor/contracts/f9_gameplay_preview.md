# F9 — uso real do pacote com perfil descartável

Continuação autorizada F9-11, sem novo épico ou conteúdo de campanha/economia.
Base de código supervisionada6d729724ca29449d02847146f989378e194d2073;
consolidação documental0e8deef9a2be0e25746ecd56caf2ddf9541c4e5a.
Sol implementa e valida; Luna supervisiona seleção congelada por impacto.
Propriedade nominal no manifesto F9 antes de criar arquivos. Principal/playtest
e save pessoal preservados; nenhuma integração em master/push.

## Resultado e autoridades

Os comandos de teste das telas abrem o pacote compilado com sprites, movimento,
aggro/patrulha, combate, efeitos e interações existentes. Reutilizar RunController,
PlayerActor/EnemyActor, CampaignRuntime, ProfileFacade/Store, ExpeditionService,
SnapshotRegistry e HUD reais. Não substituir por círculo, morte simulada ou outra
fórmula/engine de combate. APIs técnicas anteriores podem continuar para regressão;
o fluxo humano de teste usa a aplicação real, sem editar scripts por mapa.

Aplicação em processo Godot4.7.2 separado do editor: recursos de gameplay têm
execução normal e não os placeholders do contexto EditorPlugin. A janela identifica
teste descartável e revisão. Perfil e controles recebem caminhos exclusivos em
`.godot/map_authoring/play`, antes de construir o controlador; não abrir o perfil
pessoal como fallback. Todas as cenas/scripts são locais e versionados. Conteúdo
remetido continua pacote passivo validado, nunca cena/script executável.

Peça/mapa/encontros/patrulhas mantêm validadores e hashes de seus produtores.
O candidato de teste é snapshot imutável local com kind/revisão/hash do pacote,
dependências e identidade de sessão. Criação/abertura é atômica, limitada e
revisável. Hash da fonte atual é conferido antes de iniciar; falha/stale não
substitui a autoria nem destrói candidato/suspensão anteriores. Formato/API de
consumo e dependências devem ficar documentados para os próximos Ex.

O perfil2/12 dos compiladores é técnico, não encolhe o personagem para fazê-lo
caber. A prévia usa o perfil de travessia já definido pela fase de produção
RuinedCrossing (atualmente20/32), respeitando o raio mínimo real do jogador.
Adaptar uma cópia do manifest para esse consumidor e validar entrada, corpos e
acessos pelas autoridades canônicas; não alterar o pacote publicado/catálogo.
Entrada autorada inválida é diagnóstico. Mapa sem entrada pode receber âncora
efêmera encontrada pelas consultas canônicas, identificada como tal na prévia.
Nenhuma queda de cota, teleporte corretivo ou tolerância relaxada.

## Apresentação e ciclo

Extrair a montagem de materiais/caps/lados/props/bordas existente de MapCanvas
para MapPackageView, compartilhado por editor e jogo. Não criar outro renderer.
Provar equivalência das capturas existentes antes de consumir a extração.
AuthoredExpeditionView reutiliza a projeção/pointer/efeitos do adaptador D05,
com a pele real e WorldCanvasOrder compartilhado. Atores observados externamente
conservam hierarquia e ordem de execução; z/apresentação não altera WorldPoint.
Ponte/rota inferior, props diante do avatar, sombras e VFX devem ser legíveis.

Bootstrap/entrada/viagem/morte/recompensas usam o ciclo canônico. A aplicação de
prévia é apresentação externa ao grafo de save; instala a apresentação depois
das substituições transacionais do controlador. Volta ao lobby conserva a facade
descartável e retorna aos controles da prévia. Nenhum fluxo pode cair no menu
com perfil pessoal ou iniciar um piloto fora do candidato por acidente.

Suspender/retomar persiste ponto, vida/SP, cooldowns, identidade/claims, patrulha,
RNG e relógios conforme o contrato existente; sem avanço offline. Compatibilidade
estrita de código/conteúdo/revisão: suspensão antiga é preservada ou recusada
com diagnóstico. Reiniciar cria sessão limpa do mesmo candidato e preserva a
anterior. Encerramento/falha/stop não deixam mutação parcial. Progresso, retorno
obsoleto e custos entram na medição F9-10; não prometer FPS a partir de checks.

GUI, AX e CLI devem chamar as mesmas APIs de candidato/lançamento/estado e ações
de jogo; parâmetros fechados e mensagens em pt-BR. Não usar kill por PID opaco
para atingir um processo que pode já ter sido reutilizado pelo sistema.

## Provas e fechamento

Primeiro, pele compartilhada com imagens equivalentes e invariantes de geometria,
ordem, props/sombras. Depois, testes em gameplay normal com jogador/inimigos reais,
clique/habilidade/LoS/bloqueio/ponte, aggro/patrulha, interação existente, corte/
retomada exatos e restart limpo. Casos negativos: pacote adulterado/stale, corpo
sem passagem, revisão incompatível e erro de gravação preservam o estado anterior.
Conferir caminhos de perfil/controles e retorno de menu, não apenas existência
de uma pasta descartável. Testes não simulam dano para alegar prova de combate.

Export release limpo deve consumir os mesmos dados/arte permitidos, conservar
validação de dependências e funcionar em ambiente limpo com perfil isolado.
Não basta abrir no editor ou copiar o próprio checkout para afirmar isso.
Fechamento exige todas as linhas F9, a área temática12 e roteiro humano sem
código. Este contrato não libera F10/E08 nem declara o preview entregue.
