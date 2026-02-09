-- OTS Hub — Tunnel config table (for Cloudflare Quick Tunnel)
CREATE TABLE IF NOT EXISTS tunnel_config (
    id SERIAL PRIMARY KEY,
    service_name TEXT UNIQUE NOT NULL,
    ws_url TEXT,
    wss_url TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tunnel_config_service ON tunnel_config(service_name);

ALTER TABLE tunnel_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read" ON tunnel_config FOR SELECT USING (true);
CREATE POLICY "Allow service write" ON tunnel_config FOR ALL USING (true);

INSERT INTO tunnel_config (service_name, ws_url, wss_url)
VALUES ('ots-hub', 'pending', 'pending')
ON CONFLICT (service_name) DO NOTHING;
