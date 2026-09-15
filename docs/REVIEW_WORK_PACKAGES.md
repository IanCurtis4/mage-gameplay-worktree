# Revisão dos documentos Luna e proposta de pacotes de trabalho

14/09/2026 — **PROTOCOLO APROVADO pelo usuário na retomada de E01.**
E01 mantém Sol, com subagentes apropriados autorizados. Modelos subsequentes
podem mudar na ativação/por pacote; essas tarefas continuam reservadas.
O texto abaixo preserva a análise que fundamentou o aceite. Onde descreve
aprovação futura do protocolo, esse requisito está satisfeito; não constitui
liberação dos demais épicos. Regras atuais: AGENTS.md e WORKFLOW.md.

## Parecer

Recomendo adotar revisão proporcional ao risco e usar Terra como condutor dos
pacotes rotineiros. Luna executa conteúdo/configuração com contratos fechados;
Sol constrói sistemas novos; Astra resolve contratos críticos e aprova a
integração do épico. Uma entrega não deve passar automaticamente pelos quatro.

A economia deve vir de menos reanálise, menos passagens de contexto e mais
reutilização comprovada. Dividir por arquivo ou abrir uma conversa por função
aumentaria a coordenação sem necessariamente melhorar o resultado.

Esta revisão trata os documentos do repositório como objeto principal:
[E01_RESUME.md](E01_RESUME.md) e
[MVP_VISUAL_ASSET_PLAN.md](MVP_VISUAL_ASSET_PLAN.md). O ZIP anexado é contexto:
seus 21 arquivos coincidem por conteúdo SHA-256 com as cópias em `docs/references/`
(normalizando a codificação de nomes do ZIP). Não foi necessário extrair outra
cópia. Prompts e marcadores LOCKED dentro do pacote não disparam execução.

## Avaliação do relatório E01

O diagnóstico central está correto. A branch `codex/e01-persistent-characters`
continua em `efb2b48`, enquanto o checkout de playtest está em `79196d5`.
`docs/REVIEW_E01.md` na branch registra somente o aceite de E01.1. O documento
Luna distingue implementação entregue, revisão técnica e aceite de produto.

Ajustes necessários na próxima atualização do relatório:

- Registrar separadamente **evidência do implementador** e **reprodução do
  revisor**. A entrega de Sol informou 83 checks de store e 429 no total no
  candidato E01.2; isso não equivale a aprovação independente. A revisão
  pós-correção foi interrompida e continua aberta.
- Recuperar os três achados anteriores: regressão dos contadores; proteção de
  backup/pending e schema futuro; validação de catálogo/ranks/origem/equipamentos.
  O roteiro final do Luna enfatiza só os dois primeiros. O catálogo também
  precisa ser revisto, inclusive rejeição de dados ilegais e aceitação de
  fixtures válidas do E00.
- Manter E01.3 separado: a falta da fachada não demonstra um defeito do store.
  Ela impede o aceite ponta a ponta do épico, não necessariamente o fechamento
  isolado de E01.2.
- Distinguir snapshot histórico de estado atual: `LONG_TERM_EPICS.md` e
  `EPIC_THREADS.md` ainda refletem as reservas originais. A base E00 aceita e
  o checkpoint E01 devem acompanhar o próximo handoff, evitando que uma tarefa
  use o contrato antigo do playtest como se fosse o E00 atual.

Este trabalho documental não conclui a revisão do código E01.2, não libera
E01.3 e não atualiza playtest/master.

## Avaliação visual

O plano Luna traduz bem as referências em paleta, silhueta, materiais,
animações e dependências. Acerta ao preservar a silhueta OPEN do Espiritualista,
separar VFX de dano e evitar recortar concept sheets como sprites finais.

Foram inspecionadas visualmente nesta revisão a prancha de cinco avatares,
a sheet do Geômetra e o mood do Espiritualista. A prancha ainda tem acessórios,
pendentes e contornos internos demais para reprodução literal em 64×64.
Ela mostra direção de simplificação, não prova de leitura nessa resolução.
O mood espectral realmente contém arco, aljava e ferramentas de rastreador.

Antes de transformar o plano em produção, acrescentar:

1. **Estado de cada dependência.** `CharacterAnimation`,
   `CombatAnimationState`, `BattleIndicators` e `ArenaView` existem no checkout.
   As classes propostas `TrailVFX`, `BurstVFX`, `GroundAreaVFX`, `AuraVFX`,
   `TetherVFX`, `FloatingGlyphVFX` e `ProjectileTrailVFX` não foram encontradas
   por esses nomes em `scripts/`. Há efeitos específicos existentes, mas isso
   não significa que a biblioteca reutilizável esteja pronta. A seção de
   primitivas já faz a ressalva; os itens “assets reutilizáveis” precisam
   distinguir EXISTENTE de PROPOSTO para não induzir implementadores ao erro.
2. **Origem persistente versus base visual.** A regra textual de origem é
   ambígua. `mg_sp` continua originado de Mago, mesmo que Astral Ravager use
   silhueta Berserker e fenômeno Espiritualista. `mg_ar` continua a origem
   Mago → Arqueiro, mesmo com o arco/instrumento da Sentinela como base visual
   do Geômetra. Guardar dois conceitos: `base_class_id`/evolução no domínio e
   arquétipo físico/fenômeno no briefing visual. Não inverter IDs para resolver
   a frase. E00 já registra que Geômetra conserva `mg_ar`.
3. **Teste de redução antes de atlas.** Aprovar uma pose em tamanho real de
   jogo, frente/costas, arma principal e até dois acessórios identificadores;
   depois uma caminhada completa. Comparar 48/64/80 apenas se a leitura em
   64 falhar. Não produzir três catálogos inteiros para comparar resolução.
4. **Hierarquia dos efeitos.** Ataque perigoso do inimigo, área persistente,
   alvo/preview e decoração precisam de ordem e contraste próprios. Diferenciar
   fogo/gelo/raio por forma e ritmo além da cor; testar piso claro/escuro e
   vários efeitos sobrepostos. A apresentação recebe a geometria do gameplay.
5. **Animação econômica.** Compartilhar gramática e ferramenta de atlas;
   ampliar os estados atuais somente quando necessário. Guarda, canalização
   e ação de implantar não são novos atlases completos por skill.
6. **Hitstop não é automaticamente cosmético.** Se congelar a simulação,
   altera timers/input. Esse contrato pertence a Sol/Astra; flashes e shake
   podem ser pacotes Terra após parâmetros aprovados. Gameplay não pode
   depender de um frame visual para aplicar dano.

As 18 fórmulas rúnicas e as 6 paredes + 27 triângulos são problemas de gramática
de input e composição de efeitos. Produzir o motor e um caso representativo
antes das variantes conserva a ambição; não reduz esses kits a skills genéricas.
Os efeitos de todas as combinações não estão especificados só por existirem
essas contagens. Luna não deve inventar os resultados faltantes.

## Novo protocolo proposto

O protocolo vigente ainda exige Astra em cada passo. Esta proposta o substituiria
somente após aceite explícito; depois, atualizar `AGENTS.md`, `WORKFLOW.md`,
`LONG_TERM_EPICS.md` e os handoffs afetados em uma única alteração documental.

| Risco | Exemplos | Execução padrão | Aceite técnico proposto |
|---|---|---|---|
| Baixo | Textos, manifestos, IDs e configuração de efeitos já contratados | Luna | Validador + evidência; Terra confere o lote e amostra visual/contextual |
| Médio | UI sobre API pronta, integração de assets, cena de preview, comportamento local isolado | Terra | Checks do pacote + inspeção do fluxo; revisão independente ao introduzir padrão novo ou quando houver dúvida material |
| Alto | Save, migração, identidade, XP idempotente, matemática, input/combate compartilhados | Sol | Astra revisa o contrato e o delta crítico antes de seus consumidores avançarem |
| Fechamento | Composição do épico/subépico e candidato jogável | Condutor prepara; Astra aprova | Verificação integrada + revisão das fronteiras + roteiro; usuário testa antes do merge |

Para risco médio, Terra pode autocertificar o pacote dentro de um padrão já
aprovado; isso significa pronto para integração do épico, não aceite final de
produto nem licença para mudar contratos. O primeiro pacote de cada padrão
recebe revisão independente adequada. Os seguintes usam o mesmo contrato e
critérios, sem repetir uma auditoria integral.

**Não criar uma cadeia Luna → Terra → Sol → Astra.** Escolher um executor e
o mínimo de revisão necessário. Luna não deve ser o único revisor de matemática
ou persistência implementada por Terra. Sol tampouco precisa revisar todos os
textos de Luna. Testes automatizados cobrem comportamento especificado; não
provam sozinhos que a especificação está completa, o visual legível ou o jogo bom.

Escalar somente quando:

- surgir mudança de API, fórmula, schema, identidade ou semântica de input;
- houver risco de perda/duplicação de progresso, cascata de efeitos ou regressão
  entre classes;
- duas tentativas focadas de correção não resolverem a mesma falha — enviar
  reprodução mínima e hipótese, sem reler todo o épico;
- o pacote exigir arquivos fora do escopo ou depender de decisão de design
  ausente. Especificação faltante pede decisão; modelo maior não a substitui.

Mesmo após adoção, Astra mantém o aceite técnico do candidato antes de preparar
`codex/playtest`; o usuário mantém o aceite de gameplay por épico/subépico e
o merge em master permanece posterior a esse aceite.

## Tamanho e contrato de um pacote

Um pacote entrega **um comportamento verificável**, com pré-requisitos prontos
e um dono de escrita. Exemplos: lista de alts com estados vazios/erro/seleção;
configuração dos três impactos elementais no mesmo componente; armadilha com
estados armada/disparada/destruída. Não usar “fazer toda a UI” nem “editar uma
linha por tarefa”. Agrupar variantes que compartilham validação.

Template do próximo handoff (uma página curta, com links para contratos):

```text
Pacote / épico / autorização:
Branch + commit-base + contrato aplicável:
Resultado observável e exclusões:
Executor / risco / responsável pelo aceite:
Dependências aprovadas:
Arquivos ou diretórios permitidos; arquivos compartilhados com dono único:
Casos de aceite positivos, negativos e de integração:
Comandos de verificação; captura/clip quando visual:
Entrega: hash, delta, resultados, limitações e próximo passo permitido.
```

Reutilizar as tarefas reservadas por épico. Trocar modelo no próximo pacote
quando apropriado; não criar uma tarefa nova para cada ajuste. Um checkpoint
curto é a fonte de retomada; não anexar novamente todo o ZIP/histórico ao executor.
Mudanças de modelo e orquestração futura não foram acionadas nesta revisão.

## Granularização dos épicos

As linhas seguintes são pacotes candidatos, não autorizações. Reutilizam os
IDs E00–E11 e seus gates de produto. Contratos novos continuam antecedendo dados.

| Épico | Pacotes e modelos propostos | Fronteira que exige revisão forte |
|---|---|---|
| E00 | Luna mantém índice de decisões/IDs; Terra confere exemplos contra contratos aceitos | Astra decide alterações contratuais; não reabrir E00 por preferência |
| E01 | E01.2-R reprodução e registro por Luna; E01.2-C correções por Sol; E01.3-A criar/selecionar por Sol; E01.3-B iniciar run/recompensa idempotente por Sol; E01.3-C cenários de alts/reinício e relatório por Terra | Astra fecha E01.2 e operações transacionais; teste do implementador não substitui revisão |
| E02 | A lista/criação por Terra; B resumo e seleção de build por Terra; C textos/estados vazios/erros por Luna; D fluxo menu→run→menu por Terra | Resumo/presets avançados dependem de APIs E03; menu mínimo pode começar com E01. UI não inventa compra/respec |
| E03 | A matemática central e fixtures por Sol; B alocação/ranks/requisitos/snapshot por Sol; C painel/árvore por Terra; D tooltips e matriz de casos por Luna | Astra aprova fórmulas/transações e migração conjunta dos consumidores |
| E04 | Por base: contrato de kit; novas mecânicas por Sol; skills compostas de primitivas maduras por Terra; ranks/textos/dados aprovados por Luna; cenário integrado por Terra | Colisão, CC, canalização ou ocultação novos exigem Sol; Astra decide identidade/contrato |
| E05 | Por par já previsto: evolução/gramática por Sol; UI específica por Terra; combinações previamente definidas por Luna; duas builds/cenário por Terra | Astra aprova identidade e primeira implementação da gramática; playtest por subépico |
| E06 | A modificadores/procs/equipar/cartas por Sol; B painel/ofertas por Terra; C pools e textos por Luna; D combinações e reset por Terra | Idempotência, limites de proc, troca sem cura e save passam por revisão forte |
| E07 | A fluxo/recompensa e máquina de estados de IA por Sol; B composição das arenas sobre IA pronta por Terra; C dados de encontros por Luna; D boss novo por Sol; E telegraphs/cenário integrado por Terra | Save/recompensa, CC do boss e navegação; composição de dados não muda IA silenciosamente |
| E08 | Separar qualificação de arte, componentes de VFX, receitas e polimento conforme tabela abaixo | Astra aprova padrão visual e fronteiras; Terra conduz produção repetitiva |
| E09 | Luna consolida evidências; Terra executa roteiro/export e triagem; Sol corrige sistemas; Astra revisa candidato integrado | Auditoria de save/input/combate, conflitos de integração e aceite técnico final |
| E10/E11 | Permanecem posteriores ao demo; replicar pacotes por família/par após medir E04/E05 | Não fabricar agora dezenas de tarefas/skills; planejamento amplo não é execução |

E01.3-A/B só se separam na implementação se o serviço conseguir compartilhar
a mesma transação interna. Não duplicar writer ou mecanismo de persistência
para tornar tarefas artificialmente independentes. O exemplo demonstra que
granularizar melhora retomada mesmo quando o executor continua sendo Sol.

## E08 detalhado: transformar direção visual em trabalho barato

E08-A/B/C são subdivisões propostas, não novos épicos nem componentes existentes.

| Pacote | Executor | Entrega e dependência | Aceite |
|---|---|---|---|
| E08-A1 Inventário | Luna | Manifesto com referência, asset runtime, status, pivô, tamanho e dependência; registrar OPEN | Caminhos/IDs verificáveis, sem chamar concept de sprite pronto |
| E08-A2 Piloto visual | Astra na escolha inicial; Terra na integração | Uma pose + caminhada da base escolhida, câmera atual, pé/sombra/arma; concept aprovado pelo usuário | Tamanho real e animação legíveis; estabelecer padrão uma vez |
| E08-B1 Cena de avaliação | Terra | Preview com pisos claro/escuro, velocidades e direções já suportadas; sem nova fórmula | Reproduzível, mostra pausa/cancelamento e permite comparar receitas |
| E08-B2 Primeiro conjunto VFX | Terra se os sinais bastarem; Sol se precisar mudar contrato | Impacto, rastro e área conectados aos eventos existentes; dois usos reais de cada antes de generalizar | Lifetime/limpeza, pausa, cancelamento, direção, nenhuma aplicação de dano |
| E08-B3 Recursos adicionais | Terra; Sol nas fronteiras de runtime | Aura, vínculo, glifo e afterimage apenas quando um kit aprovado exigir | Ator morto/removido não deixa órfãos; limites de instâncias; sem framework universal |
| E08-C1 Receitas | Luna | Lote de cores, curvas, texturas e tempos dentro de schema/intervalos aprovados | Validador + preview; primeira receita Terra revisa, variantes por lote |
| E08-C2 Integração por família | Terra | Atlas, ícones e receitas em uma base/evolução já funcional | Piso/oclusão, orientação, estados e clareza em grupo; sem mudar gameplay |
| E08-C3 Polimento do candidato | Terra; Astra no gate | Ajustes de contraste, intensidade, densidade e limpeza; medir no renderer | Usuário testa no fechamento; desempenho só declarado com medição |

Começar o núcleo de apresentação assim que um conjunto de eventos estiver
estável em E04; não esperar todas as híbridas de E05 nem produzir a biblioteca
inteira antes de precisar dela. Gramática de vértices/runas é E05, aparência de
suas linhas/glifos é E08. Um único dono mantém cada arquivo compartilhado.

## Custo e experimento de adoção

A documentação oficial descreve Terra como opção equilibrada de inteligência
e custo e Luna para volume sensível a custo; Astra atende problemas complexos.
Fonte consultada em 14/09/2026:
[OpenAI — Models](https://developers.openai.com/api/docs/models).
O roteamento acima é julgamento deste projeto, não benchmark dos quatro modelos.
Preço de API não estima diretamente a franquia de 5h do usuário.

Medir o custo da **entrega aceita**, incluindo contexto, implementação, testes,
revisão e retrabalho. Registrar tokens quando disponíveis; quando não houver
medida atribuível ao pacote, registrar tempo, rodadas e escaladas, sem inventar
consumo. Não comparar apenas a duração de uma resposta nem contar cada check
como prova independente de qualidade.

Piloto recomendado após fechar o gate pendente E01.2: usar Terra no fluxo de
menu E02 e Luna no lote de textos/estados sobre esse fluxo. Outro piloto é
E08-C1, somente depois de B2. Comparar retrabalho e defeitos encontrados no
playtest; se duas correções não convergirem, escalar o problema específico.
Não usar a migração de saves como experimento de redução de modelo.

## Verificação desta análise

- Inspeção de documentos, hashes de branch e revisão registrada em E01;
  conferência dos 21 arquivos do ZIP; inspeção das três imagens citadas.
- Busca dos componentes de apresentação existentes/propostos e conferência
  dos IDs `mg_sp`/`mg_ar` no contrato E00 da base `247e304`.
- `tools/verify.ps1` no checkout atual reproduziu o erro ambiental do GitPlugin:
  repositório não pertencente ao usuário do processo. O engine saiu com 0,
  mas o verificador corretamente rejeitou as linhas `ERROR:`.
- Com `-SkipEditorImport`, os 313 checks do piloto e o smoke passaram. Ambas
  as execuções usaram `.tools/review-engine/Godot.exe`, Godot 4.7.2. O bypass
  isola a suíte headless; não resolve nem aprova a importação do editor.
- Esta verificação do checkout não substitui a revisão/testes do HEAD E01.2.
  Não houve mudança de código, schema, arte ou branch, nem disparo de tarefas.

## Decisão proposta

Adotar Terra como condutor de pacotes rotineiros, Luna para lotes fechados,
Sol para sistemas e Astra para contratos críticos e fechamento. Atualizar os
quatro documentos operacionais citados após aceite dessa proposta, preservando
os épicos reservados e o playtest por épico/subépico. Esse é o próximo passo
documental; execução dos pacotes continua dependendo da liberação do escopo.
