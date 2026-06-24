// Config da API
const API_BASE = '/api';
const TOKEN_KEY = 'admin_token';

// Estado
let currentPage = 1;
let currentSearch = '';
let allUsers = [];
let perPage = 10;

// === AUTO-LOGIN CHECK ===
document.addEventListener('DOMContentLoaded', () => {
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) {
    showDashboard(token);
  } else {
    showLogin();
  }
  initLoginForm();
  initSearch();
});

// === NAVEGAÇÃO ===
function showLogin() {
  document.getElementById('login-page').classList.remove('hidden');
  document.getElementById('dashboard-page').classList.add('hidden');
}

function showDashboard(token) {
  document.getElementById('login-page').classList.add('hidden');
  document.getElementById('dashboard-page').classList.remove('hidden');
  loadDashboard(token);
}

// === LOGIN ===
function initLoginForm() {
  const form = document.getElementById('login-form');
  if (!form) return;
  
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    const btn = document.getElementById('btn-login');
    const errorDiv = document.getElementById('login-error');
    
    btn.disabled = true;
    btn.textContent = 'Entrando...';
    errorDiv.classList.add('hidden');
    
    try {
      const res = await fetch(`${API_BASE}/users/sign_in`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user: { email, password } })
      });
      
      const data = await res.json();
      
      if (res.ok && data.token) {
        localStorage.setItem(TOKEN_KEY, data.token);
        localStorage.setItem('admin_email', data.user?.email || email);
        showDashboard(data.token);
      } else {
        errorDiv.textContent = data.error || data.errors?.[0] || 'Credenciais inválidas';
        errorDiv.classList.remove('hidden');
      }
    } catch (err) {
      errorDiv.textContent = 'Erro ao conectar com o servidor';
      errorDiv.classList.remove('hidden');
    } finally {
      btn.disabled = false;
      btn.textContent = 'Entrar';
    }
  });
}

// === LOGOUT ===
async function logout() {
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) {
    try {
      await fetch(`${API_BASE}/users/sign_out`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${token}` }
      });
    } catch (e) {}
  }
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem('admin_email');
  showLogin();
  document.getElementById('email').value = '';
  document.getElementById('password').value = '';
}

// === DASHBOARD ===
async function loadDashboard(token) {
  const email = localStorage.getItem('admin_email');
  if (email) {
    document.getElementById('user-email').textContent = email;
  }
  
  try {
    await Promise.all([loadStats(token), loadUsers(token)]);
  } catch (err) {
    console.error('Erro ao carregar dashboard:', err);
  }
}

// === STATS ===
async function loadStats(token) {
  const res = await fetch(`${API_BASE}/users`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  if (!res.ok) return;
  
  const users = await res.json();
  const total = users.length;
  const confirmed = users.filter(u => u.confirmed_at).length;
  const pending = total - confirmed;
  const admins = users.filter(u => u.role === 'admin').length;
  
  document.getElementById('stat-total').textContent = total;
  document.getElementById('stat-confirmed').textContent = confirmed;
  document.getElementById('stat-pending').textContent = pending;
  document.getElementById('stat-admins').textContent = admins;
}

// === USERS LIST ===
async function loadUsers(token) {
  const res = await fetch(`${API_BASE}/users`, {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  if (!res.ok) return;
  
  allUsers = await res.json();
  renderUsers();
}

function renderUsers() {
  const tbody = document.getElementById('users-table-body');
  if (!tbody) return;
  
  // Filter
  let filtered = allUsers;
  if (currentSearch) {
    filtered = allUsers.filter(u => 
      u.email.toLowerCase().includes(currentSearch.toLowerCase())
    );
  }
  
  // Paginate
  const start = (currentPage - 1) * perPage;
  const end = start + perPage;
  const pageUsers = filtered.slice(start, end);
  
  if (pageUsers.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" class="text-center text-muted" style="padding: 40px;">Nenhum usuário encontrado</td></tr>`;
    return;
  }
  
  tbody.innerHTML = pageUsers.map(user => `
    <tr>
      <td>#${user.id}</td>
      <td>${escapeHtml(user.email)}</td>
      <td>${user.role === 'admin' ? '<span class="status-badge" style="background: #f59e0b20; color: #f59e0b;">Admin</span>' : 'User'}</td>
      <td>
        ${user.confirmed_at 
          ? '<span class="status-badge status-active">Confirmado</span>' 
          : '<span class="status-badge status-inactive">Pendente</span>'}
      </td>
      <td>${formatDate(user.created_at)}</td>
      <td>
        <button class="action-btn" onclick="deleteUser('${user.id}')">Remover</button>
      </td>
    </tr>
  `).join('');
  
  // Pagination
  renderPagination(filtered.length);
}

function renderPagination(totalItems) {
  const container = document.getElementById('pagination');
  if (!container) return;
  
  const totalPages = Math.ceil(totalItems / perPage);
  
  if (totalPages <= 1) {
    container.innerHTML = `Total: ${totalItems} usuário(s)`;
    return;
  }
  
  let html = `<span>Página ${currentPage} de ${totalPages}</span>`;
  html += '<div class="flex gap-2">';
  
  if (currentPage > 1) {
    html += `<button class="action-btn" onclick="goToPage(${currentPage - 1})">← Anterior</button>`;
  }
  
  for (let i = 1; i <= totalPages; i++) {
    html += `<button class="action-btn ${i === currentPage ? 'active' : ''}" onclick="goToPage(${i})">${i}</button>`;
  }
  
  if (currentPage < totalPages) {
    html += `<button class="action-btn" onclick="goToPage(${currentPage + 1})">Próxima →</button>`;
  }
  
  html += '</div>';
  container.innerHTML = html;
}

function goToPage(page) {
  currentPage = page;
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) loadUsers(token);
}

// === SEARCH ===
function initSearch() {
  const box = document.getElementById('search-box');
  if (!box) return;
  
  let timeout;
  box.addEventListener('input', (e) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => {
      currentSearch = e.target.value;
      currentPage = 1;
      const token = localStorage.getItem(TOKEN_KEY);
      if (token) {
        // Re-fetch to get fresh data
        fetch(`${API_BASE}/users`, {
          headers: { 'Authorization': `Bearer ${token}` }
        }).then(r => r.json()).then(users => {
          allUsers = users;
          renderUsers();
        });
      }
    }, 300);
  });
}

// === DELETE USER ===
async function deleteUser(userId) {
  if (!confirm('Tem certeza que deseja remover este usuário?')) return;
  
  const token = localStorage.getItem(TOKEN_KEY);
  if (!token) return;
  
  try {
    const res = await fetch(`${API_BASE}/users/${userId}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${token}` }
    });
    
    if (res.ok) {
      alert('Usuário removido com sucesso');
      loadDashboard(token);
    } else {
      const data = await res.json();
      alert(data.error || 'Erro ao remover usuário');
    }
  } catch (err) {
    alert('Erro ao conectar com o servidor');
  }
}

// === UTILS ===
function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function formatDate(dateStr) {
  const date = new Date(dateStr);
  return date.toLocaleDateString('pt-BR') + ' ' + date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}
