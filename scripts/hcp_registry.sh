# Shared helpers for talking to the HCP Vagrant Registry API from CI.
# Meant to be sourced (not executed) from workflow steps that already set
# `set -euo pipefail` and export ACCESS_TOKEN.

HCP_TMP_BODY="$(mktemp)"
trap 'rm -f "$HCP_TMP_BODY"' EXIT

# hcp_api METHOD URL [JSON_DATA]
# Prints the HTTP status code to stdout; leaves the response body in
# $HCP_TMP_BODY. Retries only on connection failures/timeouts/408/429/5xx
# (curl's default --retry behavior never retries a completed 4xx response).
hcp_api() {
  local method="$1" url="$2" data="${3:-}"
  local args=(
    --silent --show-error
    --output "$HCP_TMP_BODY"
    --write-out '%{http_code}'
    --retry 2 --retry-delay 2
    --request "$method"
    --header "Authorization: Bearer $ACCESS_TOKEN"
  )
  if [[ -n "$data" ]]; then
    args+=(--header "Content-Type: application/json" --data "$data")
  fi
  curl "${args[@]}" --url "$url"
}

# require_success HTTP_CODE CONTEXT
# Fails loudly with the captured response body if HTTP_CODE is not 2xx.
require_success() {
  local code="$1" context="$2"
  if (( code < 200 || code >= 300 )); then
    echo "::error::${context} failed (HTTP ${code})"
    echo "Response body:"
    cat "$HCP_TMP_BODY"
    exit 1
  fi
}
