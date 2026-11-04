// Phase 5 — the ERP seam. Populates `client_financial_snapshot` from a
// dedicated, read-only Oracle view, so the Flutter app only ever reads our own
// Supabase table. This function is the ONLY thing that touches the ERP.
//
// Isolation, restated: the Flutter app holds no Oracle package and no ERP
// credentials; it never reads Oracle live on page load. This function runs on
// the internal network (self-hosted/edge), reads a dedicated view through its
// own read-only Oracle user, and upserts snapshots keyed by (client_id, as_of).
//
// How it reaches Oracle: via an internal "bridge" HTTP endpoint that exposes
// the read-only view as JSON. Keeping Oracle behind the bridge means the ERP
// credentials live on the internal service, not here — this function holds only
// the bridge URL + a token. (If you deploy this self-hosted and prefer a direct
// driver, swap `fetchFromBridge` for a node-oracledb query against the view;
// the rest is unchanged.)
//
// The join key is `client.erp_client_code` — the hand-typed column. Rows whose
// erp_client_code is not set are skipped: no code, no link.
//
// Secrets (env; never in the repo):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (injected by the platform)
//   ORACLE_BRIDGE_URL     internal endpoint returning the view as JSON
//   ORACLE_BRIDGE_TOKEN   bearer token for that endpoint

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BRIDGE_URL = Deno.env.get("ORACLE_BRIDGE_URL") ?? "";
const BRIDGE_TOKEN = Deno.env.get("ORACLE_BRIDGE_TOKEN") ?? "";

const db = createClient(SUPABASE_URL, SERVICE_ROLE);

interface OutstandingRow {
  erp_client_code: string;
  total_outstanding: number;
  overdue_90_plus: number;
}

/// Reads the read-only Oracle view (client-wise outstanding) via the internal
/// bridge. Returns one row per ERP client code.
async function fetchFromBridge(): Promise<OutstandingRow[]> {
  if (!BRIDGE_URL) throw new Error("ORACLE_BRIDGE_URL not configured");
  const res = await fetch(BRIDGE_URL, {
    headers: BRIDGE_TOKEN ? { Authorization: `Bearer ${BRIDGE_TOKEN}` } : {},
  });
  if (!res.ok) throw new Error(`bridge ${res.status}: ${await res.text()}`);
  return await res.json() as OutstandingRow[];
}

Deno.serve(async () => {
  try {
    // Map erp_client_code -> our client.id. Only clients with a code linked.
    const { data: clients, error: cErr } = await db
      .from("client")
      .select("id, erp_client_code")
      .not("erp_client_code", "is", null);
    if (cErr) throw cErr;
    const byCode = new Map<string, string>();
    for (const c of clients ?? []) {
      if (c.erp_client_code) byCode.set(String(c.erp_client_code).trim(), c.id);
    }

    const rows = await fetchFromBridge();
    const asOf = new Date().toISOString().slice(0, 10); // today, IST-agnostic date

    const upserts = [];
    let skipped = 0;
    for (const r of rows) {
      const clientId = byCode.get(String(r.erp_client_code).trim());
      if (!clientId) {
        skipped++;
        continue;
      }
      upserts.push({
        client_id: clientId,
        as_of: asOf,
        total_outstanding: r.total_outstanding,
        overdue_90_plus: r.overdue_90_plus,
        synced_at: new Date().toISOString(),
      });
    }

    if (upserts.length > 0) {
      const { error: uErr } = await db
        .from("client_financial_snapshot")
        .upsert(upserts, { onConflict: "client_id,as_of" });
      if (uErr) throw uErr;
    }

    return new Response(
      JSON.stringify({ synced: upserts.length, skipped, as_of: asOf }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
