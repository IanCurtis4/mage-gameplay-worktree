# E07-F1 — altura funcional e combate espacial

18/10/2026. Autorização: “F0 acabou. Pode começar F1.” Executor temporário
**gpt-6.1-sol / high**; Luna em supervisão de testes, sem chat de reserva.
[F0 integrado](f0_integration.md), [contrato E07](../e07_contract.md),
[decisões D05](e07_decisions.md), [guia espacial](guides/world_geometry.md).

## Base, estado e dependências

Base integrada de runtime: `42604ef8674a2c28f5aadc633b73cda15178e0b3`.
Checkout exclusivo: `C:/Users/João Pedro/.codex/worktrees/content-delivery-docs/RagRPG`.
Branch: `codex/e07-f1`, limpa antes de receber o commit documental deste despacho.
O SHA completo desse commit documental será resolvido no prompt e índice antes
iniciar o chat; ele é a base executável, sem inventar SHA futuro neste arquivo.
Projeto habitual permanece em codex/playtest; não trabalhar ali, importar nele,
trocar sua branch, tocar seus sidecars/export ou save pessoal.

D05 combate aprovado expressamente em18/10: ataques de chão propagam pela
superfície/conexões dentro do alcance; lajes sólidas bloqueiam ataques entre
andares; dash segue caminhos transitáveis; teleporte conserva a passagem por
obstáculos planos, exige destino legal/alcance 3D e não atravessa lajes sólidas.
Altura participa do alcance na mesma unidade, sem bônus de high ground.

**Apresentação D05 ainda aguardando resposta:** proposta de preservar sprites e
câmera atuais em prova 2,5D, clique na superfície visível/marcador e rejeição de
ambiguidade. A lógica espacial aprovada e seus testes podem iniciar. Não implementar
renderer/projeção/clique multialtura nem declarar F1 concluída antes dessa resposta.
Registrar o aceite ou ajuste no próprio recibo/dispatch, sem reabrir regras já
aprovadas. D01–D04/D06/D07 continuam pendentes e não são defaults de produção.

## Resultado, sequência e exclusões

Entregar WorldGeometry compartilhada por navegação, AI, seleção, preview e
combate: caminhos reais por rampa; ponte com passagem inferior; superfícies
sobrepostas distintas; oclusão e alcance em alturas coerentes. Consumir manifesto
real/API F0, não construir um segundo mapa desconectado. Adaptador plano mantém
E06. Dados fixture explícitos não são a campanha D07 nem tuning de produção.

1. Inventariar interações espaciais das dez identidades e exceções atuais,
   mapear cada ativa/efeito a geometry_rule_id; regras de chão versus aéreas
   explícitas. Só classificação que preserve comportamento atual ou regra humana
   aprovada é automática; mudança nova de habilidade volta ao usuário.
2. Implementar lógica WorldGeometry, adaptador plano, erros e invariantes;
   integrar posição/superfície dos atores e efeitos, sem usar pixels projetados
   como distância de gameplay. Não alterar fórmulas de dano/atributos.
3. Após resposta visual D05, integrar renderer/input e amostra técnica pequena
   de estágio, com inspeção nativa. Não habilitar expedição de produção/lobby.
4. Consolidar validação Sol, supervisão Luna e recibo com limitações reais.

Não implementar F2+, persistência/migração/wallet, respawn/revive, ameaça nova,
quests/campanha/lojas/consumíveis, novas classes, multiplayer ou assets low-poly.
Não simular congelamento, completar D07 implicitamente ou prometer escala/FPS.
Amostra usa save fixture isolado e não concede bens ao perfil pessoal.

## Propriedade exclusiva

Coordenação transfere `tools/verify.ps1` de F0 para F1. Nenhum escritor paralelo
nestes arquivos. Edições somente por necessidade espacial; não refatorar arte,
inventário, balanceamento ou funções não relacionadas porque o arquivo consta.
Existentes permitidos (respectivos .uid acompanham o script quando necessário):

- `scripts/core/arena_navigation.gd`
- `scripts/core/skill_geometry.gd`
- `scripts/core/battle_targeting.gd`
- `scripts/main.gd`
- `scenes/main.tscn`
- `tools/verify.ps1`
- `scripts/actors/arrow_projectile.gd`
- `scripts/actors/character_animation.gd`
- `scripts/actors/combat_actor.gd`
- `scripts/actors/enemy_actor.gd`
- `scripts/actors/equipment_attachment_visual.gd`
- `scripts/actors/equipment_hand_rig.gd`
- `scripts/actors/equipment_head_visual.gd`
- `scripts/actors/geometer_trace_projectile.gd`
- `scripts/actors/mage_projectile.gd`
- `scripts/actors/player_actor.gd`
- `scripts/actors/player_projectile.gd`
- `scripts/actors/sentinel_area_projectile.gd`
- `scripts/actors/sentinel_projectile.gd`
- `scripts/world/actor_death_visual.gd`
- `scripts/world/arena_obstacle_view.gd`
- `scripts/world/arena_view.gd`
- `scripts/world/arrow_rain.gd`
- `scripts/world/battle_indicators.gd`
- `scripts/world/elementalist_sequence.gd`
- `scripts/world/explosive_trap.gd`
- `scripts/world/fire_wall.gd`
- `scripts/world/foliage_shelter.gd`
- `scripts/world/geometer_casting.gd`
- `scripts/world/geometer_triangle_field.gd`
- `scripts/world/geometer_wall_field.gd`
- `scripts/world/haunt_cone_visual.gd`
- `scripts/world/hunter_presentation.gd`
- `scripts/world/hunter_tar_field.gd`
- `scripts/world/hunter_trap.gd`
- `scripts/world/ice_wall.gd`
- `scripts/world/lightning_wall.gd`
- `scripts/world/mob_prototype_visual.gd`
- `scripts/world/phantom_barrier.gd`
- `scripts/world/player_trap.gd`
- `scripts/world/player_trap_registry.gd`
- `scripts/world/reward_pickup.gd`
- `scripts/world/sentinel_burst.gd`
- `scripts/world/snare_trap.gd`
- `scripts/world/soul_impact_sequence.gd`
- `scripts/world/spiritualist_drain_state.gd`
- `scripts/world/spiritualist_echo_state.gd`
- `scripts/world/spiritualist_halo_underlay.gd`
- `scripts/world/spiritualist_procession_state.gd`
- `scripts/world/spiritualist_veil_state.gd`

Novos diretórios/caminhos exclusivos:

- `scripts/core/expedition/spatial/*.gd` e respectivos `.uid`;
- `scripts/world/expedition_geometry_view.gd` e seu `.uid`;
- `tests/e07_f1_*.gd` e respectivos `.uid`;
- `tests/fixtures/e07/f1/**`, incluindo cenas/probes da amostra técnica;
- `docs/epics/e07/f1_api.md`, `docs/epics/e07/f1_skill_geometry_matrix.md`
  e `docs/epics/e07/delivery/f1.md`.

Fontes F0 são API de leitura. Se uma limitação impedir ponte/manifesto válido,
registrar diagnóstico e alteração aditiva necessária antes de pedir transferência;
não falsificar o manifesto ou relaxar seu validador. Fontes/fixtures/testes F0,
catálogos, schemas, fórmulas e UI fora da lista não são propriedade F1. Arquivos
fora da lista exigem transferência registrada antes de editar. Contratos Astra
e índices globais são da coordenação/arquitetura; não commitar alterações deles
por inferência. Testes antigos são leitura/execução; novos testes F1 cobrem novos
contratos sem alterar expectativas antigas para esconder regressões.

## APIs e critérios

Entregar signatures concretas, DTOs copiados, unidades, geometry_revision e erros
para `path`, `sweep`, `query_attack`, `resolve_surface`, obstáculos temporários
com revisão e consultas de posição/ocupação. Prever consumo posterior das queries
de spawn/chegada do guia sem implementar ciclo de expedição. Falha espacial não
cobra recurso/cooldown nem comita cast; revalidar revisão/LoS/alvo no commit.

I03–I05/I15: suporte contínuo em rampa, raio/altura livre, ponte sobre chão,
clique/preview na mesma superfície do commit, parede no piso inferior sem bloquear
automaticamente o superior, oclusão por laje, alcance vertical, sweep contínuo de
projétil, AoE de chão e volume aéreo, cones/linhas, dash/push/teleporte, AI/leash e
suportes. Revisão de obstáculos invalida rota velha; destino inválido/oculto/
ambíguo falha sem teleporte reparador. Teto visual oculto conserva colisão.

Cobrir dez identidades habilitadas e efeitos de itens/augments que alcançam essas
fronteiras. Provar com consumidor real, não só mocks de geometria. Nenhum fallback
2D silencioso em multialtura para kit difícil; sem alegar suporte completo com
apenas um ataque básico. Registre casos ainda sem adaptação como bloqueios.

## Validação por impacto

Godot 4.7.2 standard em
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/review-engine/Godot.exe`.
Conferir versão/hash e `tools/verify.ps1 -List`. Novos testes F1 e regressões
necessárias registradas no mesmo runner, sem filtros que ocultem erro.
Seleção inicial a justificar/concretizar pelo diff (IDs existentes conferidos):

- `arena_flow_test`
- `battle_ui_test`
- `e04_dash_rank_integration_test`
- `e04_teleport_rank_integration_test`
- `e04_archer_precision_projectile_test`
- `e04_archer_trap_runtime_test`
- `e04_mage_integrated_closure_test`
- `e04_archer_integrated_closure_test`
- `e05_elementalist_integrated_closure_test`
- `e05_spiritualist_integrated_closure_test`
- `e05_sentinel_integration_test`
- `e05_hunter_core_integration_test`
- `e05_hunter_cover_integration_test`
- `e05_hunter_traps_integration_test`
- `e05_geometer_geometry_integration_test`
- `e05_geometer_wall_projectile_test`
- `e05_geometer_triangle_projectile_test`
- `e06_spatial_policies_test`
- `e06_spatial_execution_test`
- `e06_tx_causality_test`
- `e06_effects_runtime_test`
- `e06_gameplay_ai_test`
- `e06_rx_mob_ai_test`
- `verification_profile_isolation_test`

Acrescentar testes dos demais kits afetados conforme inventário, inclusive Berserker
/Defendente; só ampliar para suíte completa se a fronteira compartilhada justificar.
Reexecutar F0 se tocar seus consumidores/inputs de modo relevante. Não somar rodadas
repetidas como cobertura. Luna supervisiona o lote final via subagente delimitado,
leitura/execução/erros/hashes; Sol corrige e valida invariantes. Sem auditoria Astra
rotineira. Se subagente indisponível, registrar, não inventar supervisão.

F0 encontrou GitPlugin configurado e indisponível no import completo. Seu fixture
sem plugin certifica apenas F0 puro. F1 deve diagnosticar e resolver o ambiente
nativo da sua worktree: primeiro usar mecanismo oficial de inicialização que não
ative o plugin. Ajuste local apenas da configuração de autoload VCS pode ser
preparado em cópia fixture/execução isolada, com delta declarado; não editar o
project.godot versionado ou instalar plugin sem transferência específica. Não
copiar esse desvio para o checkout habitual e não ocultar erros. Provar scripts,
cenas e assets de gameplay reais; registrar separadamente import nativo, smoke,
prova visual e diferenças do ambiente. Se isso impedir prova real, reportar
limitação/bloqueio concreto em vez de declarar renderer aprovado por teste puro.

Usar fixtures de perfil explícitas e isolamento verificado. Capturas visuais
nativas devem mostrar rampa, ponte/caminho inferior, marcador e ataques bloqueados;
registrar seed, inputs, engine, logs e hashes, sem substituir inspeção por exit0.
Preservar `.godot/verification/e07_f0` e arquivo de evidências da coordenação.
Logs de F1 em diretório próprio; .godot/.tools/builds não entram em Git.

## Entrega

Committar somente arquivos próprios em codex/e07-f1. Entregar hash completo,
API/matriz reais, inputs/testes/logs/capturas, papel de Luna/Sol, limitações e
roteiro de reprodução. Não avançar playtest, merge master, push, autoarquivar ou
criar chats de F2+. Coordenação integra e arquiva após validação. Decisão visual
pendente ou lacuna de kit mantém F1 aberta; correções reutilizam este chat.
