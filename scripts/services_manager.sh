#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# SOC Chat App - Unified Services Manager (macOS/Linux)
# =============================================================================
# Commands:
#   ./scripts/services_manager.sh start-all
#   ./scripts/services_manager.sh stop-all
#   ./scripts/services_manager.sh restart-all
#   ./scripts/services_manager.sh status
#   ./scripts/services_manager.sh start <service>
#   ./scripts/services_manager.sh stop <service>
# Services: mongodb, api, ngrok, web, network, fcm
# =============================================================================

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)
SERVERS_DIR="$PROJECT_ROOT/servers"
API_SERVER_DIR="$SERVERS_DIR/local_api_server"
RUN_DIR="$PROJECT_ROOT/scripts/run"
mkdir -p "$RUN_DIR"

log_info() { echo -e "\033[1;36m[INFO]\033[0m $*"; }
log_ok()   { echo -e "\033[1;32m[OK] \033[0m $*"; }
log_warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
log_err()  { echo -e "\033[1;31m[ERR]\033[0m $*"; }

pid_of() {
  local name="$1"; local pidfile="$RUN_DIR/${name}.pid"
  [[ -f "$pidfile" ]] && cat "$pidfile" || true
}

is_running_pid() {
  local pid="$1"; [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

kill_from_pid_or_port() {
  local name="$1"; local port="${2:-}"
  local pidfile="$RUN_DIR/${name}.pid"
  if [[ -f "$pidfile" ]]; then
    local pid; pid=$(cat "$pidfile")
    if is_running_pid "$pid"; then
      kill "$pid" || true
      sleep 1
      is_running_pid "$pid" && kill -9 "$pid" || true
      rm -f "$pidfile"
      log_ok "Stopped $name (PID $pid)"
      return 0
    fi
    rm -f "$pidfile"
  fi
  if [[ -n "$port" ]]; then
    # Try lsof to find by port
    if command -v lsof >/dev/null; then
      local pids; pids=$(lsof -ti :"$port" || true)
      if [[ -n "$pids" ]]; then
        kill $pids || true
        sleep 1
        kill -9 $pids || true
        log_ok "Stopped $name by port :$port"
        return 0
      fi
    fi
  fi
  log_warn "No running process found for $name"
}

# -----------------------------------------------------------------------------
# MongoDB (service-managed)
# -----------------------------------------------------------------------------
start_mongodb() {
  if command -v systemctl >/dev/null; then
    sudo systemctl start mongod || sudo systemctl start mongodb || true
    systemctl is-active mongod >/dev/null 2>&1 || systemctl is-active mongodb >/dev/null 2>&1 && log_ok "MongoDB service active" || log_warn "MongoDB not active; ensure it's installed/service name correct"
  elif command -v brew >/dev/null; then
    brew services start mongodb-community || brew services start mongodb-community@7.0 || true
    log_ok "MongoDB started via Homebrew (if installed)"
  else
    log_warn "MongoDB start not automated on this OS; start it manually if needed."
  fi
}

stop_mongodb() {
  if command -v systemctl >/dev/null; then
    sudo systemctl stop mongod || sudo systemctl stop mongodb || true
    log_ok "MongoDB stopped (systemd)"
  elif command -v brew >/dev/null; then
    brew services stop mongodb-community || brew services stop mongodb-community@7.0 || true
    log_ok "MongoDB stopped (Homebrew)"
  else
    log_warn "MongoDB stop not automated on this OS."
  fi
}

status_mongodb() {
  if command -v systemctl >/dev/null; then
    systemctl is-active mongod >/dev/null 2>&1 && echo "MongoDB: RUNNING" || (
      systemctl is-active mongodb >/dev/null 2>&1 && echo "MongoDB: RUNNING" || echo "MongoDB: NOT RUNNING"
    )
  elif command -v brew >/dev/null; then
    brew services list | grep -E "mongodb-community" >/dev/null 2>&1 && echo "MongoDB: RUNNING (brew)" || echo "MongoDB: NOT RUNNING"
  else
    # Fallback: check default port
    if command -v lsof >/dev/null && lsof -i :27017 >/dev/null 2>&1; then echo "MongoDB: LISTENING"; else echo "MongoDB: UNKNOWN"; fi
  fi
}

# -----------------------------------------------------------------------------
# API Server :3003
# -----------------------------------------------------------------------------
start_api() {
  mkdir -p "$RUN_DIR"
  (cd "$API_SERVER_DIR" && nohup env PORT=3003 HOST=0.0.0.0 node server.js >>"$RUN_DIR/api_server.log" 2>&1 & echo $! >"$RUN_DIR/api_server.pid")
  log_ok "API Server started on :3003"
}

stop_api() { kill_from_pid_or_port "api_server" 3003; }
status_api() {
  local pid; pid=$(pid_of api_server)
  if is_running_pid "$pid"; then echo "API Server: RUNNING (PID $pid)"; else echo "API Server: NOT RUNNING"; fi
}

# -----------------------------------------------------------------------------
# ngrok (public URL for mobile)
# -----------------------------------------------------------------------------
start_ngrok() {
  if ! command -v ngrok >/dev/null; then
    log_err "ngrok is not installed. Install from https://ngrok.com/download and set authtoken."
    return 1
  fi
  nohup ngrok http 3003 --domain=soc-chat-app.ngrok-free.app >>"$RUN_DIR/ngrok.log" 2>&1 & echo $! >"$RUN_DIR/ngrok.pid"
  log_ok "ngrok tunnel started"
}

stop_ngrok() { kill_from_pid_or_port "ngrok" 4040; }
status_ngrok() {
  local pid; pid=$(pid_of ngrok)
  if is_running_pid "$pid"; then echo "ngrok: RUNNING (PID $pid)"; else echo "ngrok: NOT RUNNING"; fi
}stil

# -----------------------------------------------------------------------------
# Web Proxy Server :8082
# -----------------------------------------------------------------------------
start_web() {
  (cd "$SERVERS_DIR" && nohup env PORT=8082 API_TARGET=http://localhost:3003 node server.js >>"$RUN_DIR/web_server.log" 2>&1 & echo $! >"$RUN_DIR/web_server.pid")
  log_ok "Web proxy started on :8082"
}

stop_web() { kill_from_pid_or_port "web_server" 8082; }
status_web() {
  local pid; pid=$(pid_of web_server)
  if is_running_pid "$pid"; then echo "Web Proxy: RUNNING (PID $pid)"; else echo "Web Proxy: NOT RUNNING"; fi
}

# -----------------------------------------------------------------------------
# Local Network URLs Service :3004
# -----------------------------------------------------------------------------
start_network() {
  (cd "$API_SERVER_DIR" && nohup node local_network_config.js >>"$RUN_DIR/network_urls.log" 2>&1 & echo $! >"$RUN_DIR/network_urls.pid")
  log_ok "Network URLs service started (:3004)"
}

stop_network() { kill_from_pid_or_port "network_urls" 3004; }
status_network() {
  local pid; pid=$(pid_of network_urls)
  if is_running_pid "$pid"; then echo "Network URLs: RUNNING (PID $pid)"; else echo "Network URLs: NOT RUNNING"; fi
}

# -----------------------------------------------------------------------------
# FCM Server :3000
# -----------------------------------------------------------------------------
start_fcm() {
  local fcm_js="$SERVERS_DIR/fcm_server_production.js"
  [[ -f "$fcm_js" ]] || fcm_js="$SERVERS_DIR/fcm_server.js"
  (cd "$SERVERS_DIR" && nohup env PORT=3000 NODE_ENV=production node "$fcm_js" >>"$RUN_DIR/fcm_server.log" 2>&1 & echo $! >"$RUN_DIR/fcm_server.pid")
  log_ok "FCM server started on :3000"
}

stop_fcm() { kill_from_pid_or_port "fcm_server" 3000; }
status_fcm() {
  local pid; pid=$(pid_of fcm_server)
  if is_running_pid "$pid"; then echo "FCM Server: RUNNING (PID $pid)"; else echo "FCM Server: NOT RUNNING"; fi
}

# -----------------------------------------------------------------------------
# Orchestration
# -----------------------------------------------------------------------------
start_all() {
  log_info "Starting all services..."
  start_mongodb; sleep 1
  start_api; sleep 1
  start_ngrok; sleep 1
  start_web; sleep 1
  start_network; sleep 1
  start_fcm; sleep 1
  log_ok "All services started"
}

stop_all() {
  log_info "Stopping all services..."
  stop_ngrok
  stop_api
  stop_web
  stop_network
  stop_fcm
  stop_mongodb
  log_ok "All services stopped"
}

restart_all() { stop_all; sleep 2; start_all; }

status_all() {
  echo "================ Services Status ================"
  status_mongodb
  status_api
  status_ngrok
  status_web
  status_network
  status_fcm
  echo "==============================================="
}

usage() {
  cat <<EOF
Usage: $0 <command> [service]
Commands:
  start-all            Start all services
  stop-all             Stop all services
  restart-all          Restart all services
  status               Show status of services
  start <service>      Start one service (mongodb|api|ngrok|web|network|fcm)
  stop <service>       Stop one service (mongodb|api|ngrok|web|network|fcm)
EOF
}

cmd="${1:-}"; svc="${2:-}"
case "$cmd" in
  start-all)   start_all ;;
  stop-all)    stop_all ;;
  restart-all) restart_all ;;
  status)      status_all ;;
  start)
    case "$svc" in
      mongodb) start_mongodb ;;
      api)     start_api ;;
      ngrok)   start_ngrok ;;
      web)     start_web ;;
      network) start_network ;;
      fcm)     start_fcm ;;
      *) usage; exit 1 ;;
    esac ;;
  stop)
    case "$svc" in
      mongodb) stop_mongodb ;;
      api)     stop_api ;;
      ngrok)   stop_ngrok ;;
      web)     stop_web ;;
      network) stop_network ;;
      fcm)     stop_fcm ;;
      *) usage; exit 1 ;;
    esac ;;
  *) usage; exit 1 ;;
esac