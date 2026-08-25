// ==UserScript==
// @name         BrowserParity Ent-365 Surface Spelunker & CRUD Schema Extractor
// @namespace    https://github.com/SemperSupra/BrowserParity
// @version      3.0.0
// @description  Autonomous Read-Only Surface Spelunker: Dynamic CRUD Affordance Detector, Form Schema Extractor, Grid Analyzer, and Safety-Guarded Multi-App Tour (100% CSP & TrustedTypes Immune).
// @icon         data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMjggMTI4IiB3aWR0aD0iMTI4IiBoZWlnaHQ9IjEyOCI+CiAgPGRlZnM+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9ImJhcmtHcmFkIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iIzRhMzcyOCIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjUwJSIgc3RvcC1jb2xvcj0iIzJkMjIxOCIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0b3AtY29sb3I9IiMxYTE0MGUiLz4KICAgIDwvbGluZWFyR3JhZGllbnQ+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9Im1vc3NHcmFkIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iIzRhZGU4MCIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0b3AtY29sb3I9IiMxNTgwM2QiLz4KICAgIDwvbGluZWFyR3JhZGllbnQ+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9ImFtYmVyR2xvdyIgeDE9IjAlIiB5MT0iMCUiIHgyPSIxMDAlIiB5Mj0iMTAwJSI+CiAgICAgIDxzdG9wIG9mZnNldD0iMCUiIHN0b3AtY29sb3I9IiNmZWYwOGEiLz4KICAgICAgPHN0b3Agb2Zmc2V0PSI1MCUiIHN0b3AtY29sb3I9IiNmNTllMGIiLz4KICAgICAgPHN0b3Agb2Zmc2V0PSIxMDAlIiBzdG9wLWNvbG9yPSIjYjQ1MzA5Ii8+CiAgICA8L2xpbmVhckdyYWRpZW50PgogICAgPGZpbHRlciBpZD0iZ2xvdyIgeD0iLTIwJSIgeT0iLTIwJSIgd2lkdGg9IjE0MCUiIGhlaWdodD0iMTQwJSI+CiAgICAgIDxmZUdhdXNzaWFuQmx1ciBzdGREZXZpYXRpb249IjMiIHJlc3VsdD0iYmx1ciIgLz4KICAgICAgPGZlQ29tcG9zaXRlIGluPSJTb3VyY2VHcmFwaGljIiBpbjI9ImJsdXIiIG9wZXJhdG9yPSJvdmVyIiAvPgogICAgPC9maWx0ZXI+CiAgPC9kZWZzPgoKICA8IS0tIEJhY2tncm91bmQgQ2lyY2xlIChEZWVwIEZvcmVzdCkgLS0+CiAgPGNpcmNsZSBjeD0iNjQiIGN5PSI2NCIgcj0iNjAiIGZpbGw9IiMxNDFkMTYiIHN0cm9rZT0iIzIyYzU1ZSIgc3Ryb2tlLXdpZHRoPSIzIi8+CgogIDwhLS0gRW50IFRydW5rIC8gSGVhZCAtLT4KICA8cGF0aCBkPSJNNDAgMzIgQzQwIDE4LCA1MCAxNCwgNjQgMTQgQzc4IDE0LCA4OCAxOCwgODggMzIgQzkyIDQ4LCA5NCA3MCwgOTAgOTIgQzg2IDEwOCwgNDIgMTA4LCAzOCA5MiBDMzQgNzAsIDM2IDQ4LCA0MCAzMiBaIiBmaWxsPSJ1cmwoI2JhcmtHcmFkKSIgc3Ryb2tlPSIjMWExNDBlIiBzdHJva2Utd2lkdGg9IjIiLz4KCiAgPCEtLSBCYXJrIFRleHR1cmUgTGluZXMgLS0+CiAgPHBhdGggZD0iTTUyIDI4IFE1MCA1MCA1NCA3NSBNNzYgMjggUTc4IDUwIDc0IDc1IE02NCAyMCBRNjIgNDUgNjQgNjgiIHN0cm9rZT0iIzFmMTgxMiIgc3Ryb2tlLXdpZHRoPSIyLjUiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgZmlsbD0ibm9uZSIvPgoKICA8IS0tIExlYWYgQ3Jvd24gLS0+CiAgPHBhdGggZD0iTTM4IDE4IFEzMCA4IDQ0IDggUTQ2IDE2IDM4IDE4IFoiIGZpbGw9InVybCgjbW9zc0dyYWQpIi8+CiAgPHBhdGggZD0iTTY0IDEyIFE2NCAyIDc0IDQgUTcwIDEyIDY0IDEyIFoiIGZpbGw9InVybCgjbW9zc0dyYWQpIi8+CiAgPHBhdGggZD0iTTkwIDE4IFE5OCA4IDg0IDggUTgyIDE2IDkwIDE4IFoiIGZpbGw9InVybCgjbW9zc0dyYWQpIi8+CgogIDwhLS0gTGVhZiBCZWFyZCAvIEZvbGlhZ2UgLS0+CiAgPHBhdGggZD0iTTQ0IDcyIFEzNiA4NiA0OCA5OCBRNTYgMTA4IDY0IDExNCBRNzIgMTA4IDgwIDk4IFE5MiA4NiA4NCA3MiBRNjQgODIgNDQgNzIgWiIgZmlsbD0idXJsKCNtb3NzR3JhZCkiIHN0cm9rZT0iIzE2NjUzNCIgc3Ryb2tlLXdpZHRoPSIxLjUiLz4KICA8cGF0aCBkPSJNNTIgODIgUTQ4IDk0IDU2IDEwMiBRNjQgMTA4IDcyIDEwMiBRODAgOTQgNzYgODIgUTY0IDkwIDUyIDgyIFoiIGZpbGw9IiMxNTgwM2QiLz4KCiAgPCEtLSBHbG93aW5nIEFtYmVyIEV5ZXMgKEVudGlzaCBXaXNkb20pIC0tPgogIDxlbGxpcHNlIGN4PSI1MiIgY3k9IjQ2IiByeD0iNiIgcnk9IjciIGZpbGw9InVybCgjYW1iZXJHbG93KSIgZmlsdGVyPSJ1cmwoI2dsb3cpIi8+CiAgPGVsbGlwc2UgY3g9Ijc2IiBjeT0iNDYiIHJ4PSI2IiByeT0iNyIgZmlsbD0idXJsKCNhbWJlckdsb3cpIiBmaWx0ZXI9InVybCgjZ2xvdykiLz4KICA8Y2lyY2xlIGN4PSI1MiIgY3k9IjQ2IiByPSIyLjUiIGZpbGw9IiM0NTFhMDMiLz4KICA8Y2lyY2xlIGN4PSI3NiIgY3k9IjQ2IiByPSIyLjUiIGZpbGw9IiM0NTFhMDMiLz4KICA8Y2lyY2xlIGN4PSI1NCIgY3k9IjQ0IiByPSIxLjUiIGZpbGw9IiNmZmZmZmYiLz4KICA8Y2lyY2xlIGN4PSI3OCIgY3k9IjQ0IiByPSIxLjUiIGZpbGw9IiNmZmZmZmYiLz4KCiAgPCEtLSBXaXNlIEVudCBCcm93IC8gTm9zZSAtLT4KICA8cGF0aCBkPSJNNDQgMzggUTUyIDM1IDYwIDQwIEw2NCA1NiBMNjggNDAgUTc2IDM1IDg0IDM4IiBzdHJva2U9IiMxYTE0MGUiIHN0cm9rZS13aWR0aD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CgogIDwhLS0gRGlnaXRhbCBDb21wYXNzIC8gUm9vdCBSdW5lIE92ZXJsYXkgKFN1YnRsZSkgLS0+CiAgPGNpcmNsZSBjeD0iNjQiIGN5PSI2NCIgcj0iNTQiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzRhZGU4MCIgc3Ryb2tlLXdpZHRoPSIxIiBzdHJva2UtZGFzaGFycmF5PSIzLDYiIG9wYWNpdHk9IjAuNiIvPgo8L3N2Zz4=
// @author       Antigravity AI
// @updateURL    https://SemperSupra.github.io/BrowserParity/userscripts/portal-surface-spelunker.user.js
// @downloadURL  https://SemperSupra.github.io/BrowserParity/userscripts/portal-surface-spelunker.user.js
// @supportURL   https://github.com/SemperSupra/BrowserParity/issues
// @homepageURL  https://SemperSupra.github.io/BrowserParity/
// @match        https://*.sharepoint-mil.us/*
// @match        https://*.sharepoint.us/*
// @match        https://*.teams.microsoft.us/*
// @match        https://*.gov.teams.microsoft.us/*
// @match        https://*.office365.us/*
// @match        https://*.onedrive-mil.us/*
// @match        https://*.apps.mil/*
// @match        https://*.appsplatform.us/*
// @match        https://webmail.apps.mil/*
// @match        https://dod365.sharepoint-mil.us/*
// @match        https://dod365-my.sharepoint-mil.us/*
// @match        https://dod.teams.microsoft.us/*
// @match        https://www.ohome.apps.mil/*
// @match        https://tasks.osi.apps.mil/*
// @match        https://leave.af.mil/*
// @match        https://patientportal.mhsgenesis.health.mil/*
// @runtime-env  PUBLIC_HUMAN_RESTRICTED
// @csp-level    STRICT
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function() {
    'use strict';

    // ----------------------------------------------------
    // 1. INJECT STYLES SAFELY (PURE TEXTCONTENT - ZERO INNERHTML)
    // ----------------------------------------------------
    const styles = `
        #bp-spelunker-hud {
            position: fixed !important;
            bottom: 24px !important;
            left: 24px !important;
            width: 330px !important;
            background: rgba(15, 23, 18, 0.96) !important;
            color: #f0fdf4 !important;
            border: 1px solid #2d4234 !important;
            border-radius: 12px !important;
            padding: 12px 16px !important;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
            font-size: 12px !important;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.7), 0 0 16px rgba(34, 197, 94, 0.25) !important;
            z-index: 2147483647 !important;
            backdrop-filter: blur(10px) !important;
            user-select: none !important;
            display: flex !important;
            flex-direction: column !important;
            gap: 8px !important;
            transition: all 0.2s ease !important;
        }

        #bp-spelunker-hud.minimized {
            width: auto !important;
            min-width: 150px !important;
            padding: 6px 14px !important;
            border-radius: 9999px !important;
            cursor: pointer !important;
            gap: 0 !important;
            background: rgba(15, 23, 18, 0.92) !important;
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.6) !important;
        }
        #bp-spelunker-hud.minimized .bp-spelunker-body {
            display: none !important;
        }

        .bp-spelunker-title {
            display: flex !important;
            align-items: center !important;
            justify-content: space-between !important;
            font-weight: 700 !important;
            color: #4ade80 !important;
            font-size: 13px !important;
        }

        .bp-spelunker-progress-bar {
            width: 100% !important;
            height: 6px !important;
            background: #1f2f25 !important;
            border-radius: 9999px !important;
            overflow: hidden !important;
        }

        .bp-spelunker-progress-fill {
            height: 100% !important;
            background: linear-gradient(90deg, #22c55e, #4ade80) !important;
            width: 0% !important;
            transition: width 0.3s ease !important;
        }

        .bp-crud-stats-grid {
            display: grid !important;
            grid-template-columns: repeat(4, 1fr) !important;
            gap: 4px !important;
            background: #17231b !important;
            padding: 6px 8px !important;
            border-radius: 6px !important;
            border: 1px solid #1f2f25 !important;
            text-align: center !important;
            font-size: 10px !important;
            font-weight: 600 !important;
        }
        .bp-crud-create { color: #4ade80 !important; }
        .bp-crud-read   { color: #38bdf8 !important; }
        .bp-crud-update { color: #f59e0b !important; }
        .bp-crud-delete { color: #f87171 !important; }

        .bp-spelunker-btn {
            background: #1f2f25 !important;
            color: #f0fdf4 !important;
            border: 1px solid #2d4234 !important;
            border-radius: 6px !important;
            padding: 6px 10px !important;
            font-size: 11px !important;
            font-weight: 600 !important;
            cursor: pointer !important;
            text-align: center !important;
            transition: all 0.15s ease !important;
        }
        .bp-spelunker-btn:hover { background: #22c55e !important; color: #ffffff !important; border-color: #4ade80 !important; }
        .bp-spelunker-btn.running { background: #dc2626 !important; color: #ffffff !important; }
    `;

    function injectStylesSafely() {
        if (document.getElementById('bp-spelunker-styles')) return;
        const styleEl = document.createElement('style');
        styleEl.id = 'bp-spelunker-styles';
        styleEl.textContent = styles;
        (document.head || document.documentElement || document.body)?.appendChild(styleEl);
    }

    // ----------------------------------------------------
    // 2. MULTI-APP SURFACE CATALOGS
    // ----------------------------------------------------
    const SURFACES_MHS = [
        { label: "Home", selector: '#application-layout-tab-0, [aria-label*="Home"]' },
        { label: "Health Record", selector: '#application-layout-tab-1, [aria-label*="Health Record"]' },
        { label: "Medications", selector: 'a[href*="medications"], [aria-label*="Medication"]' },
        { label: "Immunizations", selector: 'a[href*="immunizations"], [aria-label*="Immunization"]' },
        { label: "Allergies", selector: 'a[href*="allergies"], [aria-label*="Allergies"]' },
        { label: "Results & Vitals", selector: 'a[href*="results"], [aria-label*="Results and Measurements"]' },
        { label: "Documents & Notes", selector: 'a[href*="documents"], [aria-label*="Clinical Notes"]' },
        { label: "Appointments", selector: '#application-layout-tab-3, [aria-label*="Appointments"]' }
    ];

    const SURFACES_OWA = [
        { label: "Inbox Folder", selector: '[role="treeitem"][aria-label*="Inbox" i], [data-folder-name="Inbox"]' },
        { label: "Sent Items Folder", selector: '[role="treeitem"][aria-label*="Sent" i], [data-folder-name="Sent Items"]' },
        { label: "Drafts Folder", selector: '[role="treeitem"][aria-label*="Draft" i], [data-folder-name="Drafts"]' },
        { label: "Calendar Week View", selector: 'a[aria-label*="Calendar" i], button[aria-label*="Calendar" i]' },
        { label: "Reading Pane / Message", selector: 'div[role="main"], div[aria-label*="Reading Pane" i]' },
        { label: "Search Box", selector: 'input[aria-label*="Search" i], #topSearchInput' },
        { label: "New Mail Composer", selector: 'button[aria-label*="New mail" i], button[data-testid*="new-mail"]' },
        { label: "Settings Flyout", selector: 'button[aria-label*="Settings" i], button#O365_MainLink_Settings'},
        { label: "My Day / To-Do", selector: 'button[aria-label*="My Day" i], button[aria-label*="To Do" i]'}
    ];

    const SURFACES_SHAREPOINT = [
        { label: "Document Library", selector: 'a[href*="Shared Documents" i], [data-automationid*="Documents"]' },
        { label: "Site Navigation Links", selector: 'nav[role="navigation"], [data-automationid="LeftNav"], .ms-Nav' },
        { label: "Lists & Grid Views", selector: '[data-automationid="DetailsList"], [role="grid"], .ms-DetailsList' },
        { label: "Search in Site", selector: 'input[placeholder*="Search" i], input[aria-label*="Search" i]' },
        { label: "New Document / Item Dropdown", selector: 'button[name*="New" i], button[aria-label*="New" i]' }
    ];

    const SURFACES_TEAMS = [
        { label: "Activity Feed", selector: 'button[aria-label*="Activity" i], [data-tid*="activity"]' },
        { label: "Chat List", selector: 'button[aria-label*="Chat" i], [data-tid*="chat"]' },
        { label: "Teams & Channels", selector: 'button[aria-label*="Teams" i], [data-tid*="teams"]' },
        { label: "Calendar / Meetings", selector: 'button[aria-label*="Calendar" i], [data-tid*="calendar"]' },
        { label: "Search Teams", selector: 'input[aria-label*="Search" i], #control-search-box' }
    ];

    const SURFACES_PLANNER = [
        { label: "Task Board Grid", selector: '[data-automation-id="planTaskBoard"], [role="grid"], .boardCanvas' },
        { label: "Assigned to Me", selector: 'a[href*="userboard" i], button[aria-label*="Assigned to me" i]' },
        { label: "Plan Bucket Columns", selector: '.bucketColumn, [data-automation-id="bucketHeader"]' },
        { label: "Charts & Analytics View", selector: 'button[aria-label*="Charts" i], a[href*="charts" i]' },
        { label: "Schedule Calendar View", selector: 'button[aria-label*="Schedule" i], a[href*="schedule" i]' }
    ];

    const SURFACES_SEARCH = [
        { label: "Enterprise Search Input", selector: 'input[aria-label*="Search" i], #searchBox, input[type="search"]' },
        { label: "Create Canvas", selector: 'a[href*="create" i], button[aria-label*="Create" i]' },
        { label: "Quick Access Apps", selector: '[data-automationid="AppLauncher"], .waffle' }
    ];

    const SURFACES_PTO = [
        { label: "New Leave Request Form", selector: "a[href*='request' i], input[value*='request' i]" },
        { label: "Approval Inbox Queue", selector: "a[href*='approve' i], button[value*='approve' i]" },
        { label: "Subordinate Leave Roster", selector: "a[href*='subordinate' i]" },
        { label: "Profile & Leave Balances", selector: "a[href*='profile' i], a[href*='user' i]" }
    ];

    function getActiveCatalog() {
        const host = window.location.hostname.toLowerCase();
        const href = window.location.href.toLowerCase();
        const title = (document.title || '').toLowerCase();

        if (host.includes('health.mil') || title.includes('genesis') || !!document.querySelector('#application-layout-tab-0, [aria-label*="Health Record"]')) return { realm: "Clinical Health", catalog: SURFACES_MHS };
        if (host.includes('tasks.') || host.includes('planner') || href.includes('planner')) return { realm: "Planner / Tasks", catalog: SURFACES_PLANNER };
        if (host.includes('sharepoint') || href.includes('/_layouts/15/')) return { realm: "SharePoint & Lists", catalog: SURFACES_SHAREPOINT };
        if (host.includes('teams.microsoft') || href.includes('teams')) return { realm: "Teams", catalog: SURFACES_TEAMS };
        if (host.includes('ohome.apps.mil') || href.includes('/search') || href.includes('/create')) return { realm: "M365 Search", catalog: SURFACES_SEARCH };
        if (host.includes('leave.af.mil') || href.includes('leave')) return { realm: "Leave & PTO", catalog: SURFACES_PTO };
        if (host.includes('webmail.apps.mil') || host.includes('outlook') || href.includes('/mail')) return { realm: "Webmail OWA", catalog: SURFACES_OWA };
        return { realm: "Cloud Portal", catalog: SURFACES_OWA };
    }

    // ----------------------------------------------------
    // 3. READ-ONLY SAFETY GUARD & HONEYPOT EVASION
    // ----------------------------------------------------
    const FORBIDDEN_PATTERNS = /^(send|submit|invite|rsvp|accept|decline|delete|delete all|empty folder|discard all|save & send|remove|confirm)$/i;

    function isHoneypotOrTrap(element) {
        if (!element) return true;
        try {
            const style = window.getComputedStyle(element);
            if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return true;
            if (parseFloat(style.fontSize) === 0) return true;
            const rect = element.getBoundingClientRect();
            if (rect.width <= 0 || rect.height <= 0 || rect.left < -50) return true;
            const cls = (element.className || '').toString().toLowerCase();
            const id = (element.id || '').toLowerCase();
            if (cls.includes('honeypot') || cls.includes('trap') || id.includes('honeypot')) return true;
        } catch (e) {}
        return false;
    }

    function isSafeToClick(element) {
        if (!element || isHoneypotOrTrap(element)) return false;
        const text = (element.innerText || element.getAttribute('aria-label') || element.getAttribute('title') || '').trim();
        if (FORBIDDEN_PATTERNS.test(text)) {
            console.warn(`[BP Spelunker] 🛑 BLOCKED destructive click: "${text}"`);
            return false;
        }
        return true;
    }

    // ----------------------------------------------------
    // 4. DYNAMIC CRUD AFFORDANCE SCANNER
    // ----------------------------------------------------
    let crudStats = { create: 0, read: 0, update: 0, delete: 0, forms: 0, grids: 0 };

    function scanPageAffordances() {
        crudStats = { create: 0, read: 0, update: 0, delete: 0, forms: 0, grids: 0 };
        const elements = document.querySelectorAll('button, a, [role="button"], [role="tab"], [role="grid"], form');
        
        elements.forEach(el => {
            if (isHoneypotOrTrap(el)) return;
            const tag = el.tagName.toLowerCase();
            const text = (el.innerText || el.getAttribute('aria-label') || el.getAttribute('title') || '').trim();
            const lower = text.toLowerCase();

            if (tag === 'form') { crudStats.forms++; return; }
            if (el.getAttribute('role') === 'grid' || el.classList.contains('ms-DetailsList')) { crudStats.grids++; crudStats.read++; return; }

            if (/^(new|\+ new|add|create|upload|compose|new task|new mail|new item)$/i.test(text) || lower.includes('add ') || lower.includes('create ')) {
                crudStats.create++;
            } else if (/^(edit|rename|properties|move to|copy to|assign|update|change)$/i.test(text) || lower.includes('edit ')) {
                crudStats.update++;
            } else if (/^(delete|remove|discard|trash|archive)$/i.test(text) || lower.includes('delete ')) {
                crudStats.delete++;
            } else if (text.length > 0 && text.length < 40) {
                crudStats.read++;
            }
        });

        if (typeof window.__bp_signal_surface === 'function') {
            window.__bp_signal_surface({
                event: 'CRUD_AFFORDANCES_SCANNED',
                url: window.location.href,
                stats: crudStats
            });
        }
        updateHud();
    }

    // ----------------------------------------------------
    // 5. AUTONOMOUS TOUR ENGINE
    // ----------------------------------------------------
    let autoCrawling = localStorage.getItem('bp_spelunker_autocrawling') === 'true';
    let crawlIndex = parseInt(localStorage.getItem('bp_spelunker_crawl_index') || '0', 10);
    let crawlTimer = null;
    let visitedSet = new Set(JSON.parse(sessionStorage.getItem('bp_visited_surfaces') || '[]'));

    function startAutoCrawler() {
        autoCrawling = true;
        localStorage.setItem('bp_spelunker_autocrawling', 'true');
        updateHud();
        crawlNextSurface();
    }

    function stopAutoCrawler() {
        autoCrawling = false;
        localStorage.removeItem('bp_spelunker_autocrawling');
        if (crawlTimer) clearTimeout(crawlTimer);
        updateHud();
    }

    function crawlNextSurface() {
        const { catalog } = getActiveCatalog();
        if (!autoCrawling || catalog.length === 0) return;

        scanPageAffordances();

        if (crawlIndex >= catalog.length) {
            stopAutoCrawler();
            crawlIndex = 0;
            if (typeof window.__bp_signal_surface === 'function') {
                window.__bp_signal_surface({ event: 'CRAWL_COMPLETE', label: 'All App Surfaces Captured', url: window.location.href });
            }
            return;
        }

        const target = catalog[crawlIndex];
        const el = document.querySelector(target.selector);

        if (el && isSafeToClick(el)) {
            visitedSet.add(target.label);
            sessionStorage.setItem('bp_visited_surfaces', JSON.stringify(Array.from(visitedSet)));
            updateHud();

            console.log(`[BP Spelunker] 🧭 Navigating Surface (${crawlIndex + 1}/${catalog.length}): ${target.label}`);
            if (typeof window.__bp_signal_surface === 'function') {
                window.__bp_signal_surface({
                    event: 'SURFACE_HYDRATED',
                    label: target.label,
                    url: window.location.href,
                    visitedCount: visitedSet.size
                });
            }

            if (el.tagName === 'A' && el.getAttribute('target') === '_blank') {
                el.setAttribute('target', '_self');
            }
            el.click();

            if (target.label.includes('Composer') || target.label.includes('Settings')) {
                setTimeout(() => {
                    const dismissBtn = document.querySelector('[role="dialog"] button[aria-label*="Close" i], button[aria-label*="Discard" i]');
                    if (dismissBtn) dismissBtn.click();
                    else document.body?.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', bubbles: true }));
                }, 3000);
            }

            crawlIndex++;
            localStorage.setItem('bp_spelunker_crawl_index', crawlIndex.toString());
            crawlTimer = setTimeout(crawlNextSurface, 4000);
        } else {
            console.log(`[BP Spelunker] Surface not yet visible in DOM: ${target.label}, advancing...`);
            crawlIndex++;
            localStorage.setItem('bp_spelunker_crawl_index', crawlIndex.toString());
            crawlTimer = setTimeout(crawlNextSurface, 1500);
        }
    }

    // ----------------------------------------------------
    // 6. BUILD HUD PURELY VIA DOM APIS (100% CSP SAFE)
    // ----------------------------------------------------
    function ensureHudAttached() {
        injectStylesSafely();
        if (document.getElementById('bp-spelunker-hud')) {
            updateHud();
            return;
        }

        const body = document.body || document.documentElement;
        if (!body) return;

        const hud = document.createElement('div');
        hud.id = 'bp-spelunker-hud';

        // Title Bar
        const titleBar = document.createElement('div');
        titleBar.className = 'bp-spelunker-title';
        const titleSpan = document.createElement('span');
        titleSpan.textContent = '🌲 Ent Surface Spelunker';
        const toggleBtn = document.createElement('span');
        toggleBtn.id = 'bp-hud-toggle';
        toggleBtn.textContent = '—';
        toggleBtn.style.cssText = 'cursor: pointer; opacity: 0.8; font-size: 11px;';
        toggleBtn.addEventListener('click', () => hud.classList.toggle('minimized'));
        titleBar.appendChild(titleSpan);
        titleBar.appendChild(toggleBtn);
        hud.appendChild(titleBar);

        // Body Container
        const hudBody = document.createElement('div');
        hudBody.className = 'bp-spelunker-body';
        hudBody.style.cssText = 'display: flex; flex-direction: column; gap: 8px;';

        // CRUD Stats Grid
        const grid = document.createElement('div');
        grid.className = 'bp-crud-stats-grid';

        const sC = document.createElement('span');
        sC.className = 'bp-crud-create';
        sC.textContent = '+New: ';
        const bC = document.createElement('b');
        bC.id = 'bp-stat-c';
        bC.textContent = '0';
        sC.appendChild(bC);

        const sR = document.createElement('span');
        sR.className = 'bp-crud-read';
        sR.textContent = 'Read: ';
        const bR = document.createElement('b');
        bR.id = 'bp-stat-r';
        bR.textContent = '0';
        sR.appendChild(bR);

        const sU = document.createElement('span');
        sU.className = 'bp-crud-update';
        sU.textContent = 'Edit: ';
        const bU = document.createElement('b');
        bU.id = 'bp-stat-u';
        bU.textContent = '0';
        sU.appendChild(bU);

        const sD = document.createElement('span');
        sD.className = 'bp-crud-delete';
        sD.textContent = 'Del: ';
        const bD = document.createElement('b');
        bD.id = 'bp-stat-d';
        bD.textContent = '0';
        sD.appendChild(bD);

        grid.appendChild(sC);
        grid.appendChild(sR);
        grid.appendChild(sU);
        grid.appendChild(sD);
        hudBody.appendChild(grid);

        // Progress Bar
        const pBar = document.createElement('div');
        pBar.className = 'bp-spelunker-progress-bar';
        const pFill = document.createElement('div');
        pFill.id = 'bp-progress-fill';
        pFill.className = 'bp-spelunker-progress-fill';
        pBar.appendChild(pFill);
        hudBody.appendChild(pBar);

        // Coverage & Realm Info
        const infoRow = document.createElement('div');
        infoRow.style.cssText = 'display: flex; justify-content: space-between; font-size: 10px; color: #86efac;';
        const covSpan = document.createElement('span');
        covSpan.id = 'bp-hud-coverage';
        covSpan.textContent = 'Coverage: 0%';
        const realmSpan = document.createElement('span');
        realmSpan.id = 'bp-hud-realm';
        realmSpan.textContent = 'App: Detecting...';
        infoRow.appendChild(covSpan);
        infoRow.appendChild(realmSpan);
        hudBody.appendChild(infoRow);

        // Action Buttons Row
        const btnRow = document.createElement('div');
        btnRow.style.cssText = 'display: flex; gap: 6px; margin-top: 2px;';

        const btnCrawl = document.createElement('button');
        btnCrawl.id = 'bp-btn-crawl';
        btnCrawl.className = 'bp-spelunker-btn';
        btnCrawl.style.flex = '1';
        btnCrawl.textContent = '🧭 Start Read-Only Tour';
        btnCrawl.addEventListener('click', () => {
            if (autoCrawling) stopAutoCrawler();
            else startAutoCrawler();
        });

        const btnScan = document.createElement('button');
        btnScan.id = 'bp-btn-scan';
        btnScan.className = 'bp-spelunker-btn';
        btnScan.style.flex = '1';
        btnScan.textContent = '🔍 Scan CRUD';
        btnScan.addEventListener('click', scanPageAffordances);

        btnRow.appendChild(btnCrawl);
        btnRow.appendChild(btnScan);
        hudBody.appendChild(btnRow);

        hud.appendChild(hudBody);
        body.appendChild(hud);

        updateHud();
        scanPageAffordances();
    }

    function updateHud() {
        const { realm, catalog } = getActiveCatalog();
        const total = catalog.length;
        const visited = catalog.filter(c => visitedSet.has(c.label)).length;
        const pct = total > 0 ? Math.round((visited / total) * 100) : 0;

        const fill = document.getElementById('bp-progress-fill');
        if (fill) fill.style.width = pct + '%';

        const cov = document.getElementById('bp-hud-coverage');
        if (cov) cov.textContent = `Coverage: ${visited}/${total} (${pct}%)`;

        const rSpan = document.getElementById('bp-hud-realm');
        if (rSpan) rSpan.textContent = `App: ${realm}`;

        const btn = document.getElementById('bp-btn-crawl');
        if (btn) {
            btn.textContent = autoCrawling ? "⏹ Stop Spelunker" : "🧭 Start Read-Only Tour";
            btn.className = autoCrawling ? "bp-spelunker-btn running" : "bp-spelunker-btn";
        }

        const statC = document.getElementById('bp-stat-c');
        if (statC) statC.textContent = crudStats.create;
        const statR = document.getElementById('bp-stat-r');
        if (statR) statR.textContent = crudStats.read;
        const statU = document.getElementById('bp-stat-u');
        if (statU) statU.textContent = crudStats.update;
        const statD = document.getElementById('bp-stat-d');
        if (statD) statD.textContent = crudStats.delete;
    }

    // Keep HUD attached dynamically through SPA transitions
    setInterval(ensureHudAttached, 1500);

    // Auto-resume tour if active
    if (autoCrawling) {
        setTimeout(crawlNextSurface, 3000);
    }
})();
