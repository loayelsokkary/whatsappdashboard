# Supabase Edge Functions

Project ref: `zxvjzaowvzvfgrzdimbm`

## Functions

### `proxy-meta-upload`

**Purpose:** CORS proxy for uploading images to Meta's Resumable Upload API from Flutter web.

Flutter web cannot call Meta's upload endpoint directly due to CORS restrictions. This function receives the image bytes (base64-encoded) from the Flutter client, forwards them to Meta, and returns Meta's upload handle (`{ "h": "..." }`).

**Called by:** `outreach_provider.dart` → `uploadImageToMeta()` (web path only)

**Request body:**
```json
{
  "sessionUrl": "https://graph.facebook.com/v21.0/<upload_id>",
  "fileBase64": "<base64 encoded image bytes>",
  "mimeType": "image/jpeg",
  "accessToken": "<Meta access token>"
}
```

**Response:**
```json
{ "h": "<Meta upload handle>" }
```

---

## Deploying

### Prerequisites
```bash
npm install -g supabase
supabase login
```

### Deploy a single function
```bash
supabase functions deploy proxy-meta-upload --project-ref zxvjzaowvzvfgrzdimbm
```

### Deploy all functions
```bash
supabase functions deploy --project-ref zxvjzaowvzvfgrzdimbm
```

### View logs
```bash
supabase functions logs proxy-meta-upload --project-ref zxvjzaowvzvfgrzdimbm
