#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2025 Hyperpolymath Contributors
set -euo pipefail

SCHEMA="${1:-schemas/sensors.bop}"
OUTDIR="${2:-implementations/zig/generated}"

if ! command -v bebopc >/dev/null 2>&1; then
  echo "bebopc not found on PATH. Install Bebop compiler or point to it explicitly." >&2
  exit 1
fi

mkdir -p "$OUTDIR"
bebopc "$SCHEMA" --lang c --out "$OUTDIR"
echo "Generated C bindings into $OUTDIR"
