---
name: ragrpg-art
description: Preparar e integrar arte ou VFX autorizados do RagRPG reutilizando o pipeline existente e verificando leitura no jogo.
---

# Arte do RagRPG

Resolva a raiz com `git -C <diretório informado ou cwd> rev-parse --show-toplevel`.
Leia AGENTS.md, docs/MVP.md, docs/ARCHITECTURE.md, docs/WORKFLOW.md,
docs/REVIEW_WORK_PACKAGES.md e o briefing/contrato visual do escopo autorizado.
Consulte docs/MVP_VISUAL_ASSET_PLAN.md apenas nas partes relevantes e distinga
componentes existentes de propostas. A skill não autoriza produção de novo kit.

Inventarie fonte, atlas/runtime, consumidor e estado de aprovação antes de editar.
Inspecione ferramentas existentes em tools/prepare_animation_assets.py,
tools/preview_animations.py, tools/art_preview.gd e probes específicos da classe.
Confira entradas/saídas e classes configuradas antes de executar: esses scripts
não são uma API genérica e alguns geram arquivos. Preserve as fontes originais.
Para gerar ou editar raster com IA, use a skill imagegen disponível no ambiente;
não trate concept sheet como atlas final automaticamente.

Reutilize o contrato de pivô, escala e animações; confira frente/costas,
espelhamento, arma, silhueta e transparência em tamanho real. VFX consome eventos
e geometria do gameplay; mudança de semântica segue o fluxo contratual vigente.
Compare piso claro/escuro e sobreposição no renderer, além de testes dirigidos.
Registre evidência visual e limitações no checkpoint existente. Headless não
aprova legibilidade, timing percebido ou desempenho; fechamento segue a revisão
integrada e o playtest de docs/WORKFLOW.md.


## Intercâmbio no editor de mapas F7

Use piece para materiais/props já publicados no catálogo local. O bundle não instala texturas, scripts ou modelos novos; produção e integração de assets têm contrato próprio antes de referenciá-los.
Leia `docs/map_editor/exchange.md` no checkout autorizado para schema, CLI e limites.
Receba o pedido `.rpx` exportado pela pessoa, preserve-o byte a byte e trabalhe
numa cópia de `files[source.json].data`. Não edite ticket, base, permissões ou
relatório para ampliar o escopo. Declare o hash do pedido/base e os IDs que vai
alterar. As seções/IDs e caminhos protegidos são autorização local; camadas
travadas, regiões protegidas, slots fixos e pins permanecem conservados.

Produza candidate.json estrito e rode a CLI versionada `propose <pedido.rpx>
<candidate.json> <proposta.rpx>` com o Godot contratado. O produtor valida/compila;
falha conserva o original, sem scripts/cenas, paths absolutos/traversal ou
reparo silencioso. Confira `review <pedido.rpx> <proposta.rpx> <fonte_atual.json>`
e entregue proposta, diff, hashes e limitações. Base divergente exige novo pedido
exportado/reconciliação humana explícita. A pessoa importa a proposta no editor,
compara Antes/Proposta e confirma uma ação desfazível. Não sobrescreva a fonte
humana, não publique nem ative o WFC por inferência. A mesma autoridade atende
GUI/CLI. Essa adaptação da fonte versionada não sincroniza cópias instaladas.
