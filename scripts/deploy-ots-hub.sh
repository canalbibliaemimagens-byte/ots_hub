#!/bin/bash
################################################################################
# OTS Hub v2.0 - Script de Deploy Automatizado
# 
# Este script configura e implanta o OTS Hub com validação completa de cada etapa
# Uso: bash deploy-ots-hub.sh
################################################################################

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configurações
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_NAME="ots-hub"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
PYTHON_VERSION="3.8"
PORT=8000

# Função para imprimir com cores
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
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

# Função para validar comandos
validate_command() {
    if [ $? -eq 0 ]; then
        print_success "$1"
        return 0
    else
        print_error "$1 - FALHOU"
        return 1
    fi
}

# Cabeçalho
echo ""
echo "══════════════════════════════════════════════════════════"
echo -e "${BLUE}         OTS Hub v2.0 - Deploy Automatizado${NC}"
echo "══════════════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════════
# ETAPA 1: Verificações Pré-requisitos
# ═══════════════════════════════════════════════════════════
print_step "ETAPA 1: Verificando pré-requisitos..."

# Verificar Python
if command -v python3 &>/dev/null; then
    PYTHON_VER=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
    print_success "Python encontrado (versão $PYTHON_VER)"
else
    print_error "Python 3 não encontrado"
    echo "  Instalando Python 3..."
    sudo apt-get update -qq
    sudo apt-get install -y python3 python3-venv python3-pip
    validate_command "Instalação do Python 3"
fi

# Verificar pip
if command -v pip3 &>/dev/null; then
    print_success "pip3 encontrado"
else
    print_warning "pip3 não encontrado, instalando..."
    sudo apt-get install -y python3-pip
    validate_command "Instalação do pip3"
fi

# Verificar curl
if command -v curl &>/dev/null; then
    print_success "curl encontrado"
else
    print_warning "curl não encontrado, instalando..."
    sudo apt-get install -y curl
    validate_command "Instalação do curl"
fi

# Verificar systemd
if command -v systemctl &>/dev/null; then
    print_success "systemd encontrado"
else
    print_error "systemd não encontrado - este sistema não é suportado"
    exit 1
fi

echo ""

# ═══════════════════════════════════════════════════════════
# ETAPA 2: Preparação do Ambiente
# ═══════════════════════════════════════════════════════════
print_step "ETAPA 2: Preparando ambiente..."

# Navegar para diretório do projeto
if [ -d "ots_hub" ]; then
    cd ots_hub
    PROJECT_DIR="$(pwd)"
    print_success "Diretório do projeto: $PROJECT_DIR"
else
    print_error "Diretório ots_hub não encontrado"
    print_warning "Execute este script no diretório pai de ots_hub"
    exit 1
fi

# Criar virtual environment
if [ -d "venv" ]; then
    print_warning "Virtual environment já existe, removendo para recriar..."
    rm -rf venv
fi

print_step "Criando virtual environment..."
python3 -m venv venv
validate_command "Criação do virtual environment"

# Ativar venv e atualizar pip
print_step "Atualizando pip..."
venv/bin/pip install --upgrade pip --quiet
validate_command "Atualização do pip"

echo ""

# ═══════════════════════════════════════════════════════════
# ETAPA 3: Instalação de Dependências
# ═══════════════════════════════════════════════════════════
print_step "ETAPA 3: Instalando dependências Python..."

if [ -f "requirements.txt" ]; then
    venv/bin/pip install -r requirements.txt --quiet
    validate_command "Instalação de dependências"
    
    # Verificar instalação do FastAPI
    if venv/bin/python -c "import fastapi" 2>/dev/null; then
        print_success "FastAPI instalado corretamente"
    else
        print_error "Falha na instalação do FastAPI"
        exit 1
    fi
    
    # Verificar instalação do Uvicorn
    if venv/bin/python -c "import uvicorn" 2>/dev/null; then
        print_success "Uvicorn instalado corretamente"
    else
        print_error "Falha na instalação do Uvicorn"
        exit 1
    fi
else
    print_error "Arquivo requirements.txt não encontrado"
    exit 1
fi

echo ""

# ═══════════════════════════════════════════════════════════
# ETAPA 4: Configuração do .env
# ═══════════════════════════════════════════════════════════
print_step "ETAPA 4: Configurando arquivo .env..."

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_success "Arquivo .env criado a partir de .env.example"
        
        # Gerar token seguro
        print_step "Gerando token de autenticação..."
        TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
        
        # Substituir token no .env
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/gerar-um-token-seguro-aqui/$TOKEN/" .env
        else
            # Linux
            sed -i "s/gerar-um-token-seguro-aqui/$TOKEN/" .env
        fi
        
        print_success "Token gerado e configurado"
        echo ""
        print_warning "═══════════════════════════════════════════════════"
        print_warning "  IMPORTANTE: Copie este token para uso nos clientes"
        print_warning "  TOKEN: $TOKEN"
        print_warning "═══════════════════════════════════════════════════"
        echo ""
        
        # Salvar token em arquivo separado para referência
        echo "$TOKEN" > .token
        chmod 600 .token
        print_success "Token salvo em .token (arquivo protegido)"
    else
        print_error "Arquivo .env.example não encontrado"
        exit 1
    fi
else
    print_warning "Arquivo .env já existe, mantendo configuração atual"
    
    # Verificar se tem token configurado
    if grep -q "gerar-um-token-seguro-aqui" .env; then
        print_warning "Token padrão detectado no .env, gerando novo token..."
        TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/gerar-um-token-seguro-aqui/$TOKEN/" .env
        else
            sed -i "s/gerar-um-token-seguro-aqui/$TOKEN/" .env
        fi
        
        print_success "Novo token gerado: $TOKEN"
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════
# ETAPA 5: Teste da Aplicação
# ═══════════════════════════════════════════════════════════
print_step "ETAPA 5: Testando aplicação..."

# Verificar se a aplicação pode ser importada
if venv/bin/python -c "from app.main import app; print('OK')" 2>/dev/null | grep -q "OK"; then
    print_success "Aplicação pode ser importada corretamente"
else
    print_error "Falha ao importar aplicação"
    print_warning "Verifique os logs para mais detalhes"
    exit 1
fi

echo ""

# ═══════════════════════════════════════════════════════════
# ETAPA 6: Configuração do Systemd Service
# ═══════════════════════════════════════════════════════════
print_step "ETAPA 6: Configurando serviço systemd..."

# Criar arquivo de serviço systemd
print_step "Criando arquivo de serviço..."
sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=OTS Hub v2.0 - Oracle Trader WebSocket Hub
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/venv/bin"
ExecStart=$PROJECT_DIR/venv/bin/uvicorn app.main:app --host 0.0.0.0 --port $PORT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

validate_command "Criação do arquivo de serviço"

# Recarregar daemon do systemd
print_step "Recarregando systemd daemon..."
sudo systemctl daemon-reload
validate_command "Reload do systemd daemon"

# Habilitar serviço para iniciar no boot
print_step "Habilitando serviço para iniciar no boot..."
sudo systemctl enable $SERVICE_NAME
validate_command "Habilitação do serviço"

echo ""

# ═══════════════════════════════════════════════════════════
# ETAPA 7: Configuração do Firewall
# ═══════════════════════════════════════════════════════════
print_step "ETAPA 7: Configurando firewall..."

# Verificar UFW
if command -v ufw &>/dev/null; then
    print_step "UFW detectado, configurando..."
    
    # Verificar se UFW está ativo
    if sudo ufw status | grep -q "Status: active"; then
        # Verificar se porta já está aberta
        if ! sudo ufw status | grep -q "$PORT"; then
            sudo ufw allow $PORT/tcp
            validate_command "Abertura da porta $PORT no UFW"
        else
            print_warning "Porta $PORT já está aberta no UFW"
        fi
    else
        print_warning "UFW não está ativo, pulando configuração de firewall"
    fi
elif command -v iptables &>/dev/null; then
    print_step "iptables detectado, configurando..."
    
    # Verificar se regra já existe
    if ! sudo iptables -L INPUT -n | grep -q "dpt:$PORT"; then
        sudo iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
        validate_command "Abertura da porta $PORT no iptables"
        
        # Tentar salvar regras (varia por distro)
        if command -v iptables-save &>/dev/null; then
            sudo iptables-save > /tmp/iptables.rules
            print_success "Regras iptables salvas"
        fi
    else
        print_warning "Porta $PORT já está aberta no iptables"
    fi
else
    print_warning "Nenhum firewall detectado (UFW/iptables)"
fi

echo ""

# ═══════════════════════════════════════════════════════════
# ETAPA 8: Configuração do Cloudflare Tunnel (Opcional)
# ═══════════════════════════════════════════════════════════
print_step "ETAPA 8: Configurando Cloudflare Tunnel (Opcional)..."

# Verificar se cloudflared está instalado
CLOUDFLARE_ENABLED=false
if command -v cloudflared &>/dev/null; then
    print_success "cloudflared encontrado"
    CLOUDFLARE_ENABLED=true
else
    print_warning "cloudflared não encontrado"
    echo ""
    read -p "Deseja instalar e configurar Cloudflare Tunnel? (s/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_step "Instalando cloudflared..."
        
        # Detectar arquitetura
        ARCH=$(uname -m)
        if [ "$ARCH" = "x86_64" ]; then
            CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
        elif [ "$ARCH" = "aarch64" ]; then
            CLOUDFLARED_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
        else
            print_warning "Arquitetura não suportada para instalação automática: $ARCH"
            print_info "Instale manualmente: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation/"
            CLOUDFLARE_ENABLED=false
        fi
        
        if [ -n "$CLOUDFLARED_URL" ]; then
            sudo wget -q "$CLOUDFLARED_URL" -O /usr/local/bin/cloudflared
            sudo chmod +x /usr/local/bin/cloudflared
            
            if command -v cloudflared &>/dev/null; then
                validate_command "Instalação do cloudflared"
                CLOUDFLARE_ENABLED=true
            else
                print_error "Falha na instalação do cloudflared"
                CLOUDFLARE_ENABLED=false
            fi
        fi
    else
        print_info "Pulando instalação do Cloudflare Tunnel"
    fi
fi

# Configurar Cloudflare Tunnel se disponível e Supabase configurado
if [ "$CLOUDFLARE_ENABLED" = true ]; then
    # Verificar se Supabase está configurado
    if grep -q "^SUPABASE_URL=.\+$" .env && grep -q "^SUPABASE_KEY=.\+$" .env; then
        print_step "Configurando serviço Cloudflare Tunnel..."
        
        # Criar arquivo de serviço para Cloudflare Tunnel
        sudo tee /etc/systemd/system/cloudflare-tunnel.service > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel for OTS Hub
After=network.target ots-hub.service
Requires=ots-hub.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=$PROJECT_DIR/.env
ExecStart=/bin/bash $PROJECT_DIR/scripts/cloudflare_tunnel.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        
        validate_command "Criação do serviço Cloudflare Tunnel"
        
        # Recarregar daemon
        sudo systemctl daemon-reload
        
        # Habilitar e iniciar
        sudo systemctl enable cloudflare-tunnel
        print_success "Serviço Cloudflare Tunnel habilitado"
        
        print_info "O Cloudflare Tunnel será iniciado após o OTS Hub"
    else
        print_warning "Supabase não configurado no .env"
        print_info "Configure SUPABASE_URL e SUPABASE_KEY para usar Cloudflare Tunnel"
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════
# ETAPA 9: Iniciar Serviço
# ═══════════════════════════════════════════════════════════
print_step "ETAPA 9: Iniciando serviço..."

# Parar serviço se já estiver rodando
if sudo systemctl is-active --quiet $SERVICE_NAME; then
    print_step "Parando serviço existente..."
    sudo systemctl stop $SERVICE_NAME
    sleep 2
fi

# Iniciar serviço
print_step "Iniciando serviço OTS Hub..."
sudo systemctl start $SERVICE_NAME
sleep 3

# Verificar status
if sudo systemctl is-active --quiet $SERVICE_NAME; then
    print_success "Serviço iniciado com sucesso"
else
    print_error "Falha ao iniciar serviço"
    print_warning "Verifique os logs: sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi

# Iniciar Cloudflare Tunnel se configurado
if [ "$CLOUDFLARE_ENABLED" = true ] && systemctl list-unit-files | grep -q "cloudflare-tunnel.service"; then
    print_step "Iniciando Cloudflare Tunnel..."
    sleep 2
    sudo systemctl start cloudflare-tunnel
    sleep 5
    
    if sudo systemctl is-active --quiet cloudflare-tunnel; then
        print_success "Cloudflare Tunnel iniciado"
        
        # Tentar capturar URL do log
        TUNNEL_URL=$(sudo journalctl -u cloudflare-tunnel -n 50 --no-pager | grep -oP 'https://[a-z0-9-]+\.trycloudflare\.com' | head -1 || echo "")
        
        if [ -n "$TUNNEL_URL" ]; then
            print_success "URL pública do Cloudflare: $TUNNEL_URL"
            echo "  WebSocket: ${TUNNEL_URL/https:/wss:}/ws/{instance_id}"
        else
            print_warning "URL ainda não disponível, aguarde alguns segundos"
            print_info "Verifique com: sudo journalctl -u cloudflare-tunnel -f"
        fi
    else
        print_warning "Cloudflare Tunnel não iniciou"
        print_info "Verifique logs: sudo journalctl -u cloudflare-tunnel -n 50"
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════
# ETAPA 10: Validação Final
# ═══════════════════════════════════════════════════════════
print_step "ETAPA 10: Validando instalação..."

# Aguardar serviço estar pronto
print_step "Aguardando serviço ficar pronto..."
sleep 5

# Testar endpoint de health
print_step "Testando endpoint /health..."
HEALTH_RESPONSE=$(curl -s http://localhost:$PORT/health || echo "FALHOU")

if echo "$HEALTH_RESPONSE" | grep -q "status"; then
    print_success "Endpoint /health respondendo corretamente"
    echo "  Resposta: $HEALTH_RESPONSE"
else
    print_error "Endpoint /health não está respondendo"
    print_warning "Verifique os logs: sudo journalctl -u $SERVICE_NAME -n 50"
    exit 1
fi

# Verificar logs recentes
print_step "Verificando logs recentes..."
if sudo journalctl -u $SERVICE_NAME -n 5 --no-pager | grep -q "Application startup complete"; then
    print_success "Aplicação iniciada corretamente (verificado nos logs)"
else
    print_warning "Não foi possível confirmar inicialização completa nos logs"
fi

echo ""

# ═══════════════════════════════════════════════════════════
# RESUMO FINAL
# ═══════════════════════════════════════════════════════════
echo "══════════════════════════════════════════════════════════"
echo -e "${GREEN}         ✓ Deploy Concluído com Sucesso!${NC}"
echo "══════════════════════════════════════════════════════════"
echo ""
echo -e "${BLUE}Informações do Serviço:${NC}"
echo "  Nome:         $SERVICE_NAME"
echo "  Porta:        $PORT"
echo "  Diretório:    $PROJECT_DIR"
echo "  Status:       $(sudo systemctl is-active $SERVICE_NAME)"
echo ""
echo -e "${BLUE}Comandos Úteis:${NC}"
echo "  Status:       sudo systemctl status $SERVICE_NAME"
echo "  Parar:        sudo systemctl stop $SERVICE_NAME"
echo "  Iniciar:      sudo systemctl start $SERVICE_NAME"
echo "  Reiniciar:    sudo systemctl restart $SERVICE_NAME"
echo "  Logs:         sudo journalctl -u $SERVICE_NAME -f"
echo "  Logs (tail):  sudo journalctl -u $SERVICE_NAME -n 100"
echo ""

if [ "$CLOUDFLARE_ENABLED" = true ] && systemctl list-unit-files | grep -q "cloudflare-tunnel.service"; then
    echo -e "${BLUE}Cloudflare Tunnel:${NC}"
    echo "  Status:       sudo systemctl status cloudflare-tunnel"
    echo "  Logs:         sudo journalctl -u cloudflare-tunnel -f"
    echo "  Reiniciar:    sudo systemctl restart cloudflare-tunnel"
    
    # Tentar obter URL do Supabase se disponível
    if [ -f "$PROJECT_DIR/.env" ]; then
        SUPABASE_URL=$(grep "^SUPABASE_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
        SUPABASE_KEY=$(grep "^SUPABASE_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
        
        if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_KEY" ]; then
            TUNNEL_DATA=$(curl -s "${SUPABASE_URL}/rest/v1/tunnel_config?service_name=eq.ots-hub&select=wss_url" \
                -H "apikey: ${SUPABASE_KEY}" \
                -H "Authorization: Bearer ${SUPABASE_KEY}" 2>/dev/null || echo "")
            
            if [ -n "$TUNNEL_DATA" ]; then
                WSS_URL=$(echo "$TUNNEL_DATA" | grep -oP '"wss_url":"[^"]+' | cut -d'"' -f4)
                if [ -n "$WSS_URL" ] && [ "$WSS_URL" != "pending" ]; then
                    echo "  URL Pública:  $WSS_URL"
                fi
            fi
        fi
    fi
    echo ""
fi

echo -e "${BLUE}Testes:${NC}"
echo "  Health:       curl http://localhost:$PORT/health"
echo "  Root:         curl http://localhost:$PORT/"
echo "  Status:       curl http://localhost:$PORT/api/v1/status"
echo "  Docs:         http://localhost:$PORT/docs"
echo ""

if [ -f ".token" ]; then
    echo -e "${YELLOW}Token de Autenticação:${NC}"
    echo "  $(cat .token)"
    echo "  (também salvo em: $PROJECT_DIR/.token)"
    echo ""
fi

echo -e "${GREEN}Deploy finalizado com sucesso! O OTS Hub está rodando.${NC}"
echo "══════════════════════════════════════════════════════════"
echo ""
