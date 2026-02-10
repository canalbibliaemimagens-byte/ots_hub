-- ============================================================================
-- 🧹 SCRIPT DE LIMPEZA - LEGADO (V2/CSV Workflows)
-- ============================================================================
-- ⚠️ ATENÇÃO: Execute este script APENAS após verificar que a migração para V3
-- foi bem sucedida e que você não precisa mais dos dados antigos.
-- ============================================================================

-- 1. Remover Views Legadas (baseadas em modelos antigos)
DROP VIEW IF EXISTS v_hmm_performance;
DROP VIEW IF EXISTS v_hourly_performance;
DROP VIEW IF EXISTS v_symbol_summary;

-- 2. Remover Tabelas de Importação CSV (não utilizadas na V3)
DROP TABLE IF EXISTS csv_file_metadata;
DROP TABLE IF EXISTS csv_files_summary;
DROP TABLE IF EXISTS csv_storage_stats;

-- ============================================================================
-- 3. Tabelas de Histórico Antigo (OPCIONAL)
-- Descomente as linhas abaixo se quiser limpar o histórico da V2 também.
-- Mantenha se quiser usar para auditoria ou comparação.
-- ============================================================================

-- DROP TABLE IF EXISTS cycles;
-- DROP TABLE IF EXISTS events;
-- DROP TABLE IF EXISTS sessions;

-- ⚠️ 'trades' e 'telemetry' podem conter dados úteis para histórico.
-- Avalie antes de apagar.
-- DROP TABLE IF EXISTS trades;
-- DROP TABLE IF EXISTS telemetry;

-- ============================================================================
-- 4. Tabelas CRÍTICAS (NÃO APAGAR)
-- ============================================================================
-- tunnel_config -> Usada pelo Cloudflare Tunnel (Manter!)
