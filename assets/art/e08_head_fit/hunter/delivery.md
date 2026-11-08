# Caçadora — base de cabelo em staging

64 poses com cabelo claro e sem capuz foram compostas a partir de quatro fontes autoradas. O original RGBA c1167462f02c866bbb11f6afca2b1eae450399131635285c108a179129906974 foi preservado; resultado df7aa3e9cdc28284c9636c02c7648e52547fb7034daf657a1e3fae57d05806a3. Verificados 64 grounds, 112 crops de dedos e pixels fora das máscaras/proteções byte a byte; reprodução offline repetida. Prancha inclui quatro vistas, idle/hurt/duas mortes, base/elmo piloto/maçã/ovo, 1×/4×.

A célula S15 mantém o traço marrom curvo do atlas de entrada sob o rosto; possível arco residual nativo29 foi comunicado a Root e não alterado nesta unidade. Âncoras e ângulos de morte requerem prova de acessórios no renderer. Integração, inspeção nativa/export e aceite permanecem pendentes; não executamos Godot, importação ou suíte de gameplay. Staging não conclui P4.

## Correção S15 — 8/11
Após limpeza da native29, `original_rgba_sha256` foi atualizado. A fonte antiga
de cabelo ainda continha o arco; a região S15 foi reduzida de [27,20,64,57]
para [27,20,64,52], preservando o corpo limpo abaixo, sem apagar pixels por código.
Os demais63 frames do bare-head permanecem byte a byte idênticos. O compositor
verificou 112 crops vivos,64 grounds e preservação fora da máscara/proteções.
A prancha foi substituída por comparação 1x/3x das quatro mortes: original,
corpo corrigido e bare-head; estudos de equipamento seguem pendentes no renderer.
O texto acima sobre S15 com arco é o recibo histórico anterior a esta correção.
