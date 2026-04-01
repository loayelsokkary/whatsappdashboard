# Outreach System Fixes

## 1. Empty Message Bubbles (Different Per User)

**Problem**: Some messages appeared as empty bubbles in the chat. The same message could show text for one user but appear empty for another, even on the same account.

**Root Cause**: Supabase realtime subscriptions use the anon key (`SupabaseService.client`), which respects Row Level Security (RLS). If `vivid_outreach_messages` has RLS enabled without a permissive policy for the anon role, `payload.newRecord` arrives with empty fields. Messages added to the UI from realtime would have empty `customerMessage`, `aiResponse`, and `managerResponse`, producing empty bubbles.

Different users see different empty bubbles because it depends on session timing: messages loaded via the initial HTTP fetch (admin client, bypasses RLS) display correctly, while messages that arrived via realtime during that user's session appear empty.

**Fix** (`lib/providers/outreach_provider.dart`): Both realtime callbacks (`subscribeToMessages` and `subscribeToAllMessages`) now only extract the message `id` from `payload.newRecord`, then re-fetch the full row via the admin client (`_db`) which bypasses RLS. This guarantees all message fields are populated.

```dart
// Before (broken): trusted realtime payload directly
callback: (payload) {
  final row = payload.newRecord;
  final msg = OutreachMessage.fromJson(row); // empty fields due to RLS
  _messages.add(msg);
}

// After (fixed): use payload only for ID, re-fetch via admin client
callback: (payload) async {
  final id = payload.newRecord['id']?.toString();
  final fullRow = await _db
      .from('vivid_outreach_messages')
      .select()
      .eq('id', id)
      .single();
  final msg = OutreachMessage.fromJson(fullRow); // full data
  _messages.add(msg);
}
```

**Alternative long-term fix**: Add a permissive RLS policy to `vivid_outreach_messages`:
```sql
ALTER TABLE vivid_outreach_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public_access" ON "vivid_outreach_messages" FOR ALL USING (true) WITH CHECK (true);
```
This would make realtime payloads include all fields, but the admin client re-fetch approach is safer regardless.

---

## 2. Broadcast Messages: Wrong Direction + Empty Text

**Problem**: Broadcast/template messages sent via n8n appeared on the left side (as inbound) and showed empty text, even though n8n inserted the data correctly.

**Root Cause**: The n8n broadcast workflow writes to `vivid_outreach_messages` using different field names than what the dashboard expected:

| What n8n writes | What the dashboard checked |
|---|---|
| `direction: 'outbound'` | `sent_by: 'manager'` or `sent_by: 'ai'` |
| `content: 'Hello Loay...'` | `manager_response`, `ai_response`, `customer_message` |

The `OutreachMessage` model didn't parse `direction` or `content` at all, so:
- `isOutbound` returned `false` (because `sent_by` was null) — message rendered on the left
- `displayText` returned `''` (because `manager_response`, `ai_response`, and `customer_message` were all empty) — empty bubble

**Fix** (`lib/models/outreach_models.dart`): Added `direction` and `content` fields to `OutreachMessage`:

```dart
// New fields
final String? direction;
final String? content;

// Updated fromJson
direction: json['direction'] as String?,
content: json['content'] as String?,

// Updated isOutbound — also checks direction field
bool get isOutbound =>
    sentBy == 'manager' ||
    sentBy == 'ai' ||
    direction == 'outbound';

// Updated displayText — also checks content field
String get displayText {
  if (managerResponse != null && managerResponse!.isNotEmpty) return managerResponse!;
  if (aiResponse != null && aiResponse!.isNotEmpty) return aiResponse!;
  if (content != null && content!.isNotEmpty) return content!;
  return customerMessage;
}
```

---

## 3. Duplicate Messages When Sending Media

**Problem**: When a manager sent a PDF or image, the message appeared twice in the chat.

**Root Cause**: Race condition between `sendMessage()` and the realtime subscription. When `sendMessage` does `await _db.insert(row).select().single()`, the DB commits the row and the realtime WebSocket event can fire before the HTTP response returns. The realtime callback adds the message to `_messages` first, then `sendMessage` adds it again.

**Fix** (`lib/providers/outreach_provider.dart`): Added a dedup check in `sendMessage` before adding to the list:

```dart
final inserted = await _db.from('vivid_outreach_messages').insert(row).select().single();
final newMsg = OutreachMessage.fromJson(inserted);
// Dedup: realtime may have already added this message
if (!_messages.any((m) => m.id == newMsg.id)) {
  _messages.add(newMsg);
}
```

---

## Files Changed

| File | Changes |
|---|---|
| `lib/models/outreach_models.dart` | Added `direction` and `content` fields, updated `isOutbound` and `displayText` |
| `lib/providers/outreach_provider.dart` | Realtime callbacks re-fetch via admin client; dedup in `sendMessage` |
