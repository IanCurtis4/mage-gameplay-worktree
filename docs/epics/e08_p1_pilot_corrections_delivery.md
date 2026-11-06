# E08 P1 — correções de atlas e UI encontradas no piloto

6/11/2026. Sol Apresentação, validação autoral. Entrega do
[contrato de correção](e08_p1_pilot_corrections_contract.md), com propriedade
sequencial registrada em [dispatch](e08_dispatch.md). Não encerra o piloto P3.

## Candidato, base e preservação

- Base efetiva: `b105dbc6884395edac9f7478b0afe200a4a0940d`.
- WIP Terra preservado, **INCOMPLETO/EM_CORREÇÃO**:
  `7f04830e01db0f49acefd47899c271b45b65adaf`.
- Implementação, testes e evidência: `3c405e9903ae930b719020b402afe65fc62caa22`.
- Branch `codex/e08`, checkout
  `C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
- Este recibo recebe commit documental posterior; não muda os inputs testados.
  SHA final: `git log -1 -- docs/epics/e08_p1_pilot_corrections_delivery.md`.
- Estado: ENTREGUE com validação autoral concluída; P0/Luna ainda consolidam o
  checkpoint. P1 devolve a posse após o commit do recibo e para de escrever.
  Correções futuras retornam ao mesmo chat. Nenhum master/push, habitual ou save
  pessoal foi modificado; nenhuma conversa criada ou arquivada.

Conferidos os 114 caminhos do WIP P3 fora dos arquivos transferidos: preservados
sem diff desde a base. `main.gd` recebeu apenas o ajuste de layout; o glue P3,
áudio/limiter P2mix, assets/fontes/WAVs/probe/recibo Terra, mapas e schemas não
foram editados. Quatro backups continuam untracked, com hashes de P0.
[inputs.json](e08_evidence/p1_pilot_corrections/inputs.json) fixa esses hashes.

A retomada explícita com ragrpg-resume confirmou raiz Git, project.godot, branch,
base e alterações locais. CLI Python de retomada e docs/WORKFLOW_TOOLING.md não
existem nesta base; não houve cópia de tooling nem execução de CLI adivinhado.
O diagnóstico Git e a autorização/contrato atuais permitiram continuar o mesmo P1.

## API de corpo por instância

Em [CharacterAnimation](../../scripts/actors/character_animation.gd):
`set_body_atlas(texture: Texture2D) -> bool`.

Precondições efetivas: animation configurada com **kind de inimigo fora de
WEAPONLESS_KINDS** e `_equipment_visual` vazio. Assim, todos os kinds de jogador
são recusados, mesmo antes de equipar algo; um inimigo com contrato de equipamento
também é recusado. O uso inicial esperado é animal_companion para lobo/javali.
Não há queda silenciosa para o weaponless antigo depois de aceitar a variante.

Aceita somente Texture2D de catálogo persistível com caminho `res://`, sem
sub-recurso `::`, disponível no ResourceLoader como Texture2D, tamanho256×512 e
imagem válida. Null, dimensão errada, textura transitória ou contrato de
jogador/equipamento retornam false antes de mudar qualquer campo. A textura
compartilhada não é modificada. Não houve novo enum, campo, cache, schema ou codec.

A aplicação atualiza somente `atlas`, `_base_atlas`, `_ground_offsets` e
`_base_ground_offsets`, já existentes. Recalcula contato pela última linha opaca
em cada uma das 32 células64×64, mantendo pivô(32,58). Conserva **a mesma instância
CombatAnimationState**, ação/tempos, facing, frente/costas, flip, caminhada, hurt e
death. `configure(kind)` continua sendo o reset explícito para o padrão e um novo
clock; não é chamado pela nova API.

`death_copy()` conserva corpo/offsets e cria seu estado terminal independente.
A orientação passou a ser copiada exatamente: o teste novo encontrou arredondamento
ao normalizar novamente um vetor já unitário. A correção copia facing/back_view/
flip_h existentes, sem relaxar o oráculo. Captura/restauração do grafo usa os
campos atuais e referências persistíveis; nenhuma migração.

Integração futura de Terra: chamar a API uma vez depois da configuração do ator,
fora do desenho, conferir o bool e solicitar `actor.queue_redraw()` se precisar de
redesenho imediato. O draw_key existente já inclui o atlas. Não acessar campos
privados durante draw, nem trocar recursos compartilhados. P1 testou os PNGs já
existentes animal_companion e gel; **não criou arte**. Atlas próprios de lobo e
javali e sua ligação por ocorrência continuam com Terra após novo handoff P0.

## UI120% e interação

- ExpeditionStatusPanel agora possui ContentScroll com conteúdo completo, quebra
  de texto e follow_focus. Limita o retângulo à área entre HUD/Admin e rodapé; a
  rolagem permite chegar a portais, objetivo e suspensão sem esconder botões.
- O painel é colocado abaixo dos modais e seus escudos de input. Mantém
  mouse_filter STOP; HUD/ajuda informativos continuam IGNORE. A roda dentro do
  painel rola conteúdo sem mudar o zoom do mundo.
- Rodapé usa largura disponível e a altura mínima real do VBox/HFlow; fica acima
  da barra com folga12. Status longo pode quebrar linha. Não se removeu controle,
  fonte ou conteúdo, nem reduziu preferência ou escala efetiva.
- Ajuda tem retângulo limitado ao viewport mesmo quando a regra contextual antiga
  a mantém oculta. Corrigida a falha antiga help1280 do ui_layout_test sem alterar
  esse teste. Não se mudou sua regra de contexto para fingir encaixe.
- Assinaturas de resize são instaladas na criação do painel e desconectadas pela
  liberação do receptor. Três tamanhos/ciclos e reconstrução do painel descartável
  mantiveram dois handlers do root, sem acumulação.

GuiMetrics e BattleControls foram inspecionados, mas não precisaram de edição:
escala/resize e rolagem do modal existentes passaram na integração. O callback de
layout de main considera minimum_size_changed do rodapé; glue P3 preservado.
Nenhuma mudança de viewport/câmera no runtime, progresso, portal, pausa ou save.

## Prova nativa preenchida

Cena real publicada **Floresta do Santuário**, seed42, estágio Prado dos Terraços,
perfil descartável. HUD atualizado explicitamente antes de pausar: VIDA150/150,
SP85/85 e resumo real de campanha. Câmera100%, UI120%, font/theme normais. Ações
reais estão presentes; slots vazios correspondem ao personagem novo da fixture.
Não são o defeito antigo de HUD sem atualização do probe pausado.

Capturas nativas inspecionadas, sem montagem/edição:

| Janela | Contexto/HUD | Ações alcançáveis | Modal/áudio/fechar |
|---|---|---|---|
| 1280×720 | [Topo](e08_evidence/p1_pilot_corrections/native/forest_1280_top_120.png) | [Rolagem](e08_evidence/p1_pilot_corrections/native/forest_1280_actions_120.png) | [Controles](e08_evidence/p1_pilot_corrections/native/forest_1280_settings_120.png) |
| 1920×1080 | [Topo](e08_evidence/p1_pilot_corrections/native/forest_1920_top_120.png) | [Rolagem](e08_evidence/p1_pilot_corrections/native/forest_1920_actions_120.png) | [Controles](e08_evidence/p1_pilot_corrections/native/forest_1920_settings_120.png) |

A janela1920 preserva o stretch canvas_items1280×720 do projeto. O registro usa
coordenadas lógicas antes desse stretch, sem mudar a preferência120%: painel
(28,8;264)468×165,6, rodapé começa em444 e barra em549,6. Há separação real em
ambas as capturas; o painel recorta sua própria área rolável. O último botão de
suspensão fica inteiramente alcançável no fim da rolagem.

Teste nativo **61/61 PASS**, exit0, zero erros/timeouts, timeout300s; OpenGL3.3
Compatibility, GTX1080, driverNVIDIA582.66. Usou eventos de mouse/roda e Escape
pela rota real de input, foco de cada botão, abertura/fechamento do modal e resize
1280→1920→1280. Não executou portais/suspensão apenas para provar acesso, nem
mudou sua elegibilidade. [native_ui.json](e08_evidence/p1_pilot_corrections/native/native_ui.json)
registra HUD, estágio, retângulos, escala, scroll e handlers.

## Testes e inputs congelados

Engine pareado autorizado do principal:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe`,
versão `4.7.2.stable.official.ed1daf0bf`, SHA256
`ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`.
Uma fixture existente: `.godot/verification/e07_f1/fixture_project`.
Sincronização somente por deltas e manifesto; o runner confrontou **2.301 fontes**
nos dois lados. APPDATA isolado em `fixture_project/.godot/e08_user`.

Importação inicial passou com apenas o aviso conhecido de projeto aninhado
ignorado. Rodada final `.godot/verification/e08_p1_corrections_final`, timeout300:
**9/9 selecionados PASS**, exit0 em todos, zero SCRIPT ERROR/ERROR/timeouts.
Não aprova as outras etapas das 311 disponíveis.

| Teste | Checks | Resultado |
|---|---:|---|
| combat_animation_test | 39 | PASS |
| e08_presentation_test | 2.204 | PASS |
| e08_pilot_ui_test | 55 headless | PASS |
| e08_audio_test | 132 | PASS |
| battle_ui_test | 47 | PASS |
| ui_layout_test | 30 | PASS |
| action_bar_ui_test | 80 | PASS |
| e07_f7_presentation_test | 27 | PASS |
| e07_f3_lifecycle_test | 90 | PASS |

Os 2.122 checks anteriores de e08_presentation foram preservados, inclusive setup;
acrescentados 82 para corpo/estado, inválidos, independência, 32 contatos, cópia,
morte/revive, recusa de equipamento e captura/restauração de variante. O teste
novo de UI inclui fluxo real de floresta, retângulos, input e reconstrução do
painel; os seis saves PNG acrescentam seis checks na variante nativa. Não somar
repetições de desenvolvimento como cobertura independente.

[inputs.json](e08_evidence/p1_pilot_corrections/inputs.json) fixa fontes executadas,
atlas existentes usados, engine, manifesto/config, WIP preservado e backups.
[raw_evidence.zip](e08_evidence/p1_pilot_corrections/raw_evidence.zip) conserva 29
membros brutos: planos/checks/outputs das tentativas, nativo e manifesto/config.
SHA256 `ea340a5c8e8dd70b585f65a7048b2a5c710075c0296a0b39af46b9db012feba0`.
[hashes.json](e08_evidence/p1_pilot_corrections/hashes.json) identifica membros e
seis PNGs. ZIP binário impede normalização CRLF pelo Git; JSON externo possui
cópia bruta no ZIP e/ou hash normalizado LF. Evidência total cerca de7,48MB.

### Falhas corrigidas e limites da prova

- Primeira rodada acusou uma falha do novo oráculo de cópia de orientação:
  normalização repetida alterava componentes. Corrigido death_copy, expectativa
  preservada; os 2.204 checks passaram depois.
- A primeira montagem do teste de UI enviava Escape a _unhandled_input, enquanto
  a rota de fechar modal está em _input. Corrigido o estímulo para push_input real;
  não se mudou o comportamento esperado. A montagem inicial gerou cinco falhas
  em cascata porque o modal ficava aberto; log preservado.
- Primeira invocação PowerShell do exe gráfico/attach não expôs ExitCode. A prova
  foi repetida usando ProcessStartInfo, captura stdout/stderr e espera com timeout;
  o registro nativo definitivo inclui exit0 e61checks. Não se tomou ausência de
  exit code como aprovação.
- Prova é de layout/interação e persistência da variante. Não certifica arte nova,
  desempenho mediana/p95/memória, áudio subjetivo, export/PCK ou aceite de produto.
  As capturas pausadas não demonstram uma suspensão persistida inteira em vídeo.
  A reconstrução do painel tem teste próprio; lifecycle90 cobre install/ativação
  existentes. O snapshot novo de atlas cobre captura e restore do grafo.

## Reprodução e handback

PowerShell7, a partir do checkout acima, sem novo projeto/fixture/export:

```powershell
$env:APPDATA = Join-Path $PWD '.godot/verification/e07_f1/fixture_project/.godot/e08_user'
$engine = 'C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/godot/Godot_v4.7.2-stable_win64.exe'
$tests = @('combat_animation_test','e08_presentation_test','e08_pilot_ui_test',
  'ui_layout_test','battle_ui_test','action_bar_ui_test','e08_audio_test',
  'e07_f7_presentation_test','e07_f3_lifecycle_test')
./tools/verify.ps1 -F1Fixture -GodotPath $engine -Test $tests -CheckTimeoutSeconds 300 -VerificationDirectory (Join-Path $PWD '.godot/verification/e08_p1_corrections_luna')
```

Para nativo, executar o MESMO `tests/e08_pilot_ui_test.gd`, sem --headless, usando
--path da fixture e o argumento após `--`:
`--capture-dir=<pasta absoluta nova de evidência>`. A lista exata de argumentos,
exit/timeout/hash está em `native/process.json` dentro do ZIP. Aguardar o processo
pela API ProcessStartInfo/Process, como verify, evitando a invocação assíncrona de
exe gráfico do PowerShell. Native usa viewport real e Compatibility do projeto.
Não reutilizar perfis pessoais. Confrontar inputs e manifesto antes de Luna.

Arquivos alterados: character_animation.gd; main.gd somente layout;
ui/expedition/expedition_status_panel.gd; teste e08_presentation (somente adição);
novo e08_pilot_ui_test.gd/.uid; verify (somente registro novo, P2/P3 preservados);
este recibo e e08_evidence/p1_pilot_corrections. Nenhum arquivo adicional solicitado.
`git diff --check` passou; linhas não ASCII preexistentes de runtime/runner foram
confrontadas e preservadas. Nenhum oráculo antigo foi editado.

Cinco perfis descartáveis próprios e08_p1_pilot_ui foram removidos após validação,
com caminhos absolutos conferidos dentro da fixture:2.938.808B. A fixture/cache
existentes e dois checkouts foram mantidos para supervisão, sem limpeza cega.
O commit do recibo devolve posse a P0, para supervisão Luna/consolidação e depois
retorno explícito ao **mesmo Terra P3** com API e caminhos autorizados de arte.
P3 segue incompleto; P4–P7 permanecem fechados. P1 para de escrever nesse ponto.
