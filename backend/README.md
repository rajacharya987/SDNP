# SafeLink AI - Threat Detection & Security Backend API

A containerized Laravel 11 API backend providing real-time URL threat detection, subscription scam analysis, SMS social engineering detection, data breach checks, and temporary burner email services for the **SafeLink AI** Flutter app.

---

## Architecture Overview

```
                      +-----------------------------+
                      |   SafeLink AI Flutter App   |
                      +--------------+--------------+
                                     |
                                REST API (JSON)
                                     v
                      +-----------------------------+
                      |     Nginx (Port 8080)       |
                      +--------------+--------------+
                                     |
                                  FastCGI
                                     v
                      +-----------------------------+
                      |    Laravel PHP-FPM Stack    |
                      +---+-----------+---------+---+
                          |           |         |
           +--------------+           |         +--------------+
           v                          v                        v
  +-----------------+       +------------------+     +------------------+
  |  MySQL Database |       |  Redis Cache     |     | Threat Intelligence|
  |  (Scan History) |       |  (24h Scan TTL)  |     | APIs (GSB/VT/HIBP)|
  +-----------------+       +------------------+     +------------------+
```

---

## 🚀 Quick Start with Docker

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed on your machine.

### Running the Backend

1. **Navigate to backend folder**:
   ```bash
   cd SDNP/backend
   ```

2. **Start Docker Containers**:
   ```bash
   docker compose up -d --build
   ```

3. **Check Running Services**:
   ```bash
   docker compose ps
   ```
   You will see four active containers:
   - `safelink-webserver` (Nginx on `http://localhost:8080`)
   - `safelink-app` (PHP 8.3 FPM Application)
   - `safelink-db` (MySQL 8.0 Database on port `3306`)
   - `safelink-redis` (Redis Server on port `6379`)

4. **Run Database Migrations**:
   ```bash
   docker compose exec app php artisan migrate --seed
   ```

---

## 📡 API Endpoints Reference

### 1. Health Check
- **URL**: `GET /api/v1/health`
- **Response**:
  ```json
  {
    "status": "healthy",
    "app": "SafeLink AI Backend",
    "version": "1.0.0",
    "timestamp": "2026-08-09T09:58:00Z"
  }
  ```

---

### 2. URL Threat & Subscription Scam Scanner
- **URL**: `POST /api/v1/scan-url`
- **Headers**: `Content-Type: application/json`
- **Request Body**:
  ```json
  {
    "url": "http://g00gle-verify-account.xyz"
  }
  ```
- **Response**:
  ```json
  {
    "status": "success",
    "message": "URL security analysis complete",
    "data": {
      "url": "http://g00gle-verify-account.xyz",
      "domain": "g00gle-verify-account.xyz",
      "verdict": "DANGEROUS",
      "verdict_title": "Dangerous Phishing / Scam Source",
      "verdict_color": "red",
      "risk_score": 85,
      "threat_details": [
        "Suspicious TLD extension: .xyz",
        "Possible brand impersonation / typosquatting target: google"
      ],
      "breakdown": {
        "heuristics": {
          "score": 60,
          "threats": [
            "Suspicious TLD extension: .xyz",
            "Possible brand impersonation / typosquatting target: google"
          ]
        },
        "google_safe_browsing": {
          "status": "untested",
          "is_malicious": false
        },
        "virustotal": {
          "status": "untested",
          "is_malicious": false
        }
      }
    }
  }
  ```

---

### 3. SMS & Social Engineering Analyzer
- **URL**: `POST /api/v1/analyze-sms`
- **Request Body**:
  ```json
  {
    "message": "URGENT: Your account is locked! Click http://bit.ly/bank-fix to verify immediately."
  }
  ```
- **Response**:
  ```json
  {
    "status": "success",
    "data": {
      "risk_score": 80,
      "verdict": "HIGH_RISK_SCAM",
      "verdict_title": "High Risk Scam Message",
      "verdict_color": "red",
      "flags_detected": [
        "Urgency Indicator: 'urgent'",
        "Urgency Indicator: 'locked'",
        "Contains Embedded Links (1)",
        "URL Shortener Link Detected: http://bit.ly/bank-fix"
      ],
      "extracted_urls": [
        "http://bit.ly/bank-fix"
      ],
      "recommendation": "Do NOT click any embedded links or provide personal details. Verify with the organization directly."
    }
  }
  ```

---

### 4. Data Breach Checker
- **URL**: `POST /api/v1/check-breach`
- **Request Body**:
  ```json
  {
    "identifier": "user@example.com"
  }
  ```

---

### 5. Disposable Temp Mail Generator
- **URL**: `POST /api/v1/temp-mail/generate`
- **Response**:
  ```json
  {
    "status": "success",
    "data": {
      "email": "a8x9q2m10k@safelink-temp.com",
      "expires_in_minutes": 60
    }
  }
  ```

---

### 6. Temp Mail Inbox Lookup
- **URL**: `GET /api/v1/temp-mail/inbox/{address}`

---

## 🔑 External API Configuration (`.env`)

Add your free API keys to `.env` to activate live third-party security scans:

```ini
# Google Safe Browsing API Key
GOOGLE_SAFE_BROWSING_API_KEY=your_google_safe_browsing_key_here

# VirusTotal API Key
VIRUSTOTAL_API_KEY=your_virustotal_key_here

# Have I Been Pwned API Key
HIBP_API_KEY=your_hibp_key_here
```
