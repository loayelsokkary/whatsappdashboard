# Vivid WhatsApp Dashboard

![Vivid Logo](https://vividsystems.co)

A professional WhatsApp AI Conversation Management Dashboard built by **Vivid Algorithms W.L.L.** for 3B's Gents Salon in Bahrain.

## 🎯 Overview

This dashboard provides real-time monitoring and management of WhatsApp conversations powered by an AI chatbot that speaks Bahraini Arabic. It allows salon staff to:

- **Monitor** all customer conversations in real-time
- **Take over** from AI when human intervention is needed
- **Release** conversations back to AI after resolution
- **Track** conversation analytics and customer sentiment
- **Manage** VIP customers with priority handling

## ✨ Features

### MVP Phase 1 (Current)
- ✅ Real-time conversation list with status indicators
- ✅ AI/Human active status management
- ✅ Take over & release conversation functionality
- ✅ Message threading with WhatsApp-style bubbles
- ✅ Arabic/English language support with RTL
- ✅ VIP customer badges
- ✅ Sentiment indicators
- ✅ Supabase real-time integration
- ✅ n8n webhook support for message sending
- ✅ Mock authentication (production-ready structure)

### Coming Soon (Phase 2)
- 🔜 Full Supabase authentication
- 🔜 Odoo booking integration
- 🔜 AI confidence score analytics
- 🔜 Conversation search & filters
- 🔜 Bulk message broadcasting
- 🔜 Performance analytics dashboard

## 🎨 Brand Colors (Vivid Guidelines 2025)

| Color | Hex | Usage |
|-------|-----|-------|
| Dark Navy | `#05001E` | Main background |
| Navy | `#0A0A2E` | Secondary background |
| Deep Blue | `#224995` | Cards, panels |
| Teal Blue | `#0768A1` | Borders, accents |
| Cyan Blue | `#0282AE` | Highlights |
| Purple Blue | `#3150CA` | Secondary buttons |
| Bright Blue | `#076EFE` | Primary actions |
| Cyan | `#54F6FF` | AI status, accents |
| White | `#FFFFFF` | Primary text |

## 🛠️ Tech Stack

- **Frontend:** Flutter 3.x (Web)
- **State Management:** Provider
- **Backend:** Supabase (PostgreSQL + Realtime)
- **Automation:** n8n (WhatsApp Business API integration)
- **AI:** OpenAI GPT-4 (via n8n)
- **Typography:** Poppins (Google Fonts)

## 📦 Project Structure

```
vivid_dashboard/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   └── models.dart           # Data models
│   ├── providers/
│   │   ├── agent_provider.dart   # Authentication state
│   │   └── conversations_provider.dart  # Conversations state
│   ├── screens/
│   │   ├── login_screen.dart     # Login UI
│   │   └── dashboard_screen.dart # Main dashboard
│   ├── services/
│   │   └── supabase_service.dart # Supabase API client
│   ├── theme/
│   │   └── vivid_theme.dart      # Brand colors & theme
│   ├── utils/
│   │   └── time_utils.dart       # Time formatting
│   └── widgets/
│       ├── sidebar.dart          # Navigation sidebar
│       ├── conversation_list.dart # Conversation list panel
│       └── conversation_detail.dart # Message thread panel
├── pubspec.yaml                  # Dependencies
├── supabase_schema.sql           # Database schema
└── README.md
```

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** (3.0+)
   ```bash
   # macOS with Homebrew
   brew install --cask flutter
   
   # Or download from flutter.dev
   ```

2. **Supabase Account** - Create project at [supabase.com](https://supabase.com)

3. **n8n Instance** - For WhatsApp Business API integration

### Installation

1. **Clone/Extract the project**
   ```bash
   cd vivid_dashboard
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   
   Edit `lib/services/supabase_service.dart`:
   ```dart
   class SupabaseConfig {
     static const String url = 'YOUR_SUPABASE_URL';
     static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
   }
   ```

4. **Setup Database**
   
   Run `supabase_schema.sql` in your Supabase SQL editor to create:
   - `conversations` table
   - `messages` table
   - `handoffs` table
   - Required functions and triggers
   - Real-time subscriptions

5. **Run the app**
   ```bash
   # Enable web support
   flutter config --enable-web
   
   # Run in Chrome
   flutter run -d chrome
   ```

### Demo Login

For testing without Supabase auth:
- **Email:** `agent@vivid.co`
- **Password:** `demo123`

## 🔗 n8n Integration

### Incoming Messages (WhatsApp → Dashboard)

When n8n receives a WhatsApp message, call this Supabase function:

```javascript
// n8n HTTP Request Node
POST https://YOUR_PROJECT.supabase.co/rest/v1/rpc/insert_whatsapp_message
Headers: {
  "apikey": "YOUR_SERVICE_KEY",
  "Content-Type": "application/json"
}
Body: {
  "p_phone": "+97333334444",
  "p_message_text": "بغيت موعد بكرة",
  "p_sender_type": "customer",
  "p_direction": "inbound",
  "p_customer_name": "Ahmed" // optional
}
```

### Outgoing Messages (AI Response)

```javascript
// After AI generates response
Body: {
  "p_phone": "+97333334444",
  "p_message_text": "زين! شنو الوقت اللي يناسبك؟",
  "p_sender_type": "ai",
  "p_direction": "outbound",
  "p_ai_confidence": 92.5
}
```

### Agent Messages (Human Takeover)

The dashboard automatically calls the Supabase API when agents send messages. Configure your n8n workflow to:

1. Listen to Supabase webhook for new `messages` with `sender_type = 'human_agent'`
2. Send via WhatsApp Business API

## 📊 Database Schema

### conversations
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| phone_number | VARCHAR(20) | WhatsApp number |
| customer_name | VARCHAR(255) | Customer name |
| status | VARCHAR(50) | ai_active, human_active, etc. |
| language | VARCHAR(10) | ar, en |
| is_vip | BOOLEAN | VIP customer flag |
| sentiment | VARCHAR(20) | positive, neutral, negative |
| last_message_at | TIMESTAMPTZ | Last activity |
| unread_count | INTEGER | Unread messages |

### messages
| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| conversation_id | UUID | FK to conversations |
| sender_type | VARCHAR(20) | customer, ai, human_agent, system |
| message_text | TEXT | Message content |
| direction | VARCHAR(10) | inbound, outbound |
| ai_confidence | DECIMAL(5,2) | AI confidence score |
| created_at | TIMESTAMPTZ | Timestamp |

## 🔒 Security

- Row Level Security (RLS) enabled on all tables
- Service role key for n8n (backend only)
- Anon key for dashboard (authenticated users)
- Data encryption in transit and at rest

## 🌐 Deployment

### Web Hosting (Recommended: Vercel/Netlify)

```bash
# Build for web
flutter build web --release

# Output in build/web/
```

### Firebase Hosting

```bash
firebase init hosting
flutter build web
firebase deploy
```

## 🤝 Support

- **Technical Issues:** support@vividsystems.co
- **Documentation:** https://docs.vividsystems.co
- **Emergency:** Contact Vivid team directly

## 📜 License

Proprietary - Vivid Algorithms W.L.L. 2025
Developed for 3B's Gents Salon, Manama, Kingdom of Bahrain

---

Built with 💙 by **Vivid Algorithms**

*Transforming customer conversations with AI*
