const API_BASE_URL = 'http://localhost:8080/api/v1';

// 1. Extension Installation & Context Menu Setup
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'sentinel_scan_link',
    title: '🛡️ Scan link with SentinelX',
    contexts: ['link']
  });

  console.log('SentinelX 2.0 Multi-Layer Protection Installed');
});

// 2. Intercept Navigations & Auto-Block Phishing Sites
chrome.webNavigation.onBeforeNavigate.addListener(async (details) => {
  // Only process main frame navigations (frameId 0)
  if (details.frameId !== 0) return;

  const url = details.url;

  // Skip browser internal protocols & extension block page itself
  if (url.startsWith('chrome://') || url.startsWith('chrome-extension://') || url.startsWith('edge://') || url.startsWith('about:')) {
    return;
  }

  try {
    const fingerprintData = await fetchFingerprint(url);

    if (fingerprintData.action === 'BLOCK' || fingerprintData.threat_score >= 75) {
      console.warn('SentinelX Intercepted High Risk Site:', url, fingerprintData);

      const blockPageUrl = chrome.runtime.getURL(`block/block.html?url=${encodeURIComponent(url)}&score=${fingerprintData.threat_score}&reasons=${encodeURIComponent(JSON.stringify(fingerprintData.reasons))}`);

      chrome.tabs.update(details.tabId, { url: blockPageUrl });
    }
  } catch (err) {
    console.warn('SentinelX Navigation Inspector Exception:', err);
  }
});

// 3. Handle Context Menu Clicks
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === 'sentinel_scan_link' && info.linkUrl) {
    const targetUrl = info.linkUrl;
    
    showNotification('SentinelX Scanning...', `Analyzing threat score for: ${targetUrl}`);

    const res = await fetchFingerprint(targetUrl);

    if (res.threat_score >= 75) {
      showNotification('🔴 SENTINELX BLOCK WARNING', `DANGER: High Risk Phishing Site (${res.threat_score}/100)!`);
    } else if (res.threat_score >= 30) {
      showNotification('🟡 SUSPICIOUS LINK', `Caution: ${res.reasons[0] || 'Unverified domain'}`);
    } else {
      showNotification('🟢 SAFE DOMAIN', `Clean website verified. Threat Score: ${res.threat_score}/100`);
    }
  }
});

// 4. Fetch Fingerprint from Backend or Client Fallback
async function fetchFingerprint(url) {
  try {
    const response = await fetch(`${API_BASE_URL}/sentinel/fingerprint`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url })
    });
    const contentType = response.headers.get('content-type') || '';
    if (response.ok && contentType.includes('application/json')) {
      const json = await response.json();
      return json.data;
    }
  } catch (err) {
    console.warn('Backend unavailable, running background heuristic check', err);
  }

  // Local Client Heuristic Fallback Engine
  let score = 0;
  const reasons = [];
  let domain = url;
  try { domain = new URL(url).hostname; } catch (e) {}

  if (/paypa1|g00gle|chase-verify|bank-login/i.test(domain)) {
    score += 45;
    reasons.push('Lookalike brand domain spoofing');
  }

  const suspiciousExts = ['xyz', 'top', 'tk', 'click', 'work', 'gq'];
  const ext = domain.split('.').pop();
  if (suspiciousExts.includes(ext)) {
    score += 25;
    reasons.push(`High risk TLD extension (.${ext})`);
  }

  if (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(domain)) {
    score += 35;
    reasons.push('Direct IP address hostname');
  }

  return {
    url,
    domain,
    threat_score: score,
    verdict: score >= 75 ? 'MALICIOUS' : (score >= 30 ? 'SUSPICIOUS' : 'SAFE'),
    action: score >= 75 ? 'BLOCK' : 'ALLOW',
    reasons
  };
}

// 5. Notification Helper
function showNotification(title, message) {
  chrome.notifications.create({
    type: 'basic',
    iconUrl: '../icons/icon48.png',
    title: title,
    message: message,
    priority: 2
  });
}

// 6. Active Tab Security Badge Listener
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url && tab.url.startsWith('http')) {
    fetchFingerprint(tab.url).then(res => {
      if (res.threat_score >= 75) {
        chrome.action.setBadgeBackgroundColor({ color: '#EF4444', tabId });
        chrome.action.setBadgeText({ text: 'BLOCK', tabId });
      } else if (res.threat_score >= 30) {
        chrome.action.setBadgeBackgroundColor({ color: '#F59E0B', tabId });
        chrome.action.setBadgeText({ text: 'WARN', tabId });
      } else {
        chrome.action.setBadgeBackgroundColor({ color: '#10B981', tabId });
        chrome.action.setBadgeText({ text: 'SAFE', tabId });
      }
    });
  }
});
