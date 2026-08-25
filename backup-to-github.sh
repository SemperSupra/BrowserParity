#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec pwsh "${SCRIPT_DIR}/backup-to-github.ps1" "$@"