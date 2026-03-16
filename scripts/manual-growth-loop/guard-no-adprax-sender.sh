#!/usr/bin/env bash
set -euo pipefail

# guard-no-adprax-sender.sh
# Purpose: hard stop if ANY outbound-email sender identity in this workspace
# (env vars or explicit arguments) is using the Adprax domain.
#
# Context: Jabbit and Adprax are different apps. Jabbit outbound must never
# send using Adprax branding/senders/domains.
#
# Usage:
#   bash scripts/manual-growth-loop/guard-no-adprax-sender.sh
#   bash scripts/manual-growth-loop/guard-no-adprax-sender.sh "Jon <jon@jabbitapp.com>"

ADPRAX_DOMAIN_REGEX='(^|[^A-Za-z0-9_.-])adprax\.com([^A-Za-z0-9_.-]|$)'

check_value() {
  local label="$1"
  local value="${2:-}"

  if [ -z "$value" ]; then
    return 0
  fi

  # Case-insensitive domain match.
  if echo "$value" | tr '[:upper:]' '[:lower:]' | grep -Eq "$ADPRAX_DOMAIN_REGEX"; then
    echo "ERR: outbound sender is using blocked Adprax domain (${label}=${value})" >&2
    echo "     Fix: use a Jabbit-owned sender (e.g. @jabbitapp.com)." >&2
    return 42
  fi
}

# 1) Check explicit arguments (if provided)
for arg in "$@"; do
  check_value "arg" "$arg" || exit $?
done

# 2) Check common env vars (present or future)
for k in \
  JABBIT_OUTBOUND_FROM \
  RESEND_FROM \
  RESEND_FROM_EMAIL \
  FROM_EMAIL \
  DEFAULT_FROM \
  OUTBOUND_FROM \
  EMAIL_FROM \
; do
  # shellcheck disable=SC2154
  v="${!k:-}"
  check_value "$k" "$v" || exit $?
done

exit 0
