# Deploy — OTS Hub

## Oracle Cloud (Always Free E2.1)

```bash
ssh -i ~/.ssh/oracle_key ubuntu@<IP>

# Upload
scp -r ots_hub/ ubuntu@<IP>:~/

# Setup automatizado
cd ~/ots_hub
bash deploy/setup.sh
```

## Comandos

```bash
sudo systemctl status ots-hub
sudo systemctl restart ots-hub
sudo journalctl -u ots-hub -f
curl http://localhost:8000/health
```

## Abrir porta no OCI

Security List → Add Ingress Rule:
- Source: `0.0.0.0/0`
- Protocol: TCP
- Port: `8000`

Firewall local:
```bash
sudo iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
```

## Atualizar

```bash
cd ~/ots_hub
# Substituir arquivos
source venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart ots-hub
```
