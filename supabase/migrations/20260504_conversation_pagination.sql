-- =============================================================================
-- Migration: conversation pagination support
-- Date: 2026-05-04
-- Project: zxvjzaowvzvfgrzdimbm (karisma)
-- Run ONCE in Supabase SQL editor. Safe to re-run (CREATE OR REPLACE / IF NOT EXISTS).
--
-- This migration creates:
--   1. idx_karisma_messages_phone_agg — composite index for GROUP BY aggregation
--   2. get_latest_customer_phones(p_ai_phone, p_limit, p_offset)
--   3. get_conversation_count(p_ai_phone)
--
-- No DDL on any table. No data modifications. No existing objects dropped.
-- =============================================================================

-- =============================================================================
-- 1. Composite index for GROUP BY customer_phone
-- =============================================================================
-- Speeds up Query A (latest 100 customers) by enabling an index-only scan
-- over (ai_phone, customer_phone, created_at). With this index the planner
-- can walk all (ai_phone='...', customer_phone, created_at) entries, collect
-- MAX(created_at) per customer group without touching the heap, and sort the
-- ~700 aggregate rows by last_msg DESC — no full table scan needed.
--
-- CONCURRENTLY = no table lock; safe on production with live traffic.
-- IF NOT EXISTS = safe to re-run.

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_karisma_messages_phone_agg
  ON karisma_messages (ai_phone, customer_phone, created_at);

-- =============================================================================
-- 2. RPC: get_latest_customer_phones
-- =============================================================================
-- Returns the most recently active customer phones for a given ai_phone,
-- ordered by their last message timestamp descending. Used by
-- ConversationsProvider._fetchInitialLoad() and loadMore() to drive
-- paginated conversation loading (page N = offset N*100).
--
-- SECURITY DEFINER: runs with definer's permissions, bypassing RLS on the
-- per-client messages table. Matches the pattern used by
-- get_broadcast_analytics_aggregates and process_monthly_rollover.
-- SET search_path = public: prevents search_path injection attacks.

CREATE OR REPLACE FUNCTION get_latest_customer_phones(
  p_ai_phone   text,
  p_limit      int  DEFAULT 100,
  p_offset     int  DEFAULT 0
)
RETURNS TABLE (customer_phone text, last_msg timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT customer_phone, MAX(created_at) AS last_msg
  FROM karisma_messages
  WHERE ai_phone = p_ai_phone
  GROUP BY customer_phone
  ORDER BY last_msg DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- Permissions: service_role only (matches process_monthly_rollover pattern).
-- Postgres grants EXECUTE to PUBLIC by default for new functions —
-- the REVOKE lines below lock that down explicitly.
REVOKE ALL ON FUNCTION get_latest_customer_phones(text, int, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_latest_customer_phones(text, int, int) FROM anon;
REVOKE ALL ON FUNCTION get_latest_customer_phones(text, int, int) FROM authenticated;
GRANT  EXECUTE ON FUNCTION get_latest_customer_phones(text, int, int) TO service_role;

-- =============================================================================
-- 3. RPC: get_conversation_count
-- =============================================================================
-- Returns the total count of unique customer_phones for a given ai_phone.
-- Used by ConversationsProvider to populate the conversation counter badge
-- in the header with the true DB total rather than the loaded-set size.
--
-- Called once on initialize() alongside get_latest_customer_phones.
-- Also called after real-time inserts from previously-unknown phones to
-- increment the displayed total.

CREATE OR REPLACE FUNCTION get_conversation_count(
  p_ai_phone text
)
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(DISTINCT customer_phone)
  FROM karisma_messages
  WHERE ai_phone = p_ai_phone;
$$;

REVOKE ALL ON FUNCTION get_conversation_count(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_conversation_count(text) FROM anon;
REVOKE ALL ON FUNCTION get_conversation_count(text) FROM authenticated;
GRANT  EXECUTE ON FUNCTION get_conversation_count(text) TO service_role;

-- =============================================================================
-- 4. Notify PostgREST to reload schema
-- =============================================================================
-- Forces PostgREST to pick up the new RPC signatures immediately.
-- Without this the API cache may lag by up to 5 seconds on Supabase hosted.

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- After running this migration, verify with the queries in the accompanying
-- verification checklist (A through G) before proceeding to Phase 1.
-- =============================================================================
