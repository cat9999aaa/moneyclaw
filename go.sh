#!/usr/bin/env bash
set -euo pipefail

APP_NAME="moneyclaw"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="${APP_DIR}/.run"
PID_FILE="${PID_DIR}/${APP_NAME}.pid"
LOG_FILE="${PID_DIR}/${APP_NAME}.log"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
log_ok() { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_err() { printf "${RED}[ERR]${NC} %s\n" "$*"; }

usage() {
  cat <<'EOF'
MoneyClaw go.sh - One script to run all

Usage:
  ./go.sh up           # install deps + build + start (recommended)
  ./go.sh install      # install toolchain and dependencies
  ./go.sh build        # build project
  ./go.sh start        # start in background
  ./go.sh stop         # stop background process
  ./go.sh restart      # restart process
  ./go.sh status       # show process status
  ./go.sh logs         # tail logs
  ./go.sh doctor       # environment diagnosis
  ./go.sh key-setup    # one-click Conway API key provisioning (SIWE)
  ./go.sh service-install   # install + enable systemd service (boot autostart)
  ./go.sh service-remove    # disable + remove systemd service
  ./go.sh service-status    # show systemd service status
  ./go.sh service-logs      # tail systemd journal logs
  ./go.sh setup        # run interactive setup wizard
  ./go.sh run          # run in foreground
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_err "Missing command: $1"
    return 1
  fi
}

ensure_node() {
  if ! command -v node >/dev/null 2>&1; then
    log_err "Node.js not found. Please install Node.js >= 20 first."
    exit 1
  fi
  local major
  major="$(node -p "process.versions.node.split('.')[0]")"
  if [ "${major}" -lt 20 ]; then
    log_err "Node.js >= 20 required, current: $(node -v)"
    exit 1
  fi
  log_ok "Node.js $(node -v)"
}

ensure_pnpm() {
  if command -v pnpm >/dev/null 2>&1; then
    log_ok "pnpm $(pnpm -v)"
    return
  fi

  if command -v corepack >/dev/null 2>&1; then
    log_info "Enabling pnpm via corepack..."
    corepack enable
    corepack prepare pnpm@10.28.1 --activate
  else
    log_warn "corepack not found, installing pnpm globally via npm..."
    npm install -g pnpm@10.28.1
  fi

  require_cmd pnpm
  log_ok "pnpm $(pnpm -v)"
}

install_deps() {
  ensure_node
  ensure_pnpm
  mkdir -p "${PID_DIR}"
  cd "${APP_DIR}"
  log_info "Installing dependencies..."
  pnpm install --frozen-lockfile || pnpm install
  log_ok "Dependencies installed"
}

build_app() {
  cd "${APP_DIR}"
  log_info "Building project..."
  npm run build
  log_ok "Build success"
}

is_running() {
  if [ -f "${PID_FILE}" ]; then
    local pid
    pid="$(cat "${PID_FILE}" || true)"
    if [ -n "${pid}" ] && kill -0 "${pid}" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

start_bg() {
  cd "${APP_DIR}"
  mkdir -p "${PID_DIR}"

  if is_running; then
    log_warn "Already running with PID $(cat "${PID_FILE}")"
    return
  fi

  log_info "Starting MoneyClaw in background..."
  nohup node dist/index.js --run >"${LOG_FILE}" 2>&1 &
  local pid=$!
  echo "${pid}" >"${PID_FILE}"
  sleep 1

  if kill -0 "${pid}" >/dev/null 2>&1; then
    log_ok "Started. PID=${pid}"
    log_info "Log file: ${LOG_FILE}"
  else
    log_err "Start failed. Check logs: ${LOG_FILE}"
    exit 1
  fi
}

stop_bg() {
  if ! is_running; then
    log_warn "Not running"
    rm -f "${PID_FILE}"
    return
  fi

  local pid
  pid="$(cat "${PID_FILE}")"
  log_info "Stopping PID ${pid}..."
  kill "${pid}" >/dev/null 2>&1 || true

  for _ in $(seq 1 10); do
    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      rm -f "${PID_FILE}"
      log_ok "Stopped"
      return
    fi
    sleep 1
  done

  log_warn "Graceful stop timeout, forcing kill -9..."
  kill -9 "${pid}" >/dev/null 2>&1 || true
  rm -f "${PID_FILE}"
  log_ok "Stopped (forced)"
}

status_app() {
  if is_running; then
    local pid
    pid="$(cat "${PID_FILE}")"
    log_ok "Running. PID=${pid}"
  else
    log_warn "Not running"
  fi

  if [ -f "${LOG_FILE}" ]; then
    log_info "Log file: ${LOG_FILE}"
  fi
}

logs_app() {
  mkdir -p "${PID_DIR}"
  touch "${LOG_FILE}"
  log_info "Tailing logs (Ctrl+C to exit)..."
  tail -n 200 -f "${LOG_FILE}"
}

doctor() {
  log_info "Running diagnostics..."
  cd "${APP_DIR}"

  if command -v node >/dev/null 2>&1; then
    log_ok "node: $(node -v)"
  else
    log_err "node: missing"
  fi

  if command -v pnpm >/dev/null 2>&1; then
    log_ok "pnpm: $(pnpm -v)"
  else
    log_err "pnpm: missing"
  fi

  if [ -f "package.json" ]; then
    log_ok "package.json found"
  else
    log_err "package.json missing"
  fi

  if [ -f "dist/index.js" ]; then
    log_ok "dist/index.js present"
  else
    log_warn "dist/index.js missing (run ./go.sh build)"
  fi

  status_app
}

setup_interactive() {
  cd "${APP_DIR}"
  node dist/index.js --setup
}

run_fg() {
  cd "${APP_DIR}"
  exec node dist/index.js --run
}

key_setup() {
  ensure_node
  cd "${APP_DIR}"

  if [ ! -f "${APP_DIR}/dist/index.js" ]; then
    log_warn "dist/index.js not found, building first..."
    ensure_pnpm
    build_app
  fi

  log_info "Provisioning Conway API key via SIWE..."
  node dist/index.js --provision
  log_ok "Provision finished. You can run: ./go.sh status"
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    log_err "Need root privileges. Run as root or install sudo."
    exit 1
  fi
}

service_install() {
  ensure_node
  ensure_pnpm
  mkdir -p "${PID_DIR}"

  local run_user
  run_user="${SUDO_USER:-$(id -un)}"
  if [ "${run_user}" = "root" ] && [ -n "${USER:-}" ] && [ "${USER}" != "root" ]; then
    run_user="${USER}"
  fi

  local unit_file="/etc/systemd/system/${APP_NAME}.service"
  local run_path="${APP_DIR}"
  local node_path
  node_path="$(command -v node)"

  run_as_root mkdir -p "${run_path}/.run"
  run_as_root chown -R "${run_user}:${run_user}" "${run_path}/.run"

  log_info "Writing systemd unit: ${unit_file}"
  run_as_root /bin/sh -c "cat > '${unit_file}' <<EOF
[Unit]
Description=MoneyClaw Runtime
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${run_user}
WorkingDirectory=${run_path}
ExecStart=${node_path} ${run_path}/dist/index.js --run
Restart=always
RestartSec=3
StartLimitIntervalSec=0
KillSignal=SIGINT
TimeoutStopSec=20
Environment=NODE_ENV=production
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
StandardOutput=append:${run_path}/.run/systemd.log
StandardError=append:${run_path}/.run/systemd.log

[Install]
WantedBy=multi-user.target
EOF"

  run_as_root systemctl daemon-reload
  run_as_root systemctl enable "${APP_NAME}.service"
  run_as_root systemctl restart "${APP_NAME}.service"
  log_ok "systemd service installed and started"
  log_info "Check: ./go.sh service-status"
}

service_remove() {
  local unit_file="/etc/systemd/system/${APP_NAME}.service"
  if ! run_as_root test -f "${unit_file}"; then
    log_warn "Service unit not found: ${unit_file}"
    return
  fi

  run_as_root systemctl stop "${APP_NAME}.service" || true
  run_as_root systemctl disable "${APP_NAME}.service" || true
  run_as_root rm -f "${unit_file}"
  run_as_root systemctl daemon-reload
  log_ok "systemd service removed"
}

service_status() {
  run_as_root systemctl --no-pager --full status "${APP_NAME}.service" || true
}

service_logs() {
  run_as_root journalctl -u "${APP_NAME}.service" -n 200 -f
}

cmd="${1:-up}"

case "${cmd}" in
  up)
    install_deps
    build_app
    start_bg
    status_app
    ;;
  install)
    install_deps
    ;;
  build)
    build_app
    ;;
  start)
    start_bg
    ;;
  stop)
    stop_bg
    ;;
  restart)
    stop_bg
    start_bg
    status_app
    ;;
  status)
    status_app
    ;;
  logs)
    logs_app
    ;;
  doctor)
    doctor
    ;;
  key-setup)
    key_setup
    ;;
  service-install)
    service_install
    ;;
  service-remove)
    service_remove
    ;;
  service-status)
    service_status
    ;;
  service-logs)
    service_logs
    ;;
  setup)
    setup_interactive
    ;;
  run)
    run_fg
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    log_err "Unknown command: ${cmd}"
    usage
    exit 1
    ;;
esac
