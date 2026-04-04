import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const {
      action,
      // Step 1 fields
      appId,
      apiVersion,
      fileType,
      fileLength,
      // Step 2 fields
      sessionUrl,
      fileBase64,
      mimeType,
      // Shared
      accessToken,
    } = await req.json();

    // ── Step 1: Create upload session ─────────────────────────────────────────
    if (action === "create_session") {
      if (!appId || !fileType || !fileLength || !accessToken) {
        return new Response(
          JSON.stringify({ error: "Missing required fields: appId, fileType, fileLength, accessToken" }),
          { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
        );
      }

      const version = apiVersion ?? "v21.0";
      const metaResponse = await fetch(
        `https://graph.facebook.com/${version}/${appId}/uploads?file_type=${fileType}&file_length=${fileLength}`,
        {
          method: "POST",
          headers: { "Authorization": `OAuth ${accessToken}` },
        }
      );

      const data = await metaResponse.json();
      if (!metaResponse.ok) {
        console.error("Meta create_session failed:", metaResponse.status, data);
      }
      return new Response(JSON.stringify(data), {
        status: metaResponse.ok ? 200 : metaResponse.status,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }

    // ── Step 2: Upload binary data ─────────────────────────────────────────────
    if (!sessionUrl || !fileBase64 || !accessToken) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: sessionUrl, fileBase64, accessToken" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    // Decode base64 to binary
    const binaryString = atob(fileBase64);
    const bytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i);
    }

    // Upload to Meta's resumable upload endpoint
    const metaResponse = await fetch(sessionUrl, {
      method: "POST",
      headers: {
        "Authorization": `OAuth ${accessToken}`,
        "file_offset": "0",
        "Content-Type": mimeType || "image/jpeg",
      },
      body: bytes,
    });

    if (!metaResponse.ok) {
      const errorText = await metaResponse.text();
      console.error("Meta upload failed:", metaResponse.status, errorText);
      return new Response(
        JSON.stringify({ error: `Meta upload failed: ${metaResponse.status}`, details: errorText }),
        { status: metaResponse.status, headers: { "Content-Type": "application/json", ...corsHeaders } }
      );
    }

    const metaData = await metaResponse.json();
    return new Response(JSON.stringify(metaData), {
      status: 200,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });

  } catch (error) {
    console.error("proxy-meta-upload error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders } }
    );
  }
});
