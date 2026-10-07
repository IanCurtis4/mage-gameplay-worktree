# Sentinela solo e barras globais — contrato autorizado

07/10/2026. Autorização humana conferida no chat de Astra, turno
01a1172a-0d03-7ae0-9078-5f7041ba0913, incluindo resposta de passivas automáticas.
Base revisada f67fc412af20ce9cb8d263edaaf00f41f4267e6d; branch isolada
codex/sentinel-action-bars. Preservar correções de AoE letal e reservas nos menus.
Não alterar checkout habitual/playtest, master, saves pessoais ou iniciar classes.

## Precedência e comportamento

Este contrato substitui o limite global de cinco ativas e duas passivas dos
contratos anteriores. Todas as skills aprendidas e legais da identidade atual
estão disponíveis; todas as passivas aprendidas/legais operam automaticamente.
Pontos, gates, ranks, equipamentos, carteiras e orçamento permanecem iguais.
Barra organiza atalhos: arrastar não aprende nem concede rank, recurso ou poder.

Sentinela ganha intrinsecamente 4 Foco por ação de dano direto próprio aplicado,
enquanto viva/em combate, ICD compartilhado 0,5s. Autos/skills e dano letal valem;
miss, zero, DoT, secundário e fonte alheia não. Uma emissão/AoE paga uma vez, com
ledger limitado e determinístico. Observar/Leitura somam ganhos próprios; preservar
geração estacionária, cap100, reserva, decaimento, pausa e limpeza. Sem movespeed.

Barras: 24 slots, duas fileiras de 12. Padrão 1,2,3,4,R,F,Q,E,',V,5,T; segunda
fileira Alt+essas teclas. Binds globais por slot; limpar/restaurar e conflito
explícito, sem duplicidade. Modificadores exatos, repeat ignorado, captura sem
cast, key-up associado ao key-down mesmo soltando Alt primeiro. Rebind/drag
cancela intenção pendente. Digitar em campos não lança. Preservar três modos de
cast e clique. Geômetra conserva botões de elementos, sem sequestrar 1/2/3;
recompensa e reinício usam botões/atalhos auxiliares distintos documentados.

## Consumidores e migração

| Fronteira | Consumidores | Dono / invariantes |
|---|---|---|
| Foco | SentinelFocusState, PlayerActor, dano central | Sol / own-direct, ICD, AoE, letal, Hz |
| Aprendidas/passivas | BuildSnapshot, PlayerActor, RunState, main, calculador | Sol / identidade, gate, fonte única |
| Layout persistente | CharacterState, ProfileCodec, ProfileFacade, progressão | Sol / 24 IDs únicos ou vazios, roundtrip |
| Biblioteca/menu | CharacterMenu, treino/admin | integração / sem slots passivos, sem concessão |
| Barra/input | BattleControls, ControlPreferences, CastIntent, main | integração / combos, captura, release, UI |
| Regressões | bases/evoluções/híbridas, fixtures e verify | condutor / expectativas novas explícitas |

Layout por personagem, campo próprio opcional em saves legados, migração dos
slots ativos selecionados mantendo ordem e vazios. Arrays antigos dos presets
continuam preservados como dados legados, nunca autoridade de disponibilidade.
Passivas efetivas derivam de ranks/identidade legal, não do array antigo. Não
reembolsar ou conceder skills. Respec/class lock pruna referências inválidas.
Run copia build/pontos/stats; editar barra só muda organização, sem cura, refill,
recarga nova ou mutação de build. Fachada salva somente layout nessa operação.

## Pacotes e aceite

1. Reprodução solo + ganho intrínseco e invariantes 30/60/144 Hz.
2. Biblioteca/passivas automáticas + layout/migração/fachada e snapshots.
3. Barra/editor, binds globais, drag/drop, alternativa clicável e input integrado.
4. Regressões globais, renderer 1280×720 e menu, verify integral, checkpoint único.

Skills ragrpg-resume e ragrpg-class-delivery orientam esta execução. CLI externo
explicitamente autorizado: menu-tabs/RagRPG/tools/workflow/workflow.py; manter
--project no d066 e não importar manifesto antigo sobre testes novos.
Revisão integrada Astra após pacote inteiro. Aceite humano/merge separados;
nenhum PASS anterior aprova as novas regras ou o novo candidato.
