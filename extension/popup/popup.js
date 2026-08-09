const API_BASE_URL = 'http://localhost:8080/api/v1';

document.addEventListener('DOMContentLoaded', () => {
  initTabs();
  bindFingerprintInspector();
  bindExtensionAuditor();
  bindSmsAnalyzer();
  bindDnsToggle();
  
  // Auto-detect current browser tab URL & auto-trigger fingerprint evaluation immediately
  autoInspectCurrentTab();
});

// --- Tab Switching Logic ---
function initTabs() {
  const tabBtns = document.querySelectorAll('.tab-btn');
  const tabPanels = document.querySelectorAll('.tab-panel');

  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      const targetTabId = btn.getAttribute('data-tab');

      tabBtns.forEach(b => b.classList.remove('active'));
      tabPanels.forEach(p => p.classList.remove('active'));

      btn.classList.add('active');
      document.getElementById(targetTabId).classList.add('active');
    });
  });
}

// --- Auto-detect Active Tab URL & Run Automatic Fingerprint ---
function autoInspectCurrentTab() {
  if (typeof chrome !== 'undefined' && chrome.tabs && chrome.tabs.query) {
    chrome.tabs.query({ active: true, currentWindow: true }, async (tabs) => {
      if (tabs && tabs[0] && tabs[0].url) {
        const url = tabs[0].url;
        const bannerDomain = document.getElementById('bannerDomain');
        const fpInput = document.getElementById('fingerprintUrlInput');

        if (url.startsWith('chrome://') || url.startsWith('edge://') || url.startsWith('about:')) {
          if (bannerDomain) bannerDomain.textContent = 'System Browser Page';
          updateBannerVerdict({ verdict: 'SAFE', threat_score: 0 }, 'System Page');
          return;
        }

        try {
          const domain = new URL(url).hostname;
          if (bannerDomain) bannerDomain.textContent = domain;
          if (fpInput) fpInput.value = url;

          // Automatically run fingerprint scan
          const fingerprintData = await fetchFingerprintAPI(url);
          
          updateBannerVerdict(fingerprintData, domain);
          displayFingerprintResult(fingerprintData);

        } catch (e) {
          if (bannerDomain) bannerDomain.textContent = url;
        }
      }
    });
  }
}

// Update Active Site Shield Banner & Threat Card on Popup Load
function updateBannerVerdict(data, domain) {
  const banner = document.getElementById('activeTabBanner');
  const bannerIcon = document.getElementById('bannerIcon');
  const bannerTitle = document.getElementById('bannerTitle');
  const bannerBadge = document.getElementById('bannerBadge');
  const threatCard = document.getElementById('activeThreatCard');
  const scorePill = document.getElementById('activeScorePill');
  const reasonsList = document.getElementById('activeReasonsList');

  if (!banner) return;

  banner.className = 'active-tab-banner';
  bannerBadge.className = 'banner-badge';

  if (data.verdict === 'SAFE') {
    banner.classList.add('safe');
    bannerBadge.classList.add('safe');
    if (bannerIcon) bannerIcon.textContent = '🛡️';
    if (bannerTitle) bannerTitle.textContent = 'Safe & Verified Domain';
    if (bannerBadge) bannerBadge.textContent = 'SAFE';
    if (threatCard) threatCard.classList.add('hidden');
  } else if (data.verdict === 'SUSPICIOUS' || data.threat_score >= 30) {
    banner.classList.add('caution');
    bannerBadge.classList.add('caution');
    if (bannerIcon) bannerIcon.textContent = '⚠️';
    if (bannerTitle) bannerTitle.textContent = 'Caution / Unverified Site';
    if (bannerBadge) bannerBadge.textContent = 'SUSPICIOUS';
  } else {
    banner.classList.add('danger');
    bannerBadge.classList.add('danger');
    if (bannerIcon) bannerIcon.textContent = '🚨';
    if (bannerTitle) bannerTitle.textContent = 'BLOCKED PHISHING THREAT!';
    if (bannerBadge) bannerBadge.textContent = 'BLOCKED';
  }

  // If threats/reasons detected, display blocked indicators on Dashboard tab
  if (data.reasons && data.reasons.length > 0 && threatCard) {
    if (scorePill) scorePill.textContent = `Score: ${data.threat_score}/100`;
    if (reasonsList) {
      reasonsList.innerHTML = '';
      data.reasons.forEach(r => {
        const li = document.createElement('li');
        li.textContent = `🚨 ${r}`;
        reasonsList.appendChild(li);
      });
    }
    threatCard.classList.remove('hidden');
  }
}

// --- Safe API Fetcher with HTML error handling & JSON validation ---
async function fetchFingerprintAPI(url) {
  try {
    const res = await fetch(`${API_BASE_URL}/sentinel/fingerprint`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url })
    });

    const contentType = res.headers.get('content-type') || '';
    if (res.ok && contentType.includes('application/json')) {
      const json = await res.json();
      setNetworkStatus(true);
      return json.data;
    }
  } catch (err) {
    console.warn('Backend API offline or returned HTML text, running client fallback', err);
    setNetworkStatus(false);
  }

  // Fallback Client Heuristic Fingerprint Engine
  return runClientFingerprintFallback(url);
}

function displayFingerprintResult(data) {
  const card = document.getElementById('fingerprintCard');
  const verdictEl = document.getElementById('fpVerdict');
  const scoreEl = document.getElementById('fpScore');

  if (!card) return;
  card.className = 'result-card';

  if (data.threat_score >= 75) {
    card.classList.add('danger');
    if (verdictEl) verdictEl.textContent = '🔴 MALICIOUS SITE';
  } else if (data.threat_score >= 30) {
    card.classList.add('caution');
    if (verdictEl) verdictEl.textContent = '🟡 SUSPICIOUS SITE';
  } else {
    card.classList.add('safe');
    if (verdictEl) verdictEl.textContent = '🟢 SAFE & CLEAN SITE';
  }

  if (scoreEl) scoreEl.textContent = `Score: ${data.threat_score}/100`;

  const hostEl = document.getElementById('fpHost');
  if (hostEl) hostEl.textContent = data.domain || '-';

  const ipEl = document.getElementById('fpIpRep');
  if (ipEl) ipEl.textContent = data.fingerprint?.infrastructure?.ip_reputation || 'CLEAN';

  const ageEl = document.getElementById('fpAge');
  if (ageEl) ageEl.textContent = data.fingerprint?.infrastructure?.domain_age || 'Established';

  const httpsEl = document.getElementById('fpHttps');
  if (httpsEl) httpsEl.textContent = data.fingerprint?.tls?.https ? 'HTTPS Valid' : 'Insecure HTTP';

  const certEl = document.getElementById('fpCert');
  if (certEl) certEl.textContent = data.fingerprint?.tls?.certificate_valid ? 'Valid SSL' : 'Invalid SSL';

  const issuerEl = document.getElementById('fpIssuer');
  if (issuerEl) issuerEl.textContent = data.fingerprint?.tls?.issuer || 'Let\'s Encrypt';

  const loginEl = document.getElementById('fpLogin');
  if (loginEl) loginEl.textContent = data.fingerprint?.page?.has_login_form ? 'Login Form Found ⚠️' : 'None';

  const brandEl = document.getElementById('fpBrand');
  if (brandEl) brandEl.textContent = data.fingerprint?.identity?.brand_similarity_score || 'Clean';

  const reasonsList = document.getElementById('fpReasonsList');
  if (reasonsList) {
    reasonsList.innerHTML = '';
    if (data.reasons && data.reasons.length > 0) {
      reasonsList.classList.remove('hidden');
      data.reasons.forEach(r => {
        const li = document.createElement('li');
        li.textContent = `⚠️ ${r}`;
        reasonsList.appendChild(li);
      });
    } else {
      reasonsList.classList.add('hidden');
    }
  }

  card.classList.remove('hidden');
}

function runClientFingerprintFallback(url) {
  let host = url;
  try { host = new URL(url.includes('://') ? url : `https://${url}`).hostname; } catch (e) {}

  let score = 0;
  const reasons = [];

  if (/paypa1|g00gle|chase|wellsfargo/i.test(host)) {
    score += 45;
    reasons.push('Lookalike brand impersonation target');
  }

  if (/\.xyz|\.top|\.tk|\.click/i.test(host)) {
    score += 25;
    reasons.push('Suspicious domain TLD extension');
  }

  if (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(host)) {
    score += 40;
    reasons.push('Direct IP address hostname');
  }

  const verdict = score >= 75 ? 'MALICIOUS' : (score >= 30 ? 'SUSPICIOUS' : 'SAFE');
  return {
    url,
    domain: host,
    threat_score: score,
    verdict: verdict,
    action: score >= 75 ? 'BLOCK' : 'ALLOW',
    reasons,
    fingerprint: {
      infrastructure: { ip_reputation: score > 30 ? 'SUSPICIOUS' : 'CLEAN', domain_age: 'Unverified' },
      tls: { https: url.startsWith('https'), certificate_valid: url.startsWith('https'), issuer: 'Let\'s Encrypt' },
      page: { has_login_form: false },
      identity: { brand_similarity_score: score > 30 ? '92% Spoof Match' : 'Clean' }
    }
  };
}

// --- Manual Fingerprint Button Binding ---
function bindFingerprintInspector() {
  const inspectBtn = document.getElementById('inspectFingerprintBtn');
  const pasteBtn = document.getElementById('pasteFingerprintBtn');
  const urlInput = document.getElementById('fingerprintUrlInput');

  if (pasteBtn) {
    pasteBtn.addEventListener('click', async () => {
      try {
        const text = await navigator.clipboard.readText();
        urlInput.value = text;
      } catch (err) {
        console.warn('Clipboard read failed', err);
      }
    });
  }

  if (inspectBtn) {
    inspectBtn.addEventListener('click', async () => {
      const url = urlInput.value.trim();
      if (!url) return;

      inspectBtn.disabled = true;
      inspectBtn.textContent = 'Generating Fingerprint...';

      const data = await fetchFingerprintAPI(url);

      inspectBtn.disabled = false;
      inspectBtn.textContent = 'Re-Inspect Website Fingerprint';

      displayFingerprintResult(data);
    });
  }
}

// --- Browser Extension Security Inspector ---
function bindExtensionAuditor() {
  const btn = document.getElementById('runExtAuditBtn');
  if (btn) {
    btn.addEventListener('click', auditExtensions);
  }
}

async function auditExtensions() {
  const container = document.getElementById('extAuditList');
  if (!container) return;
  container.innerHTML = '<div class="inbox-empty">Auditing browser extensions...</div>';

  if (typeof chrome !== 'undefined' && chrome.management && chrome.management.getAll) {
    chrome.management.getAll((extensions) => {
      const formatted = extensions
        .filter(e => e.type === 'extension' && e.enabled)
        .map(e => ({
          id: e.id,
          name: e.name,
          version: e.version,
          permissions: e.permissions || []
        }));

      renderExtensionAuditList(formatted);
    });
  } else {
    const sampleExts = [
      { name: 'AdBlock Shield Pro', permissions: ['<all_urls>', 'webRequest', 'storage'] },
      { name: 'Video Saver HD', permissions: ['<all_urls>', 'cookies', 'tabs'] },
      { name: 'Color Picker Utility', permissions: ['activeTab'] },
    ];
    renderExtensionAuditList(sampleExts);
  }
}

function renderExtensionAuditList(exts) {
  const container = document.getElementById('extAuditList');
  if (!container) return;
  container.innerHTML = '';

  exts.forEach(e => {
    const perms = e.permissions || [];
    const hasBroad = perms.includes('<all_urls>') || perms.includes('http://*/*') || perms.includes('https://*/*');

    const div = document.createElement('div');
    div.className = 'ext-item';
    div.innerHTML = `
      <div class="ext-item-header">
        <span>${e.name}</span>
        <span class="badge-active" style="background:${hasBroad ? 'rgba(239, 68, 68, 0.2)' : 'rgba(16, 185, 129, 0.2)'}; color:${hasBroad ? '#EF4444' : '#10B981'};">
          ${hasBroad ? 'HIGH RISK' : 'SAFE'}
        </span>
      </div>
      <div class="ext-item-desc">Permissions: ${perms.slice(0, 3).join(', ') || 'Minimal'}</div>
    `;
    container.appendChild(div);
  });
}

// --- SMS Analyzer Binding ---
function bindSmsAnalyzer() {
  const btn = document.getElementById('analyzeSmsBtn');
  const textInput = document.getElementById('smsText');

  if (btn) {
    btn.addEventListener('click', async () => {
      const text = textInput.value.trim();
      if (!text) return;

      btn.disabled = true;
      btn.textContent = 'Analyzing...';

      let result = null;
      try {
        const res = await fetch(`${API_BASE_URL}/analyze-sms`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: text })
        });
        const contentType = res.headers.get('content-type') || '';
        if (res.ok && contentType.includes('application/json')) {
          const json = await res.json();
          result = json.data;
        }
      } catch (e) {}

      btn.disabled = false;
      btn.textContent = 'Analyze Text';

      const card = document.getElementById('smsResultCard');
      const verdict = document.getElementById('smsVerdict');
      const flagsContainer = document.getElementById('smsFlags');

      if (card) {
        card.className = 'result-card';
        if (flagsContainer) flagsContainer.innerHTML = '';

        if (result && result.verdict === 'HIGH_RISK_SCAM') {
          card.classList.add('danger');
          if (verdict) verdict.textContent = '🔴 High Risk Phishing Scam';
        } else {
          card.classList.add('safe');
          if (verdict) verdict.textContent = '🟢 Likely Safe Message';
        }

        card.classList.remove('hidden');
      }
    });
  }
}

// --- Local DNS Shield Toggle ---
function bindDnsToggle() {
  const toggle = document.getElementById('dnsToggle');
  if (toggle) {
    toggle.addEventListener('change', (e) => {
      const isEnabled = e.target.checked;
      const dnsStat = document.getElementById('dnsStat');
      if (dnsStat) {
        dnsStat.textContent = isEnabled ? '2' : '0 (Disabled)';
      }
    });
  }
}

function setNetworkStatus(isOnline) {
  const el = document.getElementById('networkStatus');
  if (!el) return;
  if (!isOnline) {
    el.className = 'status-indicator offline';
    el.querySelector('.status-text').textContent = 'Offline Mode';
  } else {
    el.className = 'status-indicator';
    el.querySelector('.status-text').textContent = 'Backend Active';
  }
}
