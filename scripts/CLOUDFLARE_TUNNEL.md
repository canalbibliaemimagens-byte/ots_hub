# Cloudflare Tunnel - OTS Hub

## 📡 O que é o Cloudflare Tunnel?

O Cloudflare Tunnel permite expor seu servidor OTS Hub à internet sem precisar abrir portas no firewall ou configurar port forwarding. Ele cria um túnel seguro entre seu servidor e a rede Cloudflare.

## 🔄 Como Funciona

1. **Cloudflared** cria um túnel do seu servidor para Cloudflare
2. Cloudflare gera uma **URL pública** (ex: `https://xyz-abc-123.trycloudflare.com`)
3. O script captura essa URL e **salva no Supabase**
4. Clientes leem a URL do Supabase para conectar ao Hub

## ✅ Vantagens

- ✓ Sem necessidade de IP público estático
- ✓ Sem configuração de firewall/router
- ✓ Conexão criptografada automaticamente (HTTPS/WSS)
- ✓ URL atualizada automaticamente no Supabase
- ✓ Funciona em qualquer rede (casa, empresa, cloud)

## 🚀 Configuração Automática

O script de deploy pergunta se você quer instalar o Cloudflare Tunnel. Se você escolher "sim":

1. **Instala cloudflared** automaticamente
2. **Cria serviço systemd** para iniciar com o sistema
3. **Configura integração** com Supabase
4. **Inicia automaticamente** junto com o OTS Hub

### Durante o Deploy

```bash
bash deploy-ots-hub.sh
```

Você verá:
```
═══════════════════════════════════════════════════════════
ETAPA 8: Configurando Cloudflare Tunnel (Opcional)...
═══════════════════════════════════════════════════════════
⚠ cloudflared não encontrado

Deseja instalar e configurar Cloudflare Tunnel? (s/N): s
```

Digite `s` e pressione Enter.

## 🔧 Configuração Manual

Se você pulou durante o deploy, pode instalar manualmente:

### 1. Instalar cloudflared

```bash
# Para x86_64 (amd64)
sudo wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared

# Para ARM64
sudo wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared
sudo chmod +x /usr/local/bin/cloudflared

# Verificar instalação
cloudflared --version
```

### 2. Configurar Supabase no .env

Edite o arquivo `.env` no diretório `ots_hub`:

```bash
cd ots_hub
nano .env
```

Configure:
```env
SUPABASE_URL=https://seu-projeto.supabase.co
SUPABASE_KEY=sua-service-role-key
```

**IMPORTANTE:** Use a **Service Role Key**, não a anon key!

### 3. Criar Serviço Systemd

```bash
# Substitua /caminho/para/ots_hub pelo caminho real
sudo nano /etc/systemd/system/cloudflare-tunnel.service
```

Cole:
```ini
[Unit]
Description=Cloudflare Tunnel for OTS Hub
After=network.target ots-hub.service
Requires=ots-hub.service

[Service]
Type=simple
User=seu-usuario
WorkingDirectory=/caminho/para/ots_hub
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
EnvironmentFile=/caminho/para/ots_hub/.env
ExecStart=/bin/bash /caminho/para/ots_hub/scripts/cloudflare_tunnel.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Substitua `seu-usuario` e `/caminho/para/ots_hub` pelos valores corretos.

### 4. Habilitar e Iniciar

```bash
sudo systemctl daemon-reload
sudo systemctl enable cloudflare-tunnel
sudo systemctl start cloudflare-tunnel
```

## 📊 Verificar Status

### Usando o Script de Controle

```bash
bash control-ots-hub.sh tunnel
```

Você verá:
```
══════════════════════════════════════════════════════════
         Status do Cloudflare Tunnel
══════════════════════════════════════════════════════════

▶ Status do Systemd:
● cloudflare-tunnel.service - Cloudflare Tunnel for OTS Hub
   Active: active (running)
   ...

▶ URL Pública:
  WSS URL:     wss://xyz-abc-123.trycloudflare.com
  WS URL:      ws://xyz-abc-123.trycloudflare.com
  Atualizado:  2025-02-10T12:34:56Z

▶ Logs Recentes:
  ...
```

### Comandos Systemd Diretos

```bash
# Status
sudo systemctl status cloudflare-tunnel

# Logs em tempo real
sudo journalctl -u cloudflare-tunnel -f

# Reiniciar
sudo systemctl restart cloudflare-tunnel

# Parar
sudo systemctl stop cloudflare-tunnel

# Iniciar
sudo systemctl start cloudflare-tunnel
```

## 🔍 Obter URL Pública

### Método 1: Script de Controle

```bash
bash control-ots-hub.sh tunnel
```

### Método 2: Logs

```bash
sudo journalctl -u cloudflare-tunnel -n 50 | grep "https://"
```

### Método 3: Supabase Diretamente

Se você tem acesso ao Supabase Dashboard:

1. Vá para **Table Editor**
2. Abra a tabela `tunnel_config`
3. Procure o registro com `service_name = 'ots-hub'`
4. A URL está no campo `wss_url`

### Método 4: API do Supabase

```bash
# Configure estas variáveis
SUPABASE_URL="https://seu-projeto.supabase.co"
SUPABASE_KEY="sua-service-role-key"

# Obter URL
curl -s "${SUPABASE_URL}/rest/v1/tunnel_config?service_name=eq.ots-hub&select=wss_url" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}"
```

Resposta:
```json
[{"wss_url":"wss://xyz-abc-123.trycloudflare.com"}]
```

## 🔐 Como os Clientes Usam

Os clientes (Connector, Preditor, Executor, Dashboard) devem:

1. **Ler a URL do Supabase** na tabela `tunnel_config`
2. **Conectar usando WSS** (WebSocket Secure)

Exemplo de conexão:
```
wss://xyz-abc-123.trycloudflare.com/ws/instance-id
```

## 🔄 Atualização Automática da URL

**IMPORTANTE:** A URL do Cloudflare Tunnel pode mudar quando:
- O serviço é reiniciado
- O servidor é reiniciado
- Há uma desconexão temporária

O script atualiza automaticamente a URL no Supabase sempre que ela muda, então os clientes sempre terão a URL mais recente.

## 🐛 Troubleshooting

### Tunnel não inicia

```bash
# 1. Verificar logs
sudo journalctl -u cloudflare-tunnel -n 100

# 2. Verificar se cloudflared está instalado
which cloudflared
cloudflared --version

# 3. Verificar se OTS Hub está rodando
sudo systemctl status ots-hub

# 4. Testar manualmente
cd ots_hub
source venv/bin/activate
cloudflared tunnel --url http://localhost:8000
```

### URL não aparece no Supabase

```bash
# 1. Verificar logs do tunnel
sudo journalctl -u cloudflare-tunnel -n 50

# 2. Verificar configuração do Supabase no .env
cd ots_hub
cat .env | grep SUPABASE

# 3. Verificar se o script está rodando
ps aux | grep cloudflare_tunnel.sh

# 4. Testar conexão com Supabase
curl "${SUPABASE_URL}/rest/v1/tunnel_config?select=*" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}"
```

### URL muda constantemente

Isso é normal para o Quick Tunnel gratuito do Cloudflare. Para uma URL permanente:

1. Crie uma conta no Cloudflare Zero Trust
2. Configure um Tunnel nomeado
3. Atualize o script `cloudflare_tunnel.sh` para usar seu tunnel

### Clientes não conseguem conectar

```bash
# 1. Verificar se URL está acessível
curl -I https://sua-url.trycloudflare.com/health

# 2. Verificar logs do Hub
sudo journalctl -u ots-hub -f

# 3. Verificar se porta local está respondendo
curl http://localhost:8000/health

# 4. Reiniciar ambos os serviços
sudo systemctl restart ots-hub
sudo systemctl restart cloudflare-tunnel
```

## 📝 Estrutura de Dados no Supabase

A tabela `tunnel_config` tem esta estrutura:

```sql
CREATE TABLE tunnel_config (
    id SERIAL PRIMARY KEY,
    service_name TEXT UNIQUE NOT NULL,
    ws_url TEXT,
    wss_url TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

Exemplo de registro:
```json
{
  "id": 1,
  "service_name": "ots-hub",
  "ws_url": "ws://xyz-abc-123.trycloudflare.com",
  "wss_url": "wss://xyz-abc-123.trycloudflare.com",
  "updated_at": "2025-02-10T12:34:56.789Z"
}
```

## 🔒 Segurança

### Service Role Key vs Anon Key

**IMPORTANTE:** O script precisa da **Service Role Key** porque:
- Precisa fazer UPSERT (insert/update)
- Precisa atualizar registros existentes
- A anon key tem permissões limitadas

A Service Role Key deve ser mantida **PRIVADA** e nunca compartilhada publicamente.

### Políticas RLS (Row Level Security)

O Supabase tem políticas configuradas para:
- **Leitura pública**: Qualquer um pode ler a URL (necessário para clientes)
- **Escrita com service key**: Apenas o serviço pode atualizar

```sql
-- Políticas configuradas
CREATE POLICY "Allow public read" ON tunnel_config FOR SELECT USING (true);
CREATE POLICY "Allow service write" ON tunnel_config FOR ALL USING (true);
```

## 🎯 Fluxo Completo

```
1. OTS Hub inicia
   ↓
2. Cloudflare Tunnel inicia (após Hub)
   ↓
3. Cloudflare gera URL pública
   ↓
4. Script captura URL dos logs
   ↓
5. Script faz UPSERT no Supabase
   ↓
6. URL disponível em tunnel_config
   ↓
7. Clientes leem URL do Supabase
   ↓
8. Clientes conectam via WSS
```

## 📞 Suporte

Se tiver problemas:

1. Execute: `bash control-ots-hub.sh tunnel`
2. Verifique logs: `sudo journalctl -u cloudflare-tunnel -f`
3. Teste manualmente: `cloudflared tunnel --url http://localhost:8000`
4. Verifique Supabase: acesse a tabela `tunnel_config`

## 🔗 Links Úteis

- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Quick Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/do-more-with-tunnels/trycloudflare/)
- [Supabase Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

---

**Nota:** O Quick Tunnel é gratuito mas a URL muda a cada reinicialização. Para URL permanente, considere criar um Tunnel nomeado no Cloudflare Zero Trust (também gratuito para uso pessoal).
