const API_BASE_URL = 'http://localhost:8080/api/v1';

// 1. Context Menu Setup
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: 'safelink_scan_link',
    title: '🛡️ Scan link with SafeLink AI',
    contexts: ['link']
  });

  console.log('SafeLink AI Extension Installed Successfully');
});

// 2. Handle Context Menu Clicks
chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId === 'safelink_scan_link' && info.linkUrl) {
    const targetUrl = info.linkUrl;
    
    // Notify scanning start
    showNotification('SafeLink AI Scanning...', `Checking threat intelligence for: ${targetUrl}`);

    const result = await scanUrl(targetUrl);

    if (result.verdict === 'SAFE') {
      showNotification('🟢 Safe Link Verified', `No threat found on ${result.domain}. Clean domain!`);
    } else if (result.verdict === 'SUSPICIOUS') {
      showNotification('🟡 Suspicious Link Warning', `Caution: ${result.verdict_title || 'Unverified subscription/domain'}`);
    } else {
      showNotification('🔴 DANGEROUS SCAM LINK!', `DANGER: Flagged as phishing or scam source! Score: ${result.risk_score}/100`);
    }
  }
});

// 3. Background URL Scanner Function
async function scanUrl(url) {
  try {
    const response = await fetch(`${API_BASE_URL}/scan-url`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url })
    });
    if (response.ok) {
      const json = await response.json();
      return json.data;
    }
  } catch (err) {
    console.warn('Backend unavailable, running background heuristic check', err);
  }

  // Fallback Heuristics
  let score = 0;
  let domain = url;
  try { domain = new URL(url).hostname; } catch (e) {}

  const suspiciousExts = ['xyz', 'top', 'tk', 'click', 'work', 'gq'];
  const ext = domain.split('.').pop();
  if (suspiciousExts.includes(ext)) score += 35;
  if (/bit\.ly|tinyurl\.com|rb\.gy/i.test(domain)) score += 25;
  if (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(domain)) score += 40;

  const verdict = score >= 50 ? 'DANGEROUS' : score >= 25 ? 'SUSPICIOUS' : 'SAFE';
  return { url, domain, verdict, risk_score: score, verdict_title: 'Heuristic security check' };
}

// 4. Native Browser Notification Helper
function showNotification(title, message) {
  chrome.notifications.create({
    type: 'basic',
    iconUrl: '../icons/icon48.png',
    title: title,
    message: message,
    priority: 2
  });
}

// 5. Active Tab Security Badge Listener
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  if (changeInfo.status === 'complete' && tab.url && tab.url.startsWith('http')) {
    scanUrl(tab.url).then(res => {
      if (res.verdict === 'SAFE') {
        chrome.action.setBadgeBackgroundColor({ color: '#10B981', tabId });
        chrome.action.setBadgeText({ text: 'SAFE', tabId });
      } else if (res.verdict === 'SUSPICIOUS') {
        chrome.action.setBadgeBackgroundColor({ color: '#F59E0B', tabId });
        chrome.action.setBadgeText({ text: 'WARN', tabId });
      } else {
        chrome.action.setBadgeBackgroundColor({ color: '#EF4444', tabId });
        chrome.action.setBadgeText({ text: 'SCAM', tabId });
      }
    });
  }
});
