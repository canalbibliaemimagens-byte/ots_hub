# Scripts de Deploy e Controle - OTS Hub v2.0

Este pacote contém dois scripts automatizados para facilitar o deploy e gerenciamento do OTS Hub.

## 📦 Arquivos Incluídos

1. **deploy-ots-hub.sh** - Script de deploy completo
2. **control-ots-hub.sh** - Script de controle e gerenciamento
3. **SCRIPTS_README.md** - Este arquivo

## 🚀 Script 1: Deploy (deploy-ots-hub.sh)

### O que faz

O script de deploy executa uma instalação completa do OTS Hub com validação em cada etapa:

**Etapas executadas:**
1. ✓ Verificação de pré-requisitos (Python, pip, curl, systemd)
2. ✓ Preparação do ambiente (criação de venv)
3. ✓ Instalação de dependências Python
4. ✓ Configuração do arquivo .env com token seguro
5. ✓ Teste da aplicação
6. ✓ Configuração do serviço systemd
7. ✓ Configuração do firewall (UFW/iptables)
8. ✓ Inicialização do serviço
9. ✓ Validação final com testes de conectividade

### Como usar

```bash
# Dar permissão de execução (se necessário)
chmod +x deploy-ots-hub.sh

# Executar o deploy
bash deploy-ots-hub.sh
```

### O que acontece durante o deploy

1. **Verificações automáticas**: O script instala automaticamente qualquer dependência faltante
2. **Token seguro**: Gera automaticamente um token de autenticação seguro e salva em `.token`
3. **Serviço systemd**: Configura o OTS Hub para iniciar automaticamente no boot
4. **Firewall**: Abre a porta 8000 automaticamente
5. **Validação**: Testa todos os endpoints antes de concluir

### Após o deploy

O script mostrará:
- ✓ Token de autenticação gerado
- ✓ Comandos úteis para gerenciar o serviço
- ✓ URLs dos endpoints disponíveis
- ✓ Como verificar logs

**Exemplo de saída:**
```
══════════════════════════════════════════════════════════
         ✓ Deploy Concluído com Sucesso!
══════════════════════════════════════════════════════════

Informações do Serviço:
  Nome:         ots-hub
  Porta:        8000
  Status:       active

Token de Autenticação:
  ABC123...XYZ789
```

## 🎮 Script 2: Controle (control-ots-hub.sh)

### O que faz

Script completo para gerenciar e monitorar o OTS Hub após instalado.

### Comandos disponíveis

```bash
# Modo com comandos diretos
bash control-ots-hub.sh start      # Inicia o serviço
bash control-ots-hub.sh stop       # Para o serviço
bash control-ots-hub.sh restart    # Reinicia o serviço
bash control-ots-hub.sh status     # Mostra status detalhado
bash control-ots-hub.sh logs       # Mostra últimos 100 logs
bash control-ots-hub.sh logs 50    # Mostra últimos 50 logs
bash control-ots-hub.sh logs 100 follow  # Segue logs em tempo real
bash control-ots-hub.sh health     # Executa health check completo
bash control-ots-hub.sh validate   # Valida instalação completa
bash control-ots-hub.sh backup     # Cria backup do projeto
bash control-ots-hub.sh info       # Mostra informações do sistema

# Modo interativo (menu)
bash control-ots-hub.sh
```

### Detalhes dos comandos

#### `start`
- Inicia o serviço OTS Hub
- Verifica se já está rodando
- Valida que o endpoint /health está respondendo
- Mostra status da inicialização

#### `stop`
- Para o serviço OTS Hub de forma limpa
- Verifica se realmente parou

#### `restart`
- Reinicia o serviço
- Útil após mudanças no código ou configuração
- Valida que o serviço voltou online

#### `status`
- Mostra status completo do systemd
- Exibe informações da aplicação (conexões, uptime)
- Mostra uso de recursos (CPU, memória)
- Exibe status detalhado dos WebSockets

#### `logs [linhas] [follow]`
- Exibe logs do serviço
- Parâmetros opcionais:
  - `linhas`: número de linhas (padrão: 100)
  - `follow`: seguir logs em tempo real

Exemplos:
```bash
bash control-ots-hub.sh logs           # Últimas 100 linhas
bash control-ots-hub.sh logs 50        # Últimas 50 linhas
bash control-ots-hub.sh logs 100 follow  # Seguir em tempo real
```

#### `health`
- Executa health check completo
- Verifica:
  - ✓ Serviço systemd está ativo
  - ✓ Porta 8000 está ouvindo
  - ✓ Endpoint /health responde
  - ✓ Endpoint root responde
  - ✓ Informações sobre teste WebSocket

#### `validate`
- Validação completa da instalação
- Verifica:
  1. Arquivos do projeto (main.py, .env, venv)
  2. Serviço systemd configurado e ativo
  3. Dependências Python instaladas
  4. Configuração de firewall
- Reporta todos os problemas encontrados

#### `backup`
- Cria backup completo do projeto
- Exclui arquivos desnecessários (venv, cache, .git)
- Salva em `~/ots_hub_backups/`
- Mostra lista de backups disponíveis

#### `info`
- Exibe informações completas do sistema
- Configurações atuais
- Status do serviço
- Endpoints disponíveis
- Comandos úteis

### Modo Interativo

Execute sem parâmetros para menu interativo:

```bash
bash control-ots-hub.sh
```

Você verá:
```
══════════════════════════════════════════════════════════
         OTS Hub v2.0 - Controle
══════════════════════════════════════════════════════════

Selecione uma opção:

  1) Start      - Iniciar serviço
  2) Stop       - Parar serviço
  3) Restart    - Reiniciar serviço
  4) Status     - Ver status detalhado
  5) Logs       - Ver logs recentes
  6) Health     - Health check completo
  7) Validate   - Validar instalação
  8) Backup     - Criar backup
  9) Info       - Informações do sistema
  0) Sair

Opção:
```

## 📋 Fluxo de Trabalho Recomendado

### Instalação Inicial

```bash
# 1. Deploy inicial
bash deploy-ots-hub.sh

# 2. Verificar se está funcionando
bash control-ots-hub.sh health

# 3. Ver status detalhado
bash control-ots-hub.sh status
```

### Uso Diário

```bash
# Ver se está rodando
bash control-ots-hub.sh status

# Ver logs em tempo real
bash control-ots-hub.sh logs 50 follow

# Reiniciar após mudanças
bash control-ots-hub.sh restart
```

### Resolução de Problemas

```bash
# 1. Validar instalação
bash control-ots-hub.sh validate

# 2. Ver logs recentes
bash control-ots-hub.sh logs 100

# 3. Health check
bash control-ots-hub.sh health

# 4. Reiniciar serviço
bash control-ots-hub.sh restart
```

### Manutenção

```bash
# Criar backup antes de mudanças
bash control-ots-hub.sh backup

# Após mudanças, reiniciar
bash control-ots-hub.sh restart

# Validar que tudo está OK
bash control-ots-hub.sh validate
```

## 🔧 Comandos Systemd Diretos

Se preferir usar comandos systemd diretamente:

```bash
# Iniciar
sudo systemctl start ots-hub

# Parar
sudo systemctl stop ots-hub

# Reiniciar
sudo systemctl restart ots-hub

# Status
sudo systemctl status ots-hub

# Logs
sudo journalctl -u ots-hub -f

# Habilitar no boot
sudo systemctl enable ots-hub

# Desabilitar no boot
sudo systemctl disable ots-hub
```

## 📊 Endpoints Disponíveis

Após o deploy, os seguintes endpoints estarão disponíveis:

### HTTP/REST
- `http://localhost:8000/` - Root (informações básicas)
- `http://localhost:8000/health` - Health check
- `http://localhost:8000/api/v1/status` - Status detalhado
- `http://localhost:8000/docs` - Documentação interativa (Swagger)

### WebSocket
- `ws://localhost:8000/ws/{instance_id}` - Conexão WebSocket

### Testes rápidos

```bash
# Health check
curl http://localhost:8000/health

# Status detalhado
curl http://localhost:8000/api/v1/status

# Informações básicas
curl http://localhost:8000/

# Acessar documentação
# Abra no navegador: http://localhost:8000/docs
```

## 🔐 Segurança

### Token de Autenticação

O script de deploy gera automaticamente um token seguro. Você encontra o token:

1. **Na saída do script de deploy**
2. **No arquivo `.token`** (no diretório do projeto)
3. **No arquivo `.env`** (variável `ORACLE_TOKEN`)

**IMPORTANTE:** 
- Mantenha o token seguro
- Não compartilhe publicamente
- Use o mesmo token em todos os clientes conectados ao Hub

### Regenerar Token

Se precisar gerar um novo token:

```bash
# 1. Gerar novo token
NEW_TOKEN=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")

# 2. Atualizar no .env (no diretório ots_hub)
cd ots_hub
sed -i "s/ORACLE_TOKEN=.*/ORACLE_TOKEN=$NEW_TOKEN/" .env

# 3. Reiniciar serviço
bash ../control-ots-hub.sh restart

# 4. Salvar token
echo $NEW_TOKEN > .token
chmod 600 .token
```

## 🐛 Troubleshooting

### Serviço não inicia

```bash
# 1. Verificar logs
bash control-ots-hub.sh logs 100

# 2. Validar instalação
bash control-ots-hub.sh validate

# 3. Verificar se a porta está em uso
sudo netstat -tlnp | grep 8000
# ou
sudo ss -tlnp | grep 8000

# 4. Tentar iniciar manualmente
cd ots_hub
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Endpoint não responde

```bash
# 1. Verificar se serviço está rodando
bash control-ots-hub.sh status

# 2. Health check
bash control-ots-hub.sh health

# 3. Verificar firewall
sudo ufw status
# ou
sudo iptables -L INPUT -n | grep 8000

# 4. Verificar logs
bash control-ots-hub.sh logs 50 follow
```

### Erro "Permission Denied"

```bash
# Dar permissão aos scripts
chmod +x deploy-ots-hub.sh control-ots-hub.sh

# Se persistir, usar sudo
sudo bash deploy-ots-hub.sh
```

### Problemas com dependências

```bash
# Reinstalar dependências
cd ots_hub
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

## 📝 Logs e Monitoramento

### Localização dos Logs

Os logs são gerenciados pelo systemd/journalctl:

```bash
# Ver logs recentes
sudo journalctl -u ots-hub -n 100

# Seguir logs em tempo real
sudo journalctl -u ots-hub -f

# Logs desde uma data
sudo journalctl -u ots-hub --since "2024-01-01"

# Logs das últimas 2 horas
sudo journalctl -u ots-hub --since "2 hours ago"

# Logs com prioridade específica
sudo journalctl -u ots-hub -p err  # apenas erros
```

### Níveis de Log

O OTS Hub usa os seguintes níveis:
- **DEBUG**: Informações detalhadas (apenas quando DEBUG=True)
- **INFO**: Eventos normais de operação
- **WARNING**: Alertas sobre situações anormais
- **ERROR**: Erros que impedem operações específicas
- **CRITICAL**: Erros graves que afetam todo o sistema

## 🔄 Atualizações

### Atualizar código

```bash
# 1. Fazer backup
bash control-ots-hub.sh backup

# 2. Parar serviço
bash control-ots-hub.sh stop

# 3. Atualizar código (git pull, copiar arquivos, etc)
cd ots_hub
git pull  # se estiver usando git

# 4. Reinstalar dependências (se necessário)
source venv/bin/activate
pip install -r requirements.txt

# 5. Reiniciar serviço
bash ../control-ots-hub.sh start

# 6. Validar
bash ../control-ots-hub.sh validate
```

## 💡 Dicas

1. **Use o modo interativo** quando estiver explorando: `bash control-ots-hub.sh`

2. **Crie backups regulares** antes de mudanças importantes

3. **Monitore os logs** durante operação: `bash control-ots-hub.sh logs 50 follow`

4. **Valide após mudanças**: `bash control-ots-hub.sh validate`

5. **Use health check** periodicamente: `bash control-ots-hub.sh health`

## 📞 Suporte

Se encontrar problemas:

1. Execute a validação: `bash control-ots-hub.sh validate`
2. Verifique os logs: `bash control-ots-hub.sh logs 100`
3. Execute health check: `bash control-ots-hub.sh health`
4. Consulte a documentação do OTS Hub no diretório `docs/`

## 📄 Arquivos Importantes

```
ots_hub/
├── .env              # Configurações (incluindo token)
├── .token            # Token salvo separadamente
├── app/              # Código da aplicação
├── requirements.txt  # Dependências Python
├── venv/            # Virtual environment
└── docs/            # Documentação adicional

/etc/systemd/system/
└── ots-hub.service  # Configuração do serviço

~/ots_hub_backups/   # Backups criados
```

---

**Versão:** 2.0  
**Data:** 2025  
**Scripts criados para:** OTS Hub v2.0 - Oracle Trader System
