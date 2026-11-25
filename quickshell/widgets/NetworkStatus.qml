// NetworkStatus.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../services"
import "../theme/confFormat.mjs" as ConfFmt
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Hyprland

BarPill {
    id: root

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isIslands
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

    // Backend NetworkManager telemetry (IP, gateway, DNS, VPNs, hotspot, saved profiles, QR)
    readonly property string netScript: decodeURIComponent(Qt.resolvedUrl("../scripts/network.py").toString().replace(/^file:\/\//, ""))
    property string activeTab: "wifi" // wifi | vpn | hotspot
    property string ifaceName: ""
    property string ip4Addr: ""
    property string gatewayAddr: ""
    property string dnsAddr: ""
    property real rxRateBps: 0
    property real txRateBps: 0
    property real _lastRxBytes: -1
    property real _lastTxBytes: -1
    property real _lastSampleMs: 0
    property bool hotspotActive: false
    property var vpnProfiles: []
    property var savedProfiles: []
    property bool showSavedManager: false
    property string statusError: ""
    property bool busyAction: false

    // Wi-Fi / Hotspot QR sheet state
    property bool showQrSheet: false
    property string qrSsid: ""
    property string qrPassword: ""
    property var qrRows: []
    property bool qrCopied: false

    readonly property bool anyVpnActive: {
        for (let i = 0; i < vpnProfiles.length; i++) {
            if (vpnProfiles[i].active === "true") return true;
        }
        return false;
    }

    function parseKv(text) {
        let raw = ConfFmt.parseFlatConf(text || "");
        let out = {};
        for (let k in raw) out[k] = ConfFmt.unescapeField(raw[k]);
        return out;
    }

    function formatSpeed(bps) {
        if (!bps || bps < 1024) return Math.round(bps || 0) + " B/s";
        if (bps < 1024 * 1024) return (bps / 1024).toFixed(1) + " KB/s";
        return (bps / (1024 * 1024)).toFixed(2) + " MB/s";
    }

    Process {
        id: netProbeProc
        command: ["python3", root.netScript, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let kv = root.parseKv(text);
                root.ifaceName = kv.iface || "";
                root.ip4Addr = kv.ip4 || "";
                root.gatewayAddr = kv.gateway || "";
                root.dnsAddr = kv.dns || "";
                root.hotspotActive = (kv.hotspot_active === "true");
                root.vpnProfiles = ConfFmt.parseRecords(text || "", "vpn") || [];
                root.savedProfiles = ConfFmt.parseRecords(text || "", "saved") || [];

                let nowMs = Date.now();
                let rx = parseFloat(kv.rx_bytes || "0") || 0;
                let tx = parseFloat(kv.tx_bytes || "0") || 0;
                if (root._lastSampleMs > 0 && root._lastRxBytes >= 0 && nowMs > root._lastSampleMs) {
                    let dt = (nowMs - root._lastSampleMs) / 1000.0;
                    root.rxRateBps = Math.max(0, (rx - root._lastRxBytes) / dt);
                    root.txRateBps = Math.max(0, (tx - root._lastTxBytes) / dt);
                }
                root._lastRxBytes = rx;
                root._lastTxBytes = tx;
                root._lastSampleMs = nowMs;
            }
        }
    }

    Process {
        id: netActProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.busyAction = false;
                let kv = root.parseKv(text);
                root.statusError = (kv.ok === "false") ? (kv.error || "command failed") : "";
                root.refreshNetStatus();
                if (root.activeTab === "hotspot" && kv.active === "true") {
                    root.fetchWifiQr(kv.ssid || "", kv.password || "");
                }
            }
        }
    }

    Process {
        id: qrProc
        stdout: StdioCollector {
            onStreamFinished: {
                let kv = root.parseKv(text);
                if (kv.ok === "true" && kv.rows) {
                    root.qrSsid = kv.ssid || "";
                    root.qrPassword = kv.password || "";
                    root.qrRows = kv.rows.split("|").filter(Boolean);
                    root.showQrSheet = true;
                    root.statusError = "";
                    qrCanvas.requestPaint();
                } else {
                    root.statusError = kv.error || "could not build wi-fi qr";
                }
            }
        }
    }

    Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: popup.open
        onTriggered: root.refreshNetStatus()
    }

    Timer {
        id: qrCopyTimer
        interval: 1200
        onTriggered: root.qrCopied = false
    }

    function refreshNetStatus() {
        if (!netProbeProc.running) netProbeProc.running = true;
    }

    function runNetCmd(args) {
        root.busyAction = true;
        root.statusError = "";
        if (netActProc.running) netActProc.running = false;
        netActProc.command = ["python3", root.netScript].concat(args);
        netActProc.running = true;
    }

    function fetchWifiQr(ssidOverride, passOverride) {
        let cmd = ["python3", root.netScript, "qr"];
        if (ssidOverride) {
            cmd.push(ssidOverride);
            if (passOverride) cmd.push(passOverride);
        }
        if (qrProc.running) qrProc.running = false;
        qrProc.command = cmd;
        qrProc.running = true;
    }

    active: popup.open
    hovered: netMouse.containsMouse
    pressed: netMouse.pressed
    clip: true

    implicitWidth: {
        if (Theme.isVertical) return pillSize;
        if (netMouse.containsMouse || popup.open || root.anyVpnActive || root.hotspotActive) return netRow.implicitWidth + 20;
        return pillSize;
    }

    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

    function isTargetMonitorActive() {
        return !root.barScreen
            || Quickshell.screens.length <= 1
            || (root.barMonitor && Hyprland.focusedMonitor && root.barMonitor.id === Hyprland.focusedMonitor.id);
    }

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
            refreshNetStatus();
        } else if (!popup.pinned) {
            popup.pinned = true;
        } else {
            popup.pinned = false;
            popup.open = false;
        }
    }

    function getConnectionText() {
        if (root.hotspotActive) return "wi-fi hotspot broadcasting";
        if (root.anyVpnActive) return "vpn tunnel active • " + (root.ip4Addr || root.ifaceName);
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
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hotspotActive ? Theme.iconRadio : root.netIcon
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            color: root.hotspotActive
                ? Theme.warn
                : (!NetworkService.isConnected
                    ? Theme.on_surface_variant
                    : (popup.open || netMouse.containsMouse || root.anyVpnActive ? Theme.primary : Theme.on_surface))

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            visible: !Theme.isVertical && root.anyVpnActive
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.iconShield
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.fontSizeXs
            color: Theme.primary
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Theme.isVertical && (netMouse.containsMouse || popup.open || root.hotspotActive)
            text: {
                if (root.hotspotActive) return "hotspot";
                if (!NetworkService.isConnected) return "offline";
                if (NetworkService.isWiredConnected) return "ethernet";
                return root.activeSsidLower || "wi-fi";
            }
            font.family: Theme.fontFamily
            font.variableAxes: Theme.sansAxes
            font.pixelSize: Theme.fontSizeSm
            font.weight: Theme.fontWeightMedium
            color: root.hotspotActive ? Theme.warn : Theme.on_surface
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
            NetworkService.rescan();
            root.refreshNetStatus();
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
        function onRequestNetworkToggle() { if (root.isTargetMonitorActive()) root.togglePopup(); }
        function onRequestNetworkOpen() {
            if (!root.isTargetMonitorActive()) return;
            root.updatePopupPosition();
            popup.pinned = true;
            popup.open = true;
            NetworkService.rescan();
            root.refreshNetStatus();
        }
        function onRequestNetworkClose() { popup.open = false; }
        function onRequestNetworkTab(tabName) {
            if (!root.isTargetMonitorActive()) return;
            let t = String(tabName || "wifi").toLowerCase();
            if (t === "vpn" || t === "hotspot" || t === "wifi") {
                root.activeTab = t;
            }
            root.showQrSheet = false;
            root.updatePopupPosition();
            popup.pinned = true;
            popup.open = true;
            NetworkService.rescan();
            root.refreshNetStatus();
        }
    }

    PopupPanel {
        id: popup
        screen: root.barScreen
        cardWidth: 420
        cardHeight: 530

        onOpenChanged: {
            if (open) {
                root.statusError = "";
                root._lastSampleMs = 0;
                root.refreshNetStatus();
            } else {
                root.showQrSheet = false;
            }
        }

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
                    color: root.hotspotActive ? Theme.warn_overlay : (!NetworkService.isConnected ? Theme.widgetBg : Theme.primary_overlay)
                    border.color: root.hotspotActive ? Theme.warn : (!NetworkService.isConnected ? Theme.widgetBorder : Theme.alpha(Theme.primary, 0.35))
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    Text {
                        anchors.centerIn: parent
                        text: root.hotspotActive ? Theme.iconRadio : root.netIcon
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                        color: root.hotspotActive ? Theme.warn : (NetworkService.isConnected ? Theme.primary : Theme.on_surface_variant)
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "network & wi-fi"
                        font.family: Theme.fontDisplay
                        font.variableAxes: Theme.displayAxes
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.on_surface
                    }

                    Text {
                        text: root.getConnectionText()
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
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
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.monoWeightBold
                        color: !NetworkService.isConnected ? Theme.on_surface_variant : Theme.primary
                    }
                }

                ToggleSwitch {
                    checked: NetworkService.wifiEnabled
                    onToggled: NetworkService.toggleWifi()
                }
            }

            // segmented tabs: wi-fi | vpn | hotspot
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { id: "wifi", label: "wi-fi", icon: Theme.iconWifi, badge: "" },
                        { id: "vpn", label: root.anyVpnActive ? "vpn (on)" : "vpn", icon: Theme.iconShield, badge: root.vpnProfiles.length > 0 ? String(root.vpnProfiles.length) : "" },
                        { id: "hotspot", label: root.hotspotActive ? "hotspot (on)" : "hotspot", icon: Theme.iconRadio, badge: "" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isTab: root.activeTab === modelData.id
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: Theme.radiusPill
                        color: isTab
                            ? (modelData.id === "hotspot" && root.hotspotActive ? Theme.warn : Theme.primary)
                            : (tabMouse.containsMouse ? Theme.widgetHover : Theme.cardBg)
                        border.color: isTab ? "transparent" : Theme.cardBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                visible: !Theme.isTextIconSet
                                text: modelData.icon
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeXs
                                color: isTab ? Theme.on_primary : Theme.on_surface_variant
                            }

                            Text {
                                text: modelData.label
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: isTab ? Theme.fontWeightBold : Theme.fontWeightMedium
                                color: isTab ? Theme.on_primary : Theme.on_surface
                            }

                            Text {
                                visible: modelData.badge !== ""
                                text: modelData.badge
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 9
                                font.weight: Theme.monoWeightBold
                                color: isTab ? Theme.on_primary : Theme.primary
                            }
                        }

                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeTab = modelData.id;
                                root.showQrSheet = false;
                                if (modelData.id === "hotspot" && root.hotspotActive) {
                                    root.fetchWifiQr();
                                }
                            }
                        }
                    }
                }
            }

            // error banner if nmcli returns error
            Rectangle {
                visible: root.statusError !== ""
                Layout.fillWidth: true
                implicitHeight: netErrTxt.implicitHeight + 10
                radius: Theme.radiusSm
                color: Theme.error_overlay
                border.color: Theme.error
                border.width: 1

                Text {
                    id: netErrTxt
                    anchors.fill: parent
                    anchors.margins: 5
                    text: root.statusError
                    font.family: Theme.fontMono
                    font.variableAxes: Theme.monoAxes
                    font.pixelSize: 9
                    color: Theme.error
                    wrapMode: Text.WordWrap
                }
            }

            // INLINE WI-FI QR SHARE CARD
            Rectangle {
                visible: root.showQrSheet
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: Theme.primary
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "wi-fi share qr: " + root.qrSsid
                            font.family: Theme.fontDisplay
                            font.variableAxes: Theme.displayAxes
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.primary
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        IconButton {
                            icon: Theme.iconClose
                            iconSize: Theme.fontSizeXs
                            tooltip: "back"
                            onClicked: root.showQrSheet = false
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 212
                        height: 212
                        radius: Theme.radiusMd
                        color: "#ffffff"
                        border.color: Theme.outline_variant
                        border.width: 1

                        Canvas {
                            id: qrCanvas
                            anchors.fill: parent
                            anchors.margins: 12
                            onPaint: {
                                let ctx = getContext("2d");
                                if (!ctx) return;
                                ctx.fillStyle = "#ffffff";
                                ctx.fillRect(0, 0, width, height);
                                let rows = root.qrRows || [];
                                let n = rows.length;
                                if (n <= 0) return;
                                let cell = Math.floor(Math.min(width, height) / n);
                                let offX = Math.floor((width - cell * n) / 2);
                                let offY = Math.floor((height - cell * n) / 2);
                                ctx.fillStyle = "#090a10";
                                for (let r = 0; r < n; r++) {
                                    let rowStr = rows[r];
                                    for (let c = 0; c < rowStr.length; c++) {
                                        if (rowStr.charAt(c) === "1") {
                                            ctx.fillRect(offX + c * cell, offY + r * cell, cell, cell);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            height: 30
                            radius: Theme.radiusSm
                            color: Theme.widgetBg
                            border.color: Theme.widgetBorder
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 14
                                text: root.qrPassword !== "" ? ("pass: " + root.qrPassword) : "open network (no password)"
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 10
                                color: Theme.on_surface
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        Rectangle {
                            visible: root.qrPassword !== ""
                            height: 30
                            implicitWidth: cpPassTxt.implicitWidth + 16
                            radius: Theme.radiusPill
                            color: root.qrCopied ? Theme.primary : Theme.primary_overlay
                            border.color: Theme.primary
                            border.width: 1

                            Text {
                                id: cpPassTxt
                                anchors.centerIn: parent
                                text: root.qrCopied ? "copied" : "copy pass"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: root.qrCopied ? Theme.on_primary : Theme.primary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["wl-copy", root.qrPassword]);
                                    root.qrCopied = true;
                                    qrCopyTimer.restart();
                                }
                            }
                        }
                    }
                }
            }

            // ================= TAB 1: WI-FI =================
            ColumnLayout {
                visible: root.activeTab === "wifi" && !root.showQrSheet
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                // active connection card + ip/speed telemetry
                Rectangle {
                    id: activeCard
                    Layout.fillWidth: true
                    implicitHeight: isRenamingActive ? 64 : (activeTelemetryRow.visible ? 78 : 58)
                    color: NetworkService.isConnected ? Theme.primary_overlay : Theme.cardBg
                    radius: Theme.radiusMd
                    border.color: NetworkService.isConnected ? Theme.primary : Theme.cardBorder
                    border.width: 1
                    clip: true

                    property bool isRenamingActive: false

                    Behavior on implicitHeight { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 5
                        visible: !activeCard.isRenamingActive

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
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
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                                    color: NetworkService.isConnected ? Theme.primary : Theme.on_surface_variant
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    spacing: 4
                                    Layout.fillWidth: true

                                    Text {
                                        text: !NetworkService.isConnected
                                            ? "not connected"
                                            : (NetworkService.isWiredConnected ? "ethernet connection" : (root.activeSsidLower || "connected"))
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Theme.fontWeightBold
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
                                            : ("signal " + root.activeSignalPct + "%" + (root.ifaceName ? (" • " + root.ifaceName) : "")))
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: 10
                                    color: Theme.on_surface_variant
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            IconButton {
                                visible: NetworkService.isWifiConnected
                                icon: Theme.iconGrid
                                iconSize: Theme.fontSizeXs
                                tooltip: "show wi-fi qr code"
                                onClicked: root.fetchWifiQr()
                            }

                            Rectangle {
                                visible: NetworkService.isWifiConnected
                                height: 24
                                implicitWidth: discTxt.implicitWidth + 14
                                radius: Theme.radiusPill
                                color: discMouse.containsMouse ? Theme.error_overlay : "transparent"
                                border.color: discMouse.containsMouse ? Theme.error : Theme.primary
                                border.width: 1

                                Text {
                                    id: discTxt
                                    anchors.centerIn: parent
                                    text: discMouse.containsMouse ? "disconnect" : "linked"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: 10
                                    font.weight: Theme.fontWeightBold
                                    color: discMouse.containsMouse ? Theme.error : Theme.primary
                                }

                                MouseArea {
                                    id: discMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const iface = NetworkService.wifiDevice?.name;
                                        if (iface) Quickshell.execDetached(["nmcli", "dev", "disconnect", "iface", iface]);
                                    }
                                }
                            }
                        }

                        // live IPv4 / Gateway / Speed strip
                        RowLayout {
                            id: activeTelemetryRow
                            visible: NetworkService.isConnected && root.ip4Addr !== ""
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "ip " + root.ip4Addr + (root.gatewayAddr ? (" • gw " + root.gatewayAddr) : "")
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 9
                                color: Theme.on_surface_variant
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "↓" + root.formatSpeed(root.rxRateBps) + "  ↑" + root.formatSpeed(root.txRateBps)
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 9
                                font.weight: Theme.monoWeightBold
                                color: Theme.primary
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
                                font.variableAxes: Theme.sansAxes
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
                            tooltip: "reset"
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

                // available networks + saved profiles toggle card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMd
                    color: Theme.cardBg
                    border.color: Theme.cardBorder
                    border.width: 1
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: root.showSavedManager
                                    ? ("saved profiles (" + root.savedProfiles.length + ")")
                                    : ("wireless networks (" + root.sortedNetworks.length + ")")
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: Theme.on_surface
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                height: 24
                                implicitWidth: savedChipTxt.implicitWidth + 14
                                radius: Theme.radiusPill
                                color: root.showSavedManager ? Theme.primary_overlay : (savedMouse.containsMouse ? Theme.widgetHover : "transparent")
                                border.color: root.showSavedManager ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                Text {
                                    id: savedChipTxt
                                    anchors.centerIn: parent
                                    text: root.showSavedManager ? "nearby" : ("saved (" + root.savedProfiles.length + ")")
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: 10
                                    font.weight: root.showSavedManager ? Theme.fontWeightBold : Theme.fontWeightRegular
                                    color: root.showSavedManager ? Theme.primary : Theme.on_surface_variant
                                }

                                MouseArea {
                                    id: savedMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.showSavedManager = !root.showSavedManager
                                }
                            }

                            IconButton {
                                visible: NetworkService.wifiEnabled && !root.showSavedManager
                                icon: Theme.iconRefresh
                                iconSize: Theme.fontSizeXs
                                tooltip: "rescan"
                                onClicked: NetworkService.rescan()
                            }

                            IconButton {
                                icon: Theme.iconTerminal
                                iconSize: Theme.fontSizeXs
                                tooltip: "open nmtui"
                                onClicked: {
                                    Quickshell.execDetached(["kitty", "-e", "nmtui"]);
                                    popup.open = false;
                                }
                            }
                        }

                        // saved profiles manager list
                        ListView {
                            visible: root.showSavedManager
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 5
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.savedProfiles

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isAct: modelData.active === "true"
                                width: parent ? parent.width : 360
                                height: 42
                                radius: Theme.radiusSm
                                color: isAct ? Theme.primary_overlay : Theme.widgetBg
                                border.color: isAct ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: modelData.name.toLowerCase()
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: isAct ? Theme.fontWeightBold : Theme.fontWeightMedium
                                        color: isAct ? Theme.primary : Theme.on_surface
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    IconButton {
                                        icon: Theme.iconGrid
                                        iconSize: 11
                                        tooltip: "qr code"
                                        onClicked: root.fetchWifiQr(modelData.name)
                                    }

                                    IconButton {
                                        icon: Theme.iconTrash
                                        iconSize: 11
                                        tooltip: "forget network"
                                        onClicked: root.runNetCmd(["forget", modelData.uuid || modelData.name])
                                    }
                                }
                            }
                        }

                        // nearby wi-fi list
                        ListView {
                            id: netList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 6
                            boundsBehavior: Flickable.StopAtBounds
                            visible: !root.showSavedManager && NetworkService.wifiEnabled && root.sortedNetworks.length > 0
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

                                property bool isExpanded: false

                                width: netList.width
                                height: isExpanded ? 94 : 52
                                color: isItemConnected ? Theme.primary_overlay : (itemHover.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                radius: Theme.radiusMd
                                border.color: (isItemConnected || netItem.isExpanded) ? Theme.primary : Theme.widgetBorder
                                border.width: 1
                                clip: true

                                Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                                onIsExpandedChanged: {
                                    if (isExpanded && !isItemConnected) pwdInput.forceActiveFocus();
                                }

                                MouseArea {
                                    id: itemHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (!netItem.isItemConnected) netItem.isExpanded = !netItem.isExpanded
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
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
                                                font.variableAxes: Theme.iconAxes
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
                                                font.variableAxes: Theme.sansAxes
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: netItem.isItemConnected ? Theme.fontWeightBold : Theme.fontWeightDemiBold
                                                color: netItem.isItemConnected ? Theme.primary : Theme.on_surface
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            RowLayout {
                                                spacing: 4
                                                Text {
                                                    text: (netItem.isItemConnected ? "connected • " : "") + netItem.sigPct + "% signal" + (netItem.isSecured && !netItem.isItemConnected ? " • secured" : "")
                                                    font.family: Theme.fontMono
                                                    font.variableAxes: Theme.monoAxes
                                                    font.pixelSize: Theme.fontSizeXs
                                                    color: netItem.isItemConnected ? Theme.primary : Theme.on_surface_variant
                                                }
                                            }
                                        }

                                        IconButton {
                                            icon: netItem.isItemConnected ? Theme.iconClose : (netItem.isExpanded ? Theme.iconChevronUp : Theme.iconChevronDown)
                                            iconSize: Theme.fontSizeXs
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
                                                font.variableAxes: Theme.sansAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.on_surface
                                                selectByMouse: true

                                                Text {
                                                    anchors.fill: parent
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: netItem.isSecured ? "password (blank if saved)..." : "open network"
                                                    font: parent.font
                                                    color: Theme.on_surface_disabled
                                                    visible: pwdInput.text === ""
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
                                            onClicked: showPassword = !showPassword
                                        }

                                        Rectangle {
                                            height: 30
                                            implicitWidth: connTxt.implicitWidth + 16
                                            radius: Theme.radiusPill
                                            color: connectBtnMouse.containsMouse ? Theme.primary_overlay : Theme.primary
                                            border.color: Theme.primary
                                            border.width: 1

                                            Text {
                                                id: connTxt
                                                anchors.centerIn: parent
                                                text: "connect"
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Theme.fontWeightBold
                                                color: connectBtnMouse.containsMouse ? Theme.primary : Theme.on_primary
                                            }

                                            MouseArea {
                                                id: connectBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const target = netItem.networkName;
                                                    if (!target) return;
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

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: !root.showSavedManager && (!NetworkService.wifiEnabled || root.sortedNetworks.length === 0)

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: !NetworkService.wifiEnabled ? "wi-fi is turned off" : "scanning for wireless networks..."
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.on_surface
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: !NetworkService.wifiEnabled
                                        ? "flip the switch above or right-click the bar icon"
                                        : "searching local ssids in range..."
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_surface_variant
                                }
                            }
                        }
                    }
                }
            }

            // ================= TAB 2: VPN =================
            Rectangle {
                visible: root.activeTab === "vpn" && !root.showQrSheet
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "vpn & wireguard tunnels"
                            font.family: Theme.fontDisplay
                            font.variableAxes: Theme.displayAxes
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_surface
                            Layout.fillWidth: true
                        }

                        IconButton {
                            icon: Theme.iconTerminal
                            iconSize: Theme.fontSizeXs
                            tooltip: "manage in nmtui"
                            onClicked: {
                                Quickshell.execDetached(["kitty", "-e", "nmtui"]);
                                popup.open = false;
                            }
                        }
                    }

                    ListView {
                        visible: root.vpnProfiles.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.vpnProfiles

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isAct: modelData.active === "true"
                            width: parent ? parent.width : 360
                            height: 52
                            radius: Theme.radiusMd
                            color: isAct ? Theme.primary_overlay : Theme.widgetBg
                            border.color: isAct ? Theme.primary : Theme.widgetBorder
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Text {
                                    text: Theme.iconShield
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeMd
                                    color: isAct ? Theme.primary : Theme.on_surface_variant
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: modelData.name.toLowerCase()
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: isAct ? Theme.fontWeightBold : Theme.fontWeightMedium
                                        color: isAct ? Theme.primary : Theme.on_surface
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.type + (isAct ? " • tunnel up" : " • inactive")
                                        font.family: Theme.fontMono
                                        font.variableAxes: Theme.monoAxes
                                        font.pixelSize: 10
                                        color: isAct ? Theme.primary : Theme.on_surface_variant
                                    }
                                }

                                ToggleSwitch {
                                    checked: isAct
                                    onToggled: root.runNetCmd(["vpn", isAct ? "down" : "up", modelData.name])
                                }
                            }
                        }
                    }

                    Item {
                        visible: root.vpnProfiles.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 24
                            spacing: 6

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Theme.iconShield
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeTitle
                                color: Theme.on_surface_variant
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "no vpn profiles found"
                                font.family: Theme.fontDisplay
                                font.variableAxes: Theme.displayAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: Theme.on_surface
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: "import an openvpn or wireguard config via nmcli / nmtui and it appears here for one-click toggling"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.on_surface_variant
                            }
                        }
                    }
                }
            }

            // ================= TAB 3: HOTSPOT =================
            Rectangle {
                visible: root.activeTab === "hotspot" && !root.showQrSheet
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: root.hotspotActive ? Theme.warn : Theme.cardBorder
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: Theme.iconRadio
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeLg
                            color: root.hotspotActive ? Theme.warn : Theme.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: root.hotspotActive ? "hotspot active" : "wi-fi access point"
                                font.family: Theme.fontDisplay
                                font.variableAxes: Theme.displayAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: root.hotspotActive ? Theme.warn : Theme.on_surface
                            }

                            Text {
                                text: root.hotspotActive ? "sharing network over wpa2 ap" : "configure ssid and passphrase"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: 10
                                color: Theme.on_surface_variant
                            }
                        }

                        Rectangle {
                            height: 30
                            implicitWidth: hsBtnTxt.implicitWidth + 18
                            radius: Theme.radiusPill
                            color: root.hotspotActive ? Theme.error : Theme.primary

                            Text {
                                id: hsBtnTxt
                                anchors.centerIn: parent
                                text: root.hotspotActive ? "stop" : "start ap"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: root.hotspotActive ? Theme.on_error : Theme.on_primary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (Settings) {
                                        Settings.hotspotSsid = hsSsidIn.text.trim() || "quickshell-ap";
                                        Settings.hotspotPassword = hsPassIn.text.trim() || "nixoshotspot";
                                    }
                                    root.runNetCmd([
                                        "hotspot",
                                        root.hotspotActive ? "off" : "on",
                                        hsSsidIn.text.trim() || "quickshell-ap",
                                        hsPassIn.text.trim() || "nixoshotspot"
                                    ]);
                                }
                            }
                        }
                    }

                    Text {
                        text: "hotspot ssid"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.pixelSize: 10
                        color: Theme.on_surface_variant
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: Theme.radiusSm
                        color: Theme.widgetBg
                        border.color: hsSsidIn.activeFocus ? Theme.primary : Theme.widgetBorder
                        border.width: 1

                        TextInput {
                            id: hsSsidIn
                            anchors.fill: parent
                            anchors.margins: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: Settings?.hotspotSsid || "quickshell-ap"
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface
                            selectByMouse: true
                        }
                    }

                    Text {
                        text: "wpa2 passphrase (min 8 chars)"
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.pixelSize: 10
                        color: Theme.on_surface_variant
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: Theme.radiusSm
                        color: Theme.widgetBg
                        border.color: hsPassIn.activeFocus ? Theme.primary : Theme.widgetBorder
                        border.width: 1

                        TextInput {
                            id: hsPassIn
                            anchors.fill: parent
                            anchors.margins: 8
                            verticalAlignment: TextInput.AlignVCenter
                            text: Settings?.hotspotPassword || "nixoshotspot"
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface
                            selectByMouse: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 32
                        radius: Theme.radiusPill
                        color: hsQrMouse.containsMouse ? Theme.primary_overlay : Theme.widgetBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Theme.iconGrid
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.primary
                            }

                            Text {
                                text: "generate hotspot qr code"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightMedium
                                color: Theme.on_surface
                            }
                        }

                        MouseArea {
                            id: hsQrMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.fetchWifiQr(hsSsidIn.text.trim() || "quickshell-ap", hsPassIn.text.trim() || "nixoshotspot")
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
