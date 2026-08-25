# BrowserParity

A clean, personal configuration setup and utility toolkit that keeps **Opera**, **Microsoft Edge**, **Mozilla Firefox**, and **Google Chrome** in consistent sync with DuckDuckGo search, dark mode, uniform typography, enterprise intranet & local network security, and helpful userscripts.

🌐 **Web Deployment Hub**: [https://SemperSupra.github.io/BrowserParity/](https://SemperSupra.github.io/BrowserParity/)  
📦 **GitHub Repository**: [https://github.com/SemperSupra/BrowserParity](https://github.com/SemperSupra/BrowserParity)

---

## 🧭 Navigation

* [👨‍💻 1. Human User Guide](#-1-human-user-guide)
  * [1-Line Quickstart](#1-line-quickstart)
  * [Browser Configuration Matrix](#browser-configuration-matrix)
  * [Network Profiles: Home vs. Mobile](#network-profiles-home-vs-mobile)
  * [Private GitHub Backup & Restore](#private-github-backup--restore)
  * [Userscript Tools Catalog](#userscript-tools-catalog)
  * [Keyboard Shortcut Cheat Sheet](#keyboard-shortcut-cheat-sheet)
  * [Troubleshooting & FAQ](#troubleshooting--faq)
* [⚙️ 2. Automation & CLI Reference](#️-2-automation--cli-reference)
  * [Complete CLI Parameter Reference](#complete-cli-parameter-reference)
  * [Exit Codes & Idempotency Invariants](#exit-codes--idempotency-invariants)
  * [Declarative JSON Schemas](#declarative-json-schemas)
  * [Cross-Platform Engine Architecture](#cross-platform-engine-architecture)

---

# 👨‍💻 1. Human User Guide

### 1-Line Quickstart

#### On Windows (PowerShell 5.1 or pwsh 7.x):
```powershell
irm https://raw.githubusercontent.com/SemperSupra/BrowserParity/main/bootstrap-new-box.ps1 | iex
```

#### On macOS & Linux (POSIX Bash):
```bash
curl -fsSL https://raw.githubusercontent.com/SemperSupra/BrowserParity/main/bootstrap-new-box.sh | bash
```

---

### Browser Configuration Matrix

| Setting / Component | Opera | Microsoft Edge | Mozilla Firefox | Google Chrome | Parity Behavior |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **Default Search** | **DuckDuckGo** | **DuckDuckGo** | **DuckDuckGo** | **DuckDuckGo** | Clean privacy search |
| **Userscript Sync** | **Violentmonkey** | **Violentmonkey** | **Violentmonkey** | **Violentmonkey** | Synced via Cloud |
| **Cookie Popups** | **Consent-O-Matic** | **Consent-O-Matic** | **Consent-O-Matic** | **Consent-O-Matic** | Auto-dismiss banners |
| **Ad / Tracker Block**| **Native Strict Block**| **uBlock Origin Lite** | **uBlock Origin** | **uBlock Origin Lite** | Zero ad clutter |
| **Web Dark Mode** | **Native Dark Theme** | **Dark Reader** | **Firefox Native Dark**| **Dark Reader** | Eye-friendly dark UI |
| **Notifications** | **Blocked** (`2`) | **Blocked** (`2`) | **Blocked** (`2`) | **Blocked** (`2`) | Zero prompt spam |
| **Media Autoplay** | **Blocked** | **Blocked** | **Blocked** (`5`) | **Blocked** | No audio/video autoplay |
| **AI / Assistant Bloat**| **Disabled** (Aria hidden)| **Disabled** (Copilot off)| **Disabled** (Pocket off)| **Disabled** (Sandbox off)| Zero sidebar AI nags |
| **Search Autocomplete**| **Disabled** | **Disabled** | **Disabled** | **Disabled** | No address bar predictions |
| **Session Restore** | **Restore Previous** | **Restore Previous** | **Restore Previous** | **Restore Previous** | Tabs preserved on crash/reboot |
| **Typography** | **Segoe UI / Consolas** | **Segoe UI / Consolas** | **Segoe UI / Consolas** | **Segoe UI / Consolas** | Standard 16px / 13px mono |
| **Downloads Path** | `~/Downloads` | `~/Downloads` | `~/Downloads` | `~/Downloads` | Silent save to Downloads |
| **Background RAM** | **Disabled** | **Disabled** | **Disabled** | **Disabled** | No background RAM on boot |

---

### Network Profiles: Home vs. Mobile

BrowserParity includes two pre-tuned DNS and network security profiles:

* **`Home` Profile (Default)**: Optimized for local dev servers, internal intranets, and mesh VPNs (`*.local`, `*.ts.net`, `192.168.*`, `10.*`). Features resilient Quad9 DNS with local router fallback and IPv4 priority.
* **`Mobile` Profile**: Zero-trust hardening for untrusted public Wi-Fi (airports, hotels, cellular hotspots). Enforces strict DNS-over-HTTPS (DoH), strict HTTPS-only mode, and Encrypted Client Hello (ECH / ESNI).

```powershell
# Apply Home profile (default):
.\sync-browser-parity.ps1 -Profile Home

# Apply Mobile profile before traveling:
.\sync-browser-parity.ps1 -Profile Mobile
```

---

### Private GitHub Backup & Restore

Keep personal bookmarks, extensions, and exact profile states backed up across devices while keeping this repository 100% open source:

* **Public Repository (`BrowserParity`)**: Holds only open-source parity scripts, userscripts, and schemas.
* **Private Repository (`BrowserParity-mark`)**: Encapsulates your personal bookmarks, extensions, and custom settings.

```powershell
# 1. Back up bookmarks & profiles to private GitHub repository:
.\backup-to-github.ps1

# 2. Preview delta vs local state on a new machine without changing files:
.\restore-from-github.ps1 -Diff

# 3. Restore and smart-merge on a new machine:
.\restore-from-github.ps1
```

> [!IMPORTANT]
> **Strict Privacy Safety Enforced**:
> `backup-to-github.ps1` verifies repository visibility via GitHub CLI. If the target repository is detected as **PUBLIC**, the script **immediately halts with a security error** and refuses to upload your bookmarks or personal profile data.

---

### Userscript Tools Catalog

All userscripts in [`userscripts/`](userscripts/) can be installed directly with 1 click from the [Live Deployment Hub](https://SemperSupra.github.io/BrowserParity/):

| Userscript | Target Sites | Key Features |
| :--- | :--- | :--- |
| **[`webmail-calendar-sync.user.js`](userscripts/webmail-calendar-sync.user.js)** | Webmail & OWA (`outlook.office365.us`, `mail.mil`) | • **`Alt+G`**: 1-Click Send to Google Calendar<br>• **`Alt+D`**: Download active email as RFC-822 `.eml`<br>• **`Alt+F`**: Instant client-side regex search<br>• Bulk `.ICS` month/week grid export<br>• 1-Click grab all email attachments |
| **[`sharepoint-teams-power-dx.user.js`](userscripts/sharepoint-teams-power-dx.user.js)** | SharePoint Online, OneDrive, Teams | • **`Alt+Click`**: Force direct file download<br>• **`Alt+D`**: Download active Office Online doc<br>• **`Alt+B`**: Batch download visible library files<br>• Direct `⬇` download icons on document lists |
| **[`health-record-grabber.user.js`](userscripts/health-record-grabber.user.js)** | Health & Clinical Portals | • **`Alt+M`**: Open Consolidated Record Dossier<br>• Clean **Print to PDF** (strips nav bars and sidebars)<br>• **`Alt+L`**: Export all Lab Results to CSV / Excel<br>• Export Medications list to CSV / Markdown |
| **[`work-portal-power-dx.user.js`](userscripts/work-portal-power-dx.user.js)** | Work Portals & Forms | • **Session Guard**: Auto-extends idle session timeout modals<br>• Enables Textarea Resizing (`resize: both`)<br>• Re-enables native browser spellcheck<br>• Strips anti-paste/anti-copy restrictions |
| **[`ai-chat-power-dx.user.js`](userscripts/ai-chat-power-dx.user.js)** | ChatGPT & Google Gemini | • **`Alt+W`**: Toggle 94vw Responsive Full-Width Layout<br>• **`Alt+E`**: 1-Click Export full chat to clean Markdown `.md`<br>• **`Alt+↑ / ↓`**: Terminal-style prompt history cycler<br>• **`/`**: Instant focus prompt input |
| **[`web-power-dx.user.js`](userscripts/web-power-dx.user.js)** | Amazon & eBay (US/DE), Hacker News, GitHub | • Dims and de-sponsors paid ads on Amazon & eBay<br>• 1-Click Amazon US ↔ DE ASIN product switcher<br>• Modern Dark mode & collapsible threads on Hacker News<br>• 95vw Wide-Screen PR and Diff view on GitHub |

---

### Keyboard Shortcut Cheat Sheet

| Shortcut | Context / Domain | Functionality |
| :--- | :--- | :--- |
| **`Alt + G`** | Webmail (OWA) | **Send to Google Calendar** (Opens pre-filled web event editor). |
| **`Alt + D`** | Webmail / SharePoint | **Direct Download** (Saves `.eml` or extracts active Office Online doc). |
| **`Alt + F`** | Webmail (OWA) | **Instant Client Filter** (Real-time regex search in loaded message list). |
| **`Alt + Click`** | SharePoint / Teams | **Force Direct Download** (Bypasses web viewer traps). |
| **`Alt + B`** | SharePoint / Teams | **Batch Folder Downloader** (Sequentially downloads all visible files). |
| **`Alt + M`** | Health Portal | **Open Consolidated Record Dossier** (Prepares clean Print-to-PDF). |
| **`Alt + L`** | Health Portal | **Export Labs to CSV** (Instant spreadsheet download). |
| **`Alt + W`** | ChatGPT / Gemini | **Toggle Wide Screen** (Expands container to 94vw). |
| **`Alt + E`** | ChatGPT / Gemini | **Export Chat as .MD** (Saves `.md` file to Downloads). |
| **`Alt + ↑ / ↓`** | ChatGPT / Gemini | **Cycle Prompt History** (Navigates recent prompt submissions). |

---

### Troubleshooting & FAQ

#### 1. Smart Card & Client Certificate Recognition:
Firefox automatically loads client certificates from the Windows OS Smart Card CSP without third-party middleware because `sync-browser-parity.ps1` sets:
```javascript
user_pref("security.osclientcerts.autoload", true);
user_pref("security.enterprise_roots.enabled", true);
```
If your smart card certificates are not appearing, ensure the Windows Certificate Propagation service is running:
```powershell
Get-Service -Name SCardSvr, CertPropSvc | Start-Service
```

#### 2. Local LAN HTTP Connections Blocked:
Ensure you are running under `-Profile Home`. Home mode allows plaintext HTTP connections to local subnets (`192.168.*`, `10.*`, `*.local`).

---

# ⚙️ 2. Automation & CLI Reference

### Complete CLI Parameter Reference

#### `sync-browser-parity.ps1`
| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-Profile` | `String` | `'Home'` | Target network profile: `'Home'` (LAN friendly) or `'Mobile'` (Strict DoH & HTTPS-Only). |
| `-Browsers` | `String[]` | `@('Opera','Edge','Firefox','Chrome')` | Target specific browser(s) to configure or manage. |
| `-Install` | `Switch` | `False` | Automatically installs missing browsers via `winget` (Windows), `brew` (macOS), or `apt` (Linux). |
| `-Uninstall`| `Switch` | `False` | Uninstalls targeted browsers. |
| `-Purge` | `Switch` | `False` | Deeply purges profile directories, cache, and leftover registry entries. |
| `-Rollback` | `Switch` | `False` | Restores browser settings to the most recent backup snapshot in `backups/`. |
| `-Launch` | `Switch` | `False` | Launches browser GUI windows after applying parity rules. |
| `-Onboard` | `Switch` | `False` | Launches extension setup tabs and local onboarding hub. |
| `-Versions` | `Switch` | `False` | Displays installed browser version matrix and upgrade history. |
| `-Schema` | `Switch` | `False` | Displays declarative configuration schema rules matrix. |

#### `backup-to-github.ps1`
| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-Repo` | `String` | `'BrowserParity-mark'` | Target private GitHub repository name. |
| `-LocalPath`| `String` | `~/.browserparity-configs` | Local staging clone path. |
| `-Browsers` | `String[]` | `@('Opera','Edge','Firefox','Chrome')` | Select browsers to back up. |

#### `restore-from-github.ps1`
| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-Repo` | `String` | `'BrowserParity-mark'` | Target private GitHub repository name. |
| `-Diff` | `Switch` | `False` | Previews file differences and line deltas without applying changes. |
| `-Launch` | `Switch` | `False` | Launches browsers after restoring configurations. |

---

### Exit Codes & Idempotency Invariants

* **Exit Code `0`**: Operation completed successfully or no-op required (idempotent).
* **Exit Code `1`**: Prerequisite check failed (missing `git`/`gh`) or security violation (attempted backup to public repository).
* **Idempotent Re-entrancy**: Running `sync-browser-parity.ps1` multiple times produces identical state without duplicating preferences or closing active windows.

---

### Declarative JSON Schemas

Configuration rules are declared in [`schemas/browser-parity-schema.json`](schemas/browser-parity-schema.json). Each rule adheres to the schema:
```json
{
  "category": "Anti-Annoyance",
  "minVersion": 0,
  "targetFile": "Preferences",
  "path": ["profile", "default_content_setting_values", "notifications"],
  "value": 2,
  "action": "Set",
  "description": "Block website notification popup requests"
}
```

---

### Cross-Platform Engine Architecture

```text
BrowserParity/
├── index.html                     # 🌐 Live Web Deployment Hub (GitHub Pages)
├── onboarding.html                # 🚀 Local Offline Extension Hub & Dashboard
├── bootstrap-new-box.ps1          # 🪟 Windows Setup Wizard (PowerShell 5.1 & 7.x)
├── bootstrap-new-box.sh           # 🍏/🐧 macOS & Linux Setup Wizard (POSIX Bash)
├── sync-browser-parity.ps1        # ⚙️ Core Parity Engine (Windows)
├── sync-browser-parity.sh         # ⚙️ POSIX Bash Engine Wrapper
├── backup-to-github.ps1           # 🔒 Private GitHub Backup Tool
├── restore-from-github.ps1        # 🔄 Private GitHub Restore & Diff Engine
├── schemas/
│   └── browser-parity-schema.json # 📜 Declarative Version-Gated Rules Schema
└── userscripts/                   # 📜 Power DX & Work Userscripts
    ├── ai-chat-power-dx.user.js
    ├── webmail-calendar-sync.user.js
    ├── work-portal-power-dx.user.js
    ├── sharepoint-teams-power-dx.user.js
    ├── health-record-grabber.user.js
    └── web-power-dx.user.js
```

---

## 📜 License

This project is personal open-source software licensed under the [MIT License](LICENSE).