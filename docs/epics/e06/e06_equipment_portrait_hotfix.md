# Correção da identidade no retrato de equipamentos

Base:5be843fca755656af0d687fcb781ff72ba52ca08; fonte codex/e06-inventory; destino codex/playtest. Correção solicitada pelo usuário em16/10/2026, dentro do E06. Sol possui scripts/core/build_presentation.gd, tests/e06_inventory_profile_panel_test.gd e este checkpoint; Luna possui apenas relatório ignorado de supervisão.

Resultado: retrato de equipamentos usa Geômetra para evolução persistida mg_ar. As seis evoluções puras já eram reconhecidas. Bases continuam usando sua aparência; classes futuras não jogáveis conservam fallback. Mesma função atende lobby e run. Sem mudança de saves, regras, kits ou arte. Critério: matriz das dez identidades através do consumidor InventoryCharacterPreview, importação e testes dirigidos de inventário via tools/verify.ps1. Aplicar candidato tecnicamente aprovado preservando locais/save; aceite humano e merge separados.

## Validação técnica

Concluída: tools/verify.ps1, quatro etapas dirigidas (importação, UI de inventário, painel de perfil, entrada da janela),104 verificações e zero falhas. Matriz cobre as três bases, seis evoluções puras e Geômetra. O retrato real recebe a identidade correta; lobby e run compartilham o mapeamento. Supervisão Luna: C:\Users\João Pedro\Documents\ChatGPT\RagRPG\.godot\verification\portrait_hotfix\watch.json; SHA256 8c27edc9653799f72674cd973ddcab741c692d521215410b9f2b8581f8ec39e2. Sol conferiu causa, consumidores e limites. Não repetida a suíte completa230; sem mudança de regras/save. Aplicação no playtest preserva locais e três arquivos pessoais; recibo operacional em .godot/verification/portrait_hotfix/receipt.json. Aceite humano pendente.
