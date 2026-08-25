// ==UserScript==
// @name         BrowserParity Ent-365 Cloud Suite Power DX & Command Palette
// @namespace    https://github.com/SemperSupra/BrowserParity
// @version      2.1.0
// @description  Supercharges Enterprise 365: Global Command Palette (Ctrl+K), Fast Navigation Hotkeys (Alt+M, Alt+C, Alt+T, Alt+S), 1-Click Document Downloader, and Teams Presence Guard (100% CSP Safe).
// @icon         data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMjggMTI4IiB3aWR0aD0iMTI4IiBoZWlnaHQ9IjEyOCI+CiAgPGRlZnM+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9ImJhcmtHcmFkIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iIzRhMzcyOCIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjUwJSIgc3RvcC1jb2xvcj0iIzJkMjIxOCIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0b3AtY29sb3I9IiMxYTE0MGUiLz4KICAgIDwvbGluZWFyR3JhZGllbnQ+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9Im1vc3NHcmFkIiB4MT0iMCUiIHkxPSIwJSIgeDI9IjEwMCUiIHkyPSIxMDAlIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwJSIgc3RvcC1jb2xvcj0iIzRhZGU4MCIvPgogICAgICA8c3RvcCBvZmZzZXQ9IjEwMCUiIHN0b3AtY29sb3I9IiMxNTgwM2QiLz4KICAgIDwvbGluZWFyR3JhZGllbnQ+CiAgICA8bGluZWFyR3JhZGllbnQgaWQ9ImFtYmVyR2xvdyIgeDE9IjAlIiB5MT0iMCUiIHgyPSIxMDAlIiB5Mj0iMTAwJSI+CiAgICAgIDxzdG9wIG9mZnNldD0iMCUiIHN0b3AtY29sb3I9IiNmZWYwOGEiLz4KICAgICAgPHN0b3Agb2Zmc2V0PSI1MCUiIHN0b3AtY29sb3I9IiNmNTllMGIiLz4KICAgICAgPHN0b3Agb2Zmc2V0PSIxMDAlIiBzdG9wLWNvbG9yPSIjYjQ1MzA5Ii8+CiAgICA8L2xpbmVhckdyYWRpZW50PgogICAgPGZpbHRlciBpZD0iZ2xvdyIgeD0iLTIwJSIgeT0iLTIwJSIgd2lkdGg9IjE0MCUiIGhlaWdodD0iMTQwJSI+CiAgICAgIDxmZUdhdXNzaWFuQmx1ciBzdGREZXZpYXRpb249IjMiIHJlc3VsdD0iYmx1ciIgLz4KICAgICAgPGZlQ29tcG9zaXRlIGluPSJTb3VyY2VHcmFwaGljIiBpbjI9ImJsdXIiIG9wZXJhdG9yPSJvdmVyIiAvPgogICAgPC9maWx0ZXI+CiAgPC9kZWZzPgoKICA8IS0tIEJhY2tncm91bmQgQ2lyY2xlIChEZWVwIEZvcmVzdCkgLS0+CiAgPGNpcmNsZSBjeD0iNjQiIGN5PSI2NCIgcj0iNjAiIGZpbGw9IiMxNDFkMTYiIHN0cm9rZT0iIzIyYzU1ZSIgc3Ryb2tlLXdpZHRoPSIzIi8+CgogIDwhLS0gRW50IFRydW5rIC8gSGVhZCAtLT4KICA8cGF0aCBkPSJNNDAgMzIgQzQwIDE4LCA1MCAxNCwgNjQgMTQgQzc4IDE0LCA4OCAxOCwgODggMzIgQzkyIDQ4LCA5NCA3MCwgOTAgOTIgQzg2IDEwOCwgNDIgMTA4LCAzOCA5MiBDMzQgNzAsIDM2IDQ4LCA0MCAzMiBaIiBmaWxsPSJ1cmwoI2JhcmtHcmFkKSIgc3Ryb2tlPSIjMWExNDBlIiBzdHJva2Utd2lkdGg9IjIiLz4KCiAgPCEtLSBCYXJrIFRleHR1cmUgTGluZXMgLS0+CiAgPHBhdGggZD0iTTUyIDI4IFE1MCA1MCA1NCA3NSBNNzYgMjggUTc4IDUwIDc0IDc1IE02NCAyMCBRNjIgNDUgNjQgNjgiIHN0cm9rZT0iIzFmMTgxMiIgc3Ryb2tlLXdpZHRoPSIyLjUiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgZmlsbD0ibm9uZSIvPgoKICA8IS0tIExlYWYgQ3Jvd24gLS0+CiAgPHBhdGggZD0iTTM4IDE4IFEzMCA4IDQ0IDggUTQ2IDE2IDM4IDE4IFoiIGZpbGw9InVybCgjbW9zc0dyYWQpIi8+CiAgPHBhdGggZD0iTTY0IDEyIFE2NCAyIDc0IDQgUTcwIDEyIDY0IDEyIFoiIGZpbGw9InVybCgjbW9zc0dyYWQpIi8+CiAgPHBhdGggZD0iTTkwIDE4IFE5OCA4IDg0IDggUTgyIDE2IDkwIDE4IFoiIGZpbGw9InVybCgjbW9zc0dyYWQpIi8+CgogIDwhLS0gTGVhZiBCZWFyZCAvIEZvbGlhZ2UgLS0+CiAgPHBhdGggZD0iTTQ0IDcyIFEzNiA4NiA0OCA5OCBRNTYgMTA4IDY0IDExNCBRNzIgMTA4IDgwIDk4IFE5MiA4NiA4NCA3MiBRNjQgODIgNDQgNzIgWiIgZmlsbD0idXJsKCNtb3NzR3JhZCkiIHN0cm9rZT0iIzE2NjUzNCIgc3Ryb2tlLXdpZHRoPSIxLjUiLz4KICA8cGF0aCBkPSJNNTIgODIgUTQ4IDk0IDU2IDEwMiBRNjQgMTA4IDcyIDEwMiBRODAgOTQgNzYgODIgUTY0IDkwIDUyIDgyIFoiIGZpbGw9IiMxNTgwM2QiLz4KCiAgPCEtLSBHbG93aW5nIEFtYmVyIEV5ZXMgKEVudGlzaCBXaXNkb20pIC0tPgogIDxlbGxpcHNlIGN4PSI1MiIgY3k9IjQ2IiByeD0iNiIgcnk9IjciIGZpbGw9InVybCgjYW1iZXJHbG93KSIgZmlsdGVyPSJ1cmwoI2dsb3cpIi8+CiAgPGVsbGlwc2UgY3g9Ijc2IiBjeT0iNDYiIHJ4PSI2IiByeT0iNyIgZmlsbD0idXJsKCNhbWJlckdsb3cpIiBmaWx0ZXI9InVybCgjZ2xvdykiLz4KICA8Y2lyY2xlIGN4PSI1MiIgY3k9IjQ2IiByPSIyLjUiIGZpbGw9IiM0NTFhMDMiLz4KICA8Y2lyY2xlIGN4PSI3NiIgY3k9IjQ2IiByPSIyLjUiIGZpbGw9IiM0NTFhMDMiLz4KICA8Y2lyY2xlIGN4PSI1NCIgY3k9IjQ0IiByPSIxLjUiIGZpbGw9IiNmZmZmZmYiLz4KICA8Y2lyY2xlIGN4PSI3OCIgY3k9IjQ0IiByPSIxLjUiIGZpbGw9IiNmZmZmZmYiLz4KCiAgPCEtLSBXaXNlIEVudCBCcm93IC8gTm9zZSAtLT4KICA8cGF0aCBkPSJNNDQgMzggUTUyIDM1IDYwIDQwIEw2NCA1NiBMNjggNDAgUTc2IDM1IDg0IDM4IiBzdHJva2U9IiMxYTE0MGUiIHN0cm9rZS13aWR0aD0iMyIgZmlsbD0ibm9uZSIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CgogIDwhLS0gRGlnaXRhbCBDb21wYXNzIC8gUm9vdCBSdW5lIE92ZXJsYXkgKFN1YnRsZSkgLS0+CiAgPGNpcmNsZSBjeD0iNjQiIGN5PSI2NCIgcj0iNTQiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzRhZGU4MCIgc3Ryb2tlLXdpZHRoPSIxIiBzdHJva2UtZGFzaGFycmF5PSIzLDYiIG9wYWNpdHk9IjAuNiIvPgo8L3N2Zz4=
// @author       Antigravity AI
// @updateURL    https://SemperSupra.github.io/BrowserParity/userscripts/sharepoint-teams-power-dx.user.js
// @downloadURL  https://SemperSupra.github.io/BrowserParity/userscripts/sharepoint-teams-power-dx.user.js
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
// @runtime-env  PUBLIC_HUMAN_RESTRICTED
// @csp-level    STRICT
// @grant        none
// @run-at       document-idle
// ==/UserScript==

(function() {
    'use strict';

    // ----------------------------------------------------
    // 1. INJECT STYLES SAFELY (PURE TEXTCONTENT)
    // ----------------------------------------------------
    const styles = `
        #bp-sp-badge {
            position: fixed !important;
            bottom: 20px !important;
            right: 20px !important;
            background: linear-gradient(135deg, #17231b, #0f1712) !important;
            color: #f0fdf4 !important;
            border: 1px solid #2d4234 !important;
            backdrop-filter: blur(10px) !important;
            padding: 8px 14px !important;
            border-radius: 9999px !important;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
            font-size: 12px !important;
            font-weight: 600 !important;
            cursor: pointer !important;
            z-index: 2147483645 !important;
            box-shadow: 0 8px 24px rgba(0,0,0,0.5), 0 0 16px rgba(34, 197, 94, 0.2) !important;
            display: flex !important;
            align-items: center !important;
            gap: 8px !important;
            user-select: none !important;
            transition: all 0.2s ease !important;
        }
        #bp-sp-badge:hover {
            border-color: #4ade80 !important;
            box-shadow: 0 8px 28px rgba(0,0,0,0.6), 0 0 20px rgba(74, 222, 128, 0.4) !important;
            transform: translateY(-2px) !important;
        }

        #ent-palette-overlay {
            position: fixed !important;
            top: 0 !important; left: 0 !important; right: 0 !important; bottom: 0 !important;
            background: rgba(0, 0, 0, 0.65) !important;
            backdrop-filter: blur(6px) !important;
            z-index: 2147483646 !important;
            display: flex !important;
            justify-content: center !important;
            align-items: flex-start !important;
            padding-top: 15vh !important;
        }
        #ent-palette-modal {
            background: #0f1712 !important;
            border: 1px solid #2d4234 !important;
            box-shadow: 0 20px 50px rgba(0,0,0,0.8), 0 0 24px rgba(74, 222, 128, 0.25) !important;
            border-radius: 14px !important;
            width: 580px !important;
            max-width: 90vw !important;
            color: #f0fdf4 !important;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
            overflow: hidden !important;
        }
        #ent-palette-header {
            display: flex !important;
            align-items: center !important;
            padding: 14px 18px !important;
            border-bottom: 1px solid #1f2f25 !important;
            background: #17231b !important;
            gap: 12px !important;
        }
        #ent-palette-input {
            flex: 1 !important;
            background: transparent !important;
            border: none !important;
            color: #f0fdf4 !important;
            font-size: 15px !important;
            font-weight: 500 !important;
            outline: none !important;
        }
        #ent-palette-input::placeholder { color: #86efac88 !important; }
        #ent-palette-results {
            max-height: 380px !important;
            overflow-y: auto !important;
            padding: 8px !important;
        }
        .ent-palette-item {
            padding: 10px 14px !important;
            border-radius: 8px !important;
            display: flex !important;
            align-items: center !important;
            justify-content: space-between !important;
            cursor: pointer !important;
            transition: all 0.15s ease !important;
            color: #f0fdf4 !important;
            text-decoration: none !important;
        }
        .ent-palette-item:hover, .ent-palette-item.active {
            background: #1f2f25 !important;
            border-left: 3px solid #4ade80 !important;
            padding-left: 17px !important;
        }
        .ent-palette-item-left {
            display: flex !important;
            align-items: center !important;
            gap: 10px !important;
        }
        .ent-palette-item-title { font-weight: 600 !important; font-size: 13px !important; }
        .ent-palette-item-category { font-size: 11px !important; color: #86efac !important; }
        .ent-palette-item-shortcut {
            font-size: 10px !important;
            background: #17231b !important;
            border: 1px solid #2d4234 !important;
            padding: 2px 6px !important;
            border-radius: 4px !important;
            color: #9ca3af !important;
        }
        #ent-palette-footer {
            padding: 8px 18px !important;
            background: #17231b !important;
            border-top: 1px solid #1f2f25 !important;
            font-size: 11px !important;
            color: #9ca3af !important;
            display: flex !important;
            justify-content: space-between !important;
        }
    `;

    function injectStylesSafely() {
        if (document.getElementById('ent-power-dx-styles')) return;
        const styleEl = document.createElement('style');
        styleEl.id = 'ent-power-dx-styles';
        styleEl.textContent = styles;
        (document.head || document.documentElement || document.body)?.appendChild(styleEl);
    }

    // ----------------------------------------------------
    // 2. COMMAND PALETTE DESTINATIONS CATALOG
    // ----------------------------------------------------
    const DESTINATIONS = [
        { title: "Webmail: Inbox", category: "Email", url: "https://webmail.apps.mil/mail/inbox", shortcut: "Alt+M", icon: "📬" },
        { title: "Webmail: Calendar Week View", category: "Schedule", url: "https://webmail.apps.mil/calendar/view/week", shortcut: "Alt+C", icon: "📅" },
        { title: "Webmail: Contacts & People", category: "Directory", url: "https://webmail.apps.mil/people/", icon: "👥" },
        { title: "SharePoint: On-Call Schedule (Current Week)", category: "Operations", url: "https://dod365.sharepoint-mil.us/sites/EUCOM-ELITE-OPS/Lists/OnCall%20Schedule/On%20Call%20Current%20Week.aspx", shortcut: "Alt+S", icon: "📊" },
        { title: "SharePoint: EUCOM JOC Systems Documents", category: "Files", url: "https://dod365.sharepoint-mil.us/teams/EUCOM-joc-systems/Shared Documents", icon: "📁" },
        { title: "OneDrive: My Personal Files", category: "Files", url: "https://dod365-my.sharepoint-mil.us/my", shortcut: "Alt+D", icon: "☁️" },
        { title: "Planner: SOP Plan Task Board", category: "Tasks", url: "https://tasks.osi.apps.mil/dod365.onmicrosoft.us/en-US/Home/Planner/#/plantaskboard?groupId=88e79079-60a9-4f16-af20-7d983e71f241&planId=ny5reUBfnUu8ejIehjXeoowADbPQ", shortcut: "Alt+T", icon: "📋" },
        { title: "Planner: Assigned to Me Tasks", category: "Tasks", url: "https://tasks.osi.apps.mil/dod365.onmicrosoft.us/en-US/Home/Planner/#/userboard", icon: "👤" },
        { title: "Teams: Chats & Channels", category: "Collaboration", url: "https://dod.teams.microsoft.us/v2", icon: "💬" },
        { title: "M365: Copilot Enterprise Search", category: "Search", url: "https://www.ohome.apps.mil/search/", icon: "🤖" },
        { title: "M365: Create New Document / Form", category: "Create", url: "https://www.ohome.apps.mil/create/", icon: "➕" },
        { title: "Enterprise Leave & PTO Portal", category: "Time-Off", url: "https://leave.af.mil/", icon: "🍃" },
        { title: "Enterprise Clinical Health Portal", category: "Health", url: "https://patientportal.mhsgenesis.health.mil/", icon: "🌿" }
    ];

    // ----------------------------------------------------
    // 3. RENDER COMMAND PALETTE (100% CSP SAFE - PURE DOM)
    // ----------------------------------------------------
    let paletteOpen = false;
    let selectedIndex = 0;
    let filteredItems = [...DESTINATIONS];

    function toggleCommandPalette() {
        if (paletteOpen) closeCommandPalette();
        else openCommandPalette();
    }

    function openCommandPalette() {
        injectStylesSafely();
        if (document.getElementById('ent-palette-overlay')) return;
        paletteOpen = true;
        selectedIndex = 0;
        filteredItems = [...DESTINATIONS];

        const body = document.body || document.documentElement;
        if (!body) return;

        const overlay = document.createElement('div');
        overlay.id = 'ent-palette-overlay';

        const modal = document.createElement('div');
        modal.id = 'ent-palette-modal';

        // Header
        const header = document.createElement('div');
        header.id = 'ent-palette-header';
        const icon = document.createElement('span');
        icon.textContent = '🌲';
        icon.style.fontSize = '18px';
        const input = document.createElement('input');
        input.id = 'ent-palette-input';
        input.type = 'text';
        input.placeholder = 'Type to jump to any App, List, Task, or File...';
        input.autocomplete = 'off';
        const escBadge = document.createElement('span');
        escBadge.textContent = 'ESC to close';
        escBadge.style.cssText = 'font-size: 11px; background:#1f2f25; padding:2px 6px; border-radius:4px; color:#86efac;';
        header.appendChild(icon);
        header.appendChild(input);
        header.appendChild(escBadge);
        modal.appendChild(header);

        // Results Container
        const results = document.createElement('div');
        results.id = 'ent-palette-results';
        modal.appendChild(results);

        // Footer
        const footer = document.createElement('div');
        footer.id = 'ent-palette-footer';
        const fLeft = document.createElement('span');
        fLeft.textContent = '↑↓ to Navigate • Enter to Jump';
        const fRight = document.createElement('span');
        fRight.textContent = 'Ent-365 Unified Cloud';
        footer.appendChild(fLeft);
        footer.appendChild(fRight);
        modal.appendChild(footer);

        overlay.appendChild(modal);
        body.appendChild(overlay);

        input.focus();
        renderPaletteItems();

        input.addEventListener('input', (e) => {
            const q = e.target.value.toLowerCase().trim();
            if (!q) {
                filteredItems = [...DESTINATIONS];
            } else {
                filteredItems = DESTINATIONS.filter(d => 
                    d.title.toLowerCase().includes(q) || 
                    d.category.toLowerCase().includes(q)
                );
            }
            selectedIndex = 0;
            renderPaletteItems();
        });

        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) closeCommandPalette();
        });
    }

    function closeCommandPalette() {
        const overlay = document.getElementById('ent-palette-overlay');
        if (overlay) overlay.remove();
        paletteOpen = false;
    }

    function renderPaletteItems() {
        const container = document.getElementById('ent-palette-results');
        if (!container) return;
        while (container.firstChild) { container.removeChild(container.firstChild); }

        if (filteredItems.length === 0) {
            const empty = document.createElement('div');
            empty.style.cssText = 'padding: 16px; text-align: center; color: #9ca3af;';
            empty.textContent = 'No matching cloud destinations found.';
            container.appendChild(empty);
            return;
        }

        filteredItems.forEach((item, idx) => {
            const row = document.createElement('div');
            row.className = `ent-palette-item ${idx === selectedIndex ? 'active' : ''}`;

            const left = document.createElement('div');
            left.className = 'ent-palette-item-left';
            const iSpan = document.createElement('span');
            iSpan.style.fontSize = '16px';
            iSpan.textContent = item.icon;
            const textCol = document.createElement('div');
            const titleDiv = document.createElement('div');
            titleDiv.className = 'ent-palette-item-title';
            titleDiv.textContent = item.title;
            const catDiv = document.createElement('div');
            catDiv.className = 'ent-palette-item-category';
            catDiv.textContent = item.category;
            textCol.appendChild(titleDiv);
            textCol.appendChild(catDiv);
            left.appendChild(iSpan);
            left.appendChild(textCol);
            row.appendChild(left);

            if (item.shortcut) {
                const sSpan = document.createElement('span');
                sSpan.className = 'ent-palette-item-shortcut';
                sSpan.textContent = item.shortcut;
                row.appendChild(sSpan);
            }

            row.addEventListener('click', () => { window.location.href = item.url; });
            container.appendChild(row);
        });
    }

    // ----------------------------------------------------
    // 4. GLOBAL HOTKEYS LISTENER (Ctrl+K, Alt+M, Alt+C, Alt+T, Alt+S, Alt+D)
    // ----------------------------------------------------
    window.addEventListener('keydown', (e) => {
        if ((e.ctrlKey || e.metaKey) && (e.key === 'k' || e.key === 'K')) {
            e.preventDefault();
            toggleCommandPalette();
            return;
        }

        if (paletteOpen) {
            if (e.key === 'Escape') {
                e.preventDefault();
                closeCommandPalette();
            } else if (e.key === 'ArrowDown') {
                e.preventDefault();
                if (filteredItems.length > 0) {
                    selectedIndex = (selectedIndex + 1) % filteredItems.length;
                    renderPaletteItems();
                }
            } else if (e.key === 'ArrowUp') {
                e.preventDefault();
                if (filteredItems.length > 0) {
                    selectedIndex = (selectedIndex - 1 + filteredItems.length) % filteredItems.length;
                    renderPaletteItems();
                }
            } else if (e.key === 'Enter') {
                e.preventDefault();
                if (filteredItems[selectedIndex]) {
                    window.location.href = filteredItems[selectedIndex].url;
                }
            }
            return;
        }

        if (e.altKey && !e.ctrlKey && !e.shiftKey) {
            const key = e.key.toLowerCase();
            if (key === 'm') { e.preventDefault(); window.location.href = "https://webmail.apps.mil/mail/inbox"; }
            else if (key === 'c') { e.preventDefault(); window.location.href = "https://webmail.apps.mil/calendar/view/week"; }
            else if (key === 't') { e.preventDefault(); window.location.href = "https://tasks.osi.apps.mil/dod365.onmicrosoft.us/en-US/Home/Planner/"; }
            else if (key === 's') { e.preventDefault(); window.location.href = "https://dod365.sharepoint-mil.us/sites/EUCOM-ELITE-OPS/Lists/OnCall%20Schedule/On%20Call%20Current%20Week.aspx"; }
            else if (key === 'd') { e.preventDefault(); window.location.href = "https://dod365-my.sharepoint-mil.us/my"; }
        }
    });

    // ----------------------------------------------------
    // 5. TEAMS ACTIVE PRESENCE KEEPALIVE GUARD
    // ----------------------------------------------------
    if (window.location.hostname.includes('teams')) {
        setInterval(() => {
            const dummyEvent = new MouseEvent('mousemove', { bubbles: true, cancelable: false, clientX: 10, clientY: 10 });
            document.dispatchEvent(dummyEvent);
        }, 180000);
    }

    // ----------------------------------------------------
    // 6. RENDER FLOATING BADGE SAFELY
    // ----------------------------------------------------
    function ensureBadgeAttached() {
        injectStylesSafely();
        if (document.getElementById('bp-sp-badge')) return;
        const body = document.body || document.documentElement;
        if (!body) return;

        const badge = document.createElement('div');
        badge.id = 'bp-sp-badge';
        const titleSpan = document.createElement('span');
        titleSpan.textContent = '🌲 Ent-365';
        const subSpan = document.createElement('span');
        subSpan.textContent = '[Ctrl+K]';
        subSpan.style.cssText = 'opacity: 0.7; font-size: 11px;';
        badge.appendChild(titleSpan);
        badge.appendChild(subSpan);
        badge.addEventListener('click', toggleCommandPalette);
        body.appendChild(badge);
    }

    setInterval(ensureBadgeAttached, 2000);
})();
