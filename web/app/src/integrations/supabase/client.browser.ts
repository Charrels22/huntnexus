import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const supabaseUrl = "https://urbncbjapasnjqjqicjv.supabase.co";
const publishableKey = "sb_publishable_geE8f_NT1lzxlUfSoCzT9w_rd4U-HoL";

let browserClient: SupabaseClient | null = null;

export function getSupabaseBrowserClient() {
  if (typeof window === "undefined") return null;

  if (!browserClient) {
    browserClient = createClient(supabaseUrl, publishableKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    });
  }

  return browserClient;
}
