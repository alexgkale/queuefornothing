// GET /api/state?ticket=N - where do I stand in the Global Queue?
import { createClient } from "@supabase/supabase-js";

const supa = createClient(
  process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
      { auth: { persistSession: false } }
      );

      export default async function handler(req, res) {
        const ticket = parseInt(req.query.ticket, 10) || 0;
          const { data, error } = await supa.rpc("qfn_state", { p_ticket: ticket });
            if (error) return res.status(500).json({ error: error.message });
              res.setHeader("cache-control", "no-store");
                return res.status(200).json(data);
                }
                
