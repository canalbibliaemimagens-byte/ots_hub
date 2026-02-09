#!/bin/bash
# OTS Hub — Deploy Script (Oracle Cloud E2.1)
set -e

echo "══════════════════════════════════"
echo "  OTS Hub v2.0 — Setup"
echo "══════════════════════════════════"

# 1. Python venv
if [ ! -d "venv" ]; then
    echo "→ Criando venv..."
    python3 -m venv venv
fi

echo "→ Instalando dependências..."
venv/bin/pip install --upgrade pip -q
venv/bin/pip install -r requirements.txt -q

# 2. .env
if [ ! -f ".env" ]; then
    echo "→ Criando .env..."
    cp .env.example .env
    TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    sed -i "s/gerar-um-token-seguro-aqui/$TOKEN/" .env
    echo "⚠️  Token gerado: $TOKEN"
    echo "⚠️  COPIE ESTE TOKEN para os processos Oracle Trader v3!"
else
    echo "→ .env já existe, mantendo..."
fi

# 3. Systemd
echo "→ Configurando systemd service..."
sudo cp deploy/ots-hub.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ots-hub
sudo systemctl restart ots-hub

echo ""
echo "══════════════════════════════════"
echo "  ✅ Deploy completo!"
echo "══════════════════════════════════"
echo ""
echo "  Status: sudo systemctl status ots-hub"
echo "  Logs:   sudo journalctl -u ots-hub -f"
echo "  Test:   curl http://localhost:8000/health"
echo ""

# 4. Firewall
if command -v iptables &>/dev/null; then
    if ! sudo iptables -L INPUT -n | grep -q "8000"; then
        sudo iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
        echo "  iptables: porta 8000 aberta"
    fi
fi
