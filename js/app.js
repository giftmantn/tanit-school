// ============================================================
// TANIT SCHOOL — SHARED APP LOGIC
// Supabase client, auth helpers, utilities, icons
// ============================================================

let sb = null;

// The @supabase/supabase-js UMD build exposes a global `supabase`
// with a `createClient` method. We alias it to `sb` to avoid a
// global name collision.
function initSupabase() {
  const lib = window.supabase;
  const url = window.SUPABASE_URL || "";
  if (!lib || !url || url.indexOf("YOUR_") === 0) {
    sb = null;
    return;
  }
  sb = lib.createClient(url, window.SUPABASE_ANON_KEY || "");
}

// ---------- Auth helpers ----------
async function getSession() {
  if (!sb) return null;
  const { data, error } = await sb.auth.getSession();
  return error ? null : data.session;
}

async function getProfile(session) {
  if (!sb || !session) return null;
  const { data, error } = await sb
    .from("profiles")
    .select("*")
    .eq("id", session.user.id)
    .maybeSingle();
  return error ? null : data;
}

// Returns { session, profile }
async function getAuth() {
  const session = await getSession();
  const profile = session ? await getProfile(session) : null;
  return { session, profile };
}

// Redirect to a page with a flash message
function flash(message) {
  sessionStorage.setItem("tanit_flash", message);
}

function takeFlash() {
  const m = sessionStorage.getItem("tanit_flash");
  sessionStorage.removeItem("tanit_flash");
  return m;
}

// ---------- Theme (dark / light) ----------
function getTheme() {
  return localStorage.getItem("tanit_theme") || "light";
}

function setTheme(theme) {
  localStorage.setItem("tanit_theme", theme);
  applyTheme();
}

function applyTheme() {
  const theme = getTheme();
  document.documentElement.setAttribute("data-theme", theme);
  document.querySelectorAll(".theme-toggle").forEach((btn) => {
    const dark = theme === "dark";
    const sun = btn.querySelector(".sun");
    const moon = btn.querySelector(".moon");
    if (sun) sun.style.display = dark ? "block" : "none";
    if (moon) moon.style.display = dark ? "none" : "block";
  });
}

// ---------- Google Drive helpers ----------
// Extract the file ID from any Google Drive / Docs share link
function driveFileId(url) {
  if (!url) return null;
  const m = String(url).match(/\/d\/([a-zA-Z0-9_-]+)/);
  if (m) return m[1];
  const m2 = String(url).match(/[?&]id=([a-zA-Z0-9_-]+)/);
  if (m2) return m2[1];
  if (/^[a-zA-Z0-9_-]{15,}$/.test(String(url).trim())) return url.trim();
  return null;
}

function isValidDriveUrl(url) {
  return !!driveFileId(url);
}

// Direct-download link (for the Download button)
function driveDownloadUrl(url) {
  const id = driveFileId(url);
  return id ? `https://drive.google.com/uc?export=download&id=${id}` : url;
}

// Link that opens Google Drive directly
function driveOpenUrl(url) {
  const id = driveFileId(url);
  return id ? `https://drive.google.com/file/d/${id}/view` : url;
}

// Embeddable preview link (works for PDFs and many documents)
function drivePreviewUrl(url) {
  const id = driveFileId(url);
  return id ? `https://drive.google.com/file/d/${id}/preview` : url;
}

// Thumbnail
function driveThumbUrl(url) {
  const id = driveFileId(url);
  return id ? `https://drive.google.com/thumbnail?id=${id}&sz=w400` : "";
}

// Label for a document type, translated to the current language.
function docTypeLabel(doc, docTypes) {
  if (doc.doc_type_id && docTypes) {
    const dt = docTypes.find((d) => d.id === doc.doc_type_id);
    if (dt) return dt[`name_${getLang()}`] || dt.name_fr;
  }
  const type = doc.doc_type || "cours";
  let label = t("teacher.doc.type." + type) || type;
  if (type === "autre" && doc.doc_type_other) label += " — " + doc.doc_type_other;
  return label;
}

// ---------- Document card ----------
function docCard(doc, levels, subjects, sections, favIds, isLoggedIn, docTypes) {
  const level = levels.find((l) => l.id === doc.level_id);
  const subject = subjects.find((s) => s.id === doc.subject_id);
  const section = sections.find((s) => s.id === doc.section_id);
  const lang = getLang();
  const title = doc[`title_${lang}`] || doc.title_fr;
  const faved = favIds.has(doc.id);
  const thumb = driveThumbUrl(doc.drive_url);
  const typeLabel = docTypeLabel(doc, docTypes);

  const el = document.createElement("div");
  el.className = "doc-card";
  el.innerHTML = `
    <div class="doc-thumb">
      ${thumb ? `<img src="${thumb}" alt="" loading="lazy" onerror="this.style.display='none'">` : ""}
      <button class="icon-btn fav-btn ${faved ? "faved" : ""}" data-id="${doc.id}" title="${t("doc.add_fav")}">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="${faved ? "#eab308" : "none"}" stroke="currentColor" stroke-width="2"><path d="M12 17.27 18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/></svg>
      </button>
    </div>
    <div class="doc-body">
      <div class="doc-title">${escapeHtml(title)}</div>
      <div class="doc-meta">
        ${typeLabel ? `<span class="chip">${escapeHtml(typeLabel)}</span>` : ""}
        ${level ? `<span class="chip primary">${escapeHtml(level[`name_${lang}`] || level.name_fr)}</span>` : ""}
        ${subject ? `<span class="chip accent">${escapeHtml(subject[`name_${lang}`] || subject.name_fr)}</span>` : ""}
        ${section ? `<span class="chip neutral">${escapeHtml(section[`name_${lang}`] || section.name_fr)}</span>` : ""}
      </div>
      <div class="doc-footer">
        <a class="btn btn-sm" href="document.html?id=${doc.id}">${t("doc.open")}</a>
      </div>
    </div>`;

  const favBtn = el.querySelector(".fav-btn");
  favBtn.addEventListener("click", () => toggleFavorite(doc.id, favBtn));
  return el;
}

// Favorite toggle
async function toggleFavorite(docId, btn) {
  const { session } = await getAuth();
  if (!session) {
    alert(t("browse.login_fav"));
    return;
  }
  if (!sb) return;
  const faved = btn && btn.classList.contains("faved");
  if (faved) {
    await sb.from("favorites").delete().eq("user_id", session.user.id).eq("document_id", docId);
    if (btn) btn.classList.remove("faved");
  } else {
    await sb.from("favorites").insert({ user_id: session.user.id, document_id: docId });
    if (btn) btn.classList.add("faved");
  }
}

async function loadFavIds() {
  const { session } = await getAuth();
  if (!session || !sb) return new Set();
  const { data } = await sb.from("favorites").select("document_id").eq("user_id", session.user.id);
  return new Set((data || []).map((f) => f.document_id));
}

// ---------- Level / subject fetch ----------
// One shared safe wrapper: never throws, logs any DB error to the console so
// a single bad query can't blank the rest of the page.
async function safeSelect(table, columns, orderBy) {
  if (!sb) return [];
  try {
    const q = sb.from(table).select(columns);
    if (orderBy) q.order(orderBy);
    const { data, error } = await q;
    if (error) console.error(`fetch ${table}:`, error.message);
    return data || [];
  } catch (e) {
    console.error(`fetch ${table}:`, e.message);
    return [];
  }
}

async function fetchLevels() {
  return safeSelect("levels", "*", "ord");
}

async function fetchSubjects() {
  return safeSelect("subjects", "*", "ord");
}

// Sections (filières) — only meaningful for 2ème→4ème secondaire.
async function fetchSections() {
  return safeSelect("sections", "*", "ord");
}

async function fetchDocTypes() {
  return safeSelect("document_types", "*", "ord");
}

// Returns { [level_id]: [section_id, ...] }
async function fetchLevelSections() {
  const rows = await safeSelect("level_sections", "level_id, section_id");
  const map = {};
  (rows || []).forEach((r) => {
    (map[r.level_id] = map[r.level_id] || []).push(r.section_id);
  });
  return map;
}

// Returns { [level_id]: [subject_id, ...] }
async function fetchLevelSubjects() {
  const rows = await safeSelect("level_subjects", "level_id, subject_id");
  const map = {};
  (rows || []).forEach((r) => {
    (map[r.level_id] = map[r.level_id] || []).push(r.subject_id);
  });
  return map;
}

// Returns { [section_id]: [subject_id, ...] }
async function fetchSectionSubjects() {
  const rows = await safeSelect("section_subjects", "section_id, subject_id");
  const map = {};
  (rows || []).forEach((r) => {
    (map[r.section_id] = map[r.section_id] || []).push(r.subject_id);
  });
  return map;
}

// Levels that carry sections (2ème, 3ème, 4ème année secondaire).
const SECTION_LEVEL_ORDS = [11, 12, 13];

// ---------- Shared navbar / footer ----------
function renderNavbar(profile) {
  const nav = document.getElementById("navbar");
  if (!nav) return;
  const lang = getLang();
  const approved = !!(profile && profile.status === "approved");
  nav.innerHTML = `
    <div class="container nav-inner">
      <a href="index.html" class="brand">
        <span class="brand-logo">${lang === "ar" ? "ت" : "T"}</span>
        <span class="brand-text">${lang === "ar" ? window.SITE_NAME_AR : window.SITE_NAME}</span>
      </a>
      <button class="hamburger" aria-label="Menu">
        <span></span><span></span><span></span>
      </button>
      <nav class="nav-links" id="navLinks">
        <a class="link" href="browse.html" data-i18n="nav.browse"></a>
        ${approved ? `<a class="link" href="favorites.html" data-i18n="nav.favorites"></a>` : ""}
        ${approved && (profile.role === "teacher" || profile.role === "admin") ? `<a class="link" href="teacher.html" data-i18n="nav.teacher"></a>` : ""}
        ${approved && profile.role === "admin" ? `<a class="link" href="admin.html" data-i18n="nav.admin"></a>` : ""}
        ${approved ? `
          <span class="user-chip">
            <span>${escapeHtml(profile.full_name || profile.email || "")}</span>
            <span class="role">${t("role." + (profile.role || "student"))}</span>
          </span>
          <a class="link" href="#" id="logoutLink" data-i18n="nav.logout"></a>
        ` : `
          <a class="link" href="auth.html" data-i18n="nav.login"></a>
        `}
      </nav>
      <div class="lang-switch">
        <button data-lang="ar" class="${lang === "ar" ? "active" : ""}">العربية</button>
        <button data-lang="fr" class="${lang === "fr" ? "active" : ""}">FR</button>
        <button data-lang="en" class="${lang === "en" ? "active" : ""}">EN</button>
      </div>
      <button class="icon-btn theme-toggle" id="themeToggle" title="Theme">
        <svg class="sun" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="display:none"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>
        <svg class="moon" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>
      </button>
    </div>`;

  nav.querySelector(".hamburger").addEventListener("click", () => {
    nav.querySelector(".nav-links").classList.toggle("open");
  });
  nav.querySelectorAll(".lang-switch button").forEach((b) => {
    b.addEventListener("click", () => {
      setLang(b.dataset.lang);
      renderNavbar(profile);
    });
  });
  const themeToggle = nav.querySelector("#themeToggle");
  if (themeToggle) {
    themeToggle.addEventListener("click", () => {
      setTheme(getTheme() === "dark" ? "light" : "dark");
    });
  }
  applyTheme();
  const logout = nav.querySelector("#logoutLink");
  if (logout) {
    logout.addEventListener("click", async (e) => {
      e.preventDefault();
      if (sb) await sb.auth.signOut();
      flash(t("nav.logout"));
      window.location.href = "index.html";
    });
  }
  const page = window.location.pathname.split("/").pop() || "index.html";
  nav.querySelectorAll(".link[href]").forEach((a) => {
    if (a.getAttribute("href") === page) a.classList.add("active");
  });

  applyLang();
}

function renderFooter() {
  const foot = document.getElementById("footer");
  if (!foot) return;
  foot.innerHTML = `
    <div class="container footer-inner">
      <span class="brand"><span class="brand-logo">${getLang() === "ar" ? "ت" : "T"}</span><span class="brand-text"></span></span>
      <span data-i18n="footer.rights"></span>
    </div>`;
  applyLang();
}

// ---------- Misc helpers ----------
// Free client-side translation with a fallback chain:
//  1. Google's public translate endpoint
//  2. MyMemory (free, no key)
// Returns null on failure so callers can silently skip.
async function translateText(text, fromLang, toLang) {
  const providers = [
    `https://translate.googleapis.com/translate_a/single?client=gtx&sl=${fromLang}&tl=${toLang}&dt=t&q=${encodeURIComponent(text)}`,
    `https://api.mymemory.translated.net/get?q=${encodeURIComponent(text)}&langpair=${fromLang}|${toLang}`,
  ];
  for (const url of providers) {
    try {
      const res = await fetch(url);
      if (!res.ok) continue;
      const data = await res.json();
      let out = "";
      if (Array.isArray(data[0])) {
        out = data[0].map((seg) => seg[0]).join("");
      } else if (data.responseData && data.responseData.translatedText) {
        out = data.responseData.translatedText;
      }
      out = String(out).trim();
      if (out && out !== text) return out;
    } catch (e) {
      console.warn("translateText provider failed:", url, e);
    }
  }
  console.warn("translateText: all providers failed for", text, fromLang, "->", toLang);
  return null;
}

function escapeHtml(str) {
  if (str == null) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// Build an options list for <select>
function optionList(items, selectedId, nameFn) {
  return items
    .map((it) => `<option value="${it.id}" ${it.id === selectedId ? "selected" : ""}>${escapeHtml(nameFn(it))}</option>`)
    .join("");
}

// Auth guard: redirects to auth.html if not logged in / wrong role / not approved
// Accepts a single role ("teacher") or an array of allowed roles (["teacher","admin"]).
async function requireRole(roles) {
  const { session, profile } = await getAuth();
  if (!session) {
    flash(t("auth.error.login"));
    window.location.href = "auth.html";
    return null;
  }
  if (!profile || profile.status !== "approved") {
    window.location.href = "auth.html";
    return null;
  }
  const allowed = Array.isArray(roles) ? roles : roles ? [roles] : null;
  if (allowed && !allowed.includes(profile.role)) {
    alert(t("admin.no_perm"));
    window.location.href = "index.html";
    return null;
  }
  return { session, profile };
}

function showAlert(id, message, type) {
  const el = document.getElementById(id);
  if (!el) return;
  el.textContent = message;
  el.className = "alert show " + type;
}

function clearAlert(id) {
  const el = document.getElementById(id);
  if (el) el.className = "alert";
}

document.addEventListener("DOMContentLoaded", () => {
  initSupabase();
  applyTheme();
  applyLang();
  renderFooter();
});
