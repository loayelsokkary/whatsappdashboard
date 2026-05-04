-- =============================================================================
-- Migration: broadcast analytics aggregation RPC
-- Date: 2026-04-30
-- Project: zxvjzaowvzvfgrzdimbm (karisma)
-- Run ONCE in Supabase SQL editor. Safe to re-run (CREATE OR REPLACE guard).
--
-- This migration creates ONE function. It performs no DDL on any table.
-- No columns are added, no data is modified, no existing objects are dropped.
--
-- get_broadcast_analytics_aggregates(p_recipients_table, p_broadcasts_table)
--   Called by BroadcastAnalyticsProvider.fetchAnalytics() to replace a full
--   paginated recipient table dump with a single server-side GROUP BY.
--   Returns one row per broadcast_id plus one global summary row
--   (broadcast_id IS NULL). Caller handles empty results gracefully (zeros).
-- =============================================================================

CREATE OR REPLACE FUNCTION get_broadcast_analytics_aggregates(
  p_recipients_table text,
  p_broadcasts_table text
)
RETURNS TABLE (
  broadcast_id  uuid,
  recipients    bigint,
  delivered     bigint,   -- status IS DISTINCT FROM 'failed' (includes 'read')
  read          bigint,   -- status = 'read'
  failed        bigint    -- status = 'failed'
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  table_exists boolean;
  dyn_sql      text;
BEGIN
  -- Verify both tables exist before querying (matches process_monthly_rollover pattern).
  -- Returns empty result set on missing tables so the caller can show zeros
  -- rather than surfacing a DB error to the UI.
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN (p_recipients_table, p_broadcasts_table)
    GROUP BY ()
    HAVING COUNT(*) = 2
  ) INTO table_exists;

  IF NOT table_exists THEN
    RAISE NOTICE
      'get_broadcast_analytics_aggregates: tables (%, %) not found, returning empty',
      p_recipients_table, p_broadcasts_table;
    RETURN;
  END IF;

  -- Per-broadcast aggregates UNION ALL one global summary row (broadcast_id = NULL).
  -- FORMAT(%I) quotes identifiers safely against injection.
  -- delivered = everything that is not 'failed' (intentionally includes 'read').
  dyn_sql := FORMAT(
    'SELECT
       broadcast_id,
       COUNT(*)                                                          AS recipients,
       COUNT(*) FILTER (WHERE status IS DISTINCT FROM ''failed'')       AS delivered,
       COUNT(*) FILTER (WHERE status = ''read'')                        AS read,
       COUNT(*) FILTER (WHERE status = ''failed'')                      AS failed
     FROM %I
     GROUP BY broadcast_id

     UNION ALL

     SELECT
       NULL::uuid                                                        AS broadcast_id,
       COUNT(*)                                                          AS recipients,
       COUNT(*) FILTER (WHERE status IS DISTINCT FROM ''failed'')       AS delivered,
       COUNT(*) FILTER (WHERE status = ''read'')                        AS read,
       COUNT(*) FILTER (WHERE status = ''failed'')                      AS failed
     FROM %I',
    p_recipients_table,
    p_recipients_table
  );

  RETURN QUERY EXECUTE dyn_sql;
END;
$$;

-- =============================================================================
-- Permissions: service_role only (matches process_monthly_rollover pattern).
-- Postgres grants EXECUTE to PUBLIC by default for new functions —
-- the REVOKE lines below lock that down explicitly.
-- =============================================================================

GRANT EXECUTE ON FUNCTION get_broadcast_analytics_aggregates(text, text) TO service_role;
REVOKE EXECUTE ON FUNCTION get_broadcast_analytics_aggregates(text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION get_broadcast_analytics_aggregates(text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION get_broadcast_analytics_aggregates(text, text) FROM authenticated;

-- =============================================================================
-- After running this migration, verify correctness with these queries
-- in the Supabase SQL editor before deploying the Dart change (Phase 2).
--
-- Step 1 — Raw RPC output (N+1 rows: one per broadcast_id + one global NULL row):
--   SELECT * FROM get_broadcast_analytics_aggregates(
--     'karisma_broadcast_recipients', 'karisma_broadcasts'
--   ) ORDER BY broadcast_id NULLS LAST;
--
-- Step 2 — Global row against ground truth
--   (expected: recipients=26168, delivered=23099, read=11667, failed=3069):
--   SELECT * FROM get_broadcast_analytics_aggregates(
--     'karisma_broadcast_recipients', 'karisma_broadcasts'
--   ) WHERE broadcast_id IS NULL;
--
-- Step 3 — Computed rates
--   (expected: delivery_rate_pct=88.27, read_rate_pct=50.51):
--   SELECT
--     delivered, read, failed, recipients,
--     ROUND(delivered::numeric / NULLIF(recipients, 0) * 100, 2) AS delivery_rate_pct,
--     ROUND(read::numeric      / NULLIF(delivered,  0) * 100, 2) AS read_rate_pct
--   FROM get_broadcast_analytics_aggregates(
--     'karisma_broadcast_recipients', 'karisma_broadcasts'
--   ) WHERE broadcast_id IS NULL;
--
-- Step 4 — Per-campaign rows for top 5 most recent broadcasts:
--   SELECT agg.broadcast_id, b.campaign_name, b.sent_at,
--          agg.recipients, agg.delivered, agg.read, agg.failed
--   FROM get_broadcast_analytics_aggregates(
--     'karisma_broadcast_recipients', 'karisma_broadcasts'
--   ) agg
--   JOIN karisma_broadcasts b ON b.id = agg.broadcast_id
--   WHERE agg.broadcast_id IS NOT NULL
--   ORDER BY b.sent_at DESC LIMIT 5;
--
-- Step 5 — Cross-check Step 4 against direct SQL (numbers must be identical):
--   SELECT rec.broadcast_id, b.campaign_name, b.sent_at,
--          COUNT(*) AS recipients,
--          COUNT(*) FILTER (WHERE rec.status IS DISTINCT FROM 'failed') AS delivered,
--          COUNT(*) FILTER (WHERE rec.status = 'read')   AS read,
--          COUNT(*) FILTER (WHERE rec.status = 'failed') AS failed
--   FROM karisma_broadcast_recipients rec
--   JOIN karisma_broadcasts b ON b.id = rec.broadcast_id
--   WHERE rec.broadcast_id IN (
--     SELECT id FROM karisma_broadcasts ORDER BY sent_at DESC LIMIT 5
--   )
--   GROUP BY rec.broadcast_id, b.campaign_name, b.sent_at
--   ORDER BY b.sent_at DESC;
-- =============================================================================
