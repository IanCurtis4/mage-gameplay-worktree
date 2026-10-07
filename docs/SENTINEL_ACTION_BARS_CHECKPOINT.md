# Sentinela solo e barras — checkpoint consolidado

07/10/2026. Contrato: [SENTINEL_ACTION_BARS_PLAN.md](SENTINEL_ACTION_BARS_PLAN.md).
Autorização e decisão de passivas automáticas conferidas na conversa humana de
Astra, turno `01a1172a-0d03-7ae0-9078-5f7041ba0913`. Este escopo substitui o
cabeçalho histórico do Defendente; não libera classes ou épicos seguintes.

Branch `codex/sentinel-action-bars`, base revisada
`f67fc412af20ce9cb8d263edaaf00f41f4267e6d`. Candidato: HEAD contendo este
checkpoint. Implementação e regressões concluídas; revisão técnica independente,
preparação de playtest e aceite humano ainda pendentes. Aprovação da base não
aprova este delta. Checkout habitual permanece em `codex/playtest` na base.

- `4158265`: contrato autorizado e abertura do checkpoint.
- `c18d7c8`: Foco solo, biblioteca legal, passivas automáticas e persistência.
- `17350f6`: barras, input, editores, integração e probes nativos.
- `0b7e277`: regressões globais e registro dos seis testes novos no verificador.
- Commit deste checkpoint: arquitetura atualizada e fechamento da evidência.

## Comportamentos implementados

- Foco intrínseco 4/0,5 s por ação direta própria positiva, ledger 256/TTL 10 s,
  pausa/letal/AoE/ICD/secondary, preservando Observe/Leitura/estabilidade/reserva.
- Biblioteca canônica por identidade/rank/gate; todas as passivas aprendidas
  legais automáticas. Presets 5+2 persistem como legados, sem controlar o runtime.
  Rank, job, pré-requisitos, origem e definição concreta continuam obrigatórios.
- Layout 24 por personagem, migração selecionada com ordem/vazios, codec estrito,
  facade somente organização inclusive durante run, sem alterar snapshot.
- Editor pausado e menu: biblioteca, arrastar/trocar/remover, alternativa clicável,
  binds globais exatos/captura/conflitos. RELEASE congela skill do key-down.
- Geômetra F1/F2/F3/F6; recompensa F8/restart F9. Teclas 1/2/3 não sequestradas.
- Treino retry recebe cópia da barra da sessão sem salvar ou mutar build atual.

## Evidências dirigidas do implementador (não aprovação independente)

Godot 4.7.2 standard Compatibility. Fixtures/configs isoladas, sem save pessoal.
Foco puro 85; integração real 73; input 105; UI 74; persistência 228;
input/controller 59; Sentinel antigos 1559 + integração 341 + builds 300 + guia 140;
passivas das bases 169. Layout 30 (1280×720 e 1920×1080).
Prova nativa de drag real pelo Viewport: 30 checks / 4 capturas em
`.godot/verification/action_bar_native`; jogo/menu: 200 checks / 9 capturas em
`.godot/verification/action_bar_game_native` (Sentinela, Geômetra,
Espiritualista e Mago). Provas são leitura/layout, não qualificação de FPS.

Rotação solo de 60 s a 30/60/144 Hz usa atores reais e dano aplicado no emissor:
86/87/90 autos, 8/8/10 Cabeças, 340/340/360 Foco ganho; 240/240/300 gasto;
saldo 100/100/60, movimento aproximadamente 11,7 mil unidades. Cadência existente
difere por frame; não há
ajuste global de ASPD/movespeed e isto não mede IA/projéteis/DPS em partida.

## Achados resolvidos nesta retomada

1. Padding herdado expandia cartão e empurrava barra até y=722: padding local
   compacto; layout e renderer passam.
2. Clique em cartão sob tecla RELEASE podia manter latch: mouse cancela latch.
3. Retry treino perdia organização: novo snapshot copiado somente no restart.
4. Biblioteca aprendida expandia lista antiga HUD sobre arena/barra: lista
   duplicada oculta para todas identidades; feedback permanece nos cartões.
5. Botão Classe desenhava sobre editor: ocultado durante modal de controles.
6. Queries menu e runtime divergiam em gate: opções compartilham snapshot legal.
7. Metadata futura sem implementação aparecia no ator: disponibilidade exige
   definição concreta do catálogo runtime, com regressão de fronteira.
8. Testes antigos acessavam seletores removidos e podiam emitir erro com exit 0:
   fluxos atualizados para biblioteca/barra, mantendo asserts de compra, save,
   reload e execução, com rejeição de erros pelo verificador integral.

## Validação integral e vínculo ao candidato

`tools/verify.ps1` integral terminou com exit 0: import do editor, 152 scripts
de teste e smoke da cena, sem `ERROR:`/`SCRIPT ERROR:`/`Parse Error:`. Log:
`.godot/verification/action_bars_verify.log`. Código/testes estavam estáveis;
documentação e commits foram consolidados durante a execução. Este log legado
não é relatório vinculado ao commit final nem substitui a reprodução do revisor.

CLI externo explicitamente autorizado, sem copiar tooling:
`C:/Users/João Pedro/.codex/worktrees/menu-tabs/RagRPG/tools/workflow/workflow.py`.
Origem `0c008d4843d13f772aa2b69be22d24d2300b80a1`; SHA256 do CLI
`e642dbe882cd7ea3cd687da51ed978bdecc93675fbb31d08d26626a0b40a1bae`.
Seleção usa as inscrições atuais de `tools/verify.ps1`, não manifesto antigo.
Após o commit documental, executar `validate --project <d066> --suite all
--role implementer --godot <engine>` em HEAD limpo e estável. Relatório local
em `.godot/workflow/*/report.json`: o handoff informa caminho efetivo e resultado;
`status` identifica o relatório com `current_inputs=true`. Só um resultado
`complete=true`, `status=passed`, associado ao HEAD final, fecha esta evidência.
Nenhum relatório anterior/reaproveitado foi promovido a aprovação nova.

Primeira tentativa integral encontrou GitPlugin/cache do engine externo. A
execução válida usou `safe.directory` apenas no processo e permissão dos caches
de revisão; sem mudança global de Git ou `project.godot`. Auditorias parciais,
execuções interrompidas e falhas anteriores não são evidência integral final.

## Limitações e roteiro de playtest

Nomes longos usam abreviação no cartão e texto completo no hover/biblioteca.
Personagens novos começam com barra vazia: abrir editor para atribuir skills
aprendidas. Binds exatos exigem combinação explícita quando se deseja lançar
com Shift no INSTANT; nos modos de mira, Shift pode ser usado na confirmação.
Arte, desempenho e balanceamento fora do contrato não foram ampliados.

Após aprovação técnica e preparação por Astra:

1. Personagem antigo: confirmar migração da ordem/vazios, ranks e equipamentos;
   personagem novo: aprender e arrastar uma skill, sem concessão automática.
2. No menu e em batalha pausada, trocar/remover/reordenar e testar slot 24;
   reabrir jogo e confirmar layout por personagem e binds globais persistidos.
3. Testar CONFIRM, RELEASE e INSTANT; soltar Alt antes da tecla, clicar sob
   tecla pressionada, cancelar, digitar e remapear com conflito explícito.
4. Sentinela solo em movimento: ganhar Foco com autos/dano direto, gastar em
   reset/rede/explosivo; pausa/menu não consome reserva nem acelera relógios.
5. Confirmar passivas automáticas, treino/retry preservando barra e regressão
   breve de Geômetra (elementos/Shift), Espiritualista e Mago.

Próximo passo autorizado: relatório integral do HEAD final e handoff único ao
Astra para revisão independente deste escopo completo. Aprovação técnica libera
preparação por Astra; aceite de gameplay continua com o usuário, merge depois.
Não alterar checkout habitual, master, saves pessoais, assets ou novas classes
durante esta entrega.
