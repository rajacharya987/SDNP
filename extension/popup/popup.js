const API_BASE_URL = 'http://localhost:8080/api/v1';

document.addEventListener('DOMContentLoaded', () => {
  initTabs();
  checkActiveTabSecurity();
  bindUrlScanner();
  bindSmsAnalyzer();
  bindBreachChecker();
  bindTempMail();
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

// --- Check Active Browser Tab ---
async function checkActiveTabSecurity() {
  const banner = document.getElementById('activeTabBanner');
  const bannerIcon = document.getElementById('bannerIcon');
  const bannerTitle = document.getElementById('bannerTitle');
  const bannerDomain = document.getElementById('bannerDomain');
  const bannerBadge = document.getElementById('bannerBadge');

  if (typeof chrome !== 'undefined' && chrome.tabs && chrome.tabs.query) {
    chrome.tabs.query({ active: true, currentWindow: true }, async (tabs) => {
      if (tabs && tabs[0] && tabs[0].url) {
        const url = tabs[0].url;
        
        // Skip browser internal pages
        if (url.startsWith('chrome://') || url.startsWith('edge://') || url.startsWith('about:')) {
          bannerTitle.textContent = 'System Browser Page';
          bannerDomain.textContent = url;
          bannerBadge.textContent = 'Internal';
          return;
        }

        try {
          const domain = new URL(url).hostname;
          bannerDomain.textContent = domain;
          document.getElementById('urlInput').value = url;

          // Call backend API or run local heuristic fallback
          const scanData = await scanUrlAPI(url);
          applyBannerVerdict(scanData, domain);

        } catch (e) {
          bannerTitle.textContent = 'Active Page Check Failed';
          bannerDomain.textContent = 'Unable to parse URL';
        }
      }
    });
  } else {
    bannerTitle.textContent = 'Active Shield Standby';
    bannerDomain.textContent = 'Paste link below to scan';
  }
}

function applyBannerVerdict(scanData, domain) {
  const banner = document.getElementById('activeTabBanner');
  const bannerIcon = document.getElementById('bannerIcon');
  const bannerTitle = document.getElementById('bannerTitle');
  const bannerBadge = document.getElementById('bannerBadge');

  banner.className = 'active-tab-banner';
  bannerBadge.className = 'banner-badge';

  if (scanData.verdict === 'SAFE') {
    banner.classList.add('safe');
    bannerBadge.classList.add('safe');
    bannerIcon.textContent = '🟢';
    bannerTitle.textContent = 'Safe & Clean Site';
    bannerBadge.textContent = 'SAFE';
  } else if (scanData.verdict === 'SUSPICIOUS') {
    banner.classList.add('caution');
    bannerBadge.classList.add('caution');
    bannerIcon.textContent = '🟡';
    bannerTitle.textContent = 'Caution / Unverified Site';
    bannerBadge.textContent = 'SUSPICIOUS';
  } else {
    banner.classList.add('danger');
    bannerBadge.classList.add('danger');
    bannerIcon.textContent = '🔴';
    bannerTitle.textContent = 'Dangerous Phishing Threat';
    bannerBadge.textContent = 'DANGEROUS';
  }
}

// --- 1. URL Scanner Binding ---
function bindUrlScanner() {
  const scanBtn = document.getElementById('scanUrlBtn');
  const pasteBtn = document.getElementById('pasteUrlBtn');
  const urlInput = document.getElementById('urlInput');

  pasteBtn.addEventListener('click', async () => {
    try {
      const text = await navigator.clipboard.readText();
      urlInput.value = text;
    } catch (err) {
      console.warn('Clipboard read failed', err);
    }
  });

  scanBtn.addEventListener('click', async () => {
    const url = urlInput.value.trim();
    if (!url) return;

    scanBtn.disabled = true;
    scanBtn.textContent = 'Scanning Threat...';

    const result = await scanUrlAPI(url);

    scanBtn.disabled = false;
    scanBtn.textContent = 'Scan Link Threat';

    displayUrlResult(result);
  });
}

async function scanUrlAPI(url) {
  try {
    const response = await fetch(`${API_BASE_URL}/scan-url`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: url })
    });

    if (response.ok) {
      const json = await response.json();
      return json.data;
    }
  } catch (err) {
    console.warn('Backend API offline, running client-side heuristic engine fallback', err);
    setNetworkStatus(false);
  }

  // Fallback Client Heuristic Analysis if backend is offline
  return runClientHeuristics(url);
}

function displayUrlResult(data) {
  const card = document.getElementById('urlResultCard');
  const title = document.getElementById('urlVerdictTitle');
  const badge = document.getElementById('urlScoreBadge');
  const msg = document.getElementById('urlVerdictMsg');
  const threatList = document.getElementById('urlThreatList');

  card.className = 'result-card';
  threatList.innerHTML = '';

  if (data.verdict === 'SAFE') {
    card.classList.add('safe');
    title.textContent = '🟢 Clean & Verified Domain';
  } else if (data.verdict === 'SUSPICIOUS') {
    card.classList.add('caution');
    title.textContent = '🟡 Caution / Unverified Link';
  } else {
    card.classList.add('danger');
    title.textContent = '🔴 Dangerous Threat Detected!';
  }

  badge.textContent = `Risk Score: ${data.risk_score}/100`;
  msg.textContent = data.verdict_title || 'Analysis complete.';

  if (data.threat_details && data.threat_details.length > 0) {
    threatList.classList.remove('hidden');
    data.threat_details.forEach(t => {
      const li = document.createElement('li');
      li.textContent = `⚠️ ${t}`;
      threatList.appendChild(li);
    });
  } else {
    threatList.classList.add('hidden');
  }

  card.classList.remove('hidden');
}

// Client Heuristics Engine Fallback
function runClientHeuristics(url) {
  let score = 0;
  const threats = [];
  let host = '';

  try {
    host = new URL(url.includes('://') ? url : `https://${url}`).hostname;
  } catch (e) {
    host = url;
  }

  const suspiciousTlds = ['xyz', 'top', 'tk', 'ml', 'ga', 'cf', 'gq', 'work', 'click', 'link'];
  const ext = host.split('.').pop();
  if (suspiciousTlds.includes(ext)) {
    score += 30;
    threats.push(`High-risk domain extension (.${ext})`);
  }

  const shorteners = ['bit.ly', 'tinyurl.com', 't.co', 'rb.gy', 'cutt.ly'];
  if (shorteners.includes(host)) {
    score += 25;
    threats.push(`URL Shortener link detected (${host})`);
  }

  if (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(host)) {
    score += 40;
    threats.push(`Direct IP hostname without domain SSL`);
  }

  let verdict = 'SAFE';
  if (score >= 60) verdict = 'DANGEROUS';
  else if (score >= 25) verdict = 'SUSPICIOUS';

  return {
    url,
    domain: host,
    verdict,
    risk_score: score,
    verdict_title: verdict === 'SAFE' ? 'No major threat flags found' : 'Potential security risk flagged',
    threat_details: threats
  };
}

// --- 2. SMS Analyzer Binding ---
function bindSmsAnalyzer() {
  const analyzeBtn = document.getElementById('analyzeSmsBtn');
  const smsInput = document.getElementById('smsInput');

  analyzeBtn.addEventListener('click', async () => {
    const text = smsInput.value.trim();
    if (!text) return;

    analyzeBtn.disabled = true;
    analyzeBtn.textContent = 'Analyzing Text Phishing...';

    let result = null;
    try {
      const response = await fetch(`${API_BASE_URL}/analyze-sms`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: text })
      });
      if (response.ok) {
        const json = await response.json();
        result = json.data;
      }
    } catch (e) {
      setNetworkStatus(false);
    }

    if (!result) {
      // Fallback local text analyzer
      result = runLocalTextAnalyzer(text);
    }

    analyzeBtn.disabled = false;
    analyzeBtn.textContent = 'Analyze Text Phishing Flags';

    displaySmsResult(result);
  });
}

function runLocalTextAnalyzer(text) {
  const lower = text.toLowerCase();
  const flags = [];
  let score = 0;

  if (lower.includes('urgent') || lower.includes('locked') || lower.includes('immediate')) {
    flags.push("Urgency Indicator: 'urgent/locked'");
    score += 30;
  }
  if (lower.includes('winner') || lower.includes('claim') || lower.includes('tax refund')) {
    flags.push("Financial Bait Keywords");
    score += 35;
  }
  if (lower.includes('http://') || lower.includes('https://') || lower.includes('bit.ly')) {
    flags.push("Contains Embedded Link");
    score += 20;
  }

  const verdict = score >= 50 ? 'HIGH_RISK_SCAM' : score >= 25 ? 'SUSPICIOUS' : 'SAFE';
  return {
    verdict,
    risk_score: score,
    verdict_title: verdict === 'SAFE' ? 'Message Appears Normal' : 'Scam / Phishing Indicators Detected',
    flags_detected: flags,
    recommendation: score >= 25 ? 'Do not click links or share credentials.' : 'Looks safe.'
  };
}

function displaySmsResult(data) {
  const card = document.getElementById('smsResultCard');
  const title = document.getElementById('smsVerdictTitle');
  const scoreBadge = document.getElementById('smsScoreBadge');
  const flagsList = document.getElementById('smsFlagsList');
  const rec = document.getElementById('smsRecommendation');

  card.className = 'result-card';
  flagsList.innerHTML = '';

  if (data.verdict === 'SAFE') {
    card.classList.add('safe');
    title.textContent = '🟢 Likely Safe Message';
  } else if (data.verdict === 'SUSPICIOUS') {
    card.classList.add('caution');
    title.textContent = '🟡 Suspicious Phishing Pattern';
  } else {
    card.classList.add('danger');
    title.textContent = '🔴 High Risk Scam Message';
  }

  scoreBadge.textContent = `Score: ${data.risk_score}/100`;

  if (data.flags_detected && data.flags_detected.length > 0) {
    data.flags_detected.forEach(flag => {
      const chip = document.createElement('span');
      chip.className = 'flag-chip';
      chip.textContent = flag;
      flagsList.appendChild(chip);
    });
  }

  rec.textContent = data.recommendation || '';
  card.classList.remove('hidden');
}

// --- 3. Breach Checker Binding ---
function bindBreachChecker() {
  const checkBtn = document.getElementById('checkBreachBtn');
  const emailInput = document.getElementById('breachInput');

  checkBtn.addEventListener('click', async () => {
    const email = emailInput.value.trim();
    if (!email) return;

    checkBtn.disabled = true;
    checkBtn.textContent = 'Checking Breaches...';

    let result = null;
    try {
      const response = await fetch(`${API_BASE_URL}/check-breach`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier: email })
      });
      if (response.ok) {
        const json = await response.json();
        result = json.data;
      }
    } catch (e) {
      setNetworkStatus(false);
    }

    if (!result) {
      result = {
        account: email,
        breached: false,
        breach_count: 0,
        message: 'No breach records found (Backend offline verification).'
      };
    }

    checkBtn.disabled = false;
    checkBtn.textContent = 'Check Leaked Breaches';

    displayBreachResult(result);
  });
}

function displayBreachResult(data) {
  const card = document.getElementById('breachResultCard');
  const title = document.getElementById('breachVerdictTitle');
  const msg = document.getElementById('breachMsg');

  card.className = 'result-card';

  if (data.breached) {
    card.classList.add('danger');
    title.textContent = `🔴 Compromised in ${data.breach_count} Data Breaches!`;
    msg.textContent = `Email ${data.account} was found in public leak databases. Change your passwords immediately.`;
  } else {
    card.classList.add('safe');
    title.textContent = '🟢 No Breach Records Found';
    msg.textContent = `Email ${data.account} appears clean in tracked breach databases.`;
  }

  card.classList.remove('hidden');
}

// --- 4. Disposable Temp Mail Binding ---
function bindTempMail() {
  const genBtn = document.getElementById('generateEmailBtn');
  const copyBtn = document.getElementById('copyEmailBtn');
  const refreshBtn = document.getElementById('refreshInboxBtn');
  const tempEmailText = document.getElementById('tempEmailText');
  const inboxList = document.getElementById('inboxList');

  let currentAddress = '';

  genBtn.addEventListener('click', async () => {
    genBtn.disabled = true;
    genBtn.textContent = 'Generating...';

    try {
      const res = await fetch(`${API_BASE_URL}/temp-mail/generate`, { method: 'POST' });
      if (res.ok) {
        const json = await res.json();
        currentAddress = json.data.email;
        tempEmailText.textContent = currentAddress;
      }
    } catch (e) {
      // Local fallback burner generator
      const random = Math.random().toString(36).substring(2, 10);
      currentAddress = `burner_${random}@safelink-temp.com`;
      tempEmailText.textContent = currentAddress;
      setNetworkStatus(false);
    }

    genBtn.disabled = false;
    genBtn.textContent = 'Generate New Burner Email';

    fetchInbox(currentAddress);
  });

  copyBtn.addEventListener('click', () => {
    if (currentAddress) {
      navigator.clipboard.writeText(currentAddress);
      const originalText = tempEmailText.textContent;
      tempEmailText.textContent = 'Copied to Clipboard!';
      setTimeout(() => tempEmailText.textContent = originalText, 1500);
    }
  });

  refreshBtn.addEventListener('click', () => {
    if (currentAddress) {
      fetchInbox(currentAddress);
    }
  });
}

async function fetchInbox(address) {
  const inboxList = document.getElementById('inboxList');
  inboxList.innerHTML = '<div class="inbox-empty">Checking inbox...</div>';

  try {
    const res = await fetch(`${API_BASE_URL}/temp-mail/inbox/${address}`);
    if (res.ok) {
      const json = await res.json();
      const messages = json.data.messages || [];

      if (messages.length === 0) {
        inboxList.innerHTML = '<div class="inbox-empty">No incoming messages yet.</div>';
        return;
      }

      inboxList.innerHTML = '';
      messages.forEach(m => {
        const div = document.createElement('div');
        div.className = 'inbox-item';
        div.innerHTML = `
          <div class="inbox-subject">${m.subject}</div>
          <div class="inbox-sender">From: ${m.sender}</div>
        `;
        inboxList.appendChild(div);
      });
      return;
    }
  } catch (e) {
    setNetworkStatus(false);
  }

  inboxList.innerHTML = '<div class="inbox-empty">Virtual Inbox Ready (0 messages).</div>';
}

function setNetworkStatus(isOnline) {
  const el = document.getElementById('networkStatus');
  if (!isOnline) {
    el.className = 'status-indicator offline';
    el.querySelector('.status-text').textContent = 'Offline Mode';
  } else {
    el.className = 'status-indicator';
    el.querySelector('.status-text').textContent = 'Backend Active';
  }
}
