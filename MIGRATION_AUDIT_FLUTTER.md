# Migration Audit — Vivid WhatsApp Dashboard (Flutter Web)

**Date:** 2026-05-08  
**Branch audited:** `mars/dashboard-updates`  
**Supabase project:** `zxvjzaowvzvfgrzdimbm` (production, Bahrain region)  
**Auditor note:** All findings derived from source code and migrations only. Items that cannot be determined from code are marked `UNCLEAR`.

---

## Table of Contents

1. [Repo Structure](#1-repo-structure)
2. [Authentication and Session Management](#2-authentication-and-session-management)
3. [Multi-Tenant Architecture (ClientConfig System)](#3-multi-tenant-architecture-clientconfig-system)
4. [Database Schema](#4-database-schema)
5. [Supabase RPCs](#5-supabase-rpcs)
6. [Real-Time Subscriptions](#6-real-time-subscriptions)
7. [WhatsApp Integration](#7-whatsapp-integration)
8. [Provider / State-Management Map](#8-provider--state-management-map)
9. [Screen-by-Screen Feature Inventory](#9-screen-by-screen-feature-inventory)
10. [Services Layer](#10-services-layer)
11. [Models](#11-models)
12. [Recently Shipped Features (Last 60 Days)](#12-recently-shipped-features-last-60-days)
13. [Known Issues and Tech Debt](#13-known-issues-and-tech-debt)
14. [Deployment and Environment](#14-deployment-and-environment)
15. [Third-Party Dependencies](#15-third-party-dependencies)
16. [Data Volumes and Operational Notes](#16-data-volumes-and-operational-notes)

---

## 1. Repo Structure

```
whatsappdashboard-1/
├── lib/
│   ├── main.dart                         # Entry point, MultiProvider tree, AuthWrapper, MainScaffold
│   ├── models/
│   │   ├── models.dart                   # ALL core domain models (1,449 lines)
│   │   ├── financial_models.dart         # FinancialTransaction, TransactionType, PaymentStatus
│   │   └── outreach_models.dart          # OutreachContact, OutreachMessage, OutreachBroadcast
│   ├── providers/                        # 17 ChangeNotifier classes (16 registered)
│   │   ├── agent_provider.dart           # Login, session restore, logout
│   │   ├── conversations_provider.dart   # Paginated conversation loading (1,269 lines)
│   │   ├── broadcasts_provider.dart      # Broadcast send/schedule/cancel (1,085 lines)
│   │   ├── templates_provider.dart       # WhatsApp template sync from Meta (986 lines)
│   │   ├── roi_analytics_provider.dart   # Attribution analytics (1,386 lines)
│   │   ├── admin_analytics_provider.dart # Vivid-admin cross-client analytics
│   │   ├── analytics_provider.dart       # DEAD CODE — not registered in MultiProvider
│   │   ├── broadcast_analytics_provider.dart # Broadcast analytics (251 lines)
│   │   ├── activity_logs_provider.dart   # Activity log with pagination (326 lines)
│   │   ├── manager_chat_provider.dart    # Manager↔AI chat
│   │   ├── notification_provider.dart    # Browser push notifications
│   │   ├── outreach_provider.dart        # CRM outreach (contacts, messages, broadcasts)
│   │   ├── financials_provider.dart      # Internal P&L tracking
│   │   ├── ai_settings_provider.dart     # Per-customer AI toggle
│   │   ├── user_management_provider.dart # User CRUD
│   │   ├── admin_provider.dart           # Vivid-admin operations
│   │   ├── chatbot_analytics_provider.dart # Chatbot-specific metrics
│   │   └── theme_provider.dart           # Sidebar collapse, dark/light toggle
│   ├── screens/
│   │   ├── login_screen.dart             # Login + OTP-based password reset
│   │   ├── dashboard_screen.dart         # Conversation list + detail panels
│   │   ├── admin_panel.dart              # Vivid-admin mega-screen (9,149 lines)
│   │   ├── analytics_screen.dart         # ROI + chatbot analytics tabs
│   │   ├── broadcast_analytics_screen.dart # Campaign analytics
│   │   ├── roi_analytics_screen.dart     # ROI deep-dive (redirects to analytics_screen)
│   │   ├── templates_screen.dart         # Template list/management
│   │   ├── template_detail_screen.dart   # Template variable editor
│   │   ├── new_template_screen.dart      # Create new WhatsApp template
│   │   ├── new_outreach_template_screen.dart # Create outreach template
│   │   ├── financials_tab.dart           # Financials table (Vivid-admin only)
│   │   └── outreach_panel.dart           # CRM outreach panel
│   ├── services/
│   │   ├── supabase_service.dart         # Supabase client singleton (1,963 lines)
│   │   ├── impersonate_service.dart      # Admin impersonation helpers
│   │   └── query_result_service.dart     # AI query results (dynamic table)
│   ├── widgets/                          # 18 reusable widget files
│   ├── utils/                            # analytics_exporter, audio_controller, date_formatter,
│   │                                     #   health_scorer, media_download_helper, time_utils,
│   │                                     #   toast_service, initials_helper
│   └── theme/vivid_theme.dart            # Color palette and text styles
├── supabase/migrations/                  # 5 SQL migrations
│   ├── 20260418_broadcast_reply_payment.sql
│   ├── 20260429_broadcast_rollover.sql
│   ├── 20260430_broadcast_analytics_rpc.sql
│   ├── 20260504_conversation_pagination.sql
│   └── 20260504_needs_reply_pagination.sql   # PLACEHOLDER — not filled in
├── web/                                  # Flutter Web build target
├── pubspec.yaml
├── vercel.json
└── VIVID_PROJECT_CONTEXT.md              # Comprehensive project context document (820 lines)
```

### Key size indicators

| File | Lines | Notes |
|------|-------|-------|
| `admin_panel.dart` | 9,149 | Vivid-admin only; should be split |
| `supabase_service.dart` | 1,963 | All DB I/O, RPC calls, Meta API helpers |
| `roi_analytics_provider.dart` | 1,386 | Attribution window, paginated fetch |
| `conversations_provider.dart` | 1,269 | Phase 1 paginated architecture |
| `models/models.dart` | 1,449 | All core models in one file |
| `broadcasts_provider.dart` | 1,085 | Broadcast lifecycle |
| `templates_provider.dart` | 986 | Meta sync, variable detection |

---

## 2. Authentication and Session Management

### Authentication mechanism

The dashboard does **not** use Supabase Auth. It uses a custom `users` table with a bespoke login flow.

**Login path** (`supabase_service.dart:100–285`):

1. Call the `login_user(p_email, p_password)` PostgreSQL RPC (SECURITY DEFINER).
2. If the RPC throws an `ACCOUNT_BLOCKED` Postgres error code, re-throw immediately — no fallback.
3. If the RPC throws any other error, fall back to a **plaintext password SELECT** directly on the `users` table:
   ```dart
   .from('users')
   .select()
   .eq('email', email)
   .eq('password', password)
   .single()
   ```
4. On success, store `user.id` in `window.sessionStorage` with key `vivid_user_id`.

**Password hashing path** — when creating or updating a user from admin panel, the code calls the `hash_password(p_password text)` PostgreSQL RPC and stores the result in `users.password_hash`. The plaintext fallback still checks `users.password` (unhashed column), so some accounts may have only a hash while others have both, or only plaintext.

**Session restore** (`agent_provider.dart:23–50`):

```dart
final storage = web.window.sessionStorage;
final userId = storage.getItem('vivid_user_id');
// → query users table by id → check status != 'blocked' → load client
```

Session is lost on tab close (sessionStorage, not localStorage).

**Password reset flow** (`login_screen.dart`):

1. User enters email → code generated client-side via `Random().nextInt(900000) + 100000`.
2. Code inserted into `password_reset_codes` table (`email`, `code`, `used`, `created_at`).
3. Code sent to user via n8n webhook at `https://n8n.vividsystems.cloud/webhook/password-reset`.
4. 6-digit OTP field auto-advances on last digit.
5. Server checks code within 10-minute window (`created_at > now() - interval '10 minutes'`) and `used = false`.
6. On match: updates `users.password` (plaintext) and `users.password_hash`, marks code `used = true`.
7. 60-second resend cooldown enforced client-side.

**User roles** (`UserRole` enum in `models.dart`):

| Role | String value | Description |
|------|-------------|-------------|
| `admin` | `'admin'` | Full access. If `client_id IS NULL` → Vivid admin. If `client_id IS NOT NULL` → client admin |
| `manager` | `'manager'` | Can message, view broadcasts, limited settings |
| `viewer` | `'viewer'` | Read-only |
| `analytics` | `'analytics'` | Analytics tabs only |

**Permission model** (`AppUser` in `models.dart:602–755`):

- `customPermissions: Set<Permission>` — explicitly granted extras.
- `revokedPermissions: Set<Permission>` — explicitly blocked.
- Resolution priority: **revoked > custom > role default**.
- `isVividAdmin` = `role == admin && clientId == null`
- `isClientAdmin` = `role == admin && clientId != null`

**Security note:** The service role key (`_supabaseServiceRoleKey`) is hardcoded as a string literal in `supabase_service.dart` at approximately line 30. This was flagged in the March 2026 security audit. It must not be moved to client-side code that gets compiled into the web bundle without obfuscation — currently it is, which means the key is discoverable via source-map inspection. See section 13 for full security findings.

---

## 3. Multi-Tenant Architecture (ClientConfig System)

### ClientConfig static class

`ClientConfig` (defined in `models.dart:760–1018`) is a **static, non-ChangeNotifier** class. It acts as the runtime configuration singleton after login. All providers access it to determine which table names, phone numbers, and webhook URLs to use.

**State fields:**

```dart
static Client? _currentClient;       // currently active tenant
static AppUser? _currentUser;        // logged-in user
static bool _isPreviewMode = false;  // impersonation active
static AppUser? _savedAdminUser;     // original admin saved during impersonation
static String? _previewClientId;     // safety guard for exitPreview()
```

**Set on login:** `ClientConfig.setCurrentClient(client)` and `ClientConfig.setCurrentUser(user)` are called from `agent_provider.dart` after successful authentication.

**Cleared on logout:** `ClientConfig.clear()` zeroes all fields.

### Per-client dynamic table names

Each row in the `clients` table carries explicit column values that are read into the `Client` model. Providers resolve table names via `ClientConfig` getters:

| ClientConfig getter | `clients` column | Example value |
|--------------------|-----------------|---------------|
| `messagesTable` | `messages_table` | `karisma_messages` |
| `broadcastsTable` | `broadcasts_table` | `karisma_broadcasts` |
| `broadcastRecipientsTable` | `broadcast_recipients_table` | `karisma_broadcast_recipients` |
| `templatesTable` | `templates_table` | `karisma_whatsapp_templates` |
| `managerChatsTable` | `manager_chats_table` | `karisma_manager_chats` |
| `aiSettingsTable` | `ai_settings_table` | `karisma_ai_settings` |
| `customerPredictionsTable` | `customer_predictions_table` | `karisma_customer_predictions` |
| `queryResultsTable` | `query_results_table` | `hob_query_results` |
| `bookingsTable` | `bookings_table` | UNCLEAR — no example seen in code |

### Per-client phone numbers

| ClientConfig getter | `clients` column | Purpose |
|--------------------|-----------------|---------|
| `conversationsPhone` | `conversations_phone` | `ai_phone` filter for conversation queries |
| `broadcastsPhone` | `broadcasts_phone` | Source phone for broadcast sends |
| `remindersPhone` | `reminders_phone` | Booking reminders phone |
| `businessPhone` | `business_phone` | Legacy catch-all (kept for backward compatibility) |

When `conversationsPhone` is null, falls back to `businessPhone`. Same fallback for `broadcastsPhone` and `remindersPhone`.

### Per-client Meta API credentials

| `clients` column | Used by |
|-----------------|---------|
| `waba_id` | Templates sync, broadcast dispatch |
| `meta_access_token` | All Meta API calls after `applyClientMetaConfig()` |

`applyClientMetaConfig(Client client)` in `supabase_service.dart` sets the service-level `metaWabaId` and `metaAccessToken` statics. If either is null/empty, a WARNING is printed and the global fallback (from `system_settings`) is used.

### Shared WABA

HOB and Vivid Demo share WABA `4194190724181657`. The `clients.is_shared_waba` boolean column (auto-set by a Supabase DB trigger) guards template sync so the `slug` prefix filter prevents one client's templates overwriting the other's rows.

`normalizeSlug(slug)` in `templates_provider.dart`:
```dart
slug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')
```

### Feature flags

`clients.enabled_features` is a Postgres array stored in `Client.enabledFeatures`. Features are checked at two levels:

1. `ClientConfig.hasFeature(feature)` — checks the array.
2. `MainScaffold._isFeatureConfigured(feature)` — additional check that the required table/phone exists (e.g., `messagesTable` must be non-null for `conversations` feature to initialize).

Known feature strings used in code: `conversations`, `broadcasts`, `whatsapp_templates`, `booking_reminders`, `analytics`, `manager_chat`.

### Product type

`clients.product_type` (default `'retention'`). When `'chatbot'`, `ClientConfig.isChatbotClient` returns true and the `ChatbotAnalyticsProvider` flow is used instead of the ROI attribution path.

### Admin impersonation

`impersonate_service.dart`:

1. `startImpersonation(client)` — saves `ClientConfig.currentUser` to `_originalAdmin`, calls `ClientConfig.enterPreview(client, tempUser)`, writes `impersonation_start` to `activity_logs`.
2. `stopImpersonation()` — calls `ClientConfig.exitPreview()`, writes `impersonation_end` to `activity_logs`.
3. `exitPreview()` has a safety guard: if `clientId` arg does not match `_previewClientId`, it aborts early to prevent double-exit bugs.

Impersonation events are hidden from client-facing activity log views via `_hideInternalActions = true` in `ActivityLogsProvider`.

---

## 4. Database Schema

### Global / shared tables

These tables are not per-client. They live in the public schema and are accessed by all tenants.

#### `clients`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `name` | text | Display name |
| `slug` | text UNIQUE | URL-safe identifier, used as table-name prefix |
| `webhook_url` | text | Legacy catch-all webhook URL |
| `enabled_features` | text[] | Feature flags array |
| `business_phone` | text/numeric | Legacy, may be stored as numeric in DB |
| `messages_table` | text | Per-client messages table name |
| `broadcasts_table` | text | |
| `broadcast_recipients_table` | text | |
| `templates_table` | text | |
| `manager_chats_table` | text | |
| `ai_settings_table` | text | |
| `customer_predictions_table` | text | |
| `query_results_table` | text | |
| `bookings_table` | text | |
| `waba_id` | text | Meta WABA ID (per-client override) |
| `meta_access_token` | text | Meta API token (per-client override) |
| `conversations_phone` | text | Per-feature phone |
| `conversations_webhook_url` | text | |
| `broadcasts_phone` | text | |
| `broadcasts_webhook_url` | text | |
| `reminders_phone` | text | |
| `reminders_webhook_url` | text | |
| `manager_chat_webhook_url` | text | |
| `predictions_refresh_webhook_url` | text | |
| `broadcast_limit` | int | Monthly send cap |
| `rollover_balance` | int NOT NULL DEFAULT 0 | Unused quota rolled from prior month (added 20260429) |
| `has_ai_conversations` | bool DEFAULT true | Feature flag for AI chat |
| `is_shared_waba` | bool DEFAULT false | Auto-set by DB trigger |
| `product_type` | text DEFAULT 'retention' | 'retention' or 'chatbot' |

#### `users`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `email` | text UNIQUE | Normalized to lowercase on login |
| `password` | text | Plaintext password (legacy — security concern) |
| `password_hash` | text | bcrypt hash (set when password is updated via admin) |
| `name` | text | |
| `role` | text | 'admin', 'manager', 'viewer', 'analytics' |
| `client_id` | uuid FK→clients | NULL = Vivid admin |
| `status` | text | 'active', 'blocked' |
| `custom_permissions` | jsonb | Extra granted permissions set |
| `revoked_permissions` | jsonb | Explicitly removed permissions set |
| `created_at` | timestamptz | |

#### `activity_logs`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `user_id` | uuid FK→users | |
| `user_name` | text | Denormalized |
| `user_email` | text | Denormalized |
| `client_id` | uuid FK→clients | |
| `action_type` | text | `ActionType` enum value |
| `description` | text | |
| `created_at` | timestamptz | |

`ActionType` enum values (from `models.dart`): `messageSent`, `broadcastSent`, `templateCreated`, `templateSynced`, `labelSet`, `aiToggled`, `impersonation_start`, `impersonation_end`, and others.

#### `system_settings`

| Column | Type | Notes |
|--------|------|-------|
| `key` | text PK | |
| `value` | text | |

Keys read by the app:

| Key | Purpose |
|-----|---------|
| `meta_api_version` | Meta Graph API version (e.g., `v21.0`) |
| `meta_access_token` | Global fallback Meta token |
| `meta_waba_id` | Global fallback WABA ID |
| `meta_app_id` | App ID `1969042950344680` |
| `outreach_phone` | Outreach WABA phone |
| `outreach_send_webhook` | n8n URL for outreach message sends |
| `outreach_broadcast_webhook` | n8n URL for outreach broadcasts |
| `outreach_waba_id` | Outreach WABA ID |
| `outreach_meta_access_token` | Outreach Meta token |
| `webhook_secret` | `X-Vivid-Secret` header value for n8n |

#### `password_reset_codes`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | UNCLEAR — assumed |
| `email` | text | |
| `code` | text | 6-digit string generated client-side |
| `used` | bool | Set true on consumption |
| `created_at` | timestamptz | Valid for 10 minutes |

#### `client_quota_history` (added 20260429)

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `client_id` | uuid FK→clients | |
| `month` | date | First day of month |
| `base_limit` | int | `broadcast_limit` at rollover time |
| `rollover_in` | int | Carry-in balance used |
| `sent_count` | int | Broadcasts sent during that month |
| `rollover_out` | int | Balance carried to next month |
| `created_at` | timestamptz | |

UNIQUE constraint on `(client_id, month)`.

#### `vivid_financials` (Vivid-internal, not per-client)

Accessed via `adminClient`. Columns: UNCLEAR — model derived from `FinancialTransaction.fromJson`.

#### Vivid Outreach tables (global, not per-client)

All accessed via `adminClient`:

- `vivid_outreach_contacts`
- `vivid_outreach_messages`
- `vivid_outreach_broadcasts`
- `vivid_outreach_broadcast_recipients`
- `vivid_outreach_whatsapp_templates`

### Per-client dynamic tables

Created by the `create_client_tables(p_slug text, p_ai_phone text)` PostgreSQL RPC when a new client is onboarded via the admin wizard.

#### `{slug}_messages` (e.g., `karisma_messages`)

The core conversation log. Messages are rows; a "conversation" is a group of rows sharing `customer_phone`.

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid/bigint PK | UNCLEAR — not read by model's primary key field |
| `ai_phone` | text/numeric | The business phone number; stored as numeric in DB, `rawAiPhone?.toString()` in fromJson |
| `customer_phone` | text | Customer's phone number |
| `customer_message` | text | Inbound message text |
| `ai_response` | text | AI-generated response text |
| `Voice_Response` | text | Voice message transcript (capital V from DB) |
| `manager_response` | text | Manager override text |
| `created_at` | timestamptz | Message timestamp |
| `is_voice_message` | bool | True if audio file |
| `sent_by` | text | `'AI'`, `'manager'`, `'system'` |
| `label` | text | Conversation label (set per-conversation, stored on most recent row) |
| `label_set_at` | timestamptz | When label was applied (may be missing on older tables) |
| `media_url` | text | Media attachment URL |
| `media_type` | text | MIME type |

Index (added 20260504):
```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_karisma_messages_phone_agg
  ON karisma_messages (ai_phone, customer_phone, created_at);
```

#### `{slug}_broadcasts` (e.g., `karisma_broadcasts`)

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `campaign_name` | text | |
| `sent_at` | timestamptz | |
| `status` | text | `'sent'`, `'scheduled'`, `'cancelled'`, `'failed'` |
| `total_recipients` | int | |
| `template_name` | text | |
| `offer_amount` | numeric | Used in ROI analytics |
| `target_sheet` | text | Google Sheets tab used as recipient source |

#### `{slug}_broadcast_recipients` (e.g., `karisma_broadcast_recipients`)

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `broadcast_id` | uuid FK→broadcasts | |
| `phone` | text | Recipient phone number |
| `status` | text | `null`/`'accepted'`/`'sent'`/`'delivered'`/`'read'`/`'failed'` |
| `sent_at` | timestamptz | |
| `reply_text` | text | First inbound reply within attribution window (added 20260418) |
| `replied_at` | timestamptz | (added 20260418) |
| `amount_paid` | numeric | Payment amount if paid within window (added 20260418) |
| `paid_at` | timestamptz | (added 20260418) |

Attribution trigger: `trg_populate_broadcast_reply` on `{slug}_messages` INSERT attributes the first inbound reply within a 72-hour window to the most recent eligible broadcast recipient row for that phone.

#### `{slug}_whatsapp_templates` (e.g., `karisma_whatsapp_templates`)

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `meta_template_id` | text UNIQUE | ID from Meta |
| `name` | text | |
| `status` | text | `'APPROVED'`, `'PENDING'`, `'REJECTED'` |
| `category` | text | |
| `body_text` | text | Template body |
| `header_type` | text | `'TEXT'`, `'IMAGE'`, `'VIDEO'` |
| `header_text` | text | |
| `footer_text` | text | |
| `body_variables` | jsonb | Variable placeholders |
| `body_variable_labels` | jsonb | Human-readable labels |
| `body_variable_sources` | jsonb | Source mapping |
| `offer_image_url` | text | Supabase Storage URL only (CDN URLs stripped on sync) |
| `slug` | text | Client slug, used for shared-WABA isolation |
| `created_at` | timestamptz | |

#### `{slug}_manager_chats` (e.g., `karisma_manager_chats`)

Used for the Manager Chat panel (manager↔AI interaction, not customer-facing).

UNCLEAR — full column list not enumerated in source. Known columns from message inserts: `user_id`, `role`, `content`, `created_at`, `session_id`.

#### `{slug}_ai_settings` (e.g., `karisma_ai_settings`)

Per-customer AI on/off toggle.

Known columns: `customer_phone` (likely PK), `ai_enabled` bool, `updated_at`.

#### `{slug}_customer_predictions` (e.g., `karisma_customer_predictions`)

Predictive analytics scores per customer.

UNCLEAR — full schema not enumerated. Known: `customer_phone`, prediction score fields, `updated_at`.

#### `{slug}_query_results` (e.g., `hob_query_results`)

AI natural-language query results cache. 60-second freshness window.

UNCLEAR — full schema not enumerated.

---

## 5. Supabase RPCs

All RPCs in this project are `SECURITY DEFINER` so they can access per-client tables that have RLS active. All are granted `EXECUTE` to `service_role` only and explicitly revoked from `PUBLIC`, `anon`, `authenticated`.

### `login_user(p_email text, p_password text)`

- **Client:** anon client
- **Purpose:** Validates credentials against `users` table.
- **Returns:** User row or raises Postgres error.
- **Error codes:** `ACCOUNT_BLOCKED` (custom) is caught specifically to block fallback.
- **Status:** Active. Has a known bug (UNCLEAR — possibly uuid/text type mismatch) that causes it to throw non-blocking errors, triggering the plaintext fallback in `supabase_service.dart`.

### `hash_password(p_password text)`

- **Client:** anon client
- **Purpose:** Returns bcrypt hash of a plaintext password.
- **Returns:** text (hash string).
- **Called from:** `supabase_service.dart` during user create, password update, and password reset.
- **Status:** Active.

### `create_client_tables(p_slug text, p_ai_phone text)`

- **Client:** adminClient
- **Purpose:** Creates all per-client tables (`{slug}_messages`, `{slug}_broadcasts`, etc.) in one DDL batch when a new client is onboarded.
- **Returns:** void / success flag (UNCLEAR).
- **Called from:** `admin_panel.dart` in the new-client wizard (lines 3372 and 3440 — called twice, once for initial create and once on retry/update path).
- **Status:** Active.

### `get_latest_customer_phones(p_ai_phone text, p_limit int DEFAULT 100, p_offset int DEFAULT 0)`

- **Client:** anon client (uses service_role via SECURITY DEFINER)
- **Purpose:** Returns `(customer_phone text, last_msg timestamptz)` for the most recently active customers of a given AI phone, paginated.
- **Returns:** TABLE rows.
- **Defined in:** `20260504_conversation_pagination.sql`
- **Limitation:** Query is hardcoded to `karisma_messages` table. Does **not** work for other clients (HOB, etc.) without a separate migration or parameterization.
- **Called from:** `supabase_service.fetchLatestCustomerPhones()` → `ConversationsProvider._fetchInitialLoad()`, `loadMoreConversations()`.
- **Status:** Active. Known hardcoded-table limitation.

### `get_conversation_count(p_ai_phone text)`

- **Client:** anon client (SECURITY DEFINER)
- **Purpose:** Returns `bigint` — count of distinct `customer_phone` values for the given `ai_phone`.
- **Defined in:** `20260504_conversation_pagination.sql`
- **Limitation:** Same hardcoded `karisma_messages` table issue as above.
- **Called from:** `supabase_service.fetchTotalConversationCount()` → `ConversationsProvider._fetchInitialLoad()`.
- **Status:** Active. Known hardcoded-table limitation.

### `get_needs_reply_count(p_ai_phone text, p_limit int DEFAULT 1000, p_offset int DEFAULT 0)` (inferred name)

- **Client:** anon client (SECURITY DEFINER)
- **Purpose:** Returns count of conversations where the last message is from the customer (i.e., no AI/manager follow-up yet).
- **Defined in:** `20260504_needs_reply_pagination.sql` — **this migration file contains only a placeholder string `[paste the same SQL above]` and no actual SQL**. The RPC is called in the app but was never deployed via this migration file.
- **Called from:** `supabase_service.fetchNeedsReplyCount()`.
- **Status:** UNCLEAR — may have been deployed manually or is broken.

### `get_needs_reply_phones(p_ai_phone text, p_limit int DEFAULT 1000, p_offset int DEFAULT 0)` (inferred name)

- **Client:** anon client (SECURITY DEFINER)
- **Purpose:** Returns phone numbers for conversations that need a reply.
- **Defined in:** Same unfilled migration file.
- **Called from:** `supabase_service.fetchNeedsReplyPhones()` → `ConversationsProvider.activateNeedsReplyFilter()`.
- **Status:** UNCLEAR — same concern as above.

### `get_broadcast_analytics_aggregates(p_recipients_table text, p_broadcasts_table text)`

- **Client:** adminClient
- **Purpose:** Returns per-broadcast delivery/read/failed counts via dynamic SQL (`FORMAT(%I)` for table names), plus a global NULL summary row.
- **Defined in:** `20260430_broadcast_analytics_rpc.sql`
- **Note:** This RPC exists and is correctly defined, but `BroadcastAnalyticsProvider` does **not** use it — it still does client-side aggregation over a full paginated fetch instead.
- **Status:** Defined but **unused** by the Flutter app.

### `process_monthly_rollover()`

- **Client:** Not called from Flutter — intended for pg_cron or manual execution.
- **Purpose:** On the 1st of each month (Bahrain time), computes unused quota per client and writes a new `rollover_balance` to `clients` and an audit row to `client_quota_history`.
- **Guard:** `EXTRACT(DAY FROM NOW() AT TIME ZONE 'Asia/Bahrain') != 1` → exits early.
- **Defined in:** `20260429_broadcast_rollover.sql`
- **Status:** Defined. Cron schedule: UNCLEAR — no pg_cron definition found in migrations.

---

## 6. Real-Time Subscriptions

All subscriptions use the **anon-key `client`** (not adminClient), because Supabase Realtime does not support the service role client in the Flutter SDK.

### Subscription channels

| Channel name | Table | Filter | Created by |
|-------------|-------|--------|-----------|
| `messages_realtime_{tableName}` | `{slug}_messages` | `ai_phone=eq.{phone}` | `SupabaseService.subscribeToExchanges()` |
| `broadcasts_{broadcastsTable}` | `{slug}_broadcasts` | none | `BroadcastsProvider._subscribeToBroadcasts()` |
| `recipients_{broadcastId}` | `{slug}_broadcast_recipients` | `broadcast_id=eq.{id}` | `BroadcastsProvider._subscribeToRecipients(broadcastId)` |
| `manager_chat_{table}_{userId}` | `{slug}_manager_chats` | `user_id=eq.{userId}` | `ManagerChatProvider._subscribe()` |
| `notifications_channel` | UNCLEAR | none | `NotificationProvider` |
| `outreach_messages_{contactPhone}` | `vivid_outreach_messages` | (phone filter) | `OutreachProvider._subscribeToContact()` |
| `outreach_messages_global` | `vivid_outreach_messages` | none | `OutreachProvider._subscribeGlobal()` |
| `admin_messages_{client.id}` | `{slug}_messages` | (client's table) | `AdminProvider._subscribeToMessages()` |
| `admin_broadcasts_{client.id}` | `{slug}_broadcasts` | (client's table) | `AdminProvider._subscribeToBroadcasts()` |
| `admin_recipients_{client.id}` | `{slug}_broadcast_recipients` | (client's table) | `AdminProvider._subscribeToRecipients()` |

### Conversations realtime flow

When a new `INSERT` or `UPDATE` arrives on the messages channel:

1. `SupabaseService` processes the event and emits via a Dart `Stream<RawExchange>`.
2. `ConversationsProvider` stream listener identifies the `customer_phone` from the new message.
3. If the phone is already in `_exchangesByPhone`, the new message is appended.
4. If the phone is **not yet loaded** (new customer or first page not reached), `_fetchAndInsertUnloadedCustomer(phone)` is called asynchronously. The `_phonesBeingFetched` set prevents concurrent duplicate fetches.
5. `_buildConversations()` is called to recompute the UI-facing conversation list.

### Notification channel concern

`notifications_channel` in `NotificationProvider` is created without any client-specific filter. This means **all logged-in clients receive each other's notification events** if they are in the same Supabase project. This is a potential cross-tenant data leak for notification metadata.

---

## 7. WhatsApp Integration

### Meta Cloud API

- API version: `v21.0` (configurable via `system_settings.meta_api_version`)
- App ID: `1969042950344680`
- WABA IDs: per-client from `clients.waba_id`; shared WABA `4194190724181657` for HOB and Vivid Demo

### n8n workflow server

Base URL: `https://n8n.vividsystems.cloud`

All outbound webhook calls from Flutter go through the `proxy-webhook` Supabase Edge Function on web builds (to avoid CORS). On native builds, direct HTTP POST is used.

```dart
// Web path (supabase_service.dart:1375)
final fnResponse = await client.functions.invoke('proxy-webhook', body: {...});

// Native path
final response = await http.post(Uri.parse(url), body: jsonEncode(payload));
```

A shared secret header `X-Vivid-Secret` is included if `SupabaseService.webhookSecret` (from `system_settings`) is non-empty.

### Webhook endpoints per feature

| Feature | URL source | Payload fields |
|---------|-----------|---------------|
| Send customer message | `ClientConfig.conversationsWebhookUrl` | `ai_phone`, `customer_phone`, `manager_response`, `sent_by`, `messages_table`, optional media fields |
| Send broadcast | `ClientConfig.broadcastsWebhookUrl` | `template_name`, `target_sheet`, `ai_phone`, `broadcasts_table`, `broadcast_recipients_table` |
| Manager chat query | `ClientConfig.managerChatWebhookUrl` | `webhookUrl`, `userId`, `content`, `session_id` |
| Password reset | Hardcoded: `https://n8n.vividsystems.cloud/webhook/password-reset` | `email`, `code` |
| Outreach message send | `SupabaseService.outreachSendWebhook` | UNCLEAR — full payload not audited |
| Outreach broadcast | `SupabaseService.outreachBroadcastWebhook` | UNCLEAR |
| Predictions refresh | `ClientConfig.predictionsRefreshWebhookUrl` | UNCLEAR |

### Template sync flow

`TemplatesProvider.syncFromMeta()`:

1. Check `_globalSyncLock` (static bool) — prevent concurrent syncs across any provider instance.
2. Fetch all templates from Meta Graph API: `GET /v21.0/{waba_id}/message_templates`.
3. For each Meta template:
   a. Look up existing DB row by `meta_template_id`.
   b. Preserve `body_variable_labels`, `body_variable_sources`, `offer_image_url` from DB.
   c. Strip scontent/fbcdn CDN URLs (Facebook removes these); keep only Supabase Storage URLs.
   d. Upsert to `{slug}_whatsapp_templates`.
4. Stale cleanup: DELETE rows whose `meta_template_id` is not in the current Meta response set.
5. For shared WABA clients: filter by `slug` column to prevent cross-client deletion.

### Broadcast send flow

1. User selects template, recipient list, optional schedule time.
2. `BroadcastsProvider.sendBroadcast()`:
   - POST to `ClientConfig.broadcastsWebhookUrl` with template + recipient data.
   - Insert confirmation row into `managerChatsTable` with status `'Sending...'`.
   - Fire `_pollBroadcastResults()` async.
3. `_pollBroadcastResults()`: polls every 10 seconds, up to 30 attempts (5 minutes), for delivery counts. Updates the manager-chat confirmation row when done.
4. Scheduled broadcasts: `scheduleBroadcast()` inserts a row with `status: 'scheduled'` and a UTC-converted scheduled time (input is Bahrain time UTC+3).

### Broadcast quota enforcement

- Monthly limit: `ClientConfig.currentClient.effectiveLimit` = `broadcastLimit + rolloverBalance`
- `fetchMonthlySentCount()` computes month start in Bahrain time, queries non-failed recipients.
- Enforcement is client-side only — no server-side guard against over-sending.

### Media upload

Customer-sent media is uploaded by n8n to Supabase Storage. Manager-sent media is uploaded by the Flutter app to bucket `media`, path `{slug}/{timestamp}_{sanitized_filename}`.

### Voice messages

- Stored as `is_voice_message = true` rows.
- `Voice_Response` column (capital V) holds transcript.
- Rendered by `VoiceMessageBubble` widget.

---

## 8. Provider / State-Management Map

The app uses the `provider` package (ChangeNotifier + MultiProvider). All 16 active providers are registered at app root in `main.dart`. There is no lazy loading — all providers are instantiated at startup regardless of which features the current client has enabled.

| Provider | File | Registered | Purpose |
|---------|------|-----------|---------|
| `AgentProvider` | `agent_provider.dart` | Yes | Auth, session restore, logout |
| `ConversationsProvider` | `conversations_provider.dart` | Yes | Paginated conversations + realtime messaging |
| `BroadcastsProvider` | `broadcasts_provider.dart` | Yes | Broadcast lifecycle, send, schedule, cancel |
| `TemplatesProvider` | `templates_provider.dart` | Yes | WhatsApp template sync from Meta + Supabase storage |
| `RoiAnalyticsProvider` | `roi_analytics_provider.dart` | Yes | Revenue attribution analytics (retention clients) |
| `ChatbotAnalyticsProvider` | `chatbot_analytics_provider.dart` | Yes | Chatbot-specific metrics (chatbot product type) |
| `AdminAnalyticsProvider` | `admin_analytics_provider.dart` | Yes | Vivid-admin cross-client analytics |
| `NotificationProvider` | `notification_provider.dart` | Yes | Browser push + sound notifications for new messages |
| `AiSettingsProvider` | `ai_settings_provider.dart` | Yes | Per-customer AI on/off toggle |
| `ManagerChatProvider` | `manager_chat_provider.dart` | Yes | Manager chat with AI, session grouping |
| `AdminProvider` | `admin_provider.dart` | Yes | Vivid-admin client/user CRUD, label triggers |
| `UserManagementProvider` | `user_management_provider.dart` | Yes | Client-admin user CRUD |
| `ActivityLogsProvider` | `activity_logs_provider.dart` | Yes | Activity log with server-side pagination and filtering |
| `OutreachProvider` | `outreach_provider.dart` | Yes | CRM outreach contacts, messages, broadcasts |
| `FinancialsProvider` | `financials_provider.dart` | Yes | Internal P&L tracking (Vivid-internal only) |
| `ThemeProvider` | `theme_provider.dart` | Yes | Sidebar expand/collapse, dark/light mode |
| `AnalyticsProvider` | `analytics_provider.dart` | **No** | DEAD CODE — not registered in MultiProvider |
| `BroadcastAnalyticsProvider` | `broadcast_analytics_provider.dart` | Scoped | Registered locally inside `admin_panel.dart` only |

### Provider initialization order

`MainScaffold._initProviders()` is called in `initState` and checks `_isFeatureConfigured()` before initializing each provider:

1. Conversations: if `conversations` feature enabled and `messagesTable` is set.
2. Broadcasts: if `broadcasts` feature enabled and (`broadcastsPhone` or `broadcastsWebhookUrl`) is set.
3. Other providers: initialized on navigation to their respective screen.

---

### `ConversationsProvider` (`conversations_provider.dart`)

**Purpose:** Manages the paginated list of all conversations for the current client, real-time incoming message handling, needs-reply filtering, and message sending with optimistic updates.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_exchangesByPhone` | `Map<String, List<RawExchange>>` | Primary data store. Key = customer_phone. Each value is the full exchange history for that customer. Populated by RPC page fetches and realtime events. |
| `_allExchanges` | `List<RawExchange>` | Shim — flattened view of all exchanges from `_exchangesByPhone`. Kept in sync so legacy code paths (`_buildConversations`, search filter) keep working. Will be removed in Phase 3. |
| `_phonesBeingFetched` | `Set<String>` | In-flight guard. Before calling `_fetchAndInsertUnloadedCustomer(phone)`, the phone is checked here. Prevents duplicate fetches when multiple real-time events fire rapidly for the same unloaded phone. |
| `_totalConversationCount` | `int` | Server-side count of distinct customer phones. Fetched via `get_conversation_count` RPC on initial load. Used to show the accurate header counter (not capped by page size). |
| `_currentPage` | `int` | Zero-based page index for the main conversation list infinite scroll. Incremented by `loadMoreConversations()`. |
| `_hasMorePages` | `bool` | Cleared when an RPC page fetch returns fewer than 100 phones. Prevents `loadMoreConversations()` from making unnecessary network calls. |
| `_needsReplyPhones` | `List<String>` | Ordered list of phones that have an unanswered customer message. Populated by `activateNeedsReplyFilter()` via `fetchNeedsReplyPhones` RPC. |
| `_needsReplyCount` | `int` | Server-side count of conversations needing a reply. Fetched on initial load and refreshed after each sent message. |
| `_isNeedsReplyFilterActive` | `bool` | Global filter toggle. When true, the `conversations` getter filters `_conversations` to only show phones present in `_needsReplyPhones`. |
| `_needsReplyCurrentPage` | `int` | Page index for needs-reply pagination, incremented by `loadMoreNeedsReply()`. |
| `_needsReplyHasMorePages` | `bool` | Set false when `fetchNeedsReplyPhones` returns fewer than 100 results. |
| `_conversations` | `List<Conversation>` | Derived UI list, rebuilt by `_buildConversations()` from `_allExchanges`. Sorted by `lastMessageAt` descending. |
| `_pendingMessages` | `List<Message>` | Optimistic messages shown immediately before server confirmation arrives. Removed when the real-time echo arrives or after 30-second timeout. |
| `_selectedCustomerPhone` | `String?` | Currently open conversation phone. Used to zero the unread count on select. |
| `_isLoading` | `bool` | Set during initial load and `fetchConversations()`. |
| `_isLoadingMore` | `bool` | Set during `loadMoreConversations()` and `activateNeedsReplyFilter()`. |
| `_isSending` | `bool` | Set during `sendMessage()`. Guards against concurrent sends. |
| `_searchQuery` | `String` | Client-side search string. Filters by name, phone, or message content via `_allExchanges` scan. |
| `_statusFilter` | `ConversationStatus?` | Client-side status filter. Applied only when `_isNeedsReplyFilterActive` is false. |
| `_labelFilter` | `String?` | Client-side label filter. Applied after status/needsReply filters. |
| `_soundEnabled` | `bool` | Whether notification sounds are enabled. |
| `_knownExchangeIds` | `Set<String>` | Deduplication set. Tracks all exchange IDs added via realtime. (Phase 3 restoration pending.) |

**Public getters:**

- `conversations` → `List<Conversation>` — Returns the filtered/sorted conversation list. Applies needs-reply filter first (uses `_needsReplyPhones` set), then status filter, then label filter, then search.
- `messages` → `List<Message>` — Returns all `Message` objects for `_selectedCustomerPhone`, built from `_exchangesByPhone[phone]`. Expands each `RawExchange` into up to three `Message` objects (customer, AI, manager). Appends matching `_pendingMessages`.
- `totalConversationCount` → `int` — Server-side total (from RPC), not capped at page size.
- `needsReplyCount` → `int` — Server-side count of unanswered conversations.
- `hasMorePages` → `bool` — Whether more pages are available for infinite scroll.
- `needsReplyHasMorePages` → `bool` — Whether more pages of needs-reply phones can be loaded.
- `isLoadingMore` → `bool` — True during any pagination operation.
- `availableLabels` → `List<String>` — Sorted unique label values across all loaded conversations.
- `totalUnreadCount` → `int` — Sum of `unreadCount` across all conversations.
- `highlightedExchangeId` → `String?` — Exchange highlighted by search navigation (auto-clears after 2 seconds).

**Public methods:**

```dart
Future<void> initialize()
// Sets up initial load (_fetchInitialLoad), starts realtime subscription,
// registers stream listener for new/updated exchanges.

Future<void> loadMoreConversations()
// Fetches page (_currentPage + 1) of phones via RPC,
// adds any new phones to _exchangesByPhone, advances _currentPage.
// No-op if _isLoadingMore or !_hasMorePages.

Future<void> activateNeedsReplyFilter()
// Fetches page 0 of needs-reply phones via RPC, sets _isNeedsReplyFilterActive.
// Loads exchanges for any unloaded phones in the result set.
// Reverts the flag if the RPC throws.

void deactivateNeedsReplyFilter()
// Clears _isNeedsReplyFilterActive, resets _needsReplyPhones and page state.

Future<void> loadMoreNeedsReply()
// Fetches the next page of needs-reply phones, adds new phones to _needsReplyPhones,
// loads exchanges for unloaded ones. No-op if filter is inactive.

Future<bool> sendMessage(String conversationId, String text, {mediaUrl, mediaType, mediaFilename, replyToMessage})
// Creates a pending message immediately, posts to n8n via sendMessageViaWebhook.
// On success: sets 5-second timeout to remove pending if no realtime echo arrives.
// On failure: removes the pending message and sets _error.

Future<String?> uploadMedia(Uint8List bytes, String filename)
// Uploads to Supabase Storage bucket 'media', path '{slug}/{timestamp}_{sanitized_filename}'.
// Returns the public URL or null on failure.

Future<bool> setConversationLabel(String customerPhone, String label)
// Calls SupabaseService.updateConversationLabel, then updates local _conversations state.

Future<List<MessageSearchResult>> searchMessages(String query)
// Queries the messages table via ilike. Deduplicates name/phone matches to one per conversation.

void setHighlightedExchange(String? id)
// Sets _highlightedExchangeId; auto-clears after 2 seconds.
```

**`_fetchInitialLoad()` — the three parallel calls:**

1. `service.fetchLatestCustomerPhones(page: 0, pageSize: 100)` — gets the 100 most recently active customer phones via `get_latest_customer_phones` RPC.
2. `service.fetchTotalConversationCount()` — fetches total distinct phone count via `get_conversation_count` RPC.
3. `service.fetchNeedsReplyCount()` — fetches unanswered conversation count via `get_needs_reply_count` RPC.

Steps 2 and 3 are launched as concurrent futures. After awaiting phones, all exchanges for those phones are fetched via `fetchExchangesForPhones`, then `_exchangesByPhone` is populated, `_allExchanges` shim is rebuilt, and `service.seedExchangeCache` is called to prime the realtime base state.

**`_fetchAndInsertUnloadedCustomer()` — the two race guards:**

- Guard 1 (pre-fetch): `if (_exchangesByPhone.containsKey(phone)) return;` — skips if phone was loaded by another path before this call.
- Guard 2 (post-fetch): `if (_exchangesByPhone.containsKey(phone)) return;` — skips if another async path loaded the same phone while the `await fetchExchangesForPhones([phone])` was in flight.
- `_phonesBeingFetched.add(phone)` is set at entry and `remove(phone)` in the `finally` block, preventing concurrent duplicate fetch calls for the same phone from the realtime stream.

**Depends on:** `SupabaseService` (RPCs, exchanges fetch, realtime subscription, webhook send, label update), `ClientConfig` (table names, phones, slug for upload path), `web.Notification` / `web.AudioContext` for browser alerts.

**Quirks / notable implementation details:**

- `_allExchanges` is a redundant flattened list maintained as a shim for backward compatibility. `_buildConversations()` still iterates it. Phase 3 will replace this with a direct `_exchangesByPhone` iteration.
- The stream listener from `SupabaseService.exchangesStream` receives a snapshot of ALL cached exchanges (not just new ones). It clears and rebuilds `_exchangesByPhone` for already-loaded phones on each event, which means every realtime message triggers a full rebuild of all loaded conversations. This is acceptable at current scale but will need optimization.
- `broadcastLifecycleLabel` computation in `_buildConversations()` scans exchanges backward from the end to find the last broadcast row, then tracks customer/agent reply indices. A conversation shows `'Sent'` if no customer replied, `'Replied'` if agent's last index > customer's last index, `'Needs Reply'` otherwise.
- Handoff messages containing `"manager will be with you shortly"` or `"المدير سيكون معك"` are detected by `_isHandoffMessage()` and excluded from the `needsReply` status calculation.
- Pending messages use ID format `pending_{customerPhone}_{millisecondsSinceEpoch}`. The `messages` getter filters them by matching prefix against `_selectedCustomerPhone` and also deduplicates against real `managerResponse` content.
- `initializePreview()` is a stripped version of `initialize()` with no realtime subscription — used when an admin impersonates a client.

---

### `BroadcastsProvider` (`broadcasts_provider.dart`)

**Purpose:** Manages the list of broadcast campaigns for the current client, handles send/schedule/cancel operations, tracks recipient counts and delivery stats, and polls for sending progress.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_broadcasts` | `List<Broadcast>` | All broadcasts for the current client, sorted by `sent_at` descending. |
| `_recipients` | `List<BroadcastRecipient>` | Full paginated recipient list for the currently selected broadcast. |
| `_selectedBroadcast` | `Broadcast?` | Currently selected broadcast (detail view). |
| `_isLoading` | `bool` | Set during `fetchBroadcasts()`. |
| `_isLoadingRecipients` | `bool` | Set during `selectBroadcast()` while recipients are being fetched. |
| `_recipientSentCount` | `int` | Count of recipients with status `accepted`, `sent`, or `delivered` for the selected broadcast. |
| `_isSending` | `bool` | Set while `sendBroadcast()` or `scheduleBroadcast()` HTTP call is in flight. |
| `_monthlySentCount` | `int` | Count of non-failed recipients for all broadcasts since the start of the current Bahrain calendar month. |
| `_monthlyFailedCount` | `int` | Count of failed recipients for the same period. |
| `_sendingPollTimer` | `Timer?` | 5-second polling timer that checks `status` for all `sending`-state broadcasts. Auto-stops when none remain in that state. |
| `_broadcastsChannel` | `RealtimeChannel?` | Supabase realtime subscription on `{slug}_broadcasts` (INSERT + UPDATE). |
| `_recipientsChannel` | `RealtimeChannel?` | Supabase realtime subscription on `{slug}_broadcast_recipients` filtered by `broadcast_id`. |

**Public getters:**

- `broadcasts` → `List<Broadcast>` — All loaded broadcasts.
- `recipients` → `List<BroadcastRecipient>` — All recipients for selected broadcast.
- `monthlySentCount` / `monthlyLimit` / `remainingBroadcasts` — Quota display values.
- `rolloverBalance` → `int` — From `ClientConfig.currentClient?.rolloverBalance`.
- `effectiveLimit` — Exposed as `monthlyLimit` = `broadcastLimit + rolloverBalance`.
- `isAtLimit` → `bool` — True when `monthlySentCount >= monthlyLimit` and `monthlyLimit > 0`.
- `recipientsSent` / `recipientsDelivered` / `recipientsRead` / `recipientsFailed` — Delivery funnel counts computed from loaded `_recipients`.

**Public methods:**

```dart
Future<void> fetchBroadcasts()
// Fetches all broadcasts from adminClient, then calls _enrichRecipientCounts()
// for accurate totals, then fetchMonthlySentCount().

Future<void> fetchRecipients(String broadcastId)
// Paginated fetch (1000/page) from recipients table for the given broadcast.
// Loops until a page < 1000 rows is returned.

Future<void> fetchMonthlySentCount()
// Computes Bahrain month start (UTC+3 offset), queries broadcast IDs since then,
// counts non-failed recipients, also counts failed recipients separately.

Future<bool> sendBroadcast(String instruction, {String? templateName, String? templateImageUrl})
// Validates quota, POSTs to ClientConfig.broadcastsWebhookUrl, inserts a
// confirmation row into manager_chats, fires _pollBroadcastResults fire-and-forget.
// Returns true on HTTP 2xx.

Future<bool> scheduleBroadcast(String instruction, DateTime scheduledAtBht, {String? editBroadcastId, String? templateName, String? templateImageUrl})
// Converts Bahrain time to UTC (subtract 3h), inserts a 'scheduled' row into
// the broadcasts table. If editBroadcastId is provided, updates the existing row instead.

Future<void> cancelScheduledBroadcast(String broadcastId)
// Updates status to 'cancelled' via adminClient.

Future<void> renameBroadcast(String broadcastId, String newName)
// Updates campaign_name, then verifies the update persisted (reads back).
// Throws if the read-back value differs (likely RLS issue).
```

**Depends on:** `SupabaseService.adminClient` (all DB reads/writes), `SupabaseService.postWebhook` (send/schedule via n8n), `ClientConfig` (table names, phones, webhook URLs, quota).

**Quirks / notable implementation details:**

- `_enrichRecipientCounts()` runs parallel `COUNT` queries (one per broadcast) to bypass Supabase's 1000-row default limit that would truncate total counts on the old single-fetch path.
- `_pollBroadcastResults()` runs fire-and-forget (never awaited). It polls every 10 seconds up to 30 attempts (5 minutes), then updates the manager chat row with a delivery summary string.
- `fetchMonthlySentCount()` uses Bahrain timezone boundary: `DateTime.now().toUtc().add(Duration(hours: 3))` for month start, then subtracts 3h back to UTC for the query.
- `_broadcastsTable` and `_recipientsTable` throw `StateError` if `ClientConfig` is not fully loaded — this guards against calls made before login completes.
- `renameBroadcast()` includes a post-update read-back with an explicit mismatch check. The error message calls out RLS as the likely cause, since `adminClient` should bypass RLS.

---

### `TemplatesProvider` (`templates_provider.dart`)

**Purpose:** Fetches WhatsApp templates from the per-client Supabase table for display, syncs them from the Meta API into Supabase, creates new templates via Meta API, and deletes templates.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_templates` | `List<WhatsAppTemplate>` | Templates loaded from the per-client DB table for display. |
| `_allMetaTemplates` | `List<WhatsAppTemplate>` | Raw templates fetched from Meta API during sync. Not shown directly in UI. |
| `_templateDbStatuses` | `Map<String, Map<String, dynamic>>` | Full DB row per `meta_template_id`. Used for validation status dots in the UI. |
| `_isLoading` | `bool` | Set during `fetchTemplates()`. |
| `_isSyncing` | `bool` | Set during `syncTemplatesToSupabase()`. |
| `_isSubmitting` | `bool` | Set during `createTemplate()` and `deleteTemplate()`. |
| `_globalSyncLock` | `static bool` | Process-wide mutex. Prevents concurrent syncs across provider instances or multiple tab navigations. |
| `_lastSuccessfulFetchTime` | `DateTime?` | Set after a successful Meta API fetch. Guards against wiping the DB if Meta returns an empty list (stale-cache protection). |

**Public getters:**

- `templates` → `List<WhatsAppTemplate>` — Display-path templates from DB.
- `allMetaTemplates` → `List<WhatsAppTemplate>` — Raw Meta API templates (sync path only).
- `templateDbStatuses` → `Map<String, Map<String, dynamic>>` — Full row data keyed by `meta_template_id`.
- `isSyncing`, `isLoading`, `isSubmitting` → loading state booleans.

**Public methods:**

```dart
Future<void> fetchTemplates()
// Reads from adminClient .from(ClientConfig.templatesTable).eq('client_id', clientId).
// Populates both _templates and _templateDbStatuses.

Future<void> fetchMetaTemplates()
// Paginates Meta Graph API GET /{waba_id}/message_templates?limit=100.
// Follows paging.next cursor until exhausted. Stores in _allMetaTemplates.
// Uses per-client WABA ID from ClientConfig (never falls back to global WABA).

Future<String?> syncTemplatesToSupabase()
// Full sync: fetchMetaTemplates → filter for client prefix (shared WABA) →
// per-template DB read to preserve labels/sources/images → upsert new rows →
// update existing rows → delete stale rows. Returns null on success.
// Releases _globalSyncLock in finally block.

Future<({String? error, String? templateId})> createTemplate({name, language, category, components})
// POST to Meta API /{waba_id}/message_templates. Returns templateId on success.

Future<String?> deleteTemplate(String name, String id)
// DELETE to Meta API /{waba_id}/message_templates?name={name}.
// On 200: removes from Supabase table and local _templates list.
```

**Static helpers:**

- `normalizeSlug(slug)` → transforms client slug to safe prefix (`[^a-z0-9]` → `_`).
- `_smartLabels(bodyText, varCount)` → 50-char lookahead context detection for variable labels (English + Arabic keywords).
- `_autoSources(labels)` → maps `customer_name` → `customer_data`, everything else → `ai_extracted`.

**Depends on:** `SupabaseService.adminClient` (DB reads/writes), `http` package (Meta API calls), `ClientConfig` (WABA ID, access token, templates table, slug, shared WABA flag).

**Quirks / notable implementation details:**

- Shared WABA clients (e.g., HOB and Vivid Demo) must have template names prefixed with their normalized slug (e.g., `hob_`). During sync, a prefix filter prevents one client's templates from being written into the other's table row.
- A second gateway check is applied inside the per-template row loop to block any template that slips past the outer filter.
- The sync preserves `offer_image_url` only if it points to the project's own Supabase Storage URL (`zxvjzaowvzvfgrzdimbm.supabase.co/storage/v1/object/public`). Meta CDN URLs (`scontent.*`, `fbcdn.net`) are discarded because they expire.
- A client-context safety abort at line ~449 compares `clientId` before and after the async Meta fetch to prevent writing to the wrong client's table if the admin navigates away mid-sync.
- Template fetch from DB uses `eq('client_id', clientId)` — the `meta_template_id` field is the unique identifier in Meta's system but the DB upsert uses `onConflict: 'client_id,template_name,language_code'`.

---

### `RoiAnalyticsProvider` (`roi_analytics_provider.dart`)

**Purpose:** Computes all ROI analytics metrics for retention-type clients. Fetches messages and broadcast data, applies the 168-hour attribution window, and builds `AnalyticsData` with leads, revenue, engagement, response times, campaign performance, and daily breakdowns.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_isLoading` | `bool` | Set during `fetchAnalytics()`. |
| `_error` | `String?` | Error string from last failed fetch. |
| `_data` | `AnalyticsData?` | Assembled analytics result. Null until first successful fetch. |

**Public methods:**

```dart
Future<void> fetchAnalytics({
  required String clientId,
  required String? messagesTable,
  required String? broadcastsTable,
  DateTime? startDate,
  DateTime? endDate,
  String? campaignId,
  DateTime? compareStartDate,
  DateTime? compareEndDate,
  Duration overdueThreshold = const Duration(minutes: 30),
})
// Paginated fetch of messages (1000/page), all broadcasts + recipients (1000/page).
// Filters out sent_by='broadcast' rows. Builds campaign lookups.
// Calls _computeMetrics() for current period and optionally for comparison period.
// Assembles AnalyticsData with campaigns, daily breakdown, labeled customers, etc.
```

**Attribution model:** `_kAttributionWindowHours = 168` (7 days). A lead is attributed to a broadcast if the customer's phone was **ever** in `broadcast_recipients` (ever-touched model). Falls back to 72h window for phones that were never broadcast recipients.

**Depends on:** `SupabaseService.adminClient`, `ClientConfig.broadcastRecipientsTable`.

**Quirks / notable implementation details:**

- Lead count uses a 24-hour gap rule: a new "lead" is counted each time a customer sends a message more than 24 hours after their previous message.
- Revenue is computed per label event (`payment done` label), using `offer_amount` from the attributed campaign. One phone + label + calendar day = one event (deduplication).
- Engagement rate = unique respondents / unique recipients across all campaigns.
- Average response time is capped at 86400 seconds (24h) per observation.
- Employee performance is derived from `sent_by` field on outbound messages.
- The `compare*` parameters fetch a completely separate set of messages and compute a parallel `_ComputedMetrics` for period-over-period comparison.

---

### `BroadcastAnalyticsProvider` (`broadcast_analytics_provider.dart`)

**Purpose:** Computes delivery/read/failed rates across all broadcasts for the current client, and the last-7-days daily activity chart. Registered locally (scoped) inside `admin_panel.dart` broadcast analytics tab — not in the global MultiProvider tree.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_analytics` | `BroadcastAnalyticsData?` | Computed analytics result. |
| `_isLoading` | `bool` | Set during `fetchAnalytics()`. |
| `_error` | `String?` | Error string from last failure. |

**Public methods:**

```dart
Future<void> fetchAnalytics()
// Fetches all broadcasts (no range filter), then paginates all recipients (1000/page).
// Computes delivery/read/failed totals in Dart. Builds CampaignPerformance for
// the 5 most recent broadcasts. Builds DailyBroadcastActivity for last 7 days.
```

**Depends on:** `SupabaseService.adminClient`, `ClientConfig` (table names).

**Quirks / notable implementation details:**

- Does NOT use the `get_broadcast_analytics_aggregates` RPC that was specifically created for this purpose. Client-side aggregation is used instead, which is slow and memory-intensive for large recipient sets.
- Status counting logic: `failed` → failed; `read` → increments both read and delivered; everything else (null, `accepted`, `sent`, `delivered`) → delivered only.
- `totalRevenue` is summed from `offer_amount` on broadcast rows (not recipients). This counts potential offer value, not actual payments.
- `last7Days` uses `DateTime.now()` at call time as the anchor for "today."

---

### `ActivityLogsProvider` (`activity_logs_provider.dart`)

**Purpose:** Fetches and filters the activity log with a two-tier filtering system: server-side filters applied at fetch time, and client-side filters applied in the `_filteredLogs` getter. Supports lazy display rendering with `displayedLogs` (50-item increments).

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_logs` | `List<ActivityLog>` | All fetched logs (unfiltered). |
| `_isLoading` / `_isLoadingMore` | `bool` | Loading state flags. |
| `_offset` | `int` | Current server-side fetch offset (advances by page size on `loadMore()`). |
| `_hasMore` | `bool` | Set false when a page returns fewer than 1000 rows. |
| `_displayLimit` | `int` | Client-side display cap. Starts at 50, incremented by 50 via `showMore()`. |
| `_fetchClientId` | `String?` | The client ID used for the current fetch (separate from `_selectedClientId` filter). |
| `_selectedClientId` | `String?` | Admin-only client filter (triggers re-fetch). |
| `_selectedUserId` | `String?` | Client-side user filter. |
| `_selectedActionType` | `ActionType?` | Can be applied server-side or client-side. |
| `_startDate` / `_endDate` | `DateTime?` | Date range filters (server-side when set). |
| `_searchQuery` | `String` | Client-side search (matches `userName`, `description`, `userEmail`). |
| `_filterAiOnly` | `bool` | Shows only `aiToggled` action type. |
| `_hideInternalActions` | `bool` | When true, excludes `impersonation_start` and `impersonation_end` from server query (for client-facing views). |
| `_blockedUserIds` | `Set<String>` | Set of blocked user IDs fetched from `users` table, used to flag users in filter dropdowns. |

**Public methods:**

```dart
Future<void> fetchLogs({String? clientId, bool hideInternalActions = false})
// Resets pagination, fetches first page (1000 rows) from server via SupabaseService.fetchActivityLogs.
// Applies server filters: clientId, actionTypes, excludeActionTypes, date range.

Future<void> loadMore()
// Appends the next server page. Increments _offset.

void showMore()
// Increments _displayLimit by 50. Does NOT fetch from server.

void setClientFilter(String? clientId)    // Re-fetches from server
void setActionTypeFilter(ActionType? at)   // Re-fetches from server
void setDateRange(DateTime? s, DateTime? e) // Re-fetches from server
void setUserFilter(String? userId)          // Client-side only
void setSearchQuery(String query)           // Client-side only
void setAiFilter(bool value)               // Client-side only
void clearFilters()                        // Clears all, re-fetches from server
```

**Computed getters:**

- `displayedLogs` → First `_displayLimit` items from `_filteredLogs`.
- `filteredCount` → Length of `_filteredLogs` (for header).
- `uniqueUsers` → Deduplicated user list from all fetched logs (for filter dropdown).
- `logCountsByType` / `logCountsByUser` — Aggregation maps for analytics display.
- `todayLogs` / `thisWeekLogs` — Time-filtered subsets.

**Depends on:** `SupabaseService.instance.fetchActivityLogs()`, `SupabaseService.client` (for blocked user IDs query).

---

### `AdminProvider` (`admin_provider.dart`)

**Purpose:** Vivid-admin operations — full CRUD on clients and users, bulk user operations, client health monitoring via last-login timestamps, and label trigger management.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_clients` | `List<Client>` | All clients loaded by `fetchClients()`. |
| `_allUsers` | `List<Map<String, dynamic>>` | All users across all clients (raw JSON). |
| `_selectedClient` | `Client?` | Currently selected client in admin panel. |
| `_selectedClientUsers` | `List<AppUser>` | Users for the selected client. |
| `_lastLogins` | `Map<String, DateTime?>` | Last login timestamp per client ID. Used for health dots. |
| `_labelTriggers` | `List<Map<String, dynamic>>` | Label trigger rules for selected client. |
| `_isLoadingTriggers` | `bool` | Set during `fetchLabelTriggers()`. |

**Public methods:**

```dart
Future<void> fetchClients()
Future<bool> createClient({name, slug, enabledFeatures, ...all column fields})
Future<bool> updateClient({clientId, ...partial column fields})
Future<bool> deleteClient(String clientId)
Future<void> selectClient(Client client)
// Selects client, fetches its users, fetches label triggers if 'labels' feature enabled.

Future<void> fetchClientUsers(String clientId)
Future<void> fetchAllUsers()
Future<bool> createUser({clientId, email, password, name, role, customPermissions, revokedPermissions})
Future<bool> updateUser({userId, email?, password?, name?, role?, customPermissions?, revokedPermissions?})
Future<bool> resetUserPassword({userId, newPassword})
Future<bool> toggleUserStatus(String userId, String newStatus)
Future<int> bulkToggleStatus(List<String> userIds, String newStatus)
Future<int> bulkChangeRole(List<String> userIds, String newRole)
Future<int> bulkDeleteUsers(List<String> userIds)
Future<({int success, List<String> errors})> importUsersFromCsv(List<Map<String, String>> rows)
// CSV columns: name, email, password, role, client_id.

Future<void> fetchLastLoginPerClient()
// Queries activity_logs for most recent 'login' per client_id.
int getHealthStatus(String clientId)
// 0 = active (<24h), 1 = recent (<7d), 2 = inactive (7d+ or never).

Future<void> fetchLabelTriggers(String clientId)
Future<String?> createLabelTrigger({clientId, label, triggerWords, color?, autoApply})
Future<String?> updateLabelTrigger(String id, Map<String, dynamic> updates, String clientId)
Future<String?> deleteLabelTrigger(String id, String clientId)
```

**Depends on:** `SupabaseService.instance` (all client/user/log queries), `SupabaseService.client` (bulk status/role/delete via anon key directly on `users` table).

**Quirks / notable implementation details:**

- Bulk operations (`bulkToggleStatus`, `bulkChangeRole`, `bulkDeleteUsers`) use `SupabaseService.client` (anon key) rather than `adminClient`, which creates an RLS dependency on those operations.
- `availableRoles` list includes `'agent'` — which is not defined in the `UserRole` enum (enum only has `admin`, `manager`, `agent`, `viewer`). The `agent` role maps to `UserRole.agent` via `UserRole.fromString`.
- `fetchLastLoginPerClient()` fetches ALL login events for ALL clients and finds the most recent per client. For large log tables this could be slow; no `LIMIT` per client is applied.

---

### `AgentProvider` (`agent_provider.dart`)

**Purpose:** Manages authentication state — login, session restoration from `sessionStorage`, logout, and initial `ClientConfig` setup.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_agent` | `Agent?` | Simple name+email display model. Set on successful login/restore. |
| `_isLoading` | `bool` | Set during `login()`. |
| `_isRestoringSession` | `bool` | Starts `true`. Cleared after `restoreSession()` completes (success or fail). Used by `AuthWrapper` to show a loading screen instead of login. |
| `_error` | `String?` | Login error message. |
| `_isAdmin` | `bool` | True only for Vivid super admins (not client admins). |

**Public methods:**

```dart
Future<void> restoreSession()
// Reads 'vivid_user_id' from window.sessionStorage.
// Fetches user row by ID. Checks status != 'blocked'.
// Calls ClientConfig.setAdmin or ClientConfig.setClientUser based on user type.
// On any failure: clears sessionStorage, sets _isRestoringSession = false.

Future<bool> login(String email, String password)
// Calls SupabaseService.instance.login(email, password).
// On success: sets _agent, calls ClientConfig.setAdmin or setClientUser,
// writes user.id to sessionStorage.

void logout()
// Calls SupabaseService.instance.logout(), clears _agent,
// removes 'vivid_user_id' from sessionStorage, calls ClientConfig.clear().
```

**Depends on:** `SupabaseService.instance` (login), `SupabaseService.client` (session restore user query), `ClientConfig` (setAdmin, setClientUser, clear), `web.window.sessionStorage`.

---

### `AiSettingsProvider` (`ai_settings_provider.dart`)

**Purpose:** Fetches and updates per-customer AI on/off settings from the `{slug}_ai_settings` table. Provides optimistic toggle (UI updates immediately, then confirmed by DB refresh).

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_settings` | `Map<String, AiChatSetting>` | Keyed by `customerPhone`. |
| `_isLoading` | `bool` | Set during `fetchAllSettings()`. |
| `_error` | `String?` | Last error string. |

**Public methods:**

```dart
Future<void> fetchAllSettings()
// Fetches all rows from aiTable where ai_phone = ClientConfig.businessPhone.
// No-op if !ClientConfig.hasAiConversations or aiTable is null.

Future<AiChatSetting?> fetchSetting(String customerPhone)
// Fetches single row for the given phone. Updates _settings cache.

Future<bool> toggleAi(String customerPhone, bool enabled)
// Optimistic update: immediately updates local cache, notifies listeners.
// Then updates (or inserts) DB row.
// On error: reverts local cache to previous value.
// No-op if !ClientConfig.hasAiConversations.
```

**Depends on:** `SupabaseService.adminClient`, `ClientConfig.aiSettingsTable`, `ClientConfig.businessPhone`, `ClientConfig.hasAiConversations`.

---

### `NotificationProvider` (`notification_provider.dart`)

**Purpose:** Subscribes to new messages on the client's messages table via Realtime, and fires browser notifications + audio alerts when a customer message arrives and the AI is disabled for that customer (or when the client has no AI).

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_notifications` | `List<ManagerNotification>` | In-memory notification list (not persisted). |
| `_unreadCount` | `int` | Count of unread notifications. |
| `_soundEnabled` | `bool` | Whether to play sound alerts. |
| `_browserNotificationsEnabled` | `bool` | Whether browser Notification API permission was granted. |
| `_channel` | `RealtimeChannel?` | Supabase realtime channel named `notifications_channel`. |

**Key behavior:** The channel name `notifications_channel` has **no client-specific filter** in the channel name or subscription. The `ai_phone` check is done in the callback, but the channel itself is not filtered — all clients on the same Supabase project receive each other's Postgres change events on insert. See Section 13 for the cross-tenant leak risk.

Uses `dart:html` (`html.Notification`, `html.AudioElement`) — this is a deprecated import that will break in future Flutter SDK versions. `notification_provider.dart` is one of three files not yet migrated to `package:web`.

**Depends on:** `SupabaseService.adminClient` (AI setting check), `ClientConfig` (table names, phone, hasAiConversations).

---

### `ManagerChatProvider` (`manager_chat_provider.dart`)

**Purpose:** Manages the manager chat panel — displays messages grouped into sessions, sends messages via n8n webhook, handles real-time message updates, and maintains session-ID assignment even when n8n writes rows without a session_id.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_allMessages` | `List<ManagerChatMessage>` | All messages for the current user across all sessions. |
| `_currentSessionId` | `String?` | Active session UUID. Null = legacy messages without session_id. |
| `_messageSessionMap` | `Map<String, String>` | In-memory cache of `message.id → session_id`. Survives DB refreshes to preserve session assignments when n8n saves rows without session_id. |
| `_isLoading` | `bool` | Set during `_loadAllMessages()`. |
| `_isWaitingForResponse` | `bool` | Set when a message is sent and cleared when the AI response arrives (via realtime or polling). |
| `_predictionStats` | `PredictionStats?` | Prediction context for HOB clients. Loaded async on initialize if `customerPredictionsTable` is configured. |
| `_draftMessage` | `String` | Draft text preserved across navigation (not persisted). |
| `_pollTimer` | `Timer?` | Fallback polling timer for AI responses when realtime is delayed. |
| `_chatChannel` | `RealtimeChannel?` | Realtime subscription filtered by `user_id`. |

**Public methods:**

```dart
void initialize({required String agentId, required String managerPhoneNumber})
// Sets up messages load and realtime subscription.
// Idempotent: if already initialized for same user, just refreshes messages.

Future<void> sendMessage(String content)
// Inserts a temp message locally, POSTs to managerChatWebhookUrl via n8n,
// starts fallback poll timer.

void startNewSession()
// Generates new UUID, sets _currentSessionId.

void selectSession(String? sessionId)
// Switches to a different session. Messages getter filters accordingly.
```

**Session ID resolution:** n8n often saves the DB row without `session_id`. When a realtime INSERT arrives, the provider:
1. Tries to match by message ID first, then by `userMessage` content against temp messages.
2. Resolves the session ID from: DB record's `session_id` → temp message's `session_id` → `_currentSessionId` (fallback).
3. Calls `_patchSessionId(messageId, resolvedSessionId)` to write the session ID back to the DB row so future full refreshes preserve it.

**Depends on:** `SupabaseService.adminClient` (DB reads/writes), `SupabaseService.client` (realtime), `SupabaseService.postWebhook`, `SupabaseService.fetchPredictionStats()`, `ClientConfig`.

---

### `UserManagementProvider` (`user_management_provider.dart`)

**Purpose:** Client admin's self-service user management — CRUD on users scoped to `ClientConfig.currentClient.id`. Uses anon client directly (not `adminClient`), so RLS must permit these operations.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_users` | `List<AppUser>` | Users for the current client. |
| `_isLoading` | `bool` | Set during `fetchUsers()`. |
| `_error` | `String?` | Last error string. |

**Public methods:**

```dart
Future<void> fetchUsers()
// Queries users table via SupabaseService.client (anon key) filtered by client_id.
// Relies on RLS permitting this SELECT.

Future<bool> createUser({name, email, role, password, customPermissions?, revokedPermissions?})
// Inserts into users table via anon client.
// Logs ActionType.userCreated to activity_logs.

Future<bool> updateUser({userId, name?, email?, role?, password?, customPermissions?, revokedPermissions?})
// Updates users table via anon client. Handles empty list → null for clearing permissions.

Future<bool> toggleUserStatus(String userId)
// Toggles between 'active' and 'blocked'.

bool emailExists(String email, {String? excludeUserId})
// Client-side check against already-loaded _users list.
```

**Depends on:** `SupabaseService.client` (anon key for all DB operations), `SupabaseService.instance.toggleUserStatus()`, `SupabaseService.instance.log()`, `ClientConfig.currentClient`.

**Quirks:** Unlike `AdminProvider`, all DB operations use the anon key client. This means RLS policies must allow the logged-in user to SELECT, INSERT, UPDATE on `users` rows within their `client_id`. This is a security consideration flagged in the March 2026 audit.

---

### `ThemeProvider` (`theme_provider.dart`)

**Purpose:** Persists UI preferences (dark/light mode, sidebar expanded/collapsed) across page reloads using `SharedPreferences`.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_themeMode` | `ThemeMode` | Current theme. Defaults to `ThemeMode.dark`. |
| `_sidebarExpanded` | `bool` | Whether the sidebar is expanded. Defaults to `true`. |

**Public methods:**

```dart
Future<void> toggleTheme()    // Flips dark/light, persists to SharedPreferences 'isDarkMode'.
Future<void> toggleSidebar()  // Flips sidebar state, persists to SharedPreferences 'sidebarExpanded'.
```

**Depends on:** `shared_preferences` package.

---

### `OutreachProvider` (`outreach_provider.dart`)

**Purpose:** Manages the CRM outreach module — contacts CRUD with import from Excel/CSV, outreach messages with realtime subscription per-contact and global, broadcasts to filtered contact lists, and outreach-specific WhatsApp template management.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_contacts` | `List<OutreachContact>` | All CRM contacts. |
| `_selectedContact` | `OutreachContact?` | Currently open contact. |
| `_contactFilter` | `ContactStatus?` | Status filter for contact list. |
| `_contactSearch` | `String` | Search filter (company name, contact name, phone). |
| `_lastMessageByContact` | `Map<String, OutreachMessage>` | Most recent message per contact ID. Used for sort and preview. |
| `_messages` | `List<OutreachMessage>` | Messages for selected contact. |
| `_messagesChannel` | `RealtimeChannel?` | Per-contact realtime subscription. |
| `_globalMessagesChannel` | `RealtimeChannel?` | Global subscription to all outreach messages (for "needs reply" badge updates). |
| `_broadcasts` | `List<OutreachBroadcast>` | All outreach broadcasts. |
| `_broadcastRecipients` | `List<OutreachBroadcastRecipient>` | Paginated recipients for selected broadcast (50/page). |
| `_recipientTotalCount` | `int` | Server-side total recipients for selected broadcast. |
| `_templates` | `List<WhatsAppTemplate>` | Templates from `vivid_outreach_whatsapp_templates`. |

**Computed getters:**

- `needsReplyContactIds` → contacts whose most recent message in `_lastMessageByContact` is inbound (`!isOutbound`).
- `contactCounts` → `Map<ContactStatus, int>` — count per status for the filter bar badges.
- `hasSendWebhook` / `hasBroadcastWebhook` / `hasMetaCredentials` — config guards.

**Depends on:** `SupabaseService.adminClient`, `SupabaseService.client` (realtime), system_settings config via `SupabaseService` static getters (`outreachPhone`, `outreachSendWebhook`, etc.).

---

### `FinancialsProvider` (`financials_provider.dart`)

**Purpose:** Vivid-internal P&L tracking. Fetches `FinancialTransaction` rows from the `vivid_financials` table with optional date-range filter. Applies client-side type/status/client/search filters. Computes summary totals.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_transactions` | `List<FinancialTransaction>` | All fetched transactions (unfiltered). |
| `_typeFilter` | `TransactionType?` | Client-side income/expense filter. |
| `_statusFilter` | `PaymentStatus?` | Client-side payment status filter. |
| `_clientFilter` | `String?` | Client-side client ID filter. |
| `_datePreset` | `DateRangePreset` | Current date range preset (defaults to `allTime`). |
| `_customStart` / `_customEnd` | `DateTime?` | Custom date range boundaries. |
| `_search` | `String` | Client-side search (description, invoice number, category, client name). |

**Summary getters:**

- `totalRevenue` → sum of `income` + `paid` transactions.
- `outstanding` → sum of `income` + (`pending` or `overdue`) transactions.
- `totalExpenses` → sum of `expense` + `paid` transactions.
- `netProfit` → `totalRevenue - totalExpenses`.

**Depends on:** `SupabaseService.instance.fetchFinancials()`, `SupabaseService.instance.createFinancial()`, etc. All via `adminClient` (vivid_financials has no RLS for normal users).

---

### `ChatbotAnalyticsProvider` (`chatbot_analytics_provider.dart`)

**Purpose:** Computes chatbot-specific metrics for `productType == 'chatbot'` clients: total conversations, AI-handled vs human-takeover rates, average response times, open/overdue conversations list, and per-day breakdown.

**State fields:**

| Field | Type | Description |
|-------|------|-------------|
| `_data` | `ChatbotAnalyticsData?` | Computed result after `fetchAnalytics()`. |
| `_isLoading` | `bool` | Set during fetch. |
| `_error` | `String?` | Error from last failure. |

**Public methods:**

```dart
Future<void> fetchAnalytics({
  required String? messagesTable,
  DateTime? startDate,
  DateTime? endDate,
  Duration overdueThreshold = const Duration(minutes: 30),
})
// Fetches messages paginated (1000/page). Groups by phone. Per-phone:
// determines AI-handled (only ai_response rows) vs human-takeover
// (any manager_response). Computes avg response time per phone.
// Builds ChatbotDailyBreakdown for each calendar day (Bahrain timezone).
```

**Imports `OpenConversation` from `roi_analytics_provider.dart`** — shared model for the open/overdue conversation list.

---

### `AdminAnalyticsProvider` (`admin_analytics_provider.dart`)

**Purpose:** Vivid-admin cross-client analytics dashboard. Fetches message and broadcast data from all clients simultaneously (parallel fetches per client), then aggregates into `VividCompanyAnalytics`.

**State:** Contains `VividCompanyAnalytics? _analytics`, `bool _isLoading`, `String? _error`, and realtime channels per client (`admin_messages_{client.id}`, `admin_broadcasts_{client.id}`, `admin_recipients_{client.id}`). Opening this panel creates `3 × N` channels for N clients — a potential channel-limit concern for large client counts.

**Key models in this file:**

- `VividCompanyAnalytics` — Top-level aggregate: `totalClients`, `totalMessages`, `totalBroadcasts`, `overallAutomationRate`, `messagesByDay` (last 7 days), `messagesByHour`, `topCustomers`, `allClientActivities`, broadcast delivery counts, time-bucketed counts.
- `ClientActivity` — Per-client breakdown: `messageCount`, `broadcastCount`, `lastActivity`, `aiMessages`, `managerMessages`, `uniqueCustomers`, `automationRate`.
- `TopCustomerInfo` — Cross-client top customer by message count.

---

## 9. Screen-by-Screen Feature Inventory

### `login_screen.dart`

- Email/password login form.
- Email normalized to lowercase on every keystroke.
- 3-step forgot-password dialog: email entry → 6-digit OTP (auto-advance on last digit) → new password.
- 60-second resend cooldown (client-side timer).
- No "remember me" — session lives in sessionStorage only.

### `dashboard_screen.dart` (main conversation UI)

Responsive layout:
- `<600px` (mobile): list OR detail, toggled via back button.
- `600–900px` (medium): list panel takes 40% width, detail takes 60%.
- `>900px` (large): list panel takes 35%, detail takes 65%, with a draggable resize handle.

Sub-widgets:
- `ConversationListPanel` — filterable list, infinite scroll trigger.
- `ConversationDetailPanel` — message thread, send box, media picker, label selector, AI toggle.
- `SideProfilePanel` — customer profile sidebar (predictions, history).

Key behaviors:
- Conversations sorted by last-message timestamp descending.
- `needsReply` filter: fetches phones via `get_needs_reply_phones` RPC, then loads unloaded ones.
- Label update: on empty label clears all rows for customer; on set label updates most-recent-row only (with fallback if `label_set_at` column missing).
- Handoff messages excluded from `needsReply` detection: contains "manager will be with you shortly" or "المدير سيكون معك".
- Appointment trigger detection: English + Arabic Bahraini dialect keywords.
- Payment trigger detection: English + Arabic keywords.
- Optimistic send: message appears immediately with `pending` state; 5-second fallback removes it if no realtime echo.
- Media upload: to Supabase Storage `media` bucket.
- Voice message playback via `VoiceMessageBubble`.

### `admin_panel.dart` (Vivid admin only, 9,149 lines)

Access gate: `agent.isVividAdmin` check. Non-admins see a permission denied message.

Major tabs/sections:

| Tab | Content |
|-----|---------|
| Dashboard | Summary cards across all clients |
| Clients | List, create, edit, delete clients |
| Client wizard | Multi-step onboarding: basic info → Meta config → feature config → table names → phone numbers → webhook URLs → preview |
| Users | User management across all clients |
| Analytics | `VividCompanyAnalytics` view — cross-client metrics |
| Activity Logs | Global activity log with client/user/date filters |
| Broadcast Analytics | Scoped `BroadcastAnalyticsProvider` + `RoiAnalyticsProvider` |
| Financials | `FinancialsProvider` — P&L table, income/expense tracking |
| System Settings | `system_settings` table editor |
| Impersonation | Enter preview as any client |

Client wizard calls `create_client_tables` RPC at two points (lines 3372, 3440) — UNCLEAR if both are necessary or if one is a retry path.

### `analytics_screen.dart`

Contains two tabs selected by `productType`:
- **`retention` clients:** ROI Analytics tab (uses `RoiAnalyticsProvider`) + Broadcast Analytics tab.
- **`chatbot` clients:** Chatbot Analytics tab (uses `ChatbotAnalyticsProvider`).

Date range filters: Today, Yesterday, Last 7 Days, Last 30 Days, This Month, All Time, Custom Range.

### `broadcast_analytics_screen.dart`

Uses `BroadcastAnalyticsProvider` (locally scoped in `admin_panel.dart` when accessed from admin; otherwise accessed from main tree). Displays campaign performance table, delivery/read/failed rates, last-7-days chart.

### `templates_screen.dart`

- Template list from `{slug}_whatsapp_templates`.
- "Sync from Meta" button triggers `TemplatesProvider.syncFromMeta()`.
- Filter by status (APPROVED, PENDING, REJECTED).
- Navigate to `template_detail_screen.dart` on tap.

### `template_detail_screen.dart` and `new_template_screen.dart`

- Variable editor: `body_variable_labels` and `body_variable_sources` per variable.
- Smart label detection (50-character lookahead for keywords).
- Image upload for header images to Supabase Storage, then meta upload (proxied through Edge Function).

### `outreach_panel.dart`

- CRM contact management: import from Excel/CSV, manual add.
- Contact lifecycle: `ContactStatus` states (lead → contacted → interested → meeting_scheduled → proposal_sent → client → lost).
- Outreach messages: send via n8n webhook or direct WhatsApp API.
- Outreach broadcasts: send to filtered contact list.
- Template management: separate `vivid_outreach_whatsapp_templates` table.

### `financials_tab.dart`

- Vivid-internal P&L tracking via `vivid_financials` table.
- Date range filter, type filter (income/expense), status filter.
- Create/update/delete transactions.
- Summary cards: total revenue, outstanding, expenses, net profit.
- Currency defaults to `'BHD'`.

---

## 10. Services Layer

### `SupabaseService` (`supabase_service.dart`, 1,963 lines)

Singleton class (`SupabaseService.instance`). Also exposes static accessors:

- `SupabaseService.client` — anon key client (used for Realtime only + RPC calls that go through SECURITY DEFINER).
- `SupabaseService.adminClient` — service_role key client (bypasses all RLS; used for all data reads/writes).

**Key method groups:**

*Authentication:*
- `login(email, password)` — RPC first, plaintext fallback.
- `logout()` — no server-side operation, session cleared client-side.
- `createUser(...)`, `updateUser(...)`, `deleteUser(...)` — CRUD on `users` table via adminClient.

*Client management:*
- `fetchAllClients()`, `fetchClientById(id)` — query `clients` table.
- `createClient(...)`, `updateClient(...)`, `deleteClient(...)`.
- `applyClientMetaConfig(client)` — sets service-level Meta credentials.
- `resetToDefaultMetaConfig()` — reverts to global defaults.

*Conversations:*
- `fetchLatestCustomerPhones(aiPhone, {limit, offset})` → calls `get_latest_customer_phones` RPC.
- `fetchExchangesForPhones(phones, aiPhone)` — paginated `.inFilter()` query, 1000/page.
- `fetchTotalConversationCount(aiPhone)` → calls `get_conversation_count` RPC.
- `fetchNeedsReplyCount(aiPhone)` → calls `get_needs_reply_count` RPC.
- `fetchNeedsReplyPhones(aiPhone)` → calls `get_needs_reply_phones` RPC.
- `subscribeToExchanges(tableName, aiPhone)` → creates Realtime channel.
- `seedExchangeCache(exchanges)` — populates `_cachedExchanges` for realtime base state.
- `sendMessageViaWebhook(...)` → `postWebhook()`.
- `updateConversationLabel(...)` — upsert to most-recent row; graceful fallback if `label_set_at` column missing.

*Broadcasts:*
- All broadcast CRUD delegated to `BroadcastsProvider` directly via adminClient.

*Templates:*
- Meta API calls (fetch templates, upload image) are made from `TemplatesProvider` directly.

*System:*
- `loadAndApplySystemSettings()` — fetches `system_settings` → sets Meta config + loads outreach config.
- `fetchActivityLogs(...)` — server-side filtered, paginated (1000/page).
- `fetchFinancials(...)` — fetches from `vivid_financials` with optional date range.

*Webhook proxy:*
- `postWebhook(url, payload)` — on web routes through `proxy-webhook` Edge Function; on native uses `http.post` directly.

**Static outreach config** (from `system_settings`):
```dart
static String get outreachPhone => ...
static String get outreachSendWebhook => ...
static String get outreachBroadcastWebhook => ...
static String get outreachWabaId => ...
static String get outreachMetaAccessToken => ...
static String get webhookSecret => ...
```

### `ImpersonateService` (`impersonate_service.dart`)

- `startImpersonation(client)` — saves admin user, enters preview, logs event.
- `stopImpersonation()` — restores admin user, logs event.

### `QueryResultService` (`query_result_service.dart`)

- Dynamic table: `ClientConfig.queryResultsTable ?? 'hob_query_results'`
- 60-second window for "recent" result fetch.
- Uses anon client (not adminClient) — potential RLS issue if table has restrictive policies.
- Returns structured query results for the Manager Chat / AI query panel.

---

## 11. Models

This section documents every model class, data class, and enum in the codebase. Primary source is `lib/models/models.dart` (1,449 lines). Additional model files: `lib/models/financial_models.dart`, `lib/models/outreach_models.dart`. Two data classes (`Broadcast`, `BroadcastRecipient`) live in `lib/providers/broadcasts_provider.dart`.

---

### Enums — `models.dart`

#### `SenderType`

Identifies which agent produced a message row.

| Value | DB string | Meaning |
|-------|-----------|---------|
| `customer` | `'customer'` | Inbound message from the customer |
| `ai` | `'ai'` | Outbound reply generated by the AI |
| `manager` | `'manager'` | Outbound reply typed by a human manager |

No `system` value exists — that was a documentation error in previous versions.

#### `ConversationStatus`

Derived status, never stored directly in the DB; computed in `_buildConversations()` inside `ConversationsProvider`.

| Value | DB string | `displayName` | Derivation rule |
|-------|-----------|---------------|-----------------|
| `needsReply` | `'needs_reply'` | `'Needs Reply'` | Latest exchange has a non-empty `customerMessage` and both `aiResponse` and `managerResponse` are empty (or blank). Also set when the latest outbound is flagged as a handoff and no human manager reply follows. |
| `replied` | `'replied'` | `'Replied'` | Latest exchange has a non-empty `managerResponse` OR the last AI reply is non-empty. |

There is no `handedOff` value in the current codebase — references to it in earlier documentation were incorrect.

#### `ActionType`

All 13 values used in `ActivityLog.actionType`. `fromString()` falls back to `login` if unrecognised.

| Value | `.value` (DB string) | `.displayName` |
|-------|----------------------|----------------|
| `login` | `'login'` | `'Session Started'` |
| `logout` | `'logout'` | `'Session Ended'` |
| `messageSent` | `'message_sent'` | `'Message Sent'` |
| `broadcastSent` | `'broadcast_sent'` | `'Broadcast Sent'` |
| `aiToggled` | `'ai_toggled'` | `'AI Toggle'` |
| `userCreated` | `'user_created'` | `'User Created'` |
| `userUpdated` | `'user_updated'` | `'User Updated'` |
| `userDeleted` | `'user_deleted'` | `'User Deleted'` |
| `userBlocked` | `'user_blocked'` | `'User Blocked'` |
| `clientCreated` | `'client_created'` | `'Client Created'` |
| `clientUpdated` | `'client_updated'` | `'Client Updated'` |
| `impersonationStart` | `'impersonation_start'` | `'Impersonation Started'` |
| `impersonationEnd` | `'impersonation_end'` | `'Impersonation Ended'` |

#### `UserRole`

Four roles in ascending access order. `fromString()` falls back to `viewer`.

| Value | `.value` | Description |
|-------|----------|-------------|
| `admin` | `'admin'` | Full access; if `clientId == null` → Vivid super admin; if `clientId != null` → client admin |
| `manager` | `'manager'` | All features except user management |
| `agent` | `'agent'` | Conversations (view + send) only |
| `viewer` | `'viewer'` | Read-only across all features |

#### `Permission`

13 granular permissions, grouped by category. Stored in Supabase as snake_case strings in `custom_permissions` and `revoked_permissions` JSONB arrays.

| Permission | `.value` (DB) | Category |
|------------|---------------|----------|
| `viewDashboard` | `'view_dashboard'` | Dashboard |
| `viewAnalytics` | `'view_analytics'` | Dashboard |
| `viewConversations` | `'view_conversations'` | Conversations |
| `sendMessages` | `'send_messages'` | Conversations |
| `viewBroadcasts` | `'view_broadcasts'` | Broadcasts |
| `sendBroadcasts` | `'send_broadcasts'` | Broadcasts |
| `viewManagerChat` | `'view_manager_chat'` | AI Assistant |
| `useManagerChat` | `'use_manager_chat'` | AI Assistant |
| `viewUsers` | `'view_users'` | User Management |
| `manageUsers` | `'manage_users'` | User Management |
| `viewActivityLogs` | `'view_activity_logs'` | Activity Logs |
| `viewTemplates` | `'view_templates'` | Templates |
| `manageTemplates` | `'manage_templates'` | Templates |

**`Permissions.rolePermissions` — static const matrix:**

| Role | Default permissions |
|------|-------------------|
| `admin` | All 13 |
| `manager` | viewDashboard, viewAnalytics, viewConversations, sendMessages, viewBroadcasts, sendBroadcasts, viewManagerChat, useManagerChat, viewTemplates, manageTemplates |
| `agent` | viewDashboard, viewConversations, sendMessages |
| `viewer` | viewDashboard, viewAnalytics, viewConversations, viewBroadcasts, viewManagerChat |

---

### `RawExchange`

**Source:** `lib/models/models.dart`  
**Represents:** One row from a `{slug}_messages` table. Each row contains one customer inbound turn plus the corresponding AI and/or manager outbound replies — all in a single row.

**Fields:**

| Field | Type | DB column | Notes |
|-------|------|-----------|-------|
| `id` | `String` | `id` | UUID primary key |
| `aiPhone` | `String` | `ai_phone` | Business phone number. Stored as NUMERIC in DB — `fromJson` calls `.toString()` to avoid cast error |
| `customerPhone` | `String` | `customer_phone` | Same numeric-safe toString parse |
| `customerName` | `String?` | `customer_name` | Optional; may be null for unknown contacts |
| `customerMessage` | `String` | `customer_message` | Inbound text. Empty string if voice message |
| `voiceResponse` | `String?` | `Voice_Response` | **Capital V** — matches the DB column name exactly. Contains transcribed voice text when customer sent a voice note |
| `aiResponse` | `String` | `ai_response` | AI outbound reply. Empty string when no AI reply exists |
| `managerResponse` | `String?` | `manager_response` | Human manager reply; null until a manager types |
| `label` | `String?` | `label` | Conversation label string set by automation or manager |
| `mediaUrl` | `String?` | `media_url` | Signed URL to media attachment |
| `mediaType` | `String?` | `media_type` | `'image'`, `'document'`, `'pdf'`, `'video'`, etc. |
| `mediaFilename` | `String?` | `media_filename` | Original filename for document attachments |
| `isVoiceFlag` | `bool` | `is_voice_message` | Explicit boolean from DB; defaults to `false` if null |
| `voiceNoteUrl` | `String?` | `voice_note_url` | URL to the actual audio file for playback |
| `sentBy` | `String?` | `sent_by` | `'manager'` when a human typed this row's outbound reply; `null` when AI-generated |
| `createdAt` | `DateTime` | `created_at` | Parsed from ISO-8601 string; falls back to `DateTime.now()` if null |

**`fromJson` parsing notes:**
- `voiceResponse` reads `json['Voice_Response']` — capital V is intentional and must not be changed to match DB column.
- `aiPhone` and `customerPhone`: `rawPhone?.toString()` because Supabase may return numeric columns as `int` in some query paths.
- `isVoiceFlag`: `json['is_voice_message'] as bool? ?? false` — explicit null guard.
- `createdAt`: falls back to `DateTime.now()` if `created_at` is null (defensive).

**`toJson`:** Emits `Voice_Response` (capital V) and omits `isVoiceFlag`, `voiceNoteUrl`, `sentBy` — these are not written back to the DB from this path.

**Computed properties:**

| Property | Type | Logic |
|----------|------|-------|
| `isVoiceMessage` | `bool` | `isVoiceFlag \|\| (voiceResponse != null && voiceResponse!.trim().isNotEmpty)` |
| `customerInput` | `String` | Returns `voiceResponse` if `isVoiceMessage` and `voiceResponse != null`; otherwise `customerMessage` |
| `hasMedia` | `bool` | `mediaUrl != null && mediaUrl!.isNotEmpty` |
| `isImage` | `bool` | `mediaType == 'image'` |
| `isDocument` | `bool` | `mediaType == 'document' \|\| mediaType == 'pdf'` |

---

### `Message`

**Source:** `lib/models/models.dart`  
**Represents:** A single display-layer message bubble in the chat UI. Built from `RawExchange` inside `ConversationsProvider.messages` getter. Each `RawExchange` can produce up to three `Message` objects (customer, AI, manager).

**Fields:**

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | Compound format: `'{exchangeId}_customer'`, `'{exchangeId}_ai'`, or `'{exchangeId}_manager'` |
| `content` | `String` | Text content of this bubble |
| `senderType` | `SenderType` | `customer`, `ai`, or `manager` |
| `isOutbound` | `bool` | `true` for `ai` and `manager`; `false` for `customer` |
| `senderName` | `String?` | Display name (customer name, or `'AI'`/`'Manager'`) |
| `createdAt` | `DateTime` | Timestamp |
| `isVoiceMessage` | `bool` | Forwarded from `RawExchange.isVoiceMessage` for voice bubbles |
| `voiceNoteUrl` | `String?` | Audio URL for playback widget |
| `label` | `String?` | Forwarded from exchange label |
| `mediaUrl` | `String?` | Media attachment URL |
| `mediaType` | `String?` | Media type string |
| `mediaFilename` | `String?` | Document filename |
| `replyToId` | `String?` | ID of quoted/replied-to message |
| `replyToMessage` | `Message?` | Inline nested quoted message object |

**Computed:**

| Property | Logic |
|----------|-------|
| `hasMedia` | `mediaUrl != null && mediaUrl!.isNotEmpty` |
| `isImage` | `mediaType == 'image'` |
| `isDocument` | `mediaType == 'document' \|\| mediaType == 'pdf'` |

`Message` has no `fromJson` — it is constructed programmatically in `ConversationsProvider._buildConversations()`.

---

### `Conversation`

**Source:** `lib/models/models.dart`  
**Represents:** A grouped summary of all exchanges for one `customer_phone`. Derived in `ConversationsProvider._buildConversations()` — never fetched directly from DB.

**Fields:**

| Field | Type | Notes |
|-------|------|-------|
| `customerPhone` | `String` | Primary key / group key |
| `customerName` | `String?` | From the most recent exchange with a non-null name |
| `lastMessage` | `String` | Preview text of the most recent exchange |
| `lastMessageAt` | `DateTime` | Timestamp of the most recent exchange |
| `status` | `ConversationStatus` | `needsReply` or `replied` — derived, never stored |
| `unreadCount` | `int` | Count of exchanges where `managerResponse` is null and `aiResponse` is empty (customer messages that have not received any reply yet) |
| `startedAt` | `DateTime` | Timestamp of the oldest exchange for this phone |
| `label` | `String?` | Label from the most recent exchange; null if no label |
| `broadcastLifecycleLabel` | `String?` | `'Sent'` / `'Needs Reply'` / `'Replied'` when the conversation was initiated by a broadcast; `null` otherwise |

**Computed:**

| Property | Logic |
|----------|-------|
| `displayName` | `customerName ?? customerPhone` |
| `id` | Alias for `customerPhone` |

**`copyWith` flags:** Two special boolean flags exist alongside the normal nullable overrides:
- `clearLabel: bool` (default `false`) — pass `true` to explicitly set `label` to null (needed because passing `label: null` to copyWith is ambiguous).
- `clearBroadcastLifecycleLabel: bool` (default `false`) — same pattern for `broadcastLifecycleLabel`.

**`broadcastLifecycleLabel` derivation** (implemented in `ConversationsProvider._buildConversations()`):
1. Null if the phone does not appear in `_broadcastRecipients` map.
2. `'Replied'` if any exchange after the broadcast `sentAt` timestamp has a non-empty `managerResponse`.
3. `'Needs Reply'` if a broadcast was sent but no human reply follows.
4. `'Sent'` as the initial state when the broadcast row exists but no customer response has come in yet.

---

### `MessageSearchResult`

**Source:** `lib/models/models.dart`  
**Represents:** A single search hit from full-text search across message exchanges.

| Field | Type | Notes |
|-------|------|-------|
| `customerPhone` | `String` | Phone of the matching conversation |
| `customerName` | `String?` | Customer name if known |
| `matchedText` | `String` | The text snippet that matched the query |
| `matchedField` | `String` | One of: `'customer_message'`, `'manager_response'`, `'name'`, `'phone'` |
| `date` | `DateTime` | Timestamp of the matching exchange |
| `exchangeId` | `String` | UUID of the matched `RawExchange` row |

**Computed:** `displayName` → `customerName ?? customerPhone`

---

### `ActivityLog`

**Source:** `lib/models/models.dart`  
**Represents:** One entry in the `activity_logs` Supabase table.

| Field | Type | DB column | Notes |
|-------|------|-----------|-------|
| `id` | `String` | `id` | UUID |
| `clientId` | `String?` | `client_id` | Null for Vivid admin actions |
| `userId` | `String?` | `user_id` | The user who performed the action |
| `userName` | `String` | `user_name` | Denormalized name; defaults to `'Unknown'` |
| `userEmail` | `String?` | `user_email` | Denormalized email |
| `actionType` | `ActionType` | `action_type` | Parsed via `ActionType.fromString()`; falls back to `login` |
| `description` | `String` | `description` | Human-readable description of the action |
| `metadata` | `Map<String, dynamic>` | `metadata` | JSONB; defaults to `{}` |
| `createdAt` | `DateTime` | `created_at` | Falls back to `DateTime.now()` if null |

**`toJson`:** Emits all fields. **`getMetadata(key)`** — convenience helper that returns `metadata[key]?.toString()`.

---

### `AppUser`

**Source:** `lib/models/models.dart`  
**Represents:** A logged-in user (either a Vivid super admin or a per-client user).

**Fields:**

| Field | Type | DB column | Notes |
|-------|------|-----------|-------|
| `id` | `String` | `id` | UUID |
| `email` | `String` | `email` | Login email |
| `name` | `String` | `name` | Display name |
| `role` | `UserRole` | `role` | Parsed via `UserRole.fromString()`; falls back to `viewer` |
| `clientId` | `String?` | `client_id` | `null` for Vivid super admins |
| `createdAt` | `DateTime` | `created_at` | Falls back to `DateTime.now()` if null |
| `customPermissions` | `Set<Permission>?` | `custom_permissions` | JSONB array of permission strings; `null` means "use role defaults only" |
| `revokedPermissions` | `Set<Permission>?` | `revoked_permissions` | Explicitly denied permissions; takes priority over both custom grants and role defaults |
| `password` | `String?` | `password` | Plaintext; only populated in client admin user-management context — never used for auth |
| `status` | `String` | `status` | `'active'` or `'blocked'`; defaults to `'active'` |

**Computed properties:**

| Property | Logic |
|----------|-------|
| `isVividAdmin` | `role == admin && clientId == null` |
| `isClientAdmin` | `role == admin && clientId != null` |
| `isAdmin` | `role == admin` |
| `isBlocked` | `status == 'blocked'` |
| `hasCustomPermissions` | `customPermissions` non-empty OR `revokedPermissions` non-empty |
| `isReadOnly` | `role == viewer && !hasCustomPermissions` |
| `canManageUsers` | `hasPermission(manageUsers)` |
| `canSendMessages` | `hasPermission(sendMessages)` |
| `canSendBroadcasts` | `hasPermission(sendBroadcasts)` |
| `initials` | Delegates to `getInitials(name)` utility |

**`hasPermission(Permission permission)` logic — three-tier priority:**
1. Vivid admins short-circuit: always `true`.
2. If `revokedPermissions` contains `permission` → `false`.
3. If `customPermissions` contains `permission` → `true`.
4. Fall back to `Permissions.hasPermission(role, permission)` (role matrix lookup).

**`effectivePermissions`:** Starts with role defaults, adds all custom grants, removes all revoked. Vivid admins return all 13 permissions.

**`copyWith` flags:** `clearCustomPermissions: bool` and `clearRevokedPermissions: bool` allow explicit null-out of permission sets.

**`fromJson` notes:**
- `customPermissions` / `revokedPermissions`: `Permission.fromStringList(json[key] as List)` — silently drops unrecognised strings.
- `password` is read as-is from the DB row (plaintext; not used for auth).

**`toJson`:** Omits `custom_permissions` / `revoked_permissions` keys entirely when the sets are null or empty (avoids writing empty arrays to DB).

---

### `ClientConfig` (static non-ChangeNotifier)

**Source:** `lib/models/models.dart`  
**Purpose:** Process-wide singleton holding the currently active client context. Mutated by `AgentProvider` on login/logout and by `AdminProvider` during impersonation. Not a `ChangeNotifier` — consumers read it synchronously; state changes propagate through provider `notifyListeners()` calls in the owning providers.

**Private state:**

| Field | Type | Notes |
|-------|------|-------|
| `_currentClient` | `Client?` | Active client; `null` for Vivid admin with no preview |
| `_currentUser` | `AppUser?` | Active user |
| `_isPreviewMode` | `bool` | True while admin is impersonating a client |
| `_savedAdminUser` | `AppUser?` | Real admin user saved on first `enterPreview()` call |
| `_previewClientId` | `String?` | Client ID of the active preview; used by `exitPreview` stale-call guard |
| `_onEnterPreviewCredentials` | `void Function(Client)?` | Registered by `SupabaseService` to swap API keys on enter |
| `_onExitPreviewCredentials` | `void Function()?` | Registered by `SupabaseService` to restore API keys on exit |

**Key static getters (selection):**

| Getter | Returns |
|--------|---------|
| `currentClient` | `Client?` |
| `currentUser` | `AppUser?` |
| `isVividAdmin` | `bool` |
| `isPreviewMode` | `bool` |
| `messagesTable` | `String?` — `_currentClient?.messagesTable` |
| `broadcastsTable` | `String?` |
| `templatesTable` | `String?` |
| `managerChatsTable` | `String?` |
| `broadcastRecipientsTable` / `broadcastRecipientsTableName` | `String?` (two aliases for same field) |
| `aiSettingsTable` / `aiSettingsTableName` | `String?` (two aliases) |
| `customerPredictionsTable` / `customerPredictionsTableName` | `String?` (two aliases) |
| `queryResultsTable` | `String?` |
| `managerChatsTableName` | `String` — **throws** if null/empty |
| `conversationsPhone` | `String?` — falls back to `businessPhone` |
| `broadcastsPhone` | `String?` — falls back to `businessPhone` |
| `conversationsWebhookUrl` | `String?` — falls back to `webhookUrl` |
| `broadcastsWebhookUrl` | `String?` — falls back to `webhookUrl` |
| `managerChatWebhookUrl` | `String?` — falls back to `webhookUrl` |
| `hasAiConversations` | `bool` |
| `productType` | `String` — `'retention'` or `'chatbot'`; defaults to `'retention'` |
| `isChatbotClient` | `bool` — `productType == 'chatbot'` |
| `isSharedWaba` | `bool` |
| `isConversationsConfigured` | `bool` — phone + table both non-empty |
| `isBroadcastsConfigured` | `bool` — (phone or webhook) + table both non-empty |

**`hasFeature(feature)`:** Returns `true` for Vivid admins unconditionally. Otherwise checks `enabledFeatures.contains(feature)` AND the user's relevant `hasPermission()` for features mapped to permissions (`conversations`, `broadcasts`, `analytics`, `manager_chat`, `user_management`). All other feature strings pass the permission check automatically.

**`enterPreview(client, tempUser)`:** Only saves `_savedAdminUser` on the first enter (i.e., when `_isPreviewMode == false`). Sequential client switches while already in preview do not overwrite `_savedAdminUser` with a temp user — preventing the real admin from being lost.

**`exitPreview({String? clientId})`:** If `clientId != null` and `_previewClientId != clientId`, the call is a stale dispose() from a widget that was replaced by a newer preview — returns early without restoring context.

**Mutation methods:** `setClientUser(client, user)`, `setAdmin(user)`, `enterPreview(client, tempUser)`, `exitPreview({clientId})`, `clear()`.

---

### `Client`

**Source:** `lib/models/models.dart`  
**Represents:** One row from the `clients` Supabase table.

**Fields:**

| Field | Type | DB column | Notes |
|-------|------|-----------|-------|
| `id` | `String` | `id` | UUID |
| `name` | `String` | `name` | Display name |
| `slug` | `String` | `slug` | Short identifier; used as table-name prefix (e.g., `karisma_messages`) |
| `webhookUrl` | `String?` | `webhook_url` | Legacy fallback webhook |
| `enabledFeatures` | `List<String>` | `enabled_features` | JSONB array of feature name strings |
| `businessPhone` | `String?` | `business_phone` | Legacy fallback phone; stored as NUMERIC, parsed with `.toString()` |
| `messagesTable` | `String?` | `messages_table` | e.g., `'karisma_messages'` |
| `broadcastsTable` | `String?` | `broadcasts_table` | e.g., `'karisma_broadcasts'` |
| `bookingsTable` | `String?` | `bookings_table` | Optional; only for booking-enabled clients |
| `templatesTable` | `String?` | `templates_table` | e.g., `'karisma_whatsapp_templates'` |
| `managerChatsTable` | `String?` | `manager_chats_table` | e.g., `'karisma_manager_chats'` |
| `broadcastRecipientsTable` | `String?` | `broadcast_recipients_table` | e.g., `'karisma_broadcast_recipients'` |
| `aiSettingsTable` | `String?` | `ai_settings_table` | e.g., `'threeBs_ai_chat_settings'` |
| `customerPredictionsTable` | `String?` | `customer_predictions_table` | e.g., `'HOB_customer_predictions'`; only HOB has this |
| `queryResultsTable` | `String?` | `query_results_table` | e.g., `'hob_query_results'`; only HOB |
| `wabaId` | `String?` | `waba_id` | Per-client WABA override; overrides global default when non-null |
| `metaAccessToken` | `String?` | `meta_access_token` | Per-client Meta API token override |
| `conversationsPhone` | `String?` | `conversations_phone` | Feature-specific phone; falls back to `businessPhone` |
| `conversationsWebhookUrl` | `String?` | `conversations_webhook_url` | Feature-specific webhook |
| `broadcastsPhone` | `String?` | `broadcasts_phone` | Feature-specific phone |
| `broadcastsWebhookUrl` | `String?` | `broadcasts_webhook_url` | Feature-specific webhook |
| `remindersPhone` | `String?` | `reminders_phone` | For reminders feature |
| `remindersWebhookUrl` | `String?` | `reminders_webhook_url` | For reminders feature |
| `managerChatWebhookUrl` | `String?` | `manager_chat_webhook_url` | n8n AI manager webhook |
| `broadcastLimit` | `int?` | `broadcast_limit` | Monthly cap; null = unlimited |
| `rolloverBalance` | `int` | `rollover_balance` | Unused messages from previous month; set by `process_monthly_rollover()` pg_cron |
| `productType` | `String` | `product_type` | `'retention'` (default) or `'chatbot'` |
| `predictionsRefreshWebhookUrl` | `String?` | `predictions_refresh_webhook_url` | n8n webhook to trigger prediction recalculation |
| `hasAiConversations` | `bool` | `has_ai_conversations` | Defaults to `true` |
| `isSharedWaba` | `bool` | `is_shared_waba` | Auto-set by Supabase trigger when clients share a WABA ID |
| `createdAt` | `DateTime` | `created_at` | |

**Computed:**

| Property | Logic |
|----------|-------|
| `effectiveLimit` | `(broadcastLimit ?? 0) + rolloverBalance` |

**Methods:**

```dart
bool hasFeature(String feature)
// Returns enabledFeatures.contains(feature).

String? getPhoneForFeature(String feature)
// 'conversations' → conversationsPhone ?? businessPhone
// 'broadcasts'    → broadcastsPhone ?? businessPhone
// default         → businessPhone

String? getWebhookForFeature(String feature)
// 'conversations' → conversationsWebhookUrl ?? webhookUrl
// 'broadcasts'    → broadcastsWebhookUrl ?? webhookUrl
// 'manager_chat'  → managerChatWebhookUrl ?? webhookUrl
// default         → webhookUrl
```

**`fromJson` notes:**
- All phone fields: `rawPhone?.toString()` to handle NUMERIC DB storage.
- `enabledFeatures`: guarded with `?? []` in case column is null.
- `rolloverBalance`: `?? 0` default.
- `isSharedWaba`: `?? false` default.

---

### `WhatsAppTemplate`

**Source:** `lib/models/models.dart`  
**Represents:** One WhatsApp Business template, populated either from a Supabase row or directly from the Meta Graph API response.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | DB row UUID (or Meta template ID when fetching from API) |
| `name` | `String` | Template name as registered in Meta |
| `displayName` | `String?` | Friendly name stored in the DB `display_name` column |
| `status` | `String` | `'APPROVED'`, `'PENDING'`, `'REJECTED'`, etc. |
| `language` | `String` | e.g., `'en_US'`, `'ar'` |
| `category` | `String` | `'MARKETING'`, `'UTILITY'`, `'AUTHENTICATION'` |
| `headerType` | `String` | `'TEXT'`, `'IMAGE'`, `'VIDEO'`, `''` (none) |
| `headerText` | `String?` | Text content when `headerType == 'TEXT'` |
| `headerMediaUrl` | `String?` | Sample media handle URL when `headerType == 'IMAGE'` or `'VIDEO'` |
| `body` | `String` | Template body text (may contain `{{1}}` placeholders) |
| `footer` | `String?` | Footer text |
| `buttons` | `List<TemplateButton>` | CTA or Quick Reply buttons |
| `componentsJson` | `List<dynamic>` | Raw `components` array from Meta API response; preserved for re-sending |
| `targetSheet` | `String?` | Google Sheets tab name for variable population |

**`label` computed getter:** Returns `displayName` if non-empty; falls back to `name`.

**`fromJson` component parsing:**
- Iterates `components` array.
- `'HEADER'` component: reads `format` for `headerType`; if `'TEXT'` reads `text`; if `'IMAGE'`/`'VIDEO'` reads `example.header_handle[0]` for `headerMediaUrl`.
- `'BODY'` component: reads `text` for `body`.
- `'FOOTER'` component: reads `text` for `footer`.
- `'BUTTONS'` component: maps `buttons` array through `TemplateButton.fromJson`.

---

### `TemplateButton`

**Source:** `lib/models/models.dart`

| Field | Type | Notes |
|-------|------|-------|
| `type` | `String` | `'QUICK_REPLY'`, `'URL'`, `'PHONE_NUMBER'`, `'COPY_CODE'` |
| `text` | `String` | Button label text |

Both fields default to `''` if null in JSON.

---

### `Agent`

**Source:** `lib/models/models.dart`  
Simple UI display model for showing manager/agent names and avatars.

| Field | Type |
|-------|------|
| `name` | `String` |
| `email` | `String` |

**Computed:** `initials` → `getInitials(name)`.

---

### `CustomerProfileStats`

**Source:** `lib/models/models.dart`  
Aggregate stats shown in the customer profile side panel.

| Field | Type | Notes |
|-------|------|-------|
| `totalExchanges` | `int` | Total message rows for this customer |
| `customerMessageCount` | `int` | Inbound messages only |
| `agentMessageCount` | `int` | Manager/human replies only |
| `broadcastCount` | `int` | Number of broadcast campaigns that included this customer |
| `broadcastResponseRate` | `double` | Fraction of broadcasts they responded to |
| `lastContactedAt` | `DateTime?` | Most recent exchange timestamp |
| `lastCampaignAt` | `DateTime?` | Most recent broadcast sent to this customer |
| `labelsHistory` | `List<String>` | All distinct labels ever assigned to exchanges for this phone |
| `lastHandledBy` | `String?` | `sentBy` value from the most recent exchange with a manager reply |

No `fromJson` — constructed programmatically in `SupabaseService`.

---

### `CustomerPrediction`

**Source:** `lib/models/models.dart`  
**Represents:** One row from the `{slug}_customer_predictions` table (currently only HOB).

| Field | Type | DB column | Notes |
|-------|------|-----------|-------|
| `phone` | `String` | `phone` | Customer phone |
| `customerName` | `String?` | `customer_name` | |
| `totalVisits` | `int` | `total_visits` | Defaults to `0` |
| `lastVisit` | `DateTime?` | `last_visit` | Nullable ISO-8601 |
| `daysSinceLastVisit` | `int` | `days_since_last_visit` | Defaults to `0` |
| `primaryService` | `String?` | `primary_service` | Most frequently booked service |
| `lastService` | `String?` | `last_service` | Service from the most recent visit |
| `avgGapDays` | `int` | `avg_gap_days` | Average days between visits; defaults to `0` |
| `predictedNextVisit` | `DateTime?` | `predicted_next_visit` | ML-predicted next visit date |
| `daysUntilPredicted` | `int` | `days_until_predicted` | Days from today to `predictedNextVisit`; negative = overdue |
| `category` | `String` | `category` | One of: `'New'`, `'Returning'`, `'Regular'`, `'At Risk'`, `'Lapsed'` |

---

### `PredictionStats`

**Source:** `lib/models/models.dart`  
Aggregate counts computed from the predictions table, displayed in the AI manager panel sidebar.

| Field | Type | Notes |
|-------|------|-------|
| `overdueCount` | `int` | Customers whose `predictedNextVisit` is in the past |
| `thisWeekCount` | `int` | Predicted visits in the next 7 days |
| `thisMonthCount` | `int` | Predicted visits in the next 30 days |
| `serviceBreakdown` | `Map<String, int>` | Count per `primaryService` string |

**`PredictionStats.empty()`** — static factory returning all-zero instance.

---

### `Broadcast`

**Source:** `lib/providers/broadcasts_provider.dart` (not `models.dart`)  
**Represents:** One row from a `{slug}_broadcasts` table.

| Field | Type | DB column | Notes |
|-------|------|-----------|-------|
| `id` | `String` | `id` | `?.toString()` for numeric-safe parse |
| `clientId` | `String?` | `client_id` | |
| `campaignName` | `String?` | `campaign_name` | |
| `messageContent` | `String?` | `message_content` | Template body with variables filled in |
| `photo` | `String?` | `photo` | Media URL for image-header broadcasts |
| `sentAt` | `DateTime` | `sent_at` | `DateTime.parse()` — required field |
| `totalRecipients` | `int` | `total_recipients` | Int-safe parse: tries `as int` first, then `int.tryParse(toString)` |
| `status` | `String?` | `status` | `'scheduled'`, `'sending'`, `'sent'`, `'failed'` |
| `scheduledAt` | `DateTime?` | `scheduled_at` | `DateTime.parse()` if non-null |
| `webhookPayload` | `Map<String, dynamic>?` | `webhook_payload` | JSONB; only set when broadcast has a pre-built payload |

`Broadcast` does NOT include `templateName` or `offerAmount` fields — those are in the `BroadcastAnalyticsProvider`'s own raw-map pass (reads `offer_amount` directly from the JSON without a typed model).

---

### `BroadcastRecipient`

**Source:** `lib/providers/broadcasts_provider.dart` (not `models.dart`)  
**Represents:** One row from a `{slug}_broadcast_recipients` table.

| Field | Type | DB column | Notes |
|-------|------|-----------|-------|
| `id` | `String` | `id` | `?.toString()` safe |
| `broadcastId` | `String?` | `broadcast_id` | FK to broadcasts table |
| `customerPhone` | `String?` | `customer_phone` | `.toString()` safe |
| `customerName` | `String?` | `customer_name` | |
| `messageSent` | `String?` | `message_sent` | Actual text sent to this recipient |
| `status` | `String?` | `status` | `null`, `'accepted'`, `'sent'`, `'delivered'`, `'read'`, `'failed'` |
| `wamid` | `String?` | `wamid` | WhatsApp message ID from Meta |
| `deliveredAt` | `DateTime?` | `delivered_at` | Nullable; set by webhook |
| `readAt` | `DateTime?` | `read_at` | Nullable; set by webhook |
| `errorCode` | `String?` | `error_code` | `.toString()` safe |
| `errorMessage` | `String?` | `error_message` | `.toString()` safe |
| `replyText` | `String?` | `reply_text` | Customer's reply if they responded |
| `repliedAt` | `DateTime?` | `replied_at` | Timestamp of reply |
| `amountPaid` | `double?` | `amount_paid` | Revenue attribution; `(json['amount_paid'] as num?)?.toDouble()` |
| `paidAt` | `DateTime?` | `paid_at` | When payment was recorded |

**Computed:** `displayName` → `customerName ?? customerPhone ?? 'Unknown'`

**Status semantics** (used by `BroadcastsProvider` getters):
- `recipientsSent`: `status == 'sent' || status == 'accepted'`
- `recipientsDelivered`: `status == 'delivered'`
- `recipientsRead`: `status == 'read'`
- `recipientsFailed`: `status == 'failed'`

**Status semantics** (used by `BroadcastAnalyticsProvider` for aggregate counts):
- `'failed'` → failed
- `'read'` → read + delivered (read implies delivered)
- everything else (null, `'accepted'`, `'sent'`, `'delivered'`) → delivered only

---

### `FinancialTransaction`

**Source:** `lib/models/financial_models.dart`

| Field | Type | DB column | Notes |
|-------|------|-----------|-------|
| `id` | `String` | `id` | `?? ''` safe |
| `clientId` | `String?` | `client_id` | |
| `clientName` | `String?` | (joined) | Populated from `json['clients']['name']` when select includes `.select('*, clients(name)')` |
| `type` | `TransactionType` | `type` | `TransactionType.fromDb()` |
| `category` | `String?` | `category` | Free-text from `FinancialCategories` lists |
| `amount` | `double` | `amount` | `(json['amount'] as num?)?.toDouble() ?? 0.0` |
| `currency` | `String` | `currency` | Defaults to `'BHD'` |
| `description` | `String?` | `description` | |
| `invoiceNumber` | `String?` | `invoice_number` | |
| `paymentStatus` | `PaymentStatus` | `payment_status` | `PaymentStatus.fromDb()` |
| `dueDate` | `DateTime?` | `due_date` | `DateTime.tryParse()` |
| `paidDate` | `DateTime?` | `paid_date` | `DateTime.tryParse()` |
| `recurring` | `bool` | `recurring` | Defaults to `false` |
| `recurringInterval` | `String?` | `recurring_interval` | e.g., `'monthly'` |
| `metadata` | `Map<String, dynamic>?` | `metadata` | JSONB |
| `createdBy` | `String?` | `created_by` | User ID |
| `createdAt` | `DateTime` | `created_at` | Falls back to `DateTime.now()` |
| `updatedAt` | `DateTime?` | `updated_at` | `DateTime.tryParse()` |

**`toInsertJson()`:** Excludes `id`, `created_at`, `updated_at`; includes conditional fields only when non-null.

**`fromJson` note:** `clientName` is read from the nested join result: `if (json['clients'] is Map) clientName = (json['clients'] as Map)['name']`. This avoids a `String` cast error when the join is absent.

---

### Enums — `financial_models.dart`

#### `TransactionType`

| Value | `.dbValue` | `.label` |
|-------|-----------|---------|
| `income` | `'income'` | `'Income'` |
| `expense` | `'expense'` | `'Expense'` |

`fromDb(null)` defaults to `income`.

#### `PaymentStatus`

| Value | `.dbValue` | `.label` |
|-------|-----------|---------|
| `pending` | `'pending'` | `'Pending'` |
| `paid` | `'paid'` | `'Paid'` |
| `overdue` | `'overdue'` | `'Overdue'` |
| `cancelled` | `'cancelled'` | `'Cancelled'` |

`fromDb(null)` defaults to `pending`.

#### `DateRangePreset`

| Value | `.label` |
|-------|---------|
| `thisMonth` | `'This Month'` |
| `lastMonth` | `'Last Month'` |
| `thisQuarter` | `'This Quarter'` |
| `thisYear` | `'This Year'` |
| `allTime` | `'All Time'` |
| `custom` | `'Custom'` |

#### `FinancialCategories` (static class)

Income categories: `'Monthly Subscription'`, `'Setup Fee'`, `'Custom Development'`, `'Broadcast Credits'`, `'Other'`.

Expense categories: `'Server Costs'`, `'API Costs'`, `'Software'`, `'Marketing'`, `'Staff'`, `'Other'`.

---

### `OutreachContact`

**Source:** `lib/models/outreach_models.dart`  
**Represents:** One CRM prospect/client in the outreach module (table: `vivid_outreach_contacts`).

| Field | Type | DB column | Notes |
|-------|------|-----------|-------|
| `id` | `String` | `id` | `?? ''` safe |
| `companyName` | `String` | `company_name` | Required; `?? ''` safe |
| `contactName` | `String?` | `contact_name` | Optional person's name |
| `phone` | `String` | `phone` | `?.toString()` safe |
| `email` | `String?` | `email` | |
| `industry` | `String?` | `industry` | |
| `status` | `ContactStatus` | `status` | `ContactStatus.fromDb()`; defaults to `lead` |
| `notes` | `String?` | `notes` | |
| `tags` | `List<String>` | `tags` | JSONB array; parsed via `rawTags.map((e) => e.toString()).toList()` |
| `lastContactedAt` | `DateTime?` | `last_contacted_at` | `DateTime.tryParse()` |
| `createdAt` | `DateTime` | `created_at` | Falls back to `DateTime.now()` |

**Computed:** `displayName` → `contactName ?? companyName`

**`toInsertJson()`:** Excludes `id`, `created_at`, `last_contacted_at`.

---

### `OutreachMessage`

**Source:** `lib/models/outreach_models.dart`  
**Represents:** One row from `vivid_outreach_messages`. Structurally mirrors `RawExchange` but adds `contactId`, `direction`, and `content`.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | |
| `contactId` | `String?` | FK to outreach_contacts |
| `aiPhone` | `String?` | Business phone |
| `customerPhone` | `String` | `.toString()` safe |
| `customerName` | `String?` | |
| `customerMessage` | `String` | Defaults to `''` |
| `aiResponse` | `String?` | |
| `managerResponse` | `String?` | |
| `sentBy` | `String?` | `'manager'` or `'ai'` |
| `direction` | `String?` | `'inbound'` or `'outbound'` |
| `content` | `String?` | Used by broadcast/template rows that don't fit the exchange structure |
| `label` | `String?` | |
| `mediaUrl` | `String?` | |
| `mediaType` | `String?` | |
| `mediaFilename` | `String?` | |
| `createdAt` | `DateTime` | Falls back to `DateTime.now()` |

**Computed:**

| Property | Logic |
|----------|-------|
| `displayText` | Returns first non-empty of: `managerResponse`, `aiResponse`, `content`, `customerMessage` |
| `isOutbound` | `sentBy == 'manager' \|\| sentBy == 'ai' \|\| direction == 'outbound'` |

---

### `OutreachBroadcast`

**Source:** `lib/models/outreach_models.dart`  
Broadcast campaign for the outreach module (table: `vivid_outreach_broadcasts`).

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | |
| `name` | `String?` | Campaign name |
| `templateName` | `String?` | WhatsApp template used |
| `messageBody` | `String?` | Text body |
| `status` | `String?` | `'scheduled'`, `'sent'`, `'failed'` |
| `scheduledAt` | `DateTime?` | `DateTime.tryParse()` |
| `sentAt` | `DateTime?` | `DateTime.tryParse()` |
| `totalRecipients` | `int` | Defaults to `0` |
| `deliveredCount` | `int` | Defaults to `0` |
| `failedCount` | `int` | Defaults to `0` |
| `createdAt` | `DateTime` | Falls back to `DateTime.now()` |

**Computed:** `displayName` → `name ?? templateName ?? 'Untitled'`

---

### `OutreachBroadcastRecipient`

**Source:** `lib/models/outreach_models.dart`

| Field | Type | Notes |
|-------|------|-------|
| `id` | `String` | |
| `broadcastId` | `String?` | |
| `contactId` | `String?` | |
| `phone` | `String?` | |
| `name` | `String?` | |
| `status` | `String?` | |
| `sentAt` | `DateTime?` | |
| `deliveredAt` | `DateTime?` | |

---

### Enums — `outreach_models.dart`

#### `ContactStatus`

CRM pipeline stages. DB values use snake_case; Dart values use camelCase.

| Dart value | `.dbValue` | `.label` |
|------------|-----------|---------|
| `lead` | `'lead'` | `'Lead'` |
| `contacted` | `'contacted'` | `'Contacted'` |
| `interested` | `'interested'` | `'Interested'` |
| `meetingScheduled` | `'meeting_scheduled'` | `'Meeting'` |
| `proposalSent` | `'proposal_sent'` | `'Proposal'` |
| `client` | `'client'` | `'Client'` |
| `lost` | `'lost'` | `'Lost'` |

`fromDb(null)` defaults to `lead`.

---

## 12. Recently Shipped Features (Last 60 Days)

The following is derived from `git log --since="2026-03-09"` (approximately 60 days before the audit date of 2026-05-08). ~50 commits are relevant.

### Conversation pagination (Phase 1) — 2026-05-04

**Commits:** `6fa2e81`, `f33f747` (reverted), `6a4629e` (revert), `6fa2e81` (re-landed)  
**Migration:** `20260504_conversation_pagination.sql`

- Replaced full-table conversation load with paginated RPC:
  - `get_latest_customer_phones` returns 100 phones at a time with `OFFSET`.
  - Infinite scroll loads next page on demand.
- Added `get_conversation_count` RPC for accurate total counter in header (not capped at 100).
- Added `get_needs_reply_count` / `get_needs_reply_phones` RPCs for the needs-reply filter.
- `_phonesBeingFetched` guard prevents concurrent duplicate fetches.
- `seedExchangeCache()` ensures realtime base state is populated from initial load.

**Known regression:** `get_latest_customer_phones` and `get_conversation_count` are hardcoded to `karisma_messages` — other clients will not work correctly.

### Monthly broadcast quota rollover — 2026-04-29

**Commit:** `ab00506`  
**Migration:** `20260429_broadcast_rollover.sql`

- Added `rollover_balance INT NOT NULL DEFAULT 0` to `clients`.
- Created `client_quota_history` table for month-by-month audit trail.
- Created `process_monthly_rollover()` PostgreSQL function.
- Unused quota (up to 1× base limit) is carried forward each month.
- `effectiveLimit` getter = `broadcastLimit + rolloverBalance`.

### Analytics broadcast count fix — 2026-05-04

**Commit:** `838453c`

- `BroadcastsProvider.fetchBroadcasts()` now enriches each broadcast with actual recipient counts via parallel COUNT queries, bypassing the silent 1000-row cap that affected the old single-fetch path.

### Broadcast analytics RPC (unused) — 2026-04-30

**Migration:** `20260430_broadcast_analytics_rpc.sql`  
- Defined `get_broadcast_analytics_aggregates()` RPC with dynamic SQL.
- Not yet used by the Flutter app — `BroadcastAnalyticsProvider` still does client-side aggregation.

### Broadcast reply/payment attribution — 2026-04-18

**Migration:** `20260418_broadcast_reply_payment.sql`

- Added `reply_text`, `replied_at`, `amount_paid`, `paid_at` columns to `karisma_broadcast_recipients`.
- Added `trg_populate_broadcast_reply` trigger: attributes first inbound reply within 72-hour window to the most recent eligible broadcast recipient.

### Template scroll fix — 2026-05-08 (most recent)

**Commit:** `917e094`

- Template list scroll is now isolated from the broadcast send popup's scroll context, preventing UI jank when the template popup is open.

### QueryResultService dynamic table — 2026-05-03

**Commits:** `2bd08da`, `21a25c6`

- `QueryResultService` table name now reads from `ClientConfig.queryResultsTable` instead of hardcoded `'hob_query_results'`.
- "Send Offer" action now opens the broadcast compose dialog directly.
- HOB and Vivid Demo scheduling now work correctly.

### CORS fix via Edge Function proxy — 2026-03-xx

**Commit:** `394ad97`

- All n8n webhook calls on web now route through `proxy-webhook` Supabase Edge Function.
- Eliminates CORS errors on production web builds.

### Template images + preserve offer_image_url — 2026-03-xx

**Commits:** `9818827`, `feb79b0`

- Template image upload flow proxied through Edge Function (Step 1 of Meta two-step upload).
- Sync preserves `offer_image_url` from DB; strips scontent/fbcdn CDN URLs that Meta removes.

### Mobile responsive layout — 2026-03-xx

**Commit:** `70ce59f`

- Sidebar collapses to icon-only at `<900px`.
- Bottom navigation bar replaces sidebar at `<600px`.
- Impersonation events hidden from client activity log views.
- WABA contamination prevention during template sync for shared-WABA clients.

### Analytics attribution fixes — 2026-03-xx

**Commits:** `75f14fe`, various `save` commits

- Attribution window fixed at 168 hours (7 days).
- Default date range changed from `last30Days` to `allTime`.
- `enterPreview` now triggers a fresh data fetch for the impersonated client.

### Broadcast system overhaul — 2026-03-xx

**Commits:** `68f024a`, `484493a`, `4d92b96`

- All broadcast paths now route through the compose dialog with template selector.
- Merge node removed from n8n payload path.
- `template_name` and `target_sheet` now correctly passed from all broadcast entry points.

### Broadcast Intelligence panel — 2026-03-xx

**Commit:** `13675c3`

- New analytics panel showing per-broadcast reply rate, revenue attribution, and delivery funnel.
- Template pipeline hardening.
- Preview mode improvements.

---

## 13. Known Issues and Tech Debt

### Critical security issues (from March 2026 audit — do NOT fix without Omar's approval)

1. **Service role key in source code** (`supabase_service.dart` ~line 30): The `_supabaseServiceRoleKey` JWT string is a hardcoded constant compiled into the web bundle. Anyone who loads the app and inspects the JavaScript source (or source maps) can extract this key and make direct authenticated requests to Supabase bypassing all RLS.

2. **Plaintext password fallback** (`supabase_service.dart:197–285`): When `login_user` RPC throws a non-blocking error, the code falls back to `SELECT * FROM users WHERE email = ? AND password = ?` (plaintext comparison over the anon client). This means: (a) plaintext passwords traverse the wire without hashing, and (b) the `users.password` column stores cleartext for users who have never reset their password via the admin panel.

3. **Dual password storage**: Some accounts may have `password` (plaintext) but no `password_hash`, while accounts updated via admin wizard have both. No migration exists to force-hash all existing plaintext passwords.

4. **`users` table accessible via anon key**: The plaintext fallback SELECT works against the `users` table over the anon key. This implies `users` either has no RLS, or has RLS that permits reading matching rows via anon. Either way is a security concern.

5. **Cross-client notification leak**: `notifications_channel` in `NotificationProvider` has no client-specific filter. All clients in the same Supabase project receive each other's notification events.

### High priority tech debt

6. **`get_latest_customer_phones` hardcoded to `karisma_messages`**: The conversation pagination RPC is hardcoded to one client's table. The `p_ai_phone` filter is applied, so data isolation is maintained, but HOB and other clients cannot use this RPC. The function must be parameterized to accept a `p_table_name text` argument, or separate functions must be created per client.

   Same issue applies to: `get_conversation_count`, and presumably `get_needs_reply_count` / `get_needs_reply_phones`.

7. **`20260504_needs_reply_pagination.sql` is empty**: The file contains only the placeholder text `[paste the same SQL above]`. The needs-reply RPCs referenced in `supabase_service.dart` were either deployed manually or are not actually running in production. If they are absent, `activateNeedsReplyFilter()` will throw a Supabase RPC-not-found error.

8. **`AnalyticsProvider` dead code**: `lib/providers/analytics_provider.dart` (with `AnalyticsData` model) and the corresponding `SupabaseService.fetchAnalytics()` method are not connected to any active UI. `analytics_screen.dart` uses `RoiAnalyticsProvider` and `ChatbotAnalyticsProvider` instead. The file should be removed to avoid confusion.

9. **`fetchAnalytics()` in `supabase_service.dart` (line 1551–1554) hits the 1000-row Supabase cap**: `client.from(tableName).select().eq('ai_phone', businessPhone)` — no `.range()` pagination. Since this path is currently dead code, it is not an active bug, but if re-activated it would silently truncate results for any client with more than 1000 messages.

10. **`_fetchConversationsAnalytics()` in `analytics_provider.dart` (line ~53) same issue**: Same uncapped fetch, same dead-code status.

11. **`BroadcastAnalyticsProvider` does not use the analytics RPC**: `get_broadcast_analytics_aggregates` was specifically built to avoid client-side aggregation of large recipient sets, but `broadcast_analytics_provider.dart` still fetches all recipients in a paginated loop and computes counts in Dart. For clients with many thousands of recipients, this is slow and memory-intensive.

12. **`QueryResultService` uses anon client**: `query_result_service.dart` uses `SupabaseService.client` (anon key) rather than `adminClient`. If the `{slug}_query_results` table has RLS policies that restrict anon access, reads will silently return empty. This is inconsistent with every other per-client table access pattern.

13. **All 16 providers instantiated at startup**: Even providers for features a client has not enabled (e.g., `OutreachProvider` for a client without outreach) are created at app start. This adds unnecessary memory and may trigger premature initialization side effects.

14. **Broadcast quota enforcement is client-side only**: Nothing in the database or n8n prevents sending more messages than `effectiveLimit`. A determined user could bypass the client-side check by manipulating the app state.

15. **`create_client_tables` RPC called twice in wizard**: `admin_panel.dart` calls it at lines 3372 and 3440. UNCLEAR if both are intentional (initial create vs. retry) or if one is a duplicate that could fail with "table already exists" errors on retry.

16. **`dart:html` legacy import in three files**: `notification_provider.dart`, `analytics_exporter.dart`, `audio_controller.dart` use `import 'dart:html' as html`. This is deprecated in favor of `package:web/web.dart`. The app compiles because `dart:html` is still supported but will break in future Flutter/Dart SDK updates. `agent_provider.dart` and `conversations_provider.dart` have already migrated to `package:web`.

17. **No error boundary / global error handler**: Uncaught exceptions in async provider methods set `_error` strings but there is no global error reporting or crash analytics integration visible in the code.

18. **Session does not persist across tab close**: `window.sessionStorage` is cleared on tab close. Users must log in again in a new tab. `window.localStorage` would provide persistent login but was not chosen — UNCLEAR if intentional for security reasons.

19. **Password reset code generated client-side**: The 6-digit reset code is generated using `Random()` (not `Random.secure()`) in `login_screen.dart`. This is a weak source of randomness for a security-sensitive code.

20. **Vivid Analytics Feedback backlog** (from `Vivid_Analytics_Feedback_Final.md`):
    - Revenue and booking metrics need to be separated in ROI display.
    - Compare feature needs redesign.
    - Metric box descriptions and arrow colors are unclear.
    - Employee performance cards need uniform sizing.
    - Action required list needs implementation.
    - Engagement rate definition is unclear to users.
    - Chart improvements requested (axis labels, tooltips).
    - Loading states needed throughout analytics screens.
    - Funnel visualization requested.
    - Real-time indicators needed.

---

## 14. Deployment and Environment

### Build target

Flutter Web only. The app is not configured for mobile or desktop targets based on available evidence.

Build command (from project context):
```bash
flutter build web --release
```

Output directory: `build/web`

### Hosting

Deployed to **Vercel**. Configuration (`vercel.json`):

```json
{
  "outputDirectory": "build/web",
  "framework": null,
  "rewrites": [{"source": "/(.*)", "destination": "/index.html"}]
}
```

`framework: null` tells Vercel to serve static files. The SPA rewrite rule handles Flutter's client-side routing.

### Supabase project

| Setting | Value |
|---------|-------|
| Project ID | `zxvjzaowvzvfgrzdimbm` |
| URL | `https://zxvjzaowvzvfgrzdimbm.supabase.co` |
| Region | UNCLEAR — Bahrain timezone used throughout, likely Middle East region |
| Anon key | Hardcoded in `supabase_service.dart` |
| Service role key | Hardcoded in `supabase_service.dart` (security concern) |

### Supabase Edge Functions

One Edge Function is known to be deployed:

| Function | Purpose |
|---------|---------|
| `proxy-webhook` | Proxies all outbound n8n webhook calls from the web app to avoid CORS |

### Supabase Storage

One bucket is known:

| Bucket | Path pattern | Purpose |
|--------|-------------|---------|
| `media` | `{slug}/{timestamp}_{filename}` | Customer and manager-sent media attachments |

UNCLEAR — whether a separate bucket exists for template header images.

### n8n workflow server

URL: `https://n8n.vividsystems.cloud`  
Authentication: `X-Vivid-Secret` header (value from `system_settings.webhook_secret`).  
UNCLEAR — whether this is a self-hosted n8n instance or cloud-hosted.

### Environment variables

No `.env` file or Flutter `--dart-define` variables are used. All configuration is either hardcoded in `supabase_service.dart` or fetched from the `system_settings` table at runtime.

### Meta Cloud API credentials

- App ID `1969042950344680` — hardcoded in `supabase_service.dart`.
- Global WABA ID and token: stored in `system_settings` and loaded at startup.
- Per-client WABA ID and token: stored in `clients` table, applied via `applyClientMetaConfig()` on login/impersonation.

### Migrations deployment

No migration runner (Supabase CLI, sqitch, flyway) is configured. The `supabase/migrations/` folder contains SQL files intended to be run manually in the Supabase SQL editor. There is no enforcement of migration order or idempotency beyond the `CREATE OR REPLACE` / `IF NOT EXISTS` guards within each file.

---

## 15. Third-Party Dependencies

All from `pubspec.yaml`.

### Flutter SDK

- Dart SDK: `>=3.0.0 <4.0.0`
- Flutter SDK: `>=3.0.0 <4.0.0`

### Production dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `provider` | ^6.1.1 | State management (ChangeNotifier) |
| `supabase_flutter` | ^2.3.4 | Supabase client (PostgREST, Realtime, Storage, Edge Functions) |
| `google_fonts` | ^6.1.0 | Typography |
| `http` | ^1.1.0 | HTTP client for n8n webhook calls (native path) |
| `intl` | ^0.19.0 | Date/number formatting |
| `url_launcher` | ^6.2.1 | Open URLs in browser/external app |
| `shared_preferences` | ^2.2.2 | Persistent key-value storage (imported but primary session uses sessionStorage) |
| `cupertino_icons` | ^1.0.6 | iOS-style icon set |
| `pdf` | ^3.10.8 | PDF generation for analytics export |
| `file_picker` | ^10.3.10 | File/image picker for media uploads |
| `web` | ^1.0.0 | Modern `dart:html` replacement for web APIs |
| `excel` | ^4.0.6 | Read/write Excel files for outreach contact import |
| `emoji_picker_flutter` | ^2.1.1 | Emoji picker in message compose box |

### Development / test dependencies

UNCLEAR — `pubspec.yaml` dev_dependencies section not audited in detail; standard Flutter test packages assumed.

### External services

| Service | Usage |
|---------|-------|
| Meta Cloud API v21.0 | WhatsApp template management, message delivery |
| n8n (`https://n8n.vividsystems.cloud`) | Message routing, broadcast execution, AI chat, password reset emails |
| Supabase | Database (PostgreSQL), Realtime, Storage, Edge Functions |
| Vercel | Static web hosting |
| Google Fonts CDN | Font delivery (loaded by `google_fonts` package) |

---

## 16. Data Volumes and Operational Notes

### Conversation / message scale

UNCLEAR — exact row counts not visible from code alone.

Observations from code that imply scale considerations:
- Pagination was introduced (Phase 1, 2026-05-04) specifically because loading all conversations in one query was becoming impractical. 100 phones/page was chosen.
- `fetchExchangesForPhones()` uses 1000-row batches with a loop, implying >1000 messages per page-load is expected.
- `idx_karisma_messages_phone_agg` index was created `CONCURRENTLY` (safe for live traffic) suggesting the table is large enough that a blocking index build would matter.
- The ROI analytics provider fetches messages in 1000-row paginated loops, suggesting tens of thousands of messages per client.

### Broadcast recipient scale

- `BroadcastsProvider.fetchRecipients()` paginates with `batchSize = 1000`, implying broadcasts can have >1000 recipients.
- `BroadcastAnalyticsProvider` paginates recipients 1000/page in a loop — this can be slow for large recipient sets.
- `get_broadcast_analytics_aggregates` RPC was created to address this but is not yet used.

### Template sync scale

UNCLEAR — Meta API response size for templates not constrained in code (single fetch, no pagination). If a client has >200 templates, the Meta API may paginate responses and only the first page would be synced. No cursor-based paging is implemented in `templates_provider.dart`.

### Monthly rollover schedule

`process_monthly_rollover()` must be triggered externally (pg_cron or manual). No pg_cron setup is visible in the migrations. If not scheduled, rollover balances will never update automatically.

### Realtime channel limits

Supabase free/pro tier has limits on concurrent Realtime channels. The admin analytics view opens one channel per client (`admin_messages_{client.id}`, `admin_broadcasts_{client.id}`, `admin_recipients_{client.id}`) simultaneously. For a Vivid admin viewing all clients, this could create `3 × N` channels where N = number of clients. UNCLEAR how many clients are active.

### Bahrain timezone boundary

All broadcast scheduling, monthly rollover computation, and sent-count queries use `Asia/Bahrain` (UTC+3). This is hardcoded in the rollover migration and in `BroadcastsProvider.fetchMonthlySentCount()`. Clients in other timezones would have incorrect quota resets.

### Supabase PostgREST default row limit

PostgREST caps responses at 1000 rows by default unless a `Range` header or `.range()` call is used. Known places where this cap is **NOT** applied and could silently truncate data:

1. `supabase_service.dart:1551–1554` — `fetchAnalytics()` (dead code, but present)
2. `analytics_provider.dart:~53` — `_fetchConversationsAnalytics()` (dead code)
3. `supabase_service.dart` — `client.from('system_settings').select()` (small table, not a concern)
4. `admin_provider.dart` — multiple `select()` calls on per-client tables without pagination (UNCLEAR which are paginated)

Known places where pagination IS correctly applied:
- `broadcasts_provider.dart` — `fetchRecipients()` — 1000/page loop
- `roi_analytics_provider.dart` — paginated message + recipient fetch
- `conversations_provider.dart` — 100 phones/page via RPC + 1000 exchanges/page
- `activity_logs_provider.dart` — 1000/page server-side
- `broadcast_analytics_provider.dart` — 1000/page loop for recipients

### Storage usage

Media files accumulate in the `media` bucket over time. No eviction policy, lifecycle rule, or storage quota enforcement is visible in the code.

### Audit log retention

`activity_logs` table grows indefinitely. No retention/archival policy is defined.

---

*End of audit document.*
