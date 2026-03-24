# Vivid WhatsApp Dashboard - Project Context

## Overview
Multi-tenant WhatsApp Dashboard SaaS for Vivid Algorithms (Bahrain). Built with Flutter Web + Supabase + n8n workflows. Business managers use it to monitor and manage AI chatbot conversations with their customers.

Production URL: `https://dashboard.vividsystems.co`

## Current Clients
1. **3B's Gents Salon** (slug: `threeBs`) — conversations, analytics
2. **Karisma Medical Center** (slug: `karisma`) — broadcasts, analytics, manager AI chat
3. **Demo Client** (slug: `demo`) — all features for testing

## Tech Stack
- **Frontend**: Flutter Web (Dart SDK >=3.0.0 <4.0.0)
- **Backend**: Supabase (PostgreSQL + Realtime + RLS)
- **Automation**: n8n workflows for WhatsApp integration
- **WhatsApp**: Meta Cloud API v21.0 via n8n (shared WABA for ALL clients)
- **State Management**: Provider (ChangeNotifier pattern)
- **Font**: Google Fonts (Poppins)
- **Theme**: Dark-only, custom `VividTheme` with `VividColors` palette

## Dependencies (pubspec.yaml)
- `provider` — state management
- `google_fonts` — typography (Poppins)
- `http` — webhook HTTP calls
- `intl` — date/time formatting + number formatting (`NumberFormat('#,###')`)
- `supabase_flutter` — Supabase client, Realtime, PostgREST
- `url_launcher` — external links
- `shared_preferences` — local caching
- `pdf` — PDF generation (analytics export)
- `file_picker` — media uploads
- `web` — browser APIs (file downloads, clipboard, audio)
- `emoji_picker_flutter` — emoji keyboard in chat

## Architecture

### Multi-Tenant Design
- Each client has their own tables: `{slug}_messages`, `{slug}_broadcasts`, `{slug}_broadcast_recipients`, `{slug}_manager_chats`, `{slug}_bookings`, `{slug}_vivid_customers`, `{slug}_whatsapp_templates`, `{slug}_customer_predictions`
- `clients` table stores per-client configuration (table names, webhook URLs, phone numbers per feature, enabled features)
- `users` table with `client_id` foreign key for access control
- Role-based access: `admin` (Vivid super admin, no client_id), `admin` (client admin, has client_id), `manager`, `agent`, `viewer`
- Features are enabled per-client via `enabled_features` JSON array in `clients` table

### Supabase Client Pattern (CRITICAL)
- **`SupabaseService.adminClient`** (service role key) — bypasses RLS. Used for ALL per-client dynamic table reads/writes.
- **`SupabaseService.client`** (anon key) — subject to RLS. Used ONLY for Realtime subscriptions (required by Supabase).
- **NEVER mix**: Don't use adminClient for realtime channels. Don't use client for direct table reads (gets 0 rows due to RLS).
- **Meta API fields** (static on SupabaseService): `metaApiVersion` ('v21.0'), `metaAccessToken`, `metaWabaId`, `metaAppId`
- **`applyClientMetaConfig(Client)`** (:296) overrides WABA/token per client; `resetToDefaultMetaConfig()` (:288) reverts

### Pagination Pattern (for large tables)
```dart
const pageSize = 1000;
int offset = 0;
while (true) {
  final rows = await SupabaseService.adminClient.from(table).select(columns)
      .order('created_at', ascending: false)
      .range(offset, offset + pageSize - 1);
  // process rows...
  if (rows.length < pageSize) break;
  offset += pageSize;
}
```

### Number Formatting Convention
All numbers displayed to users use `NumberFormat('#,###')` with commas — NO K/M suffix abbreviations.
```dart
static final _numFmt = NumberFormat('#,###');
// 1234 → "1,234", 1000000 → "1,000,000"
```

### Key Supabase Tables

#### Shared Tables
```sql
clients (
  id UUID PK,
  name TEXT,
  slug TEXT UNIQUE,
  enabled_features JSONB,           -- e.g. ["conversations","broadcasts","analytics","manager_chat","booking_reminders"]
  broadcasts_table TEXT,             -- e.g. "karisma_broadcasts"
  bookings_table TEXT,               -- e.g. "karisma_bookings"
  messages_table TEXT,               -- e.g. "karisma_messages"
  manager_chats_table TEXT,          -- e.g. "karisma_manager_chats"
  broadcast_recipients_table TEXT,
  vivid_customers_table TEXT,
  templates_table TEXT,              -- e.g. "karisma_whatsapp_templates"
  customer_predictions_table TEXT,   -- e.g. "karisma_customer_predictions"
  conversations_phone TEXT,          -- WhatsApp number for conversations feature
  broadcasts_phone TEXT,             -- WhatsApp number for broadcasts feature
  reminders_phone TEXT,              -- WhatsApp number for booking reminders
  conversations_webhook_url TEXT,    -- n8n webhook for sending messages
  broadcasts_webhook_url TEXT,       -- n8n webhook for broadcasts
  manager_chat_webhook_url TEXT,     -- n8n webhook for AI chat
  business_phone TEXT,               -- Legacy shared phone (deprecated, use per-feature phones)
  webhook_url TEXT                   -- Legacy shared webhook (deprecated)
)

users (
  id UUID PK,
  email TEXT UNIQUE,
  password TEXT,                     -- Hashed via login_user() RPC
  name TEXT,
  role TEXT,                         -- 'admin', 'manager', 'agent', 'viewer'
  client_id UUID FK → clients,      -- NULL for Vivid super admins
  custom_permissions JSONB,          -- Additional permissions granted
  revoked_permissions JSONB          -- Permissions removed from role defaults
)

activity_logs (
  id UUID PK,
  client_id UUID,
  user_id UUID,
  user_name TEXT,
  action_type TEXT,                  -- 'login','logout','message_sent','broadcast_sent','ai_toggled','user_created', etc.
  description TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ
)

ai_chat_settings (
  ai_phone TEXT,
  customer_phone TEXT,
  ai_enabled BOOLEAN DEFAULT true
)
```

#### Per-Client Tables (example for karisma)
```sql
karisma_messages (
  id UUID PK,
  customer_phone TEXT,
  customer_name TEXT,
  customer_message TEXT,             -- Incoming from customer
  ai_response TEXT,                  -- AI's reply
  manager_response TEXT,             -- Employee's manual reply
  ai_phone TEXT,                     -- Business WhatsApp number
  sent_by TEXT,                      -- 'customer', 'ai', 'manager', 'broadcast'
  label TEXT,                        -- e.g. 'Appointment Booked', 'Payment Done', 'interested', etc.
  campaign_id TEXT,                  -- Links to broadcast campaign
  offer_amount NUMERIC,             -- Revenue per conversion (set on broadcast campaign rows)
  created_at TIMESTAMPTZ
)

karisma_broadcasts (
  id UUID PK,
  campaign_name TEXT,
  message_content TEXT,
  sent_at TIMESTAMPTZ,
  total_recipients INT,
  offer_amount NUMERIC               -- Revenue amount per conversion
)

karisma_broadcast_recipients (
  id UUID PK,
  broadcast_id UUID FK,
  customer_phone TEXT,
  customer_name TEXT,
  message_sent BOOLEAN,
  sent_at TIMESTAMPTZ
)

karisma_manager_chats (
  id UUID PK,
  client_id UUID,
  user_id UUID,                      -- Per-user chat filtering
  user_name TEXT,
  user_message TEXT,
  ai_response TEXT,
  session_id TEXT,                   -- Groups messages into chat sessions
  created_at TIMESTAMPTZ
)

karisma_bookings (
  id UUID PK,
  booking_id TEXT,
  name TEXT,
  phone TEXT,
  service TEXT,
  appointment_date DATE,
  appointment_time TEXT,
  status TEXT,                       -- 'pending','reminder_sent','confirmed','cancelled'
  reminder_3day BOOLEAN,
  reminder_1day BOOLEAN
)

karisma_whatsapp_templates (
  meta_template_id TEXT,
  client_id UUID,
  template_name TEXT,                -- Full Meta name with prefix (e.g. "karisma_summer_deal")
  display_name TEXT,                 -- Clean name without prefix (e.g. "summer_deal")
  language_code TEXT,
  category TEXT,
  status TEXT,                       -- APPROVED, PENDING, REJECTED
  header_type TEXT,                  -- TEXT, IMAGE, VIDEO, DOCUMENT, or empty
  header_text TEXT,
  header_media_url TEXT,
  header_has_variable BOOLEAN,
  body_text TEXT,                    -- Template body with {{1}} {{2}} placeholders
  body_variable_count INT,
  body_variable_labels JSONB,        -- Array of labels like ["customer_name","service","price"]
  body_variable_descriptions JSONB,
  body_variable_sources JSONB,       -- Array of data sources for each variable
  buttons JSONB,
  button_count INT,
  is_active BOOLEAN,
  target_services JSONB,
  offer_image_url TEXT,
  updated_at TIMESTAMPTZ
)

karisma_customer_predictions (
  phone TEXT,
  customer_name TEXT,
  total_visits INT,
  last_visit DATE,
  days_since_last_visit INT,
  primary_service TEXT,
  last_service TEXT,
  avg_gap_days NUMERIC,
  predicted_next_visit DATE,
  days_until_predicted INT,          -- Negative = overdue, 0-7 = due this week, 8-30 = due this month
  category TEXT                      -- 'New', 'Returning', 'Regular', 'At Risk', 'Lapsed'
)
```

### ClientConfig (Static Runtime State)
After login, `ClientConfig` holds the current client + user. All providers and services reference it:
```dart
ClientConfig.currentClient        // Client object with all config
ClientConfig.currentUser          // AppUser object
ClientConfig.broadcastsTable      // "karisma_broadcasts"
ClientConfig.messagesTableName    // "karisma_messages"
ClientConfig.managerChatsTable    // "karisma_manager_chats"
ClientConfig.bookingsTable        // "karisma_bookings"
ClientConfig.templatesTable       // "karisma_whatsapp_templates"
ClientConfig.customerPredictionsTable // "karisma_customer_predictions"
ClientConfig.conversationsPhone   // WhatsApp number for conversations
ClientConfig.broadcastsPhone      // WhatsApp number for broadcasts
ClientConfig.broadcastsWebhookUrl // n8n webhook URL for broadcasts
ClientConfig.managerChatWebhookUrl // n8n webhook URL for AI chat
ClientConfig.conversationsWebhookUrl // n8n webhook URL for sending messages
ClientConfig.hasFeature('conversations') // Check if feature enabled
ClientConfig.isVividAdmin         // true if admin role + NO client_id
ClientConfig.isClientAdmin        // true if admin role + HAS client_id
ClientConfig.hasAiConversations   // true if conversations feature + webhook configured
ClientConfig.canPerformAction('use_manager_chat') // Permission check
```

### Authentication
- Custom auth (NOT Supabase Auth) — uses `users` table directly
- Login via `login_user()` RPC (hashed passwords) with fallback to plain-text comparison
- Session persistence: `sessionStorage` (web) for session restore on refresh
- `AgentProvider` manages auth state, session restore, and routing
- Routes: Vivid super admins → `AdminPanel`, client users → `MainScaffold`

### n8n Workflows
1. **SQL Agent Karisma** — Handles WhatsApp messages and dashboard requests for Karisma
2. **Demo for all customers** — Handles Demo client with AI Agent routing

Webhook flow:
```
Dashboard → HTTP POST to webhook → n8n workflow → AI Agent → Supabase insert → Realtime → Dashboard update
```

## File Structure

### Entry Point
- `lib/main.dart` — App initialization, MultiProvider setup (17 providers), AuthWrapper routing, MainScaffold with sidebar + content area. Initializes providers based on configured features only.

### Models (`lib/models/`)
- `models.dart` — ALL data models in one file:
  - **Enums**: `SenderType`, `ConversationStatus`, `ReminderStatus`, `ActionType`, `BroadcastStatus`
  - **Client** (~line 1): Full client config (slug, table names, webhooks, phones, features)
  - **AppUser**: User with role, permissions, client_id. Has `isReadOnly`, `isVividAdmin`, `isClientAdmin`
  - **ClientConfig** (~line 772): Static class holding current client/user. Dynamic table name getters, feature checks, permission checks
  - **RawExchange**: Single row from messages table (customer_message, ai_response, manager_response, sent_by, label, campaign_id, offer_amount, etc.)
  - **Message**: Parsed from RawExchange — has `content`, `sender`, `timestamp`, `isCustomer`, `isAI`, `isManager`
  - **Conversation**: Aggregated from exchanges — customerPhone, lastMessage, unreadCount, status, label, lastActiveAt. `broadcastLifecycleLabel` tracks: "Sent" → "Needs Reply" → "Replied"
  - **Broadcast**, **BroadcastRecipient**: Campaign and recipient tracking
  - **Booking**: Appointment with reminder status
  - **ActivityLog**: Action audit trail
  - **NavDestination**: Enum for sidebar navigation
  - **WhatsAppTemplate** (~line 1217): Template model with slug prefix support
    - `name` — full Meta template name (e.g., "karisma_appointment_reminder")
    - `displayName` — clean name without prefix (e.g., "appointment_reminder"), nullable
    - `label` getter — returns `displayName` if set, falls back to `name`
    - `status` — APPROVED, PENDING, REJECTED
    - `headerType` — TEXT, IMAGE, VIDEO, DOCUMENT, or empty
    - `body` — template body with `{{1}}` `{{2}}` placeholders
    - `componentsJson` — raw Meta API components array
  - **CustomerPrediction** (~line 1335): Predictive analytics model
    - `phone`, `customerName`, `totalVisits`, `lastVisit`, `daysSinceLastVisit`
    - `primaryService`, `lastService`, `avgGapDays`, `predictedNextVisit`
    - `daysUntilPredicted` — negative = overdue, 0-7 = due this week, 8-30 = due this month
    - `category` — "New", "Returning", "Regular", "At Risk", "Lapsed"
  - **PredictionStats** (~line 1380): Aggregated prediction metrics
    - `overdueCount`, `thisWeekCount`, `thisMonthCount`, `serviceBreakdown` (Map<String,int>)

### Providers (`lib/providers/`)
All use `ChangeNotifier` pattern with Provider.

| Provider | Purpose |
|----------|---------|
| `agent_provider.dart` | Auth state, login/logout, session restore |
| `conversations_provider.dart` | Fetch/filter conversations, send messages, AI toggle, realtime subscriptions, trigger-word auto-labeling. `broadcastLifecycleLabel` on conversations. |
| `broadcasts_provider.dart` | Fetch/send broadcasts via AI webhook, realtime subscriptions. Respects `ClientConfig.currentClient.broadcastLimit` for monthly caps. Paginates recipients (100 per page). |
| `manager_chat_provider.dart` | AI chat per-user, send queries to n8n webhook, realtime subscription with user_id filter. **Draft message preservation**: `draftMessage` getter/setter, `clearDraft()` — survives navigation. **Prediction context**: fetches `PredictionStats` on init, includes in webhook payload. Sessions grouped by `session_id`. |
| `templates_provider.dart` | Template CRUD, Meta API sync, slug prefix system. See [Templates System](#templates-system-slug-prefix) below. |
| `roi_analytics_provider.dart` | ROI analytics computation — fetches messages + broadcasts + recipients, computes metrics (leads, conversions, revenue, response times, daily trends, campaign breakdown). Supports date ranges + compare mode. Includes `LabeledCustomer` model for pipeline UI. |
| `analytics_provider.dart` | Per-client analytics: total messages, AI/manager responses, daily counts, unique customers, top customers, team performance. Filters by `ai_phone`. Uses adminClient. |
| `broadcast_analytics_provider.dart` | Broadcast-specific analytics |
| `admin_analytics_provider.dart` | Vivid admin cross-client analytics. `fetchCompanyAnalytics()` — paginated (1000-row chunks) using adminClient. `fetchPredictiveMetrics(client)` — aggregates customerPredictions into PredictiveMetrics (categoryDistribution, retentionRate, atRiskCount, lapsedCount, dueThisWeek, overdueCount, topServices, avgGapDays, totalCustomers). |
| `notification_provider.dart` | Browser push notifications via `html.Notification` API + sound. Subscribes to client-specific messages table via Realtime. Notifies when AI is disabled for a customer. |
| `ai_settings_provider.dart` | Fetch/toggle AI enabled per customer phone |
| `booking_reminders_provider.dart` | Fetch bookings, send manual reminders |
| `activity_logs_provider.dart` | Fetch/filter activity logs for client admins |
| `user_management_provider.dart` | CRUD users for a client |
| `admin_provider.dart` | Vivid admin: manage clients, global user management. `fetchClients()`, `createClient()`, `updateClient()`, `deleteClient()`, `fetchAllUsers()`, `createUser()`, `deleteUser()`. Activity log subscription. |

### Services (`lib/services/`)
- `supabase_service.dart` — Singleton service. Contains:
  - Supabase initialization (URL + anon key hardcoded)
  - `login()` / authentication — tries hashed RPC first, falls back to plaintext
  - `adminClient` (service role, bypasses RLS) and `client` (anon key, RLS-enforced)
  - `applyClientMetaConfig(Client)` / `resetToDefaultMetaConfig()` — per-client WABA overrides
  - `fetchExchanges()` — paginated fetch from messages table
  - `subscribeToExchanges()` — Realtime subscription for live message updates
  - `sendMessage()` — HTTP POST to conversation webhook
  - `toggleAI()` — Update `ai_chat_settings` table
  - `updateConversationLabel()` — Update label on most recent exchange for a customer
  - `fetchPredictionStats()` (:624) — queries customerPredictionsTable, splits into overdue/thisWeek/thisMonth by `predicted_next_visit` relative to today, builds service breakdown map
  - `logActivity()` (:348) → `activity_logs` table
  - `doesTableExist()`, `getTableRowCount()`, `checkTablesStatus()` — table utilities

### Screens (`lib/screens/`)
| Screen | Purpose |
|--------|---------|
| `login_screen.dart` | Login form with Vivid branding, forced dark mode |
| `dashboard_screen.dart` | Conversations view: conversation list (left) + conversation detail (right). Has resizable divider between panels. Responsive: mobile (list OR detail), tablet, desktop. |
| `analytics_screen.dart` | Full ROI analytics dashboard. Has `_ConversationsView` (main) and `_BroadcastsView` tabs. Date range filters. Compare mode. Line charts. Metric cards with pipeline dialog. Campaign breakdown table. Employee response times. Export to Excel/PDF. |
| `broadcast_analytics_screen.dart` | Broadcast-only analytics for clients without conversations |
| `roi_analytics_screen.dart` | Standalone ROI analytics (may be unused — analytics_screen.dart is the primary) |
| `admin_panel.dart` | Vivid super admin panel with 10 tabs. See [Admin Panel](#admin-panel-vivid-super-admins) below. |
| `templates_screen.dart` | Client template list — shows `template.label` (display name without prefix). Delete uses `template.name` (full Meta name). |
| `new_template_screen.dart` | Create template — prepends client slug prefix to template name before Meta API submission. |
| `template_detail_screen.dart` | Edit template labels, variable sources, offer image |

### Widgets (`lib/widgets/`)
| Widget | Purpose |
|--------|---------|
| `sidebar.dart` | Navigation sidebar (72px wide). Shows nav icons with unread badges. User avatar + settings at bottom. Notification bell. `NavDestination` enum defined here. |
| `conversation_list_panel.dart` | Scrollable list of conversations with search, status filter, label filter. Shows last message preview, time ago, unread badge, label color chip. |
| `conversation_detail.dart` | Chat view for selected conversation. Message bubbles (customer=left, AI/manager=right). Header with customer name, AI toggle, label button. Message input with emoji picker. Voice message bubble support. |
| `broadcasts_panel.dart` | Natural language broadcast interface. User types instruction → AI generates campaign → sends WhatsApp messages. Shows broadcast history + recipient details. |
| `manager_chat_panel.dart` | AI chat for managers + Prediction Insights sidebar. See [Manager Chat & Predictions](#manager-chat--predictions) below. |
| `booking_reminders_panel.dart` | Booking appointments list with manual reminder sending. |
| `activity_logs_panel.dart` | Activity log viewer with filters. Stat cards with `NumberFormat('#,###')` formatting. |
| `client_analytics_view.dart` | Per-client analytics embedded in admin panel. Includes predictive section with clickable cards (Due This Week, Overdue → open customer list dialog). |
| `vivid_company_analytics_view.dart` | Cross-client aggregated analytics for Vivid admins. Colors: blueGrey, teal, VividColors.brightBlue. |
| `command_center_tab.dart` | Admin command center — quick overview, client status, system health. Numbers use `NumberFormat('#,###')`. |
| `user_management_panel.dart` | User list with CRUD operations |
| `user_management_dialog.dart` | Dialog for creating/editing users |
| `voice_message_bubble.dart` | Audio playback widget for voice messages |

### Theme (`lib/theme/`)
- `vivid_theme.dart` — Dark theme only. Key colors:
  - `VividColors.darkNavy` (#020010) — main background
  - `VividColors.navy` (#050520) — secondary background / cards
  - `VividColors.deepBlue` (#0A1628) — panels
  - `VividColors.tealBlue` (#054D73) — borders/accents
  - `VividColors.brightBlue` (#0550B8) — primary actions
  - `VividColors.cyan` (#38BEC9) — AI status/accents
  - `VividColors.statusUrgent` (#DC4444) — red alerts
  - `VividColors.statusSuccess` (#34B869) — green success
  - `VividColors.statusWarning` (#D4A528) — yellow warnings
  - `VividWidgets.icon()` / `VividWidgets.logo()` — brand assets
  - `VividWidgets.statusBadge()` — reusable status chip
  - `VividWidgets.gradientContainer()` — gradient box
  - `VividColorScheme` extension accessed via `context.vividColors`

### Utilities (`lib/utils/`)
- `date_formatter.dart` — `timeAgo()`, `formatDate()` helpers
- `time_utils.dart` — Bahrain timezone (UTC+3) conversion
- `analytics_exporter.dart` — Export analytics to Excel (CSV) and PDF. Uses `NumberFormat('#,###')`.
- `audio_controller.dart` — Web audio playback for notification sounds
- `initials_helper.dart` — Extract initials from names for avatars
- `health_scorer.dart` — Health scoring utilities

### Assets
- `assets/images/` — `vivid_icon.png`, `vivid_logo.png` (brand assets)
- `assets/fonts/` — Custom font files

---

## Templates System (Slug Prefix)

All clients share ONE Meta WABA. Templates are scoped per-client via a naming convention.

### Slug Normalization
```dart
// TemplatesProvider.normalizeSlug (static method)
static String normalizeSlug(String slug) =>
    slug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
// "threeBs" → "threebs", "Vivid_Demo" → "vivid_demo", "HOB" → "hob"
```

### Template Creation (`new_template_screen.dart`)
When a client creates a template, the slug prefix is prepended:
```dart
final userTemplateName = _nameController.text.trim().toLowerCase().replaceAll(' ', '_');
final slug = ClientConfig.currentClient?.slug ?? '';
final prefix = TemplatesProvider.normalizeSlug(slug);
final templateName = prefix.isNotEmpty ? '${prefix}_$userTemplateName' : userTemplateName;
// User types "summer_deal" → Meta gets "karisma_summer_deal"
// syncSingleTemplate called with displayName: userTemplateName
```

### Template Display (`templates_screen.dart`)
Shows `template.label` (which returns `displayName` if set, else `name`). Clients never see the prefix.

### Sync Flow (`syncTemplatesToSupabase`, templates_provider.dart:367)
1. **Safety guards**: Global mutex lock (`_globalSyncLock`), stale cache detection (empty Meta response when prior succeeded → abort), client context validation (clientId hasn't changed mid-async)
2. Fetch ALL templates from Meta API via `fetchMetaTemplates()`
3. For each template, compute `display_name`:
   - If name starts with client's prefix → strip prefix for `display_name`
   - Otherwise → `display_name` = full name (global/legacy template)
4. **ALL templates sync to ALL clients** (no filtering by prefix — backward compatible)
5. For each template row, preserve existing DB values: `body_variable_labels`, `body_variable_sources`, `offer_image_url`
6. Auto-generate smart labels if none preserved (examines ~50 chars before each `{{n}}` placeholder for keywords like "hi/hello" → "customer_name", "BHD/price" → "price", etc.)
7. Strip expiring CDN URLs (scontent.*, fbcdn.net), keep only Supabase Storage URLs for images
8. Upsert all rows into per-client table
9. **Stale cleanup**: Delete DB rows whose `meta_template_id` is NOT in the current Meta template set

### Single Template Sync (`syncSingleTemplate`)
Accepts optional `String? displayName` parameter. Used after creating a template to immediately add it to the client's DB with the clean display name.

### Template Delete (`deleteTemplate`, templates_provider.dart:220)
1. DELETE from Meta API by template name
2. DELETE from per-client Supabase table by `template_name`
3. Remove from in-memory `_templates` list

### Smart Label Detection (`_smartLabels`)
Examines ~50 chars before each `{{n}}` placeholder:
- "customer_name" — keywords: hi, hello, dear, مرحبا, عزيزي
- "price" — keywords: BHD, offer, دينار, price
- "service" — keywords: treatment, service, خدمة
- "date" — keywords: appointment, date, تاريخ
- "provider" — keywords: dr, doctor, دكتور
- "branch" — keywords: location, branch, فرع
- Falls back to: customer_name, service, price, date, param_5...

### Template Fetching (`fetchTemplates`)
Reads from per-client Supabase table (`ClientConfig.templatesTable`), NOT from Meta API. Parses `display_name` into `WhatsAppTemplate.displayName`. Meta API fetch (`fetchMetaTemplates()`) is only used by the sync operation.

---

## Manager Chat & Predictions

### Overview
"Vivid AI" page — AI chat assistant for managers with predictive intelligence sidebar.

### Key Files
- `lib/widgets/manager_chat_panel.dart` — chat UI + `_PredictionInsightsPanel` + `_PriorityCustomerListDialog`
- `lib/providers/manager_chat_provider.dart` — chat state, sessions, draft, predictions
- `lib/services/supabase_service.dart:624` — `fetchPredictionStats()`
- `lib/models/models.dart:1335` — CustomerPrediction model
- `lib/models/models.dart:1380` — PredictionStats model

### ManagerChatProvider State
- `_allMessages`, `_currentSessionId`, `_draftMessage`, `_predictionStats`, `_isWaitingForResponse`
- Sessions: Messages grouped by `session_id`; legacy messages have null session
- Fetches PredictionStats on init, includes in n8n webhook payload

### Draft Message Preservation
```
1. initState → restore from provider.draftMessage → set controller text
2. _messageController.addListener(_onDraftChanged) → saves to provider on every keystroke
3. _sendMessage() → controller.clear() + provider.clearDraft()
4. dispose → removeListener
```
Survives navigation away and back since provider lives in MultiProvider tree.

### n8n Webhook Payload
```json
{
  "user_message": "...",
  "prediction_context": {
    "overdue_count": 5,
    "due_this_week": 12,
    "due_this_month": 30,
    "top_services": { "Haircut": 15, "Facial": 8 }
  },
  "client_id": "uuid",
  "user_id": "uuid"
}
```

### Prediction Insights Panel (`_PredictionInsightsPanel`, manager_chat_panel.dart)
Right sidebar on Vivid AI page showing:

**PRIORITY TARGETS** (stat cards):
- **Overdue** (red #F87171) — customers past predicted visit date (`days_until_predicted < 0`)
- **Due This Week** (yellow #FBBF24) — predicted in next 7 days (0-7)
- **Due This Month** (cyan) — predicted in 8-30 days

**On tap**: Each card opens `_PriorityCustomerListDialog` (NOT a broadcast modal) with:
- Scrollable list of CustomerPrediction objects
- Search by name/phone
- Each tile shows: name, phone, primary service, last visit date, predicted date, overdue/days-until badge
- Sorted: most overdue first (overdue category), soonest first (due this week/month)
- Colors: red for overdue, yellow for due today, cyan for upcoming

**SERVICE BREAKDOWN**: Top 5 services with horizontal bars and counts. Tappable → prefills chat with service-specific question.

**QUICK ACTIONS**:
- "Send to Overdue Customers" → opens broadcast modal
- "Send to Due This Week" → broadcast modal
- "Send to Due This Month" → broadcast modal
- "Get Prediction Summary" → prefills chat
- "Refresh Data" → reloads stats

### Priority Customer List Dialog (`_PriorityCustomerListDialog`)
- StatefulWidget at end of `manager_chat_panel.dart`
- Fetches from `ClientConfig.customerPredictionsTable` via adminClient
- Filters by category based on `audienceDescription` param
- Customer tile: name, overdue badge, phone, service, last visit, predicted date
- Colors: red (#F87171) for overdue, yellow (#FBBF24) for due today, cyan for upcoming

### Predictive Section in Analytics (`client_analytics_view.dart`)
- `_buildPredictiveSection()` shows cards: Retention Rate, At Risk, Lapsed, Due This Week, Overdue, Avg Gap
- Due This Week and Overdue cards are clickable → open `_showPriorityCustomersDialog()` (same customer list dialog pattern)
- Uses `_PriorityCategory` enum: overdue, dueThisWeek, dueThisMonth
- `_MetricCard` widget has optional `onTap` callback for clickable cards

---

## Admin Panel (Vivid Super Admins)

`lib/screens/admin_panel.dart` — Only accessible to users with `isVividAdmin` (admin role + no client_id).

### 10 Tabs
1. **Command Center** (`command_center_tab.dart`) — Quick overview, client status, system health
2. **Clients** — Client list with CRUD, feature toggles, table config, preview mode
3. **Users** — All users across clients, create/edit/delete/block
4. **Templates** (`_AdminTemplatesTab`, :6410) — All Meta API templates with client badges, sync to all
5. **Analytics** (`client_analytics_view.dart`) — Per-client analytics with date filters, predictive section
6. **Company Analytics** (`vivid_company_analytics_view.dart`) — Cross-client aggregated metrics
7. **Financials** (`financials_tab.dart`) — Income/expense tracking
8. **Activity Logs** (`activity_logs_panel.dart`) — Audit trail
9. **Outreach** (`outreach_panel.dart`) — Sales contacts
10. **Settings** (`settings_tab.dart`) — Meta API creds, webhooks, system settings

### Admin Templates Tab (`_AdminTemplatesTab`, :6410)
- Fetches directly from Meta API (not per-client tables)
- Prefix→client map built from `AdminProvider.clients` using `TemplatesProvider.normalizeSlug()`
- Each card shows: template name, status badge (Approved/Pending/Rejected), **client badge** (client name or "Global")
- Search, status filter, category filter
- Preview panel (right side): WhatsApp-style bubble, buttons, metadata
- **"Sync to All Clients" button**: For each client with templates enabled:
  - Filter templates by prefix (own prefix = strip, other prefix = skip, no prefix = global)
  - Preserve existing labels/sources/images from DB
  - Upsert into client's templates table
- **Delete**: Removes from Meta API + all client Supabase tables

### Admin Preview Mode (ImpersonateService)
- "View as Client" button on each client card
- `ImpersonateService.startImpersonation(client)` → `ClientConfig.enterPreview(client, tempUser)`
- Saves admin user, switches context, applies client Meta config
- Stale dispose guard: `exitPreview(clientId)` checks `_previewClientId` to prevent race conditions
- On exit: restores admin user, resets Meta config

### Company Analytics (`vivid_company_analytics_view.dart`)
- Uses `AdminAnalyticsProvider` for cross-client data
- `fetchCompanyAnalytics()` — paginated queries (1000 rows/page) using adminClient
- Metrics: total messages, AI vs manager responses, active clients, busiest hours
- Colors: blueGrey, teal, VividColors.brightBlue (no bright purple/green/orange — professional muted palette)

---

## Features In Detail

### 1. Conversations (Customer Chats)
- View all WhatsApp conversations grouped by customer phone
- Send replies from dashboard (HTTP POST to n8n webhook)
- Toggle AI on/off per customer (updates `ai_chat_settings` table)
- Real-time updates via Supabase Realtime subscriptions
- Conversation status: "Needs Reply" (customer sent last) vs "Replied" (AI/manager sent last)
- Broadcasts (sentBy='broadcast') are excluded from reply status calculation
- Unread count: counts exchanges after last AI/manager response (skips broadcasts)
- Label system: Auto-detect trigger words on employee message send (e.g., "booking confirmed" → "Appointment Booked"), plus manual label button in header
- Broadcast lifecycle labels: "Sent" → "Needs Reply" → "Replied"
- Copy message with visual "Copied!" feedback bubble
- Resizable list/detail divider (drag handle)
- Browser push notifications when AI is disabled and customer messages arrive
- Table: `{slug}_messages`

### 2. Broadcasts
- Natural language broadcast interface: "send 10% discount to all hot customers"
- AI Agent (n8n) generates SQL query → fetches customers → sends WhatsApp templates
- Track campaigns and recipients with delivery status
- Monthly broadcast limit per client (`ClientConfig.currentClient.broadcastLimit`)
- Paginated recipients (100 per page)
- Tables: `{slug}_broadcasts`, `{slug}_broadcast_recipients`

### 3. Manager AI Chat (Vivid AI)
- Chat interface for managers to query business data via AI
- "How many appointments this week?", "Show me top customers"
- Per-user chat history (each user sees only their messages, filtered by user_id)
- Chat sessions grouped by `session_id`
- Draft message preserved across navigation (provider state)
- Prediction context (overdue/due counts, top services) sent with each query
- Prediction Insights sidebar with clickable priority target cards
- Table: `{slug}_manager_chats`

### 4. ROI Analytics
- **Metric Cards**: Leads, Organic Leads, Appointments Booked, Payment Done (clickable for pipeline)
- **Pipeline Dialog**: Kanban-style drag-and-drop (Appointment Booked → Payment Done columns)
- **Revenue**: Calculated from `label` × `offer_amount` on broadcast campaign rows
- **Line Charts**: Custom `_LineChartPainter` for daily trends with filled area
- **Compare Mode**: Current period vs previous period with % change indicators
- **Date Ranges**: Today, Yesterday, 7 Days, 30 Days, This Month, All Time, Custom
- **Campaign Breakdown**: Table with per-campaign leads, conversions, revenue, engagement rate
- **Employee Response Times**: Average response time per employee
- **Action Required**: Customers waiting longest for reply (sorted by wait time)
- **Export**: Excel (CSV) and PDF export
- **Performance Alerts**: Engagement rate shown in blue (not red) to avoid alarm

### 5. Booking Reminders
- View upcoming appointments from `{slug}_bookings` table
- Send manual WhatsApp reminders
- Auto-reminders via n8n (3-day, 1-day before appointment)

### 6. Activity Logs
- Track all user actions with timestamps
- ActionTypes: login (displayed as "Session Started"), logout ("Session Ended"), message_sent, broadcast_sent, ai_toggled, user_created/updated/deleted, client_created/updated
- Stat cards with subtitles, numbers formatted with commas
- Filter by action type, date range

### 7. User Management
- Create/edit/delete users per client
- Assign roles: admin, manager, agent, viewer
- Custom permissions and revoked permissions (JSONB fields)
- Vivid admin panel: manage all clients and users globally

### 8. WhatsApp Templates
- Create, view, edit, delete templates per client
- Slug prefix system auto-assigns templates to correct client
- Template sync from Meta API preserves existing labels/sources/images
- Stale template cleanup during sync
- Smart label auto-detection for template variables
- See [Templates System](#templates-system-slug-prefix) above

### 9. Predictive Analytics (Customer Predictions)
- ML-generated predictions stored in `{slug}_customer_predictions` table
- Priority targets: overdue, due this week, due this month
- Customer categorization: New, Returning, Regular, At Risk, Lapsed
- Service breakdown analysis
- Clickable cards in both Vivid AI sidebar and admin analytics view
- Table: `{slug}_customer_predictions`

---

## Code Patterns

### Dynamic Table Names
```dart
String get _messagesTable {
  final table = ClientConfig.messagesTableName;
  if (table != null && table.isNotEmpty) return table;
  final slug = ClientConfig.currentClient?.slug;
  if (slug != null && slug.isNotEmpty) return '${slug}_messages';
  return 'messages';
}
```

### Activity Logging
```dart
await SupabaseService.instance.log(
  actionType: ActionType.broadcastSent,
  description: 'Sent broadcast: $instruction',
  metadata: {'instruction': instruction},
);
```

### Realtime Subscriptions with User Filter
```dart
_channel = SupabaseService.client
    .channel('manager_chat_${table}_$userId')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: table,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) { ... },
    )
    .subscribe();
```

### Feature Configuration Check
```dart
bool _isFeatureConfigured(String feature) {
  if (!ClientConfig.hasFeature(feature)) return false;
  switch (feature) {
    case 'conversations':
      return client.conversationsPhone != null && client.conversationsPhone!.isNotEmpty;
    case 'broadcasts':
      return (client.broadcastsWebhookUrl?.isNotEmpty ?? false) || (client.broadcastsPhone?.isNotEmpty ?? false);
    // ...
  }
}
```

### Webhook Payload (Dashboard → n8n)
```json
{
  "source": "dashboard",
  "type": "query",
  "body": {
    "record": {
      "message": "user's question",
      "user_id": "uuid",
      "user_name": "John Doe",
      "client_id": "uuid"
    }
  }
}
```

### Trigger Word Auto-Labeling
When an employee sends a message, the text is checked against patterns:
- **"Appointment Booked"**: `appointment booked`, `booking confirmed`, `booked you in`, `appointment confirmed`, `see you on`, `scheduled for`
- **"Payment Done"**: `payment received`, `payment confirmed`, `payment done`, `paid`, `payment successful`

If matched, the most recent exchange's `label` field is updated via `SupabaseService.updateConversationLabel()`.

## Responsive Design
- **Mobile** (<600px): Bottom navigation bar, single-panel views (list OR detail, not both)
- **Tablet** (600-900px): Compact sidebar (60px) + content, conversation list (30%) + detail
- **Desktop** (>900px): Full sidebar (72px) + content, conversation list + detail with resizable divider

## Environment

### Supabase
- Project: Vivid Algorithms
- URL: `https://zxvjzaowvzvfgrzdimbm.supabase.co`
- Anon Key: in `lib/services/supabase_service.dart`

### n8n
- URL: `https://n8n.vividsystems.cloud`

### Dashboard
- Production: `https://dashboard.vividsystems.co`

## Important Notes

1. **Always use ClientConfig** for table names and webhook URLs — never hardcode table names
2. **RLS policies** are set to `public_access` for simplicity (app handles auth via custom login). New tables MUST have: `CREATE POLICY "public_access" ON "{table_name}" FOR ALL USING (true) WITH CHECK (true);`
3. **Realtime** requires table to have RLS enabled (even if policy is permissive)
4. **n8n webhooks** expect specific payload structure — check before changing
5. **Build before deploy**: `flutter build web` then push to domain
6. **Hard refresh** for users after deploy: Cmd+Shift+R
7. **Bahrain timezone** (UTC+3) — `time_utils.dart` handles conversion for display
8. **Revenue labels** must be exactly `"Appointment Booked"` and `"Payment Done"` (title case) — analytics lowercases before comparing
9. **Broadcasts excluded from status**: Rows with `sentBy='broadcast'` are skipped when determining conversation reply status and unread count
10. **Organic leads**: Leads from customer phones NOT associated with any broadcast campaign
11. **Per-user chat history**: Manager chat filters by `user_id` so each user only sees their own conversations
12. **adminClient for table access**: ALL per-client dynamic table reads/writes use `SupabaseService.adminClient` (service role). Realtime stays on `SupabaseService.client` (anon key). Never mix.
13. **Number formatting**: Use `NumberFormat('#,###')` everywhere — no K/M abbreviations
14. **Template display names**: Always show `template.label` to users, use `template.name` for API calls
15. **debugPrint not print**: Use `debugPrint()` instead of `print()` throughout the codebase

## Commands

```bash
# Run locally
flutter run -d chrome

# Build for production
flutter build web

# Analyze for errors
flutter analyze
```

## Recent Changes (2026-03-24)

### Template Rework (Slug Prefix System)
- Added `displayName` field + `label` getter to WhatsAppTemplate model
- Added `TemplatesProvider.normalizeSlug()` static method
- `new_template_screen.dart` prepends `{prefix}_` to template name on Meta API submission
- `syncTemplatesToSupabase()` sets `display_name` based on prefix match (strips prefix for own templates)
- `templates_screen.dart` shows `template.label` instead of `template.name`
- Admin templates tab: client assignment badges, "Sync to All Clients" button

### Template Delete Supabase Cleanup
- `deleteTemplate()` now also deletes from per-client Supabase table (was only deleting from Meta API)
- `syncTemplatesToSupabase()` now removes stale rows (templates in DB but no longer in Meta)

### Priority Targets Customer List Dialog
- `_buildStatCard` onTap changed from broadcast modal → customer list dialog
- Added `_PriorityCustomerListDialog` widget — StatefulWidget with search, customer tiles
- Added clickable `_MetricCard` in `client_analytics_view.dart` for predictive section

### Draft Message Preservation
- Added `draftMessage` getter/setter + `clearDraft()` to ManagerChatProvider
- Chat panel restores draft on initState, saves on every keystroke, clears on send

### Number Formatting Standardization
- Replaced all K/M suffix formatting with `NumberFormat('#,###')` (real numbers with commas)
- Files: command_center_tab, broadcast_analytics_screen, activity_logs_panel, analytics_exporter, vivid_company_analytics_view

### Company Analytics Fixes
- Switched `fetchCompanyAnalytics` from `SupabaseService.client` to `adminClient`
- Added pagination (1000-row chunks) for messages, broadcasts, recipients queries
- Professional muted colors: blueGrey, teal, VividColors.brightBlue
