#!/usr/bin/env bash
# Xvfb + XFCE + x11vnc + websockify. The default invocation returns immediately
# so Codespaces postStartCommand does not block; the supervisor keeps going.
set -u

PREFIX=/opt/linuxlite-desktop
WEB_ROOT="${WEB_ROOT:-$PREFIX/web}"
WALLPAPER=/usr/share/backgrounds/linuxlite/LinuxLite.png
DISPLAY_NUM="${DISPLAY_NUM:-1}"
export DISPLAY=":${DISPLAY_NUM}"
RESOLUTION="${VNC_RESOLUTION:-1600x900x24}"
VNC_PORT="${VNC_PORT:-5901}"
WEB_PORT="${WEB_PORT:-6080}"
LOG="${DESKTOP_LOG:-/tmp/linuxlite-desktop.log}"

if [[ -z "${XDG_RUNTIME_DIR:-}" || ! -d "${XDG_RUNTIME_DIR}" || ! -w "${XDG_RUNTIME_DIR}" ]]; then
  runtime_dir="/tmp/runtime-$(id -u)"
  export XDG_RUNTIME_DIR="$runtime_dir"
fi
PID_DIR="${XDG_RUNTIME_DIR}/linuxlite-pids"
mkdir -p "$XDG_RUNTIME_DIR" "$PID_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }

pid_alive() {
  local pidfile="$1"
  [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null
}

start_if_needed() {
  local pidfile="$1"
  shift
  if pid_alive "$pidfile"; then
    return 0
  fi
  "$@" &
  echo $! > "$pidfile"
}

set_prop() {
  local channel="$1" prop="$2" type="$3" value="$4"
  if xfconf-query -c "$channel" -p "$prop" >/dev/null 2>&1; then
    xfconf-query -c "$channel" -p "$prop" -s "$value" >/dev/null
  else
    xfconf-query -c "$channel" -p "$prop" --create -t "$type" -s "$value" >/dev/null
  fi
}

write_auth() {
  local pass="${VNC_PASSWORD:-}"
  pass="${pass//$'\r'/}"
  pass="${pass//$'\n'/}"
  if [[ "$pass" == \#* ]]; then
    log "VNC_PASSWORD cannot start with #; starting without a VNC password"
    pass=""
  fi
  if ((${#pass} > 8)); then
    log "VNC_PASSWORD is longer than 8 characters; VNC uses the first 8"
    pass="${pass:0:8}"
  fi
  AUTH_PASS="$pass"
  python3 - "$WEB_ROOT/vnc-auth.js" "$pass" <<'PY'
import json, sys
path, password = sys.argv[1], sys.argv[2]
with open(path, "w", encoding="utf-8") as fh:
    fh.write("window.__VNC_PASSWORD__ = " + json.dumps(password) + ";\n")
PY
  chmod 644 "$WEB_ROOT/vnc-auth.js" 2>/dev/null || true
  if [[ -n "$pass" ]]; then
    printf '%s\n' "$pass" > "$PID_DIR/vncpasswd"
    chmod 600 "$PID_DIR/vncpasswd"
  else
    rm -f "$PID_DIR/vncpasswd"
  fi
}

seed_config() {
  local dest="$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"
  mkdir -p "$dest" "$HOME/.config/autostart"
  local src base name
  for src in "$PREFIX/xfce/"*.xml; do
    [[ -f "$src" ]] || continue
    base="$(basename "$src")"
    if [[ ! -f "$dest/$base" ]]; then
      cp "$src" "$dest/$base"
    fi
  done
  for name in xscreensaver light-locker xfce4-screensaver gnome-keyring-pkcs11 gnome-keyring-secrets gnome-keyring-ssh; do
    cat > "$HOME/.config/autostart/${name}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
Hidden=true
X-GNOME-Autostart-enabled=false
EOF
  done
}

ensure_xvfb() {
  if xdpyinfo >/dev/null 2>&1; then
    return 0
  fi
  if pid_alive "$PID_DIR/xvfb.pid"; then
    return 0
  fi
  Xvfb "$DISPLAY" -screen 0 "$RESOLUTION" -nolisten tcp -ac +extension GLX +render -noreset &
  echo $! > "$PID_DIR/xvfb.pid"
}

wait_for_x() {
  local _
  for _ in $(seq 1 50); do
    if xdpyinfo >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

ensure_dbus() {
  export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
  if pid_alive "$PID_DIR/dbus.pid" && [[ -S "${XDG_RUNTIME_DIR}/bus" ]]; then
    return 0
  fi
  rm -f "${XDG_RUNTIME_DIR}/bus"
  dbus-daemon --session --address="$DBUS_SESSION_BUS_ADDRESS" --nofork --nopidfile &
  echo $! > "$PID_DIR/dbus.pid"
  local _
  for _ in $(seq 1 50); do
    [[ -S "${XDG_RUNTIME_DIR}/bus" ]] && return 0
    sleep 0.1
  done
  return 1
}

ensure_xfce() {
  if pid_alive "$PID_DIR/xfce.pid"; then
    return 0
  fi
  startxfce4 &
  echo $! > "$PID_DIR/xfce.pid"
}

ensure_vnc() {
  local -a args
  args=(x11vnc -display "$DISPLAY" -rfbport "$VNC_PORT" -localhost -forever -shared -noxdamage -noscr -wait 5 -defer 5 -quiet)
  if [[ -n "${AUTH_PASS:-}" ]]; then
    args+=(-passwdfile "$PID_DIR/vncpasswd")
  else
    args+=(-nopw)
  fi
  start_if_needed "$PID_DIR/x11vnc.pid" "${args[@]}"
}

ensure_websockify() {
  start_if_needed "$PID_DIR/websockify.pid" \
    websockify --web "$WEB_ROOT" "0.0.0.0:${WEB_PORT}" "127.0.0.1:${VNC_PORT}"
}

apply_look() {
  local icon="elementary-xfce"
  if [[ ! -d "/usr/share/icons/${icon}" && -d /usr/share/icons/Adwaita ]]; then
    icon="Adwaita"
  fi
  if ! xfconf-query -c xsettings -l >/dev/null 2>&1; then
    return 1
  fi
  set_prop xsettings /Net/ThemeName string Arc || return 1
  set_prop xsettings /Net/IconThemeName string "$icon" || return 1
  set_prop xfwm4 /general/theme string Arc || true
  set_prop xfwm4 /general/button_layout string "|HMC" || true
  set_prop xfwm4 /general/use_compositing bool false || true
  set_prop xfce4-panel /panels/panel-1/position string "p=12;x=0;y=0" || true
  set_prop xfce4-panel /panels/panel-1/length uint 100 || true
  xset s off -dpms s noblank >/dev/null 2>&1 || true

  [[ -f "$WALLPAPER" ]] || return 0

  local output name prop found=0
  while IFS= read -r prop; do
    case "$prop" in
      */last-image|*/last-single-image)
        xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER" >/dev/null 2>&1 || true
        found=1
        ;;
      */image-style)
        xfconf-query -c xfce4-desktop -p "$prop" -s 5 >/dev/null 2>&1 || true
        ;;
    esac
  done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null || true)

  local -a candidates=()
  while IFS= read -r output; do
    [[ -n "$output" ]] || continue
    name="$(printf '%s' "$output" | tr -cd '[:alnum:]')"
    candidates+=("/backdrop/screen0/monitor${name}/workspace0/last-image")
  done < <(xrandr 2>/dev/null | awk '/ connected/{print $1}')
  candidates+=(
    /backdrop/screen0/monitor0/workspace0/last-image
    /backdrop/screen0/monitorVirtual1/workspace0/last-image
    /backdrop/screen0/monitordefault/workspace0/last-image
  )
  for prop in "${candidates[@]}"; do
    local style="${prop%/last-image}/image-style"
    if xfconf-query -c xfce4-desktop -p "$prop" >/dev/null 2>&1; then
      xfconf-query -c xfce4-desktop -p "$prop" -s "$WALLPAPER" >/dev/null 2>&1 || true
      found=1
    else
      xfconf-query -c xfce4-desktop -p "$prop" --create -t string -s "$WALLPAPER" >/dev/null 2>&1 || true
    fi
    if xfconf-query -c xfce4-desktop -p "$style" >/dev/null 2>&1; then
      xfconf-query -c xfce4-desktop -p "$style" -s 5 >/dev/null 2>&1 || true
    fi
  done
  [[ "$found" -eq 1 ]]
}

supervise() {
  local look_tries=0
  write_auth
  seed_config
  while true; do
    ensure_xvfb || true
    if wait_for_x; then
      xset s off -dpms s noblank >/dev/null 2>&1 || true
      ensure_dbus || true
      seed_config
      ensure_xfce || true
      ensure_vnc || true
      ensure_websockify || true
      if [[ "$look_tries" -lt 30 ]]; then
        if apply_look; then
          look_tries=30
          log "desktop ready on port ${WEB_PORT}"
        else
          look_tries=$((look_tries + 1))
        fi
      fi
    fi
    sleep 2
  done
}

cmd="${1:-start}"
case "$cmd" in
  supervise)
    supervise
    ;;
  apply-look)
    apply_look
    ;;
  start)
    if pid_alive "$PID_DIR/supervisor.pid"; then
      log "desktop already running"
      exit 0
    fi
    : > "$LOG"
    setsid "$0" supervise >>"$LOG" 2>&1 </dev/null &
    echo $! > "$PID_DIR/supervisor.pid"
    ;;
  *)
    log "usage: $0 [start|supervise|apply-look]"
    exit 2
    ;;
esac
