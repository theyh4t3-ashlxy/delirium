// NetworkStatus.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../services"
import Quickshell
import Quickshell.Networking

Rectangle {
    id: root

    property var barScreen: null
    property var barMonitor: null

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isBento
    readonly property int effectiveBarMargin: isFloatingBar ? ((Settings?.barMargin > 0) ? Settings.barMargin : 8) : 0

    readonly property string activeSsidLower: (NetworkService.activeSsid || "").toLowerCase()
    readonly property int activeSignalPct: {
        let s = NetworkService.signalStrength ?? 0;
        return Math.round(s <= 1.0 && s > 0 ? s * 100 : s);
    }
    readonly property string netIcon: Theme.getWifiIcon(
        root.activeSignalPct,
        NetworkService.wifiEnabled && NetworkService.isWifiConnected,
        NetworkService.isWiredConnected
    )

    readonly property var rawNetworks: (NetworkService.wifiEnabled && NetworkService.wifiDevice?.networks?.values)
        ? NetworkService.wifiDevice.networks.values
        : []

    // sort connected network first, then strongest signal so your router isn't buried under the neighbor's printer
    readonly property var sortedNetworks: {
        let list = [];
        for (let i = 0; i < rawNetworks.length; i++) {
            let n = rawNetworks[i];
            if (!n) continue;
            if (!n.connected && (!n.name || n.name.trim() === "")) continue;
            list.push(n);
        }
        list.sort((a, b) => {
            if (!!a.connected !== !!b.connected) return a.connected ? -1 : 1;
            return (b.signalStrength ?? 0) - (a.signalStrength ?? 0);
        });
        return list;
    }

    implicitWidth: {
        if (Theme.isVertical) return Theme.barHeight - 8;
        if (netMouse.containsMouse || popup.open) return netRow.implicitWidth + 20;
        return Theme.barHeight - 8;
    }
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radiusPill

    color: {
        if (netMouse.pressed) return Theme.widgetActive;
        if (popup.open) return Theme.primary_overlay;
        if (netMouse.containsMouse) return Theme.pillHover;
        return Theme.pillBg;
    }
    border.color: popup.open ? Theme.primary : Theme.pillBorder
    border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1
    clip: true

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

    function updatePopupPosition() {
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

    function togglePopup() {
        updatePopupPosition();
        if (!popup.open) {
            popup.pinned = true;
            popup.open = true;
            NetworkService.rescan();
        } else if (!popup.pinned) {
            popup.pinned = true;
        } else {
            popup.pinned = false;
            popup.open = false;
        }
    }

    function getConnectionText() {
        if (!NetworkService.isConnected) return Theme.getFlavor("network_off", "disconnected • offline");
        if (NetworkService.isWiredConnected) return Theme.getFlavor("network_on", "wired ethernet • link up");

        let txt = "connected • " + root.activeSignalPct + "% signal";
        if (NetworkService.rawActiveSsid && NetworkService.rawActiveSsid !== NetworkService.activeSsid) {
            txt += " (" + NetworkService.rawActiveSsid.toLowerCase() + ")";
        }
        return Theme.getFlavor("network_on", txt);
    }

    function toSignalPct(sig) {
        if (!sig || isNaN(sig)) return 0;
        return Math.round(sig <= 1.0 ? sig * 100 : sig);
    }

    Row {
        id: netRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.netIcon
            font.family: Theme.fontIcon
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            color: !NetworkService.isConnected
                ? Theme.on_surface_variant
                : (popup.open || netMouse.containsMouse ? Theme.primary : Theme.on_surface)

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Theme.isVertical && (netMouse.containsMouse || popup.open)
            text: !NetworkService.isConnected
                ? "offline"
                : (NetworkService.isWiredConnected ? "ethernet" : (root.activeSsidLower || "wi-fi"))
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            font.weight: Font.Medium
            color: Theme.on_surface
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(implicitWidth, 140)
        }
    }

    HoverFlyoutHandler {
        popup: popup
        mouseArea: netMouse
        updatePos: () => {
            root.updatePopupPosition();
            if (typeof NetworkService !== "undefined" && NetworkService?.rescan) {
                NetworkService.rescan();
            }
        }
    }

    // left click opens menu, right click toggles wifi power, middle click rescans
    MouseArea {
        id: netMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                NetworkService.toggleWifi();
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                NetworkService.rescan();
                return;
            }
            root.togglePopup();
        }
    }

    Connections {
        target: Settings
        function onRequestNetworkToggle() { root.togglePopup(); }
        function onRequestNetworkOpen() {
            root.updatePopupPosition();
            popup.open = true;
            NetworkService.rescan();
        }
        function onRequestNetworkClose() { popup.open = false; }
    }

    PopupPanel {
        id: popup
        cardWidth: 410
        cardHeight: 500

        content: ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            // header matching Bluetooth & ScreenCapture
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 34
                    height: 34
                    radius: Theme.radiusMd
                    color: !NetworkService.isConnected ? Theme.widgetBg : Theme.primary_overlay
                    border.color: !NetworkService.isConnected ? Theme.widgetBorder : Theme.alpha(Theme.primary, 0.35)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    Text {
                        anchors.centerIn: parent
                        text: root.netIcon
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                        color: NetworkService.isConnected ? Theme.primary : Theme.on_surface_variant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "network & wi-fi"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.Bold
                        color: Theme.on_surface
                    }

                    Text {
                        text: root.getConnectionText()
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
                    color: !NetworkService.isConnected ? Theme.widgetBg : Theme.primary_overlay
                    border.color: !NetworkService.isConnected ? Theme.widgetBorder : Theme.primary
                    border.width: 1

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: !NetworkService.isConnected
                            ? "offline"
                            : (NetworkService.isWiredConnected ? "wired" : (root.activeSignalPct + "%"))
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Font.Bold
                        color: !NetworkService.isConnected ? Theme.on_surface_variant : Theme.primary
                    }
                }

                ToggleSwitch {
                    checked: NetworkService.wifiEnabled
                    onToggled: NetworkService.toggleWifi()
                }
            }

            // active connection card
            Rectangle {
                id: activeCard
                Layout.fillWidth: true
                implicitHeight: isRenamingActive ? 64 : 58
                color: NetworkService.isConnected ? Theme.primary_overlay : Theme.cardBg
                radius: Theme.radiusMd
                border.color: NetworkService.isConnected ? Theme.primary : Theme.cardBorder
                border.width: 1
                clip: true

                property bool isRenamingActive: false

                Behavior on implicitHeight { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Rectangle {
                    visible: Theme.isGlass
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.glassHighlight
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10
                    visible: !activeCard.isRenamingActive

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: Theme.radiusSm
                        color: NetworkService.isConnected ? Theme.alpha(Theme.primary, 0.22) : Theme.widgetBg
                        border.color: NetworkService.isConnected ? Theme.alpha(Theme.primary, 0.45) : Theme.widgetBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: NetworkService.isWiredConnected
                                ? Theme.iconEthernet
                                : (NetworkService.isWifiConnected ? Theme.iconWifiHigh : Theme.iconWifiOff)
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                            color: NetworkService.isConnected ? Theme.primary : Theme.on_surface_variant
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 6
                            Layout.fillWidth: true

                            Text {
                                text: !NetworkService.isConnected
                                    ? "not connected"
                                    : (NetworkService.isWiredConnected ? "ethernet connection" : (root.activeSsidLower || "connected"))
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: NetworkService.isConnected ? Theme.primary : Theme.on_surface
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            IconButton {
                                visible: NetworkService.isWifiConnected
                                icon: Theme.iconEdit
                                iconSize: Theme.fontSizeXs
                                tooltip: "rename display alias"
                                onClicked: {
                                    aliasEditInput.text = Settings.getNetworkAlias(NetworkService.rawActiveSsid);
                                    activeCard.isRenamingActive = true;
                                    aliasEditInput.forceActiveFocus();
                                }
                            }
                        }

                        Text {
                            text: !NetworkService.isConnected
                                ? "no active network interface"
                                : (NetworkService.isWiredConnected
                                    ? "wired interface active"
                                    : ("signal " + root.activeSignalPct + "%" + (NetworkService.rawActiveSsid && NetworkService.rawActiveSsid !== NetworkService.activeSsid ? (" • raw: " + NetworkService.rawActiveSsid.toLowerCase()) : "")))
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface_variant
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        visible: NetworkService.isWifiConnected
                        height: 26
                        implicitWidth: discTxt.implicitWidth + 16
                        radius: Theme.radiusPill
                        color: discMouse.containsMouse ? Theme.error_overlay : "transparent"
                        border.color: discMouse.containsMouse ? Theme.error : Theme.primary
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        Text {
                            id: discTxt
                            anchors.centerIn: parent
                            text: discMouse.containsMouse ? "disconnect" : "linked"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.Bold
                            color: discMouse.containsMouse ? Theme.error : Theme.primary
                        }

                        MouseArea {
                            id: discMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const iface = NetworkService.wifiDevice?.name;
                                if (iface) {
                                    Quickshell.execDetached(["nmcli", "dev", "disconnect", "iface", iface]);
                                }
                            }
                        }
                    }
                }

                // inline alias editor
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6
                    visible: activeCard.isRenamingActive

                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: Theme.radiusSm
                        color: Theme.widgetBg
                        border.color: aliasEditInput.activeFocus ? Theme.primary : Theme.widgetBorder
                        border.width: 1

                        TextInput {
                            id: aliasEditInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface
                            selectByMouse: true

                            onAccepted: {
                                Settings.setNetworkAlias(NetworkService.rawActiveSsid, text);
                                activeCard.isRenamingActive = false;
                            }
                        }
                    }

                    IconButton {
                        icon: Theme.iconCheck
                        iconSize: Theme.fontSizeXs
                        tooltip: "save alias"
                        onClicked: {
                            Settings.setNetworkAlias(NetworkService.rawActiveSsid, aliasEditInput.text);
                            activeCard.isRenamingActive = false;
                        }
                    }

                    IconButton {
                        icon: Theme.iconTrash
                        iconSize: Theme.fontSizeXs
                        tooltip: "reset to real ssid"
                        onClicked: {
                            Settings.setNetworkAlias(NetworkService.rawActiveSsid, "");
                            activeCard.isRenamingActive = false;
                        }
                    }

                    IconButton {
                        icon: Theme.iconClose
                        iconSize: Theme.fontSizeXs
                        tooltip: "cancel"
                        onClicked: activeCard.isRenamingActive = false
                    }
                }
            }

            // available networks card
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
                            text: Theme.iconWifi
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                            color: Theme.primary
                        }

                        Text {
                            text: "wireless networks (" + root.sortedNetworks.length + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Font.Bold
                            color: Theme.on_surface
                        }

                        Item { Layout.fillWidth: true }

                        // rescan chip
                        Rectangle {
                            visible: NetworkService.wifiEnabled
                            height: 24
                            implicitWidth: rescanRow.implicitWidth + 14
                            radius: Theme.radiusPill
                            color: rescanMouse.containsMouse ? Theme.widgetHover : "transparent"
                            border.color: rescanMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            RowLayout {
                                id: rescanRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    visible: !Theme.isTextIconSet
                                    text: Theme.iconRefresh
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeXs
                                    color: rescanMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
                                }

                                Text {
                                    text: "rescan"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    color: rescanMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
                                }
                            }

                            MouseArea {
                                id: rescanMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: NetworkService.rescan()
                            }
                        }

                        // nmtui launcher chip
                        Rectangle {
                            height: 24
                            implicitWidth: nmtuiRow.implicitWidth + 14
                            radius: Theme.radiusPill
                            color: nmtuiMouse.containsMouse ? Theme.widgetHover : "transparent"
                            border.color: nmtuiMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            RowLayout {
                                id: nmtuiRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    visible: !Theme.isTextIconSet
                                    text: Theme.iconTerminal
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeXs
                                    color: nmtuiMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
                                }

                                Text {
                                    text: "nmtui"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    color: nmtuiMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
                                }
                            }

                            MouseArea {
                                id: nmtuiMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["kitty", "-e", "nmtui"]);
                                    popup.open = false;
                                }
                            }
                        }
                    }

                    // scrollable network list
                    ListView {
                        id: netList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        visible: NetworkService.wifiEnabled && root.sortedNetworks.length > 0
                        model: root.sortedNetworks

                        delegate: Rectangle {
                            id: netItem
                            required property var modelData
                            readonly property bool isItemConnected: modelData.connected || false
                            readonly property string networkName: modelData.name || ""
                            readonly property int sigPct: root.toSignalPct(modelData.signalStrength)
                            readonly property bool isSecured: (modelData.security !== undefined && modelData.security !== 0) || (modelData.flags !== undefined && modelData.flags > 0)

                            readonly property string aliasName: Settings.getNetworkAlias(networkName)
                            readonly property string displayName: (aliasName !== "" ? aliasName : (networkName !== "" ? networkName : "hidden network")).toLowerCase()
                            readonly property string rawHint: (aliasName !== "" && aliasName !== networkName) ? ("raw: " + networkName.toLowerCase() + " • ") : ""

                            property bool isExpanded: false

                            width: netList.width
                            height: isExpanded ? 94 : 52
                            color: isItemConnected ? Theme.primary_overlay : (itemHover.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                            radius: Theme.radiusMd
                            border.color: (isItemConnected || netItem.isExpanded) ? Theme.primary : Theme.widgetBorder
                            border.width: 1
                            clip: true

                            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            onIsExpandedChanged: {
                                if (isExpanded && !isItemConnected) {
                                    pwdInput.forceActiveFocus();
                                }
                            }

                            MouseArea {
                                id: itemHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!netItem.isItemConnected) {
                                        netItem.isExpanded = !netItem.isExpanded;
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: Theme.radiusSm
                                        color: netItem.isItemConnected ? Theme.alpha(Theme.primary, 0.22) : Theme.cardBg
                                        border.color: netItem.isItemConnected ? Theme.alpha(Theme.primary, 0.45) : Theme.widgetBorder
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.getWifiIcon(netItem.sigPct, true, false)
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                                            color: netItem.isItemConnected ? Theme.primary : Theme.on_surface_variant
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            text: netItem.displayName
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: netItem.isItemConnected ? Font.Bold : Font.DemiBold
                                            color: netItem.isItemConnected ? Theme.primary : Theme.on_surface
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        RowLayout {
                                            spacing: 4

                                            Text {
                                                text: netItem.rawHint + (netItem.isItemConnected ? "connected • " : "") + netItem.sigPct + "% signal"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontSizeXs
                                                color: netItem.isItemConnected ? Theme.primary : Theme.on_surface_variant
                                            }

                                            Text {
                                                text: "• secured"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.on_surface_variant
                                                visible: netItem.isSecured && !netItem.isItemConnected
                                            }

                                            Text {
                                                text: Theme.iconLock
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.on_surface_variant
                                                visible: netItem.isSecured && !netItem.isItemConnected && !Theme.isTextIconSet
                                            }
                                        }
                                    }

                                    IconButton {
                                        icon: netItem.isItemConnected ? Theme.iconClose : (netItem.isExpanded ? Theme.iconChevronUp : Theme.iconChevronDown)
                                        iconSize: Theme.fontSizeXs
                                        tooltip: netItem.isItemConnected ? "disconnect" : (netItem.isExpanded ? "collapse" : "connect")
                                        onClicked: {
                                            if (netItem.isItemConnected) {
                                                const iface = NetworkService.wifiDevice?.name;
                                                if (iface) Quickshell.execDetached(["nmcli", "dev", "disconnect", "iface", iface]);
                                            } else {
                                                netItem.isExpanded = !netItem.isExpanded;
                                            }
                                        }
                                    }
                                }

                                // expandable password + connect row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    visible: netItem.isExpanded && !netItem.isItemConnected

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 30
                                        radius: Theme.radiusSm
                                        color: Theme.cardBg
                                        border.color: pwdInput.activeFocus ? Theme.primary : Theme.widgetBorder
                                        border.width: 1

                                        TextInput {
                                            id: pwdInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            verticalAlignment: TextInput.AlignVCenter
                                            echoMode: showPwdBtn.showPassword ? TextInput.Normal : TextInput.Password
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.on_surface
                                            selectByMouse: true

                                            Text {
                                                anchors.fill: parent
                                                verticalAlignment: Text.AlignVCenter
                                                text: netItem.isSecured ? "enter wi-fi password (or leave blank if saved)..." : "open network • click connect"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.on_surface_disabled
                                                visible: pwdInput.text === ""
                                                elide: Text.ElideRight
                                            }

                                            onAccepted: connectBtnMouse.clicked(null)
                                        }
                                    }

                                    IconButton {
                                        id: showPwdBtn
                                        visible: netItem.isSecured
                                        property bool showPassword: false
                                        icon: showPassword ? Theme.iconEyeOff : Theme.iconEye
                                        iconSize: Theme.fontSizeXs
                                        tooltip: showPassword ? "hide password" : "show password"
                                        onClicked: showPassword = !showPassword
                                    }

                                    Rectangle {
                                        height: 30
                                        implicitWidth: connTxt.implicitWidth + 18
                                        radius: Theme.radiusPill
                                        color: connectBtnMouse.containsMouse ? Theme.primary_overlay : Theme.primary
                                        border.color: Theme.primary
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            id: connTxt
                                            anchors.centerIn: parent
                                            text: "connect"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Font.Bold
                                            color: connectBtnMouse.containsMouse ? Theme.primary : Theme.on_primary
                                        }

                                        MouseArea {
                                            id: connectBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const target = netItem.networkName;
                                                if (target === "") return;

                                                if (pwdInput.text.trim() !== "") {
                                                    Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", target, "password", pwdInput.text.trim()]);
                                                } else {
                                                    Quickshell.execDetached(["nmcli", "dev", "wifi", "connect", target]);
                                                }
                                                netItem.isExpanded = false;
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
                        visible: !NetworkService.wifiEnabled || root.sortedNetworks.length === 0

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
                                    text: !NetworkService.wifiEnabled ? Theme.iconWifiOff : Theme.iconWifi
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeMd : Theme.fontSizeTitle
                                    color: Theme.on_surface_variant
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: !NetworkService.wifiEnabled ? "wi-fi is turned off" : "scanning for wireless networks..."
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Font.Bold
                                color: Theme.on_surface
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: !NetworkService.wifiEnabled
                                    ? (Theme.kaoSleepy + " flip the switch above or right-click the bar icon")
                                    : (Theme.kaoLoading + " searching for local ssids in range...")
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
