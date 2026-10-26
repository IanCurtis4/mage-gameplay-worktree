# Supervisão Luna — fundação de massa e relevo F9

## Identificação

- Checkout `.tools/map-editor-m5`, branch `codex/map-editor-f9`.
- SHA congelado e HEAD antes/depois: `270ff3ab78f3a6af299027bdd5ad8e69bd8beba5`.
- Godot 4.7.2 standard; SHA256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424`.
- Uma fixture compartilhada `.godot/verification/e07_f1/fixture_project`, usada em sequência. Sem cópia ou limpeza.

## Recibos autorais e proveniência

`relief_core_02/manifest.json` e `runs.json` identificam HEAD `50ba51ac03960e4eba3cc92729fd557c80290e5d`, não o SHA congelado atual. A execução autoral Core teve import e estágios candidate 53, document 70, terrain 102, composition 63, population 91, patrol 58, generation 89 e exchange 113, todos exit 0, sem timeout/aborto e `ok: true` (639 checks). Conferi os 1.885 inputs contra o checkout atual: a única divergência é `scripts/core/expedition/spatial/world_geometry.gd`, SHA do recibo `05FAE130BD8A5DE6DE85FC694155BB250D4AA8B8A2FBBD346F2DA695FF91BAD3`, SHA atual `83B24B32A452AAB7ED6956B6B369EBD846AA3857831B433D9166CCAF4E1B947C`. Esse é o ajuste posterior declarado: validar o segmento inteiro até o destino exato, em vez do ajuste curto. Documentação também mudou, fora do conjunto de inputs do manifesto.

`relief_precision_final_01/runs.json` registra Mesh 34/34 no HEAD `50ba51ac03960e4eba3cc92729fd557c80290e5d`, engine correspondente, exit 0 e sem timeout. `relief_f0_01/checks.jsonl` registra os checks F0 anteriores: geração 56, adversarial 149 e consumer 198, antes da mudança de `world_geometry.gd`. `relief_precision_relief_01` é diagnóstico sem instrumentação, portanto não foi tratado como runner oficial. Esses recibos históricos não são atribuídos ao SHA atual. As execuções Luna abaixo fornecem a reprodução das etapas dirigidas no SHA congelado.

## Execução Luna

Os quatro runners foram chamados em sequência com importação padrão e a mesma fixture. Cada `runs.json` registra o mesmo SHA antes/depois, engine acima, inputs fonte e cópia, exit 0, `ok: true`, sem timeout/aborto ou check falho:

| Etapa | Resultado |
| --- | ---: |
| Mesh | 34/34 |
| Relief | 56/56 |
| Geometry | 46/46 |
| Objects | 53/53 |

A seleção oficial foi listada antes da execução e confirmou 30/299 etapas: 3 F0 (`generation`, `adversarial`, `consumer`), 25 F1 (geometria, atores, inventário, adversarial, consumidores, canais, casts/áreas, classes, guard/travel, coleta, fields, Ice Wall, Geometer, composição, cena piloto e apresentação) e 2 snapshots (F3/F6). Executada com `-F1Fixture -SkipEditorImport -CheckTimeoutSeconds 300`, os 30 registros terminaram com exit 0, `failed=false`, `timed_out=false`; resumo `Selected checks passed (30/299 steps)`. `APPDATA` e `LOCALAPPDATA` apontaram para `.godot/discardable_profile` dentro da fixture durante a execução.

## Evidência, erros e hashes

Saídas, logs de engine e manifestos estão nos diretórios `mesh/`, `authorities/`, `geometry/`, `objects/` e `official/` sob esta pasta. SHA256:

- `mesh/runs.json`: `237718D54A19FBA2F619A503CDA69B3840EC5E30138BC3665902651F8A130E6F`.
- `authorities/runs.json`: `EF5BA874D7D0A1650D2D86E449D97CFBDEE9CDFD3F106D7B868E761909AA9472`.
- `geometry/runs.json`: `B81FEA62938E71D26BB08C09BB79991FD502CCECD2636B69AEFF8D07DD8BEC89`.
- `objects/runs.json`: `57903B7B01548E6F0A69A1DB91F12C0A406DF489B249B5281D477AE6B8EF5305`.
- `official/plan.json`: `1215654BF081C910B19B93525D7E486B02B1F36AE16EE2CD17AFCEF63214DE90`.
- `official/checks.jsonl`: `D289322476EBD3037DC315C923E50483569E02E8D64AA07D29737221462B9789`.

Confirmei novamente o SHA da engine após os runners. Não encontrei `SCRIPT ERROR`, `Parse Error` ou `ERROR:` nos logs. Não houve falha ou timeout. A fixture foi liberada após concluir a comparação de inputs e avisar Sol.

## Limites

Esta evidência cobre a fundação de massa/relevo, suporte em malha, autoridades de geometria, compatibilidade de objetos e a regressão oficial selecionada. Material, cliffs, biomas e renderização continuam abertos; export e a suíte F9 completa não foram executados. A supervisão confere execução, conclusão, saídas e hashes; não é auditoria semântica independente nem aprovação de F9 completo.
