# E05 — Sentinela: checkpoint consolidado

04/10/2026. Implementação autorizada em 03/10/2026; condutor Sol 6.1.
Contrato: E05_SENTINEL_PLAN.md. Biblioteca 7 ativas/2 passivas, slots 5+2.

## Estado

Plano e checkpoint de Astra incorporados, sem código de menu-tabs. Branch isolada
`codex/e05-evolutions` avançou por fast-forward de b53eb58 para e103162, limpa
antes da abertura. A autorização humana foi conferida no chat de Astra.
Geômetra revisada está em playtest, sem aceite de produto inferido por iniciar
Sentinela. Diretório habitual/codex-playtest e saves pessoais permanecem intactos.

S0–S7 concluídos no candidato isolado, em commits por bloco/skill e sem gates
intermediários. Verificação completa PASS; próximo passo é a revisão técnica
integrada de Astra, em um único handoff. Nenhum aceite humano foi inferido.

## Abertura / S0

Base e103162; leitura dos contratos concluída. Foco observa `encounter_active`
canônico de RunController, inclusive treino/boss; não infere combate do alvo.
Reset será uma emissão especial imediata que inicia recuperação normal e não
consome a munição Explosiva. A classe continuará bloqueada até S7 integrado.
Catálogo/ranks são pacote delimitado independente; matemática e transações
permanecem com o condutor. Sem alteração de schema ou atributos globais.

S0 fechado: nove IDs/handlers/ranks, gates/free rank, override parcial e
`content_ready=false`; `SentinelTuning`/`SentinelMath` com INT isolada, coeficientes
aditivos e CD DES local. Duas builds de 20 pontos planejadas no contrato.
Import PASS, catálogo 749 checks, matemática 72 checks, Geômetra builds 341 PASS.

S0 commit b7ec8b8. S1 fechado: Foco run-only com movimento efetivo, estabilidade,
decay fora de encontro e pausa; Observar com três acertos e cadência por emissão;
Postura condicional no StatCalculator, retirada antes do auto após deslocamento.
Medidor/retículo/marca mínimos acompanham o sistema, sem save novo. Teste real e
pure: 338 checks PASS em 30/60/144 Hz, sem multiplicar ganho por AoE; hit letal
válido é distinguido de alvo previamente morto. S7 fará acabamento de apresentação.

S1 commit a258cec. S2 fechado: Cabeça valida alvo/LoS/SP/Foco/CC antes de cobrar,
emite um projétil com snapshot e inicia recuperação normal do auto. Um guard por
frame impede auto comum posterior no mesmo frame, inclusive com delta grande.
126 checks PASS (ranks, recusas, três modos de input, projétil real, pausa e
limpeza); regressão de perseguição/inércia 41 PASS. Trajetória própria e estado
SEM FOCO acompanham o disparo. Arte original gerada para normalização posterior.

## Registro compacto a manter pelo condutor

S2 commit 4e20f95. S3 fechado: Perfurante direcional sem alvo, um projétil mágico
INT+DES com crítico normal, atravessa corpos uma vez e para em paredes/alcance.
CD DES local aplicado antes do modificador canônico; mira acompanha cursor.
219 checks PASS: 30/60/144 Hz e delta longo, deduplicação, parede, snapshot,
marca e isolamento de atributos/CD. Cabeça 126 checks PASS novamente.

S3 commit 07a735b. S4 Rede fechada: projétil abre no primeiro corpo/terreno/ponto,
área com LoS/deduplicação, INT isolada, root após impacto pelo canal mágico.
167 checks PASS: ranks, boss cap/budget, ataque permitido sob root, preparo
cancelável grátis, revalidação, parede, delta/frequências, shield/proc/limpeza.
Revisão interna corrigiu a tag de controle para `magic`; ID da skill não é canal.

Rede commit 204533d. Explosivo fechado: reserva SP/Foco sem custo/CD/reset,
cancelamento libera, próximo auto revalida e paga uma vez, substituindo dano
físico por INT e área sem duplicar principal. 162 checks PASS: ranks, recursos
livres, snapshots no lançamento, alvo trocado/perdido, LoS, proc único, input,
pausa/morte/fim e nenhum auto gratuito. Resets não consomem a reserva.

Explosivo commit f11b183 (166 checks com dispatcher adicional). Concussão
fechada: reset ST físico baixo, stun/debuff após dano positivo por canais
canônicos, snapshot do controle em voo. 313 checks PASS: ranks, crítico não
alonga CC, boss/resistência/budget, miss/shield/dead, debuff MAX, proc antes de
controle novo, recursos e reserva intacta. Cabeça 126 PASS novamente.

Concussão commit 1abe305. Leitura já implementada em S1, agora validada com
Rede/Concussão/Explosivo reais: OR crítico/CC anterior, uma devolução por ação,
ICD 1s, sem qualificar seu próprio novo controle. Absoluto fechado: duração
4–6s, +20% alcance (não raios/colliders), ganho 15/s imediato apenas parado,
sem dispensar Postura .75s, sem reset/auto-renovação. 228 checks PASS incluindo
30/60/144 Hz, expiração parcial, snapshots, pausa, morte/fim e stats sem cura.

Absoluto commit 2816938. S6 fechado: duas builds com compras reais 19 base/20 evolução, 87 atributos,
5+2 slots, equipamento nulo controlado. 300 checks PASS: evolução/gates,
rank grátis sem autoequip, menus job22/31/37, carteiras/slots, save/reload/legacy,
treino sem write/recompensa, locks/respec. Tooltips mostram atual/próximo rank.
Comparação R5 (crítica/caster): Perfurante 145,4/249,8 bruto, CD 4,556/4,662s;
Rede 40/130; Explosivo 73,4/262,4. Mesmos custos/rank; não é medida de DPS.

S6 commit ea5d44a. S7 fechado: atlas original 4×8 com fonte/prompt preservados,
animações frente/costas, VFX identificáveis, indicadores de munição/Absoluto,
medidor de Foco/SP reservado, guia recolhível e cards de custo/estado sem corte.
Biblioteca completa habilitada somente neste candidato (`content_ready=true`).
Orçamento de 12 bursts cosméticos não limita dano, controle ou procs; treino e
boss usam o estado de encontro canônico. A integração mantém 5+2 slots, saves e
atributos globais existentes; Caçador e outros marcos não foram iniciados.

Auditoria final corrigiu a reserva de Explosivo: ela não cria um piso de 25 Foco
fora de combate. Após a graça de 3s, o decaimento chega a zero; reserva sem
cobertura é liberada sem gastar SP/iniciar CD. Em combate não há expiração
arbitrária. Teste de Foco atualizado para 340 checks. Procs também rejeitam
fonte alheia; pausa preserva a munição, Esc/cancelamento explícito libera.

## Evidências finais — 04/10/2026

- `tools/verify.ps1` completo, incluindo import, regressões das demais classes,
  smoke da cena e progressão administrativa: PASS, exit 0, sem erros de script.
- Sentinela: 3.298 checks headless PASS. Catálogo 749, matemática 72, Foco 340,
  Cabeça 126, Perfurante 219, Rede 167, Explosivo 166, Concussão 313, Absoluto
  228, builds/progressão/save 300, atlas 137, guia/UI 140, integração 341.
- Renderer real Godot 4.7.2/OpenGL: probe 286 checks, 30 capturas, zero falhas;
  atlas nativo 139 PASS e guia nativo PASS. Capturas inspecionadas em pisos
  claro/escuro, solo e cena controlada de 20 atores, nas duas builds legais.
- Capturas locais, não versionadas: `.godot/verification/sentinel_renderer/`,
  `sentinel_atlas_native.png` e `sentinel_onboarding_native.png`.
- Arte: `assets/art/animations/sentinel.png`; fonte original e prompt exato em
  `assets/art/animation_sources/sentinel_source.png` e `sentinel_prompts.md`.
  Preparador mecânico reproduzível: `tools/prepare_sentinel_atlas.gd`.
- Testes usam estado/fixtures isolados. Saves pessoais, diretório habitual,
  `codex/playtest` e `master` não foram alterados por esta entrega.

## Limites e roteiro de playtest

As provas nativas são capturas controladas; reposição de recursos/recargas serve
à leitura visual, não mede cadência sustentada, DPS ou FPS. Equilíbrio, sensação
dos resets e aceite estético continuam sujeitos à revisão e ao playtest humano.
O candidato não está publicado no diretório habitual antes da revisão integrada.

Após aprovação técnica: evoluir Arqueiro, conferir Cabeça grátis sem autoequip,
equipar 5+2 e formar Foco; experimentar as builds crítica/caster; preparar
Explosivo e usar resets sem consumi-lo; mover, pausar, cancelar e testar controle
em boss. Fora de combate, conferir decaimento e liberação da reserva insuficiente.

## Aceites

- Escopo e execução: autorizados em 03/10/2026.
- Revisão integrada Astra: código e apresentação aprovados com duas correções; detalhes em REVIEW_E05_SENTINEL.md. Publicação exige PASS integral do commit consolidado.
- Playtest humano e merge em master: pendentes.

