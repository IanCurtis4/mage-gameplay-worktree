# E04-MGI — fechamento integrado do Mago

Base `81d8df1` (aceite do candidato anterior em master). Escopo: cenário
integrado e auditoria do kit existente; nenhuma skill, fórmula, save ou
comportamento jogável novo. Branch de implementação `codex/e04-base-classes`.

`tests/e04_mage_integrated_closure_test.gd` percorre perfil isolado em
`.godot/verification`, compra os 13 IDs do Mago com a carteira real de 19
pontos e confere R0, nomes em pt-BR e equipagem manual. Salva/reabre dois
presets com cinco ativas e a única passiva disponível; o segundo slot passivo
permanece vazio, sem habilidade inventada.

- Elemental: Bola de Fogo, Parede de Fogo, Lança de Gelo, Relâmpago e
  Descarga Elétrica. Reproduz Eletrizado → Descarga com dano e consumo da
  marca, sem depender do stun aleatório; também verifica slow do gelo.
- Espiritual/defensiva: Impacto das Almas, Assombro, Barreira Fantasma,
  Parede de Gelo e Teleporte. Confere sequência, fear/enfraquecimento,
  interceptação de projétil, navegação atravessável da barreira fantasma,
  colisão sólida temporária do gelo e mobilidade.

Em ambas, o menu inicia uma run real; snapshot, preview, HUD, ranks e SP regen
derivado são conferidos. Um melee e um arqueiro emitem ataques; os encontros
terminam com recompensa, limpeza de efeitos e encerramento persistente sem
escolha obrigatória de augment. Lança de Fogo e Parede de Raios continuam
disponíveis na biblioteca, mas não cabem nesses dois loadouts; suas suítes
individuais e as regressões das três classes rodam em `tools/verify.ps1`.

## Evidência e limites

MGI: 101 checks. `tools/verify.ps1` completo em Godot 4.7.2 inclui importação,
as suítes de Mago, Arqueiro e Espadachim, e smoke. XP máximo de job é fixture
de perfil isolado; 400 HP no arqueiro evita abate antes de exercitar o combo;
dano final elevado força o fim do encontro. Isso demonstra transições e
limpeza, não balanceamento, dificuldade, desempenho nem diversão. O visual
das skills ainda é provisório; a abrangência parcial do playtest do usuário
continua uma limitação de produto, não um defeito reproduzido.

Auditoria do recorte aceito: nenhum bloqueio jogável adicional foi reproduzido
pelos cenários MGI e regressões existentes. E04 permanece no gate técnico de
Astra para este fechamento; E05 não foi iniciado. Não alterar `codex/playtest`
ou `master` por esta entrega. Como não há mudança jogável, o candidato aceito
anterior não precisa ser substituído por este teste/documentação, sujeito à
decisão de integração de Astra.
