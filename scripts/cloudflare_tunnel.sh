#!/bin/bash
#
# cloudflare_tunnel.sh - Inicia Cloudflare Tunnel e envia URL para Supabase
#
# Este script:
# 1. Inicia cloudflared com Quick Tunnel
# 2. Captura a URL gerada
# 3. Envia para tabela tunnel_config no Supabase
# 4. Mantém o tunnel rodando

set -e

# Carregar .env se existir (para execução manual)
if [ -f "$(dirname "$0")/../.env" ]; then
    export $(grep -v '^#' "$(dirname "$0")/../.env" | xargs)
fi

# === CONFIGURAÇÃO ===
SUPABASE_URL="${SUPABASE_URL:-https://erinxuykijsydorlgjgy.supabase.co}"
SUPABASE_KEY="${SUPABASE_KEY:-}"  # Service role key (não anon!)
SERVICE_NAME="${SERVICE_NAME:-ots-hub}"
LOCAL_PORT="${LOCAL_PORT:-8000}"
LOG_FILE="${HOME}/cloudflare_tunnel.log"

# === FUNÇÕES ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

send_to_supabase() {
    local ws_url="$1"
    local wss_url="$2"
    
    if [ -z "$SUPABASE_KEY" ]; then
        log "WARN: SUPABASE_KEY não configurada, pulando envio"
        return 0
    fi
    
    # UPSERT (Insert ou Update se existir)
    # Usa on_conflict=service_name
    curl -s -X POST "${SUPABASE_URL}/rest/v1/tunnel_config?on_conflict=service_name" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: resolution=merge-duplicates" \
        -d "{
            \"service_name\": \"${SERVICE_NAME}\",
            \"ws_url\": \"${ws_url}\",
            \"wss_url\": \"${wss_url}\",
            \"updated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }" > /dev/null
    
    log "URL enviada ao Supabase (UPSERT): ${wss_url}"
    
    # 2. UPDATE para garantir (caso já existia)
    curl -s -X PATCH "${SUPABASE_URL}/rest/v1/tunnel_config?service_name=eq.${SERVICE_NAME}" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"ws_url\": \"${ws_url}\",
            \"wss_url\": \"${wss_url}\",
            \"updated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
        }" > /dev/null
    
    log "URL enviada ao Supabase: ${wss_url}"
}

# === MAIN ===
log "=== Iniciando Cloudflare Tunnel ==="

# Aguarda rede estabilizar (útil no boot)
sleep 5

# Arquivo temporário para capturar output
TUNNEL_OUTPUT=$(mktemp)

# Inicia cloudflared em background, capturando output
cloudflared tunnel --url "http://localhost:${LOCAL_PORT}" --protocol http2 2>&1 | tee "$TUNNEL_OUTPUT" &
TUNNEL_PID=$!

log "Tunnel PID: $TUNNEL_PID"

# Aguarda URL aparecer no output (max 30s)
ATTEMPTS=0
MAX_ATTEMPTS=30
TUNNEL_URL=""

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    sleep 1
    ATTEMPTS=$((ATTEMPTS + 1))
    
    # Procura pela URL no output
    TUNNEL_URL=$(grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_OUTPUT" | head -1 || true)
    
    if [ -n "$TUNNEL_URL" ]; then
        log "URL capturada: $TUNNEL_URL"
        break
    fi
done

if [ -z "$TUNNEL_URL" ]; then
    log "ERRO: Não conseguiu capturar URL após ${MAX_ATTEMPTS}s"
    kill $TUNNEL_PID 2>/dev/null || true
    exit 1
fi

# Gera URLs para WebSocket
WS_URL="${TUNNEL_URL/https:/ws:}"
WSS_URL="${TUNNEL_URL/https:/wss:}"

log "WS URL: $WS_URL"
log "WSS URL: $WSS_URL"

# Envia para Supabase
send_to_supabase "$WS_URL" "$WSS_URL"

log "=== Tunnel ativo, mantendo processo ==="

# Limpa arquivo temporário
rm -f "$TUNNEL_OUTPUT"

# Aguarda processo do tunnel (mantém script rodando)
wait $TUNNEL_PID
