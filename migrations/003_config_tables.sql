-- OTS Hub — Tabelas de Configuração Centralizada
-- Versão alinhada com oracle_trader_v3/docs/supabase_schema.sql
--
-- NOTA: Se você já executou o supabase_schema.sql no SQL Editor do Supabase,
-- este arquivo não recriará as tabelas (usa CREATE TABLE IF NOT EXISTS).
-- Este arquivo é alternativo/equivalente ao supabase_schema.sql para ambientes
-- onde o schema ainda não foi aplicado.
--
-- Ordem de execução recomendada:
--   1. Use docs/supabase_schema.sql via Supabase Dashboard (preferido)
--   2. OU use este arquivo se preferir migrations versionadas
--   NÃO execute os dois - use apenas um.

-- ============================================================================
-- 1. OTS Hub Configuration
-- ============================================================================
CREATE TABLE IF NOT EXISTS ots_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ots_config_key ON ots_config(key);
ALTER TABLE ots_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for components" ON ots_config FOR ALL USING (true) WITH CHECK (true);

INSERT INTO ots_config (key, value, description) VALUES
    ('hub_url', 'ws://localhost:8000', 'URL do Hub WebSocket'),
    ('oracle_token', 'change-me-in-production', 'Token de autenticação compartilhado'),
    ('allowed_origins', '*', 'CORS allowed origins (separados por vírgula)'),
    ('host', '0.0.0.0', 'Host do servidor Hub'),
    ('port', '8000', 'Porta do servidor Hub'),
    ('debug', 'false', 'Modo debug (true/false)'),
    ('auth_timeout', '5', 'Timeout de autenticação em segundos'),
    ('telemetry_interval_min', '10', 'Intervalo de telemetria em minutos')
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- 2. Trading Symbols
-- ============================================================================
CREATE TABLE IF NOT EXISTS trading_symbols (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    symbol TEXT UNIQUE NOT NULL,
    enabled BOOLEAN DEFAULT true,
    lot_weak DECIMAL(10, 4) DEFAULT 0.01,
    lot_moderate DECIMAL(10, 4) DEFAULT 0.03,
    lot_strong DECIMAL(10, 4) DEFAULT 0.05,
    sl_usd DECIMAL(10, 2) DEFAULT 10.00,
    tp_usd DECIMAL(10, 2) DEFAULT 0.00,
    max_spread_pips DECIMAL(10, 2) DEFAULT 2.0,
    category TEXT DEFAULT 'forex',
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trading_symbols_enabled ON trading_symbols(enabled);
ALTER TABLE trading_symbols ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for components" ON trading_symbols FOR ALL USING (true) WITH CHECK (true);

INSERT INTO trading_symbols (symbol, enabled, lot_weak, lot_moderate, lot_strong, sl_usd, tp_usd, max_spread_pips, category) VALUES
    ('EURUSD', true, 0.01, 0.03, 0.05, 10.00, 0.00, 2.0, 'forex'),
    ('GBPUSD', true, 0.01, 0.03, 0.05, 10.00, 0.00, 2.0, 'forex'),
    ('USDJPY', true, 0.01, 0.03, 0.05, 10.00, 0.00, 2.0, 'forex'),
    ('XAUUSD', true, 0.01, 0.02, 0.03, 15.00, 0.00, 3.0, 'commodities')
ON CONFLICT (symbol) DO NOTHING;

-- ============================================================================
-- 3. Risk Config
-- ============================================================================
CREATE TABLE IF NOT EXISTS risk_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_name TEXT UNIQUE NOT NULL DEFAULT 'default',
    max_drawdown_pct DECIMAL(5, 2) DEFAULT 10.00,
    max_daily_loss_usd DECIMAL(10, 2) DEFAULT 100.00,
    max_consecutive_losses INTEGER DEFAULT 5,
    pause_after_losses BOOLEAN DEFAULT true,
    max_positions INTEGER DEFAULT 5,
    max_exposure_per_symbol_pct DECIMAL(5, 2) DEFAULT 20.00,
    trading_hours_start TIME,
    trading_hours_end TIME,
    active BOOLEAN DEFAULT true,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE risk_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for components" ON risk_config FOR ALL USING (true) WITH CHECK (true);

INSERT INTO risk_config (profile_name, max_drawdown_pct, max_daily_loss_usd, max_consecutive_losses, max_positions) VALUES
    ('default', 10.00, 100.00, 5, 5),
    ('conservative', 5.00, 50.00, 3, 3),
    ('aggressive', 20.00, 200.00, 10, 10)
ON CONFLICT (profile_name) DO NOTHING;

-- ============================================================================
-- 4. Connector Config
-- ============================================================================
CREATE TABLE IF NOT EXISTS connector_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    connector_type TEXT NOT NULL,
    instance_id TEXT UNIQUE NOT NULL,
    client_id TEXT,
    client_secret TEXT,
    access_token TEXT,
    account_id TEXT,
    environment TEXT DEFAULT 'demo',
    symbols TEXT[],
    timeframe TEXT DEFAULT 'M15',
    warmup_bars INTEGER DEFAULT 1000,
    account_update_interval INTEGER DEFAULT 10,
    enabled BOOLEAN DEFAULT true,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_connector_config_type ON connector_config(connector_type);
ALTER TABLE connector_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for components" ON connector_config FOR ALL USING (true) WITH CHECK (true);

-- ============================================================================
-- 5. Executor Config
-- ============================================================================
CREATE TABLE IF NOT EXISTS executor_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id TEXT UNIQUE NOT NULL,
    risk_profile TEXT DEFAULT 'default',
    enabled_symbols TEXT[],
    max_orders_per_minute INTEGER DEFAULT 10,
    enabled BOOLEAN DEFAULT true,
    paused BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE executor_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for components" ON executor_config FOR ALL USING (true) WITH CHECK (true);

-- ============================================================================
-- 6. Trading Models (para multi-model suporte)
-- ============================================================================
CREATE TABLE IF NOT EXISTS trading_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT UNIQUE NOT NULL,
    symbol TEXT NOT NULL,
    timeframe TEXT NOT NULL,
    version TEXT DEFAULT '1.0',
    storage_bucket TEXT DEFAULT 'oracle_models',
    storage_path TEXT,
    model_path TEXT,
    min_bars INTEGER DEFAULT 350,
    warmup_bars INTEGER DEFAULT 1000,
    training_date TIMESTAMPTZ,
    accuracy DECIMAL(5, 2),
    sharpe_ratio DECIMAL(5, 2),
    hmm_config JSONB,
    rl_config JSONB,
    active BOOLEAN DEFAULT true,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trading_models_symbol ON trading_models(symbol);
CREATE INDEX IF NOT EXISTS idx_trading_models_active ON trading_models(active);
ALTER TABLE trading_models ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for components" ON trading_models FOR ALL USING (true) WITH CHECK (true);

-- ============================================================================
-- 7. Preditor Config
-- ============================================================================
CREATE TABLE IF NOT EXISTS preditor_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instance_id TEXT UNIQUE NOT NULL,
    model_id UUID REFERENCES trading_models(id),
    min_bars INTEGER DEFAULT 350,
    warmup_bars INTEGER DEFAULT 1000,
    enabled BOOLEAN DEFAULT true,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE preditor_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all for components" ON preditor_config FOR ALL USING (true) WITH CHECK (true);

-- ============================================================================
-- 8. Update Triggers
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_ots_config_updated_at BEFORE UPDATE ON ots_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_trading_symbols_updated_at BEFORE UPDATE ON trading_symbols
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_risk_config_updated_at BEFORE UPDATE ON risk_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_connector_config_updated_at BEFORE UPDATE ON connector_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_executor_config_updated_at BEFORE UPDATE ON executor_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_trading_models_updated_at BEFORE UPDATE ON trading_models
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_preditor_config_updated_at BEFORE UPDATE ON preditor_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- SCHEMA COMPLETO — Execute popular com: python scripts/populate_supabase_config.py
-- ============================================================================
