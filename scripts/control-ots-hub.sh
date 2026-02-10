#!/bin/bash
################################################################################
# OTS Hub v2.0 - Script de Controle
# 
# Script completo para gerenciar o serviço OTS Hub
# Uso: bash control-ots-hub.sh [comando]
# Comandos: start, stop, restart, status, logs, health, validate, backup, info
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configurações
SERVICE_NAME="ots-hub"
PORT=8000

# Detectar diretório do projeto
if [ -d "ots_hub" ]; then
    PROJECT_DIR="$(cd ots_hub && pwd)"
elif [ -f "app/main.py" ]; then
    PROJECT_DIR="$(pwd)"
else
    PROJECT_DIR="/opt/ots_hub"  # Fallback
fi

# Funções de impressão
print_header() {
    echo ""
    echo "══════════════════════════════════════════════════════════"
    echo -e "${BLUE}$1${NC}"
    echo "══════════════════════════════════════════════════════════"
    echo ""
}

print_section() {
    echo -e "${CYAN}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Verificar se serviço existe
check_service_exists() {
    if ! systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
        print_error "Serviço $SERVICE_NAME não encontrado"
        print_info "Execute o script de deploy primeiro: bash deploy-ots-hub.sh"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════
# COMANDO: START
# ═══════════════════════════════════════════════════════════
cmd_start() {
    print_header "Iniciando OTS Hub"
    check_service_exists
    
    # Verificar se já está rodando
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_warning "Serviço já está rodando"
        print_info "Use 'restart' para reiniciar ou 'stop' para parar"
        return 0
    fi
    
    print_section "Iniciando serviço..."
    sudo systemctl start $SERVICE_NAME
    
    # Aguardar inicialização
    sleep 3
    
    # Verificar status
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Serviço iniciado com sucesso"
        
        # Testar endpoint
        sleep 2
        if curl -s http://localhost:$PORT/health >/dev/null 2>&1; then
            print_success "Endpoint /health respondendo"
        else
            print_warning "Serviço iniciado mas endpoint ainda não responde"
            print_info "Aguarde alguns segundos e tente: curl http://localhost:$PORT/health"
        fi
    else
        print_error "Falha ao iniciar serviço"
        print_info "Verifique os logs: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════
# COMANDO: STOP
# ═══════════════════════════════════════════════════════════
cmd_stop() {
    print_header "Parando OTS Hub"
    check_service_exists
    
    # Verificar se está rodando
    if ! sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_warning "Serviço já está parado"
        return 0
    fi
    
    print_section "Parando serviço..."
    sudo systemctl stop $SERVICE_NAME
    
    # Aguardar parada
    sleep 2
    
    # Verificar status
    if ! sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Serviço parado com sucesso"
    else
        print_error "Falha ao parar serviço"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════
# COMANDO: RESTART
# ═══════════════════════════════════════════════════════════
cmd_restart() {
    print_header "Reiniciando OTS Hub"
    check_service_exists
    
    print_section "Reiniciando serviço..."
    sudo systemctl restart $SERVICE_NAME
    
    # Aguardar reinicialização
    sleep 3
    
    # Verificar status
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Serviço reiniciado com sucesso"
        
        # Testar endpoint
        sleep 2
        if curl -s http://localhost:$PORT/health >/dev/null 2>&1; then
            print_success "Endpoint /health respondendo"
        else
            print_warning "Serviço reiniciado mas endpoint ainda não responde"
            print_info "Aguarde alguns segundos"
        fi
    else
        print_error "Falha ao reiniciar serviço"
        print_info "Verifique os logs: sudo journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════
# COMANDO: STATUS
# ═══════════════════════════════════════════════════════════
cmd_status() {
    print_header "Status do OTS Hub"
    check_service_exists
    
    # Status do systemd
    print_section "Status do Systemd:"
    sudo systemctl status $SERVICE_NAME --no-pager || true
    
    echo ""
    
    # Status da aplicação
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_section "Status da Aplicação:"
        
        # Tentar obter health
        HEALTH=$(curl -s http://localhost:$PORT/health 2>/dev/null || echo "")
        
        if [ -n "$HEALTH" ]; then
            echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
        else
            print_warning "Não foi possível obter status da aplicação"
        fi
        
        echo ""
        
        # Tentar obter status detalhado
        print_section "Status Detalhado:"
        STATUS=$(curl -s http://localhost:$PORT/api/v1/status 2>/dev/null || echo "")
        
        if [ -n "$STATUS" ]; then
            echo "$STATUS" | python3 -m json.tool 2>/dev/null || echo "$STATUS"
        else
            print_warning "Não foi possível obter status detalhado"
        fi
    else
        print_error "Serviço não está rodando"
    fi
    
    echo ""
    
    # Informações de recursos
    print_section "Uso de Recursos:"
    if command -v ps &>/dev/null; then
        PID=$(sudo systemctl show -p MainPID $SERVICE_NAME | cut -d'=' -f2)
        if [ "$PID" != "0" ]; then
            ps -p $PID -o pid,ppid,cmd,%mem,%cpu,etime 2>/dev/null || print_info "Não foi possível obter informações de recursos"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════
# COMANDO: LOGS
# ═══════════════════════════════════════════════════════════
cmd_logs() {
    print_header "Logs do OTS Hub"
    check_service_exists
    
    local lines=${1:-100}
    local follow=${2:-false}
    
    if [ "$follow" = "follow" ] || [ "$follow" = "-f" ]; then
        print_section "Seguindo logs em tempo real (Ctrl+C para sair)..."
        echo ""
        sudo journalctl -u $SERVICE_NAME -f
    else
        print_section "Últimas $lines linhas de log:"
        echo ""
        sudo journalctl -u $SERVICE_NAME -n $lines --no-pager
    fi
}

# ═══════════════════════════════════════════════════════════
# COMANDO: HEALTH
# ═══════════════════════════════════════════════════════════
cmd_health() {
    print_header "Health Check do OTS Hub"
    
    print_section "Verificando conectividade..."
    
    # Teste 1: Service está rodando?
    if sudo systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        print_success "Serviço systemd: ATIVO"
    else
        print_error "Serviço systemd: INATIVO"
        return 1
    fi
    
    # Teste 2: Porta está ouvindo?
    if command -v netstat &>/dev/null; then
        if sudo netstat -tlnp | grep -q ":$PORT "; then
            print_success "Porta $PORT: OUVINDO"
        else
            print_error "Porta $PORT: NÃO ESTÁ OUVINDO"
        fi
    elif command -v ss &>/dev/null; then
        if sudo ss -tlnp | grep -q ":$PORT "; then
            print_success "Porta $PORT: OUVINDO"
        else
            print_error "Porta $PORT: NÃO ESTÁ OUVINDO"
        fi
    fi
    
    # Teste 3: Endpoint /health responde?
    print_section "Testando endpoints..."
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Endpoint /health: OK (HTTP $HTTP_CODE)"
        
        # Mostrar resposta
        RESPONSE=$(curl -s http://localhost:$PORT/health 2>/dev/null)
        echo ""
        echo "  Resposta:"
        echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    else
        print_error "Endpoint /health: FALHOU (HTTP $HTTP_CODE)"
    fi
    
    echo ""
    
    # Teste 4: Root endpoint
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/ 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ]; then
        print_success "Endpoint /: OK (HTTP $HTTP_CODE)"
    else
        print_error "Endpoint /: FALHOU (HTTP $HTTP_CODE)"
    fi
    
    echo ""
    
    # Teste 5: WebSocket (básico)
    print_section "Testando WebSocket..."
    if command -v wscat &>/dev/null; then
        print_info "Use 'wscat -c ws://localhost:$PORT/ws/test' para testar WebSocket"
    else
        print_info "Instale wscat para testar WebSocket: npm install -g wscat"
    fi
}

# ═══════════════════════════════════════════════════════════
# COMANDO: VALIDATE
# ═══════════════════════════════════════════════════════════
cmd_validate() {
    print_header "Validação Completa do OTS Hub"
    
    local errors=0
    
    # 1. Verificar arquivos
    print_section "1. Verificando arquivos do projeto..."
    
    if [ -d "$PROJECT_DIR" ]; then
        print_success "Diretório do projeto: $PROJECT_DIR"
    else
        print_error "Diretório do projeto não encontrado: $PROJECT_DIR"
        ((errors++))
    fi
    
    if [ -f "$PROJECT_DIR/app/main.py" ]; then
        print_success "Arquivo main.py encontrado"
    else
        print_error "Arquivo main.py não encontrado"
        ((errors++))
    fi
    
    if [ -f "$PROJECT_DIR/.env" ]; then
        print_success "Arquivo .env encontrado"
        
        # Verificar token
        if grep -q "gerar-um-token-seguro-aqui" "$PROJECT_DIR/.env" 2>/dev/null; then
            print_warning "Token padrão detectado no .env - CONFIGURE UM TOKEN SEGURO!"
            ((errors++))
        fi
    else
        print_error "Arquivo .env não encontrado"
        ((errors++))
    fi
    
    if [ -d "$PROJECT_DIR/venv" ]; then
        print_success "Virtual environment encontrado"
    else
        print_error "Virtual environment não encontrado"
        ((errors++))
    fi
    
    echo ""
    
    # 2. Verificar serviço systemd
    print_section "2. Verificando serviço systemd..."
    
    if systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
        print_success "Serviço systemd configurado"
        
        if systemctl is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
            print_success "Serviço habilitado para iniciar no boot"
        else
            print_warning "Serviço não está habilitado para iniciar no boot"
        fi
        
        if sudo systemctl is-active --quiet $SERVICE_NAME; then
            print_success "Serviço está rodando"
        else
            print_warning "Serviço não está rodando"
        fi
    else
        print_error "Serviço systemd não configurado"
        ((errors++))
    fi
    
    echo ""
    
    # 3. Verificar dependências Python
    print_section "3. Verificando dependências Python..."
    
    if [ -f "$PROJECT_DIR/venv/bin/python" ]; then
        cd "$PROJECT_DIR"
        
        # FastAPI
        if venv/bin/python -c "import fastapi" 2>/dev/null; then
            VERSION=$(venv/bin/python -c "import fastapi; print(fastapi.__version__)")
            print_success "FastAPI instalado (versão $VERSION)"
        else
            print_error "FastAPI não instalado"
            ((errors++))
        fi
        
        # Uvicorn
        if venv/bin/python -c "import uvicorn" 2>/dev/null; then
            VERSION=$(venv/bin/python -c "import uvicorn; print(uvicorn.__version__)")
            print_success "Uvicorn instalado (versão $VERSION)"
        else
            print_error "Uvicorn não instalado"
            ((errors++))
        fi
        
        # WebSockets
        if venv/bin/python -c "import websockets" 2>/dev/null; then
            print_success "WebSockets instalado"
        else
            print_error "WebSockets não instalado"
            ((errors++))
        fi
    fi
    
    echo ""
    
    # 4. Verificar firewall
    print_section "4. Verificando firewall..."
    
    if command -v ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
        if sudo ufw status | grep -q "$PORT"; then
            print_success "Porta $PORT aberta no UFW"
        else
            print_warning "Porta $PORT não está aberta no UFW"
        fi
    elif command -v iptables &>/dev/null; then
        if sudo iptables -L INPUT -n | grep -q "dpt:$PORT"; then
            print_success "Porta $PORT aberta no iptables"
        else
            print_warning "Porta $PORT não está aberta no iptables"
        fi
    else
        print_info "Nenhum firewall detectado"
    fi
    
    echo ""
    
    # Resumo
    print_section "═══════════════════════════════════════"
    if [ $errors -eq 0 ]; then
        print_success "Validação completa: TUDO OK"
    else
        print_error "Validação completa: $errors erro(s) encontrado(s)"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════
# COMANDO: TUNNEL
# ═══════════════════════════════════════════════════════════
cmd_tunnel() {
    print_header "Status do Cloudflare Tunnel"
    
    # Verificar se serviço existe
    if ! systemctl list-unit-files | grep -q "cloudflare-tunnel.service"; then
        print_error "Serviço Cloudflare Tunnel não configurado"
        print_info "Execute o deploy novamente e escolha instalar o Cloudflare Tunnel"
        return 1
    fi
    
    # Status do systemd
    print_section "Status do Systemd:"
    sudo systemctl status cloudflare-tunnel --no-pager || true
    
    echo ""
    
    # Tentar obter URL do Supabase
    print_section "URL Pública:"
    
    if [ -f "$PROJECT_DIR/.env" ]; then
        SUPABASE_URL=$(grep "^SUPABASE_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d ' ')
        SUPABASE_KEY=$(grep "^SUPABASE_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d ' ')
        
        if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_KEY" ]; then
            TUNNEL_DATA=$(curl -s "${SUPABASE_URL}/rest/v1/tunnel_config?service_name=eq.ots-hub&select=ws_url,wss_url,updated_at" \
                -H "apikey: ${SUPABASE_KEY}" \
                -H "Authorization: Bearer ${SUPABASE_KEY}" 2>/dev/null || echo "")
            
            if [ -n "$TUNNEL_DATA" ]; then
                echo "$TUNNEL_DATA" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data and len(data) > 0:
        entry = data[0]
        print(f\"  WSS URL:     {entry.get('wss_url', 'N/A')}\")
        print(f\"  WS URL:      {entry.get('ws_url', 'N/A')}\")
        print(f\"  Atualizado:  {entry.get('updated_at', 'N/A')}\")
    else:
        print('  Nenhum tunnel registrado no Supabase')
except:
    print('  Erro ao processar dados do Supabase')
" 2>/dev/null || echo "  Não foi possível obter URL do Supabase"
            else
                print_warning "Não foi possível conectar ao Supabase"
            fi
        else
            print_warning "Supabase não configurado no .env"
        fi
    else
        print_warning "Arquivo .env não encontrado"
    fi
    
    echo ""
    
    # URL dos logs
    print_section "Logs Recentes:"
    sudo journalctl -u cloudflare-tunnel -n 10 --no-pager 2>/dev/null || print_warning "Não foi possível obter logs"
}

# ═══════════════════════════════════════════════════════════
# COMANDO: BACKUP
# ═══════════════════════════════════════════════════════════
cmd_backup() {
    print_header "Backup do OTS Hub"
    
    BACKUP_DIR="$HOME/ots_hub_backups"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/ots_hub_backup_$TIMESTAMP.tar.gz"
    
    # Criar diretório de backup
    mkdir -p "$BACKUP_DIR"
    
    print_section "Criando backup..."
    print_info "Destino: $BACKUP_FILE"
    
    # Criar backup
    cd "$PROJECT_DIR"
    tar -czf "$BACKUP_FILE" \
        --exclude='venv' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='.git' \
        . 2>/dev/null
    
    if [ -f "$BACKUP_FILE" ]; then
        SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        print_success "Backup criado: $BACKUP_FILE ($SIZE)"
        
        # Listar backups existentes
        echo ""
        print_section "Backups disponíveis:"
        ls -lh "$BACKUP_DIR" | grep "ots_hub_backup" | awk '{print "  " $9 " (" $5 ")"}'
    else
        print_error "Falha ao criar backup"
        exit 1
    fi
}

# ═══════════════════════════════════════════════════════════
# COMANDO: INFO
# ═══════════════════════════════════════════════════════════
cmd_info() {
    print_header "Informações do OTS Hub"
    
    print_section "Configuração:"
    echo "  Serviço:       $SERVICE_NAME"
    echo "  Porta:         $PORT"
    echo "  Diretório:     $PROJECT_DIR"
    
    if [ -f "$PROJECT_DIR/.env" ]; then
        echo "  Config (.env): Presente"
        
        # Ler configurações do .env (sem mostrar token)
        if grep -q "^HOST=" "$PROJECT_DIR/.env" 2>/dev/null; then
            HOST=$(grep "^HOST=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
            echo "  Host:          $HOST"
        fi
        
        if grep -q "^DEBUG=" "$PROJECT_DIR/.env" 2>/dev/null; then
            DEBUG=$(grep "^DEBUG=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
            echo "  Debug:         $DEBUG"
        fi
    fi
    
    echo ""
    
    print_section "Status:"
    if sudo systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        echo "  Estado:        ATIVO"
        
        UPTIME=$(sudo systemctl show -p ActiveEnterTimestamp $SERVICE_NAME | cut -d'=' -f2)
        echo "  Uptime desde:  $UPTIME"
        
        PID=$(sudo systemctl show -p MainPID $SERVICE_NAME | cut -d'=' -f2)
        echo "  PID:           $PID"
    else
        echo "  Estado:        INATIVO"
    fi
    
    echo ""
    
    print_section "Endpoints:"
    echo "  Root:          http://localhost:$PORT/"
    echo "  Health:        http://localhost:$PORT/health"
    echo "  Status:        http://localhost:$PORT/api/v1/status"
    echo "  Docs:          http://localhost:$PORT/docs"
    echo "  WebSocket:     ws://localhost:$PORT/ws/{instance_id}"
    
    echo ""
    
    print_section "Comandos úteis:"
    echo "  Iniciar:       sudo systemctl start $SERVICE_NAME"
    echo "  Parar:         sudo systemctl stop $SERVICE_NAME"
    echo "  Reiniciar:     sudo systemctl restart $SERVICE_NAME"
    echo "  Status:        sudo systemctl status $SERVICE_NAME"
    echo "  Logs:          sudo journalctl -u $SERVICE_NAME -f"
}

# ═══════════════════════════════════════════════════════════
# MENU INTERATIVO
# ═══════════════════════════════════════════════════════════
show_menu() {
    print_header "OTS Hub v2.0 - Controle"
    
    echo "Selecione uma opção:"
    echo ""
    echo "  1) Start      - Iniciar serviço"
    echo "  2) Stop       - Parar serviço"
    echo "  3) Restart    - Reiniciar serviço"
    echo "  4) Status     - Ver status detalhado"
    echo "  5) Logs       - Ver logs recentes"
    echo "  6) Health     - Health check completo"
    echo "  7) Validate   - Validar instalação"
    echo "  8) Backup     - Criar backup"
    echo "  9) Info       - Informações do sistema"
    echo " 10) Tunnel     - Status do Cloudflare Tunnel"
    echo "  0) Sair"
    echo ""
    read -p "Opção: " choice
    
    case $choice in
        1) cmd_start ;;
        2) cmd_stop ;;
        3) cmd_restart ;;
        4) cmd_status ;;
        5) cmd_logs 100 ;;
        6) cmd_health ;;
        7) cmd_validate ;;
        8) cmd_backup ;;
        9) cmd_info ;;
        10) cmd_tunnel ;;
        0) exit 0 ;;
        *) print_error "Opção inválida"; show_menu ;;
    esac
    
    echo ""
    read -p "Pressione ENTER para continuar..."
    show_menu
}

# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════
main() {
    # Verificar se foi passado comando
    if [ $# -eq 0 ]; then
        show_menu
        exit 0
    fi
    
    # Processar comando
    case "$1" in
        start)
            cmd_start
            ;;
        stop)
            cmd_stop
            ;;
        restart)
            cmd_restart
            ;;
        status)
            cmd_status
            ;;
        logs)
            cmd_logs "${2:-100}" "${3:-}"
            ;;
        health)
            cmd_health
            ;;
        validate)
            cmd_validate
            ;;
        backup)
            cmd_backup
            ;;
        info)
            cmd_info
            ;;
        tunnel)
            cmd_tunnel
            ;;
        *)
            echo "Uso: $0 {start|stop|restart|status|logs|health|validate|backup|info|tunnel}"
            echo ""
            echo "Comandos:"
            echo "  start      - Inicia o serviço"
            echo "  stop       - Para o serviço"
            echo "  restart    - Reinicia o serviço"
            echo "  status     - Mostra status detalhado"
            echo "  logs       - Mostra logs (use: logs 100 follow para seguir)"
            echo "  health     - Executa health check completo"
            echo "  validate   - Valida instalação completa"
            echo "  backup     - Cria backup do projeto"
            echo "  info       - Mostra informações do sistema"
            echo "  tunnel     - Status do Cloudflare Tunnel e URL pública"
            echo ""
            echo "Ou execute sem argumentos para menu interativo"
            exit 1
            ;;
    esac
}

# Executar
main "$@"
