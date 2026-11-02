import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

PopupPanel {
    id: root

    cardWidth: 400
    cardHeight: layoutContent.implicitHeight + (Theme.popupPadding * 2)

    property var device: UPower.displayDevice
    // find the actual physical battery in UPower so we can read nativePath and hardware health
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
    readonly property bool isSaver: PowerProfiles.profile === PowerProfile.PowerSaver
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

    property string batKernelName: physicalBattery?.nativePath || ""
    property int cycleCount: 0
    property int startThresh: 0
    property int stopThresh: 100
    property real capFull: 0
    property real capDesign: 0
    property string cpuLoad: "--"
    property bool hasDgpu: false
    property bool showDiagnostics: false

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
        let uFull = physicalBattery?.energyCapacity ?? 0;
        return uFull > 0 ? -1.0 : -1.0;
    }

    readonly property string userTerm: Quickshell.env("TERMINAL") || "kitty"
    readonly property string batteryScript: Qt.resolvedUrl("../scripts/battery.py").toString().replace(/^file:\/\//, "")
    readonly property string sysmonScript: Qt.resolvedUrl("../scripts/sysmon.zsh").toString().replace(/^file:\/\//, "")

    // silent hardware probe via external script
    Process {
        id: hwProbe
        command: ["python3", root.batteryScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = (text || "").trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    let eq = line.indexOf("=");
                    if (eq < 0) continue;
                    let k = line.slice(0, eq).trim();
                    let v = line.slice(eq + 1).trim();

                    switch (k) {
                        case "name": if (v) root.batKernelName = v; break;
                        case "cycles": { let c = parseInt(v); if (!isNaN(c) && c > 0) root.cycleCount = c; break; }
                        case "start": { let st = parseInt(v); if (!isNaN(st)) root.startThresh = st; break; }
                        case "stop": { let sp = parseInt(v); if (!isNaN(sp) && sp > 0) root.stopThresh = sp; break; }
                        case "full": { let f = parseFloat(v); if (!isNaN(f) && f > 0) root.capFull = f; break; }
                        case "design": { let d = parseFloat(v); if (!isNaN(d) && d > 0) root.capDesign = d; break; }
                        case "load": if (v) root.cpuLoad = v; break;
                        case "gpus": { let g = parseInt(v); if (!isNaN(g)) root.hasDgpu = g > 1; break; }
                    }
                }
            }
        }
    }

    function refreshHardwareStats() {
        if (!hwProbe.running) {
            hwProbe.running = true;
        }
    }

    onOpenChanged: {
        if (open) {
            refreshHardwareStats();
        }
    }

    // reusable squishy power profile pill
    component ProfilePill: Rectangle {
        id: pPill
        property string label: ""
        property string icon: ""
        property bool isCurrent: false
        property bool available: true
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 36
        implicitHeight: 36
        opacity: available ? 1.0 : 0.38
        radius: isCurrent ? Theme.radiusMd : Theme.radiusPill
        color: isCurrent
            ? Theme.primary_overlay
            : (pMouse.pressed ? Theme.widgetActive : (pMouse.containsMouse && available ? Theme.widgetHover : Theme.widgetBg))
        border.color: isCurrent
            ? Theme.alpha(Theme.primary, 0.65)
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
                font.pixelSize: Theme.fontSizeXs
                color: pPill.isCurrent ? Theme.primary : Theme.textSecondary
            }

            Text {
                text: pPill.label
                font.family: Theme.fontFamily
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

    content: ColumnLayout {
        id: layoutContent
        anchors.fill: parent
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
                    font.pixelSize: Theme.fontSizeMd
                    font.weight: Theme.fontWeightBold
                    color: Theme.textPrimary
                }

                Text {
                    text: {
                        let prof = "balanced";
                        if (root.isSaver) prof = "power-saver";
                        else if (PowerProfiles.profile === PowerProfile.Performance) prof = "performance";
                        let devTag = root.batKernelName ? (root.batKernelName.toLowerCase() + " • ") : "";
                        return devTag + prof + " mode";
                    }
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textSecondary
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
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightBold
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
            implicitHeight: gaugeCol.implicitHeight + 24
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
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: root.pct + "%"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Math.round(34 * Theme.fontScale)
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
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                        }
                    }

                    Rectangle {
                        visible: root.watts > 0
                        height: 24
                        implicitWidth: wattTxt.implicitWidth + 14
                        radius: Theme.radiusPill
                        color: Theme.pillBg
                        border.color: Theme.pillBorder
                        border.width: 1

                        Text {
                            id: wattTxt
                            anchors.centerIn: parent
                            text: (root.isCharging ? "+" : "-") + root.watts + " W"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: root.batAccent
                        }
                    }
                }

                // chunky pill gauge with charge threshold marker
                Rectangle {
                    Layout.fillWidth: true
                    height: 14
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

                    // stop threshold marker line
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
                        label: "charge limit",
                        val: (root.stopThresh > 0 && root.stopThresh < 100) ? (root.stopThresh + "%") : "100%",
                        icon: Theme.iconShield
                    }
                ]

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 62
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
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.primary
                            }

                            Text {
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                            }
                        }

                        Text {
                            text: modelData.val
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeMd
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }

        // power profile daemon card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: ppdCol.implicitHeight + 20
            radius: Theme.radiusLg
            color: Theme.cardBg
            border.color: Theme.cardBorder
            border.width: 1

            ColumnLayout {
                id: ppdCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "power profile"
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightBold
                    color: Theme.textSecondary
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    ProfilePill {
                        label: "saver"
                        icon: Theme.iconMoon
                        isCurrent: root.isSaver
                        onClicked: PowerProfiles.profile = PowerProfile.PowerSaver
                    }

                    ProfilePill {
                        label: "balanced"
                        icon: Theme.iconSparkles
                        isCurrent: PowerProfiles.profile === PowerProfile.Balanced
                        onClicked: PowerProfiles.profile = PowerProfile.Balanced
                    }

                    ProfilePill {
                        label: "performance"
                        icon: Theme.iconFlame
                        available: PowerProfiles.hasPerformanceProfile
                        isCurrent: PowerProfiles.profile === PowerProfile.Performance
                        onClicked: PowerProfiles.profile = PowerProfile.Performance
                    }
                }
            }
        }

        // collapsible diagnostics toggle pill
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            radius: Theme.radiusPill
            color: mouseDiag.containsMouse ? Theme.pillHover : Theme.pillBg
            border.color: root.showDiagnostics ? Theme.alpha(Theme.primary, 0.45) : Theme.pillBorder
            border.width: (root.showDiagnostics || Theme.pillBorder.a > 0) ? 1 : 0

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: root.showDiagnostics ? Theme.iconChevronUp : Theme.iconChevronDown
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.primary
                }

                Text {
                    text: root.showDiagnostics
                        ? "hide system monitors"
                        : ("system monitors  •  load " + root.cpuLoad)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightMedium
                    color: Theme.textSecondary
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

        // smooth animated monitor launchers drawer
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.showDiagnostics ? 36 : 0
            visible: Layout.preferredHeight > 0
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation {
                    duration: Theme.animFast
                    easing.type: Theme.animEasing
                }
            }

            RowLayout {
                anchors.fill: parent
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
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.primary
                        }

                        Text {
                            text: "nvtop (gpu)"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
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
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.primary
                        }

                        Text {
                            text: "btop  •  load " + root.cpuLoad
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
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
