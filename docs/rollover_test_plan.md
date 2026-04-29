# Rollover System — Manual Test Plan

## 1. Trigger `process_monthly_rollover()` without waiting a month

The function has an internal guard that exits unless the Bahrain clock shows the 1st of
the month. To test any time, temporarily bypass the guard by calling the inner logic
directly in the Supabase SQL editor:

```sql
-- Step 1: Inspect current state
SELECT id, name, broadcast_limit, rollover_balance
FROM clients
WHERE broadcast_limit IS NOT NULL AND broadcast_limit > 0;

-- Step 2: Call the function (only actually processes on the 1st of month in Bahrain time)
SELECT process_monthly_rollover();

-- Step 3: To force a run on any day, call the logic manually for one client:
DO $$
DECLARE
  prev_month_start TIMESTAMPTZ := DATE_TRUNC('month', NOW() AT TIME ZONE 'Asia/Bahrain' - INTERVAL '1 month') AT TIME ZONE 'Asia/Bahrain';
  prev_month_end   TIMESTAMPTZ := DATE_TRUNC('month', NOW() AT TIME ZONE 'Asia/Bahrain') AT TIME ZONE 'Asia/Bahrain';
  sent_count       BIGINT;
BEGIN
  -- Replace table names with the target client's tables
  SELECT COUNT(*)
  INTO sent_count
  FROM karisma_broadcast_recipients rec
  JOIN karisma_broadcasts bcast ON rec.broadcast_id = bcast.id
  WHERE bcast.sent_at >= prev_month_start
    AND bcast.sent_at <  prev_month_end
    AND rec.status <> 'failed';

  RAISE NOTICE 'Karisma sent last month: %', sent_count;
  RAISE NOTICE 'Window: [%, %)', prev_month_start, prev_month_end;
END$$;
```

## 2. Expected values for Karisma (baseline: 16,624 / 18,000 as of 2026-04-29)

If the month were closed today with sent_count = 16,624:

| Variable | Calculation | Value |
|---|---|---|
| `previous_eff_limit` | 18,000 (base) + 0 (current rollover) | 18,000 |
| `unused` | GREATEST(0, 18,000 − 16,624) | 1,376 |
| `new_rollover` | LEAST(1,376, 18,000) | **1,376** |
| Next month effective limit | 18,000 + 1,376 | **19,376** |

Verify after run:
```sql
SELECT rollover_balance FROM clients WHERE name = 'Karisma';
-- expected: 1376

SELECT * FROM client_quota_history WHERE client_id = '<karisma-uuid>' ORDER BY month DESC LIMIT 1;
-- expected: month=2026-04-01, base_limit=18000, rollover_in=0, sent_count=16624, rollover_out=1376
```

## 3. Edge cases to verify

### 3a. Client with `broadcast_limit = 0` or NULL — should not be touched

```sql
-- Insert a test client with no limit (or use an existing one)
-- After running process_monthly_rollover(), verify:
SELECT rollover_balance FROM clients WHERE broadcast_limit IS NULL OR broadcast_limit = 0;
-- All should remain 0. No rows in client_quota_history for these clients.
SELECT * FROM client_quota_history WHERE client_id IN (
  SELECT id FROM clients WHERE broadcast_limit IS NULL OR broadcast_limit = 0
);
-- Should return 0 rows.
```

### 3b. Client whose `sent_count` exceeds `effective_limit` — rollover should clamp to 0

```sql
-- Simulate: update a test client so sent_count > effective_limit
-- e.g., base=100, rollover_in=50, and the query returns sent_count=200
-- Expected: unused = GREATEST(0, 150 - 200) = 0, new_rollover = LEAST(0, 100) = 0
-- Verify rollover_balance stays 0, not negative.
SELECT rollover_balance FROM clients WHERE id = '<test-client-id>';
-- expected: 0
```

### 3c. Client whose `unused` exceeds 1× cap — rollover should clamp to `broadcast_limit`

```sql
-- Simulate: base=1000, rollover_in=1000 (eff_limit=2000), sent_count=0
-- unused = 2000, new_rollover = LEAST(2000, 1000) = 1000
-- Verify the cap:
SELECT rollover_balance FROM clients WHERE id = '<test-client-id>';
-- expected: 1000 (not 2000)
```

### 3d. First-ever run for a client — `rollover_balance` starts at 0

```sql
-- New client: broadcast_limit=500, rollover_balance=0 (default), sent_count=300
-- previous_eff_limit = 500 + 0 = 500
-- unused = 500 - 300 = 200
-- new_rollover = LEAST(200, 500) = 200
SELECT rollover_balance FROM clients WHERE id = '<new-client-id>';
-- expected: 200
SELECT * FROM client_quota_history WHERE client_id = '<new-client-id>';
-- expected: rollover_in=0, rollover_out=200
```

### 3e. Idempotency — running the cron twice for the same month

```sql
-- ON CONFLICT (client_id, month) DO NOTHING prevents duplicate audit rows.
-- The UPDATE to clients will re-apply the same value (idempotent).
-- Run the function body twice for the same month and verify:
-- 1. client_quota_history has exactly one row per (client_id, month)
-- 2. rollover_balance is unchanged on second run (already set to new_rollover)
```

## 4. Rollback procedure

If the cron runs and produces incorrect rollover values, here is the recovery sequence:

```sql
-- Step 1: Identify the affected month
SELECT * FROM client_quota_history ORDER BY created_at DESC LIMIT 10;

-- Step 2: Revert rollover_balance for affected clients to their rollover_in values
UPDATE clients c
SET rollover_balance = h.rollover_in
FROM client_quota_history h
WHERE c.id = h.client_id
  AND h.month = '2026-04-01';  -- replace with the incorrect month

-- Step 3: Delete the bad audit rows
DELETE FROM client_quota_history WHERE month = '2026-04-01';

-- Step 4: Fix the underlying issue (bad sent_count, wrong table name, etc.)

-- Step 5: Re-run process_monthly_rollover() by temporarily removing the guard
-- or calling the DO block in section 1 above.
```
