# Vivid WhatsApp Dashboard - Project Context

## Overview
Multi-tenant WhatsApp Dashboard SaaS for Vivid Algorithms (Bahrain). Built with Flutter Web + Supabase + n8n workflows. Business managers use it to monitor and manage AI chatbot conversations with their customers.

## Current Clients
1. **3B's Gents Salon** (slug: `threeBs`) - conversations, analytics
2. **Karisma Medical Center** (slug: `karisma`) - broadcasts, analytics, manager AI chat
3. **Demo Client** (slug: `demo`) - all features for testing

## Tech Stack
- **Frontend**: Flutter Web
- **Backend**: Supabase (PostgreSQL + Realtime + RLS)
- **Automation**: n8n workflows for WhatsApp integration
- **WhatsApp**: Meta Cloud API via n8n

## Architecture

### Multi-Tenant Design
- Each client has their own tables: `{slug}_messages`, `{slug}_broadcasts`, `{slug}_broadcast_recipients`, `{slug}_manager_chats`, `{slug}_bookings`, `{slug}_vivid_customers`
- `clients` table stores per-client configuration including table names, webhook URLs, phone numbers per feature
- `users` table with `client_id` foreign key for access control
- Role-based access: admin, manager, agent, viewer

### Key Tables (Supabase)
```sql
-- Shared tables
clients (id, name, slug, enabled_features, broadcasts_table, bookings_table, 
         conversations_phone, broadcasts_phone, reminders_phone,
         conversations_webhook_url, broadcasts_webhook_url, manager_chat_webhook_url, ...)
users (id, email, password, name, role, client_id, custom_permissions, revoked_permissions)
activity_logs (id, client_id, user_id, user_name, action_type, description, metadata, created_at)

-- Per-client tables (example for karisma)
karisma_broadcasts (id, campaign_name, message_content, sent_at, total_recipients)
karisma_broadcast_recipients (id, broadcast_id, customer_phone, customer_name, message_sent, sent_at)
karisma_manager_chats (id, client_id, user_id, user_name, user_message, ai_response, created_at)
karisma_bookings (id, booking_id, name, phone, service, appointment_date, appointment_time, status, reminder_3day, reminder_1day)
```

### ClientConfig (Flutter)
Static class that holds current client and user after login:
- `ClientConfig.currentClient` - Client object with all config
- `ClientConfig.currentUser` - AppUser object
- `ClientConfig.broadcastsTable` - returns e.g. "karisma_broadcasts"
- `ClientConfig.broadcastsWebhookUrl` - returns webhook URL for broadcasts
- `ClientConfig.managerChatWebhookUrl` - returns webhook URL for AI chat

### n8n Workflows
1. **SQL Agent Karisma** - Handles WhatsApp messages and dashboard requests for Karisma
2. **Demo for all customers** - Handles Demo client with AI Agent routing

Webhook flow:
```
Dashboard → HTTP POST to webhook → n8n workflow → AI Agent → Supabase insert → Realtime → Dashboard update
```

## Features

### 1. Conversations (Customer Chats)
- View all WhatsApp conversations with customers
- Send replies from dashboard
- Toggle AI on/off per customer
- Table: `{slug}_messages`

### 2. Broadcasts
- Send mass WhatsApp messages via AI natural language ("send 10% discount to all hot customers")
- AI Agent generates SQL query, fetches customers, sends WhatsApp templates
- Track campaigns and recipients
- Tables: `{slug}_broadcasts`, `{slug}_broadcast_recipients`

### 3. Manager AI Chat
- Chat interface for managers to query business data
- "How many appointments this week?", "Show me top customers"
- Per-user chat history (each user sees only their messages)
- Table: `{slug}_manager_chats` with user_id filtering

### 4. Analytics
- Conversation stats, broadcast stats
- Export to Excel

### 5. Booking Reminders
- View upcoming appointments
- Send manual reminders
- Auto-reminders via n8n (3-day, 1-day)
- Table: `{slug}_bookings`

### 6. Activity Logs
- Track all user actions (login, logout, broadcasts sent, messages sent, etc.)
- Table: `activity_logs`

### 7. User Management
- Create/edit/delete users
- Assign roles and custom permissions
- Admin panel for Vivid admins

## Key Flutter Files

### Providers (lib/providers/)
- `broadcasts_provider.dart` - Fetch/send broadcasts, realtime subscriptions
- `manager_chat_provider.dart` - AI chat with per-user filtering
- `broadcast_analytics_provider.dart` - Broadcast stats
- `analytics_provider.dart` - Conversation analytics
- `activity_logs_provider.dart` - Fetch/filter activity logs
- `booking_reminders_provider.dart` - Bookings management

### Services (lib/services/)
- `supabase_service.dart` - All Supabase operations, login, logging

### Models (lib/models/)
- `models.dart` - All data models (Client, AppUser, Broadcast, etc.)

### Screens/Panels (lib/screens/ or lib/panels/)
- `broadcasts_panel.dart` - Broadcasts UI
- `manager_chat_panel.dart` - AI chat UI
- `conversations_panel.dart` - Customer chats UI
- `analytics_panel.dart` - Analytics dashboard

## Current Status

### ✅ COMPLETED
1. Multi-tenant architecture with per-client tables
2. Dynamic table names in providers (uses ClientConfig)
3. Broadcasts feature for Demo client (full flow working)
4. Manager chat table schema updated for Karisma (user_id, user_message, ai_response)
5. Activity logging for login/logout, user CRUD, client CRUD
6. Activity logging added for broadcasts and AI chat messages
7. Per-user chat history filtering in manager_chat_provider.dart

### 🔧 IN PROGRESS (Karisma deadline: 2 days)

#### Code/Supabase Tasks:
- [ ] #7 - Fix analytics export inconsistencies

#### n8n Tasks (do later together):
- [ ] #1 - Fix AI chat not responding (n8n workflow needs to save to new table schema)
- [ ] #4 - Customer WhatsApp messages + employee replies from dashboard
- [ ] #5 - Labels for customer inquiries (trigger words → auto-label)
- [ ] #3 - Photos/PDFs support (new feature, enable/disable per client)

### ⚠️ MISSING TABLES
- `karisma_broadcast_recipients` - needs to be created

## n8n Workflow Updates Needed

### For Manager Chat (Karisma)
The n8n workflow needs to save to new schema:
```
Old: message, role, status, agent_id, manager_phone_number
New: user_message, ai_response, user_id, user_name, client_id
```

Webhook payload from dashboard now includes:
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

n8n should:
1. Process with AI Agent
2. Insert to karisma_manager_chats: user_message, ai_response, user_id, user_name, client_id

### For Broadcasts
Working flow in Demo workflow:
1. AI Agent detects broadcast request
2. Execute SQL query to get customers
3. Insert to {slug}_broadcasts
4. Loop: Send WhatsApp template + Insert to {slug}_broadcast_recipients
5. Save confirmation to {slug}_manager_chats

## Environment

### Supabase
- Project: Vivid Algorithms
- URL: https://zxvjzaowvzvfgrzdimbm.supabase.co

### n8n
- URL: https://n8n.vividsystems.cloud

### Dashboard
- Production: https://dashboard.vividsystems.co

## Code Patterns

### Dynamic Table Names
```dart
String get _broadcastsTable {
  final table = ClientConfig.broadcastsTable;
  if (table != null && table.isNotEmpty) {
    return table;
  }
  final slug = ClientConfig.currentClient?.slug;
  if (slug != null && slug.isNotEmpty) {
    return '${slug}_broadcasts';
  }
  return 'broadcasts';
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
_chatChannel = SupabaseService.client
    .channel('manager_chat_${_managerChatsTable}_$userId')
    .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: _managerChatsTable,
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) { ... },
    )
    .subscribe();
```

## Important Notes

1. **Always use ClientConfig** for table names and webhook URLs
2. **RLS policies** are set to public_access for simplicity (app handles auth)
3. **Realtime** requires table to have RLS enabled
4. **n8n webhooks** expect specific payload structure - check before changing
5. **Build before deploy**: `flutter build web` then push to domain
6. **Hard refresh** for users after deploy: Cmd+Shift+R

## Commands

```bash
# Run locally
flutter run -d chrome

# Build for production
flutter build web

# Deploy (your deployment method)
# ...
```
