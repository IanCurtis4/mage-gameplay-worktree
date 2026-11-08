# Caçadora — staging direcional

64 poses e cabeças, body/weaponless idênticos, manifesto e calibração preparados offline. Os 32 quadros S/N correspondem ao native_cleaned; 29 deles são idênticos byte a byte ao original. As células originais 28/30/31 tinham arco residual e foram substituídas por arte ImageGen sem arma; 29 foi preservada. Ambos os corpos têm 112 pontos vivos com alpha superior a 5; essa verificação não prova anatomia ou oclusão no renderer. Oito poses de morte usam depth0 e ângulos PI/2 para equipamentos soltos, contas zero.

As luvas das poses E37/E45 e W53/W55 merecem atenção com equipamentos em inspeção nativa. Validação no renderer, integração, export e aceite de produto permanecem pendentes. Não executamos Godot, importação ou suíte de gameplay. Staging não conclui P4.

## Correção S15 — 8/11
A inspeção posterior confirmou arco em native29, então a fonte v2 substitui só
esse frame. Agora 28 nativas originais permanecem intactas e as quatro mortes
28/29/30/31 usam arte sem arco; 28/30/31 não mudaram nesta rodada. O body e o
weaponless mantêm os outros63 frames idênticos. Comparação estática em
`assets/art/e08_head_fit/hunter/contact_sheet.png` mostra o original e ambas as
variantes corrigidas. Rigs, 112 crops vivos e 64 grounds foram conferidos no
compositor; visibilidade/anatomia de mão e encaixe de acessórios em runtime ainda
requerem prova nativa. Não houve Godot, importação ou suíte de gameplay.
