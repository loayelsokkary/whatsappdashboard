# Vivid WhatsApp Dashboard — Admin Feature Inventory

**Source**: Flutter Web codebase at `dashboard.vividsystems.co`  
**Generated**: 2026-04-01  
**Purpose**: Complete specification for replication in Next.js at `app.vividsystems.co`  
**Branch**: `mars/dashboard-updates`

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Admin Sidebar Navigation](#2-admin-sidebar-navigation)
3. [Home Screen (Command Center)](#3-home-screen-command-center)
4. [Clients Screen](#4-clients-screen)
5. [Users Screen](#5-users-screen)
6. [Templates Screen (Admin)](#6-templates-screen-admin)
7. [Client Analytics Screen](#7-client-analytics-screen)
8. [Vivid Analytics Screen](#8-vivid-analytics-screen)
9. [Financials Screen](#9-financials-screen)
10. [Activity Logs Screen](#10-activity-logs-screen)
11. [Outreach Section](#11-outreach-section)
12. [Settings Screen](#12-settings-screen)
13. [Preview / Impersonation Mode](#13-preview--impersonation-mode)
14. [Onboarding Wizard](#14-onboarding-wizard)
15. [Client-Facing Screens](#15-client-facing-screens)
16. [Data Architecture](#16-data-architecture)
17. [External Integrations](#17-external-integrations)
18. [Authentication & Authorization](#18-authentication--authorization)

---

## 1. Architecture Overview

| Attribute | Value |
|-----------|-------|
| Frontend | Flutter Web (Dart) |
| Backend | Supabase (PostgreSQL + Auth + Storage + Realtime) |
| State management | Provider (`ChangeNotifier`) — 17 providers |
| Multi-tenancy | Each client has dedicated dynamically-named DB tables |
| Product types | `retention` (broadcast/CRM focus) and `chatbot` (AI conversation focus) |
| Auth | Custom `users` table with hashed passwords via `login_user` RPC; session stored in browser `sessionStorage` |

### Two User Contexts

- **Vivid Super Admin** — user with `role = admin` and `client_id = NULL`. Sees `AdminPanel` with 10 tabs.
- **Client User** — user with `role = admin/manager/agent/viewer` and a `client_id`. Sees `MainScaffold` with feature-gated sidebar.

---

## 2. Admin Sidebar Navigation

The admin panel uses a 10-tab layout. On desktop: persistent left sidebar. On mobile: hamburger drawer.

| # | Tab Label | Widget/Screen | Icon | Admin-Only? |
|---|-----------|---------------|------|-------------|
| 0 | Dashboard | `CommandCenterTab` | `dashboard` | Yes |
| 1 | Clients | `_ClientsTab` | `people` | Yes |
| 2 | Users | `_UsersTab` | `person` | Yes |
| 3 | Templates | `_AdminTemplatesTab` | `article` | Yes |
| 4 | Client Analytics | `_AnalyticsTab` | `analytics` | Yes |
| 5 | Vivid Analytics | `VividCompanyAnalyticsView` | `bar_chart` | Yes |
| 6 | Financials | `FinancialsTab` | `payments` | Yes |
| 7 | Activity Logs | `ActivityLogsPanel(isAdmin: true)` | `history` | Yes |
| 8 | Outreach | `OutreachPanel` | `campaign` | Yes |
| 9 | Settings | `SettingsTab` | `settings` | Yes |

All tabs are admin-only. Clients never see the `AdminPanel` — they see the `MainScaffold` described in [Section 15](#15-client-facing-screens).

---

## 3. Home Screen (Command Center)

**Widget**: `lib/widgets/command_center_tab.dart`

### Summary Stats Cards (top row)

| Card | Data Source | Calculation |
|------|-------------|-------------|
| Total Clients | `clients` table | `COUNT(*)` |
| Total Users | `users` table | `COUNT(*)` |
| Total Messages | All `{slug}_messages` tables | Sum of row counts across all clients |
| Total Broadcasts | All `{slug}_broadcasts` tables | Sum of row counts across all clients |

### Client Health Section

- Grid of health score cards, one per client
- Each card shows: client name, health grade (A–F), color indicator
- Clicking a card navigates to that client's detail in the Clients tab

**Health Scoring** (`lib/utils/health_scorer.dart`):

| Score | Grade | Color |
|-------|-------|-------|
| 90–100 | A | Green |
| 75–89 | B | Light green |
| 60–74 | C | Yellow |
| 40–59 | D | Orange |
| 0–39 | F | Red |

Scoring factors:
- **Active users**: Users who logged in within the last 7 days (from `activity_logs`)
- **Feature adoption**: Number of enabled features vs total available
- **Message activity**: Message count in the last 30 days

### Live Activity Feed

- Real-time Supabase subscription on `activity_logs` table (INSERT events)
- Shows last 20 entries
- Each entry: user name, action display name, client name, relative timestamp

### Export

- CSV export of command center summary (client name, health grade, active users, total users, feature count, message count)

### Actions

- Clicking a client health card: navigates to Clients tab with that client selected

---

## 4. Clients Screen

**Widget**: `lib/screens/admin_panel.dart` → `_ClientsTab`

### Client List (left panel — 400px on desktop, full-width on mobile)

Displayed as scrollable cards. Each card shows:
- Avatar (initials-based, colored)
- Client name + slug
- "AI" badge (if `hasAiConversations = true`)
- User count
- Feature count
- Health indicator dot (green = active <24h, yellow = active <7d, red = inactive 7d+)
- Phone number (if set)
- Feature chips (conversations, broadcasts, analytics, etc.) — each chip shows a color-coded config status dot

### Client Actions (per card)

| Action | Description |
|--------|-------------|
| Preview (eye icon) | Enter impersonation/preview mode for this client |
| Analytics (chart icon) | Navigate to Client Analytics tab for this client |
| Refresh Predictions (sync icon) | Trigger `predictionsRefreshWebhookUrl` for this client |
| Edit (pencil icon) | Open Edit Client dialog |

### Add Client

Opens the 6-step Onboarding Wizard (see [Section 14](#14-onboarding-wizard)).

### Edit Client Dialog

Fields editable in the Edit dialog:

| Field | Supabase Column | Notes |
|-------|-----------------|-------|
| Client Name | `name` | |
| Slug | `slug` | Read-only after creation (changing breaks table names) |
| Product Type | `product_type` | `retention` or `chatbot` |
| Enabled Features | `enabled_features` | Array of feature strings |
| Has AI Conversations | `has_ai_conversations` | Boolean toggle |
| Is Shared WABA | `is_shared_waba` | Auto-set by Supabase trigger; editable |
| Conversations Phone | `conversations_phone` | |
| Conversations Webhook URL | `conversations_webhook_url` | |
| Broadcasts Phone | `broadcasts_phone` | |
| Broadcasts Webhook URL | `broadcasts_webhook_url` | |
| Reminders Phone | `reminders_phone` | |
| Reminders Webhook URL | `reminders_webhook_url` | |
| Manager Chat Webhook URL | `manager_chat_webhook_url` | |
| WABA ID | `waba_id` | Meta WhatsApp Business Account ID |
| Meta Access Token | `meta_access_token` | Masked in UI |
| Broadcast Limit | `broadcast_limit` | Monthly limit (e.g., 500) |
| Predictions Webhook URL | `predictions_refresh_webhook_url` | |
| Messages Table | `messages_table` | Dynamic table name |
| Broadcasts Table | `broadcasts_table` | Dynamic table name |
| Templates Table | `templates_table` | Dynamic table name |
| Manager Chats Table | `manager_chats_table` | Dynamic table name |
| Broadcast Recipients Table | `broadcast_recipients_table` | Dynamic table name |
| AI Settings Table | `ai_settings_table` | Dynamic table name |
| Customer Predictions Table | `customer_predictions_table` | Dynamic table name |

### Client Model (`clients` Supabase Table)

```
id                          UUID, PK
name                        TEXT
slug                        TEXT UNIQUE (e.g., "karisma", "hob")
webhook_url                 TEXT (legacy fallback)
enabled_features            TEXT[] (e.g., ['conversations','broadcasts','analytics'])
business_phone              TEXT (legacy fallback)
messages_table              TEXT (e.g., 'karisma_messages')
broadcasts_table            TEXT
bookings_table              TEXT
templates_table             TEXT
manager_chats_table         TEXT
broadcast_recipients_table  TEXT
ai_settings_table           TEXT
customer_predictions_table  TEXT
waba_id                     TEXT
meta_access_token           TEXT
conversations_phone         TEXT
conversations_webhook_url   TEXT
broadcasts_phone            TEXT
broadcasts_webhook_url      TEXT
reminders_phone             TEXT
reminders_webhook_url       TEXT
manager_chat_webhook_url    TEXT
broadcast_limit             INTEGER
product_type                TEXT ('retention' | 'chatbot')
predictions_refresh_webhook_url TEXT
has_ai_conversations        BOOLEAN DEFAULT true
is_shared_waba              BOOLEAN DEFAULT false
created_at                  TIMESTAMPTZ
```

---

## 5. Users Screen

**Widget**: `lib/screens/admin_panel.dart` → `_UsersTab`

### Display

- Full-width table of all users across all clients
- Columns: Name, Email, Role, Client, Status, Created At, Actions

### Filters

- Filter by client (dropdown)
- Filter by role (dropdown)
- Search by name/email

### CRUD Operations

| Operation | Details |
|-----------|---------|
| Create | Opens Add User dialog. Fields: Name, Email, Password, Role, Client |
| Read | Lists all users with full details |
| Update | Edit name, email, role, status |
| Delete | Soft delete or hard delete |
| Block | Sets `status = 'blocked'` |

### User Roles

| Role | Value | Description |
|------|-------|-------------|
| Admin | `admin` | Full access including user management. If `client_id = NULL` → Vivid Super Admin |
| Manager | `manager` | All features except user management |
| Agent | `agent` | Customer conversations only |
| Viewer | `viewer` | Read-only access to all features |

### User Model (`users` Supabase Table)

```
id                  UUID, PK
email               TEXT UNIQUE
name                TEXT
role                TEXT ('admin' | 'manager' | 'agent' | 'viewer')
client_id           UUID FK → clients.id (NULL for Vivid admins)
password            TEXT (hashed via hash_password RPC)
status              TEXT ('active' | 'blocked') DEFAULT 'active'
custom_permissions  TEXT[] (extra permissions beyond role)
revoked_permissions TEXT[] (permissions removed from role defaults)
created_at          TIMESTAMPTZ
updated_at          TIMESTAMPTZ
```

### Permission System

Permissions are role-based with per-user overrides:

| Permission | Value | Admin | Manager | Agent | Viewer |
|------------|-------|-------|---------|-------|--------|
| View Dashboard | `view_dashboard` | ✓ | ✓ | ✓ | ✓ |
| View Analytics | `view_analytics` | ✓ | ✓ | | ✓ |
| View Conversations | `view_conversations` | ✓ | ✓ | ✓ | ✓ |
| Send Messages | `send_messages` | ✓ | ✓ | ✓ | |
| View Broadcasts | `view_broadcasts` | ✓ | ✓ | | ✓ |
| Send Broadcasts | `send_broadcasts` | ✓ | ✓ | | |
| View AI Assistant | `view_manager_chat` | ✓ | ✓ | | ✓ |
| Use AI Assistant | `use_manager_chat` | ✓ | ✓ | | |
| View Users | `view_users` | ✓ | | | |
| Manage Users | `manage_users` | ✓ | | | |
| View Activity Logs | `view_activity_logs` | ✓ | | | |
| View Templates | `view_templates` | ✓ | ✓ | | |
| Manage Templates | `manage_templates` | ✓ | ✓ | | |

`custom_permissions` and `revoked_permissions` allow per-user overrides of role defaults.

---

## 6. Templates Screen (Admin)

**Widget**: `lib/screens/admin_panel.dart` → `_AdminTemplatesTab`

### Layout (Desktop)

Two-panel layout:
- **Left panel** (~280px): Client selector list
- **Right panel**: Template grid + preview

### Layout (Mobile)

- `DropdownButton<Client>` for client selection
- Icon buttons for actions
- Horizontal scrollable filter chips
- Full-width template grid
- `DraggableScrollableSheet` bottom sheet for template preview (initialChildSize: 0.75)

### Client Selector (Left Panel)

- Scrollable list of all clients
- Each item: client name, message/template count badge
- Actions per client:
  - **Sync All** — calls `TemplatesProvider.syncTemplates()` → Meta API `GET /{wabaId}/message_templates` → saves to `{slug}_whatsapp_templates`
  - **Refresh** — re-fetches from Supabase
  - **Delete All** — deletes from Supabase + calls Meta API `DELETE` for each

### Template Grid

- Filter chips: All, Approved, Pending, Rejected
- Search field
- Template cards showing: name, status badge (color-coded), language, category, body preview, variable count, header type

### Template Detail Panel (right side on desktop, bottom sheet on mobile)

Fields displayed per template:

| Field | Source |
|-------|--------|
| Name | `name` (Meta template name, may have slug prefix) |
| Display Name | `display_name` (friendly name, overrides `name` in UI) |
| Status | `status` (APPROVED / PENDING / REJECTED) |
| Language | `language` (e.g., `en_US`, `ar`) |
| Category | `category` (MARKETING / UTILITY / AUTHENTICATION) |
| Header Type | `header_type` (NONE / TEXT / IMAGE) |
| Header Text | `header_text` |
| Header Image URL | `header_media_url` (Supabase Storage URL) |
| Offer Image URL | `offer_image_url` (separate from header image) |
| Body | `body` (with `{{n}}` placeholders) |
| Footer | `footer` |
| Buttons | `buttons` JSON array (type + text) |
| Variable Count | `body_variable_count` |
| Variable Labels | `body_variable_labels` TEXT[] |
| Variable Sources | `body_variable_sources` TEXT[] |
| Variable Descriptions | `body_variable_descriptions` TEXT[] |
| Target Services | `target_services` TEXT[] |
| Synced to DB | `synced_to_db` BOOLEAN |
| Is Configured | computed: header image uploaded + variables labeled |

### Delete Flow

1. Call Meta API: `DELETE /v{version}/{wabaId}/message_templates?name={templateName}`
2. Delete from Supabase: `DELETE FROM {slug}_whatsapp_templates WHERE id = ?`
3. Provider removes from local state

### Shared WABA Filtering

When `is_shared_waba = true` for a client, template sync filters Meta API results by slug prefix (e.g., only templates starting with `hob_` are shown for HOB client).

---

## 7. Client Analytics Screen

**Widget**: `lib/screens/admin_panel.dart` → `_AnalyticsTab` → `lib/widgets/client_analytics_view.dart`

### Client Selector

- Dropdown at top of screen to select which client to view
- Defaults to first client in the list

### Tabs

All tabs are feature-gated based on what the selected client has enabled.

| Tab | Feature Gate | Description |
|-----|-------------|-------------|
| Overview | always | Aggregate summary for the client |
| Conversations | `conversations` | Message volume, response metrics |
| Broadcasts | `broadcasts` | Campaign performance |
| Manager Chat | `manager_chat` | AI assistant usage stats |
| Labels | `labels` | Label distribution and trends |
| Predictions | `predictive_intelligence` | Customer return predictions |
| Insights | always | Advanced analytics insights |

### Date Filter

- Presets: All Time, Today, Last 7 Days, Last 30 Days, This Month
- Custom date range picker

### Export

- CSV and PDF export for each tab's data

### Key Metrics (per tab)

**Overview**:
- Total messages, inbound vs outbound
- Active customers (30-day window)
- Average response time
- AI vs manager response ratio

**Broadcasts**:
- Campaigns sent, total recipients, delivery rate, read rate
- Response rate (7-day attribution window)

**Manager Chat**:
- Total sessions, total messages, sessions per user
- Average session duration

---

## 8. Vivid Analytics Screen

**Widget**: `lib/widgets/vivid_company_analytics_view.dart`

Aggregated metrics across **all clients** combined.

### Header

- Vivid logo + "Vivid Company Analytics" title
- Real-time badge (live data indicator)
- "Aggregate metrics across all clients" subtitle (hidden on mobile)
- Export button

### Metric Cards

| Card | Description | Source |
|------|-------------|--------|
| Total Clients | Count of all clients | `clients` table |
| Total Users | Sum of users across all clients | `users` table |
| Total Messages | Sum of all message rows across all client message tables | Per-client dynamic tables |
| Total Broadcasts | Sum of all broadcast rows | Per-client dynamic tables |
| Active This Month | Clients with activity in current month | `activity_logs` |
| AI Conversations | Clients with `has_ai_conversations = true` | `clients` table |

### Cross-client aggregation

Data aggregated via `AdminAnalyticsProvider` which queries each client's dynamic tables individually and sums results.

### Export Button

- Downloads a CSV file with the aggregated metrics
- Also supports PDF export with branded Vivid styling, Arabic font support, embedded logo

---

## 9. Financials Screen

**Widget**: `lib/screens/financials_tab.dart`

### Layout

- Summary cards (top row) + Transaction list (main area)
- Filter bar: date range, type, category, status

### Summary Cards

| Card | Calculation |
|------|-------------|
| Total Revenue | SUM of paid income transactions |
| Outstanding | SUM of pending income transactions |
| Total Expenses | SUM of all expense transactions |
| Net Profit | Revenue - Expenses |

### Transaction List

Columns: Date, Client, Type, Category, Amount, Status, Description, Actions (Edit, Delete)

### Add/Edit Transaction Dialog

Fields:

| Field | Type | Values |
|-------|------|--------|
| Type | Enum | `income`, `expense` |
| Category (income) | Dropdown | Subscription, Setup Fee, Consultation, Broadcast Credits, Support, Custom Development, Other |
| Category (expense) | Dropdown | Infrastructure, Tools & Software, Staff, Marketing, Operations, Other |
| Amount | Number | |
| Currency | Text | Default: BHD |
| Status | Enum | `paid`, `pending`, `overdue`, `cancelled` |
| Description | Text | |
| Invoice Number | Text | |
| Client/Vendor | Text | |
| Due Date | Date | |
| Paid Date | Date | |
| Recurring | Boolean | |
| Recurring Interval | Text | monthly, quarterly, yearly |
| Notes | Text | |

### `vivid_financials` Supabase Table

```
id                  UUID, PK
client_id           UUID (can be null for Vivid-level transactions)
client_name         TEXT
type                TEXT ('income' | 'expense')
category            TEXT
amount              DECIMAL
currency            TEXT DEFAULT 'BHD'
status              TEXT ('paid' | 'pending' | 'overdue' | 'cancelled')
description         TEXT
invoice_number      TEXT
vendor_client       TEXT
due_date            DATE
paid_date           DATE
recurring           BOOLEAN
recurring_interval  TEXT
notes               TEXT
created_at          TIMESTAMPTZ
updated_at          TIMESTAMPTZ
```

---

## 10. Activity Logs Screen

**Widget**: `lib/widgets/activity_logs_panel.dart`

Two usage modes:
- `ActivityLogsPanel(isAdmin: true)` — shows all clients, shows all action types including impersonation
- `ActivityLogsPanel(isAdmin: false)` — scoped to current client, hides impersonation events

### Filters

| Filter | Type | Notes |
|--------|------|-------|
| Client | Dropdown | Admin-only; scopes to a specific client |
| Action Type | Dropdown | See action types table below |
| Date Range | Date pickers | Start and end date |
| Search | Text field | Client-side search across description, user name, user email |
| AI Only | Toggle chip | Shows only `ai_toggled` events |

### Action Types

| Enum Value | DB Value | Display Name |
|------------|----------|--------------|
| `login` | `login` | Session Started |
| `logout` | `logout` | Session Ended |
| `messageSent` | `message_sent` | Message Sent |
| `broadcastSent` | `broadcast_sent` | Broadcast Sent |
| `aiToggled` | `ai_toggled` | AI Toggle |
| `userCreated` | `user_created` | User Created |
| `userUpdated` | `user_updated` | User Updated |
| `userDeleted` | `user_deleted` | User Deleted |
| `userBlocked` | `user_blocked` | User Blocked |
| `clientCreated` | `client_created` | Client Created |
| `clientUpdated` | `client_updated` | Client Updated |
| `impersonationStart` | `impersonation_start` | Impersonation Started *(admin-only)* |
| `impersonationEnd` | `impersonation_end` | Impersonation Ended *(admin-only)* |

### Impersonation Filtering

When `isAdmin = false` (client view), provider calls `fetchLogs(hideInternalActions: true)` which passes `excludeActionTypes: ['impersonation_start', 'impersonation_end']` to Supabase query. This uses `.not('action_type', 'in', '(impersonation_start,impersonation_end)')`.

### Pagination

- Server-side: 1,000 rows per fetch (offset-based)
- Client-side display: 50 rows, "Load More" button adds 50 more

### Summary Stats Cards

Four cards displayed above the log list:
- Total Events
- Sessions (login + logout count)
- Messages Sent (message_sent count)
- Broadcasts Sent (broadcast_sent count)

On mobile, stats displayed as 2×2 grid (each card `Expanded` inside `Row`).

### Export

- CSV download of filtered log results
- Columns: Timestamp, User Name, User Email, Client, Action Type, Description

### `activity_logs` Supabase Table

```
id          UUID, PK
client_id   UUID FK → clients.id (NULL for admin-level actions)
user_id     UUID FK → users.id
user_name   TEXT
user_email  TEXT
action_type TEXT
description TEXT
metadata    JSONB
created_at  TIMESTAMPTZ
```

---

## 11. Outreach Section

**Widget**: `lib/screens/outreach_panel.dart`

Vivid's own internal CRM for outreach to prospects. Four sub-tabs.

### 11.1 Contacts Tab

**Table**: `vivid_outreach_contacts`

Displays: company name, contact name, phone, email, industry, status, last contacted, next follow-up

**CRUD**:
- Add contact (form dialog)
- Edit contact
- Delete contact
- Bulk CSV import

**Contact Statuses**: `lead`, `contacted`, `interested`, `negotiation`, `won`, `lost`, `churned`

**Contact Model Fields**:
```
id                UUID
company_name      TEXT
contact_name      TEXT
phone             TEXT
email             TEXT
industry          TEXT
notes             TEXT
status            TEXT
last_contacted_at TIMESTAMPTZ
next_follow_up    TIMESTAMPTZ
created_at        TIMESTAMPTZ
updated_at        TIMESTAMPTZ
```

### 11.2 Conversations Tab

**Widget**: `lib/widgets/outreach_chat.dart`

**Layout**: Resizable split view (contact list left, chat right) — same pattern as main conversations screen

**Contact List**:
- Search by name/phone
- "Needs Reply" filter
- Contact cards with status indicator, last message preview, relative timestamp

**Chat Panel**:
- Message bubbles (inbound/outbound)
- File/media upload to Supabase Storage `media` bucket under `outreach/` path
- Emoji picker
- Reply-to support
- Real-time updates via Supabase subscription on `vivid_outreach_messages`

**Message Model (`vivid_outreach_messages`)**:
```
id                UUID
contact_id        UUID FK → vivid_outreach_contacts.id
ai_phone          TEXT
customer_phone    TEXT
customer_name     TEXT
customer_message  TEXT
ai_response       TEXT
manager_response  TEXT
sent_by           TEXT
is_outbound       BOOLEAN
media_url         TEXT
media_type        TEXT
media_filename    TEXT
created_at        TIMESTAMPTZ
```

**Message Send**: POST to `outreach_send_webhook` (from `system_settings`)

### 11.3 Broadcasts Tab

**Table**: `vivid_outreach_broadcasts` + `vivid_outreach_broadcast_recipients`

Same layout as client broadcasts panel.

**Broadcast Model (`vivid_outreach_broadcasts`)**:
```
id                UUID
name              TEXT
message           TEXT (or template)
recipient_count   INTEGER
status            TEXT
sent_at           TIMESTAMPTZ
created_at        TIMESTAMPTZ
... (11 total fields)
```

**Broadcast Send**: POST to `outreach_broadcast_webhook` (from `system_settings`)

### 11.4 Templates Tab

**Table**: `vivid_outreach_whatsapp_templates`

- List of Vivid's own WhatsApp templates
- Sync from Meta API using outreach WABA credentials
- Same sync logic as client templates, but using `outreach_waba_id` and `outreach_meta_access_token` from `system_settings`

---

## 12. Settings Screen

**Widget**: `lib/widgets/settings_tab.dart`

Five collapsible sections.

### 12.1 Meta WhatsApp API

Displays/edits global defaults (used when a client has no per-client credentials):

| Setting Key | Description |
|-------------|-------------|
| `meta_api_version` | API version (e.g., `v22.0`) |
| `meta_access_token` | Global fallback access token |
| `meta_waba_id` | Global fallback WABA ID |
| `meta_app_id` | Meta App ID |

Edited via inline dialog; saved to `system_settings` table via `updateSystemSetting(key, value)`.

### 12.2 Outreach Configuration

| Setting Key | Description |
|-------------|-------------|
| `outreach_phone` | Vivid's outreach WhatsApp phone |
| `outreach_waba_id` | Vivid's outreach WABA ID |
| `outreach_meta_access_token` | Vivid's outreach Meta access token |
| `outreach_send_webhook` | n8n webhook URL for sending outreach messages |
| `outreach_broadcast_webhook` | n8n webhook URL for outreach broadcasts |

### 12.3 Client Config Overview

Per-client table with columns: Client Name, Features, Phone, Webhook Status, Table Status

### 12.4 Database Tables

For each client, checks existence and row count of:

| Table Suffix | Expected For |
|-------------|-------------|
| `{slug}_messages` | `conversations` feature |
| `{slug}_broadcasts` | `broadcasts` feature |
| `{slug}_broadcast_recipients` | `broadcasts` feature |
| `{slug}_manager_chats` | `manager_chat` feature |
| `{slug}_whatsapp_templates` | `broadcasts` or `whatsapp_templates` feature |
| `{slug}_ai_chat_settings` | always |
| `{slug}_customer_predictions` | `predictive_intelligence` feature |

Also checks 13 system tables:
`clients`, `users`, `activity_logs`, `ai_chat_settings`, `system_settings`, `password_reset_codes`, `label_trigger_words`, `vivid_outreach_contacts`, `vivid_outreach_messages`, `vivid_outreach_broadcasts`, `vivid_outreach_broadcast_recipients`, `vivid_outreach_whatsapp_templates`, `vivid_financials`

### 12.5 System Health

- Supabase connection check
- Last activity timestamp
- Row counts for `clients`, `users`, `activity_logs`

---

## 13. Preview / Impersonation Mode

**Service**: `lib/services/impersonate_service.dart`

### How It Works

1. Admin clicks "Preview" on a client card
2. `ImpersonateService.startImpersonation(client)` is called:
   - Saves the current admin user in `ClientConfig._savedAdminUser`
   - Creates a temporary `AppUser` with `role = admin` and `clientId = client.id`
   - Calls `ClientConfig.enterPreview(client, tempUser)`
   - Logs `impersonation_start` to `activity_logs`
3. A `_ClientPreviewScreen` widget is pushed onto the navigation stack, rendering `MainScaffold` for the selected client
4. Admin sees the full client dashboard as if they were a client admin

### Changes During Preview

- `ClientConfig.isPreviewMode = true`
- All dynamic table getters (`messagesTable`, `broadcastsTable`, etc.) return the client's tables
- `ClientConfig.currentClient` = the impersonated client
- All write actions are **blocked** (no messages, broadcasts, or templates can be sent)
- A "Preview Mode" banner is shown
- Input bar in conversations shows a read-only notice

### Exiting Preview

- Back button or "Exit Preview" button calls `ImpersonateService.endImpersonation()`
- Restores `ClientConfig._savedAdminUser` and clears preview state
- Logs `impersonation_end` to `activity_logs`

### Impersonation Events in Activity Logs

Logged to `activity_logs` with:
- `action_type = 'impersonation_start'` or `'impersonation_end'`
- `metadata = { 'client_id': ..., 'client_name': ... }`
- Hidden from client-facing activity logs (filtered server-side)

---

## 14. Onboarding Wizard

**Widget**: `lib/screens/admin_panel.dart` → `_ClientOnboardingWizard`

A 6-step dialog wizard for creating new clients.

### Step 1: Basic Info

| Field | Validation | Notes |
|-------|-----------|-------|
| Client Name | Required | Shown as `business_name` across the dashboard |
| Slug | Required, auto-generated from name | Lowercase alphanumeric + underscores only. Used as prefix for all dynamic table names. Cannot be changed after creation. |
| Product Type | Required, dropdown | `Retention Platform` (`retention`) or `Chatbot` (`chatbot`) |

**Auto-slug logic**: Converts name to lowercase, replaces spaces with `_`, strips non-alphanumeric characters.

### Step 2: Features

**Core Features** (select any combination):

| Key | Label | Description |
|-----|-------|-------------|
| `conversations` | Conversations | WhatsApp customer conversations |
| `broadcasts` | Broadcasts | Send bulk WhatsApp campaigns |
| `manager_chat` | AI Assistant | Manager AI chatbot |

**Analytics** is auto-enabled when any core feature is selected.

**Add-ons**:

| Key | Label | Notes |
|-----|-------|-------|
| `labels` | Labels | Works with Conversations — auto-tag messages by trigger words |
| `whatsapp_templates` | Templates | Works with Broadcasts |
| `media` | Media | Photo/PDF sharing in conversations |
| `predictive_intelligence` | Predictive Intelligence | AI-powered customer return predictions |

**AI Conversations toggle** (shown when `conversations` is selected):
- `AI-Powered Conversations`: boolean, defaults to `true`
- If `false`: all messages go directly to managers (no AI processing)

**Label Triggers section** (shown when `labels` is selected):
- Inline mini-form to add label triggers during creation
- Each trigger: label name, trigger words (array), color (hex), auto_apply (boolean)
- Stored as `_pendingTriggers`, written to `label_trigger_words` table after client creation

### Step 3: Configuration

| Field | Column | Notes |
|-------|--------|-------|
| Is Shared WABA | `is_shared_waba` | Toggle — enables slug-prefix filtering during template sync |
| Conversations Phone | `conversations_phone` | WhatsApp phone for conversations |
| Conversations Webhook URL | `conversations_webhook_url` | n8n webhook for incoming messages |
| Broadcasts Phone | `broadcasts_phone` | WhatsApp phone for broadcasts |
| Broadcasts Webhook URL | `broadcasts_webhook_url` | n8n webhook for broadcast delivery |
| Reminders Phone | `reminders_phone` | WhatsApp phone for booking reminders |
| Reminders Webhook URL | `reminders_webhook_url` | n8n webhook for reminders |
| Manager Chat Webhook URL | `manager_chat_webhook_url` | n8n webhook for AI chat |
| WABA ID | `waba_id` | Meta WhatsApp Business Account ID |
| Meta Access Token | `meta_access_token` | Validated against Meta API on submit |
| Broadcast Monthly Limit | `broadcast_limit` | Default: 500 |
| Predictions Webhook URL | `predictions_refresh_webhook_url` | n8n webhook to trigger prediction recalculation |

All fields optional at creation time (can be set later via Edit).

**WABA Validation**: If both WABA ID and token are provided, wizard calls `GET /v{version}/{wabaId}/message_templates?limit=1` to validate. Shows warning toast if validation fails (does not block creation).

### Step 4: First User (Optional)

Toggle "Create initial admin user" to enable.

| Field | Notes |
|-------|-------|
| Name | Required if creating user |
| Email | Required if creating user |
| Password | Required, minimum 6 characters |

User is always created with `role = 'admin'`.

### Step 5: Review

Summary of all selections before submission. Shows:
- Client name + slug
- Product type
- Selected features list
- Configured webhooks/phones
- First user details (if any)

Submit button calls:
1. `AdminProvider.createClient(...)` → `INSERT INTO clients`
2. `SupabaseService.adminClient.rpc('create_client_tables', { p_slug, p_features })` → creates all dynamic tables
3. `AdminProvider.createUser(...)` → `INSERT INTO users` (if first user was configured)
4. For each pending label trigger: `AdminProvider.createLabelTrigger(...)` → `INSERT INTO label_trigger_words`

On failure of `create_client_tables` RPC: shows error with "Retry" button (stays on review step).

### Step 6: Post-Creation Checklist

Shown automatically after successful creation. Displays a feature-dependent checklist:

| Checklist Item | Shown When |
|----------------|-----------|
| Verify all client tables were created in Supabase | Always |
| Create n8n conversations workflow | `conversations` enabled |
| Create n8n broadcasts workflow | `broadcasts` enabled |
| Verify WABA + phone number are active | `broadcasts` enabled |
| Create n8n manager chat workflow | `manager_chat` enabled |
| Configure Meta webhook → n8n URL | any core feature enabled |
| Import/sync WhatsApp templates | `whatsapp_templates` enabled |
| Set predictions_refresh_webhook_url for client | `predictive_intelligence` enabled + no URL set |

"Copy to Clipboard" button copies the checklist as plain text.

---

## 15. Client-Facing Screens

These screens are visible when logged in as a client user, or when a Vivid admin enters Preview mode.

The entry point is `lib/main.dart` → `MainScaffold`. Navigation uses a sidebar on desktop and `BottomNavigationBar` on mobile.

### Navigation Items (feature-gated)

| Screen | Feature Gate | Icon |
|--------|-------------|------|
| Conversations | `conversations` | `forum` |
| Broadcasts | `broadcasts` | `campaign` |
| Templates | `whatsapp_templates` OR `broadcasts` | `article` |
| Booking Reminders | conditional | `event` |
| Analytics | `analytics` | `analytics` |
| Vivid AI | `manager_chat` | `smart_toy` |
| Activity Logs | `admin` role only | `history` |

### 15.1 Conversations Screen

**File**: `lib/screens/dashboard_screen.dart`

**Layout**: 
- Mobile: list OR detail (single panel, tap to open)
- Tablet: resizable split with divider
- Desktop: side-by-side (conversation list + detail)

**Conversation List Panel** (`lib/widgets/conversation_list_panel.dart`):

| Feature | Description |
|---------|-------------|
| Search | Debounced (500ms), searches customer messages, names, and phone numbers |
| Needs Reply filter | Chip with count badge — shows conversations awaiting response |
| Label filter chips | Horizontal scrollable chips, one per configured label |
| Conversation cards | Avatar (initials), name, last message preview, relative time, unread badge, label indicator, AI status dot, broadcast lifecycle label, notes indicator |
| Arabic RTL | Detected and applied per-conversation |

**Conversation Detail Panel** (`lib/widgets/conversation_detail.dart`):

| Feature | Description |
|---------|-------------|
| Header | Avatar, customer name, phone (copy button), label button, profile panel toggle, AI toggle |
| Message list | Date dividers, message bubbles by sender type, reply-to context, media, voice notes, highlighted search, pending indicators |
| Input bar | Text field, emoji picker, file upload, send button, reply-to banner |
| File upload | Picks image/PDF, shows caption dialog, uploads to Supabase Storage, sends with media URL |
| AI toggle | Per-customer on/off, calls `AiSettingsProvider.toggleAi()` → `{slug}_ai_chat_settings` table |
| Label button | Sets `Appointment Booked` (green) or `Payment Done` (cyan), or clears label |
| Side profile | Animated 296px panel — customer stats, notes, predictions (see below) |

**Message Bubble Types by SenderType**:

| SenderType | Bubble Style | Description |
|------------|-------------|-------------|
| `customer` | Left-aligned, customer color | Inbound messages |
| `ai` | Right-aligned, AI color | AI-generated responses |
| `manager` | Right-aligned, agent color | Manual agent replies |
| `system` | Center, muted | System messages |
| `broadcast` | Right-aligned, broadcast style | Broadcast-originated messages |

**Voice Messages** (`lib/widgets/voice_message_bubble.dart`):
- Play/pause button with seek bar and duration
- Tap to reveal transcription text
- Uses singleton `AudioController` (Web AudioElement)

**Side Profile Panel** (`lib/widgets/side_profile_panel.dart`):

| Section | Data |
|---------|------|
| Summary | Last message date, customer since, total messages, sent/received counts |
| Labels | Distinct labels applied, latest label |
| Broadcasts | Total broadcasts sent to this customer, responded count, last campaign name and date |
| Handling | Last handled by (agent name) |
| Payments | Payment count, last appointment date |
| Response time | Average reply time |
| Notes | Add/view/delete per-customer notes |
| Predictions | Visit history, primary service, predicted next visit date, days until predicted visit, category |

### 15.2 Broadcasts Screen

**Widget**: `lib/widgets/broadcasts_panel.dart`

| Feature | Description |
|---------|-------------|
| Broadcast list | Campaign cards with name, message preview, recipient count, date |
| Monthly usage | Progress bar with warning at 80%, disabled at 100% of `broadcast_limit` |
| Compose broadcast | Dialog (hidden during preview mode) |
| Recipient details | Side panel with per-recipient delivery status, name, phone |
| Campaign name editing | Inline edit on recipient detail panel |
| Date display | Bahrain timezone (UTC+3) |

**Compose Broadcast Flow**:
1. Select template (from `{slug}_whatsapp_templates`)
2. Select recipients (from customer list)
3. Confirm and send → POST to `broadcastsWebhookUrl`
4. Creates row in `{slug}_broadcasts`, rows in `{slug}_broadcast_recipients`

### 15.3 Templates Screen (Client)

**File**: `lib/screens/templates_screen.dart`

| Feature | Description |
|---------|-------------|
| Template list | All templates from `{slug}_whatsapp_templates` |
| Sync button | Pulls from Meta API → saves to Supabase |
| Status filter | All, Approved, Pending, Rejected |
| Create new template | Opens `NewTemplateScreen` |
| Template card | Tap to open `TemplateDetailScreen` |

**New Template Screen** (`lib/screens/new_template_screen.dart`):

| Field | Options |
|-------|---------|
| Name | Text, auto-prefixed with client slug for shared WABA |
| Language | `en_US`, `ar`, `fr`, `es`, `de` |
| Category | `MARKETING`, `UTILITY`, `AUTHENTICATION` |
| Header Type | `NONE`, `TEXT`, `IMAGE` |
| Header Image | Upload to Supabase Storage → Meta resumable upload |
| Body | Rich text editor with `{{n}}` variable insertion |
| Variables | Example values, labels (customer_name, service, price, date, provider, branch), sources (customer_data, ai_extracted, static) |
| Footer | Optional text |
| Buttons | Add/remove call-to-action buttons (type + text) |
| Preview | Live preview panel on right (desktop) |

**Template Detail Screen** (`lib/screens/template_detail_screen.dart`):
- Loads from `{slug}_whatsapp_templates` by `meta_template_id`
- Edit variable labels and sources
- Replace offer image (5MB limit) → upload to Supabase Storage

**Template Setup Dialog** (`lib/widgets/template_setup_dialog.dart`):
- Service targeting: select from 9 beauty services or "All Services"
- Variable configuration (labels + sources)
- Image upload for IMAGE header templates

### 15.4 Analytics Screen

**File**: `lib/screens/roi_analytics_screen.dart`

| Feature | Description |
|---------|-------------|
| Date filter | All Time, Today, Last 7 Days, Last 30 Days, This Month |
| Attribution window | 7 days (168 hours) for broadcast response attribution |
| Export | CSV and PDF |
| Refresh | Re-fetches from Supabase |
| Header | Shows client business name |

### 15.5 Vivid AI (Manager Chat)

**Widget**: `lib/widgets/manager_chat_panel.dart`

| Feature | Description |
|---------|-------------|
| Session sidebar (250px) | List of chat sessions (ChatGPT-style), new chat button |
| Chat area | Message bubbles (user/AI), date dividers, typing indicator (animated dots) |
| Welcome message | Shown on new sessions |
| AI status | Online / thinking indicator in header |
| Broadcast command | Parses `[BROADCAST: instruction]` from AI responses |
| Draft preservation | Draft message saved across navigation |
| Prediction insights panel (280px) | Visible only for HOB client if `customerPredictionsTable` is configured |
| Mobile layout | Session sidebar hidden; prediction panel hidden |

**Message Send**: POST to `managerChatWebhookUrl` with session UUID.  
**Real-time**: Supabase subscription on `{slug}_manager_chats` + polling fallback (3s interval, max 10 attempts).  
**Disabled during preview**: Input bar shows read-only notice.

### 15.6 Activity Logs (Client View)

**Widget**: `lib/widgets/activity_logs_panel.dart` with `isAdmin: false`

Same as admin Activity Logs but:
- Scoped to the current `client_id` only
- Impersonation events (`impersonation_start`, `impersonation_end`) are hidden
- No client selector filter (always scoped to current client)

### 15.7 Notifications

**Widget**: Accessible via bell icon in sidebar header

- List of in-app notifications
- Mark individual or all as read
- Notifications are triggered when AI is disabled for a customer and they send a message

---

## 16. Data Architecture

### System Tables (shared, not per-client)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `clients` | Client configuration | All columns described in Section 4 |
| `users` | All users | All columns described in Section 5 |
| `activity_logs` | Audit trail | `client_id`, `user_id`, `action_type`, `description`, `metadata` |
| `system_settings` | Global key-value config | `key TEXT`, `value TEXT` |
| `password_reset_codes` | Temporary reset codes | `email`, `code`, `expires_at` |
| `label_trigger_words` | Auto-label trigger rules | `client_id`, `label`, `trigger_words TEXT[]`, `color`, `auto_apply` |
| `vivid_financials` | Vivid financial transactions | All columns described in Section 9 |
| `vivid_outreach_contacts` | Outreach CRM contacts | All columns described in Section 11.1 |
| `vivid_outreach_messages` | Outreach conversation messages | All columns described in Section 11.2 |
| `vivid_outreach_broadcasts` | Outreach broadcast campaigns | 11 fields |
| `vivid_outreach_broadcast_recipients` | Outreach broadcast recipients | 9 fields |
| `vivid_outreach_whatsapp_templates` | Vivid's own WhatsApp templates | mirrors client template structure |
| `ai_chat_settings` | Global AI settings (if any) | |

### Per-Client Dynamic Tables

All named `{slug}_{suffix}`, created via `create_client_tables` RPC when a client is onboarded.

| Suffix | Purpose | Created For Feature |
|--------|---------|---------------------|
| `_messages` | Conversation exchanges | `conversations` |
| `_broadcasts` | Broadcast campaigns | `broadcasts` |
| `_broadcast_recipients` | Broadcast recipient delivery | `broadcasts` |
| `_manager_chats` | Manager AI chat sessions/messages | `manager_chat` |
| `_whatsapp_templates` | WhatsApp templates | `broadcasts` or `whatsapp_templates` |
| `_ai_chat_settings` | Per-customer AI toggle | always |
| `_customer_predictions` | AI return predictions | `predictive_intelligence` |

### `{slug}_messages` Column Reference

```
id                UUID, PK
ai_phone          TEXT (WhatsApp phone number receiving messages)
customer_phone    TEXT
customer_name     TEXT
customer_message  TEXT (inbound message from customer)
Voice_Response    TEXT (transcription of voice message)
ai_response       TEXT (AI-generated response)
manager_response  TEXT (manual agent response, if any)
label             TEXT
media_url         TEXT
media_type        TEXT ('image' | 'document' | 'pdf')
media_filename    TEXT
is_voice_message  BOOLEAN
voice_note_url    TEXT
sent_by           TEXT (agent name/email for manager responses)
created_at        TIMESTAMPTZ
```

### `{slug}_whatsapp_templates` Column Reference

```
id                        UUID, PK
meta_template_id          TEXT (ID from Meta API, used as unique key)
name                      TEXT (Meta template name, may have slug prefix)
display_name              TEXT (friendly UI name)
status                    TEXT ('APPROVED' | 'PENDING' | 'REJECTED')
language                  TEXT
category                  TEXT
header_type               TEXT ('NONE' | 'TEXT' | 'IMAGE')
header_text               TEXT
header_media_url          TEXT (Supabase Storage URL)
offer_image_url           TEXT (separate offer image)
body                      TEXT
footer                    TEXT
buttons                   JSONB []
components                JSONB [] (raw Meta API components)
body_variable_count       INTEGER
body_variable_labels      TEXT []
body_variable_sources     TEXT []
body_variable_descriptions TEXT []
target_services           TEXT []
synced_to_db              BOOLEAN
created_at                TIMESTAMPTZ
```

### `{slug}_manager_chats` Column Reference

```
id              UUID, PK
session_id      UUID (groups messages into sessions)
role            TEXT ('user' | 'assistant')
content         TEXT
created_at      TIMESTAMPTZ
```

### Key Relationships

```
clients.id ──< users.client_id
clients.id ──< activity_logs.client_id
clients.id ──< label_trigger_words.client_id
clients.slug → dynamic table prefix
users.id ──< activity_logs.user_id
```

---

## 17. External Integrations

### 17.1 Meta WhatsApp Cloud API

Base URL: `https://graph.facebook.com/{version}/`  
Version configured in `system_settings.meta_api_version` (e.g., `v22.0`)

| Endpoint | Method | Purpose | Called From |
|----------|--------|---------|-------------|
| `/{wabaId}/message_templates?limit=200` | GET | Fetch all templates for a WABA | `TemplatesProvider.syncTemplates()` |
| `/{wabaId}/message_templates` | POST | Create a new template | `NewTemplateScreen` submission |
| `/{wabaId}/message_templates?name={name}` | DELETE | Delete a template | Admin template delete action |
| `/{appId}/uploads` | POST | Initiate resumable image upload session | Template image header upload |
| `/{upload_session_id}` | POST | Upload image data to session | Template image header upload (via `proxy-meta-upload` Edge Function for CORS) |

**Credentials**:  
- Global defaults from `system_settings` (`meta_access_token`, `meta_waba_id`)
- Per-client overrides from `clients.waba_id` and `clients.meta_access_token`
- Per-client credentials take precedence over global defaults

### 17.2 n8n Webhooks

All message sending goes through n8n webhooks, not directly to Meta.

| Config Key | Trigger | Payload |
|------------|---------|---------|
| `clients.conversations_webhook_url` | Agent sends a message in a conversation | `{ phone, message, session_id, ... }` |
| `clients.broadcasts_webhook_url` | Broadcast is composed and sent | `{ template, recipients, ... }` |
| `clients.manager_chat_webhook_url` | User sends message in AI assistant | `{ session_id, message, ... }` |
| `clients.predictions_refresh_webhook_url` | Admin clicks "Refresh Predictions" | `{ client_slug }` |
| `clients.reminders_webhook_url` | Booking reminder trigger | |
| `system_settings.outreach_send_webhook` | Outreach conversation message sent | |
| `system_settings.outreach_broadcast_webhook` | Outreach broadcast sent | |
| `https://n8n.vividsystems.cloud/webhook/password-reset` | Password reset requested | `{ email, code }` |

### 17.3 Supabase Storage

Two buckets:

| Bucket | Path Pattern | Contents |
|--------|-------------|----------|
| `Template-images` | `{slug}/{templateName}` | WhatsApp template header images + offer images |
| `media` | `{client_slug}/...` or `outreach/...` | Conversation media files (images, PDFs) |

Upload flow for conversation media:
1. File picked from device
2. Upload to Supabase Storage via `ConversationsProvider.uploadMedia()`
3. Public URL stored in message row
4. Message sent with `media_url`, `media_type`, `media_filename`

### 17.4 Supabase Edge Functions

| Function | Purpose |
|----------|---------|
| `proxy-meta-upload` | CORS proxy for Meta API resumable upload from browser. Flutter web can't make direct cross-origin POST to Meta's upload endpoints. |

### 17.5 Supabase Database Functions (RPCs)

| Function | Parameters | Purpose |
|----------|-----------|---------|
| `login_user(p_email, p_password)` | email TEXT, password TEXT | Authenticates user, returns user row + client row if applicable |
| `hash_password(password)` | password TEXT | Server-side bcrypt hashing |
| `create_client_tables(p_slug, p_features)` | slug TEXT, features TEXT[] | Creates all dynamic tables for a new client based on enabled features |

---

## 18. Authentication & Authorization

### Login Flow

1. User submits email + password
2. `SupabaseService.login()` calls `login_user(p_email, p_password)` RPC
3. RPC verifies password hash, returns user row
4. If `client_id` is present, also fetches and returns client row
5. `AgentProvider` stores session in browser `sessionStorage` keyed by user ID
6. `ClientConfig.setAdmin(user)` or `ClientConfig.setClientUser(client, user)` called
7. App re-renders into `AdminPanel` (Vivid admin) or `MainScaffold` (client user)

### Session Persistence

- Session data stored in browser `sessionStorage` (tab-scoped, cleared on tab close)
- On page reload, `AuthWrapper` reads session from `sessionStorage` and restores by user ID
- Key: `vivid_session_{userId}`

### Forgot Password Flow

1. User clicks "Forgot Password" on login screen
2. Enters email → calls `SupabaseService.saveResetCode()` (stores 6-digit code in `password_reset_codes`) + `sendResetCodeEmail()` (POSTs to `https://n8n.vividsystems.cloud/webhook/password-reset`)
3. n8n sends the code via email
4. User enters 6-digit code → `SupabaseService.verifyResetCode()` validates
5. User enters new password → `SupabaseService.resetPasswordByEmail()` updates `users.password` via `hash_password` RPC

### RBAC Enforcement

| Layer | Mechanism |
|-------|-----------|
| Navigation | `_isFeatureConfigured()` + `ClientConfig.hasFeature()` gates sidebar items |
| UI actions | `ClientConfig.canPerformAction()` hides/disables buttons (e.g., Compose Broadcast hidden for viewers) |
| Write operations | `ClientConfig.isPreviewMode` blocks all sends during impersonation |
| DB access | Supabase RLS; admin operations use `SupabaseService.adminClient` (service role key) |
| Custom permissions | `custom_permissions` and `revoked_permissions` per-user arrays allow fine-grained overrides |

### Role Capabilities Summary

| Capability | Vivid Admin | Client Admin | Manager | Agent | Viewer |
|------------|-------------|-------------|---------|-------|--------|
| Admin Panel (all tabs) | ✓ | | | | |
| Client CRUD | ✓ | | | | |
| User management | ✓ | ✓ | | | |
| View conversations | ✓ | ✓ | ✓ | ✓ | ✓ |
| Send messages | ✓ | ✓ | ✓ | ✓ | |
| View broadcasts | ✓ | ✓ | ✓ | | ✓ |
| Send broadcasts | ✓ | ✓ | ✓ | | |
| View AI assistant | ✓ | ✓ | ✓ | | ✓ |
| Use AI assistant | ✓ | ✓ | ✓ | | |
| View analytics | ✓ | ✓ | ✓ | | ✓ |
| Manage templates | ✓ | ✓ | ✓ | | |
| View activity logs | ✓ | ✓ | | | |
| Impersonate clients | ✓ | | | | |
| View Vivid financials | ✓ | | | | |
| Outreach CRM | ✓ | | | | |

### `system_settings` Known Keys

| Key | Description |
|-----|-------------|
| `meta_api_version` | Global Meta API version (e.g., `v22.0`) |
| `meta_access_token` | Global fallback Meta access token |
| `meta_waba_id` | Global fallback WABA ID |
| `meta_app_id` | Meta App ID |
| `outreach_phone` | Vivid outreach WhatsApp phone |
| `outreach_waba_id` | Vivid outreach WABA ID |
| `outreach_meta_access_token` | Vivid outreach Meta token |
| `outreach_send_webhook` | n8n URL for outreach message sending |
| `outreach_broadcast_webhook` | n8n URL for outreach broadcasts |
| `webhook_secret` | Shared secret for webhook verification |

---

*This document covers the complete admin feature surface as of branch `mars/dashboard-updates`, April 2026.*
