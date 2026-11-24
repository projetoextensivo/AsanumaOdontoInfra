#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APP_RUNTIME_DIR="${APP_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}/asanumaodonto-infra-${UID}}"
if [[ -n "${APP_ROOT:-}" ]]; then
  APP_ROOT="$(cd -- "$APP_ROOT" && pwd)"
elif [[ -f "$APP_RUNTIME_DIR/app_root" ]]; then
  APP_ROOT="$(cat "$APP_RUNTIME_DIR/app_root")"
else
  APP_ROOT="$(cd -- "$INFRA_DIR/.." && pwd)"
fi
PORT="${PORT:-$(cat "$APP_RUNTIME_DIR/backend.port" 2>/dev/null || printf '8080')}"
VITE_PORT="${VITE_PORT:-$(cat "$APP_RUNTIME_DIR/frontend.port" 2>/dev/null || printf '5173')}"
INTERVAL="${INTERVAL:-5}"

process_state() {
  local pid
  pid="$(cat "$APP_RUNTIME_DIR/$1.pid" 2>/dev/null || true)"
  if [[ -n "$pid" ]] && kill -0 -- "-$pid" 2>/dev/null; then printf 'ativo (PID %s)' "$pid"; else printf 'parado'; fi
}
http_state() {
  local url="$1" code
  code="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time 3 "$url" 2>/dev/null || true)"
  if [[ "$code" =~ ^2[0-9][0-9]$ ]]; then printf 'HTTP %s' "$code"; else printf 'indisponível'; fi
}

printf 'Monitorando Asanuma Odonto em %s (Ctrl+C para sair; a aplicação continuará rodando).\n' "$APP_ROOT"
trap 'printf "\nMonitoramento encerrado. A aplicação não foi parada.\n"; exit 0' INT TERM
while true; do
  printf '[%s] Backend: processo %s, %s | Frontend: processo %s, %s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "$(process_state backend)" "$(http_state "http://127.0.0.1:${PORT}/api/health")" \
    "$(process_state frontend)" "$(http_state "http://127.0.0.1:${VITE_PORT}/")"
  sleep "$INTERVAL"
done
