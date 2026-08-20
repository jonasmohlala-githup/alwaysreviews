// Shared Supabase client + auth helpers used across all pages.
// The anon/publishable key is safe to embed in client-side code — every
// query it makes is still scoped by Row Level Security on the server.
const SUPABASE_URL = "https://xbmoomufmxicwymwbovg.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_0_B9DhekLQRu5mx0Im7MZA_DbyyUlPw";
const STORAGE_BUCKET = "customer-project-images";

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function getSession() {
  const { data: { session } } = await sb.auth.getSession();
  return session;
}

// Every page needs the business_id tied to the logged-in user. RLS means this
// query can only ever return businesses this user actually belongs to.
async function getCurrentBusinessId(userId) {
  const { data, error } = await sb
    .from("business_members")
    .select("business_id")
    .eq("user_id", userId)
    .limit(1);

  if (error) throw error;
  if (!data || data.length === 0) {
    throw new Error("Your account is not linked to a business yet. Contact the person who set up your access.");
  }
  return data[0].business_id;
}

async function sendMagicLink(email, redirectTo) {
  return sb.auth.signInWithOtp({
    email,
    options: { emailRedirectTo: redirectTo || window.location.href }
  });
}

async function signOut() {
  await sb.auth.signOut();
}
