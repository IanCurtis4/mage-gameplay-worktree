# Entrega técnica — kit inicial do Mago

Branch `codex/mage-gameplay`, baseada em `c6ea3d1`. Esta entrega implementa apenas
o bloco autorizado de segunda classe. Parede de Gelo, Assombro, Barreira Fantasma,
progressão, equipamentos, cartas e o restante do Marco 2 continuam fora do escopo.

## Contratos implementados

- `ClassDefinition` e `SkillDefinition` são dados de catálogo compartilhados somente
  para leitura. `RunState` guarda `class_id`, níveis de skill e stacks; `PlayerActor`
  guarda mana e cooldowns. Toda nova run recria essas instâncias.
- A seleção de classe informa que a ação inicia nova run e recarrega a cena. Isso
  remove atores, projéteis, paredes, status, augments, recursos, cooldowns e progresso
  de encontro. Reiniciar com R preserva a classe escolhida durante a sessão.
- `DamageRequest.force_critical` expressa a regra da Bola de Fogo. `CombatMath`
  ainda exige acerto e `can_crit`; o projétil ativa a flag somente se a queimadura
  estiver vigente no impacto.
- Queimadura e slow pertencem a cada `CombatActor`. Queimadura renovada mantém uma
  única cadência de um tick por segundo; ticks são mágicos, secundários, sem crítico
  e sem cascata. Slow usa um multiplicador temporário, sem alterar `RpgStats`, e
  reaplicações não se multiplicam.
- `MageProjectile` ordena continuamente contato com alvo e obstáculo. A Bola segue
  direção fixa e para no primeiro contato; lanças seguem o alvo selecionado e paredes
  ainda as interrompem. Alvo morto/inválido encerra a lança.
- A Parede de Fogo é um único runtime com quatro pilares perpendiculares, atravessável
  e ativo por 5 s. Sobreposição entre pilares renova a mesma queimadura.
- A Investida percorre o corredor em 0,18 s e usa `dash_destination` tanto no preview
  quanto na execução. O deslocamento fica visível e nunca ultrapassa o obstáculo.
- `CombatActor.presentation_action(action, direction, duration)` é o hook comum para
  a integração visual de Astra. Jogador emite auto, slash, dash, cast e teleport;
  inimigos emitem auto aceito. Gameplay não espera a animação.

## Valores iniciais de catálogo

| Ação | Custo | Recarga base | Poder | Alcance / velocidade |
|---|---:|---:|---:|---|
| Auto do Mago | 0 | ataque básico | 1,00 × ATQM | 250 além dos corpos; 620 u/s; máximo 420 |
| Bola de Fogo | 18 | 2,5 s | 1,80 × ATQM | 700; 680 u/s |
| Parede de Fogo | 24 | 7,0 s | 0,30 × ATQM por tick | centro 180; 4 pilares, espaçamento 54, raio 22 |
| Lança de Fogo | 16 | 3,0 s | 1,35 × ATQM; ×1,5 queimando | 360; 760 u/s |
| Lança de Gelo | 14 | 3,0 s | 1,10 × ATQM | 360; 760 u/s; slow 30% por 2 s |
| Teleporte | 22 | 6,0 s | — | 320 |

Recargas recebem o `cast_multiplier` derivado no lançamento. O Mago usa
2/5/5/9/7/2, ATQM 28, mana máxima 85 e a passiva acrescenta 50% à regeneração
compartilhada, resultando em 9 mana/s. O augment `extra_spear` concede +1 lança por
stack (máximo três stacks), com custo único por lançamento.

## Validação

`tools/verify.ps1` importa o projeto com Godot 4.7.2, roda a suíte headless e faz
smoke da cena. `mage_gameplay_test.gd` cobre ordem alvo/parede, burn vigente e
expirado, renovação sem quatro cadências, slow e pausa, multi-lanças com custo único,
alvo morto, teleporte livre/sólido, dash intermediário/bloqueado, reset de runtime,
isolamento da barra e auto mágico à distância.

Também foi feita captura pelo renderer Compatibility real em 1280×720. HUD com cinco
ações, barra Q/W/A/S/D e preview da Parede de Fogo permaneceram legíveis; o painel de
ajuda foi deslocado para não ficar sob o botão de classe.

## Roteiro de playtest

1. Abra **Classe: Espadachim**, escolha Mago e confirme que a arena reinicia.
2. Teste Q/W/A/S/D nos três modos de lançamento e cancele com direito/Esc.
3. Queime um inimigo na Parede, compare Bola e Lança de Fogo durante/depois do burn
   e confirme o slow visual da Lança de Gelo.
4. Teleporte através de uma plataforma para chão livre e tente terminar dentro dela.
5. Volte ao Espadachim e confirme a Investida visível parando antes da plataforma.

As decisões numéricas são iniciais para playtest. A arte ainda usa o herói provisório
na branch de gameplay; spritesheets e o `CharacterAnimationView` serão integrados
pela branch de animação antes da revisão final.
