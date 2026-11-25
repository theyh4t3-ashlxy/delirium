// Bluetooth.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../theme/confFormat.mjs" as ConfFmt
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Hyprland

BarPill {
    id: root

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isIslands
    readonly property int effectiveBarMargin: isFloatingBar ? ((Settings?.barMargin > 0) ? Settings.barMargin : 8) : 0

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool isPowered: adapter ? adapter.enabled : false
    readonly property bool isDiscovering: adapter ? adapter.discovering : false
    property bool pairedOnlyFilter: false

    readonly property var rawDevices: (root.isPowered && root.adapter?.devices?.values) ? root.adapter.devices.values : []

    function isRealDeviceName(name, addr) {
        if (!name) return false;
        let trimmed = name.trim();
        if (trimmed === "" || trimmed === addr) return false;
        return !/^([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}$/.test(trimmed);
    }

    readonly property var sortedDevices: {
        let list = [];
        for (let i = 0; i < rawDevices.length; i++) {
            let d = rawDevices[i];
            if (!d) continue;
            if (root.pairedOnlyFilter && !d.paired && !d.connected) continue;
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

    // WirePlumber BlueZ audio profile map keyed by normalized MAC/name
    property var audioProfilesByAddr: ({})

    function refreshAudioProfiles() {
        if (!root.isPowered || !root.hasConnectedDevice) {
            root.audioProfilesByAddr = ({});
            return;
        }
        let py = "import re, subprocess\n" +
            "def esc(s): return s.replace('\\\\','\\\\\\\\').replace('\\n','\\\\n').replace('=','\\\\e').replace(',','\\\\c').replace(';','\\\\s').replace('|','\\\\p')\n" +
            "try:\n" +
            "  st = subprocess.check_output(['wpctl', 'status'], text=True, timeout=2)\n" +
            "except Exception:\n" +
            "  print('count=0'); raise SystemExit(0)\n" +
            "in_audio = False\n" +
            "in_devs = False\n" +
            "dev_ids = []\n" +
            "for line in st.splitlines():\n" +
            "  s = line.strip()\n" +
            "  if s == 'Audio': in_audio = True; in_devs = False; continue\n" +
            "  if s in ('Video', 'Settings'): in_audio = False; in_devs = False; continue\n" +
            "  if in_audio and 'Devices:' in s: in_devs = True; continue\n" +
            "  if in_audio and in_devs:\n" +
            "    if any(h in s for h in ('Sinks:', 'Sources:', 'Filters:', 'Streams:')):\n" +
            "      in_devs = False; continue\n" +
            "    m = re.match(r'^[^0-9]*(\\d+)\\.\\s+(.*)$', s)\n" +
            "    if m and '[bluez5]' in m.group(2).lower():\n" +
            "      dev_ids.append(m.group(1))\n" +
            "cards = []\n" +
            "for did in dev_ids:\n" +
            "  try:\n" +
            "    ins = subprocess.check_output(['wpctl', 'inspect', did], text=True, timeout=2)\n" +
            "  except Exception: continue\n" +
            "  mac = ''\n" +
            "  for ln in ins.splitlines():\n" +
            "    mm = re.search(r'([0-9a-fA-F]{2}(?:[:_-][0-9a-fA-F]{2}){5})', ln)\n" +
            "    if mm: mac = mm.group(1).replace('-', ':').replace('_', ':').upper(); break\n" +
            "  # query profiles from wpctl status -n or inspect settings\n" +
            "  profs = []\n" +
            "  cur_idx = ''\n" +
            "  # wpctl inspect prints * index lines under Profiles section if available\n" +
            "  cards.append((did, mac))\n" +
            "# Also try pw-dump for exact profiles + active index\n" +
            "try:\n" +
            "  import json\n" +
            "  objs = json.loads(subprocess.check_output(['pw-dump'], text=True, timeout=3))\n" +
            "  out = []\n" +
            "  for o in objs:\n" +
            "    if o.get('type') != 'PipeWire:Interface:Device': continue\n" +
            "    props = o.get('info', {}).get('props', {})\n" +
            "    if props.get('device.api') != 'bluez5': continue\n" +
            "    oid = str(o.get('id', ''))\n" +
            "    mac = str(props.get('api.bluez5.address', '')).upper()\n" +
            "    params = o.get('info', {}).get('params', {})\n" +
            "    ep = params.get('EnumProfile') or []\n" +
            "    pr = params.get('Profile') or []\n" +
            "    cur_name = pr[0].get('name', '') if pr else ''\n" +
            "    pitems = []\n" +
            "    for p in ep:\n" +
            "      pname = p.get('name', '')\n" +
            "      if pname in ('off', ''): continue\n" +
            "      pitems.append(f\"{p.get('index', 0)}:{pname}:{p.get('description', pname)}\")\n" +
            "    out.append((oid, mac, cur_name, '|'.join(pitems)))\n" +
            "  print(f'count={len(out)}')\n" +
            "  for i, (oid, mac, cur_n, plist) in enumerate(out):\n" +
            "    print(f'btp.{i}.id={oid}')\n" +
            "    print(f'btp.{i}.mac={esc(mac)}')\n" +
            "    print(f'btp.{i}.cur={esc(cur_n)}')\n" +
            "    print(f'btp.{i}.profiles={esc(plist)}')\n" +
            "except Exception:\n" +
            "  print('count=0')\n";
        if (btProfileProc.running) btProfileProc.running = false;
        btProfileProc.command = ["python3", "-c", py];
        btProfileProc.running = true;
    }

    Process {
        id: btProfileProc
        stdout: StdioCollector {
            onStreamFinished: {
                let recs = ConfFmt.parseRecords(text || "", "btp") || [];
                let map = {};
                for (let i = 0; i < recs.length; i++) {
                    let r = recs[i];
                    if (!r || !r.mac) continue;
                    let list = [];
                    let rawP = String(r.profiles || "").split("|").filter(Boolean);
                    for (let j = 0; j < rawP.length; j++) {
                        let cols = rawP[j].split(":");
                        if (cols.length >= 2) {
                            list.push({
                                index: parseInt(cols[0], 10) || 0,
                                name: cols[1],
                                desc: cols.slice(2).join(":") || cols[1]
                            });
                        }
                    }
                    map[r.mac.toUpperCase()] = { id: r.id, cur: r.cur || "", list: list };
                }
                root.audioProfilesByAddr = map;
            }
        }
    }

    active: popup.open
    hovered: btMouse.containsMouse
    pressed: btMouse.pressed
    clip: true

    implicitWidth: {
        if (Theme.isVertical) return pillSize;
        if (btMouse.containsMouse || popup.open || root.hasConnectedDevice) return btRow.implicitWidth + 20;
        return pillSize;
    }

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

    function shortProfileLabel(name) {
        let s = String(name || "").toLowerCase();
        if (s.indexOf("a2dp") !== -1) return "hi-fi a2dp";
        if (s.indexOf("headset") !== -1) return "mic hfp";
        return s.slice(0, 14);
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
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            color: !root.isPowered ? Theme.on_surface_variant : (root.hasConnectedDevice || popup.open || btMouse.containsMouse ? Theme.primary : Theme.on_surface)

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Theme.isVertical && (root.hasConnectedDevice || btMouse.containsMouse || popup.open)
            text: !root.isPowered ? "off" : (root.hasConnectedDevice ? root.primaryDeviceName : "bluetooth")
            font.family: Theme.fontFamily
            font.variableAxes: Theme.sansAxes
            font.pixelSize: Theme.fontSizeSm
            font.weight: Theme.fontWeightMedium
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
        screen: root.barScreen
        cardWidth: 420
        cardHeight: 480

        onOpenChanged: {
            if (open) root.refreshAudioProfiles();
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
                    color: !root.isPowered ? Theme.widgetBg : Theme.primary_overlay
                    border.color: !root.isPowered ? Theme.widgetBorder : Theme.alpha(Theme.primary, 0.35)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    Text {
                        anchors.centerIn: parent
                        text: root.isPowered ? (root.hasConnectedDevice ? Theme.iconBluetoothConnected : Theme.iconBluetooth) : Theme.iconBluetoothOff
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                        color: root.isPowered ? Theme.primary : Theme.on_surface_variant
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        text: "bluetooth & audio"
                        font.family: Theme.fontDisplay
                        font.variableAxes: Theme.displayAxes
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
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
                    color: !root.isPowered ? Theme.widgetBg : (root.isDiscovering ? Theme.warn_overlay : Theme.primary_overlay)
                    border.color: !root.isPowered ? Theme.widgetBorder : (root.isDiscovering ? Theme.warn : Theme.primary)
                    border.width: 1

                    Text {
                        id: statusText
                        anchors.centerIn: parent
                        text: !root.isPowered ? "off" : (root.isDiscovering ? "scanning" : (root.hasConnectedDevice ? (root.connectedDevices.length + " linked") : "ready"))
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.monoWeightBold
                        color: !root.isPowered ? Theme.on_surface_variant : (root.isDiscovering ? Theme.warn : Theme.primary)
                    }
                }

                ToggleSwitch {
                    checked: root.isPowered
                    onToggled: {
                        if (root.adapter) root.adapter.enabled = !root.adapter.enabled;
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
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                            color: Theme.primary
                        }

                        Text {
                            text: "devices (" + root.sortedDevices.length + ")"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_surface
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: root.isPowered
                            height: 24
                            implicitWidth: pairFilterTxt.implicitWidth + 12
                            radius: Theme.radiusPill
                            color: root.pairedOnlyFilter ? Theme.primary_overlay : "transparent"
                            border.color: root.pairedOnlyFilter ? Theme.primary : Theme.widgetBorder
                            border.width: 1

                            Text {
                                id: pairFilterTxt
                                anchors.centerIn: parent
                                text: "paired"
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 9
                                font.weight: root.pairedOnlyFilter ? Theme.monoWeightBold : Theme.monoWeightRegular
                                color: root.pairedOnlyFilter ? Theme.primary : Theme.on_surface_variant
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.pairedOnlyFilter = !root.pairedOnlyFilter
                            }
                        }

                        Rectangle {
                            visible: root.isPowered && root.adapter !== null
                            height: 24
                            implicitWidth: discTxt.implicitWidth + 12
                            radius: Theme.radiusPill
                            color: root.adapter?.discoverable ? Theme.primary_overlay : "transparent"
                            border.color: root.adapter?.discoverable ? Theme.primary : Theme.widgetBorder
                            border.width: 1

                            Text {
                                id: discTxt
                                anchors.centerIn: parent
                                text: root.adapter?.discoverable ? "visible" : "hidden"
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 9
                                color: root.adapter?.discoverable ? Theme.primary : Theme.on_surface_variant
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.adapter) root.adapter.discoverable = !root.adapter.discoverable;
                                }
                            }
                        }

                        Rectangle {
                            visible: root.isPowered && root.adapter !== null
                            height: 24
                            implicitWidth: scanChipRow.implicitWidth + 14
                            radius: Theme.radiusPill
                            color: root.isDiscovering ? Theme.primary_overlay : (scanMouse.containsMouse ? Theme.widgetHover : "transparent")
                            border.color: root.isDiscovering ? Theme.primary : Theme.widgetBorder
                            border.width: 1

                            RowLayout {
                                id: scanChipRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    visible: !Theme.isTextIconSet
                                    text: Theme.iconRefresh
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    color: root.isDiscovering ? Theme.primary : Theme.on_surface_variant
                                }

                                Text {
                                    text: root.isDiscovering ? "stop" : "scan"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: root.isDiscovering ? Theme.fontWeightBold : Theme.fontWeightRegular
                                    color: root.isDiscovering ? Theme.primary : Theme.on_surface_variant
                                }
                            }

                            MouseArea {
                                id: scanMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.adapter) root.adapter.discovering = !root.adapter.discovering;
                                }
                            }
                        }
                    }

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
                                    readonly property string addrKey: String(modelData?.address || "").toUpperCase()
                                    readonly property var wpProfInfo: root.audioProfilesByAddr[addrKey] ?? null
                                    readonly property bool hasAudioProfiles: Boolean(modelData?.connected && wpProfInfo && wpProfInfo.list && wpProfInfo.list.length > 1)

                                    width: devCol.width
                                    implicitHeight: devInnerCol.implicitHeight + 14
                                    radius: Theme.radiusMd
                                    color: modelData.connected ? Theme.primary_overlay : (dMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                    border.color: modelData.connected ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

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
                                            profileRefreshDelayTimer.restart();
                                        }
                                    }

                                    Timer {
                                        id: profileRefreshDelayTimer
                                        interval: 900
                                        onTriggered: root.refreshAudioProfiles()
                                    }

                                    ColumnLayout {
                                        id: devInnerCol
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
                                                color: modelData.connected ? Theme.alpha(Theme.primary, 0.22) : Theme.cardBg
                                                border.color: modelData.connected ? Theme.alpha(Theme.primary, 0.45) : Theme.widgetBorder
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.getDeviceIcon(modelData)
                                                    font.family: Theme.fontIcon
                                                    font.variableAxes: Theme.iconAxes
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
                                                    font.variableAxes: Theme.sansAxes
                                                    font.pixelSize: Theme.fontSizeSm
                                                    font.weight: modelData.connected ? Theme.fontWeightBold : Theme.fontWeightDemiBold
                                                    color: modelData.connected ? Theme.primary : Theme.on_surface
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                RowLayout {
                                                    spacing: 5

                                                    Text {
                                                        text: {
                                                            if (modelData.pairing) return "pairing...";
                                                            if (modelData.connected) return "connected";
                                                            return modelData.paired ? "paired" : "available";
                                                        }
                                                        font.family: Theme.fontMono
                                                        font.variableAxes: Theme.monoAxes
                                                        font.pixelSize: 10
                                                        color: modelData.connected ? Theme.primary : Theme.on_surface_variant
                                                    }

                                                    Text {
                                                        visible: modelData.trusted
                                                        text: "• trusted"
                                                        font.family: Theme.fontMono
                                                        font.variableAxes: Theme.monoAxes
                                                        font.pixelSize: 9
                                                        color: Theme.on_surface_variant
                                                    }

                                                    Text {
                                                        visible: btDeviceDelegate.batPct >= 0
                                                        text: "• " + btDeviceDelegate.batPct + "%"
                                                        font.family: Theme.fontMono
                                                        font.variableAxes: Theme.monoAxes
                                                        font.pixelSize: 10
                                                        font.weight: Theme.monoWeightBold
                                                        color: Theme.getBatteryColor(btDeviceDelegate.batPct, false)
                                                    }
                                                }
                                            }

                                            // trust toggle button
                                            IconButton {
                                                visible: modelData.paired || modelData.connected
                                                icon: Theme.iconShield
                                                iconSize: 12
                                                implicitWidth: 26
                                                implicitHeight: 26
                                                highlighted: modelData.trusted
                                                tooltip: modelData.trusted ? "untrust device" : "trust device"
                                                onClicked: modelData.trusted = !modelData.trusted
                                            }

                                            // connect / pair / disconnect pill
                                            Rectangle {
                                                height: 26
                                                implicitWidth: actTxt.implicitWidth + 14
                                                radius: Theme.radiusPill
                                                color: actMouse.containsMouse
                                                    ? (modelData.connected ? Theme.error_overlay : Theme.primary)
                                                    : (modelData.connected ? "transparent" : Theme.primary_overlay)
                                                border.color: actMouse.containsMouse && modelData.connected ? Theme.error : Theme.primary
                                                border.width: 1

                                                Text {
                                                    id: actTxt
                                                    anchors.centerIn: parent
                                                    text: {
                                                        if (modelData.pairing) return "cancel";
                                                        if (modelData.connected) return actMouse.containsMouse ? "disconnect" : "linked";
                                                        return modelData.paired ? "connect" : "pair";
                                                    }
                                                    font.family: Theme.fontFamily
                                                    font.variableAxes: Theme.sansAxes
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: Theme.fontWeightBold
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
                                                        if (modelData.pairing && modelData.cancelPair) {
                                                            modelData.cancelPair();
                                                        } else if (modelData.connected && modelData.disconnect) {
                                                            modelData.disconnect();
                                                        } else if (!modelData.paired && modelData.pair) {
                                                            modelData.trusted = true;
                                                            modelData.pair();
                                                        } else if (modelData.connect) {
                                                            modelData.connect();
                                                        }
                                                        profileRefreshDelayTimer.restart();
                                                    }
                                                }
                                            }

                                            IconButton {
                                                visible: modelData.paired && !modelData.connected && modelData.forget !== undefined
                                                icon: Theme.iconTrash
                                                iconSize: 12
                                                implicitWidth: 26
                                                implicitHeight: 26
                                                tooltip: "forget device"
                                                onClicked: if (modelData.forget) modelData.forget()
                                            }
                                        }

                                        // BlueZ PipeWire profile switcher (A2DP Hi-Fi vs HFP Mic)
                                        RowLayout {
                                            visible: btDeviceDelegate.hasAudioProfiles
                                            Layout.fillWidth: true
                                            spacing: 5

                                            Text {
                                                text: "codec:"
                                                font.family: Theme.fontMono
                                                font.variableAxes: Theme.monoAxes
                                                font.pixelSize: 9
                                                color: Theme.on_surface_variant
                                            }

                                            Repeater {
                                                model: btDeviceDelegate.wpProfInfo ? btDeviceDelegate.wpProfInfo.list : []

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    readonly property bool isCur: modelData.name === (btDeviceDelegate.wpProfInfo?.cur || "")
                                                    height: 20
                                                    implicitWidth: cpTxt.implicitWidth + 10
                                                    radius: Theme.radiusPill
                                                    color: isCur ? Theme.primary : Theme.cardBg
                                                    border.color: isCur ? Theme.primary : Theme.widgetBorder
                                                    border.width: 1

                                                    Text {
                                                        id: cpTxt
                                                        anchors.centerIn: parent
                                                        text: root.shortProfileLabel(modelData.name)
                                                        font.family: Theme.fontMono
                                                        font.variableAxes: Theme.monoAxes
                                                        font.pixelSize: 9
                                                        font.weight: isCur ? Theme.monoWeightBold : Theme.monoWeightRegular
                                                        color: isCur ? Theme.on_primary : Theme.on_surface_variant
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            let cid = btDeviceDelegate.wpProfInfo?.id;
                                                            if (cid) {
                                                                Quickshell.execDetached(["wpctl", "set-profile", String(cid), String(modelData.index)]);
                                                                profileRefreshDelayTimer.restart();
                                                            }
                                                        }
                                                    }
                                                }
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
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeMd : Theme.fontSizeTitle
                                    color: Theme.on_surface_variant
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: !root.isPowered
                                    ? "bluetooth is disabled"
                                    : (root.isDiscovering ? "searching for nearby devices..." : "no matching devices found")
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: Theme.on_surface
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: !root.isPowered
                                    ? (Theme.kaoSleepy + " flip the switch above or right-click the bar icon")
                                    : (Theme.kaoEmpty + " hit 'scan' to wake up the adapter")
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
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
