#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APP_RUNTIME_DIR="${APP_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}/asanumaodonto-infra-${UID}}"
mkdir -p "$APP_RUNTIME_DIR"
chmod 700 "$APP_RUNTIME_DIR"

if [[ -n "${APP_ROOT:-}" ]]; then
  APP_ROOT="$(cd -- "$APP_ROOT" && pwd)"
elif [[ -f "$APP_RUNTIME_DIR/app_root" ]]; then
  APP_ROOT="$(cat "$APP_RUNTIME_DIR/app_root")"
else
  APP_ROOT="$(cd -- "$INFRA_DIR/.." && pwd)"
fi

fail() { printf 'Erro: %s\n' "$*" >&2; exit 1; }
is_group_running() { [[ -n "${1:-}" ]] && kill -0 -- "-$1" 2>/dev/null; }

[[ -f "$APP_ROOT/backend/pom.xml" ]] || fail "Não encontrei backend/pom.xml em $APP_ROOT. Defina APP_ROOT para a raiz do projeto."
[[ -f "$APP_ROOT/frontend/package.json" ]] || fail "Não encontrei frontend/package.json em $APP_ROOT."
[[ -x "$APP_ROOT/frontend/node_modules/.bin/vite" ]] || fail "Dependências do frontend ausentes. Execute 'npm ci' em $APP_ROOT/frontend."

for command_name in mvn java node setsid curl; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Comando obrigatório não encontrado: $command_name."
done

PORT="${PORT:-8080}"
VITE_PORT="${VITE_PORT:-5173}"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-90}"
export PORT
export API_PROXY_TARGET="${API_PROXY_TARGET:-http://127.0.0.1:${PORT}}"

backend_pid="$(cat "$APP_RUNTIME_DIR/backend.pid" 2>/dev/null || true)"
frontend_pid="$(cat "$APP_RUNTIME_DIR/frontend.pid" 2>/dev/null || true)"
if is_group_running "$backend_pid" && is_group_running "$frontend_pid"; then
  printf 'Asanuma Odonto já está em execução.\n'
  printf 'Frontend: http://localhost:%s\n' "$VITE_PORT"
  printf 'Logs: %s\n' "$APP_RUNTIME_DIR"
  exit 0
fi
if is_group_running "$backend_pid" || is_group_running "$frontend_pid"; then
  fail "Foi detectada uma execução parcial. Use infra/scripts/stop.sh e tente novamente."
fi

printf '%s\n' "$APP_ROOT" > "$APP_RUNTIME_DIR/app_root"
printf '%s\n' "$PORT" > "$APP_RUNTIME_DIR/backend.port"
printf '%s\n' "$VITE_PORT" > "$APP_RUNTIME_DIR/frontend.port"

setsid bash -c 'cd -- "$1" && exec mvn spring-boot:run' _ "$APP_ROOT/backend" \
  >"$APP_RUNTIME_DIR/backend.log" 2>&1 < /dev/null &
backend_pid=$!
printf '%s\n' "$backend_pid" > "$APP_RUNTIME_DIR/backend.pid"

setsid bash -c 'cd -- "$1" && exec ./node_modules/.bin/vite --host 0.0.0.0 --port "$2" --strictPort' _ "$APP_ROOT/frontend" "$VITE_PORT" \
  >"$APP_RUNTIME_DIR/frontend.log" 2>&1 < /dev/null &
frontend_pid=$!
printf '%s\n' "$frontend_pid" > "$APP_RUNTIME_DIR/frontend.pid"

printf 'Iniciando Asanuma Odonto...\n'
printf 'Logs: %s\n' "$APP_RUNTIME_DIR"
deadline=$((SECONDS + STARTUP_TIMEOUT))
backend_ready=0
frontend_ready=0
while (( SECONDS < deadline )); do
  if curl --silent --fail --max-time 2 "http://127.0.0.1:${PORT}/api/health" >/dev/null; then backend_ready=1; fi
  if curl --silent --fail --max-time 2 "http://127.0.0.1:${VITE_PORT}/" >/dev/null; then frontend_ready=1; fi
  if (( backend_ready && frontend_ready )) && is_group_running "$backend_pid" && is_group_running "$frontend_pid"; then
    printf 'Aplicação iniciada.\n'
    printf 'Frontend: http://localhost:%s (rede local: http://IP-DA-MAQUINA:%s)\n' "$VITE_PORT" "$VITE_PORT"
    printf 'API: http://127.0.0.1:%s/api\n' "$PORT"
    exit 0
  fi
  if ! is_group_running "$backend_pid" || ! is_group_running "$frontend_pid"; then break; fi
  sleep 1
done

printf 'Falha ao iniciar a aplicação. Últimas linhas dos logs:\n' >&2
for log_file in backend frontend; do
  printf '\n--- %s ---\n' "$log_file" >&2
  tail -n 30 "$APP_RUNTIME_DIR/${log_file}.log" >&2 || true
done
"$SCRIPT_DIR/stop.sh" || true
exit 1
