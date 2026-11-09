# P7 — Integração: consolidação, medições, release e playtest

Autorização humana em 9/11/2026, após ouvir a prévia P6 ("ficaram boas"): **sons
P6 aceitos** e P7 iniciado. Base `45b930ba` (P5+P6), branch `codex/e08`, checkout
`.tools/map-editor-m5`. [Plano](e08_approved_plan.md), [posse](e08_p7_files.json).
Avaliação visual dos efeitos P6 em jogo acontece no candidato desta fase.
Sem master/push; merge só com aceite explícito do candidato testado.

## Pacotes (sequenciais)

**C1 Terra/Sonnet — acabamento P6 dentro do contrato.** Pontos fracos registrados
pela A2: onda de choque (grito, onda de represália) pálida em chão claro; espinhos
discretos; faíscas de impacto físico finas; setas de investida pequenas em zoom 50;
flipbooks 1,4–1,7× mais rápidos que o `suggested_fps` do B1. Ajustar só parâmetros/
desenho da camada de apresentação, sem tocar regras, eventos ou catálogos de áudio.
Capturas antes/depois no renderer real.

**C2 Luna/Haiku — suíte completa.** `tools/verify.ps1` inteiro (todas as etapas) pela
fixture/wrapper, mais as sondas de mapa de P5/P6. Falhas voltam ao autor (Sol/Terra);
nenhuma expectativa editada para ocultar falha.

**C3 Sol/Opus — medições, release e candidato.**
- Medições frio/quente no mesmo hardware e roteiro: mediana/p95/picos de quadro e
  memória, comparando os controles F10 de atores e floresta com E08 (P4–P6 ligados).
  Regressões reproduzíveis de E08 são corrigidas ou registradas com causa.
- Release Windows/PCK com assets e sons, engine standard verificada, template
  conferido, proveniência e manifesto de assets; exportação de release do editor de
  mapas (`map_editor_candidate -Stage Release`) repetida.
- Candidato isolado em `.tools/playtest_e08/e08_<hash>` (padrão do piloto P3 e da
  preparação P4): EXE+PCK pareados, nome de aplicativo próprio, APPDATA isolado,
  perfis de revisão por grupo de classes com
  `tools/prepare_e08_p4_review_profile.gd` (preparado anteriormente, integrado aqui),
  roteiro de revisão atualizado para P4–P6 e LEIA-ME. Nunca copiar save pessoal.
  O checkout habitual `codex/playtest` não é alterado nesta fase; aplicá-lo é passo
  separado, com confirmação do usuário.

## Fora de escopo, registrado

Testes nativos de UI do editor de mapas exigem fixture espelho completa; o erro
`_preparation_metrics_mutex` nulo em compilação no editor vem da F10 (2ff1c00f) e
é do editor de mapas, não do runtime E08. Ordem `melee_swing` × `impact` do mesmo
golpe e a dica de commit por quadro (A1) ficam como limitações documentadas.

## Aceite

Aprovação técnica (Sol + Luna) não é aceite de produto. O usuário testa o candidato
e decide merge em `master`. Sem push automático.

## Fechamento P7 — 9/11

Duas rodadas de playtest do usuário corrigidas: C5 (rota de movimento removida; ataque
básico sem rajada de disparo, hit branco no alvo, sons originais de hit seco/corda do
arco com perfil medido de referência), C6 (encaixe de peças de cabeça por classe e
quadro), C7 (linha de mira que ficava no chão removida; hit branco para o ataque básico
das 10 classes, inimigos e golpes físicos comuns). Efeitos P6/P7 **aceitos
provisoriamente** pelo usuário, sujeitos ao teste de um amigo.

**Candidato final P7:** `6b42b305` em `.tools/playtest_e08/e08_6b42b305`
(PCK 6529da02…191c). Inspeção 22/22, floresta 19/19, perfis/atalhos por grupo, smoke ok.
Floresta parada contra F10: +5% a +12% na mediana conforme a sessão (resíduo de conteúdo
P4/P5, não das camadas C4/C7). [Release](e08_p7_release.md),
[medições](e08_p7_measurements.md), [triagem da suíte](e08_p7_triage.md).

Pendências que ficam registradas: grinalda do Elementalista e chapéu do Caçador pedem
arte nova (briefing Codex em [head fit](e08_p7_head_fit_delivery.md)); prévia de mira
válida deixou de existir junto com a linha; cena de 96 atores parados +12%; pico de
~38 ms no primeiro flipbook. Atualização do checkout habitual e merge em `master`
dependem de aceite explícito do usuário; sem push.
