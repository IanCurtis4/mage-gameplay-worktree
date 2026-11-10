# Roteiro de revisão do candidato E08 (P4–P6)

Use somente o candidato isolado em `.tools/playtest_e08/e08_<hash>` e os atalhos
**Jogar E08 - Corpo a corpo / Magia / Arco**. Cada atalho abre o mesmo EXE+PCK com um
perfil próprio (APPDATA isolado dentro da pasta `profiles/<grupo>`), separado do
perfil pessoal, do RagRPG habitual e do piloto P3. Não copie saves entre builds.
[Recibo técnico](e08_p7_release.md), [medições](e08_p7_measurements.md).

Os perfis já trazem personagens em níveis máximos legais do modo de teste, habilidades
legais liberadas e organizadas na barra, e peças existentes no inventário:

| Atalho | Personagens |
|---|---|
| Corpo a corpo | E08 Espadachim, E08 Defendente, E08 Berserker |
| Magia | E08 Mago, E08 Elementalista, E08 Espiritualista, E08 Geômetra |
| Arco | E08 Arqueiro, E08 Sentinela, E08 Caçadora |

Nenhum item ou taxa de drop novo foi criado; as peças são as já permitidas a cada classe.
Em Admin/F10 continuam disponíveis as concessões normais do modo de teste.

## Como entrar

- **Treino rápido:** selecione o personagem e use **Treinar contra boss e reforços (sem
  salvar XP)** para ver poses, equipamento e efeitos em sequência curta.
- **Mapa real:** **Floresta do Santuário**, seed **42**. A preparação inicial ainda leva
  cerca de 50 s neste computador (dívida F10, não resolvida em E08).
- Teste interface **120%** e zoom **50/100/160%** pela roda do mouse fora dos painéis.

## P4 — corpos e equipamento

- Vire o personagem para frente, costas e os dois lados; caminhe e use as ações. As quatro
  vistas devem manter roupa, rosto, mãos e porte, sem trocar braço ou equipamento.
- Equipe e retire a peça de cabeça: acessório pequeno sobre o cabelo, rosto legível;
  Mago, Arqueiro, Caçadora, Sentinela e Geômetra usam base de cabelo com acessório.
- Armas e escudos: cabo na mão, dedos à frente da pegada, sem equipamento duplicado.
  Arco e flecha acompanham o lado do disparo. Equipamento solto na morte apoia no chão.
- Compare o retrato do inventário com o personagem no mundo usando a mesma peça.

## P5 — floresta

- **Espécies:** Lobo da Mata, Javali da Encosta, Espreitador da Mata, Arqueiro da Copa
  (um único arco, embutido no corpo) e Guardião Ancestral (covil). Cada um com corpo
  próprio nas quatro vistas, sem virar raposa ou lobo genérico.
- **Materiais:** grama, terra e areia novas (v2); pedra/penhasco mantidos. Observe
  emendas, repetição visível e contraste com os atores em chão claro e escuro.
- **Bétula e decoração:** bétulas entre os carvalhos (mesma base/raiz que o carvalho),
  samambaias, flores do campo, anel de cogumelos e tronco caído. Decorativos não bloqueiam
  passagem nem visão; bétula se comporta como árvore (corpo, linha de visão, oclusão).
- **Ambiente:** folhas e pólen à deriva, feixes de luz e névoa leve na tela, sem cobrir
  indicadores de perigo, alvo ou área; som ambiente de floresta contínuo. Pausar congela.
- Rampas, pontes, oclusão e minimapa continuam como na F10.

## P6 — efeitos e sons

Use as habilidades de cada classe perto de inimigos, em chão claro (areia/terra) e escuro
(grama), nos três zooms. O que olhar e ouvir:

- **Assinaturas com folha animada:** Bola de Fogo, Teleporte, Corte em cone, Grito
  Aterrorizante, Armadilha Explosiva, Onda de Represália, Contraforte, Fenda Sangrenta,
  Arco Voltaico, Colapso Geométrico, tiro explosivo da Sentinela, armadilha congelante da
  Caçadora e invocação do Guardião. As demais ações usam efeitos desenhados por família e
  elemento (lançamento, impacto, área, cura, movimento, armadilha).
- **Sons:** cada família/elemento e cada assinatura tem som próprio (75 sons novos e 11
  refeitos, aceitos na prévia de 9/11). Confira volume relativo entre lançar, acertar e
  área, repetição em grupo grande (o limitador protege a soma) e os canais Geral/Efeitos/
  Interface/Ambiente no painel de áudio. Prévia A3 em `review/audio/`.
- **Pontos fracos conhecidos — julgar em jogo:**
  - onda de choque (grito, represália, colapso): contorno escuro pode ficar **pesado em 160%**;
  - espinhos da armadilha de natureza: ainda **pequenos em 50%**;
  - setas de investida (Guardião): **pouco contraste sobre areia**;
  - **velocidade das folhas**: agora no ritmo autoral (1,0–1,6 s por efeito); diga se
    parecem lentas demais ou se a cauda transparente incomoda.
- Efeitos e sons são apresentação: não mudam dano, alcance, linha de visão, recarga,
  recompensas ou save. Golpe corpo a corpo e impacto do mesmo golpe podem soar em ordem
  invertida por um quadro (limitação documentada).

## Correções do primeiro playtest (candidato `261801de`)

Conferir de novo o que foi pedido no primeiro playtest:

- **Rastro de caminho:** ao clicar para andar, só o marcador de destino (anel com cruz)
  aparece; nenhuma linha da rota fica desenhada depois do movimento.
- **Ataque básico** (todas as classes): sem rajada na saída do disparo; o Arqueiro mostra
  uma única flecha em voo. No acerto, uma estrela branca curta com contorno escuro, legível
  em 50% e 160%. Habilidades com assinatura continuam com a arte própria.
- **Som do ataque básico:** acerto mais seco (corpo; Espadachim mais grave; crítico mais
  agudo) e soltura de arco própria do Arqueiro. Clipe antigo × novo em
  `review/audio_c5_ataque_basico/`.
- **Peças de cabeça:** encaixe ajustado por classe e por quadro nas quatro vistas, também em
  dano e cadáver. Antes/depois em `review/c6_cabeca_antes_depois/`. Limites conhecidos:
  Berserker ainda mostra cabelo nas laterais; chapéu da Caçadora sobre cabelo volumoso nas
  costas; fitas da grinalda (Elementalista) e do véu cruzam o rosto de lado; tiaras deixam o
  cabelo acima visível por design.

## Correções do segundo playtest (candidato final `6b42b305`)

- **Linha de mira:** ao usar uma habilidade num alvo inválido, não fica mais uma linha
  vermelha no chão depois que o personagem se move; resta só o marcador (anel com cruz,
  vermelho quando inválido). A linha de mira também deixou de aparecer quando válida.
- **Acerto branco em todas as classes:** ataque automático de todas as classes e evoluções,
  garra e flecha inimigas e habilidades físicas comuns (sem assinatura própria) mostram a
  mesma estrela branca curta. Impactos de elemento (fogo, gelo, raio, arcano, espírito,
  natureza, geometria, sangue) e assinaturas mantêm a arte própria. Sons não mudaram.
  Antes/depois em `review/c7_rodada2_antes_depois/`.

## Arte nova de cabeça (candidato `d6004142`)

- **Grinalda do Elementalista** e **chapéu da Caçadora** foram redesenhados (mesmas peças,
  mesmos IDs, nada de atributo ou drop mudou). A grinalda ficou um anel fino na linha do
  cabelo, sem fitas sobre o rosto; o chapéu foi refeito nas quatro vistas. Conferir as quatro
  vistas, dano e cadáver com a peça equipada. Antes/depois em
  `review/c8_arte_cabeca_antes_depois/`.

## Limites preservados

As medições técnicas não certificam FPS de toda a campanha; carregamento inicial, portais e
picos ocasionais continuam dívidas F10. Aceite visual e sonoro é humano e separado dos testes
automatizados. Este roteiro não autoriza merge em master, push nem alteração do checkout
habitual `codex/playtest`.
