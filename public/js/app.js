(() => {
  'use strict';

  const state = {
    token: localStorage.getItem('token') || null,
    user: null,
    modules: [],
    tables: [],
    tablesByKey: {},
    lookupCache: {},   // tableKey -> [{value,label}]
    currentTable: null,
    currentPage: 1,
    searchTerm: '',
  };

  const $ = (sel, root = document) => root.querySelector(sel);
  const $all = (sel, root = document) => Array.from(root.querySelectorAll(sel));

  // -------------------------------------------------------------- API
  async function api(path, opts = {}) {
    const headers = { 'Content-Type': 'application/json', ...(opts.headers || {}) };
    if (state.token) headers.Authorization = `Bearer ${state.token}`;
    const res = await fetch(`/api${path}`, { ...opts, headers, credentials: 'include' });
    let body = null;
    try { body = await res.json(); } catch (e) { /* no body */ }
    if (!res.ok) {
      throw new Error((body && body.error) || `Request failed (${res.status})`);
    }
    return body;
  }

  function toast(msg, type = 'success') {
    const el = $('#toast');
    el.textContent = msg;
    el.className = `toast ${type}`;
    clearTimeout(toast._t);
    toast._t = setTimeout(() => el.classList.add('hidden'), 3200);
  }

  // ---------------------------------------------------------- AUTH UI
  $('#tab-login').addEventListener('click', () => switchTab('login'));
  $('#tab-signup').addEventListener('click', () => switchTab('signup'));

  function switchTab(which) {
    $('#tab-login').classList.toggle('active', which === 'login');
    $('#tab-signup').classList.toggle('active', which === 'signup');
    $('#login-form').classList.toggle('hidden', which !== 'login');
    $('#signup-form').classList.toggle('hidden', which !== 'signup');
  }

  $('#login-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const fd = new FormData(e.target);
    $('#login-error').textContent = '';
    try {
      const data = await api('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ username: fd.get('username'), password: fd.get('password') }),
      });
      onAuthSuccess(data);
    } catch (err) {
      $('#login-error').textContent = err.message;
    }
  });

  $('#signup-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const fd = new FormData(e.target);
    $('#signup-error').textContent = '';
    try {
      const data = await api('/auth/signup', {
        method: 'POST',
        body: JSON.stringify({
          username: fd.get('username'),
          email: fd.get('email'),
          password: fd.get('password'),
          displayName: fd.get('displayName'),
        }),
      });
      onAuthSuccess(data);
      toast('Account created — welcome!');
    } catch (err) {
      $('#signup-error').textContent = err.message;
    }
  });

  $('#logout-btn').addEventListener('click', async () => {
    try { await api('/auth/logout', { method: 'POST' }); } catch (e) { /* ignore */ }
    state.token = null;
    localStorage.removeItem('token');
    location.reload();
  });

  function onAuthSuccess(data) {
    state.token = data.token;
    state.user = data.user;
    localStorage.setItem('token', data.token);
    boot();
  }

  // ---------------------------------------------------------- BOOTSTRAP
  async function boot() {
    if (!state.token) return showAuthScreen();

    try {
      if (!state.user) state.user = await api('/auth/me');
      const meta = await api('/meta');
      state.modules = meta.modules;
      state.tables = meta.tables;
      state.tablesByKey = Object.fromEntries(meta.tables.map((t) => [t.table, t]));
    } catch (err) {
      console.error(err);
      state.token = null;
      localStorage.removeItem('token');
      return showAuthScreen();
    }

    $('#auth-screen').classList.add('hidden');
    $('#app-shell').classList.remove('hidden');

    renderUserChip();
    renderSidebar();
    showDashboard();
  }

  function showAuthScreen() {
    $('#auth-screen').classList.remove('hidden');
    $('#app-shell').classList.add('hidden');
  }

  function renderUserChip() {
    const u = state.user;
    $('#user-chip').innerHTML = `
      <span class="u-name">${escapeHtml(u.displayName || u.username)}</span>
      <span class="u-roles">${(u.roles || []).join(', ') || 'No role assigned'}</span>
    `;
  }

  // ---------------------------------------------------------- SIDEBAR
  function renderSidebar() {
    const nav = $('#sidebar-nav');
    nav.innerHTML = '';

    const dashBtn = document.createElement('button');
    dashBtn.className = 'nav-item';
    dashBtn.textContent = '📊  Dashboard';
    dashBtn.dataset.view = 'dashboard';
    dashBtn.addEventListener('click', () => showDashboard());
    nav.appendChild(dashBtn);

    for (const mod of state.modules) {
      const tablesInModule = state.tables.filter((t) => t.module === mod.key);
      if (tablesInModule.length === 0) continue;

      const wrap = document.createElement('div');
      wrap.className = 'nav-module';
      const title = document.createElement('div');
      title.className = 'nav-module-title';
      title.textContent = mod.label;
      wrap.appendChild(title);

      for (const t of tablesInModule) {
        const btn = document.createElement('button');
        btn.className = 'nav-item';
        btn.dataset.table = t.table;
        btn.textContent = t.label;
        btn.addEventListener('click', () => {
          showFeature(t.table);
          closeSidebarMobile();
        });
        wrap.appendChild(btn);
      }
      nav.appendChild(wrap);
    }
  }

  function setActiveNav(tableKey) {
    $all('.nav-item').forEach((el) => {
      el.classList.toggle('active', (tableKey === 'dashboard' && el.dataset.view === 'dashboard') || el.dataset.table === tableKey);
    });
  }

  $('#hamburger').addEventListener('click', () => $('.sidebar').classList.toggle('open'));
  function closeSidebarMobile() { $('.sidebar').classList.remove('open'); }

  // ---------------------------------------------------------- DASHBOARD
  async function showDashboard() {
    state.currentTable = null;
    setActiveNav('dashboard');
    $('#view-title').textContent = 'Dashboard';
    const content = $('#view-content');
    content.innerHTML = `<div class="empty-state">Loading dashboard…</div>`;

    try {
      const d = await api('/dashboard');
      content.innerHTML = `
        <div class="cards-grid">
          ${statCard(d.activeResidents, 'Active Residents')}
          ${statCard(d.households, 'Households')}
          ${statCard(d.activeAnnouncements, 'Active Announcements')}
          ${statCard('UGX ' + Number(d.totalRevenue).toLocaleString(), 'Total Revenue Collected')}
        </div>
        <div class="breakdown-grid">
          ${breakdownPanel('Court Cases by Status', d.casesByStatus)}
          ${breakdownPanel('Infrastructure Reports by Status', d.reportsByStatus)}
          ${breakdownPanel('Letter Requests by Status', d.lettersByStatus)}
        </div>
      `;
    } catch (err) {
      content.innerHTML = `<div class="empty-state">Could not load dashboard: ${escapeHtml(err.message)}</div>`;
    }
  }

  function statCard(num, label) {
    return `<div class="stat-card"><div class="num">${num}</div><div class="lbl">${label}</div></div>`;
  }

  function breakdownPanel(title, rows) {
    if (!rows || rows.length === 0) {
      return `<div class="panel"><h3>${title}</h3><div class="empty-state">No data yet</div></div>`;
    }
    const max = Math.max(...rows.map((r) => r.count));
    return `
      <div class="panel">
        <h3>${title}</h3>
        ${rows.map((r) => `
          <div class="bar-row">
            <div class="bar-label">${escapeHtml(r.status)}</div>
            <div class="bar-track"><div class="bar-fill" style="width:${max ? (r.count / max) * 100 : 0}%"></div></div>
            <div class="bar-count">${r.count}</div>
          </div>
        `).join('')}
      </div>
    `;
  }

  // ---------------------------------------------------------- FEATURE (LIST)
  async function showFeature(tableKey, page = 1, search = '') {
    const t = state.tablesByKey[tableKey];
    if (!t) return;
    state.currentTable = tableKey;
    state.currentPage = page;
    state.searchTerm = search;
    setActiveNav(tableKey);

    $('#view-title').innerHTML = `${escapeHtml(t.label)} ${t.readOnly ? '<span class="readonly-badge">Read-only log</span>' : ''}`;
    const content = $('#view-content');
    content.innerHTML = `
      <div class="feature-toolbar">
        <div class="search-box">
          <input type="text" id="search-input" placeholder="Search ${escapeHtml(t.label.toLowerCase())}…" value="${escapeHtml(search)}" />
        </div>
        ${t.readOnly ? '' : `<button class="btn btn-gold" id="add-btn">+ Add ${escapeHtml(t.label.replace(/s$/, ''))}</button>`}
      </div>
      <div class="table-wrap"><div class="empty-state">Loading…</div></div>
    `;

    $('#search-input').addEventListener('keydown', (e) => {
      if (e.key === 'Enter') showFeature(tableKey, 1, e.target.value.trim());
    });
    if (!t.readOnly) $('#add-btn').addEventListener('click', () => openModal(tableKey));

    // Preload lookups for FK columns so we can show labels instead of raw IDs
    await Promise.all(t.columns.filter((c) => c.type === 'fk').map((c) => loadLookup(c.ref)));

    try {
      const data = await api(`/${tableKey}?page=${page}&pageSize=20&search=${encodeURIComponent(search)}`);
      renderTable(t, data);
    } catch (err) {
      $('.table-wrap').innerHTML = `<div class="empty-state">Could not load records: ${escapeHtml(err.message)}</div>`;
    }
  }

  async function loadLookup(tableKey) {
    if (state.lookupCache[tableKey]) return state.lookupCache[tableKey];
    try {
      const rows = await api(`/lookup/${tableKey}`);
      const map = Object.fromEntries(rows.map((r) => [String(r.value), r.label]));
      state.lookupCache[tableKey] = map;
      return map;
    } catch (e) {
      state.lookupCache[tableKey] = {};
      return {};
    }
  }

  function renderTable(t, data) {
    const wrap = $('.table-wrap');
    if (!data.rows || data.rows.length === 0) {
      wrap.innerHTML = `<div class="empty-state">No records yet${t.readOnly ? '.' : ' — click “Add” to create the first one.'}</div>`;
      return;
    }

    const pkUpper = t.pk.toUpperCase();
    const cols = t.columns; // ordered, matches API select order (pk first, then columns)

    const thead = `<tr><th>${t.pk}</th>${cols.map((c) => `<th>${escapeHtml(c.label)}</th>`).join('')}${t.readOnly ? '' : '<th></th>'}</tr>`;

    const rowsHtml = data.rows.map((row) => {
      const cells = cols.map((c) => `<td>${formatCell(c, row[c.name.toUpperCase()])}</td>`).join('');
      const actions = t.readOnly ? '' : `
        <td class="row-actions">
          <button class="btn btn-ghost btn-sm" data-edit="${row[pkUpper]}">Edit</button>
          <button class="btn btn-danger btn-sm" data-del="${row[pkUpper]}">Delete</button>
        </td>`;
      return `<tr>${`<td>${row[pkUpper]}</td>`}${cells}${actions}</tr>`;
    }).join('');

    const totalPages = Math.max(1, Math.ceil(data.total / data.pageSize));

    wrap.innerHTML = `
      <table class="data-table">
        <thead>${thead}</thead>
        <tbody>${rowsHtml}</tbody>
      </table>
      <div class="pagination">
        <span>${data.total} record${data.total === 1 ? '' : 's'} — page ${data.page} of ${totalPages}</span>
        <span>
          <button class="btn btn-ghost btn-sm" id="prev-page" ${data.page <= 1 ? 'disabled' : ''}>← Prev</button>
          <button class="btn btn-ghost btn-sm" id="next-page" ${data.page >= totalPages ? 'disabled' : ''}>Next →</button>
        </span>
      </div>
    `;

    $('#prev-page')?.addEventListener('click', () => showFeature(t.table, state.currentPage - 1, state.searchTerm));
    $('#next-page')?.addEventListener('click', () => showFeature(t.table, state.currentPage + 1, state.searchTerm));

    $all('[data-edit]', wrap).forEach((btn) => btn.addEventListener('click', () => openModal(t.table, btn.dataset.edit)));
    $all('[data-del]', wrap).forEach((btn) => btn.addEventListener('click', () => deleteRecord(t, btn.dataset.del)));
  }

  function formatCell(col, value) {
    if (value === null || value === undefined) return '<span style="color:#c1c7cf">—</span>';
    if (col.type === 'fk') {
      const map = state.lookupCache[col.ref] || {};
      return escapeHtml(map[String(value)] || `#${value}`);
    }
    if (col.type === 'date') {
      const d = new Date(value);
      return isNaN(d) ? escapeHtml(String(value)) : d.toLocaleString();
    }
    const s = String(value);
    return escapeHtml(s.length > 80 ? s.slice(0, 80) + '…' : s);
  }

  async function deleteRecord(t, id) {
    if (!confirm(`Delete this ${t.label.replace(/s$/, '')} record? This cannot be undone.`)) return;
    try {
      await api(`/${t.table}/${id}`, { method: 'DELETE' });
      toast('Record deleted.');
      showFeature(t.table, state.currentPage, state.searchTerm);
    } catch (err) {
      toast(err.message, 'error');
    }
  }

  // ---------------------------------------------------------- MODAL (CREATE/EDIT)
  async function openModal(tableKey, id = null) {
    const t = state.tablesByKey[tableKey];
    $('#modal-title').textContent = id ? `Edit ${t.label.replace(/s$/, '')}` : `Add ${t.label.replace(/s$/, '')}`;
    const form = $('#modal-form');
    form.innerHTML = `<div class="empty-state">Loading form…</div>`;
    $('#modal-backdrop').classList.remove('hidden');

    const editableCols = t.columns.filter((c) => !c.readOnly);

    // Preload FK dropdown data
    await Promise.all(editableCols.filter((c) => c.type === 'fk').map((c) => loadLookupOptions(c.ref)));

    let existing = {};
    if (id) {
      try { existing = await api(`/${tableKey}/${id}`); } catch (err) { toast(err.message, 'error'); }
    }

    form.innerHTML = `
      <div id="modal-error" class="modal-error"></div>
      ${editableCols.map((c) => fieldHtml(c, existing[c.name.toUpperCase()])).join('')}
      <div class="modal-actions">
        <button type="button" class="btn btn-ghost" id="modal-cancel">Cancel</button>
        <button type="submit" class="btn btn-primary">${id ? 'Save Changes' : 'Create'}</button>
      </div>
    `;

    $('#modal-cancel').addEventListener('click', closeModal);

    form.onsubmit = async (e) => {
      e.preventDefault();
      const fd = new FormData(form);
      const payload = {};
      for (const c of editableCols) payload[c.name] = fd.get(c.name) ?? '';
      try {
        if (id) {
          await api(`/${tableKey}/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
          toast('Saved changes.');
        } else {
          await api(`/${tableKey}`, { method: 'POST', body: JSON.stringify(payload) });
          toast(`${t.label.replace(/s$/, '')} created.`);
        }
        closeModal();
        showFeature(tableKey, state.currentPage, state.searchTerm);
      } catch (err) {
        $('#modal-error').textContent = err.message;
      }
    };
  }

  let lookupOptionsCache = {};
  async function loadLookupOptions(tableKey) {
    if (lookupOptionsCache[tableKey]) return lookupOptionsCache[tableKey];
    try {
      const rows = await api(`/lookup/${tableKey}`);
      lookupOptionsCache[tableKey] = rows;
      return rows;
    } catch (e) {
      lookupOptionsCache[tableKey] = [];
      return [];
    }
  }

  function fieldHtml(col, value) {
    const val = value === undefined || value === null ? '' : value;
    const req = col.required ? 'required' : '';

    if (col.type === 'select') {
      const opts = (col.options || []).map((o) => `<option value="${o}" ${String(val) === o ? 'selected' : ''}>${o}</option>`).join('');
      return `<label>${escapeHtml(col.label)}<select name="${col.name}" ${req}><option value="">— Select —</option>${opts}</select></label>`;
    }
    if (col.type === 'fk') {
      const opts = (lookupOptionsCache[col.ref] || [])
        .map((o) => `<option value="${o.value}" ${String(val) === String(o.value) ? 'selected' : ''}>${escapeHtml(o.label)}</option>`).join('');
      return `<label>${escapeHtml(col.label)}<select name="${col.name}" ${req}><option value="">— Select ${escapeHtml(col.label)} —</option>${opts}</select></label>`;
    }
    if (col.type === 'textarea') {
      return `<label>${escapeHtml(col.label)}<textarea name="${col.name}" ${req}>${escapeHtml(val)}</textarea></label>`;
    }
    if (col.type === 'date') {
      const dv = val ? String(val).slice(0, 10) : '';
      return `<label>${escapeHtml(col.label)}<input type="date" name="${col.name}" value="${dv}" ${req} /></label>`;
    }
    if (col.type === 'number' || col.type === 'decimal') {
      return `<label>${escapeHtml(col.label)}<input type="number" step="${col.type === 'decimal' ? '0.01' : '1'}" name="${col.name}" value="${escapeHtml(String(val))}" ${req} /></label>`;
    }
    return `<label>${escapeHtml(col.label)}<input type="text" name="${col.name}" value="${escapeHtml(String(val))}" ${req} /></label>`;
  }

  function closeModal() {
    $('#modal-backdrop').classList.add('hidden');
    $('#modal-form').innerHTML = '';
  }
  $('#modal-close').addEventListener('click', closeModal);
  $('#modal-backdrop').addEventListener('click', (e) => { if (e.target.id === 'modal-backdrop') closeModal(); });

  function escapeHtml(str) {
    return String(str).replace(/[&<>"']/g, (m) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m]));
  }

  // GO!
  boot();
})();
