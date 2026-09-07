const loginForm = document.getElementById('loginForm');
const loginPanel = document.getElementById('loginPanel');
const dashboard = document.getElementById('dashboard');
const loginMessage = document.getElementById('loginMessage');

loginForm.addEventListener('submit', async (event) => {
  event.preventDefault();
  loginMessage.className = 'form-message success show';
  loginMessage.textContent = 'Backend authentication is not connected yet. Configure Supabase before using admin access.';
});

document.getElementById('logoutBtn').addEventListener('click', () => {
  dashboard.hidden = true;
  loginPanel.hidden = false;
});

document.getElementById('search').addEventListener('input', filterRows);
document.getElementById('statusFilter').addEventListener('change', filterRows);

function filterRows() {
  // Participant rows will be populated only after an authenticated backend query is connected.
  const search = document.getElementById('search').value.trim().toLowerCase();
  const status = document.getElementById('statusFilter').value;
  document.querySelectorAll('#participantsBody tr[data-search]').forEach(row => {
    const matchesSearch = !search || row.dataset.search.includes(search);
    const matchesStatus = status === 'all' || row.dataset.status === status;
    row.hidden = !(matchesSearch && matchesStatus);
  });
}