-- =============================================================================
-- Migration: broadcast reply_text + payment attribution
-- Date: 2026-04-18
-- Project: zxvjzaowvzvfgrzdimbm (karisma)
-- Run ONCE in Supabase SQL editor. Safe to re-run (IF NOT EXISTS guards).
-- =============================================================================

-- =============================================================================
-- BLOCK 1: Add columns (Item 2 + Item 1)
-- =============================================================================

-- Item 2: store the first customer reply to a broadcast within the 72h window
ALTER TABLE karisma_broadcast_recipients
  ADD COLUMN IF NOT EXISTS reply_text TEXT,
  ADD COLUMN IF NOT EXISTS replied_at TIMESTAMPTZ;

-- Item 1: store per-customer payment amount when "Payment Done" is recorded
ALTER TABLE karisma_broadcast_recipients
  ADD COLUMN IF NOT EXISTS amount_paid NUMERIC,
  ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

-- =============================================================================
-- BLOCK 2: Backfill reply_text from karisma_messages (Item 2)
-- Finds the first inbound customer message within 72h of the broadcast's
-- sent_at for each recipient that hasn't already been backfilled.
-- =============================================================================

UPDATE karisma_broadcast_recipients r
SET
  reply_text = first_reply.customer_message,
  replied_at = first_reply.created_at
FROM karisma_broadcasts b,
LATERAL (
  SELECT m.customer_message, m.created_at
  FROM karisma_messages m
  WHERE m.customer_phone = r.customer_phone
    AND m.customer_message IS NOT NULL
    AND m.customer_message <> ''
    AND m.created_at >= b.sent_at
    AND m.created_at <= b.sent_at + INTERVAL '72 hours'
  ORDER BY m.created_at ASC
  LIMIT 1
) first_reply
WHERE r.broadcast_id = b.id
  AND r.reply_text IS NULL
  AND r.status <> 'failed';

-- =============================================================================
-- BLOCK 3: Trigger — auto-populate reply_text for future inbound messages
-- Fires AFTER INSERT on karisma_messages. Attributes the reply to the most
-- recent broadcast the customer received within the 72h window (last-touch,
-- matching ROI provider logic).
-- =============================================================================

CREATE OR REPLACE FUNCTION populate_broadcast_reply()
RETURNS TRIGGER AS $$
BEGIN
  -- Only process customer (inbound) messages
  IF NEW.customer_message IS NULL OR NEW.customer_message = '' THEN
    RETURN NEW;
  END IF;

  -- Update the most recent eligible broadcast recipient for this phone
  UPDATE karisma_broadcast_recipients r
  SET
    reply_text = NEW.customer_message,
    replied_at = NEW.created_at
  FROM karisma_broadcasts b
  WHERE r.broadcast_id = b.id
    AND r.customer_phone = NEW.customer_phone
    AND r.reply_text IS NULL
    AND r.status <> 'failed'
    AND NEW.created_at >= b.sent_at
    AND NEW.created_at <= b.sent_at + INTERVAL '72 hours'
    AND r.id = (
      -- Pick the most recent eligible recipient row
      SELECT r2.id
      FROM karisma_broadcast_recipients r2
      JOIN karisma_broadcasts b2 ON r2.broadcast_id = b2.id
      WHERE r2.customer_phone = NEW.customer_phone
        AND r2.reply_text IS NULL
        AND r2.status <> 'failed'
        AND NEW.created_at >= b2.sent_at
        AND NEW.created_at <= b2.sent_at + INTERVAL '72 hours'
      ORDER BY b2.sent_at DESC
      LIMIT 1
    );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_populate_broadcast_reply ON karisma_messages;
CREATE TRIGGER trg_populate_broadcast_reply
  AFTER INSERT ON karisma_messages
  FOR EACH ROW
  EXECUTE FUNCTION populate_broadcast_reply();
