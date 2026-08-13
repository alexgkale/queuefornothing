// POST /api/join - one more human enters the Global Queue.
import { createClient } from "@supabase/supabase-js";

const supa = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } }
  );

export default async function handler(req, res) {
    if (req.method !== "POST") {
          return res.status(405).json({ error: "method not allowed" });
    }
    const country = (req.headers["x-vercel-ip-country"] || "XX").toString();
    const { data, error } = await supa.rpc("qfn_join", { p_country: country });
    if (error) return res.status(500).json({ error: error.message });
    res.setHeader("cache-control", "no-store");
    return res.status(200).json(data);
}
