# F9 — continuidade do suporte de terreno

Engenharia Sol dentro do produto autorizado F9-02/04/10. Não altera a direção
de arte, o renderer, as unidades, EPS ou a inclinação caminhável de45°.
É pré-requisito para demonstrar relevo orgânico com a malha canônica.

Uma divisão interna em triângulos não é uma parede. O disco horizontal do corpo
pode cobrir várias superfícies conectadas no mesmo contato, inclusive vértices
onde três ou mais bordas se encontram. Validar o disco contra o contorno fechado
da união local, mantendo bordas realmente abertas, ausência de conexão, folga,
sentido de travessia e obstáculos. Não aceitar outra altura/piso por proximidade.
Testar o trecho inteiro do movimento; amostrar só extremos perde cantos e buracos.

WorldGeometry continua autoridade única. Um auxiliar puro calcula a união local
e os contatos; o índice de células/aberturas é derivado da configuração, imutável
durante consultas e reconstruído após restore. O manifesto de snapshot recebe
omissão explícita desse cache; nenhum cache pode substituir estado canônico.
Reconfigurar limpa o índice e mantém revisões monotônicas. O grafo agrupa estados
por suporte antes das ligações internas, evitando comparar todos os pares globais.

Reproduzir primeiro vértice interno bloqueado, disco cobrindo mais de uma
abertura e travessia reta/real. Contraprovas: borda externa, canto reentrante,
buraco, conexão desativada, sentido único, folga insuficiente, obstáculo e piso
desconectado. Regressão F9 geometria/objetos, produtores Core e seleção oficial
de geometria/snapshot por impacto, com supervisão Luna em árvore congelada.
Medições de malha pequena/representativa não certificam F9 inteiro nem escala
ilimitada. Penhascos e materiais continuam pendentes de implementação própria.
