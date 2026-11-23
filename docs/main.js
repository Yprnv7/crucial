// Crucial Interactive Web Client - Inspired by shojimac.com & fileosmac.com

document.addEventListener('DOMContentLoaded', () => {
  initWindowTabs();
  initUninstaller();
  initAIAssistant();
  initFAQ();
});

// -------------------------------------------------------------------
// 1. Interactive Mac Window Tab Switcher
// -------------------------------------------------------------------
function initWindowTabs() {
  const tabs = document.querySelectorAll('.win-tab-btn');
  const views = {
    uninstaller: document.getElementById('view-uninstaller'),
    assistant: document.getElementById('view-assistant'),
    treemap: document.getElementById('view-treemap'),
    duplicates: document.getElementById('view-duplicates'),
    maintenance: document.getElementById('view-maintenance')
  };

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const target = tab.dataset.tab;
      tabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');

      Object.entries(views).forEach(([key, el]) => {
        if (!el) return;
        if (key === target) {
          el.style.display = key === 'uninstaller' ? 'grid' : 'block';
        } else {
          el.style.display = 'none';
        }
      });
    });
  });
}

// -------------------------------------------------------------------
// 2. Interactive App Uninstaller Simulation
// -------------------------------------------------------------------
const APPS_DATA = {
  claude: {
    name: 'Claude',
    version: 'v4.4212.0',
    bundleID: 'com.anthropic.claudefordesktop',
    path: '/Applications/Claude.app',
    totalBytes: '1.84 GB',
    bundleSize: '647.2 MB',
    residue: [
      { name: 'Application Support/Claude', size: '1.19 GB', cat: 'Support', bytes: 1277952000, checked: true },
      { name: 'Caches/claude-cli-nodejs', size: '325 KB', cat: 'Caches', bytes: 332800, checked: true },
      { name: 'Caches/com.anthropic.claudefordesktop', size: '1.1 MB', cat: 'Caches', bytes: 1153433, checked: true },
      { name: 'Preferences/com.anthropic.claudefordesktop.plist', size: '1 KB', cat: 'Preferences', bytes: 1024, checked: true },
      { name: 'HTTPStorages/com.anthropic.claudefordesktop', size: '296 KB', cat: 'Storage', bytes: 303104, checked: true }
    ]
  },
  chatgpt: {
    name: 'ChatGPT',
    version: 'v26.715.72359',
    bundleID: 'com.openai.codex',
    path: '/Applications/ChatGPT.app',
    totalBytes: '1.47 GB',
    bundleSize: '1.46 GB',
    residue: [
      { name: 'Application Support/com.openai.codex', size: '86 bytes', cat: 'Support', bytes: 86, checked: true },
      { name: 'Caches/com.openai.codex', size: '4.8 MB', cat: 'Caches', bytes: 5033164, checked: true },
      { name: 'Group Containers/2DC432GLL2.notifications', size: '165 KB', cat: 'Containers', bytes: 168960, checked: true },
      { name: 'HTTPStorages/com.openai.codex', size: '2.8 MB', cat: 'Storage', bytes: 2936012, checked: true }
    ]
  },
  pgadmin: {
    name: 'pgAdmin 4',
    version: 'v9.15',
    bundleID: 'org.pgadmin.pgadmin4',
    path: '/Applications/pgAdmin 4.app',
    totalBytes: '901.9 MB',
    bundleSize: '738.2 MB',
    residue: [
      { name: 'Application Support/pgAdmin 4', size: '163.7 MB', cat: 'Support', bytes: 171651891, checked: true },
      { name: 'Preferences/org.pgadmin.pgadmin4.plist', size: '1 KB', cat: 'Preferences', bytes: 1024, checked: true }
    ]
  },
  dia: {
    name: 'Dia',
    version: 'v1.58.1',
    bundleID: 'company.thebrowser.dia',
    path: '/Applications/Dia.app',
    totalBytes: '7.35 GB',
    bundleSize: '620.4 MB',
    residue: [
      { name: 'Application Support/Dia/Default', size: '6.41 GB', cat: 'Support', bytes: 6882672640, checked: true },
      { name: 'Caches/company.thebrowser.dia', size: '320.1 MB', cat: 'Caches', bytes: 335649177, checked: true },
      { name: 'HTTPStorages/company.thebrowser.dia', size: '1.2 MB', cat: 'Storage', bytes: 1258291, checked: true }
    ]
  }
};

let currentAppKey = 'claude';

function initUninstaller() {
  const listItems = document.querySelectorAll('.app-list-item');
  const triggerBtn = document.getElementById('btn-trash-trigger');
  const modal = document.getElementById('modal-uninstaller');
  const modalCancel = document.getElementById('btn-modal-cancel');
  const modalConfirm = document.getElementById('btn-modal-confirm');

  listItems.forEach(item => {
    item.addEventListener('click', () => {
      const appKey = item.dataset.app;
      if (!APPS_DATA[appKey]) return;
      listItems.forEach(i => i.classList.remove('selected'));
      item.classList.add('selected');
      currentAppKey = appKey;
      renderAppDetails(appKey);
    });
  });

  if (triggerBtn && modal) {
    triggerBtn.addEventListener('click', () => {
      populateModal(currentAppKey);
      modal.classList.add('active');
    });
  }

  if (modalCancel && modal) {
    modalCancel.addEventListener('click', () => {
      modal.classList.remove('active');
    });
  }

  if (modalConfirm && modal) {
    modalConfirm.addEventListener('click', () => {
      modalConfirm.textContent = 'Moving to Trash...';
      modalConfirm.disabled = true;
      setTimeout(() => {
        modal.classList.remove('active');
        modalConfirm.textContent = 'Move to Trash';
        modalConfirm.disabled = false;
        showToast(`✓ Safely staged ${APPS_DATA[currentAppKey].name} and residue to macOS Trash!`);
      }, 700);
    });
  }

  renderAppDetails('claude');
}

function renderAppDetails(key) {
  const data = APPS_DATA[key];
  if (!data) return;

  const titleEl = document.getElementById('cur-app-title');
  const verEl = document.getElementById('cur-app-ver');
  const bundleEl = document.getElementById('cur-app-bundle');
  const numEl = document.getElementById('cur-app-reclaim');
  const tableEl = document.getElementById('cur-residue-table');
  const triggerBtn = document.getElementById('btn-trash-trigger');

  if (titleEl) titleEl.textContent = data.name;
  if (verEl) verEl.textContent = `${data.version} • User App`;
  if (bundleEl) bundleEl.textContent = `${data.bundleID} • ${data.path}`;
  if (numEl) numEl.textContent = data.totalBytes;
  if (triggerBtn) triggerBtn.textContent = `Move to Trash (${data.totalBytes})`;

  if (tableEl) {
    tableEl.innerHTML = '';
    // 1. Bundle Row
    const bRow = document.createElement('div');
    bRow.className = 'residue-row';
    bRow.innerHTML = `
      <div class="res-check-label">
        <div class="custom-checkbox">✓</div>
        <span class="res-name">${data.name}.app (Executable Bundle)</span>
        <span class="res-cat" style="background: rgba(13, 166, 135, 0.15); color: var(--accent-light);">Bundle</span>
      </div>
      <span class="res-size">${data.bundleSize}</span>
    `;
    tableEl.appendChild(bRow);

    // 2. Residue rows
    data.residue.forEach((res, idx) => {
      const row = document.createElement('div');
      row.className = 'residue-row';
      row.innerHTML = `
        <div class="res-check-label" data-idx="${idx}">
          <div class="custom-checkbox">${res.checked ? '✓' : ''}</div>
          <span class="res-name">~/Library/${res.name}</span>
          <span class="res-cat">${res.cat}</span>
        </div>
        <span class="res-size">${res.size}</span>
      `;
      row.querySelector('.res-check-label').addEventListener('click', () => {
        res.checked = !res.checked;
        renderAppDetails(key);
      });
      tableEl.appendChild(row);
    });
  }
}

function populateModal(key) {
  const data = APPS_DATA[key];
  if (!data) return;

  const mTitle = document.getElementById('modal-app-name');
  const mList = document.getElementById('modal-summary-list');
  if (mTitle) mTitle.textContent = `Uninstall ${data.name}?`;
  if (mList) {
    const checkedRes = data.residue.filter(r => r.checked);
    mList.innerHTML = `
      <div>• <strong>${data.name}.app</strong> executable bundle (${data.bundleSize})</div>
      <div>• <strong>${checkedRes.length} support folders & caches</strong> in ~/Library</div>
      <div style="margin-top: 4px; color: var(--accent-light);">Total reclaimable: <strong>${data.totalBytes}</strong></div>
    `;
  }
}

function showToast(msg) {
  let toast = document.getElementById('app-toast');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'app-toast';
    toast.style.cssText = `
      position: fixed; bottom: 30px; right: 30px; z-index: 999;
      background: #171626; border: 1px solid var(--accent);
      color: #FFFFFF; padding: 14px 22px; border-radius: 10px;
      font-size: 14px; font-weight: 500; box-shadow: 0 10px 30px rgba(0,0,0,0.5);
      transition: all 0.3s var(--ease); transform: translateY(20px); opacity: 0;
    `;
    document.body.appendChild(toast);
  }
  toast.textContent = msg;
  toast.style.transform = 'translateY(0)';
  toast.style.opacity = '1';
  setTimeout(() => {
    toast.style.transform = 'translateY(20px)';
    toast.style.opacity = '0';
  }, 3500);
}

// -------------------------------------------------------------------
// 3. Local AI Explainer (Crucial Assistant Simulation)
// -------------------------------------------------------------------
const AI_EXPLANATIONS = {
  nodemodules: {
    question: "What is node_modules, and what happens if I delete it?",
    answer: "• Identification: node_modules is a project directory containing third-party JavaScript dependencies.\n• Origin: Generated automatically by npm, yarn, or pnpm.\n• Safety: 100% Safe to delete. No personal or custom source code lives here.\n• Rebuild: Run 'npm install' inside the repository anytime to regenerate.\n\nRisk Score: 0/100 (Safe)  •  Engine: Onboard Llama 3.2 1B (Metal)  •  Latency: 0ms"
  },
  deriveddata: {
    question: "What is Xcode DerivedData, and is it safe to trash?",
    answer: "• Identification: ~/Library/Developer/Xcode/DerivedData holds intermediate compilation artifacts, symbol indexes, and module caches.\n• Origin: Xcode builds.\n• Safety: Safe to clear. Xcode will automatically rebuild indexes on your next compile.\n• Recommended: Purge when indexing stalls or builds behave inconsistently.\n\nRisk Score: 5/100 (Safe)  •  Throughput: 47.5 t/s  •  Memory: 0 MB daemon"
  },
  caches: {
    question: "Is ~/Library/Caches safe to wipe entirely?",
    answer: "• Identification: System-wide user application cache directory.\n• Safety: Safe. All reputable macOS applications regenerate cache assets on demand.\n• Crucial Protocol: Staged directly to macOS Trash rather than rm -rf, so any active session cache can be restored if needed.\n\nRisk Score: 0/100 (Safe)  •  Verification: Cryptographic SHA-256"
  },
  spotify: {
    question: "Why does Spotify have 1.19 GB in Application Support?",
    answer: "• Identification: Spotify stores offline cached track chunks, artist artwork thumbnails, and local telemetry.\n• Impact of Deletion: Will clear offline cache and logged-out session tokens without affecting your saved playlists (playlists are stored in Spotify cloud).\n\nRisk Score: 0/100 (Safe to clean)"
  }
};

function initAIAssistant() {
  const chips = document.querySelectorAll('.ai-chip');
  const outBox = document.getElementById('ai-text-content');
  if (!chips.length || !outBox) return;

  chips.forEach(chip => {
    chip.addEventListener('click', () => {
      const topic = chip.dataset.topic;
      const data = AI_EXPLANATIONS[topic];
      if (!data) return;

      chips.forEach(c => c.style.borderColor = 'var(--line)');
      chip.style.borderColor = 'var(--accent)';

      typewriterEffect(outBox, data.answer);
    });
  });
}

function typewriterEffect(element, fullText) {
  element.textContent = '';
  let i = 0;
  const speed = 12; // ms per char (simulating ~50 t/s)

  function step() {
    if (i < fullText.length) {
      element.textContent += fullText.charAt(i);
      i++;
      setTimeout(step, speed);
    }
  }
  step();
}

// -------------------------------------------------------------------
// 4. Interactive FAQ Accordion
// -------------------------------------------------------------------
function initFAQ() {
  const items = document.querySelectorAll('.faq-item');
  items.forEach(item => {
    const btn = item.querySelector('.faq-question');
    if (!btn) return;
    btn.addEventListener('click', () => {
      const isOpen = item.classList.contains('open');
      items.forEach(i => i.classList.remove('open'));
      if (!isOpen) {
        item.classList.add('open');
      }
    });
  });
}
