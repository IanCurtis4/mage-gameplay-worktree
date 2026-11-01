# F9 — roteiro de aceite humano (P7)

Checkpoint51. Roteiro para a pessoa conferir o editor F9 inteiro, sem editar
código, na amostra de [validação](../validation.md) ("Amostra de aceite humano")
e no Bosque do Santuário. O aceite visual e de usabilidade é seu; os testes
automáticos não certificam aparência, diversão ou clareza.

## Onde

Uma cópia de aceite separada de tudo: `.tools/f9_aceite`, aberta por
`.tools/claude_bridge/abrir_editor_aceite.ps1` (botão direito → "Executar com o
PowerShell"). A cópia tem o editor de mapas ligado e um perfil descartável
próprio; o checkout de playtest, o save pessoal, as fontes commitadas e a fixture
dos testes não são tocados. `-Novo` recria a cópia (a anterior é guardada com a
data no nome).

No editor, abra a aba **Mapas** (no topo). A faixa **Roteiro do mapa** fica no
topo de cada tela.

## Tarefas

Para cada tarefa, anote na tabela do fim: tempo aproximado, erros, o que foi
difícil e se precisou de código (deve ser "não").

1. **Biblioteca e peça.** "Biblioteca…" → abra `sanctuary_woods_clearing`;
   "Criar cópia da fonte"; selecione a camada "Clareira".
   *Esperado:* a cópia abre na tela de terreno com a camada selecionada.
2. **Relevo, material e proteção.** Na cópia, esculpa uma subida e um platô
   pequenos; pinte terra batida no caminho; proteja o encaixe leste
   (conexão `a_east`) ou o caminho com uma região protegida.
   *Esperado:* o relevo é suave; a pintura acompanha; a proteção aparece e
   impede alterar a área protegida.
3. **Objeto, desfazer e diagnóstico.** "Objetos e vegetação…" → mova uma rocha;
   Desfazer/Refazer; coloque uma árvore em cima do encaixe e compile; clique no
   diagnóstico.
   *Esperado:* o desfazer é exato; o diagnóstico foca o objeto no viewport.
4. **Encontros e patrulha.** Abra a composição com o Bosque
   (`sanctuary_woods.map.json`), siga "Próximo passo" até Encontros; pinte um
   encontro; fixe um slot; em Patrulhas, mova um ponto da rota `alley_watch`.
   *Esperado:* "Preparar prévia" mostra o diff antes de aplicar; o slot fixo
   não muda ao sortear de novo; a rota inválida é apontada no ponto.
5. **Montagem e variação.** Na composição, monte duas peças manualmente e ligue
   as aberturas; em "Geração assistida…" gere uma variação com uma posição fixa;
   em "Variação regional…" faça uma variação de relevo numa região, mantendo uma
   área protegida.
   *Esperado:* a posição fixa e a área protegida ficam idênticas; a prévia vem
   antes de aplicar; um desfazer volta tudo.
6. **Salvar, reabrir, publicar e testar.** Salve tudo, feche o editor, reabra
   (o script de novo, sem `-Novo`) e reabra os arquivos. No roteiro, siga até
   "Testar no jogo"; jogue; feche o jogo; "Publicar no jogo…" com um
   identificador de teste (por exemplo `aceite_bosque`).
   *Esperado:* nada se perde ao reabrir; a publicação diz se é mapa novo ou nova
   revisão e só grava depois de "Publicar" (na cópia de aceite).
7. **No jogo.** Ande na rampa, no platô, sobre e sob a ponte; passe atrás de
   árvores; lute com um inimigo; afaste-se para ele voltar à patrulha.
   *Esperado:* o personagem é legível na rampa e na ponte; árvores à frente
   ficam translúcidas; navegação, combate e retorno funcionam.
8. **Proposta de skill num clone.** Em "Intercâmbio com skills…", exporte um
   pedido de uma cópia da clareira; importe uma proposta (por exemplo, a que o
   Claude preparar para você); revise o diff; **rejeite**.
   *Esperado:* a fonte não muda; nada é perdido.
9. **Roteiro entre telas.** Mude a peça na tela de terreno e veja o roteiro
   marcar o mapa como desatualizado; siga "Próximo passo" até as patrulhas,
   revisando cada atualização.
   *Esperado:* cada etapa pede revisão antes de aplicar; "Mostrar o problema"
   abre a tela certa quando algo é recusado.

## Conferência visual do Bosque

Olhe o Bosque no jogo e no editor e diga se está crível e legível:

- clareira e caminho curvo de terra batida;
- platôs com rampas, ponte e passagem inferior (beco);
- bifurcação no bosque oeste, emenda entre as duas peças;
- santuário com pilares e o ponto de conclusão;
- árvores, arbustos e rochas; relevo suave; bordas da floresta;
- encontros espalhados, grupo e a patrulha.

## Registro

| Tarefa | Tempo | Erros | Difícil | Precisou de código? | Observações |
| --- | --- | --- | --- | --- | --- |
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |
| 6 | | | | | |
| 7 | | | | | |
| 8 | | | | | |
| 9 | | | | | |
| Visual | | | | | |

Decisão: **aceito / aceito com ressalvas / não aceito**, e o que precisa mudar.
Pode responder no chat; o resultado entra no recibo da F9 (P8). Nada é integrado
em master sem esse aceite.
