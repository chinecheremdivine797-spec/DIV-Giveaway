const loginForm = document.getElementById('loginForm');
const loginPanel = document.getElementById('loginPanel');
const dashboard = document.getElementById('dashboard');
const loginMessage = document.getElementById('loginMessage');
const body = document.getElementById('participantsBody');

const ready = Boolean(window.DIV_SUPABASE?.url && window.DIV_SUPABASE?.anonKey && window.supabase);
const client = ready ? window.supabase.createClient(window.DIV_SUPABASE.url, window.DIV_SUPABASE.anonKey) : null;
let participants = [];

loginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  if (!client) return showLogin('Supabase configuration is missing.', true);
  showLogin('Signing in…');
  const data = Object.fromEntries(new FormData(loginForm).entries());
  const { error } = await client.auth.signInWithPassword({ email: data.email.trim(), password: data.password });
  if (error) return showLogin('Sign-in failed. Check your email and password.', true);
  await loadDashboard();
});

document.getElementById('logoutBtn').addEventListener('click', async () => {
  if (client) await client.auth.signOut();
  dashboard.hidden = true;
  loginPanel.hidden = false;
  loginForm.reset();
});

document.getElementById('search').addEventListener('input', renderRows);
document.getElementById('statusFilter').addEventListener('change', renderRows);

async function loadDashboard() {
  if (!client) return;
  const { data: userData } = await client.auth.getUser();
  if (!userData?.user) return;

  const { data: admin } = await client.from('admin_users').select('user_id').eq('user_id', userData.user.id).maybeSingle();
  if (!admin) {
    await client.auth.signOut();
    return showLogin('This account is not authorized as a DIV admin.', true);
  }

  loginPanel.hidden = true;
  dashboard.hidden = false;
  loginMessage.textContent = '';
  await refresh();
}

async function refresh() {
  body.innerHTML = '<tr><td colspan="8" style="padding:25px;color:var(--muted)">Loading participants…</td></tr>';
  const { data, error } = await client.from('participants').select('*').order('created_at', { ascending: false });
  if (error) {
    body.innerHTML = `<tr><td colspan="8" style="padding:25px;color:#b42318">Could not load participants: ${escapeHtml(error.message)}</td></tr>`;
    return;
  }
  participants = data || [];
  updateStats();
  renderRows();
}

function updateStats() {
  document.getElementById('totalEntries').textContent = participants.length;
  document.getElementById('verifiedEntries').textContent = participants.filter(p => p.verification_status === 'verified').length;
  document.getElementById('selectedEntries').textContent = participants.filter(p => p.status === 'selected').length;
  document.getElementById('sentEntries').textContent = participants.filter(p => ['sent', 'claimed'].includes(p.gift_card_status)).length;
}

function renderRows() {
  const search = document.getElementById('search').value.trim().toLowerCase();
  const status = document.getElementById('statusFilter').value;
  const filtered = participants.filter(p => {
    const text = `${p.full_name} ${p.email}`.toLowerCase();
    const statusMatch = status === 'all' ||
      (status === 'pending' && ['pending','under_review'].includes(p.verification_status)) ||
      (status === 'verified' && p.verification_status === 'verified') ||
      (status === 'sent' && ['sent','claimed'].includes(p.gift_card_status)) ||
      p.status === status;
    return (!search || text.includes(search)) && statusMatch;
  });

  if (!filtered.length) {
    body.innerHTML = '<tr><td colspan="8" style="padding:25px;color:var(--muted)">No participants found.</td></tr>';
    return;
  }

  body.innerHTML = filtered.map(p => {
    const req = `${icon(p.share_repost_verified)} Share ${icon(p.follow_channels_verified)} Follow ${icon(p.youtube_subscribed_verified)} YouTube`;
    const overall = p.verification_status === 'verified' ? 'Verified' : p.verification_status === 'rejected' ? 'Rejected' : 'Pending';
    return `<tr>
      <td>${escapeHtml(p.full_name)}</td><td>${escapeHtml(p.email)}</td><td>${escapeHtml(p.country)}</td><td>${escapeHtml(p.app_interest)}</td>
      <td style="white-space:nowrap">${req}</td><td>${formatDate(p.created_at)}</td>
      <td><strong>${escapeHtml(p.status)}</strong><br><small>${overall}</small></td>
      <td style="white-space:nowrap"><button type="button" class="header-link" onclick="verifyEntry('${p.id}')">Verify</button> <button type="button" class="header-link" onclick="selectEntry('${p.id}')">${p.status === 'selected' ? 'Unselect' : 'Select'}</button> <button type="button" class="header-link" onclick="markSent('${p.id}')">Mark sent</button></td>
    </tr>`;
  }).join('');
}

window.verifyEntry = async (id) => {
  const p = participants.find(x => x.id === id);
  if (!p) return;
  const share = confirm(`Verify SHARE/REPOST for ${p.full_name}?\nOK = verified, Cancel = leave unchanged.`);
  if (!share) return;
  const follow = confirm('Verify that the participant follows the required DIV channels?');
  const youtube = confirm('Verify that the participant subscribed to the DIV YouTube channel?');
  const { error } = await client.rpc('verify_giveaway_entry', {
    participant_id: id,
    new_share_repost_verified: share,
    new_follow_channels_verified: follow,
    new_youtube_subscribed_verified: youtube,
    new_admin_notes: null
  });
  if (error) return alert(`Verification failed: ${error.message}`);
  await refresh();
};

window.selectEntry = async (id) => {
  const p = participants.find(x => x.id === id);
  if (!p) return;
  if (p.verification_status !== 'verified') return alert('Verify all giveaway requirements before selecting this participant.');
  const next = p.status === 'selected' ? 'eligible' : 'selected';
  const { error } = await client.from('participants').update({ status: next }).eq('id', id);
  if (error) return alert(`Could not update winner status: ${error.message}`);
  await refresh();
};

window.markSent = async (id) => {
  const p = participants.find(x => x.id === id);
  if (!p) return;
  if (p.status !== 'selected') return alert('Select the verified participant first.');
  const { error } = await client.from('participants').update({ gift_card_status: 'sent', gift_card_sent_at: new Date().toISOString() }).eq('id', id);
  if (error) return alert(`Could not record gift-card delivery: ${error.message}`);
  await refresh();
};

function showLogin(text, error = false) { loginMessage.className = `form-message ${error ? 'error' : 'success'} show`; loginMessage.textContent = text; }
function icon(v) { return v ? '✓' : '○'; }
function formatDate(v) { return v ? new Date(v).toLocaleString() : '—'; }
function escapeHtml(v) { return String(v ?? '').replace(/[&<>'"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','\"':'&quot;'}[c])); }

(async () => {
  if (!client) return showLogin('Supabase configuration is missing.', true);
  const { data } = await client.auth.getSession();
  if (data?.session) await loadDashboard();
})();
