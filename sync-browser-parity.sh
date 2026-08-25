#!/usr/bin/env bash
# ====================================================================
# BROWSERPARITY - CROSS-PLATFORM (macOS / Linux / WSL)
# ====================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure PowerShell Core (pwsh) is available
if ! command -v pwsh &> /dev/null; then
    echo "[!] PowerShell Core (pwsh) is required to run BrowserParity."
    OS="$(uname -s)"
    if [ "$OS" = "Darwin" ]; then
        echo "[+] Detected macOS. Installing PowerShell via Homebrew..."
        brew install powershell
    elif [ "$OS" = "Linux" ]; then
        echo "[+] Detected Linux. Installing PowerShell..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y powershell || sudo snap install powershell --classic
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y powershell
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm powershell-bin || sudo pacman -S --noconfirm powershell
        fi
    fi
fi

exec pwsh "${SCRIPT_DIR}/sync-browser-parity.ps1" "$@"