#!/usr/bin/env bash
# ====================================================================
# BROWSERPARITY - FRESH MACHINE PROVISIONING (macOS / Linux)
# ====================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

echo "===================================================================="
echo "    🚀 BROWSERPARITY: FRESH WORKSTATION ONBOARDING (${OS})"
echo "===================================================================="

# 1. Install prerequisites (git, gh, pwsh, browsers)
if [ "$OS" = "Darwin" ]; then
    echo "[1/4] Checking macOS Homebrew & tools..."
    if ! command -v brew &> /dev/null; then
        echo "[+] Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install git gh powershell
    echo "[+] Installing browsers via Homebrew Casks..."
    brew install --cask opera microsoft-edge firefox google-chrome || true
elif [ "$OS" = "Linux" ]; then
    echo "[1/4] Checking Linux package manager & tools..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y git gh curl wget
        if ! command -v pwsh &> /dev/null; then
            sudo snap install powershell --classic || sudo apt-get install -y powershell || true
        fi
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y git gh curl wget powershell
    fi
fi

# 2. Delegate to PowerShell bootstrap engine
exec pwsh "${SCRIPT_DIR}/bootstrap-new-box.ps1" "$@"