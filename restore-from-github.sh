#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec pwsh "${SCRIPT_DIR}/restore-from-github.ps1" "$@"