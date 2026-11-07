# E08 P4 — produção artística direcional

7/11/2026. Usuário: “Vamos produzir os sprites definitivos então.” Continuação de
P4 autorizado, sem iniciar P5. Base48058190d9a7e12dce7319b6d25020e0befacfd1,
branch codex/e08, checkout C:/Users/João Pedro/Documents/ChatGPT/RagRPG/.tools/map-editor-m5.
Produtor/API: [contrato](e08_p4_directional_contract.md) e
[entrega técnica](e08_p4_directional_delivery.md). CLI workflow/tooling ausentes;
retomada por Git/checkpoint, sem copiar ferramentas. Habitual e saves preservados.

## Unidade primeiro, depois elenco

Começar pela Espiritualista de cabelo prateado/coque e traje ritual assimétrico
cinza/prata/carvão do estudo que o usuário apreciou. Referência:
e08_evidence/p4/elementalist_spiritualist_concept.png, linha inferior. Preservar
fontes históricas/candidatas. Não promover a candidata legada que perdeu24grips.
A primeira unidade completa comprova o consumo artístico antes dos demais;
esta decomposição não declara todo P4 concluído nem descarta as outras identidades.

Terra6.1 médio é executor delimitado de conteúdo conforme WORKFLOW; Sol coordena,
produz harness/teste e valida integração. Subagente, sem novo chat permanente.
Dependência produtora fechada; arquivos de dono exclusivo na
[e08_p4_art_files.json](e08_p4_art_files.json). Nenhum arquivo compartilhado em paralelo.
A transferência a Terra é apenas dos arquivos listados no seu grupo. Root escreve
somente sua lista e evidência p4_art. Retorno explícito de posse antes de editar
os arquivos do outro. Falhas do produtor retornam a Sol; API runtime é somente leitura.

## Arte e formato

Fontes por vista com imagegen integrado, transparência real, originais e prompts
preservados. Cada fonte4×4contém16poses: idle4,walk4,action4,hurt2,death2.
Quatro vistas independentes: sul,norte,leste,oeste, mesma anatomia/assimetria,
traje, escala e luz; perfil lateral é desenho próprio. Poses de dano e morte
continuam na sua vista. Mãos vazias/anatômicas visíveis com dedos legíveis, sem
arma/escudo/efeito/linha/legenda incorporados. Anexos existentes ficam separados.
O raster novo é gerado/editado com imagegen; pipeline existente faz somente a
preparação mecânica do atlas, sem inventar quadros por espelhamento/retinta.

Atlas256×1024,64células64×64, pivô32,58, corpo40–52px em repouso, sem cortar pés.
Um fator de escala por identidade preserva tamanho entre vistas e poses.
Unidade sem arma embutida: body/weaponless podem compartilhar pixels, caminhos
separados e proveniência explícita. Calibração64poses,112grips vivos anatomicamente
identificados e fingers/head/depth/angle/flip reais; verificar nos DOIS corpos.
Não escolher qualquer pixel opaco como mão. HashRGBA canônico conforme produtor.
Staging res://assets/art/e08_characters/directional/spiritualist/presentation.json,
fora da descoberta automática. Usar set_directional_manifest no probe.

## Verificação e promoção

Conferir64poses animadas nos quatro sentidos; solo claro/escuro, sombras,
equipamentos atuais (incluindo escudo/duas mãos/cabeça), morte/transições,
Camera2D50/100/160 e UI120; retrato e mundo pela mesma rotina. Conferir anatomia
em escala real e ampliada. Fonte precisa ser adequada ao jogo, não só à prancha.
Testes dirigidos do conteúdo/manifesto, seleção/restore/integração e fronteiras
atingidas, sem relaxar testes legados. Uma fixture F1 existente é reutilizada,
com sincronização explícita e hashes. Luna supervisiona lote congelado; Sol
consolida. Benchmark do renderer compara a unidade real ao controle, sem alegar
FPS de mapa. Evidência mínima portátil em docs/epics/e08_evidence/p4_art/.

Depois da unidade aprovada tecnicamente, Sol pode promover cópia para o caminho
padrão assets/art/animations/directional/spiritualist e ampliar os testes reais,
com migração explícita de expectativa visual quando necessária. Arte em staging
não significa integrada. Aceite humano do candidato precede merge/master;
sem push e sem atualização do habitual durante produção. Demais identidades
seguem com unidade/lista registrada depois desta prova, sem disparar o elenco
inteiro antes de conferir o primeiro resultado.
