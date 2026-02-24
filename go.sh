#!/usr/bin/env bash
set -euo pipefail

APP_NAME="moneyclaw"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_DIR="${APP_DIR}/.run"
PID_FILE="${PID_DIR}/${APP_NAME}.pid"
LOG_FILE="${PID_DIR}/${APP_NAME}.log"
LANG_CHOICE="${MONEYCLAW_LANG:-}"

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
  ./go.sh wallet       # show runtime wallet address and balances
  ./go.sh configure    # run interactive runtime config menu
  ./go.sh pick-model   # discover and pick active model
  ./go.sh service-install   # install + enable systemd service (boot autostart)
  ./go.sh service-remove    # disable + remove systemd service
  ./go.sh service-status    # show systemd service status
  ./go.sh service-logs      # tail systemd journal logs
  ./go.sh setup        # run interactive setup wizard
  ./go.sh run          # run in foreground
  ./go.sh update       # git pull + install/build + restart
EOF
}

t() {
  local key="$1"
  case "${LANG_CHOICE}" in
    zh)
      case "$key" in
        lang_pick) printf "请选择语言 / Select language:\n  1) 中文\n  2) English\n> ";;
        banner_1) printf "MONEYCLAW CONTROL CENTER";;
        banner_2) printf "主控面板";;
        menu_title) printf "请选择操作";;
        menu_invalid) printf "无效选项，请重试";;
        menu_exit) printf "已退出。";;
        m1) printf "1) 一键启动（安装+构建+后台启动）";;
        m2) printf "2) 配置 Conway API Key（SIWE）";;
        m3) printf "3) 运行初始化向导（--setup）";;
        m4) printf "4) 打开运行时配置菜单（--configure）";;
        m5) printf "5) 发现并选择模型（--pick-model）";;
        m6) printf "6) 启动后台进程";;
        m7) printf "7) 停止后台进程";;
        m8) printf "8) 重启后台进程";;
        m9) printf "9) 查看状态";;
        m10) printf "10) 查看日志";;
        m11) printf "11) 安装 systemd（开机自启+崩溃拉起）";;
        m12) printf "12) 查看 systemd 状态";;
        m13) printf "13) 查看 systemd 日志";;
        m14) printf "14) 查看机器人钱包地址和余额";;
        m0) printf "0) 退出";;
        prompt) printf "请输入编号 > ";;
        pause) printf "\n按回车继续...";;
        *) printf "%s" "$key";;
      esac
      ;;
    *)
      case "$key" in
        lang_pick) printf "Choose language / 请选择语言:\n  1) English\n  2) 中文\n> ";;
        banner_1) printf "MONEYCLAW CONTROL CENTER";;
        banner_2) printf "Operations Console";;
        menu_title) printf "Select an action";;
        menu_invalid) printf "Invalid option, try again";;
        menu_exit) printf "Exited.";;
        m1) printf "1) One-click up (install+build+start)";;
        m2) printf "2) Configure Conway API Key (SIWE)";;
        m3) printf "3) Run setup wizard (--setup)";;
        m4) printf "4) Open runtime config menu (--configure)";;
        m5) printf "5) Discover and pick model (--pick-model)";;
        m6) printf "6) Start background process";;
        m7) printf "7) Stop background process";;
        m8) printf "8) Restart background process";;
        m9) printf "9) Show status";;
        m10) printf "10) Tail logs";;
        m11) printf "11) Install systemd (boot + auto-restart)";;
        m12) printf "12) Show systemd status";;
        m13) printf "13) Tail systemd logs";;
        m14) printf "14) Show runtime wallet address and balances";;
        m0) printf "0) Exit";;
        prompt) printf "Enter number > ";;
        pause) printf "\nPress Enter to continue...";;
        *) printf "%s" "$key";;
      esac
      ;;
  esac
}

select_language() {
  if [ -n "${LANG_CHOICE}" ]; then
    return
  fi
  printf "\n"
  t lang_pick
  local pick
  read -r pick || pick=""
  case "$pick" in
    2) LANG_CHOICE="zh" ;;
    *) LANG_CHOICE="en" ;;
  esac
}

show_menu_banner() {
  printf "\n"
  printf "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}\n"
  printf "${BLUE}║${NC} ${GREEN}⚡ %s${NC}                                        ${BLUE}║${NC}\n" "$(t banner_1)"
  printf "${BLUE}║${NC} ${YELLOW}%s${NC}                                           ${BLUE}║${NC}\n" "$(t banner_2)"
  printf "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"
  printf "\n${YELLOW}%s${NC}\n" "$(t menu_title)"
}

configure_interactive() {
  ensure_node
  cd "${APP_DIR}"
  node dist/index.js --configure
}

pick_model_interactive() {
  ensure_node
  cd "${APP_DIR}"
  node dist/index.js --pick-model
}

json_get() {
  local file="$1"
  local key="$2"
  if [ ! -f "$file" ]; then
    return 1
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -r ".${key} // empty" "$file"
  else
    node -e "const fs=require('fs');const p=process.argv[1];const k=process.argv[2];const o=JSON.parse(fs.readFileSync(p,'utf8'));process.stdout.write(String(o[k]??''));" "$file" "$key"
  fi
}

wallet_info() {
  ensure_node
  local cfg="${HOME}/.automaton/automaton.json"
  local address api_key
  address="$(json_get "$cfg" "walletAddress" 2>/dev/null || true)"
  api_key="$(json_get "$cfg" "conwayApiKey" 2>/dev/null || true)"

  if [ -z "$address" ]; then
    log_err "walletAddress not found in ~/.automaton/automaton.json"
    return 1
  fi

  printf "\n${GREEN}Runtime Wallet${NC}\n"
  printf "Address: %s\n" "$address"

  local credits="N/A"
  if [ -n "$api_key" ]; then
    credits="$(curl -s https://api.conway.tech/v1/credits/balance -H "Authorization: $api_key" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const j=JSON.parse(s);const c=j.balance_cents??j.credits_cents;process.stdout.write(c==null?'N/A':('$'+(c/100).toFixed(2)));}catch{process.stdout.write('N/A')}})")"
  fi
  printf "Conway Credits: %s\n" "$credits"

  local rpc="${BASE_RPC_URL:-https://mainnet.base.org}"
  local eth_hex
  eth_hex="$(curl -s -X POST "$rpc" -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBalance\",\"params\":[\"$address\",\"latest\"],\"id\":1}" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const j=JSON.parse(s);process.stdout.write(j.result||'0x0')}catch{process.stdout.write('0x0')}})")"
  local eth_fmt
  eth_fmt="$(node -e "const h=(process.argv[1]||'0x0');const v=BigInt(h);const n=Number(v)/1e18;process.stdout.write(n.toFixed(6));" "$eth_hex")"
  printf "Base ETH: %s\n" "$eth_fmt"

  local usdc="0x833589fCD6EDb6E08f4c7C32D4f71b54bDa02913"
  local addr_no0x pad
  addr_no0x="${address#0x}"
  pad="$(printf '%064s' "$addr_no0x" | tr ' ' '0')"
  local data="0x70a08231${pad}"
  local usdc_hex
  usdc_hex="$(curl -s -X POST "$rpc" -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"$usdc\",\"data\":\"$data\"},\"latest\"],\"id\":1}" | node -e "let s='';process.stdin.on('data',d=>s+=d).on('end',()=>{try{const j=JSON.parse(s);process.stdout.write(j.result||'0x0')}catch{process.stdout.write('0x0')}})")"
  local usdc_fmt
  usdc_fmt="$(node -e "const h=(process.argv[1]||'0x0');const v=BigInt(h);const n=Number(v)/1e6;process.stdout.write(n.toFixed(2));" "$usdc_hex")"
  printf "Base USDC: %s\n\n" "$usdc_fmt"
}

menu_loop() {
  select_language
  while true; do
    show_menu_banner
    printf "%s\n" "$(t m1)"
    printf "%s\n" "$(t m2)"
    printf "%s\n" "$(t m3)"
    printf "%s\n" "$(t m4)"
    printf "%s\n" "$(t m5)"
    printf "%s\n" "$(t m6)"
    printf "%s\n" "$(t m7)"
    printf "%s\n" "$(t m8)"
    printf "%s\n" "$(t m9)"
    printf "%s\n" "$(t m10)"
    printf "%s\n" "$(t m11)"
    printf "%s\n" "$(t m12)"
    printf "%s\n" "$(t m13)"
    printf "%s\n" "$(t m14)"
    printf "%s\n" "$(t m0)"
    t prompt
    local choice
    read -r choice || choice="0"
    case "$choice" in
      1) install_deps; build_app; start_bg; status_app ;;
      2) key_setup ;;
      3) setup_interactive ;;
      4) configure_interactive ;;
      5) pick_model_interactive ;;
      6) start_bg ;;
      7) stop_bg ;;
      8) stop_bg; start_bg; status_app ;;
      9) status_app ;;
      10) logs_app ;;
      11) service_install ;;
      12) service_status ;;
      13) service_logs ;;
      14) wallet_info ;;
      0)
        log_ok "$(t menu_exit)"
        break
        ;;
      *)
        log_warn "$(t menu_invalid)"
        ;;
    esac
    printf "%s" "$(t pause)"
    read -r _ || true
  done
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

update_app() {
  require_cmd git
  cd "${APP_DIR}"
  log_info "Updating from remote (git pull --ff-only)..."
  git pull --ff-only
  install_deps
  build_app
  stop_bg || true
  start_bg
  status_app
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

if [ "$#" -eq 0 ]; then
  if [ -t 0 ] && [ -t 1 ]; then
    cmd="menu"
  else
    cmd="up"
  fi
else
  cmd="$1"
fi

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
  menu)
    menu_loop
    ;;
  key-setup)
    key_setup
    ;;
  wallet)
    wallet_info
    ;;
  configure)
    configure_interactive
    ;;
  pick-model)
    pick_model_interactive
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
  update)
    update_app
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
