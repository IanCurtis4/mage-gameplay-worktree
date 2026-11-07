# Receita de staging — equipamentos P4

Fontes próprias geradas com image_gen integrado, transparência solicitada; prompts,
fontes de edição e SHA-256 em `provenance.json`. A referência externa informou
proporção/estilo; nenhum sprite dela foi copiado. `inventory.json` extrai nomes,
qualidade, origem e restrições reais das definições. O pool de loot é global por
qualidade e nível, não uma associação de mob por classe. Estudos de maçã/flecha
e casca não possuem ID nem drop.

Execute `python tools/prepare_e08_equipment_redesign.py` na raiz deste checkout
com Pillow instalado. O script só recorta, mede alpha, redimensiona e posiciona
fontes autorizadas; não gera formas. Atlas de cabeça: quatro células horizontais
96x96 (S,N,E,W), cada uma equivalente a 24x24 lógicos e âncora inicial 12,13.
O recorte mede alpha >=32, preserva a borda antialias e usa até 76x64 pixels 4x;
`bbox_4x` é a caixa de posicionamento do recorte, incluindo margem, não uma
promessa de encaixe. Armas têm tamanhos e grips lógicos em `presentation.json`;
arco é espelhado para posicionar o corpo na mão, e arco/machado transladados.
A composição da folha usa as poses e pontos de cabeça da Espiritualista disponíveis
neste checkout, e depende desses arquivos para reproduzir a comparação.

O contato mostra os sprites sobre fundos claro e escuro, miniaturas em tamanho
lógico e comparações com corpo. Elas são evidência estática, não teste do renderer.
