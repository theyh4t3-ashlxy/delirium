import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

PopupPanel {
    id: root

    cardWidth: 420
    cardHeight: Math.min(Theme.popupMaxHeight ?? 720, Math.round(layoutContent.implicitHeight + (Theme.popupPadding * 2)))

    property var device: UPower.displayDevice
    readonly property var physicalBattery: {
        let list = UPower.devices?.values ?? [];
        return list.find(d => d && d.isLaptopBattery)
            ?? list.find(d => d && d.nativePath && /^(BAT|CMB|macsmc)/i.test(d.nativePath))
            ?? device;
    }

    readonly property bool onBattery: UPower.onBattery ?? true
    readonly property int pct: Math.min(100, Math.max(0, Math.round((device?.percentage ?? 0) * 100)))
    readonly property bool isCharging: device?.state === UPowerDeviceState.Charging || device?.state === UPowerDeviceState.PendingCharge
    readonly property bool isFull: device?.state === UPowerDeviceState.FullyCharged || (pct >= 99 && !onBattery)

    // unified hardware + power profile state (supports TLP+ACPI, cpufreq, and PPD)
    property string powerBackend: "acpi"
    property string activeProfile: {
        if (typeof PowerProfiles !== "undefined" && powerBackend === "ppd") {
            if (PowerProfiles.profile === PowerProfile.PowerSaver) return "power-saver";
            if (PowerProfiles.profile === PowerProfile.Performance) return "performance";
        }
        return "balanced";
    }
    property var availableProfiles: ["power-saver", "balanced", "performance"]
    readonly property bool isSaver: activeProfile === "power-saver"
    readonly property bool hasPerfProfile: availableProfiles.indexOf("performance") !== -1

    property string eppMode: ""
    property var eppChoices: []
    property bool turboAvailable: false
    property bool turboEnabled: true

    property string batKernelName: physicalBattery?.nativePath || ""
    property int cycleCount: 0
    property int startThresh: 0
    property int stopThresh: 100
    property real capFull: 0
    property real capDesign: 0
    property real voltageV: 0
    property string cpuLoad: "--"
    property bool hasDgpu: false
    property string dgpuState: ""

    // ThinkPad fanctl telemetry
    property bool fanAvailable: false
    property real cpuTemp: 0
    property real nvmeTemp: 0
    property int fanRpm: 0
    property string fanLevel: "auto"
    property string fanMode: "auto"
    property string curveProfile: "balanced"
    property int cpuMhz: 0
    property bool isCpuLocked: false
    property bool isShocking: false

    property bool showDiagnostics: false
    property bool actionBusy: false
    property string actionError: ""

    readonly property color batAccent: {
        if (isCharging) return Theme.primary;
        if (pct <= 15) return Theme.error;
        if (pct <= 30) return Theme.warn;
        return Theme.primary;
    }

    readonly property real watts: {
        let rate = Math.abs(device?.changeRate ?? physicalBattery?.changeRate ?? 0);
        return rate > 0 ? (Math.round(rate * 10) / 10) : 0.0;
    }

    readonly property real batteryHealth: {
        if (capDesign > 0 && capFull > 0) {
            return Math.min(100, Math.round((capFull / capDesign) * 1000) / 10);
        }
        if (physicalBattery?.healthSupported && physicalBattery?.healthPercentage > 0) {
            return Math.round(physicalBattery.healthPercentage * 10) / 10;
        }
        if (device?.healthSupported && device?.healthPercentage > 0) {
            return Math.round(device.healthPercentage * 10) / 10;
        }
        return -1.0;
    }

    readonly property string userTerm: Quickshell.env("TERMINAL") || "kitty"
    readonly property string batteryScript: decodeURIComponent(Qt.resolvedUrl("../scripts/battery.py").toString().replace(/^file:\/\//, ""))
    readonly property string sysmonScript: decodeURIComponent(Qt.resolvedUrl("../scripts/sysmon.zsh").toString().replace(/^file:\/\//, ""))

    function formatWh(rawVal) {
        if (!rawVal || rawVal <= 0) return "";
        // energy_* in sysfs is microWatt-hours
        let wh = rawVal > 100000 ? (rawVal / 1000000.0) : rawVal;
        return wh.toFixed(1);
    }

    function applyProbeText(text) {
        const lines = (text || "").trim().split("\n");
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            let eq = line.indexOf("=");
            if (eq < 0) continue;
            let k = line.slice(0, eq).trim();
            let v = line.slice(eq + 1).trim();

            switch (k) {
                case "name": if (v) root.batKernelName = v; break;
                case "cycles": { let c = parseInt(v, 10); if (!isNaN(c) && c > 0) root.cycleCount = c; break; }
                case "start": { let st = parseInt(v, 10); if (!isNaN(st)) root.startThresh = st; break; }
                case "stop": { let sp = parseInt(v, 10); if (!isNaN(sp) && sp > 0) root.stopThresh = sp; break; }
                case "full": { let f = parseFloat(v); if (!isNaN(f) && f > 0) root.capFull = f; break; }
                case "design": { let d = parseFloat(v); if (!isNaN(d) && d > 0) root.capDesign = d; break; }
                case "voltage": { let vv = parseFloat(v); if (!isNaN(vv) && vv > 0) root.voltageV = vv; break; }
                case "load": if (v) root.cpuLoad = v; break;
                case "gpus": { let g = parseInt(v, 10); if (!isNaN(g)) root.hasDgpu = g > 1; break; }
                case "dgpu_state": root.dgpuState = v; break;
                case "backend": if (v) root.powerBackend = v; break;
                case "profile": if (v) root.activeProfile = v; break;
                case "choices": {
                    let arr = v.split(/\s+/).filter(Boolean);
                    if (arr.length > 0) root.availableProfiles = arr;
                    break;
                }
                case "epp": root.eppMode = v; break;
                case "epp_choices": root.eppChoices = v.split(/\s+/).filter(Boolean); break;
                case "turbo":
                    root.turboAvailable = true;
                    root.turboEnabled = (v === "1");
                    break;
                case "fan_available": root.fanAvailable = (v === "1"); break;
                case "cpu_temp": { let ct = parseFloat(v); if (!isNaN(ct)) root.cpuTemp = ct; break; }
                case "nvme_temp": { let nt = parseFloat(v); if (!isNaN(nt)) root.nvmeTemp = nt; break; }
                case "fan_rpm": { let rpm = parseInt(v, 10); if (!isNaN(rpm)) root.fanRpm = rpm; break; }
                case "fan_level": root.fanLevel = v; break;
                case "fan_mode": root.fanMode = v; break;
                case "curve_profile": root.curveProfile = v; break;
                case "cpu_mhz": { let mhz = parseInt(v, 10); if (!isNaN(mhz)) root.cpuMhz = mhz; break; }
                case "cpu_locked": root.isCpuLocked = (v === "1"); break;
                case "is_shocking": root.isShocking = (v === "1"); break;
            }
        }
    }

    Process {
        id: hwProbe
        command: ["python3", root.batteryScript, "probe"]
        stdout: StdioCollector {
            onStreamFinished: root.applyProbeText(text)
        }
    }

    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.actionBusy = false;
                let ok = true;
                let err = "";
                const lines = (text || "").trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    let eq = line.indexOf("=");
                    if (eq < 0) continue;
                    let k = line.slice(0, eq).trim();
                    let v = line.slice(eq + 1).trim();
                    if (k === "ok") ok = (v === "true");
                    else if (k === "error") err = v;
                }
                root.actionError = ok ? "" : (err || "action rejected by system");
                root.refreshHardwareStats();
            }
        }
    }

    Timer {
        id: livePollTimer
        interval: 2500
        repeat: true
        running: root.open
        onTriggered: root.refreshHardwareStats()
    }

    function refreshHardwareStats() {
        if (!hwProbe.running) {
            hwProbe.running = true;
        }
    }

    function runBatteryAction(args) {
        root.actionError = "";
        root.actionBusy = true;
        if (actionProc.running) actionProc.running = false;
        actionProc.command = ["python3", root.batteryScript].concat(args);
        actionProc.running = true;
    }

    function switchPowerProfile(profileId) {
        if (root.availableProfiles.indexOf(profileId) === -1) return;
        root.activeProfile = profileId;
        if (root.powerBackend === "ppd" && typeof PowerProfiles !== "undefined") {
            if (profileId === "power-saver") PowerProfiles.profile = PowerProfile.PowerSaver;
            else if (profileId === "performance") PowerProfiles.profile = PowerProfile.Performance;
            else PowerProfiles.profile = PowerProfile.Balanced;
        }
        if (typeof Settings !== "undefined" && Settings?.requestOsdShow) {
            let icon = profileId === "power-saver" ? Theme.iconMoon : (profileId === "performance" ? Theme.iconFlame : Theme.iconSparkles);
            let val = profileId === "power-saver" ? 33 : (profileId === "balanced" ? 66 : 100);
            Settings.requestOsdShow("power", icon, val, profileId.replace("power-", ""), "backend: " + root.powerBackend);
        }
        runBatteryAction(["set-profile", profileId]);
    }

    Component.onCompleted: refreshHardwareStats()

    onOpenChanged: {
        if (open) {
            root.actionError = "";
            refreshHardwareStats();
        }
    }

    component ProfilePill: Rectangle {
        id: pPill
        property string label: ""
        property string icon: ""
        property bool isCurrent: false
        property bool available: true
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 34
        implicitHeight: 34
        opacity: available ? 1.0 : 0.38
        radius: isCurrent ? Theme.radiusMd : Theme.radiusPill
        color: isCurrent
            ? Theme.primary_overlay
            : (pMouse.pressed ? Theme.widgetActive : (pMouse.containsMouse && available ? Theme.widgetHover : Theme.widgetBg))
        border.color: isCurrent
            ? Theme.alpha(Theme.primary, 0.72)
            : (pMouse.containsMouse && available ? Theme.alpha(Theme.primary, 0.35) : Theme.widgetBorder)
        border.width: 1

        Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 5

            Text {
                visible: pPill.icon !== ""
                text: pPill.icon
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeXs
                color: pPill.isCurrent ? Theme.primary : Theme.textSecondary
            }

            Text {
                text: pPill.label
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.pixelSize: Theme.fontSizeXs
                font.weight: pPill.isCurrent ? Theme.fontWeightBold : Theme.fontWeightMedium
                color: pPill.isCurrent ? Theme.primary : Theme.textSecondary
            }
        }

        MouseArea {
            id: pMouse
            anchors.fill: parent
            hoverEnabled: pPill.available
            cursorShape: pPill.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (pPill.available) pPill.clicked();
            }
        }
    }

    component MiniActionChip: Rectangle {
        id: mc
        property string label: ""
        property string icon: ""
        property bool selected: false
        property bool danger: false
        property bool fillWidth: true
        signal clicked()

        Layout.fillWidth: fillWidth
        Layout.preferredHeight: 24
        implicitWidth: mcRow.implicitWidth + 14
        radius: Theme.radiusPill
        color: {
            if (mcMouse.pressed) return danger ? Theme.error : Theme.primary;
            if (selected) return danger ? Theme.error_overlay : Theme.primary_overlay;
            return mcMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg;
        }
        border.width: 1
        border.color: {
            if (selected) return danger ? Theme.error : Theme.primary;
            return mcMouse.containsMouse ? Theme.alpha(danger ? Theme.error : Theme.primary, 0.5) : Theme.widgetBorder;
        }

        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            id: mcRow
            anchors.centerIn: parent
            spacing: 4

            Text {
                visible: mc.icon !== "" && !Theme.isTextIconSet
                text: mc.icon
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeXs
                color: mcMouse.pressed
                    ? (mc.danger ? Theme.on_error : Theme.on_primary)
                    : (mc.danger ? Theme.error : (mc.selected ? Theme.primary : Theme.textSecondary))
            }

            Text {
                text: mc.label
                font.family: Theme.fontMono
                font.variableAxes: Theme.monoAxes
                font.pixelSize: 10
                font.weight: mc.selected ? Theme.monoWeightBold : Theme.monoWeightMedium
                color: mcMouse.pressed
                    ? (mc.danger ? Theme.on_error : Theme.on_primary)
                    : (mc.danger ? Theme.error : (mc.selected ? Theme.primary : Theme.textSecondary))
            }
        }

        MouseArea {
            id: mcMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mc.clicked()
        }
    }

    content: Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: layoutContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: layoutContent
            width: parent.width
            spacing: Theme.popupSpacing

            // top header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 36
                    height: 36
                    radius: Theme.radiusMd
                    color: Theme.alpha(root.batAccent, 0.16)
                    border.color: Theme.alpha(root.batAccent, 0.4)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Theme.getBatteryIcon(root.pct, root.isCharging, root.isSaver, false)
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeLg
                        color: root.batAccent
                    }
                }

                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true

                    Text {
                        text: "battery & power"
                        font.family: Theme.fontDisplay
                        font.variableAxes: Theme.displayAxes
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.textPrimary
                    }

                    Text {
                        text: {
                            let devTag = root.batKernelName ? (root.batKernelName.toLowerCase() + " • ") : "";
                            return devTag + root.activeProfile + " (" + root.powerBackend + ")";
                        }
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.weight: Theme.monoWeightRegular
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    height: 24
                    implicitWidth: badgeText.implicitWidth + 14
                    radius: Theme.radiusPill
                    color: Theme.alpha(root.batAccent, 0.18)
                    border.color: Theme.alpha(root.batAccent, 0.5)
                    border.width: 1

                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: root.isFull ? "full" : (root.isCharging ? "charging" : (root.pct + "%"))
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.monoWeightBold
                        color: root.batAccent
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.popupDividerHeight
                color: Theme.widgetBorder
            }

            // live hero gauge card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: gaugeCol.implicitHeight + 22
                radius: Theme.radiusLg
                color: Theme.blend(Theme.cardBg, root.batAccent, root.isCharging ? 0.14 : 0.05)
                border.color: Theme.alpha(root.batAccent, root.isCharging ? 0.4 : 0.22)
                border.width: 1

                Behavior on color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }
                Behavior on border.color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }

                ColumnLayout {
                    id: gaugeCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 11
                    spacing: 9

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: root.pct + "%"
                            font.family: Theme.fontDisplay
                            font.variableAxes: Theme.displayAxes
                            font.pixelSize: Math.round(32 * Theme.fontScale)
                            font.weight: Theme.fontWeightBold
                            color: root.batAccent
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: {
                                    if (root.isFull) return "connected to ac power";
                                    if (root.isCharging) return "charging on ac power";
                                    return "running on battery";
                                }
                                font.family: Theme.fontDisplay
                                font.variableAxes: Theme.displayAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: Theme.textPrimary
                            }

                            Text {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: {
                                    if (root.isFull) {
                                        return Theme.getFlavor("battery_full", "cells balanced and full");
                                    }
                                    if (root.isCharging) {
                                        let sec = root.device?.timeToFull ?? root.physicalBattery?.timeToFull ?? 0;
                                        let fallback = sec > 0 ? (Theme.formatUptime(sec) + " until full") : "charging";
                                        return Theme.getFlavor("battery_charging", fallback);
                                    }
                                    let sec = root.device?.timeToEmpty ?? root.physicalBattery?.timeToEmpty ?? 0;
                                    let fallback = sec > 0 ? (Theme.formatUptime(sec) + " remaining") : "discharging";
                                    if (root.pct <= 20) return Theme.getFlavor("battery_low", fallback);
                                    return fallback;
                                }
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.alignment: Qt.AlignRight

                            Rectangle {
                                visible: root.watts > 0
                                height: 22
                                implicitWidth: wattTxt.implicitWidth + 12
                                radius: Theme.radiusPill
                                color: Theme.pillBg
                                border.color: Theme.pillBorder
                                border.width: 1
                                Layout.alignment: Qt.AlignRight

                                Text {
                                    id: wattTxt
                                    anchors.centerIn: parent
                                    text: (root.isCharging ? "+" : "-") + root.watts + " W"
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.monoWeightBold
                                    color: root.batAccent
                                }
                            }

                            Text {
                                visible: root.voltageV > 0 || (root.capFull > 0 && root.capDesign > 0)
                                Layout.alignment: Qt.AlignRight
                                text: {
                                    let parts = [];
                                    if (root.capFull > 0 && root.capDesign > 0) {
                                        parts.push(root.formatWh(root.capFull) + "/" + root.formatWh(root.capDesign) + "Wh");
                                    }
                                    if (root.voltageV > 0) {
                                        parts.push(root.voltageV.toFixed(1) + "V");
                                    }
                                    return parts.join(" • ");
                                }
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 9
                                color: Theme.textSecondary
                            }
                        }
                    }

                    // pill gauge with charge threshold marker
                    Rectangle {
                        Layout.fillWidth: true
                        height: 12
                        radius: Theme.radiusPill
                        color: Theme.widgetBg
                        border.color: Theme.widgetBorder
                        border.width: 1
                        clip: true

                        Rectangle {
                            width: Math.max(parent.height, parent.width * (root.pct / 100.0))
                            height: parent.height
                            radius: Theme.radiusPill
                            color: root.batAccent

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.animNormal
                                    easing.type: Theme.animEasing
                                }
                            }
                        }

                        Rectangle {
                            visible: root.stopThresh > 0 && root.stopThresh < 100
                            x: Math.round(parent.width * (root.stopThresh / 100.0)) - 1
                            width: 2
                            height: parent.height
                            color: Theme.textPrimary
                            opacity: 0.85
                        }
                    }
                }
            }

            // hardware telemetry bento row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        {
                            label: "health",
                            val: root.batteryHealth > 0 ? (root.batteryHealth.toFixed(1) + "%") : "--",
                            icon: Theme.iconHeart
                        },
                        {
                            label: "cycles",
                            val: root.cycleCount > 0 ? String(root.cycleCount) : "--",
                            icon: Theme.iconRefresh
                        },
                        {
                            label: "charge cap",
                            val: (root.stopThresh > 0 && root.stopThresh < 100) ? (root.startThresh + "–" + root.stopThresh + "%") : "100%",
                            icon: Theme.iconShield
                        }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 58
                        radius: Theme.radiusMd
                        color: Theme.cardBg
                        border.color: Theme.cardBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 4

                                Text {
                                    text: modelData.icon
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.primary
                                }

                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.weight: Theme.fontWeightRegular
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textSecondary
                                }
                            }

                            Text {
                                text: modelData.val
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.monoWeightBold
                                color: Theme.textPrimary
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }

            // display brightness card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: brightCol.implicitHeight + 18
                radius: Theme.radiusLg
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1

                ColumnLayout {
                    id: brightCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 10
                    spacing: 7

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: Theme.iconSun
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.primary
                        }

                        Text {
                            text: "display brightness"
                            font.family: Theme.fontDisplay
                            font.variableAxes: Theme.displayAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.textSecondary
                            Layout.fillWidth: true
                        }

                        Text {
                            text: (BrightnessService?.percent ?? 0) + "%"
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.monoWeightBold
                            color: Theme.primary
                        }
                    }

                    Slider {
                        Layout.fillWidth: true
                        from: 1
                        to: 100
                        stepSize: 1
                        showValue: false
                        value: BrightnessService?.percent ?? 50
                        accentColor: Theme.primary
                        onMoved: (val) => BrightnessService.setBrightnessPercent(Math.round(val))
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [25, 50, 75, 100]

                            delegate: Rectangle {
                                required property int modelData
                                readonly property bool isCur: Math.abs((BrightnessService?.percent ?? 0) - modelData) <= 3
                                Layout.fillWidth: true
                                height: 22
                                radius: Theme.radiusPill
                                color: isCur
                                    ? Theme.primary_overlay
                                    : (bChipMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                border.color: isCur ? Theme.alpha(Theme.primary, 0.65) : Theme.widgetBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData + "%"
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: 10
                                    font.weight: isCur ? Theme.monoWeightBold : Theme.monoWeightMedium
                                    color: isCur ? Theme.primary : Theme.textSecondary
                                }

                                MouseArea {
                                    id: bChipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: BrightnessService.setBrightnessPercent(modelData)
                                }
                            }
                        }
                    }
                }
            }

            // power profile, intel epp, turbo & battery threshold card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: ppdCol.implicitHeight + 18
                radius: Theme.radiusLg
                color: Theme.cardBg
                border.color: root.isCpuLocked ? Theme.error : Theme.cardBorder
                border.width: 1

                ColumnLayout {
                    id: ppdCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "power profile"
                            font.family: Theme.fontDisplay
                            font.variableAxes: Theme.displayAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.textSecondary
                            Layout.fillWidth: true
                        }

                        Text {
                            visible: root.eppMode !== ""
                            text: root.eppMode.replace("balance_", "bal-")
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: 9
                            color: Theme.primary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ProfilePill {
                            label: "saver"
                            icon: Theme.iconMoon
                            available: root.availableProfiles.indexOf("power-saver") !== -1
                            isCurrent: root.activeProfile === "power-saver"
                            onClicked: root.switchPowerProfile("power-saver")
                        }

                        ProfilePill {
                            label: "balanced"
                            icon: Theme.iconSparkles
                            available: root.availableProfiles.indexOf("balanced") !== -1
                            isCurrent: root.activeProfile === "balanced"
                            onClicked: root.switchPowerProfile("balanced")
                        }

                        ProfilePill {
                            label: "performance"
                            icon: Theme.iconFlame
                            available: root.hasPerfProfile
                            isCurrent: root.activeProfile === "performance"
                            onClicked: root.switchPowerProfile("performance")
                        }
                    }

                    // Intel EPP + Turbo boost controls + charge limit presets
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        MiniActionChip {
                            visible: root.turboAvailable
                            icon: Theme.iconFlame
                            label: root.turboEnabled ? "turbo on" : "turbo off"
                            selected: root.turboEnabled
                            onClicked: root.runBatteryAction(["set-turbo", root.turboEnabled ? "off" : "on"])
                        }

                        MiniActionChip {
                            label: "cap 80%"
                            selected: root.stopThresh === 80
                            onClicked: root.runBatteryAction(["set-thresholds", "75", "80"])
                        }

                        MiniActionChip {
                            label: "travel 90%"
                            selected: root.stopThresh === 90
                            onClicked: root.runBatteryAction(["set-thresholds", "85", "90"])
                        }

                        MiniActionChip {
                            label: "full 100%"
                            selected: root.stopThresh >= 100
                            onClicked: root.runBatteryAction(["set-thresholds", "95", "100"])
                        }
                    }

                    // actionable feedback if privilege elevation was rejected
                    Rectangle {
                        visible: root.actionError !== ""
                        Layout.fillWidth: true
                        implicitHeight: errTxt.implicitHeight + 10
                        radius: Theme.radiusSm
                        color: Theme.error_overlay
                        border.color: Theme.error
                        border.width: 1

                        Text {
                            id: errTxt
                            anchors.fill: parent
                            anchors.margins: 5
                            text: root.actionError
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: 9
                            color: Theme.error
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // collapsible ThinkPad thermals, fan curve & system monitors pill
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: Theme.radiusPill
                color: root.isCpuLocked
                    ? Theme.error_overlay
                    : (mouseDiag.containsMouse ? Theme.pillHover : Theme.pillBg)
                border.color: root.isCpuLocked
                    ? Theme.error
                    : (root.showDiagnostics ? Theme.alpha(Theme.primary, 0.45) : Theme.pillBorder)
                border.width: (root.showDiagnostics || root.isCpuLocked || Theme.pillBorder.a > 0) ? 1 : 0

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: root.showDiagnostics ? Theme.iconChevronUp : Theme.iconChevronDown
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeXs
                        color: root.isCpuLocked ? Theme.error : Theme.primary
                    }

                    Text {
                        text: {
                            if (root.isCpuLocked) return "400mhz lock detected • click to unstick";
                            let bits = [];
                            if (root.cpuTemp > 0) bits.push(root.cpuTemp.toFixed(0) + "°C");
                            if (root.fanRpm > 0) bits.push(root.fanRpm + " rpm");
                            if (root.cpuMhz > 0) bits.push(root.cpuMhz + " mhz");
                            bits.push("load " + root.cpuLoad);
                            return root.showDiagnostics ? "hide hardware & monitors" : bits.join("  •  ");
                        }
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.monoWeightMedium
                        color: root.isCpuLocked ? Theme.error : Theme.textSecondary
                    }
                }

                MouseArea {
                    id: mouseDiag
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showDiagnostics = !root.showDiagnostics
                }
            }

            // ThinkPad thermals, fanctl curve switcher, dGPU state & btop/nvtop launchers
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.showDiagnostics
                spacing: 8

                Rectangle {
                    visible: root.fanAvailable || root.dgpuState !== ""
                    Layout.fillWidth: true
                    implicitHeight: thermCol.implicitHeight + 16
                    radius: Theme.radiusMd
                    color: Theme.cardBg
                    border.color: root.isCpuLocked ? Theme.error : Theme.cardBorder
                    border.width: 1

                    ColumnLayout {
                        id: thermCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 7

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: Theme.iconThermo
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeXs
                                color: root.cpuTemp >= 78 ? Theme.error : Theme.primary
                            }

                            Text {
                                text: {
                                    let segs = [];
                                    if (root.cpuTemp > 0) segs.push("cpu " + root.cpuTemp.toFixed(1) + "°c");
                                    if (root.nvmeTemp > 0) segs.push("nvme " + root.nvmeTemp.toFixed(0) + "°c");
                                    if (root.fanAvailable) segs.push("fan " + root.fanRpm + " rpm (" + root.fanMode + ")");
                                    return segs.join(" • ");
                                }
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 10
                                font.weight: Theme.monoWeightMedium
                                color: Theme.textPrimary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: root.dgpuState !== ""
                                text: "dgpu: " + root.dgpuState
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 9
                                font.weight: Theme.monoWeightBold
                                color: root.dgpuState === "active" ? Theme.warn : Theme.primary
                            }
                        }

                        RowLayout {
                            visible: root.fanAvailable
                            Layout.fillWidth: true
                            spacing: 4

                            MiniActionChip {
                                label: "auto"
                                selected: root.fanMode === "auto"
                                onClicked: root.runBatteryAction(["fan-level", "auto"])
                            }

                            MiniActionChip {
                                label: "quiet"
                                selected: root.fanMode === "curve" && root.curveProfile === "quiet"
                                onClicked: root.runBatteryAction(["fan-curve", "quiet"])
                            }

                            MiniActionChip {
                                label: "balanced"
                                selected: root.fanMode === "curve" && root.curveProfile === "balanced"
                                onClicked: root.runBatteryAction(["fan-curve", "balanced"])
                            }

                            MiniActionChip {
                                label: "aggr"
                                selected: root.fanMode === "curve" && root.curveProfile === "aggressive"
                                onClicked: root.runBatteryAction(["fan-curve", "aggressive"])
                            }

                            MiniActionChip {
                                label: "max"
                                selected: root.fanMode === "full-speed"
                                onClicked: root.runBatteryAction(["fan-level", "full-speed"])
                            }

                            MiniActionChip {
                                label: root.isShocking ? "shock..." : "unstick"
                                danger: root.isCpuLocked
                                selected: root.isCpuLocked || root.isShocking
                                onClicked: root.runBatteryAction(["fan-unstick"])
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    spacing: 8

                    Rectangle {
                        visible: root.hasDgpu
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusMd
                        color: mouseNvtop.containsMouse ? Theme.widgetHover : Theme.widgetBg
                        border.color: mouseNvtop.containsMouse ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Theme.iconTerminal
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.primary
                            }

                            Text {
                                text: "nvtop (gpu)"
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.monoWeightBold
                                color: Theme.textPrimary
                            }
                        }

                        MouseArea {
                            id: mouseNvtop
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached([root.userTerm, "-e", root.sysmonScript, "gpu"]);
                                root.open = false;
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusMd
                        color: mouseBtop.containsMouse ? Theme.widgetHover : Theme.widgetBg
                        border.color: mouseBtop.containsMouse ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Theme.iconCpu
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.primary
                            }

                            Text {
                                text: "btop  •  load " + root.cpuLoad
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.monoWeightBold
                                color: Theme.textPrimary
                            }
                        }

                        MouseArea {
                            id: mouseBtop
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Quickshell.execDetached([root.userTerm, "-e", root.sysmonScript, "cpu"]);
                                root.open = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
