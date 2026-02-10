# Relatório de Auditoria: oracle_trader_v3 & ots_hub

## Resumo Executivo
Este relatório descreve as descobertas de uma auditoria de código do `oracle_trader_v3` e `ots_hub`. A auditoria focou na identificação de bugs silenciosos, inconsistências, ineficiências e na verificação de requisitos comportamentais específicos. 

**Status Geral**: O sistema **NÃO atende** a vários comportamentos básicos solicitados, especificamente no ajuste dinâmico de lote e na regra de entrada "mid-movement".

## 1. Verificação de Requisitos do Usuário (Novos Itens)

### 1.1. Ajuste Dinâmico de Tamanho de Lote (Reprodutibilidade: FALHA)
- **Requisito**: Se o Preditor envia um sinal de LARGE, depois MEDIUM no mesmo sentido, o sistema deve fechar a ordem em execução e abrir nova ordem ajustando o lote.
- **Comportamento Atual**: O sistema **ignora** a mudança de intensidade se a direção for a mesma.
- **Análise Técnica**: Em `sync_logic.py`, a função `decide()` retorna `Decision.NOOP` se `real_direction == signal_direction`. Ela não verifica se a `intensity` mudou. Consequentemente, o `Executor` não recebe instrução para fechar e reabrir.
- **Correção Necessária**: Alterar `decide()` para retornar `CLOSE_AND_OPEN` (ou um novo status) quando a direção é mantida mas a intensidade muda.

### 1.2. Proteção de Entrada no Meio do Movimento (Reprodutibilidade: FALHA)
- **Requisito**: Se o bot for iniciado, deve verificar se há ordem aberta. Se corresponder, nada faz. Se divergir, fecha. **Se não houver ordem, deve esperar o próximo sinal (transição) e não entrar imediatamente.**
- **Comportamento Atual**: O sistema entra **imediatamente** na primeira execução se o sinal não for ZERO, devido à flag `first_live=True`.
- **Análise Técnica**: Em `sync_logic.py`, `SyncState.should_open` permite explicitamente a entrada se `self.first_live` for verdadeiro, ignorando a necessidade de ocorrer uma *transição* de sinal.
- **Correção Necessária**: Remover a lógica `first_live` ou configurá-la para exigir uma transição real de estado (ex: esperar o sinal ir para ZERO ou mudar de direção antes de aceitar a primeira entrada).

### 1.3. Arquitetura Multi-Par e Multi-Modelo (Reprodutibilidade: PARCIAL/FALHA)
- **Requisito**: Preditor deve carregar mais de um modelo e utilizá-los simultaneamente. Executor deve lidar com vários símbolos.
- **Comportamento Atual**:
    - **Executor**: Suporta múltiplos símbolos (`self.symbol_configs` é um dicionário).
    - **Preditor**: A classe `Preditor` (em `preditor.py`) é projetada para **um único** símbolo/modelo. Não há suporte nativo na classe para carregar múltiplos modelos em loop.
- **Correção Necessária**: Refatorar `Preditor` para gerenciar uma lista de modelos (`Dict[symbol, ModelBundle]`) ou utilizar um orquestrador que inicie múltiplos processos `Preditor`.

### 1.4. SL/TP e Configuração (Reprodutibilidade: OK com ressalvas)
- **Requisito**: SL/TP em valores financeiros baseados em PnL flutuante (Geral e Individual). Intensidade ajustável.
- **Análise**:
    - **SL Geral**: `RiskGuard` implementa limite de Drawdown global baseado no PnL da conta (`_check_drawdown`). **OK**.
    - **SL Individual**: `Executor` calcula preço de SL baseado em valor financeiro (`sl_usd`) e envia para a corretora. Funciona como SL financeiro. **OK**.
    - **Intensidade**: Configurável por par (`lot_weak`, `lot_moderate`, `lot_strong`). **OK**.
    - **Configuração Centralizada**: Atualmente espalhada em arquivos YAML/dict. **Não atende** ao requisito de centralização (sugerido Supabase).

---

## 2. Bugs Silenciosos (Anteriormente Identificados)

### 2.1. Executor: Falha Lógica em `_on_signal`
- **Localização**: `oracle_trader_v3/executor/executor.py`, linhas 162-166.
- **Problema**: O bug de "efeito colateral" no `should_open` também afeta a lógica de reentrada. Se `should_open` retornar `False` após um `CLOSE` (no caso de `CLOSE_AND_OPEN`), o bot fica fora do mercado indevidamente.

### 2.2. Connector: Confiabilidade de Ordens a Mercado
- **Localização**: `oracle_trader_v3/connectors/ctrader/client.py`.
- **Problema**: Envio de SL/TP relativo depende de cache de preço (`_last_prices`). Se o cache estiver vazio (início frio), ordens podem ir sem Stop Loss.

## 3. Recomendações de Melhoria

1.  **Migração para Supabase**: Centralizar toda configuração (símbolos, riscos, modelos) em lógicas de banco de dados, removendo arquivos YAML dispersos.
2.  **Refatoração de SyncLogic**:
    - Implementar detecção de mudança de intensidade em `decide()`.
    - Implementar modo "Wait for Signal" estrito na inicialização (remover `first_live` permissivo).
3.  **Refatoração do Preditor**:
    - Alterar para carregar múltiplos modelos e processar 1 sinal de barra -> N predições (uma por modelo).
4.  **Correção de Cache de Preço**: O Connector deve bloquear ordens até ter recebido pelo menos um tick de preço do símbolo.
