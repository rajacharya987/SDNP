# SafeLink AI - Cross-Browser Extension (Chrome, Edge, Brave, Opera)

A Manifest V3 browser extension for **Google Chrome**, **Microsoft Edge**, **Brave**, **Opera**, and modern browsers to protect users from malicious phishing links, subscription traps, SMS scams, data breaches, and generate temporary burner emails in real-time.

---

## 🌟 Key Extension Features

1. **Active Tab Real-Time Shield**:
   - Evaluates the URL of the tab currently open in your browser.
   - Shows live risk status (🟢 **Safe Domain**, 🟡 **Suspicious Link**, 🔴 **Dangerous Threat**).

2. **Multi-Tab Security Hub (Popup UI)**:
   - **URL Scanner**: Auto-pastes or accepts links to scan threat scores against SafeLink AI.
   - **SMS & Text Analyzer**: Paste SMS / email text to detect social engineering flags ("Urgent action required", "Account locked", financial bait).
   - **Data Breach Lookup**: Check if email addresses were leaked in public data breaches.
   - **Disposable Temp Mail**: Generate `@safelink-temp.com` burner emails with direct copy and virtual inbox polling.

3. **Right-Click Context Menu Scanner**:
   - Right-click any hyperlink on any web page -> Select **"🛡️ Scan link with SafeLink AI"**.
   - Displays a native browser desktop notification with the security verdict.

4. **Hybrid API + Offline Fallback**:
   - Connects to local Laravel backend (`http://localhost:8080/api/v1/`).
   - Includes client-side heuristic engine fallback (detecting suspicious TLDs like `.xyz`, `.top`, URL shorteners, direct IP hostnames) so scanning works even offline.

---

## 🛠️ How to Install in Browsers

### 1. Google Chrome / Brave / Opera
1. Open Chrome and go to `chrome://extensions`.
2. Enable **Developer mode** toggle in the top-right corner.
3. Click **Load unpacked**.
4. Select the directory: `c:\Users\Acer\New folder (2)\SDNP\extension`.
5. Pin **SafeLink AI** to your browser toolbar!

### 2. Microsoft Edge
1. Open Edge and go to `edge://extensions`.
2. Enable **Developer mode** toggle in the left sidebar.
3. Click **Load unpacked**.
4. Select the directory: `c:\Users\Acer\New folder (2)\SDNP\extension`.
5. Pin **SafeLink AI** to your browser toolbar!

---

## 📁 Extension File Structure

```
SDNP/extension/
├── manifest.json                  # Manifest V3 extension configuration
├── popup/
│   ├── popup.html                 # Tabbed security dashboard HTML
│   ├── popup.css                  # Dark mode UI styles & animations
│   └── popup.js                   # Interactive scanner logic & API fetcher
├── background/
│   └── background.js              # Service Worker (Context menu & tab status badge)
├── content/
│   ├── content.js                 # Content script for page protection
│   └── content.css                # Content banner styling
├── icons/
│   ├── icon16.png                 # Toolbar icon (16x16)
│   ├── icon48.png                 # Manage extensions icon (48x48)
│   └── icon128.png                # Web store icon (128x128)
└── README.md                      # Load guide
```
