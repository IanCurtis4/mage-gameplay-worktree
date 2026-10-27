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

## API do primeiro consumidor (em validação)

`gameplay_candidate.gd` oferece create(kind, package, current_source_hash),
valid, prepare, publish e read. Kinds map/population/patrol, conforme seus
validadores. Envelope passivo versão1: format_version, kind, source_hash,
package, candidate_hash (digest canônico dos quatro campos anteriores). Limite
5MiB incluindo envelope; produtores conservam seus4MiB. Leitura usa bytes_to_var
sem objetos, nunca bytes_to_var_with_objects. Não aceita script/cena do remetente.
Publicação local por hash, temporário verificado e rename; revisão existente
conservada em conflito. Material/arte/dependências seguem validação do produtor.

prepare só funciona no processo normal de jogo. Clona o manifest; usa traversal
20/32 da fase RuinedCrossing e o PlayerActor configurado real tem raio20, embora
o valor inicial do CombatActor antes de configure seja18. Inspeção2/12 não vira
perfil do jogador. Sem entrada autorada, procura apoio seguro e registra socket
efêmero. Consulta corpo, conectividade de ida/volta dos apoios, interações e
portais, Planner de população e validador de patrulha. Manifest derivado declara
phase_id editor_gameplay_preview e input.preview_candidate_hash; fonte/pacote
originais continuam imutáveis. Mapa com porta24 passa no compilador técnico e
é recusado para o corpo real, sem reduzir seu raio ou corrigir o ponto.

`gameplay_launcher.gd` cria candidate CAS e sessions/<nonce24>/session.bin,
resolve somente o namespace local .godot/map_authoring/play ou
user://map_authoring/play, e deriva profile/ e controls.cfg dentro da sessão.
Descriptor versão1 contém format_version, session_id, class_id, candidate_hash;
nenhum caminho de perfil vindo do payload. Classe deve ser identidade base
existente. Claim por diretório atômico+PID impede dois donos; PID vivo é recusa
conservadora e nunca alvo de kill. Stop é pedido com token da sessão. A API de
OS.create_process existe; a primeira prova nativa chama App diretamente, ainda
não certifica o caminho de lançamento pelo editor nem o binário exportado.

`GameplayApp.open(path)` valida candidato e reivindica sessão; start cria o
perfil/personagem e entra via ExpeditionService/SceneFlow; resume primeiro
restaura passivamente para conferir código e candidate_hash, só depois confirma
a retomada. suspend e restart são assíncronos e usam a UI/serviço canônicos.
Restart cria nonce/perfil novos e preserva o anterior. App é Control fora do grafo
de simulação e intercepta o CharacterMenu criado com a facade explícita, antes
de oferecer controles da prévia novamente. Atores não mudam de pai. Bootstrap ou
instalação recusados removem apresentação transitória e preservam o corte durável.

ControlPreferences.path é omitido intencionalmente pelo contrato de snapshot.
O dono da janela o atribui no child_entered_tree de cada RunController, antes de
_ready/UI; não mudar o manifest para permitir que um save escolha destino externo.
Isso inclui substituições por eventos/recompensas e retomada. Perfis e caminhos
pessoais não são fallback. Estado resumido local por token, gravação atômica e
cache de bytes evita reescrever status idêntico quatro vezes por segundo.

A prova de corte compara ponto, HP/SP, cooldowns, RNG, slots/claims/relógio,
patrulha e dados completos de ThreatView. Lifecycle suspended→active é transição
explícita do serviço, testada separadamente; não é avanço offline. O observador
de dano é Control de teste, escuta HealthState.damage_applied e não altera HP,
WorldPoint ou morte. Comparação por identidade de um ThreatView novo seria falsa:
os dados são conferidos, não o endereço do RefCounted.

Próximos consumidores dentro de F9: ligar telas/AX/CLI às mesmas APIs, provar
lançamento externo, ações/interação/habilidades, casos de revisão incompatível e
falha de IO da prévia, export limpo e roteiro humano. Os botões técnicos antigos
não foram trocados neste primeiro consumidor. Não declarar F9-11 ou F9 completos.

## Consumidor de janela e controles — continuação em execução

Código base supervisionadobf406c3, consolidação1dddfc2. Manter envelope de RUN
versão1. Acrescentar WINDOW independente: windows/<nonce>/window.bin imutável,
versão1/window_id/candidate_hash/initial_session. Cabeçalhos baratos validam
namespace fechado e referência à sessão; pacote só é revalidado ao abrir jogo.
Uma janela é usada uma vez (started.token) e tem lease próprio. Reabrir faz nova
WINDOW sobre a sessão atual indicada no status validado da antiga. Não retomar
uma janela consumida ou reproduzir entradas incertas após crash.

Restart troca RUN/perfil e conserva WINDOW/processo; status da janela aponta a
sessão atual e stop usa o token estável da janela. Liberar leases independentes
em close/falha; nenhum PID é morto. Testar na instância App e em processo Godot
normal separado, inclusive stop após restart e recusa de janela consumida. O
lançamento headless é parâmetro booleano fechado para AX/CLI e prova de processo;
não equivale a prova visual do binário release. Janela humana segue nativa.

Ações remotas serão envelopes passivos limitados e com window_id/session_id/
request_id. Recusar sessão antiga após restart. Antes de executar, registrar
receipt em memória; persistir ACK a partir do resultado em cache, sem executar
novamente se o ACK falhar. Janela nova não consome entradas da anterior. UI/AX/
CLI delegam a movimento/skill/interação/serviços existentes, não aplicam dano ou
morte simulados. Respostas não transportam root/registry/objetos executáveis.
Registrar limites, revisão incompatível, falhas e custos antes de fechar F9-11.

### Protocolo de controles versão1 implementado

Arquivo command.request por WINDOW, lock de escritor sem sobrescrever outro
pedido. Envelope fechado: format_version1/window_id/session_id/request_id/payload.
request_id24hex; resposta reply_<request_id>.json com versão/tokens/fingerprint/
result. Inputs4KiB, respostas128KiB, até256 receipts por janela. Limite conserva
histórico em memória e recusa novos pedidos; stop estável e input humano direto
continuam disponíveis. Janela consumida não é reaberta, evitando replay de
entrada incerta depois de crash. JSON estrito rejeita campos duplicados; nenhuma
cena/script/objeto vem do payload. Versão/revisão não aceitam booleano como número.

Payloads: inspect/suspend/resume/restart/close têm só kind; move acrescenta
position_xyz[3] e geometry_revision; skill acrescenta também skill_id/preview/rank.
Rank0 usa o máximo canônico, outros ranks passam pela política SkillCastRank,
sem alterar intenção anterior da UI. interaction recebe interaction_id e consulta
portal/objetivo reais; collect recebe ticket_id existente. Ponto é projetado pelo
adaptador e usa clique normal/oclusão; não é teleporte nem seção editorial.

Normalizar revisão/rank para int e coordenadas para float antes do fingerprint,
pois JSON pode mudar o tipo numérico, enquanto ExpeditionCanonical os distingue.
Mesmo request_id com outro payload é conflito. Resultado concluído fica em cache
antes do ACK; falha de rename do ACK tenta novamente só a resposta. Cache é da
WINDOW e sobrevive a restart da RUN. Header da resposta conserva session_id do
pedido original; result.state informa sessão atual. Pedidos de RUN antiga são
recusados depois de restart. Poll de reply usa os tokens/fingerprint originais.

App.describe_gameplay é projeção de ponto/HP/SP/cooldowns/ranks/inimigos/interações/
recompensa/época reais. Não oferece dano estimado, fórmulas ou objetos do serviço.
Durante substituição transacional, host destacado/passivo não é alvo de input.
App.command delega às mesmas autoridades usadas pela UI nativa. ObservedApp do
teste conta despachos e chama super, sem simular efeito; IOfail real é diretório
no destino do ACK, removido apenas dentro do namespace descartável do teste.

As telas/AX/CLI ainda precisam ser conectadas e validadas. VFX dos quatro campos
(FOGO/GELO/RAIO/BARREIRA) têm projeção D05 pendente no renderer legado; existência
de campo e custo real nesta prova não equivalem à apresentação visual desses
campos. Fechar essa projeção dentro de F9, sem nova fórmula de combate.


## Clientes humanos, AX e CLI — consumidor integrado em validação

As telas de mapa, encontros e patrulhas montam GameplayTools. Os botões
Abrir jogo, Retomar teste e Suspender e fechar teste chamam Launcher; o
seletor usa as três identidades base existentes. Retomar indica explicitamente
que preserva a última revisão testada, mesmo quando o rascunho mudou. Fonte e
histórico ficam na sessão editorial original; lançar exige compilação vigente.
O exemplo humano de duas salas agora tem abertura80 para o corpo real20;
o teste negativo reconstrói explicitamente a abertura24 e continua recusado.

Por identidade kind/document_id, referência local limitada a64 documentos em
.godot/map_authoring/play/references aponta a WINDOW validada. Não contém
perfil nem código. Gravação usa CAS por hash de bytes. Referência inválida
permanece preservada; recuperação revisável e limpeza seguem na frente10.
Janela em execução e rascunho com outra identidade não se substituem entre si.

Os sete comandos por tela são <screen>/gameplay/launch, resume, stop, inspect,
select_class, action e reply. Parâmetros fechados delegam ao mesmo componente;
headless é booleano opcional para agentes/testes, false no botão humano.

CLI: executar a engine com --headless --path <projeto> --script
res://scripts/map_authoring/preview/gameplay_cli.gd -- <pedido.json>.
Um único JSON estrito, até16KiB, sem script/cena remetidos. Resultado de uma
linha após F9_GAMEPLAY_CLI_RESULT; processo retorna0 apenas em sucesso.
JSON de saída usa escapes Unicode para conservar caminhos com acentos em
leitores Windows com code page diferente. Pedido action espera ACK por até90s
por padrão; wait:false só publica. Erro de gameplay no ACK é ok:false e saída
não zero; conclusão do transporte sozinha não é aceite da ação.

- launch: command, kind, source_path, package_path; class_id/headless opcionais.
  Relê fonte JSON validada e pacote publicado pelo produtor original; compara
  hash atual, sem confiar num hash remetido nem recompilar silenciosamente.
- resume: command, window_path; headless opcional. Janela nova sobre a sessão
  corrente da revisão anterior validada.
- stop/inspect: command, window_path.
- action: command, window_path, action; session_id/request_id/wait opcionais.
- reply: command, window_path, request_id; session_id/fingerprint opcionais.

Uma lease existente é recusa conservadora, inclusive após crash; somente o
próprio dono a libera no fluxo normal. OS.is_process_running no Windows observa
processos criados pela instância chamadora, não serve como prova de morte de
um PID estrangeiro. Painel recarregado conserva a lease; não apaga trava antiga
nem mata processo por PID. Abrir sessão já ocupada é recusado antes de lançar
outra janela. Recuperação explícita de crash segue exigida na frente10.
Referências primárias: [contrato de OS](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-is-process-running)
e [implementação Windows4.7](https://github.com/godotengine/godot/blob/4.7-stable/platform/windows/os_windows.cpp).
