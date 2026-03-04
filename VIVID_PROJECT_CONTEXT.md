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
- **WhatsApp**: Meta Cloud API via n8n
- **State Management**: Provider (ChangeNotifier pattern)
- **Font**: Google Fonts (Poppins)
- **Theme**: Dark-only, custom `VividTheme` with `VividColors` palette

## Dependencies (pubspec.yaml)
- `provider` — state management
- `google_fonts` — typography (Poppins)
- `http` — webhook HTTP calls
- `intl` — date/time formatting
- `supabase_flutter` — Supabase client, Realtime, PostgREST
- `url_launcher` — external links
- `shared_preferences` — local caching
- `pdf` — PDF generation (analytics export)
- `file_picker` — media uploads
- `web` — browser APIs (file downloads, clipboard, audio)
- `emoji_picker_flutter` — emoji keyboard in chat

## Architecture

### Multi-Tenant Design
- Each client has their own tables: `{slug}_messages`, `{slug}_broadcasts`, `{slug}_broadcast_recipients`, `{slug}_manager_chats`, `{slug}_bookings`, `{slug}_vivid_customers`
- `clients` table stores per-client configuration (table names, webhook URLs, phone numbers per feature, enabled features)
- `users` table with `client_id` foreign key for access control
- Role-based access: `admin` (Vivid super admin, no client_id), `admin` (client admin, has client_id), `manager`, `agent`, `viewer`
- Features are enabled per-client via `enabled_features` JSON array in `clients` table

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
- `lib/main.dart` — App initialization, MultiProvider setup, AuthWrapper routing, MainScaffold with sidebar + content area. Initializes providers based on configured features only.

### Models (`lib/models/`)
- `models.dart` — ALL data models in one file:
  - **Enums**: `SenderType`, `ConversationStatus`, `ReminderStatus`, `ActionType`, `BroadcastStatus`
  - **Client**: Full client config (slug, table names, webhooks, phones, features)
  - **AppUser**: User with role, permissions, client_id. Has `isReadOnly`, `isVividAdmin`, `isClientAdmin`
  - **ClientConfig**: Static class holding current client/user. Dynamic table name getters, feature checks, permission checks
  - **RawExchange**: Single row from messages table (customer_message, ai_response, manager_response, sent_by, label, campaign_id, offer_amount, etc.)
  - **Message**: Parsed from RawExchange — has `content`, `sender`, `timestamp`, `isCustomer`, `isAI`, `isManager`
  - **Conversation**: Aggregated from exchanges — customerPhone, lastMessage, unreadCount, status, label, lastActiveAt
  - **Broadcast**, **BroadcastRecipient**: Campaign and recipient tracking
  - **Booking**: Appointment with reminder status
  - **ActivityLog**: Action audit trail
  - **NavDestination**: Enum for sidebar navigation

### Providers (`lib/providers/`)
All use `ChangeNotifier` pattern with Provider.

| Provider | Purpose |
|----------|---------|
| `agent_provider.dart` | Auth state, login/logout, session restore |
| `conversations_provider.dart` | Fetch/filter conversations, send messages, AI toggle, realtime subscriptions, trigger-word auto-labeling |
| `broadcasts_provider.dart` | Fetch/send broadcasts via AI webhook, realtime subscriptions |
| `manager_chat_provider.dart` | AI chat per-user, send queries to n8n webhook, realtime subscription with user_id filter |
| `roi_analytics_provider.dart` | ROI analytics computation — fetches messages + broadcasts + recipients, computes metrics (leads, conversions, revenue, response times, daily trends, campaign breakdown). Supports date ranges + compare mode. Includes `LabeledCustomer` model for pipeline UI. |
| `analytics_provider.dart` | Legacy analytics provider (conversation stats) |
| `broadcast_analytics_provider.dart` | Broadcast-specific analytics |
| `admin_analytics_provider.dart` | Vivid admin cross-client analytics |
| `notification_provider.dart` | Browser push notifications via `html.Notification` API + sound. Subscribes to client-specific messages table via Realtime. Notifies when AI is disabled for a customer. |
| `ai_settings_provider.dart` | Fetch/toggle AI enabled per customer phone |
| `booking_reminders_provider.dart` | Fetch bookings, send manual reminders |
| `activity_logs_provider.dart` | Fetch/filter activity logs for client admins |
| `user_management_provider.dart` | CRUD users for a client |
| `admin_provider.dart` | Vivid admin: manage clients, global user management |

### Services (`lib/services/`)
- `supabase_service.dart` — Singleton service. Contains:
  - Supabase initialization (URL + anon key hardcoded)
  - `login()` / authentication
  - `fetchExchanges()` — paginated fetch from messages table
  - `subscribeToExchanges()` — Realtime subscription for live message updates
  - `sendMessage()` — HTTP POST to conversation webhook
  - `toggleAI()` — Update `ai_chat_settings` table
  - `updateConversationLabel()` — Update label on most recent exchange for a customer
  - `log()` — Insert to `activity_logs` table
  - Various helper methods for broadcasts, bookings, etc.

### Screens (`lib/screens/`)
| Screen | Purpose |
|--------|---------|
| `login_screen.dart` | Login form with Vivid branding |
| `dashboard_screen.dart` | Conversations view: conversation list (left) + conversation detail (right). Has resizable divider between panels. Responsive: mobile (list OR detail), tablet, desktop. |
| `analytics_screen.dart` | Full ROI analytics dashboard. Has `_ConversationsView` (main) and `_BroadcastsView` tabs. Date range filters (Today, Yesterday, 7d, 30d, This Month, All Time, Custom). Compare mode. Line charts (custom `_LineChartPainter`). Metric cards with pipeline dialog (drag-and-drop Kanban: Booked → Paid). Campaign breakdown table. Employee response times. Action required section. Export to Excel/PDF. |
| `broadcast_analytics_screen.dart` | Broadcast-only analytics for clients without conversations |
| `roi_analytics_screen.dart` | Standalone ROI analytics (may be unused — analytics_screen.dart is the primary) |
| `admin_panel.dart` | Vivid super admin panel: manage clients, global analytics |

### Widgets (`lib/widgets/`)
| Widget | Purpose |
|--------|---------|
| `sidebar.dart` | Navigation sidebar (72px wide). Shows nav icons with unread badges. User avatar + settings at bottom. Notification bell. `NavDestination` enum defined here. |
| `conversation_list_panel.dart` | Scrollable list of conversations with search, status filter, label filter. Shows last message preview, time ago, unread badge, label color chip. Label colors: green=Appointment Booked, cyan=Payment Done, etc. |
| `conversation_detail.dart` | Chat view for selected conversation. Message bubbles (customer=left, AI/manager=right). Header with customer name, AI toggle, label button (Appointment Booked / Payment Done / Clear). Message input with emoji picker, reply-to, file attachment. Copy message with "Copied!" overlay feedback. Voice message bubble support. |
| `broadcasts_panel.dart` | Natural language broadcast interface. User types instruction → AI generates campaign → sends WhatsApp messages. Shows broadcast history + recipient details. |
| `manager_chat_panel.dart` | AI chat for managers to query business data. Per-user chat history (filtered by user_id). |
| `booking_reminders_panel.dart` | Booking appointments list with manual reminder sending. |
| `activity_logs_panel.dart` | Activity log viewer with filters. Stat cards: Actions Today, Actions This Week, Messages Sent, Broadcasts Sent. |
| `client_analytics_view.dart` | Analytics view embedded in admin panel for specific client |
| `vivid_company_analytics_view.dart` | Cross-client analytics for Vivid admins |
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

### Utilities (`lib/utils/`)
- `date_formatter.dart` — `timeAgo()`, `formatDate()` helpers
- `time_utils.dart` — Bahrain timezone (UTC+3) conversion
- `analytics_exporter.dart` — Export analytics to Excel (CSV) and PDF
- `audio_controller.dart` — Web audio playback for notification sounds
- `initials_helper.dart` — Extract initials from names for avatars

### Assets
- `assets/images/` — `vivid_icon.png`, `vivid_logo.png` (brand assets)
- `assets/fonts/` — Custom font files

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
- Copy message with visual "Copied!" feedback bubble
- Resizable list/detail divider (drag handle)
- Browser push notifications when AI is disabled and customer messages arrive
- Table: `{slug}_messages`

### 2. Broadcasts
- Natural language broadcast interface: "send 10% discount to all hot customers"
- AI Agent (n8n) generates SQL query → fetches customers → sends WhatsApp templates
- Track campaigns and recipients with delivery status
- Tables: `{slug}_broadcasts`, `{slug}_broadcast_recipients`

### 3. Manager AI Chat
- Chat interface for managers to query business data via AI
- "How many appointments this week?", "Show me top customers"
- Per-user chat history (each user sees only their messages, filtered by user_id)
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
- Stat cards with subtitles
- Filter by action type, date range

### 7. User Management
- Create/edit/delete users per client
- Assign roles: admin, manager, agent, viewer
- Custom permissions and revoked permissions (JSONB fields)
- Vivid admin panel: manage all clients and users globally

### 8. Admin Panel (Vivid Super Admins)
- Cross-client management: create/edit clients, manage features
- Global user management
- Client analytics overview
- Only accessible to users with admin role + no client_id

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
2. **RLS policies** are set to `public_access` for simplicity (app handles auth via custom login)
3. **Realtime** requires table to have RLS enabled (even if policy is permissive)
4. **n8n webhooks** expect specific payload structure — check before changing
5. **Build before deploy**: `flutter build web` then push to domain
6. **Hard refresh** for users after deploy: Cmd+Shift+R
7. **Bahrain timezone** (UTC+3) — `time_utils.dart` handles conversion for display
8. **Revenue labels** must be exactly `"Appointment Booked"` and `"Payment Done"` (title case) — analytics lowercases before comparing
9. **Broadcasts excluded from status**: Rows with `sentBy='broadcast'` are skipped when determining conversation reply status and unread count
10. **Organic leads**: Leads from customer phones NOT associated with any broadcast campaign
11. **Per-user chat history**: Manager chat filters by `user_id` so each user only sees their own conversations

## Commands

```bash
# Run locally
flutter run -d chrome

# Build for production
flutter build web

# Analyze for errors
flutter analyze
```
