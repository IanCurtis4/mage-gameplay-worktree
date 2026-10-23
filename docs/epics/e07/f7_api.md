# E07-F7 — APIs e apresentação

23/10/2026. Implementação em validação. Base, propriedade e adendos humanos:
[checkpoint](f7_checkpoint.md), [despacho](f7_dispatch.md).

## Consumidores de UI

`PhaseSelectionPanel` usa o personagem focado no lobby. Oferece a fase inicial
aberta nível1, sem custo/chave. Monta e valida a receita pelo assembler antes
iniciar a sessão canônica. O modo expedition_entry_mode impede criar o piloto.
ExpeditionService.enter confirma a montagem; só então ExpeditionSceneFlow instala
ativa e publica a nova cena. Uma reserva existente usa resume, sem gerar seed
nova, criar build ou conceder entrada. Falha preserva a cena e expõe recuperação;
reconciliação retém a instância e request da transação incerta.

`AssetMigrationPanel` pede a prévia pública, mostra exemplares/destinos e todas
as remoções de referências. Sugestões nunca preenchem assignments. Cartas
encaixadas acompanham o host escolhido pela autoridade; cartas livres exigem
destino. Alterar uma escolha reconstrói a prévia e limpa a confirmação. O resumo
mostra o digest completo. Confirmar exige mapa completo e aceite explícito,
chamando somente apply_asset_migration; nunca converte ao abrir a tela.
Atualizar prévia permite revisar alterações de fonte antes de nova confirmação.

`ExpeditionStatusPanel` consome state.view/portal_view/ThreatView e os tickets
copiados. Oferece viagem, coleta, revive, conclusão/refúgio e suspensão; o
serviço revalida proximidade, combate, limpeza e revisão. As transações usam
barreira de fim de tick; falha incerta mantém host congelado e o mesmo serviço
para reconcile. Falha conhecida de elegibilidade devolve o mundo inalterado.
Sair ao lobby confirma suspensão; não usa end_run(abandoned) para expedições.

`ExpeditionPresentation` traduz os DTOs em pt-BR sem calcular ameaça, limiar,
recompensas ou elegibilidade. ExpeditionGeometryView apresenta portais e marcos
objetivos a partir do manifesto. ExpeditionPortal reaproveita um Label na
atualização. UI é descartável/reconstruída no install, fora do grafo persistente;
nenhum campo persistente no RunController ou runtime kind foi acrescentado.

## Consultas mínimas autorizadas nominalmente pelo usuário

MigrationPlan.dry_run acrescenta ao plan:

- characters: Array de {character_id, display_name}, incluindo alts sem referências;
- assets: Array de {instance_id, kind, definition_id, host_id, metadata}.

São projeções copiadas do candidato legado validado. Integram o digest e sua
reconstrução por validate. Alterar nome/metadado na prévia invalida confirmação.
Não expõem writer nem tornam o perfil legado gravável. A lacuna foi reproduzida
em boundary_01 (exit2 diagnóstico); o teste F7 posterior verifica a correção,
o mapa explícito, remoções, digest e arquivo ownership com bytes exatos.

RunRewardService.next_pending_ticket() retorna ticket(_queue[0]) ou {}.
A fila permanece privada; ticket retorna cópia profunda. Não emite, rerrola,
coleta, reordena ou confirma recompensas. Coleta permanece ExpeditionService.collect.

## Amostra autorada — Travessia das Ruínas

Receita em data/expedition/phases/ruined_crossing.gd, revisão1. Não importa
fixtures de teste nem cria um segundo gerador. Constrói Resources imutáveis
para ExpeditionAssembler; o manifesto completo é guardado pela autoridade.
Quatro estágios: Entrada → Caminho principal → Destino final, e ramo lateral
opcional com retorno explícito. Cada estágio conecta pátio, rampa, patamar e
uma de duas partes de ponte; a ponte passa sobre o pátio e tem laje sólida.
Perfil de travessia20/32, aberturas120/128; geometria comum valida corpos reais.

| Origem | População inicial | EXP Base/Job por exemplar |
|---|---|---|
| entry / trial_stage_1 | Mateiro normal + Guardião raro no santuário superior | 10 / 8 |
| left / trial_stage_2 | Atirador Preciso normal | 20 / 16 |
| right / trial_stage_3 | Vigia Invernal normal | 30 / 24 |
| final / trial_stage_4 | Guardião do Baluarte elite raro | 40 / 32 |

Cinco slots de amostra pequena; não é densidade universal nem expansão de
catálogo. Somente normais explicitamente trash admitem reposição. Raros/memoráveis
são únicos. EXP, loot e mácula usam F5, sem fórmula paralela. Bônus final permanece
100gold/300Base/200Job, sem item garantido. Refúgio lateral suspende sem bônus.
Escala, dificuldade e avaliação visual final continuam dependentes do playtest.

## Verificação

Testes F7: presentation (DTO/texto sem mutação), migration_boundary (projeção e
confirmação reais), authoring (seeds42–45, testemunhas, planner e imutabilidade),
flow (entrada/câmera/locks/suspensão/retomada/install/activate com confirmação perdida)
e actions (eventos de morte, tickets copiados, coleta, viagem/retorno e revive
pelas intenções reais da UI, sem teleporte ou concessão alternativa).
Capturas opcionais nativas em flow/migration com --capture-f7; --seed-43 escolhe
segunda seed no fluxo. Saves ficam em .godot/verification, nunca user://.
Regressões por impacto e evidência consolidada constarão do recibo final.
