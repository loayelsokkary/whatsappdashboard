-- =============================================================================
-- Migration: monthly broadcast quota rollover
-- Date: 2026-04-29
-- Project: zxvjzaowvzvfgrzdimbm (karisma)
-- Run ONCE in Supabase SQL editor. Safe to re-run (IF NOT EXISTS / OR REPLACE guards).
--
-- process_monthly_rollover() is triggered manually or by any external
-- scheduler. Run SELECT process_monthly_rollover(); on the 1st of each
-- month at 00:05 Asia/Bahrain (or close to it). It requires no arguments.
-- =============================================================================

-- =============================================================================
-- BLOCK 1: Add rollover_balance column to clients
-- =============================================================================

ALTER TABLE clients
  ADD COLUMN IF NOT EXISTS rollover_balance INT NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'rollover_balance_non_negative'
  ) THEN
    ALTER TABLE clients
      ADD CONSTRAINT rollover_balance_non_negative CHECK (rollover_balance >= 0);
  END IF;
END$$;

-- =============================================================================
-- BLOCK 2: Audit table — one row per client per month
-- =============================================================================

CREATE TABLE IF NOT EXISTS client_quota_history (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id    UUID        NOT NULL REFERENCES clients(id),
  month        DATE        NOT NULL,   -- first day of the closed month (e.g. 2026-04-01)
  base_limit   INT         NOT NULL,
  rollover_in  INT         NOT NULL DEFAULT 0,  -- rollover_balance at the start of this month
  sent_count   BIGINT      NOT NULL DEFAULT 0,
  rollover_out INT         NOT NULL DEFAULT 0,  -- new rollover_balance after this month closes
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (client_id, month)
);

-- =============================================================================
-- BLOCK 3: RLS on client_quota_history
-- Only SELECT is granted to the client role; writes come exclusively from the
-- SECURITY DEFINER function below (which bypasses RLS).
-- =============================================================================

ALTER TABLE client_quota_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "allow_read_client_quota_history" ON client_quota_history;
CREATE POLICY "allow_read_client_quota_history"
  ON client_quota_history
  FOR SELECT
  USING (true);

-- =============================================================================
-- BLOCK 4: process_monthly_rollover()
--
-- Closes out the previous calendar month (Asia/Bahrain timezone) for every
-- client that has broadcast_limit > 0.  Computes unused capacity, caps it at
-- 1× the base limit, and writes the new rollover_balance back to clients.
--
-- Called externally — either manually via SQL editor or by an external scheduler.
-- Running it on the wrong day is safe — the guard exits immediately unless
-- it is actually the 1st of the month in Bahrain time.
-- =============================================================================

CREATE OR REPLACE FUNCTION process_monthly_rollover()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  -- Bahrain wall-clock time (TIMESTAMP, no tz)
  bahrain_now        TIMESTAMP  := NOW() AT TIME ZONE 'Asia/Bahrain';

  -- Previous-month window expressed as UTC TIMESTAMPTZ for DB comparisons
  prev_month_end_l   TIMESTAMP;   -- local Bahrain TIMESTAMP for month arithmetic
  prev_month_start_l TIMESTAMP;
  prev_month_start   TIMESTAMPTZ;
  prev_month_end     TIMESTAMPTZ;
  prev_month_date    DATE;

  -- Per-client working variables
  r                  clients%ROWTYPE;
  sent_count         BIGINT;
  previous_eff_limit BIGINT;
  unused             BIGINT;
  new_rollover       BIGINT;
  dyn_sql            TEXT;
  table_exists       BOOLEAN;
BEGIN
  -- ── Guard ──────────────────────────────────────────────────────────────────
  -- This function is called externally on or shortly after the 1st of each
  -- month in Asia/Bahrain time. The guard makes calls on other days a safe no-op.
  IF EXTRACT(DAY FROM bahrain_now) != 1 THEN
    RAISE NOTICE 'process_monthly_rollover: Bahrain day=%, not the 1st. Exiting.',
      EXTRACT(DAY FROM bahrain_now);
    RETURN;
  END IF;

  -- ── Month boundaries ──────────────────────────────────────────────────────
  -- Do all calendar arithmetic on the Bahrain-local TIMESTAMP, then convert
  -- to UTC TIMESTAMPTZ for querying sent_at (which is stored as UTC).
  prev_month_end_l   := DATE_TRUNC('month', bahrain_now);             -- e.g. 2026-05-01 00:00:00 Bahrain
  prev_month_start_l := prev_month_end_l - INTERVAL '1 month';       -- e.g. 2026-04-01 00:00:00 Bahrain

  prev_month_start   := prev_month_start_l AT TIME ZONE 'Asia/Bahrain'; -- → 2026-03-31 21:00:00 UTC
  prev_month_end     := prev_month_end_l   AT TIME ZONE 'Asia/Bahrain'; -- → 2026-04-30 21:00:00 UTC
  prev_month_date    := prev_month_start_l::date;                     -- e.g. 2026-04-01 (audit key)

  RAISE NOTICE 'process_monthly_rollover: closing month %, window [%, %)',
    prev_month_date, prev_month_start, prev_month_end;

  -- ── Per-client loop ────────────────────────────────────────────────────────
  FOR r IN
    SELECT * FROM clients
    WHERE broadcast_limit IS NOT NULL AND broadcast_limit > 0
    ORDER BY name
  LOOP
    -- Skip clients whose table names are not configured
    IF r.broadcasts_table IS NULL OR r.broadcast_recipients_table IS NULL THEN
      RAISE NOTICE 'Skipping client "%" (id=%): missing table config', r.name, r.id;
      CONTINUE;
    END IF;

    -- Verify both tables actually exist before trying to query them. This
    -- handles legacy clients (HOB, Vivid Demo) whose clients row points to
    -- tables that don't exist yet.
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name IN (r.broadcasts_table, r.broadcast_recipients_table)
      GROUP BY ()
      HAVING COUNT(*) = 2
    ) INTO table_exists;

    IF NOT table_exists THEN
      RAISE NOTICE 'Skipping client "%" (id=%): one or both configured tables (%, %) do not exist',
        r.name, r.id, r.broadcasts_table, r.broadcast_recipients_table;
      CONTINUE;
    END IF;

    -- Count non-failed recipients for this client's broadcasts in the previous month
    dyn_sql := FORMAT(
      'SELECT COUNT(*)
       FROM %I rec
       JOIN %I bcast ON rec.broadcast_id = bcast.id
       WHERE bcast.sent_at >= $1
         AND bcast.sent_at <  $2
         AND rec.status <> ''failed''',
      r.broadcast_recipients_table,
      r.broadcasts_table
    );
    EXECUTE dyn_sql INTO sent_count USING prev_month_start, prev_month_end;
    sent_count := COALESCE(sent_count, 0);

    -- Effective limit = base + rollover that was available at the start of this month
    previous_eff_limit := COALESCE(r.broadcast_limit, 0) + COALESCE(r.rollover_balance, 0);

    -- Unused capacity (clamp to 0 — can't go negative even if over-sent)
    unused := GREATEST(0, previous_eff_limit - sent_count);

    -- New rollover is capped at 1× base limit
    new_rollover := LEAST(unused, r.broadcast_limit);

    -- Write audit row (ON CONFLICT: skip if this month was already processed)
    INSERT INTO client_quota_history
      (id, client_id, month, base_limit, rollover_in, sent_count, rollover_out, created_at)
    VALUES
      (gen_random_uuid(), r.id, prev_month_date,
       r.broadcast_limit, r.rollover_balance, sent_count, new_rollover, NOW())
    ON CONFLICT (client_id, month) DO NOTHING;

    -- Update rollover_balance on the client row
    UPDATE clients
    SET rollover_balance = new_rollover
    WHERE id = r.id;

    RAISE NOTICE 'Client "%": sent=%, eff_limit=%, unused=%, new_rollover=%',
      r.name, sent_count, previous_eff_limit, unused, new_rollover;
  END LOOP;

  RAISE NOTICE 'process_monthly_rollover: complete.';
END;
$$;

-- =============================================================================
-- BLOCK 5: Grant execute to service_role
-- Any external caller using the Supabase service role key can invoke this function.
-- =============================================================================

GRANT EXECUTE ON FUNCTION process_monthly_rollover() TO service_role;

-- Lock down execute permissions — SECURITY DEFINER functions should only be
-- callable by service_role. Postgres grants EXECUTE to PUBLIC by default.
REVOKE EXECUTE ON FUNCTION process_monthly_rollover() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION process_monthly_rollover() FROM anon;
REVOKE EXECUTE ON FUNCTION process_monthly_rollover() FROM authenticated;
