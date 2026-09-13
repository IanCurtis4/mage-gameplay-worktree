# Épicos do MVP expandido

> Atualização operacional aprovada em 14/09/2026: E00 aceito na base `247e304`;
> E01 retomado com Sol, E01.2 em revisão sobre `efb2b48`, E01.3 após esse gate.
> Adotado docs/REVIEW_WORK_PACKAGES.md: Luna para lotes fechados, Terra para
> condução rotineira, Sol para sistemas, Astra para contratos críticos/integração.
> Subagentes delimitados autorizados no épico liberado; modelos dos próximos
> chats podem mudar na ativação/por pacote. E02–E11 permanecem reservas.
> Esta atualização substitui abaixo o estado histórico de E00/E01 e as regras
> de revisão Astra a cada passo/proibição absoluta de subagentes. Escopo de
> produto e playtests permanecem. Mapa atual: docs/EPIC_THREADS.md.

13/09/2026. **E00 liberado e entregue como contrato candidato; demais épicos RESERVADOS.**
O usuário liberou E00 e pediu incorporar o handoff de híbridas e concluir sua análise.
Contrato vigente para revisão: [E00_CONTRACT.md](E00_CONTRACT.md); evidências e
aceite técnico em [REVIEW_E00.md](REVIEW_E00.md). Aceite de design permanece separado.
Nenhuma implementação de expansão, agendamento ou ciclo em segundo plano foi iniciado.

## Produto e decisões recebidas

- Personagem persistente com classe e possibilidade de alts. Menu inicial de seleção e build, expansível para lobby.
- Base level e job level permanentes; pontos de atributos e pontos de skills distintos. A run limpa augments e estado transitório, não o personagem.
- Evoluções 2-1/2-2/2-3 alternativas; 2-3 depende da base de origem. Ordem das bases distingue 56 híbridas. Níveis/requisitos/respec ainda precisam de números aprovados.
- Druida 2-1: **Naturalista** como nome de trabalho. **Filho de Gaia** é alternativa de nome/título. Nenhum efeito de gameplay depende do rótulo.
- Primeiro demo: Espadachim, Mago e Arqueiro completos, seis puras e seis híbridas direcionais entre elas. O alvo amplo é oito bases, 16 puras e 56 híbridas: 80 identidades.
- Augments continuam coletáveis no chão e escolhidos fora do combate. Mais opções significa variedade de pool/build; não necessariamente mais de três cartões por oferta.

O escopo antigo de MVP.md permanece como histórico do piloto. Esta revisão substitui para o futuro: classes limitadas a duas, níveis resetados por run e ausência de aprendizado/evoluções. Ainda não altera save/código atual.

## O que significa classe completa

Uma identidade completa tem loop jogável, auto, ativas/passivas, níveis e requisitos, duas builds distinguíveis, opções de augment, ícones/VFX/animações, tooltip consistente, save/reset e contrajogo contra ranged/melee/boss. Proposta de orçamento: base com 6–10 ativas e 2–3 passivas; evolução com 4–6 ativas e 2–3 passivas exclusivas além de fundamentos herdados; híbrida no mesmo orçamento de uma pura. O candidato E00 define cinco ativas e duas passivas equipadas por vez, além do auto e de comandos intrínsecos delimitados; aguarda aceite de design. Kit completo não significa implementar indefinidamente todo 'etc.' de uma fantasia.

## Modelo de dados planejado

Conta/perfil contém personagens e coleção conforme ADR; CharacterState contém identidade/base/evolução, XP base/job, níveis, pontos e alocações, skills aprendidas e presets. RunState contém snapshot da build, HP/SP, cooldowns, efeitos, augments e encontro. Resources de catálogo permanecem imutáveis. Dados de save versionados, transações de recompensa idempotentes e testes em diretório temporário. Propriedade de loot/cartas, respec e limites estão especificados no candidato E00_CONTRACT.md; exigem aceite de design antes da implementação definitiva.

## Ordem, responsabilidade e custo

Manter os modelos escolhidos pelo usuário: Astra (gpt-6-astra) decide/revisa arquitetura e arte; Sol (gpt-5.6-sol) implementa sistemas; Terra (gpt-5.6-terra) cuida de UI/dados delimitados. São papéis do projeto, não uma tabela de preços ou benchmark. Não há estimativa confiável de tokens para 80 kits; medir os seis híbridos pilotos e projetar com retrabalho/testes/arte separados. Não repetir todo o histórico em cada tarefa: handoff com contrato, IDs, commit-base, teste e próximo passo.

Uma conversa reservada por épico principal; subépicos reutilizam a conversa, com troca explícita de modelo por passo quando necessário. Nenhum agente pode delegar/criar conversas extras automaticamente nesta reserva. Astra revisa cada passo; usuário testa ao fechar cada épico **ou subépico de conteúdo**. E10a–e e cada par de E11 são gates separados, evitando um playtest gigantesco.

| Épico | Responsável inicial | Dependências | Estado |
|---|---|---|---|
| E00 — Contratos do MVP expandido | astra | aceite de design do candidato | ACEITE_TÉCNICO |
| E01 — Personagens persistentes e alts | sol | E00 | RESERVADO |
| E02 — Menu de personagem e build inicial | terra | E01 | RESERVADO |
| E03 — Stats, job e níveis de habilidade | sol | E00, E01 | RESERVADO |
| E04 — Três classes base completas | sol | E03 | RESERVADO |
| E05 — Evoluções e seis híbridas clássicas | sol | E04 | RESERVADO |
| E06 — Augments, equipamentos e cartas | sol | E03, E04 | RESERVADO |
| E07 — Campanha de três fases e boss | sol | E04, E06 | RESERVADO |
| E08 — Arte, animações e feedback do demo | astra | E04 | RESERVADO |
| E09 — Integração e primeiro demo bom | astra | E02, E03, E04, E05, E06, E07, E08 | RESERVADO |
| E10 — Cinco bases restantes e evoluções | sol | E09 | RESERVADO |
| E11 — Catálogo das 56 híbridas | astra | E10 | RESERVADO |

E02 e E03 podem ser independentes após E01, mas só executar em paralelo se Astra liberar contratos/arquivos sem sobreposição. E05/E07 dependem da fundação; E08 pode produzir a arte do kit já aprovado enquanto gameplay avança. As reservas não autorizam esse paralelismo agora.

## E00 — Contratos do MVP expandido

Dono inicial: gpt-6-astra, esforço high. E00.1–E00.3 entregues documentalmente;
ver contrato final e revisão acima. Nenhuma implementação dos novos sistemas autorizada.

Consolidar regras de personagem/conta/run, stats inspirados em RO, evolução 2-1/2-2/2-3 direcional e definição de kit completo.

1. Astra: ADR de persistência, job, evolução e respec; distinguir decisões aprovadas de parâmetros propostos.
2. Astra: especificar fórmulas e limites de DEF/MDEF, HIT/FLEE, crítico, ASPD, cast/pós-cast/cooldown, com exemplos revisáveis.
3. Astra: contratos Resource/runtime/save e fixtures de referência; revisar dependências antes de autorizar código.

Aceite: Documento numérico aprovado, todos os valores do painel com dono e fórmula, migração definida. Aceite de design do usuário substitui playtest por ser épico documental.

Limite: Não implementar o novo sistema de stats nem declarar fórmulas idênticas a uma versão de Ragnarok.

## E01 — Personagens persistentes e alts

Dono inicial: gpt-5.6-sol, esforço high. Dependências: E00.

Perfil local versionado, lista de personagens, identidade/classe persistente, níveis base/job e saldo de pontos; isolar estado da run.

1. Sol: ProfileState/CharacterState/RunState separados e IDs estáveis.
2. Sol: salvar atomicamente com backup/migração e recuperação de arquivo corrompido; progresso persistente independente de augments.
3. Sol: operações criar/selecionar personagem e concessão idempotente de XP, com fachada mínima de teste.

Aceite: Criar dois alts, ganhar progresso, morrer, reiniciar aplicativo e recuperar cada personagem sem duplicar XP nem vazar build/augments.

Limite: Sem lobby 3D, sincronização online ou edição de personagens reais em testes; usar saves temporários.

## E02 — Menu de personagem e build inicial

Dono inicial: gpt-5.6-terra, esforço medium. Dependências: E01.

Menu inicial expansível para lobby: criar/selecionar personagem, classe, build inicial e início explícito da run.

1. Terra: UI de lista de alts e criação, usando APIs do E01 sem fórmulas próprias.
2. Terra: presets legais e seleção de skills/equipamentos disponíveis, resumo de stats e persistência da preferência.
3. Terra: navegação voltar/iniciar, teclado/mouse e estados vazios; Astra revisa visual.

Aceite: Abrir o jogo pelo menu, selecionar dois personagens/builds distintos, iniciar runs e voltar sem trocar classe silenciosamente ou perder progresso.

Limite: Sem aprender skills inexistentes, redistribuir pontos por atalho, inventar backend ou implementar gameplay.

## E03 — Stats, job e níveis de habilidade

Dono inicial: gpt-5.6-sol, esforço high. Dependências: E00, E01.

XP de personagem e job permanentes, pontos ao subir, árvore com níveis de skills e matemática central acordada.

1. Sol: progressão/XP/pontos base e job separados, limites e transações de alocação.
2. Sol: efeitos por nível, requisitos, snapshots de build e evolução persistente elegível.
3. Terra em passo delimitado na mesma tarefa: UI de pontos, árvore e tooltips após contratos; Astra revisa consistência.

Aceite: Subir múltiplos níveis, investir pontos, reiniciar e conferir persistência, falta de pontos, pré-requisitos e números idênticos no HUD/combate.

Limite: Sem redefinir fórmulas aprovadas no E00, skills em Resources mutáveis ou progressão de augments permanente.

## E04 — Três classes base completas

Dono inicial: gpt-5.6-sol, esforço high. Dependências: E03.

Espadachim, Mago e Arqueiro completos como bases, com fundamentos dos dois ramos e skill levels.

1. Sol: finalizar kit/identidade base do Espadachim.
2. Sol: completar Mago com gelo sólido, Assombro, Barreira Fantasma e preparação de raio/canalização acordada.
3. Sol: Arqueiro jogável, arco, flechas, armadilhas e ocultação; Terra pode preencher dados contratados; Astra assume artes em E08.

Aceite: Cada base conclui um encontro e enfrenta melee/ranged; duas builds por base, habilidades ativas/passivas e níveis funcionam sem depender de augments.

Limite: Sem copiar kits completos das evoluções para as bases; não iniciar as outras cinco bases.

## E05 — Evoluções e seis híbridas clássicas

Dono inicial: gpt-5.6-sol, esforço high. Dependências: E04.

Seis evoluções puras e seis híbridas direcionais entre Espadachim, Mago e Arqueiro; acesso como 2-3.

1. Sol: seletor de evolução com origem persistente e requisitos do E03.
2. Sol: um subépico por par de puras de cada base (Defendente/Berserker; Elementalista/Espiritualista; Sentinela/Caçador).
3. Sol: um subépico por par direcional de híbridas SP/MG, SP/AR e MG/AR; Astra aprova identidade e regras antes do código.

Aceite: Cada subépico recebe playtest: desbloquear/evoluir, manter identidade após reinício, duas builds e fraqueza própria, sem soma irrestrita de duas árvores.

Limite: Não começar as seis puras/seis híbridas simultaneamente. As outras 50 híbridas ficam no E11.

## E06 — Augments, equipamentos e cartas

Dono inicial: gpt-5.6-sol, esforço high. Dependências: E03, E04.

Ampliar variedade de builds, pool de augments por identidade, equipamentos e cartas, mantendo coleta e escolha fora do combate.

1. Sol: pipeline de modificadores/efeitos, limites de proc e proteção contra cascatas.
2. Terra após contrato: preencher pools/ícones/textos e apresentar efeito atual/próximo; proposta inicial 12 gerais + 8 por base, sujeita a E00.
3. Sol: inventário/equipar/cartas/save conforme ADR; testes de elegibilidade, troca sem cura e reset apenas de estado temporário.

Aceite: Ao menos duas builds distinguíveis por classe no demo; coleta pode acumular escolhas, menu só fora do encontro, nenhuma oferta inválida ou cadeia infinita.

Limite: Sem crafting, loja online, monetização ou números de catálogo tratados como compromisso sem balanceamento.

## E07 — Campanha de três fases e boss

Dono inicial: gpt-5.6-sol, esforço high. Dependências: E04, E06.

Três fases com dois encontros e um boss, variação de inimigos e rotas, recompensa/XP e fim de run.

1. Sol: fluxo de fase/recompensa/retorno ao menu, mantendo save transacional.
2. Sol: tanque, conjurador, investida e suporte; budget de inimigos/projéteis.
3. Sol: boss com telegráficos, fases e resposta a CC; Terra para dados de composição depois de estabilizar IA.

Aceite: Completar campanha com três bases, morrer/reiniciar sem perder progresso persistente, seis escolhas de augment, boss vencível sem depender de CC permanente.

Limite: Sem mapas proceduralmente infinitos, multiplayer ou gelo físico antes de decisão específica.

## E08 — Arte, animações e feedback do demo

Dono inicial: gpt-6-astra, esforço high. Dependências: E04.

Pipeline visual consistente das três bases e evoluções do demo, terreno, VFX, ícones e áudio básico.

1. Astra: folhas e pivôs, caminhada por velocidade, direções e orçamento de animação; aprovar uma classe antes de replicar.
2. Astra: VFX de impacto/cast/área e telegráficos legíveis, terreno com profundidade e materiais próprios.
3. Terra em integração delimitada: ícones/layout/áudio já aprovados; Astra valida renderer em gameplay e guarda fontes/prompts.

Aceite: Contato com chão, orientação e cadência convincentes; skills legíveis em grupos e boss; assets locais/licenças/proveniência registrados.

Limite: Sem migrar para chão 3D real, gerar sprites de 80 classes de uma vez ou afirmar FPS sem medir.

## E09 — Integração e primeiro demo bom

Dono inicial: gpt-6-astra, esforço high. Dependências: E02, E03, E04, E05, E06, E07, E08.

Fechar demo de 3 bases, 6 puras, 6 híbridas, menu/build, progressão permanente, campanha/boss e export Windows.

1. Astra: auditoria adversarial de save/input/combate/evolução e revisão de todos os contratos.
2. Sol para defeitos sistêmicos e Terra para UI/export em passos autorizados pelo coordenador.
3. Astra: rebase/composição, verify, renderer, medição de performance e roteiro de playtest; export reproduzível.

Aceite: Build Windows executa sem editor; campanha e progressão funcionam; nenhuma falha bloqueadora; usuário aprova o demo antes do merge.

Limite: Sem release pública automática ou marketing; metas de duração/FPS são medidas, não alegadas.

## E10 — Cinco bases restantes e evoluções

Dono inicial: gpt-5.6-sol, esforço high. Dependências: E09.

Acólito, Bruxo, Druida, Ladino e Monge com seus dois ramos puros, um subépico independente por família.

1. E10a Acólito/Sacerdote/Cultista; E10b Bruxo/Demonólogo/Necromante.
2. E10c Druida/Naturalista/Metamorfo; E10d Ladino/Assassino/Dervixe.
3. E10e Monge/Elevado/Campeão. Sol código; Astra design/arte; Terra dados/UI; cada família passa por review e playtest antes da próxima.

Aceite: Por família: kit completo, progressão, duas builds, augments, animações e campanha/boss; invocações e CC com limites; save compatível.

Limite: Sem executar as cinco famílias num único lote. Naturalista é nome de trabalho; Filho de Gaia pode ser título.

## E11 — Catálogo das 56 híbridas

Dono inicial: gpt-6-astra, esforço high. Dependências: E10.

Revisar identidade das 56 propostas e produzir as 50 além do demo em pares direcionais, com orçamento medido.

1. Astra: reprovar redundâncias e aprovar contratos de cada receita complementar.
2. Um subépico por cada um dos 25 pares restantes da matriz: duas híbridas por vez. Sol implementa apenas o par liberado; Terra preenche dados aprovados.
3. Astra: arte/revisão; playtest do usuário por par; auditoria global de 8 bases + 16 puras + 56 híbridas ao final.

Aceite: Cada par tem dois loops distintos, níveis/augments/save/testes próprios e campanha viável. Catálogo final sem IDs duplicados e 80 identidades rastreáveis.

Limite: Sem lançar 50 kits simultaneamente; exploração de nomes não equivale a aceite de kit nem autorização de execução.

## Protocolo de execução futuro

1. Usuário libera épico/subépico; Astra registra autorização, base aceita e próximo passo.
2. A tarefa reservada confere handoff e estado atual; worktree antiga deve receber a base aceita **antes** de começar, preservando alterações e criando backup. Não implementar a partir de um snapshot obsoleto só porque a conversa foi criada agora.
3. Implementador entrega um passo com commit, contratos alterados e evidências. Astra revisa; reprovação retorna ao mesmo implementador, sem interromper para aceite do usuário a cada correção.
4. Astra integra passos aprovados na branch do épico, repete checks após conflitos e registra checkpoint. Sem avançar automaticamente para épicos ainda não liberados.
5. Ao fechar o épico/subépico, Astra rebaseia, atualiza codex/playtest por fast-forward e fornece roteiro. Usuário usa F5 no diretório habitual.
6. Usuário aprova produto; só então merge em master pela worktree de integração. Correções de playtest continuam no mesmo épico.
7. Registrar por checkpoint: estado, hash-base/entrega, testes, decisão técnica, bloqueio real e próximo comando/passo. Limite de usage não deve deixar status 'concluído' sem testes.

Estados: RESERVADO → LIBERADO → EM_IMPLEMENTAÇÃO → EM_REVISÃO → CORREÇÕES ou ACEITE_TÉCNICO → AGUARDANDO_PLAYTEST → ACEITO → INTEGRADO. Pausa/limite retorna com checkpoint; um chat criado não é um job agendado. Automação do ciclo só opera enquanto a coordenação estiver ativa e o épico liberado. Nenhum heartbeat foi instalado.

Referência do ambiente: [OpenAI Docs — worktrees](https://learn.chatgpt.com/docs/environments/git-worktrees). Worktrees isolam arquivos por tarefa; o fluxo do projeto adiciona revisão, rebase e atualização do diretório fixo. Não usar Handoff para trocar a branch do Godot a cada entrega.

## Planos que exigem decisão antes da execução

Fórmulas e números de nível, respec de evolução, builds/slots, limites de CC em boss, propriedade de equipamentos e política de progresso ao abandonar a run. E00 deve apresentar opções concretas. Escolher Naturalista ou Filho de Gaia não bloqueia nenhum contrato. A matriz de 56 é exploração: nomes e kits novos ainda exigem revisão por par.

