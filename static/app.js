const supabaseUrl = document.body.dataset.supabaseUrl;
const supabaseAnon = document.body.dataset.supabaseAnon;
const supabase = supabaseUrl && supabaseAnon ? window.supabase.createClient(supabaseUrl, supabaseAnon) : null;

let accessToken = null;
let currentUser = null;

const byId = (id) => document.getElementById(id);

async function ensureSession() {
  if (!supabase) return null;
  const { data } = await supabase.auth.getSession();
  accessToken = data.session?.access_token || null;
  return data.session || null;
}

async function apiFetch(path, options = {}) {
  if (!accessToken) await ensureSession();
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {}),
  };
  if (accessToken) headers.Authorization = `Bearer ${accessToken}`;
  const res = await fetch(path, { ...options, headers });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw data;
  return data;
}

async function loadSession() {
  const session = await ensureSession();
  if (!session) return null;
  const result = await apiFetch("/api/auth/session", {
    method: "POST",
    body: JSON.stringify({ token: accessToken }),
  });
  currentUser = result.user;
  return currentUser;
}

function setRoleLabel() {
  const label = byId("roleLabel");
  if (label && currentUser) {
    label.textContent = `Role: ${currentUser.role || "member"}`;
  }
}

async function initIndex() {
  const emailInput = byId("email");
  const sendLink = byId("sendLink");
  const authStatus = byId("authStatus");
  const checkSession = byId("checkSession");
  const signOut = byId("signOut");
  const sessionOutput = byId("sessionOutput");

  if (sendLink) {
    sendLink.onclick = async () => {
      const email = emailInput.value.trim();
      if (!email) return;
      const { error } = await supabase.auth.signInWithOtp({ email });
      authStatus.textContent = error ? error.message : "Magic link sent.";
    };
  }

  if (checkSession) {
    checkSession.onclick = async () => {
      const session = await ensureSession();
      sessionOutput.textContent = JSON.stringify(session, null, 2);
    };
  }

  if (signOut) {
    signOut.onclick = async () => {
      await supabase.auth.signOut();
      sessionOutput.textContent = "Signed out.";
    };
  }
}

async function initDashboard() {
  await loadSession();
  setRoleLabel();
  const announcementControls = byId("announcementControls");
  if (announcementControls && currentUser && !["advisor", "admin"].includes(currentUser.role)) {
    announcementControls.style.display = "none";
  }

  const createPost = byId("createPost");
  const loadPosts = byId("loadPosts");
  const postsOutput = byId("postsOutput");

  if (createPost) {
    createPost.onclick = async () => {
      const payload = {
        caption: byId("postCaption").value,
        visibility: byId("postVisibility").value,
      };
      const result = await apiFetch("/api/posts", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      postsOutput.textContent = JSON.stringify(result, null, 2);
    };
  }

  if (loadPosts) {
    loadPosts.onclick = async () => {
      const result = await apiFetch("/api/posts");
      postsOutput.textContent = JSON.stringify(result, null, 2);
    };
  }

  const createEvent = byId("createEvent");
  const loadEvents = byId("loadEvents");
  const eventsOutput = byId("eventsOutput");
  if (createEvent) {
    createEvent.onclick = async () => {
      const payload = {
        title: byId("eventTitle").value,
        start_at: byId("eventStart").value,
        visibility: byId("eventVisibility").value,
      };
      const result = await apiFetch("/api/events", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      eventsOutput.textContent = JSON.stringify(result, null, 2);
    };
  }
  if (loadEvents) {
    loadEvents.onclick = async () => {
      const result = await apiFetch("/api/events");
      eventsOutput.textContent = JSON.stringify(result, null, 2);
    };
  }

  const createAnnouncement = byId("createAnnouncement");
  const loadAnnouncements = byId("loadAnnouncements");
  const annOutput = byId("announcementsOutput");
  if (createAnnouncement) {
    createAnnouncement.onclick = async () => {
      const payload = {
        title: byId("annTitle").value,
        body: byId("annBody").value,
        scope: byId("annScope").value,
        district_id: byId("annDistrictId").value || null,
        chapter_id: byId("annChapterId").value || null,
      };
      const result = await apiFetch("/api/announcements", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      annOutput.textContent = JSON.stringify(result, null, 2);
    };
  }
  if (loadAnnouncements) {
    loadAnnouncements.onclick = async () => {
      const result = await apiFetch("/api/announcements");
      annOutput.textContent = JSON.stringify(result, null, 2);
    };
  }

  const createHub = byId("createHub");
  const loadHub = byId("loadHub");
  const hubOutput = byId("hubOutput");
  if (createHub) {
    createHub.onclick = async () => {
      const payload = {
        title: byId("hubTitle").value,
        body: byId("hubBody").value,
        file_path: byId("hubFilePath").value || null,
        visibility: byId("hubVisibility").value,
      };
      const result = await apiFetch("/api/hub", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      hubOutput.textContent = JSON.stringify(result, null, 2);
    };
  }
  if (loadHub) {
    loadHub.onclick = async () => {
      const result = await apiFetch("/api/hub");
      hubOutput.textContent = JSON.stringify(result, null, 2);
    };
  }

  const saveProfile = byId("saveProfile");
  if (saveProfile) {
    saveProfile.onclick = async () => {
      if (!currentUser?.id) return;
      const userPayload = {
        display_name: byId("displayName").value || null,
        username: byId("username").value || null,
        district_id: byId("districtId").value || null,
        chapter_id: byId("chapterId").value || null,
      };
      const profilePayload = {
        bio: byId("bio").value || "",
      };
      await apiFetch(`/api/users/${currentUser.id}`, {
        method: "PATCH",
        body: JSON.stringify(userPayload),
      });
      await apiFetch(`/api/profiles/${currentUser.id}`, {
        method: "PATCH",
        body: JSON.stringify(profilePayload),
      });
    };
  }

  const refreshSession = byId("refreshSession");
  if (refreshSession) {
    refreshSession.onclick = async () => {
      await loadSession();
      setRoleLabel();
    };
  }
  const logout = byId("logout");
  if (logout) {
    logout.onclick = async () => {
      await supabase.auth.signOut();
      window.location.href = "/";
    };
  }
}

if (window.location.pathname === "/") {
  initIndex();
}
if (window.location.pathname === "/dashboard") {
  initDashboard();
}
