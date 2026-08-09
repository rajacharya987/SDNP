# SafeLink AI (ScamLink)

Personal cybersecurity toolkit that helps people check links, spot phishing, review breach exposure, and browse more safely — across a **Flutter mobile app**, **Laravel API**, **browser extension**, and optional **Windows agent**.

---

## What’s in this repo

| Folder | What it is |
|--------|------------|
| [`app/`](app/) | Flutter mobile app (Android / iOS) — scan links, QR, breach check, SMS analysis, temp mail, in-app Safe Browser |
| [`backend/`](backend/) | Laravel 11 API + Docker (Nginx, PHP-FPM, MySQL, Redis) — multi-source URL threat scanning |
| [`extension/`](extension/) | Manifest V3 browser extension (Chrome, Edge, Brave, Opera) |
| [`agent/`](agent/) | Optional Windows C++ SentinelX desktop agent |

```text
  Flutter App  ──┐
  Extension    ──┼──►  http://localhost:8000/api/v1  ──►  Laravel + Redis + MySQL
  Windows Agent──┘                                              │
                                                                ▼
                                         Google Safe Browsing · VirusTotal
                                         OpenPhish · PhishTank · URLhaus
                                         Local heuristics · Site availability
```

---

## Features

### Mobile app (`app/`)
- **Scan Link** — paste a URL and get SAFE / SUSPICIOUS / DANGEROUS / UNAVAILABLE
- **Share → SafeLink** — from WhatsApp, SMS, Instagram, TikTok, Gmail, and more; auto-checks shared links/text
- **Home widget** — **Paste & Check** shortcut + last verdict on the home screen
- **Clipboard monitor** — while the app is open, asks to check newly copied links (Settings toggle)
- **QR Scanner** — scan codes before opening them
- **Breach check** — email leak lookup
- **SMS / message analyzer** — social-engineering signals + **Scan this link** for extracted URLs
- **Temp mail** — disposable inbox helpers
- **History** — recent scans on device
- **In-app Safe Browser** — open links inside the app (`webview_flutter`) after a scan
- Clear result UI — plain language status, sticky “Open in Safe Browser” action

### Backend API (`backend/`)
- Multi-source URL scanning in parallel:
  - Heuristics (HTTP, shorteners, suspicious TLDs, brand typosquats, path keywords, …)
  - **OpenPhish** (free feed, cached in Redis)
  - **PhishTank** (free)
  - **VirusTotal** (API key)
  - **Google Safe Browsing** (API key)
  - **URLhaus / abuse.ch** (optional free Auth-Key)
  - **Site availability** — DNS + HTTP reachability (“This site is not available”)
- Honest verdicts: never claims **SAFE** when checks are incomplete
- Redis cache for complete results; short TTL for incomplete ones
- Breach check, SMS analysis, temp-mail, auth (Sanctum), SentinelX endpoints

### Browser extension (`extension/`)
- Active-tab risk shield
- Popup: URL scan, SMS analyzer, breach lookup, temp mail
- Right-click “Scan link with SafeLink AI”
- Talks to the same local API

### Windows agent (`agent/`)
- Lightweight SentinelX process / unsigned binary style checks (C++)

---

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Flutter](https://docs.flutter.dev/get-started/install) (for the mobile app)
- Android device/emulator (USB debugging) or iOS toolchain
- Optional API keys (see below)

---

## Quick start — backend

```bash
cd backend
cp .env.example .env
# Set APP_KEY if empty: docker compose run --rm app php artisan key:generate

docker compose up -d --build
docker compose exec app php artisan migrate --seed
```

Services:

| Service | URL / port |
|---------|------------|
| API (Nginx) | http://localhost:8000 |
| Health | http://localhost:8000/up and `/api/v1/health` |
| MySQL | `localhost:3306` |
| Redis | `localhost:6379` |

Containers: `safelink-webserver`, `safelink-app`, `safelink-db`, `safelink-redis`.

### API keys (`.env`)

```env
GOOGLE_SAFE_BROWSING_API_KEY=   # Google Cloud → enable Safe Browsing API
VIRUSTOTAL_API_KEY=             # https://www.virustotal.com/
HIBP_API_KEY=                   # optional
PHISHTANK_APP_KEY=              # optional — https://www.phishtank.com/api_register.php
ABUSECH_AUTH_KEY=               # optional — https://auth.abuse.ch/ (URLhaus)
```

OpenPhish needs **no key**. The scanner still works with VirusTotal + OpenPhish + PhishTank if Google is blocked.

### Useful API routes

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/v1/health` | Health |
| `POST` | `/api/v1/scan-url` | Scan a URL `{ "url": "https://..." }` |
| `GET` | `/api/v1/scan-history` | Recent scans |
| `POST` | `/api/v1/check-breach` | Breach lookup |
| `POST` | `/api/v1/analyze-sms` | SMS / text analysis |
| `POST` | `/api/v1/temp-mail/generate` | Temp mailbox |
| `GET` | `/api/v1/temp-mail/inbox/{address}` | Inbox |

More detail: [`backend/README.md`](backend/README.md).

---

## Quick start — Flutter app

```bash
cd app
flutter pub get
flutter run
```

### Talking to the local API from a phone

Default API base (Android): `http://127.0.0.1:8000/api/v1` in [`app/lib/data/api_config.dart`](app/lib/data/api_config.dart).

On a **physical phone over USB**, forward the backend port:

```bash
adb reverse tcp:8000 tcp:8000
```

Or override at run time:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_LAN_IP:8000/api/v1
```

> `10.0.2.2` only works on the **emulator**, not a real phone.

### For parents / easy checking (Android)

SafeLink is meant to be used without typing URLs:

1. **Share from any app** — In WhatsApp, Messages (SMS), Instagram, TikTok, Gmail, etc., open the suspicious message → **Share** → choose **SafeLink**. The app opens and checks the link or text automatically.
2. **Select text** — Long-press a link or message → **Check with SafeLink** (Process text).
3. **Open with** — Choose SafeLink when opening an `http`/`https` link.
4. **Home screen widget** — Long-press the home screen → **Widgets** → **SafeLink** → add it. Tap **Paste & Check** after copying a link.
5. **Clipboard prompt** — With SafeLink open and *Clipboard auto-monitor* enabled in Settings, copying a link asks **Check this link?**

Local-dev builds still need the backend running and (on USB) `adb reverse tcp:8000 tcp:8000`.

---

## How Scan Link works

1. User pastes a URL (or scans a QR) → taps **Scan Link**.
2. App `POST`s to `/api/v1/scan-url`.
3. Backend:
   - Normalizes URL, runs heuristics
   - Checks if the site is reachable (DNS + HTTP)
   - Queries threat feeds in parallel
   - Scores → **SAFE** / **SUSPICIOUS** / **DANGEROUS** / **UNAVAILABLE**
4. App shows a simple result screen; **Open in Safe Browser** loads the page in an in-app WebView (with a risk banner).

**SAFE** requires enough clean provider results and no incomplete critical checks. Failed or missing providers do **not** get painted as “safe.”

---

## Browser extension

See [`extension/README.md`](extension/README.md).

1. Open `chrome://extensions` (or Edge equivalent)
2. Enable **Developer mode** → **Load unpacked** → select `extension/`
3. Point the extension at `http://localhost:8000/api/v1` (update if your popup/background still reference an older port)

---

## Windows agent

See [`agent/README.md`](agent/README.md).

```cmd
cd agent
build_agent.bat
sentinelx_agent.exe
```

---

## Project layout (high level)

```text
scamlink/
├── README.md                 ← you are here
├── app/                      Flutter client
│   ├── lib/
│   │   ├── data/             API client + config
│   │   ├── models/
│   │   ├── screens/          home, scan, browser, tools, history, settings
│   │   └── theme/
│   └── pubspec.yaml
├── backend/                  Laravel API + Docker
│   ├── app/Http/Controllers/Api/V1/
│   ├── app/Services/         GSB, VT, OpenPhish, PhishTank, URLhaus, availability
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── routes/api.php
├── extension/                MV3 browser extension
└── agent/                    Windows SentinelX agent
```

---

## Docker notes (Windows)

- Compose healthchecks wait for MySQL/Redis before starting PHP-FPM.
- Named volumes keep `vendor` off the slow Windows bind mount.
- If `safelink-app` exits with `entrypoint.sh: no such file or directory`, the script had Windows `CRLF` endings. The Dockerfile strips `\r` on build; you can also re-save `backend/docker/entrypoint.sh` as LF.
- Fix storage permissions if logs fail:

```bash
docker compose exec -u root app sh -c "chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rwx storage bootstrap/cache"
```

---

## Development tips

```bash
# Backend status
cd backend && docker compose ps

# App logs
docker compose logs -f app

# Clear false/old scan cache in Redis
docker compose exec redis redis-cli KEYS "*safelink_scan*"

# Flutter hot restart after API/UI changes
# In the flutter run terminal: R
```

---

## License / intent

Built as a practical anti-scam toolkit for day-to-day link checking. Threat intelligence depends on third-party free/paid APIs and local heuristics — treat results as guidance, not a guarantee.

For component-specific docs:
- [Backend README](backend/README.md)
- [App README](app/README.md)
- [Extension README](extension/README.md)
- [Agent README](agent/README.md)
