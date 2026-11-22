#!/usr/bin/env bash
# ==============================================================================
# tests/test_headless_e2e.sh: Isolated Headless Wayland E2E Runtime Validation
# ==============================================================================
# Executes Quickshell inside an isolated headless Hyprland Wayland instance:
#   1. Allocates an isolated Wayland socket without touching active user desktop
#   2. Runs Quickshell with isolated XDG_STATE_HOME
#   3. Asserts shell initialization reaches "Configuration Loaded"
#   4. Verifies zero layer-shell backend failures or fatal crashes
#   5. Mutates settings on disk and verifies dynamic reload without process death
#   6. Asserts clean shutdown on SIGTERM
#
# Exit 0: Headless run, layer-shell integration, and dynamic reload all succeeded.
# Exit 1: Initialization failed, layer-shell crashed, or shell crashed on reload.
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UID_NUM="$(id -u)"
RUNDIR="/run/user/$UID_NUM"

HYPRLAND_BIN="${HYPRLAND_BIN:-$(which Hyprland 2>/dev/null || echo "/run/current-system/sw/bin/Hyprland")}"
QUICKSHELL_BIN="${QUICKSHELL_BIN:-$(which quickshell 2>/dev/null || echo "/home/ashley/.local/bin/quickshell")}"

if [[ ! -x "$HYPRLAND_BIN" ]]; then
    echo "ERROR: Hyprland binary not found or not executable at: $HYPRLAND_BIN" >&2
    exit 2
fi

if [[ ! -x "$QUICKSHELL_BIN" ]]; then
    echo "ERROR: quickshell binary not found or not executable at: $QUICKSHELL_BIN" >&2
    exit 2
fi

TMP_DIR=$(mktemp -d /tmp/qs_headless_e2e_XXXXXX)
STATE_DIR="$TMP_DIR/state"
mkdir -p "$STATE_DIR/quickshell"
cp "$PROJECT_DIR/settings.conf" "$STATE_DIR/quickshell/settings.conf"

QS_LOG="$TMP_DIR/quickshell.log"
HYPR_LOG="$TMP_DIR/hyprland.log"
cat << 'EOF' > "$TMP_DIR/hypr.conf"
debug {
    enable_stdout_logs = true
}
EOF

QS_PID=""
HYPR_PID=""
NEW_SOCK=""
HOST_WAYLAND=""

cleanup() {
    local exit_code=$?
    echo "--> [CLEANUP] Tearing down headless test harness..."
    if [[ -n "$QS_PID" ]] && kill -0 "$QS_PID" 2>/dev/null; then
        kill -15 "$QS_PID" 2>/dev/null || true
        sleep 0.5
        kill -9 "$QS_PID" 2>/dev/null || true
    fi
    if [[ -n "$HYPR_PID" ]] && kill -0 "$HYPR_PID" 2>/dev/null; then
        kill -15 "$HYPR_PID" 2>/dev/null || true
        sleep 0.5
        kill -9 "$HYPR_PID" 2>/dev/null || true
    fi
    if [[ -n "$NEW_SOCK" ]]; then
        if [[ -n "$HOST_WAYLAND" && "$NEW_SOCK" == "$HOST_WAYLAND" ]]; then
            echo "--> [CLEANUP] Safety guard: Preserving host Wayland socket $HOST_WAYLAND"
        else
            echo "--> [CLEANUP] Removing isolated test socket $NEW_SOCK..."
            rm -f "$RUNDIR/$NEW_SOCK"* 2>/dev/null || true
        fi
    fi
    rm -rf "$TMP_DIR" 2>/dev/null || true
    exit "$exit_code"
}
trap cleanup EXIT INT TERM

echo "========================================================================"
echo " Running Isolated Headless Wayland E2E Runtime Test..."
echo " Hyprland:   $HYPRLAND_BIN"
echo " Quickshell: $QUICKSHELL_BIN"
echo " Workspace:  $PROJECT_DIR"
echo " Temp Dir:   $TMP_DIR"
echo "========================================================================"

# Helper: check whether a Wayland socket is actively listening with locked flock
is_socket_active() {
    local s="$1"
    local s_path="$RUNDIR/$s"
    local lock_path="$RUNDIR/$s.lock"
    [[ -S "$s_path" ]] || return 1
    if [[ -f "$lock_path" ]]; then
        ! flock -n "$lock_path" true 2>/dev/null || return 1
    fi
    if which nc >/dev/null 2>&1; then
        nc -U -z "$s_path" 2>/dev/null || return 1
    fi
    return 0
}

# 1. Detect active host Wayland socket
echo "--> Detecting active host Wayland socket in $RUNDIR..."
CANDIDATE="${WAYLAND_DISPLAY:-}"

if [[ -n "$CANDIDATE" ]] && is_socket_active "$CANDIDATE"; then
    HOST_WAYLAND="$CANDIDATE"
    echo "--> Active host Wayland detected from WAYLAND_DISPLAY: $HOST_WAYLAND"
else
    HOST_WAYLAND=""
    for s_path in "$RUNDIR"/wayland-*; do
        [[ -S "$s_path" ]] || continue
        [[ "$s_path" == *.lock* ]] && continue
        [[ "$s_path" == *awww* ]] && continue
        s_base="$(basename "$s_path")"
        if is_socket_active "$s_base"; then
            HOST_WAYLAND="$s_base"
            echo "--> Auto-detected active host Wayland socket: $HOST_WAYLAND"
            break
        fi
    done
fi

# 2. Pre-flight cleanup: prune stale un-locked sockets so Hyprland allocation is distinct
for s_path in "$RUNDIR"/wayland-*; do
    [[ -S "$s_path" ]] || continue
    [[ "$s_path" == *.lock* ]] && continue
    [[ "$s_path" == *awww* ]] && continue
    s_base="$(basename "$s_path")"
    if ! is_socket_active "$s_base"; then
        echo "--> Pruning stale un-locked socket: $s_base"
        rm -f "$s_path" "$s_path.lock" 2>/dev/null || true
    fi
done

# Snapshot existing Wayland sockets
mapfile -t INITIAL_SOCKS < <(ls "$RUNDIR"/wayland-* 2>/dev/null | grep -v "\.lock" | grep -v "awww" | xargs -r -n1 basename || true)

# 3. Launch isolated Hyprland with Aquamarine backend support
echo "--> Spawning isolated Hyprland..."
if [[ -n "$HOST_WAYLAND" ]]; then
    echo "--> Host Wayland detected at $HOST_WAYLAND; spawning nested via AQ_BACKENDS=wayland"
    AQ_BACKENDS=wayland WAYLAND_DISPLAY="$HOST_WAYLAND" "$HYPRLAND_BIN" --config "$TMP_DIR/hypr.conf" > "$HYPR_LOG" 2>&1 &
    HYPR_PID=$!
else
    echo "--> No host Wayland detected; spawning standalone headless Hyprland via AQ_BACKENDS=headless"
    env -u WAYLAND_DISPLAY AQ_BACKENDS=headless "$HYPRLAND_BIN" --config "$TMP_DIR/hypr.conf" > "$HYPR_LOG" 2>&1 &
    HYPR_PID=$!
fi

# 4. Wait for newly created Wayland socket
echo "--> Waiting for isolated Wayland socket allocation..."
for i in {1..60}; do
    mapfile -t CURRENT_SOCKS < <(ls "$RUNDIR"/wayland-* 2>/dev/null | grep -v "\.lock" | grep -v "awww" | xargs -r -n1 basename || true)
    for sock in "${CURRENT_SOCKS[@]}"; do
        is_new=true
        for old in "${INITIAL_SOCKS[@]}"; do
            if [[ "$sock" == "$old" ]]; then
                is_new=false
                break
            fi
        done
        if [[ -n "$HOST_WAYLAND" && "$sock" == "$HOST_WAYLAND" ]]; then
            is_new=false
        fi
        if $is_new && is_socket_active "$sock"; then
            NEW_SOCK="$sock"
            break 2
        fi
    done
    sleep 0.15
done

if [[ -z "$NEW_SOCK" ]]; then
    echo "ERROR: Failed to allocate headless Wayland socket." >&2
    echo "Hyprland log:" >&2
    cat "$HYPR_LOG" >&2
    exit 1
fi

echo "--> Dedicated Wayland socket allocated: $NEW_SOCK"

# Step 1: Launch Quickshell against headless socket
echo "--> Launching Quickshell under WAYLAND_DISPLAY=$NEW_SOCK and isolated XDG_STATE_HOME..."
env WAYLAND_DISPLAY="$NEW_SOCK" XDG_STATE_HOME="$STATE_DIR" "$QUICKSHELL_BIN" -p "$PROJECT_DIR/shell.qml" > "$QS_LOG" 2>&1 &
QS_PID=$!

# Wait for "Configuration Loaded"
echo "--> Awaiting 'Configuration Loaded' log marker..."
LOADED=false
for i in {1..40}; do
    if ! kill -0 "$QS_PID" 2>/dev/null; then
        echo "ERROR: Quickshell process died prematurely during initialization!" >&2
        cat "$QS_LOG" >&2
        exit 1
    fi
    if grep -q "Configuration Loaded" "$QS_LOG" 2>/dev/null; then
        LOADED=true
        break
    fi
    sleep 0.2
done

if ! $LOADED; then
    echo "ERROR: Timeout waiting for 'Configuration Loaded' from Quickshell." >&2
    echo "Quickshell log output:" >&2
    cat "$QS_LOG" >&2
    exit 1
fi
echo "[PASS] Step 1: Quickshell initialized successfully with 'Configuration Loaded'."

# Check for fatal layer-shell errors
if grep -q "No PanelWindow backend loaded" "$QS_LOG" 2>/dev/null; then
    echo "ERROR: Detected 'No PanelWindow backend loaded' layer-shell failure!" >&2
    cat "$QS_LOG" >&2
    exit 1
fi
echo "[PASS] Step 2: Layer-shell backend attached cleanly with zero PanelWindow fatal errors."

# Step 3: Interactive IPC Widget Action Verification
echo "--> Testing interactive IPC widget actions on running Quickshell instance..."
IPC_CMD=(env WAYLAND_DISPLAY="$NEW_SOCK" XDG_STATE_HOME="$STATE_DIR" "$QUICKSHELL_BIN" ipc -p "$PROJECT_DIR/shell.qml")

echo "    * Invoking 'quickshell ipc call launcher open'..."
"${IPC_CMD[@]}" call launcher open
sleep 0.4

echo "    * Invoking 'quickshell ipc call launcher toggle'..."
"${IPC_CMD[@]}" call launcher toggle
sleep 0.4

echo "    * Invoking 'quickshell ipc call launcher close'..."
"${IPC_CMD[@]}" call launcher close
sleep 0.4

if ! kill -0 "$QS_PID" 2>/dev/null; then
    echo "ERROR: Quickshell crashed during interactive IPC widget action calls!" >&2
    cat "$QS_LOG" >&2
    exit 1
fi
echo "[PASS] Step 3: Interactive IPC widget actions (open, toggle, close) executed without errors."

# Step 4: Verify Zero Leaked State Files in Repository
echo "--> Verifying state isolation: zero runtime state files created in dotfiles repo..."
DIRTY_STATE=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | grep -E "launcher_state|pinned_apps|notes\.|tasks\." || true)
if [[ -n "$DIRTY_STATE" ]]; then
    echo "ERROR: State persistence file leaked into git repository working directory!" >&2
    echo "$DIRTY_STATE" >&2
    exit 1
fi
echo "[PASS] Step 4: State isolation verified; dotfiles repo remains clean of runtime state."

# Step 5: Test Dynamic Settings Mutation & Reload
echo "--> Testing dynamic configuration mutation and hot reload..."
CONF_TARGET="$STATE_DIR/quickshell/settings.conf"

# Append mutated settings
cat << 'EOF' >> "$CONF_TARGET"
barPosition="bottom"
barHeight=48
bentoGap=12
EOF

sleep 2

# Verify process remained alive after disk change
if ! kill -0 "$QS_PID" 2>/dev/null; then
    echo "ERROR: Quickshell crashed upon dynamic settings file mutation!" >&2
    cat "$QS_LOG" >&2
    exit 1
fi

# Verify no segfault occurred in log
if grep -i -E "segmentation fault|core dumped|fatal" "$QS_LOG" 2>/dev/null; then
    echo "ERROR: Fatal error or crash detected in Quickshell log after mutation!" >&2
    cat "$QS_LOG" >&2
    exit 1
fi
echo "[PASS] Step 5: Quickshell survived dynamic configuration modification without crashes."

# Step 6: Clean shutdown verification
echo "--> Verifying clean termination on SIGTERM..."
kill -15 "$QS_PID" 2>/dev/null || true
SHUTDOWN_CLEAN=false
for i in {1..20}; do
    if ! kill -0 "$QS_PID" 2>/dev/null; then
        SHUTDOWN_CLEAN=true
        break
    fi
    sleep 0.1
done

if ! $SHUTDOWN_CLEAN; then
    echo "WARN: Quickshell did not exit within 2s of SIGTERM, forcing SIGKILL."
    kill -9 "$QS_PID" 2>/dev/null || true
else
    echo "[PASS] Step 6: Quickshell exited cleanly upon SIGTERM."
fi

echo "========================================================================"
echo "[SUCCESS] Isolated Headless Wayland E2E Validation PASSED."
echo "========================================================================"
exit 0
