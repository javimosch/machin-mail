#!/usr/bin/env bash
# Build machin-mail into one native binary. Needs machin v0.80.0+ and a C compiler.
set -euo pipefail
cd "$(dirname "$0")"
MACHIN="${MACHIN:-machin}"
"$MACHIN" encode src/machweb.src src/smtp.src src/mail.src > mail.mfl
"$MACHIN" build mail.mfl -o machin-mail
echo "built ./machin-mail"
