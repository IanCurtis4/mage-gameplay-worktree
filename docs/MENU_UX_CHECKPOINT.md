# Menu inicial — UX em três abas

03/10/2026. Escopo autorizado pelo usuário em paralelo à Geômetra.
Base: 91b5f63; implementação isolada em codex/menu-tabs.

## Resultado

- Personagem e atributos: lista de alts, criação recolhível, atributos compactos
  com detalhes em tooltip, XP e resumo da build salva.
- Skills: busca por nome, grupos base/evolução, compra de ranks e coluna própria
  de cinco ativas/duas passivas. Colunas têm rolagem independente.
- Classe e equipamento: opções de evolução elegíveis, confirmação explícita,
  itens compatíveis disponíveis e modo admin recolhido.
- Identidade, preset e início de run permanecem acessíveis fora da rolagem.
  O marcador "padrão" distingue preferência persistida do personagem em foco,
  que é o personagem editado e indicado no botão de iniciar run.

## Divulgação progressiva

Skills de outros ramos e de rank zero com requisitos de job/pré-requisito
pendentes não aparecem. Falta de pontos não esconde uma skill já liberada;
explica o botão desabilitado. Skills aprendidas continuam visíveis para equipar
ou aprimorar, inclusive quando o próximo rank ainda está bloqueado.
A UI apenas projeta metadados/summary da facade; todas as compras continuam
revalidadas pelo domínio, sem fórmulas de stats/combate ou alterações de save.

Evoluções sem conteúdo ou requisitos não aparecem. Depois da escolha normal,
a lista e os botões de confirmação desaparecem; o resumo da identidade fica.
Modo admin é a exceção explícita já autorizada para trocar de evolução.
Equipamento sem itens compatíveis oculta seu slot e apresenta estado vazio.

Selecionar skill/equipamento salva o preset via update_preset. Falha exibe erro
e restaura a seleção persistida; não deixa uma build aparentemente salva que
seria perdida ao trocar de aba/alt/preset. Botão manual de salvar preservado.
Input de navegação fora da lista não troca o personagem em segundo plano.

## Validação

Teste novo tests/menu_tabs_test.gd integrado a tools/verify.ps1:
- perfil vazio, alts, gate e escolha de evolução, exceção admin;
- desbloqueio por job, skills de outros ramos ocultas e busca vazia;
- compra/equip, autosave, falha de escrita, troca de presets e reabertura;
- foco de teclado, abas e rodapé dentro da janela;
- captura opcional pelo renderer: -- --capture-menu.

Capturas inspecionadas em 1280x720 e 960x540, renderer Compatibility.
Versões 1280x720 em docs/art/menu_ux/. Fixtures usam somente .godot/verification;
nenhum personagem ou save real foi alterado durante a verificação.

Verificação integral: tools/verify.ps1 com importação, todos os testes e smoke,
saída 0, 118 relatórios PASS, sem ERROR/FAIL. Menu novo: 38 checks headless;
44 com as seis capturas do renderer. Regressões E02: 24, E03 painel: 5,
E05 evolução: 25 checks. Não usar capturas/testes como aceite humano de UX.

## Integração e limites

Não inclui runtime parcial da Geômetra. Sol mantém o desenvolvimento isolado;
incorporar este commit ao E05 antes da integração final, preservando a adição
do teste de menu e dos testes da Geômetra em tools/verify.ps1.

Aceite visual/de usabilidade do usuário e merge em master permanecem pendentes.
A biblioteca de skills continua em lista pesquisável, sem árvore gráfica nova.
Trocar duas skills de posição requer esvaziar um slot antes de preenchê-lo;
a validação continua proibindo duplicatas. Não há novo contrato de drag-and-drop.
