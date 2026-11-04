// Phase 4 — WhatsApp notifications via the Meta Cloud API.
//
// Drains `notification_outbox` (status = 'pending') and sends each as a
// WhatsApp template message through Finsys's existing Meta Cloud API setup,
// then marks the row sent/failed. Intended to run on a schedule (pg_cron ->
// `select net.http_post(...)`, or an external scheduler hitting this function).
//
// Secrets come from the function environment — NEVER hard-coded, never in the
// repo. Set them with: `supabase secrets set WHATSAPP_TOKEN=... WHATSAPP_PHONE_ID=...`
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (injected by the platform)
//   WHATSAPP_TOKEN            Meta Cloud API access token
//   WHATSAPP_PHONE_ID         Meta phone-number id
//   NOTIFY_FALLBACK_NUMBER    E.164 number to notify when a row has no recipient
//   WHATSAPP_TEMPLATE         approved template name (default: finsys_alert)

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const WHATSAPP_TOKEN = Deno.env.get("WHATSAPP_TOKEN") ?? "";
const WHATSAPP_PHONE_ID = Deno.env.get("WHATSAPP_PHONE_ID") ?? "";
const FALLBACK_NUMBER = Deno.env.get("NOTIFY_FALLBACK_NUMBER") ?? "";
const TEMPLATE = Deno.env.get("WHATSAPP_TEMPLATE") ?? "finsys_alert";

const db = createClient(SUPABASE_URL, SERVICE_ROLE);

async function sendWhatsApp(to: string, bodyText: string): Promise<void> {
  if (!WHATSAPP_TOKEN || !WHATSAPP_PHONE_ID) {
    throw new Error("WhatsApp credentials not configured");
  }
  const res = await fetch(
    `https://graph.facebook.com/v21.0/${WHATSAPP_PHONE_ID}/messages`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${WHATSAPP_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        messaging_product: "whatsapp",
        to,
        type: "template",
        template: {
          name: TEMPLATE,
          language: { code: "en" },
          components: [
            { type: "body", parameters: [{ type: "text", text: bodyText }] },
          ],
        },
      }),
    },
  );
  if (!res.ok) {
    throw new Error(`Meta API ${res.status}: ${await res.text()}`);
  }
}

function renderBody(row: Record<string, unknown>): string {
  const p = (row.payload ?? {}) as Record<string, unknown>;
  if (row.template === "sla_breach") {
    return `SLA breach: ${p.ticket_no} (${p.severity}) for ${p.client} — ` +
      `"${p.subject}". Assigned to ${p.assignee}.`;
  }
  return `Finsys Tracker: ${JSON.stringify(p)}`;
}

Deno.serve(async () => {
  const { data: rows, error } = await db
    .from("notification_outbox")
    .select("*")
    .eq("status", "pending")
    .limit(50);
  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let sent = 0;
  let failed = 0;
  for (const row of rows ?? []) {
    const to = (row.recipient as string) || FALLBACK_NUMBER;
    try {
      if (!to) throw new Error("no recipient and no NOTIFY_FALLBACK_NUMBER");
      await sendWhatsApp(to, renderBody(row));
      await db.from("notification_outbox")
        .update({ status: "sent", sent_at: new Date().toISOString() })
        .eq("id", row.id);
      sent++;
    } catch (e) {
      await db.from("notification_outbox")
        .update({ status: "failed", error: String(e) })
        .eq("id", row.id);
      failed++;
    }
  }

  return new Response(JSON.stringify({ processed: (rows ?? []).length, sent, failed }), {
    headers: { "Content-Type": "application/json" },
  });
});
