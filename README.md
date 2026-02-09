# OTS Hub v2.0

Barramento central WebSocket para Oracle Trader v3. Roteia mensagens entre processos independentes.

## Arquitetura

```
Connector(s) ──bar──► Hub ──► Preditor
Preditor ──signal──► Hub ──► Executor
Executor ──order_command──► Hub ──► Connector(s)
Connector(s) ──order_result──► Hub ──► Executor
```

## Roles

| Role | Publica | Recebe |
|------|---------|--------|
| `connector` | bar, account_update, order_result, position_event | order_command, command |
| `preditor` | signal | bar, history_response, command |
| `executor` | order_command | signal, order_result, position_event, account_update, command |
| `dashboard` | — | signal, order_result, position_event, account_update, telemetry |
| `admin` | command | signal, telemetry, ack |

## Quick Start

```bash
# Setup
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Editar ORACLE_TOKEN no .env

# Run
uvicorn app.main:app --host 0.0.0.0 --port 8000

# Test
curl http://localhost:8000/health
pytest
```

## Deploy (Oracle Cloud)

```bash
bash deploy/setup.sh
```

## Protocolo

Envelope padrão:
```json
{"type": "bar|signal|order_command|...", "id": "uuid", "timestamp": 1234.5, "payload": {...}}
```

Auth handshake (primeiro mensagem obrigatória):
```json
{"type": "auth", "id": "1", "payload": {"token": "...", "role": "connector"}}
```
