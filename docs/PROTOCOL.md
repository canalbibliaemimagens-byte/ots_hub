# OTS Hub v2.0 — Especificação do Protocolo

## Endpoint WebSocket

`ws[s]://<host>:<port>/ws/{instance_id}`

## Envelope Padrão

```json
{
  "type": "string",
  "id": "string",
  "timestamp": 1234567890.123,
  "payload": { ... }
}
```

## Types e Roteamento

### Pipeline v3

| Type | Publisher | Subscriber(s) | Descrição |
|------|-----------|---------------|-----------|
| `bar` | connector | preditor | Nova barra OHLCV |
| `signal` | preditor | executor, dashboard | Sinal do modelo (ação, direção, intensidade) |
| `order_command` | executor | connector | Comando de ordem (open, close, modify) |
| `order_result` | connector | executor, dashboard | Resultado de execução (ticket, preço, erro) |
| `position_event` | connector | executor, dashboard | Posição fechada por SL/TP/externo |
| `account_update` | connector | executor, dashboard | Balance, equity, margin |
| `history_response` | connector | preditor | Histórico de barras solicitado |

### Controle

| Type | Publisher | Subscriber(s) | Descrição |
|------|-----------|---------------|-----------|
| `auth` | qualquer | Hub | Handshake obrigatório |
| `telemetry` | qualquer | dashboard, admin | Dados de telemetria |
| `command` | admin, dashboard | target específico | Comando administrativo |
| `ack` | target | admin, dashboard | Resposta a command |

## Auth

Primeira mensagem deve ser auth dentro de 5 segundos:

```json
{"type": "auth", "id": "1", "payload": {"token": "...", "role": "connector"}}
```

Roles válidas: `preditor`, `executor`, `connector`, `dashboard`, `admin`, `bot`

## REST Endpoints

- `GET /health` — Status do Hub
- `GET /api/v1/status` — Conexões, telemetria, comandos pendentes
- `GET /api/v1/telemetry/{instance_id}` — Última telemetria de uma instância
- `POST /api/v1/command` — Envia comando via REST
