#!/usr/bin/env bash
set -Eeuo pipefail

APP_RUNTIME_DIR="${APP_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}/asanumaodonto-infra-${UID}}"

stop_group() {
  local name="$1" pid_file="$APP_RUNTIME_DIR/$1.pid" pid=""
  pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ -z "$pid" ]]; then
    printf '%s não está registrado como ativo.\n' "$name"
    return 0
  fi
  if ! kill -0 -- "-$pid" 2>/dev/null; then
    rm -f "$pid_file"
    printf '%s já estava parado.\n' "$name"
    return 0
  fi
  printf 'Parando %s...\n' "$name"
  kill -TERM -- "-$pid" 2>/dev/null || true
  for _ in {1..15}; do
    kill -0 -- "-$pid" 2>/dev/null || break
    sleep 1
  done
  if kill -0 -- "-$pid" 2>/dev/null; then
    printf '%s não encerrou a tempo; forçando parada.\n' "$name" >&2
    kill -KILL -- "-$pid" 2>/dev/null || true
  fi
  rm -f "$pid_file"
}

stop_group frontend
stop_group backend
printf 'Aplicação parada.\n'
