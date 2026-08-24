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

const SELECTED_BUSINESS_KEY = "alwaysreviews_selected_business_id";

// Every page needs to know which business(es) the logged-in user belongs to.
// RLS means this query can only ever return rows this user actually belongs to.
// Returns every membership, joined with the business name for the switcher UI.
async function getMemberships(userId) {
  const { data, error } = await sb
    .from("business_members")
    .select("business_id, role, businesses(business_name)")
    .eq("user_id", userId);

  if (error) throw error;
  if (!data || data.length === 0) {
    throw new Error("Your account is not linked to a business yet. Contact the person who set up your access.");
  }
  return data.map(m => ({
    business_id: m.business_id,
    role: m.role,
    business_name: m.businesses?.business_name || "(unnamed business)"
  }));
}

// Resolves which business the current page should show data for.
// Non-admins (exactly one non-admin membership) always see their own business.
// Admins (any membership with role='admin') pick from a dropdown; the choice
// is remembered per-tab via sessionStorage, defaulting to the first business.
// Also renders the switcher dropdown into the topbar if admin access applies.
async function resolveBusinessContext(userId) {
  const memberships = await getMemberships(userId);
  const isAdmin = memberships.some(m => m.role === "admin");

  if (!isAdmin) {
    return { businessId: memberships[0].business_id, isAdmin: false, memberships };
  }

  let selected = sessionStorage.getItem(SELECTED_BUSINESS_KEY);
  if (!selected || !memberships.some(m => m.business_id === selected)) {
    selected = memberships[0].business_id;
    sessionStorage.setItem(SELECTED_BUSINESS_KEY, selected);
  }

  renderBusinessSwitcher(memberships, selected);

  return { businessId: selected, isAdmin: true, memberships };
}

function renderBusinessSwitcher(memberships, selectedId) {
  const whoami = document.querySelector(".topbar .whoami");
  if (!whoami) return;

  const select = document.createElement("select");
  select.className = "biz-switcher";
  select.innerHTML = memberships
    .map(m => `<option value="${m.business_id}" ${m.business_id === selectedId ? "selected" : ""}>${m.business_name}</option>`)
    .join("");

  select.addEventListener("change", () => {
    sessionStorage.setItem(SELECTED_BUSINESS_KEY, select.value);
    window.location.reload();
  });

  whoami.prepend(select);
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
