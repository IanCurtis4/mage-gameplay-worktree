# E05 — checkpoint único do Espiritualista

## Autorização, base e divisão de trabalho — 29/09/2026

O usuário aprovou o Elementalista no candidato `ce87065` e liberou a evolução
`spiritualist` do Mago, com entrega de skills uma a uma e checkpoint único da
classe. Astra cuida do atlas e dos sprites/animações das skills, em arquivos
visuais próprios; Sol é dono de runtime, dados críticos, testes, integração e
deste checkpoint. Sem handoff/gate por microtarefa. Revisão de Astra somente
após o escopo completo, seguida de playtest do usuário. `codex/playtest` só
pode avançar após aprovação técnica de Astra; `master` aguarda aceite de
produto explícito. Não começar Arqueiro ou próximo épico.

Base `ce87065`, branch `codex/e05-evolutions`. Contratos: E00_MVP_CLASS_CONTRACT,
ADR_E00_01_CHARACTER_PROGRESSION, MVP/ARCHITECTURE e WORKFLOW. Origem persistente
`mage`; sete exclusivas nos jobs 20/23/25/28/31/34/37; primeira ativa R1
gratuita sem autoequip; carteiras base19/evolução20, cinco ativas e dois
passivos equipados. Herança do Mago segue comprada. O kit precisa de duas builds
legais e loop em boss solo. `content_ready=true` após integração validada.

## Kit finito — escolhas de implementação dentro do contrato

Inspiração do brainstorm: Maldição do Eco, Drenagem canalizada e Procissão de
espectros, não uma especificação de números. Identidade nova: fixar uma maldição
de oportunidade, decidir qual golpe a consome, sustentar ou interromper a
canalização e lançar manifestações curtas sem cadáveres/summons permanentes.
Fraquezas: janela de canal exige ficar imóvel e alvo/linha estáveis; maldição
precisa de segundo golpe positivo; trocar de alvo ou errar perde eficiência.
`Assombro`/`Barreira Fantasma` da base continuam herdadas e não são rebatizadas.

| Gate e skill | Contrato R1; ranks seguintes | SP R1→R5; CD/cast |
|---|---|---|
| 20 ativa gratuita `spiritualist_echo_curse` — Maldição do Eco | Alvo único até 380, impacto direto mágico `0,85/1,00/1,12/1,22/1,30 × ATQM` por rank. Após HP positivo num sobrevivente marca por 5 s; reaplicação renova, sem acumular. Próximo acerto direto positivo elegível do jogador nesse alvo (exceto nova Maldição e Dissipação) consome marca e agenda um único eco de `0,35/0,42/0,49/0,55/0,60 × ATQM` capturado no gatilho, após 0,35 s. Eco é secundário, revalida existência do alvo, sofre mitigação atual e não gera procs/cura/novo eco. Erro/escudo não consome. | `18/20/22/23/24`; 6 s / 0,35 s |
| 23 passiva `spiritualist_echo_recovery` — Recolhimento | Quando a marca produz um eco por dano direto elegível, restitui `2/3/4 SP`; uma vez por emissão e uma vez por segundo por jogador, até SP máximo. Não depende do dano posterior do eco, nem dispara por DoT/secundário. | Sem SP/CD |
| 25 ativa `spiritualist_soul_drain` — Drenagem Espiritual | Canal de alvo até 350 por 2 s, quatro ticks a 0,5/1,0/1,5/2,0 s. Cada tick causa `0,36/0,42/0,48/0,54/0,60 × ATQM` capturado no commit e cura 15% do HP real removido, com teto agregado de 5% do HP máximo do jogador por canal. Só o primeiro tick é raiz direta (pode consumir maldição); demais são secundários. Revalidar vivo/range/LoS a cada tick. Movimento, outro comando de cast, controle, dano recebido ou morte interrompem próximos ticks; SP/CD já gastos não retornam. Nenhum tick em alvo inválido. | `22/24/26/28/30`; 10 s / preparo 0,30 s + canal 2 s |
| 28 ativa `spiritualist_spectral_veil` — Véu Espectral | Zona de ponto até 250, raio 110, duração `3/3,5/4/4,5/5 s`. Uma por jogador; recolocar substitui. Inimigos dentro recebem redução de dano causado de 15% por fonte, renovada enquanto dentro, sem dano nem obstáculo. Reutiliza canal/teto do AttributeDebuffState; boss solo recebe enfraquecimento, não exige adds. | `20/22/24/25/26`; 12 s / 0,25 s |
| 31 passiva `spiritualist_channel_focus` — Foco do Além | Completar os quatro ticks válidos de uma Drenagem sem interrupção gera uma carga por 5 s, no máximo uma. Próxima Maldição ou Dissipação válida consome no commit para adicionar `0,20/0,30/0,40 × ATQM` bruto ao primeiro impacto direto; falha/cancelamento não consome. Não amplia ecos, ticks ou DoT. | Sem SP/CD |
| 34 ativa `spiritualist_procession` — Procissão de Espectros | Três aparições para um alvo único até 380, nas saídas 0/0,20/0,40 s, cada uma com viagem visual e impacto 0,22 s após saída. Cada impacto `0,45/0,50/0,55/0,60/0,65 × ATQM` capturado no commit; primeiro é direto, dois seguintes secundários. Revalidar alvo/LoS a cada impacto e cancelar restantes se inválidos. Um boss sozinho recebe as três; não exige morte/cadáver nem deixa companion permanente. | `24/26/28/29/30`; 10 s / 0,40 s |
| 37 ativa `spiritualist_dissipation` — Rito de Dissipação | Ponto até 330, raio 100, cast 0,60 s. Uma raiz direta por alvo de `0,85/1,00/1,12/1,23/1,32 × ATQM`; alvo previamente amaldiçoado recebe +`0,55 × ATQM` bruto no mesmo pedido e só perde a marca após HP positivo. O rito não gera eco da própria marca. Após dano positivo em sobrevivente aplica redução de dano causado de 20% por 2 s, mesmo canal do Véu (maior fração prevalece). Sem marca, ainda atinge normalmente. | `27/29/31/32/33`; 14 s / 0,60 s |

Todas as distâncias usam a geometria única de runtime/previews. Cast é ajustado
pela DES pelas regras compartilhadas. Acerto direto usa DamageRequest e
StatCalculator; nenhuma fórmula de dano é duplicada no ator/UI. Ticks/eco não
alimentam procs; uma emissão não cria cascata. Marca/carga/zona/canais são
estado da run, nunca Resource de catálogo nem save. Cancelamentos, pausa,
morte, fim de encontro e reload removem estado e nós temporários. Efeitos do
mesmo canal por fontes diferentes usam máximo, nunca soma. Ao entrar com
catálogo novo, migrar aditivamente catalog_version5→6, mantendo saves reais
inalterados até o próprio jogador fazer uma operação; pré-flight/backup do
ProfileStore e testes de versão futura continuam obrigatórios.

## Brief para os assets do Astra — bloqueio visual apenas, não de regras

Atlas `spiritualist` 4 colunas × 8 linhas de células 64×64, pivô lógico
`(32,58)`, 32 poses nos estados de CharacterAnimation: frente idle/walk/cast,
costas walk/idle/cast, frente/costas hurt/death. Passos distintos, botas no
chão, transparência genuína e silhueta do Espiritualista puro (não ranger do
mood antigo). Fenômeno pálido/prata/azul-cinza/carvão, tecido ritual, névoa,
véus e crescentes; não recolorir Elementalista. O pacote final do Astra está
em `649db5e`, com atlas, quatro famílias VFX e pranchas. As texturas já foram
importadas no Godot 4.7.2; Sol integra o atlas e conecta os VFX aos eventos.

Sprites/VFX necessários, com âncoras/tempo autoritativos:

- Maldição: glifo compacto sobre o alvo ao impacto, marca sutil por 5 s e
  fratura espectral após eco disparado em +0,35 s; alvo visual pés/corpo.
- Drenagem: vínculo caster(peito −24 px)→alvo(corpo −18 px) durante canal 2 s,
  quatro ondas em 0,5 s; interromper/dissipar sem fantasma remanescente.
- Véu: círculo no chão de raio 110 e névoa/tecido rítmico por 3–5 s; não
  ilustrar bloqueio de navegação, dano ou área maior que o teste real.
- Procissão: três aparições sem corpo persistente em 0/0,20/0,40 s, trajeto
  caster→alvo e impacto em 0,22/0,42/0,62 s; dissipação rápida, boss solo.
- Dissipação: crescente/anel ao ponto, raio 100, com segunda leitura se marca
  consumida após HP positivo; manter legível sob sprite e telégrafos inimigos.
- Passivas: feedback breve e discreto no caster para restituição real de SP
  ou carga obtida/consumida; não sugerir buff/proc quando não aconteceu.

Assets de arte não mudam hitbox, tempo, custo, regra ou RNG. Sol pode usar
desenho temporário code-native nas fixtures, mas não gerar/editar bitmaps do
Astra. Contrato de apresentação deve expor eventos reais do runtime, com
fila finita, pausa e limpeza. Testar redução na resolução nativa, piso claro
e escuro, frente/costas e sobreposição com HUD.

## Duas builds legais de referência no job 40

Rank efetivo da Maldição inclui R1 gratuito; valor entre parênteses é gasto.
Cada build equipa cinco ativas e duas passivas; resto da biblioteca fica
disponível para compra futura, sem compra/equipagem implícita.

| Build | Base ≤19 pontos | Evolução ≤20 pontos | Equipados |
|---|---|---|---|
| Assombração e canal em boss | Impacto das Almas R5(5), Barreira Fantasma R5(5)=10 | Maldição R5(4), Drenagem R5(5), Procissão R3(3), Recolhimento R3(3), Foco R3(3)=18 | Maldição, Drenagem, Procissão, Impacto, Barreira; Recolhimento, Foco |
| Campo e ruptura | Parede de Gelo R5(5), Regeneração de Mana R3(3)=8 | Maldição R3(2), Véu R5(5), Procissão R3(3), Dissipação R5(5), Recolhimento R2(2)=17 | Maldição, Véu, Procissão, Dissipação, Parede; Mana, Recolhimento |

## Plano e retomada

1. **Contrato/checkpoint e migração segura**, depois catálogo ainda indisponível.
2. **Maldição do Eco** ponta a ponta: alvo/impacto/marca/consumo/eco retardado,
   boss solo, hit nulo, cancelamento, pausa e limpeza.
3. **Recolhimento**, deduplicação de emissão e SP real.
4. **Drenagem canalizada**, interrupção e cura limitada.
5. **Véu**, canal de debuff compartilhado e expiração da zona.
6. **Foco do Além**, carga por canal completado e consumo em cast válido.
7. **Procissão**, três aparições/impactos sem companion persistente.
8. **Rito de Dissipação**, consumo por dano positivo e interação de fontes.
9. **Integração visual do Astra**, catálogo content_ready apenas com kit completo;
   duas builds, migração, menu→run, boss, regressões e verify.ps1 integral.

Commits pequenos e testes dirigidos ao fim de cada item; revisão Astra somente
no fechamento. Registro de hash/resultados abaixo será atualizado conforme
execução. Tempo/tokens por skill só se houver medição atribuível real, não
estimativa inventada. As sete skills, dois presets de personagens distintos,
menu→run e boss solo estão implementados. `content_ready=true`. O teste
integrado revelou e corrigiu o cabeçalho que mostrava “Mago” mesmo usando o
Espiritualista; agora toda evolução pronta usa o próprio nome. A primeira
revisão consolidada de Astra (`docs/REVIEW_E05_SPIRITUALIST_ASTRA.md`) encontrou
quatro ajustes de integração, corrigidos em rodada única: canal interrompido
solta a pose de cast sem apagar um novo cast, halo usa pivô de chão `(48,63)`,
ticks de Drenagem e restituição real de SP têm wisps alvo→caster em fila
finita, e as duas builds executam loops determinísticos contra boss solo.
O redraw cobre também o frame em que o último efeito expira. Astra aprovou
tecnicamente o delta `a4c34f3` após inspeção e 153 checks independentes.
Segue a preparação do candidato de playtest para o usuário. A inspeção de legibilidade
e FPS com muitas skills simultâneas continua dependente do playtest.

Renderização com Godot 4.7.2 standard/OpenGL real: o probe opcional
`tools/spiritualist_renderer_probe.gd` gerou
`.godot/verification/spiritualist_renderer_probe.png` (halo/ritual) e
`.godot/verification/spiritualist_return_renderer_probe.png` (wisp em trânsito).
Inspeção visual confirmou a âncora do halo no círculo autoritativo e o pulso
entre alvo e caster. O modo `--headless` usa renderer fictício e não serve
para capturar a imagem; rodar o probe com `--rendering-method gl_compatibility`
sem `--headless` quando necessário. Capturas são locais/ignoradas pelo Git;
o usuário ainda precisa avaliar a leitura na partida.

| Item concluído | Commit | Testes | Próximo |
|---|---|---|---|
| Contrato do kit | `c129fb0` | conferência documental | 1 — migração |
| Migração aditiva 5→6 | `8a38869` | 14 checks novos + 34 regressões anteriores | 2 — Maldição |
| Arte fonte e atlas Astra | `649db5e` | importação Godot 4.7.2 sem erro; inspeção Astra documentada | integração visual após regras |
| Maldição do Eco | `2f868d5` | 29 checks novos; catálogo de evolução 65 checks | 3 — Recolhimento |
| Recolhimento | `ff8f99b` | 16 checks novos + 29 de Maldição | 4 — Drenagem |
| Drenagem Espiritual | `1a01628` | 24 checks novos + catálogo de evolução 65 checks | 5 — Véu |
| Véu Espectral | `067447f` | 19 checks novos + catálogo de evolução 65 checks | 6 — Foco |
| Foco do Além | `2c0b9ed` | 17 checks novos + regressões Drenagem e catálogo | 7 — Procissão |
| Procissão de Espectros | `9f94f6e` | 18 checks novos + catálogo de evolução 65 checks | 8 — Dissipação |
| Rito de Dissipação | `07e71e9` | 18 checks novos + catálogo de evolução 65 checks | 9 — fechamento |
| Fechamento integrado | `f8c59f0` | 72 checks de builds/menu→run/boss + 18 visuais; `tools/verify.ps1` integral | revisão técnica Astra |
| Ajustes da revisão Astra | `a4c34f3` | Drenagem 28, visuais 23, integração 86 checks; renderer real e nova regressão integral | playtest do usuário após preparo do candidato |
