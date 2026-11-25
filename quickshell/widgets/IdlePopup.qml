import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Io
import "../services"

PopupPanel {
    id: root

    cardWidth: 368
    cardHeight: Math.min(540, idleCol.implicitHeight + (Theme.popupPadding * 2))

    property int remainingSecs: 0
    readonly property bool hasTimer: remainingSecs > 0
    property bool showTimeouts: false

    function formatDurationShort(sec) {
        let s = Math.max(0, Math.round(sec));
        if (s < 60) return s + "s";
        let m = Math.floor(s / 60);
        let rem = s % 60;
        if (rem === 0) return m + "m";
        return m + "m " + rem + "s";
    }

    function stepIdleSetting(propEnabled, propSec, deltaSec, minSec, maxSec) {
        if (!Settings) return;
        let next = Math.max(minSec, Math.min(maxSec, (Settings[propSec] ?? minSec) + deltaSec));
        Settings[propSec] = next;
        if (!Settings[propEnabled]) Settings[propEnabled] = true;
        if (Settings.save) Settings.save();
    }

    function toggleIdleSetting(propEnabled) {
        if (!Settings) return;
        Settings[propEnabled] = !Settings[propEnabled];
        if (Settings.save) Settings.save();
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: root.hasTimer && !IdleService.enabled
        onTriggered: {
            if (root.remainingSecs > 1) {
                root.remainingSecs--;
            } else {
                root.remainingSecs = 0;
                IdleService.enabled = true; // resume normal idle
            }
        }
    }

    function setCaffeineTimer(minutes) {
        if (minutes <= 0) {
            root.remainingSecs = 0;
            IdleService.enabled = false; // keep awake indefinitely
        } else {
            root.remainingSecs = minutes * 60;
            IdleService.enabled = false;
        }
    }

    function formatTime(totalSec) {
        return Theme.formatTime(totalSec, true);
    }

    content: ColumnLayout {
        id: idleCol
        anchors.fill: parent
        spacing: Theme.popupSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: Theme.iconCoffee
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeLg
                color: !IdleService.enabled ? Theme.primary : Theme.on_surface_variant
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "caffeine & sleep inhibitor"
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeMd
                    font.weight: Theme.fontWeightBold
                    color: Theme.on_surface
                }

                Text {
                    text: !IdleService.enabled
                        ? (root.hasTimer ? ("active • " + root.formatTime(root.remainingSecs) + " left") : "active indefinitely")
                        : "system idle sleep enabled"
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: !IdleService.enabled ? Theme.primary : Theme.on_surface_variant
                }
            }

            Rectangle {
                height: 22
                implicitWidth: statusBadge.implicitWidth + 14
                radius: Theme.radiusPill
                color: !IdleService.enabled ? Theme.primary_container : Theme.surface_container_highest

                Text {
                    id: statusBadge
                    anchors.centerIn: parent
                    text: !IdleService.enabled ? "awake" : "sleepable"
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: 10
                    font.weight: Theme.fontWeightBold
                    color: !IdleService.enabled ? Theme.on_primary_container : Theme.on_surface_variant
                }
            }
        }

        // Timer Presets Card
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 96
            radius: Theme.radiusMd
            color: Theme.surface_container
            border.color: Theme.glassBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "keep system awake for:"
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface_variant
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "15m", val: 15 },
                            { label: "30m", val: 30 },
                            { label: "1h", val: 60 },
                            { label: "2h", val: 120 },
                            { label: "always", val: 0 }
                        ]

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            height: 32
                            radius: Theme.radiusSm
                            color: (!IdleService.enabled && ((modelData.val === 0 && !root.hasTimer) || (root.hasTimer && Math.round(root.remainingSecs/60) === modelData.val)))
                                ? Theme.primary : Theme.surface_container_high
                            border.color: Theme.glassBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightMedium
                                color: (!IdleService.enabled && ((modelData.val === 0 && !root.hasTimer) || (root.hasTimer && Math.round(root.remainingSecs/60) === modelData.val)))
                                    ? Theme.on_primary : Theme.on_surface
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setCaffeineTimer(modelData.val)
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 24
                    radius: Theme.radiusSm
                    color: IdleService.enabled ? Theme.primary_container : Theme.surface_container_highest

                    Text {
                        anchors.centerIn: parent
                        text: IdleService.enabled ? "sleep active (click to inhibit)" : "turn off inhibitor (allow sleep)"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.pixelSize: 10
                        font.weight: Theme.fontWeightMedium
                        color: IdleService.enabled ? Theme.on_primary_container : Theme.on_surface
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.remainingSecs = 0;
                            IdleService.enabled = !IdleService.enabled;
                        }
                    }
                }
            }
        }

        // Quick Display Actions
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: Theme.radiusSm
                color: Theme.surface_container_high
                border.color: Theme.glassBorder
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Theme.iconEyeOff
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.on_surface
                    }

                    Text {
                        text: "blank screen"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_surface
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Settings.dispatchDpms("disable");
                        root.open = false;
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: Theme.radiusSm
                color: Theme.surface_container_high
                border.color: Theme.glassBorder
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: Theme.iconLock
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.on_surface
                    }

                    Text {
                        text: "lock now"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_surface
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["qs", "ipc", "call", "lock", "lock"]);
                        root.open = false;
                    }
                }
            }
        }

        // Configurable automatic idle pipeline (dim -> lock -> dpms -> suspend)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: timeoutCol.implicitHeight + 16
            radius: Theme.radiusMd
            color: Theme.surface_container
            border.color: Theme.glassBorder
            border.width: 1

            ColumnLayout {
                id: timeoutCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: Theme.iconSliders
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.primary
                    }

                    Text {
                        text: "auto idle schedule"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.fontWeightBold
                        color: Theme.on_surface
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.showTimeouts ? "hide" : "edit"
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.weight: Theme.monoWeightRegular
                        font.pixelSize: 10
                        color: Theme.primary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showTimeouts = !root.showTimeouts
                    }
                }

                // summary strip when collapsed
                Text {
                    visible: !root.showTimeouts
                    Layout.fillWidth: true
                    text: [
                        "dim " + ((Settings?.idleDimEnabled ?? true) ? root.formatDurationShort(Settings?.idleDimSeconds ?? 150) : "off"),
                        "lock " + ((Settings?.idleLockEnabled ?? true) ? root.formatDurationShort(Settings?.idleLockSeconds ?? 300) : "off"),
                        "dpms " + ((Settings?.idleDpmsEnabled ?? true) ? root.formatDurationShort(Settings?.idleDpmsSeconds ?? 330) : "off"),
                        "sleep " + ((Settings?.idleSuspendEnabled ?? true) ? root.formatDurationShort(Settings?.idleSuspendSeconds ?? 600) : "off")
                    ].join(" • ")
                    font.family: Theme.fontMono
                    font.variableAxes: Theme.monoAxes
                    font.weight: Theme.monoWeightRegular
                    font.pixelSize: 10
                    color: Theme.on_surface_variant
                    elide: Text.ElideRight
                }

                Repeater {
                    model: root.showTimeouts ? [
                        { label: "dim screen",  enKey: "idleDimEnabled",     secKey: "idleDimSeconds",     step: 30, min: 30,  max: 900,  def: 150 },
                        { label: "auto lock",   enKey: "idleLockEnabled",    secKey: "idleLockSeconds",    step: 60, min: 30,  max: 1800, def: 300 },
                        { label: "screen off",  enKey: "idleDpmsEnabled",    secKey: "idleDpmsSeconds",    step: 60, min: 30,  max: 2400, def: 330 },
                        { label: "auto sleep",  enKey: "idleSuspendEnabled", secKey: "idleSuspendSeconds", step: 60, min: 60,  max: 3600, def: 600 }
                    ] : []

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 6

                        readonly property bool isOn: Settings ? Boolean(Settings[modelData.enKey]) : true
                        readonly property int curSec: Settings ? (Settings[modelData.secKey] ?? modelData.def) : modelData.def

                        Rectangle {
                            height: 22
                            width: 38
                            radius: Theme.radiusPill
                            color: parent.isOn ? Theme.primary_overlay : Theme.surface_container_high
                            border.color: parent.isOn ? Theme.primary : Theme.widgetBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: parent.parent.isOn ? "on" : "off"
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 9
                                font.weight: Theme.monoWeightBold
                                color: parent.parent.isOn ? Theme.primary : Theme.on_surface_variant
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleIdleSetting(modelData.enKey)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.weight: Theme.fontWeightRegular
                            font.pixelSize: Theme.fontSizeXs
                            color: parent.isOn ? Theme.on_surface : Theme.on_surface_disabled
                        }

                        IconButton {
                            icon: Theme.iconChevronLeft
                            iconSize: 10
                            implicitWidth: 22
                            implicitHeight: 22
                            tooltip: "-" + modelData.step + "s"
                            onClicked: root.stepIdleSetting(modelData.enKey, modelData.secKey, -modelData.step, modelData.min, modelData.max)
                        }

                        Text {
                            Layout.preferredWidth: 44
                            horizontalAlignment: Text.AlignHCenter
                            text: root.formatDurationShort(parent.curSec)
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.monoWeightBold
                            color: parent.isOn ? Theme.primary : Theme.on_surface_disabled
                        }

                        IconButton {
                            icon: Theme.iconChevronRight
                            iconSize: 10
                            implicitWidth: 22
                            implicitHeight: 22
                            tooltip: "+" + modelData.step + "s"
                            onClicked: root.stepIdleSetting(modelData.enKey, modelData.secKey, modelData.step, modelData.min, modelData.max)
                        }
                    }
                }
            }
        }
    }
}
