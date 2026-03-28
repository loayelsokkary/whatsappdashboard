import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const { sessionUrl, fileBase64, mimeType, accessToken } = await req.json();

    if (!sessionUrl || !fileBase64 || !accessToken) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: sessionUrl, fileBase64, accessToken" }),
        { status: 400, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
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
        { status: metaResponse.status, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
      );
    }

    const metaData = await metaResponse.json();

    // Return the upload handle
    return new Response(
      JSON.stringify(metaData),
      { status: 200, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
    );

  } catch (error) {
    console.error("proxy-meta-upload error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
    );
  }
});
