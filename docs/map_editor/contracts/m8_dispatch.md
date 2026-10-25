# Editor F8 / M8 — integração e autoria dual, revisão 1

25/10/2026. EM_EXECUÇÃO. Autorização humana: “F7 acabou, podemos começar F8”,
incluindo implementação de UX/AX e revisão das lacunas da autoria dual.
Base completa `7af993f955a503e42fcffc9abebb158aa591d27b`; F0–F7 por ancestralidade.
Branch `codex/map-editor-m8`; único worktree reutilizado:
`C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5`.
Principal `codex/playtest` em `fba777b3822356a10e7f6e050971e54ab1a9819b`, com
alterações locais preexistentes, permanece preservado. Não existe CLI de workflow
nem WORKFLOW_TOOLING nesta base; diagnóstico por Git/recibos, sem tooling externo.

## Decisões humanas e resultado

- Mesma peça nos fluxos manual e por seed; vários biomas por peça.
- Conexões nas bordas e áreas internas de encontro.
- Elegibilidade de espécies, raros opcionais e encontro reservado já neste F8.
  Quest é referência passiva; não cria engine, grants ou progressão de quest.
- Exceção manual explícita por instância, motivo e aviso preservados no export.
- UX agrupada por tarefa, dropdowns e redução de ruído; AX expõe ações diretas
  com identidade estável e operações de inspeção/teste pela mesma autoridade.
  Alternar apresentação não altera documento, hash, histórico ou validação.
- Área representativa, export release, evidências, limites e roteiro humano.

## Propriedade exclusiva e transferências sequenciais

Sol deste chat recebe dos produtores encerrados os arquivos abaixo (e seus .uid
existentes). Não há escritor paralelo de UI/schema/compiler. Novos arquivos são
posse exclusiva Sol até congelamento para supervisão Luna.

- `addons/ragrpg_map_editor/{shell,presentation,plugin,export_plugin}.gd` e .uid.
- `scripts/map_authoring/terrain/terrain_panel.gd`;
  `composition/{map_panel,map_document,map_compiler}.gd`;
  `document/source_schema.gd`; `population/{population_panel,population_compiler}.gd`;
  `patrol/patrol_panel.gd`; `generation/{generation_panel,generation_solver,assembler_adapter}.gd`.
- `scripts/map_authoring/context/{piece_context,context_panel,map_context_panel}.gd` e .uid.
- `tests/map_editor_candidate{,_ui}_test.gd` e .uid;
  `tools/map_editor_candidate/run.ps1`; amostras mínimas em `data/map_authoring/`.
- `scripts/map_authoring/compiler/terrain_compiler.gd`: preflight da fonte para
  chaves StringName textuais sem relaxar finitos/profundidade/geometria;
  `context/population_context.gd` e .uid; `terrain/terrain_canvas.gd` para áreas.
  `data/map_authoring/candidate_preview.{gd,tscn}` e .uid: consumidor descartável.
- `docs/map_editor/{README,validation,authoring_modes}.md`, este contrato,
  `delivery/m8.md`, `delivery/evidence/m8/author/` e .gitattributes local.
- `export_presets.cfg` apenas se necessário para export release da fixture.
  Demais autoridades de gameplay/verify.ps1/project.godot somente leitura.

Luna, autorizada pelo usuário em gpt-6-luna/xhigh, recebe somente relatórios/logs
em `delivery/evidence/m8/luna/`, comandos e SHA congelados. Mesma fixture de teste
sequencial; não escreve runtime, testes, expectativas ou dados de autoria.

## Contrato incremental e provas

Extensão opcional versionada de contexto preserva fontes v1 antigas sem reescrever
seus hashes. Fonte nova, GUI, CLI, solver e compilação compartilham validação.
Exceções jamais dispensam suporte, corpo, emenda, navegação ou catálogo canônico.
Geração por seed não herda exceções manuais. Encontro reservado não participa do
sorteio comum. Esclarecimento humano nesta rodada: ambientação de raros é diretriz
editorial de imersão, não gate inexorável. Raro manual pode existir sem palco;
raros gerados seguem elegibilidade explícita. Palco existente continua utilizável.

Provar alternância UX/AX sem mutação, ações/IDs/estado, menus e viewport nativo;
roundtrip/hash, bioma incompatível, exceção com motivo, geração sem bypass,
espécie/raros/área reservada, rejeição sem mutação e referências de quest passivas;
regressões de fonte/terreno/composição/população/patrulha/geração/intercâmbio por
impacto; export e processo release novo com perfil descartável. Listar verify
antes da seleção. Luna supervisiona término/erros/timeouts/hashes; Sol consolida.

Uma fixture reutilizável, engine compartilhada do principal; limpeza final.
Sem master/push, publicação externa, save pessoal, novos mobs/quests ou correções
E07 por inferência. Aprovação técnica e aceite humano continuam separados.
