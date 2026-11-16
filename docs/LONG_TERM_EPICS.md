# Roadmap vigente — 17/10/2026

Atualização de estado em5/11: [aceite E07/F10 com ressalvas](epics/e07/e07_closure_2026_11_05.md)
e [abertura documental E08](epics/e08_opening_2026_11_05.md). Integração Git
continua separada; E09+ não foram liberados. As reservas antigas não revogam
essa decisão nem autorizam consumidores de E08 sem seu contrato.

Este mapa substitui a lista antiga de reservas como orientação atual.
[Histórico](LONG_TERM_EPICS.history_2026_10_17.md) conserva aceites e planejamento
anteriores. Normas: [WORKFLOW](WORKFLOW.md); direção: [PRODUCT_DIRECTION](PRODUCT_DIRECTION.md).

| Escopo | Situação e próximo uso |
|---|---|
| E00–E03 | Fundamentos e progressão incorporados ao candidato; contratos preservados nos pontos não substituídos |
| E04 | Três bases disponíveis, com extensões posteriores documentadas em E06 |
| E05 | Seis evoluções puras + Geômetra disponíveis; cinco híbridas originais ainda bloqueadas. Não declarar épico inteiro encerrado |
| E06 | Implementado e [aceito em gameplay18/10](epics/e06/e06_gameplay_acceptance_2026_10_18.md); merge/publicação não executados |
| E07 | Fundação funcional aceita com ressalvas em5/11, ampliada pelo editor/F10; integração operacional separada. [Recibo](epics/e07/e07_closure_2026_11_05.md) |
| E08 | Arte, animações e feedback; [aceito em 16/11](epics/e08_p7_release.md#aceite-do-usuário--16112026) e integrado em `master` sem push |
| E09 | [Autorizado em 16/11](epics/e09.md): Paladino, Taumaturgo, Duelista e Lâmina Arcana, sistemas de Santuário e Sentença, pipeline de arte neutro; uma sessão por tarefa |
| Integração/demo | Reserva antiga do E09, [preservada](epics/e09.history_2026_11_16.md) e ainda sem número. Validação operacional Luna/Sol, com aceite humano |
| E10/E11 | Reservados. Bases restantes e híbridas futuras mantêm autorização por família/par; não produzir kits por efeito de roadmap |
| Economia/consumíveis/misc | Direção atualizada em18/10; alocação a épico/pacotes ainda a definir, sem execução automática |
| Consumíveis ampliados/profissões | [Gate separado](gates/consumables_professions.md) solicitado em18/10; profissões ainda em discussão, sem implementação autorizada |
| Cenários 3D low-poly | [Gate separado](gates/low_poly_environments.md) solicitado em18/10; natureza/construções e locais temáticos, sem produção ou mudança de renderer autorizadas |
| Propriedade e ameaça | Itens/gold por personagem e unlocks por perfil; migração de bens e ameaça controlável precisam de contratos, sem implementação automática |

## Campanha a planejar

Lobby com seleção de fases; estágios montados de partes, grandes e labirínticos,
com elevação funcional e portais de avanço. Populações se sobrepõem entre mapas
vizinhos do mesmo bioma e mudam de concentração; progressão aumenta força por
origem, sem acompanhar automaticamente o jogador. Augments por etapa continuam.
O roteiro E06 de três áreas/seis etapas é demonstração, não contrato de dimensão,
densidade, duração ou quantidade final da campanha.

Dependências sugeridas: contrato de fase/superfícies → conectores/montagem →
população/progressão → portal/recompensa/encerramento. Economia segue por decisões
de propriedade → inventário/carteira → consumo/compra/venda → UI e integração.
Números, APIs, SHA-base, donos e aceites são preenchidos apenas ao autorizar o pacote.

## Como abrir trabalho

Um novo chat Astra por épico autorizado cria arquitetura/guias e decisões de
produto. Execução/integração em chats temporários, tarefas substanciais e esforço
proporcional. Luna supervisiona testes; Sol valida/corrige/consolida. Astra só
retorna fora da arquitetura nas exceções justificadas de WORKFLOW.

As quatro [skills de entrega](DELIVERY_SKILLS.md) ajudam a preparar e executar
pacotes autorizados de mapas, augments, equipamentos/cartas e inimigos. Nenhuma
abre E07+, cria conversas, agenda tarefas ou publica por simples invocação.
Arquivamento depende de entrega registrada, validada e integrada; merge depende
do aceite humano do candidato. Não reutilizar reserva histórica como autorização.
