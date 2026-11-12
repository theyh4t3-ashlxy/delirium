// Bluetooth.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland

Rectangle {
    id: root

    property var barScreen: null
    property var barMonitor: null

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isBento
    readonly property int effectiveBarMargin: isFloatingBar ? ((Settings?.barMargin > 0) ? Settings.barMargin : 8) : 0

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool isPowered: adapter ? adapter.enabled : false
    readonly property bool isDiscovering: adapter ? adapter.discovering : false

    readonly property var rawDevices: (root.isPowered && root.adapter?.devices?.values) ? root.adapter.devices.values : []

    function isRealDeviceName(name, addr) {
        if (!name) return false;
        let trimmed = name.trim();
        if (trimmed === "" || trimmed === addr) return false;
        // bluez loves naming unnamed BLE beacons "74-13-EA-5E-A4" with dashes instead of colons
        return !/^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/.test(trimmed);
    }

    readonly property var sortedDevices: {
        let list = [];
        for (let i = 0; i < rawDevices.length; i++) {
            let d = rawDevices[i];
            if (!d) continue;
            if (!d.connected && !d.paired && !root.isRealDeviceName(d.name, d.address)) continue;
            list.push(d);
        }
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return (a.name || a.address || "").localeCompare(b.name || b.address || "");
        });
        return list;
    }

    readonly property var connectedDevices: sortedDevices.filter(d => d.connected)
    readonly property bool hasConnectedDevice: connectedDevices.length > 0
    readonly property string primaryDeviceName: hasConnectedDevice ? (connectedDevices[0].name || "connected").toLowerCase() : ""

    implicitWidth: {
        if (Theme.isVertical) return Theme.barHeight - 8;
        if (btMouse.containsMouse || popup.open || root.hasConnectedDevice) return btRow.implicitWidth + 20;
        return Theme.barHeight - 8;
    }
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radiusPill

    color: {
        if (btMouse.pressed) return Theme.widgetActive;
        if (popup.open) return Theme.primary_overlay;
        if (btMouse.containsMouse) return Theme.pillHover;
        return Theme.pillBg;
    }
    border.color: popup.open ? Theme.primary : Theme.pillBorder
    border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1
    clip: true

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

    function getDeviceBatteryPct(dev) {
        if (!dev || !dev.connected) return -1;
        if (dev.batteryAvailable !== undefined && !dev.batteryAvailable) return -1;
        let b = dev.battery;
        if (b === undefined || b === null || isNaN(b) || b <= 0) return -1;
        return b <= 1.0 ? Math.round(b * 100) : Math.round(b);
    }

    function getDeviceIcon(dev) {
        if (!dev) return Theme.iconBluetooth;
        let n = ((dev.name ?? "") + " " + (dev.icon ?? "") + " " + (dev.iconName ?? "")).toLowerCase();
        if (n.includes("headphone") || n.includes("headset") || n.includes("buds") || n.includes("airpods")
            || n.includes("audio") || n.includes("jlab") || n.includes("studio") || n.includes("soundcore")
            || n.includes("sony") || n.includes("bose") || n.includes("beats") || n.includes("wh-") || n.includes("wf-")) {
            return Theme.iconHeadphones;
        }
        if (n.includes("keyboard") || n.includes("keychron") || n.includes("hhkb")) {
            return Theme.iconKeyboard;
        }
        return dev.connected ? Theme.iconBluetoothConnected : Theme.iconBluetooth;
    }

    function syncAnchor() {
        let pt = root.mapToItem(null, 0, 0);
        if (pt && root.visible) {
            if (Theme.isVertical) {
                popup.targetRelativeX = 0;
                popup.targetRelativeY = pt.y + (root.implicitHeight / 2) + root.effectiveBarMargin;
            } else {
                popup.targetRelativeX = pt.x + (root.implicitWidth / 2) + root.effectiveBarMargin;
                popup.targetRelativeY = 0;
            }
        } else {
            popup.targetRelativeX = 0;
            popup.targetRelativeY = 0;
        }
    }

    Row {
        id: btRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.isPowered ? (root.hasConnectedDevice ? Theme.iconBluetoothConnected : Theme.iconBluetooth) : Theme.iconBluetoothOff
            font.family: Theme.fontIcon
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            color: !root.isPowered ? Theme.on_surface_variant : (root.hasConnectedDevice || popup.open || btMouse.containsMouse ? Theme.primary : Theme.on_surface)

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Theme.isVertical && (root.hasConnectedDevice || btMouse.containsMouse || popup.open)
            text: !root.isPowered ? "off" : (root.hasConnectedDevice ? root.primaryDeviceName : "bluetooth")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            font.weight: Font.Medium
            color: Theme.on_surface
        }
    }

    HoverFlyoutHandler {
        popup: popup
        mouseArea: btMouse
        updatePos: () => root.syncAnchor()
    }

    MouseArea {
        id: btMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                if (root.adapter) root.adapter.enabled = !root.adapter.enabled;
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                if (root.adapter && root.isPowered) root.adapter.discovering = !root.adapter.discovering;
                return;
            }
            root.syncAnchor();
            if (!popup.open) {
                popup.pinned = true;
                popup.open = true;
            } else if (!popup.pinned) {
                popup.pinned = true;
            } else {
                popup.pinned = false;
                popup.open = false;
            }
        }
    }

    Connections {
        target: Settings
        function onRequestBluetoothToggle() {
            root.syncAnchor();
            popup.open = !popup.open;
        }
        function onRequestBluetoothOpen() {
            root.syncAnchor();
            popup.open = true;
        }
        function onRequestBluetoothClose() {
            popup.open = false;
        }
    }

    PopupPanel {
        id: popup
        cardWidth: 400
        cardHeight: 450

        content: ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            // header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 34
                    height: 34
                    radius: Theme.radiusMd
                    color: !root.isPowered ? Theme.widgetBg : Theme.primary_overlay
                    border.color: !root.isPowered ? Theme.widgetBorder : Theme.alpha(Theme.primary, 0.35)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    Text {
                        anchors.centerIn: parent
                        text: root.isPowered ? (root.hasConnectedDevice ? Theme.iconBluetoothConnected : Theme.iconBluetooth) : Theme.iconBluetoothOff
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                        color: root.isPowered ? Theme.primary : Theme.on_surface_variant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "bluetooth & audio"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.Bold
                        color: Theme.on_surface
                    }

                    Text {
                        text: {
                            if (!root.isPowered) return "adapter powered down • radio silence";
                            if (root.isDiscovering) return "scanning nearby airwaves for devices...";
                            if (root.hasConnectedDevice) return "linked to " + root.primaryDeviceName;
                            return Theme.getFlavor("media_playing", "bluez daemon ready • idle");
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_surface_variant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    height: 22
                    implicitWidth: statusText.implicitWidth + 14
                    radius: Theme.radiusPill
                    color: !root.isPowered ? Theme.widgetBg : (root.isDiscovering ? Theme.warn_overlay : Theme.primary_overlay)
                    border.color: !root.isPowered ? Theme.widgetBorder : (root.isDiscovering ? Theme.warn : Theme.primary)
                    border.width: 1

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: !root.isPowered ? "off" : (root.isDiscovering ? "scanning" : (root.hasConnectedDevice ? (root.connectedDevices.length + " linked") : "ready"))
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Font.Bold
                        color: !root.isPowered ? Theme.on_surface_variant : (root.isDiscovering ? Theme.warn : Theme.primary)
                    }
                }

                ToggleSwitch {
                    checked: root.isPowered
                    onToggled: {
                        if (root.adapter) {
                            root.adapter.enabled = !root.adapter.enabled;
                        }
                    }
                }
            }

            // main devices card
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1
                clip: true

                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: Theme.iconBluetooth
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                            color: Theme.primary
                        }

                        Text {
                            text: "devices (" + root.sortedDevices.length + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Bold
                            color: Theme.on_surface
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: root.isPowered && root.adapter !== null
                            height: 24
                            implicitWidth: scanChipRow.implicitWidth + 16
                            radius: Theme.radiusPill
                            color: root.isDiscovering ? Theme.primary_overlay : (scanMouse.containsMouse ? Theme.widgetHover : "transparent")
                            border.color: root.isDiscovering ? Theme.primary : Theme.widgetBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            RowLayout {
                                id: scanChipRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    visible: !Theme.isTextIconSet
                                    text: Theme.iconRefresh
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeXs
                                    color: root.isDiscovering ? Theme.primary : Theme.on_surface_variant
                                }

                                Text {
                                    text: root.isDiscovering ? "stop scan" : "scan nearby"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: root.isDiscovering ? Font.Bold : Font.Normal
                                    color: root.isDiscovering ? Theme.primary : Theme.on_surface_variant
                                }
                            }

                            MouseArea {
                                id: scanMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.adapter) {
                                        root.adapter.discovering = !root.adapter.discovering;
                                    }
                                }
                            }
                        }
                    }

                    // actual Flickable + Column so the devices don't dogpile onto y: 0
                    Flickable {
                        id: devFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: devCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        visible: root.isPowered && root.sortedDevices.length > 0

                        Column {
                            id: devCol
                            width: devFlick.width
                            spacing: 6

                            Repeater {
                                model: root.sortedDevices

                                delegate: Rectangle {
                                    id: btDeviceDelegate
                                    required property var modelData
                                    readonly property int batPct: root.getDeviceBatteryPct(modelData)

                                    width: devCol.width
                                    height: 52
                                    radius: Theme.radiusMd
                                    color: modelData.connected ? Theme.primary_overlay : (dMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                    border.color: modelData.connected ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                                    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    MouseArea {
                                        id: dMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.connected) {
                                                if (modelData.disconnect) modelData.disconnect();
                                            } else {
                                                if (modelData.connect) modelData.connect();
                                            }
                                        }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: Theme.radiusSm
                                            color: modelData.connected ? Theme.alpha(Theme.primary, 0.22) : Theme.cardBg
                                            border.color: modelData.connected ? Theme.alpha(Theme.primary, 0.45) : Theme.widgetBorder
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.getDeviceIcon(modelData)
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                                                color: modelData.connected ? Theme.primary : Theme.on_surface_variant
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: (modelData.name || modelData.address || "unknown device").toLowerCase()
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: modelData.connected ? Font.Bold : Font.DemiBold
                                                color: modelData.connected ? Theme.primary : Theme.on_surface
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            RowLayout {
                                                spacing: 6

                                                Text {
                                                    text: modelData.connected ? "connected" : (modelData.paired ? "paired" : "available")
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontSizeXs
                                                    color: modelData.connected ? Theme.primary : Theme.on_surface_variant
                                                }

                                                Text {
                                                    visible: btDeviceDelegate.batPct >= 0
                                                    text: "• " + btDeviceDelegate.batPct + "% bat"
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: Font.Bold
                                                    color: Theme.getBatteryColor(btDeviceDelegate.batPct, false)
                                                }
                                            }
                                        }

                                        Rectangle {
                                            height: 26
                                            implicitWidth: actTxt.implicitWidth + 16
                                            radius: Theme.radiusPill
                                            color: actMouse.containsMouse
                                                ? (modelData.connected ? Theme.error_overlay : Theme.primary)
                                                : (modelData.connected ? "transparent" : Theme.primary_overlay)
                                            border.color: actMouse.containsMouse && modelData.connected ? Theme.error : Theme.primary
                                            border.width: 1

                                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                            Text {
                                                id: actTxt
                                                anchors.centerIn: parent
                                                text: modelData.connected ? (actMouse.containsMouse ? "disconnect" : "linked") : "connect"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Font.Bold
                                                color: actMouse.containsMouse
                                                    ? (modelData.connected ? Theme.error : Theme.on_primary)
                                                    : Theme.primary
                                            }

                                            MouseArea {
                                                id: actMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (modelData.connected) {
                                                        if (modelData.disconnect) modelData.disconnect();
                                                    } else {
                                                        if (modelData.connect) modelData.connect();
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: modelData.paired && !modelData.connected && modelData.forget !== undefined
                                            width: 26
                                            height: 26
                                            radius: Theme.radiusPill
                                            color: forgetMouse.containsMouse ? Theme.error_overlay : "transparent"
                                            border.color: forgetMouse.containsMouse ? Theme.error : Theme.widgetBorder
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: Theme.iconTrash
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.fontSizeXs
                                                color: forgetMouse.containsMouse ? Theme.error : Theme.on_surface_variant
                                            }

                                            MouseArea {
                                                id: forgetMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (modelData.forget) modelData.forget();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // empty or disabled state
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !root.isPowered || root.sortedDevices.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 48
                                height: 48
                                radius: Theme.radiusPill
                                color: Theme.widgetBg
                                border.color: Theme.widgetBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: !root.isPowered ? Theme.iconBluetoothOff : Theme.iconBluetooth
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeMd : Theme.fontSizeTitle
                                    color: Theme.on_surface_variant
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: !root.isPowered
                                    ? "bluetooth is disabled"
                                    : (root.isDiscovering ? "searching for nearby devices..." : "no paired or named devices found")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: Theme.on_surface
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: !root.isPowered
                                    ? (Theme.kaoSleepy + " flip the switch above or right-click the bar icon")
                                    : (Theme.kaoEmpty + " hit 'scan nearby' to wake up the adapter")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.on_surface_variant
                            }
                        }
                    }
                }
            }
        }
    }
}
