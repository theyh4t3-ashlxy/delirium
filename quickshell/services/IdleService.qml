pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

QtObject {
    id: root

    property bool enabled: true

    onEnabledChanged: {
        if (!root.enabled) {
            Quickshell.execDetached(["brightnessctl", "-r"]);
        }
        if (typeof Settings !== "undefined" && Settings?._initialized) {
            Settings.requestOsdShow(
                "caffeine",
                Theme.iconCoffee,
                root.enabled ? 0 : 100,
                root.enabled ? "off" : "awake",
                root.enabled ? "system auto-sleep enabled" : "sleep inhibited (caffeine on)"
            );
        }
    }

    // Must be assigned to a property inside QtObject!
    property IpcHandler ipc: IpcHandler {
        target: "idle_internal"

        function toggle(): bool {
            root.enabled = !root.enabled;
            return root.enabled;
        }

        function status(): bool {
            return root.enabled;
        }

        function set(state: bool): bool {
            root.enabled = state;
            return root.enabled;
        }
    }

    // dim screen on idle
    property IdleMonitor dimMonitor: IdleMonitor {
        enabled: root.enabled && (Settings?.idleDimEnabled ?? true) && (Settings?.idleDimSeconds ?? 150) > 0
        timeout: Math.max(10, Settings?.idleDimSeconds ?? 150)
        respectInhibitors: true
        onIsIdleChanged: {
            if (!root.enabled || !(Settings?.idleDimEnabled ?? true)) return;
            Quickshell.execDetached(isIdle ? ["brightnessctl", "-s", "set", "10%"] : ["brightnessctl", "-r"]);
        }
    }

    // lock screen natively via Quickshell
    property IdleMonitor lockMonitor: IdleMonitor {
        enabled: root.enabled && (Settings?.idleLockEnabled ?? true) && (Settings?.idleLockSeconds ?? 300) > 0
        timeout: Math.max(15, Settings?.idleLockSeconds ?? 300)
        respectInhibitors: true
        onIsIdleChanged: {
            if (!root.enabled || !(Settings?.idleLockEnabled ?? true) || !isIdle) return;
            Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"]);
        }
    }

    // turn off monitors via native Hyprland IPC
    property IdleMonitor dpmsMonitor: IdleMonitor {
        enabled: root.enabled && (Settings?.idleDpmsEnabled ?? true) && (Settings?.idleDpmsSeconds ?? 330) > 0
        timeout: Math.max(20, Settings?.idleDpmsSeconds ?? 330)
        respectInhibitors: true
        onIsIdleChanged: {
            if (!root.enabled || !(Settings?.idleDpmsEnabled ?? true)) return;

            let action = isIdle ? "disable" : "enable";
            Settings.dispatchDpms(action);
        }
    }

    // suspend system
    property IdleMonitor suspendMonitor: IdleMonitor {
        enabled: root.enabled && (Settings?.idleSuspendEnabled ?? true) && (Settings?.idleSuspendSeconds ?? 600) > 0
        timeout: Math.max(30, Settings?.idleSuspendSeconds ?? 600)
        respectInhibitors: true
        onIsIdleChanged: {
            if (!root.enabled || !(Settings?.idleSuspendEnabled ?? true) || !isIdle) return;
            Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }
}
