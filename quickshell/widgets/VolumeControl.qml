import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../controls"
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

Rectangle {
    id: volRoot

    property var barScreen: null
    property var barMonitor: null

    implicitWidth: Theme.isVertical
        ? Theme.barHeight - 8
        : (volIcon.implicitWidth + 24 + ((vMouse.containsMouse || popup.open) ? (volText.implicitWidth + 6) : 0))
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radiusPill
    color: popup.open
        ? Theme.primary_overlay
        : (volRoot.muted ? Theme.widgetBg : (vMouse.containsMouse ? Theme.pillHover : Theme.pillBg))
    border.color: Theme.pillBorder
    border.width: Theme.pillBorder === "transparent" ? 0 : 1

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // separate real hardware sinks from apps like cava/discord pretending to be speakers
    readonly property var outputDevices: {
        if (!Pipewire.nodes?.values) return [];
        return Pipewire.nodes.values.filter(n => n && !n.isStream && n.isSink && n.audio);
    }

    readonly property var inputDevices: {
        if (!Pipewire.nodes?.values) return [];
        return Pipewire.nodes.values.filter(n => n && !n.isStream && !n.isSink && n.audio);
    }

    // apps actually making noise right now
    readonly property var appStreams: {
        if (!Pipewire.nodes?.values) return [];
        return Pipewire.nodes.values.filter(n => n && n.isStream && !n.isSink && n.audio);
    }

    /*
    quickshell refuses to populate .audio or .properties unless the node is
    Explicitly tracked here, so throw the whole party into PwObjectTracker
    */
    PwObjectTracker {
        objects: [volRoot.sink, volRoot.source, ...volRoot.outputDevices, ...volRoot.inputDevices, ...volRoot.appStreams].filter(Boolean)
    }

    readonly property bool ready: sink?.ready ?? false
    readonly property real vol: (ready && sink?.audio) ? sink.audio.volume : 0
    readonly property bool muted: (ready && sink?.audio) ? sink.audio.muted : true
    readonly property real maxVolRatio: Math.max(1.0, (Settings?.volumeMax ?? 150) / 100.0)
    readonly property bool isOverdriven: !muted && vol > 1.005
    readonly property string mixerScript: Qt.resolvedUrl("../scripts/open-mixer.zsh").toString().replace(/^file:\/\//, "")

    property bool showInputs: false

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: Theme.isVertical ? undefined : parent.left
        anchors.leftMargin: Theme.isVertical ? 0 : 12
        anchors.horizontalCenter: Theme.isVertical ? parent.horizontalCenter : undefined
        spacing: 4

        Text {
            id: volIcon
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.getVolumeIcon(volRoot.vol, volRoot.muted)
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeMd
            color: popup.open
                ? Theme.primary
                : (volRoot.muted ? Theme.on_surface_disabled : (volRoot.isOverdriven ? Theme.warn : Theme.on_surface))
        }

        Text {
            id: volText
            anchors.verticalCenter: parent.verticalCenter
            visible: !Theme.isVertical && opacity > 0.01
            opacity: (vMouse.containsMouse || popup.open) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
            text: {
                if (volRoot.muted) return Theme.getVibe(Theme.kaoAnger + " shh", "muted", "muted");
                let pct = Math.round(volRoot.vol * 100);
                if (pct > 100) return Theme.getVibe(Theme.kaoPanic + " " + pct + "%", pct + "%", pct + "%");
                return pct + "%";
            }
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeXs
            color: popup.open
                ? Theme.primary
                : (volRoot.muted ? Theme.on_surface_disabled : (volRoot.isOverdriven ? Theme.warn : Theme.on_surface))
        }
    }

    function syncAnchor() {
        const coords = volRoot.mapToItem(null, 0, 0);
        if (!coords) return;
        popup.targetRelativeX = coords.x + (volRoot.width / 2);
        popup.targetRelativeY = coords.y + (volRoot.height / 2);
    }

    HoverFlyoutHandler {
        popup: popup
        mouseArea: vMouse
        updatePos: () => volRoot.syncAnchor()
    }

    MouseArea {
        id: vMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                volRoot.syncAnchor();
                if (!popup.open) {
                    popup.pinned = true;
                    popup.open = true;
                } else if (!popup.pinned) {
                    popup.pinned = true;
                } else {
                    popup.pinned = false;
                    popup.open = false;
                }
            } else if (mouse.button === Qt.RightButton) {
                if (volRoot.ready && volRoot.sink?.audio) {
                    volRoot.sink.audio.muted = !volRoot.sink.audio.muted;
                }
            } else if (mouse.button === Qt.MiddleButton) {
                Quickshell.execDetached([volRoot.mixerScript]);
            }
        }

        onWheel: (wheel) => {
            if (volRoot.ready && volRoot.sink?.audio) {
                let step = (Settings?.volumeStep ?? 5) / 100.0;
                let next = volRoot.sink.audio.volume + (wheel.angleDelta.y > 0 ? step : -step);
                volRoot.sink.audio.volume = Math.max(0.0, Math.min(volRoot.maxVolRatio, next));
                if (wheel.angleDelta.y > 0 && volRoot.sink.audio.muted) {
                    volRoot.sink.audio.muted = false;
                }
            }
        }
    }

    Connections {
        target: Settings
        function onRequestVolumeToggle() {
            volRoot.syncAnchor();
            popup.open = !popup.open;
        }
        function onRequestVolumeOpen() {
            volRoot.syncAnchor();
            popup.open = true;
        }
        function onRequestVolumeClose() {
            popup.open = false;
        }
    }

    PopupPanel {
        id: popup
        screen: volRoot.barScreen
        cardWidth: 400
        cardHeight: Math.max(Theme.popupMinHeight, Math.min(Theme.popupMaxHeight, volContentLayout.implicitHeight + (Theme.popupPadding * 2)))

        content: ColumnLayout {
            id: volContentLayout
            anchors.fill: parent
            spacing: Theme.popupSpacing

            // top header with reactive pipewire commentary
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "audio & mixer"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.on_surface
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (volRoot.muted) return Theme.getFlavor("volume_muted", "output muted");
                            if (volRoot.isOverdriven) return Theme.getFlavor("volume_high", "overdriving preamp past 100%");
                            if (volRoot.appStreams.length > 0) return Theme.getFlavor("media_playing", volRoot.appStreams.length + " active audio stream(s)");
                            return Theme.getFlavor("media_quiet", "pipewire graph idle");
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        color: volRoot.isOverdriven ? Theme.warn : Theme.on_surface_variant
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    icon: Theme.iconSliders
                    iconSize: Theme.fontSizeMd
                    tooltip: "open external mixer"
                    onClicked: Quickshell.execDetached([volRoot.mixerScript])
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.popupDividerHeight
                color: Theme.cardBorder
            }

            // master output card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: outCol.implicitHeight + (Theme.popupCardPadding * 2) + 4
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: volRoot.isOverdriven ? Theme.warn : Theme.cardBorder
                border.width: 1

                ColumnLayout {
                    id: outCol
                    anchors.fill: parent
                    anchors.margins: Theme.popupCardPadding + 2
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "output"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.primary
                        }

                        Text {
                            text: ((volRoot.sink?.description || volRoot.sink?.nickname || volRoot.sink?.name || "default output")).toLowerCase()
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface_variant
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: Math.round(volRoot.vol * 100) + "%"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: volRoot.muted
                                ? Theme.on_surface_disabled
                                : (volRoot.isOverdriven ? Theme.warn : Theme.primary)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        IconButton {
                            icon: Theme.getVolumeIcon(volRoot.vol, volRoot.muted)
                            iconSize: Theme.fontSizeMd
                            tooltip: "toggle output mute"
                            onClicked: {
                                if (volRoot.sink?.audio) volRoot.sink.audio.muted = !volRoot.sink.audio.muted;
                            }
                        }

                        // track with a 100% tick mark if volumeMax allows overdriving past 100%
                        Item {
                            id: volTrack
                            Layout.fillWidth: true
                            height: 20

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 8
                                radius: Theme.radiusPill
                                color: Theme.pillBg
                                border.color: Theme.pillBorder
                                border.width: 1

                                Rectangle {
                                    width: parent.width * Math.min(1.0, Math.max(0.0, volRoot.vol / volRoot.maxVolRatio))
                                    height: parent.height
                                    radius: Theme.radiusPill
                                    color: volRoot.muted
                                        ? Theme.on_surface_disabled
                                        : (volRoot.isOverdriven ? Theme.warn : Theme.primary)

                                    Behavior on width { NumberAnimation { duration: 40 } }
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }

                                // subtle notch showing where 100% sits when max volume is > 100%
                                Rectangle {
                                    visible: volRoot.maxVolRatio > 1.01
                                    x: parent.width * (1.0 / volRoot.maxVolRatio)
                                    width: 2
                                    height: parent.height
                                    color: Theme.on_surface_variant
                                    opacity: 0.45
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true

                                function applySinkVolume(posX) {
                                    if (!volRoot.sink?.audio || width <= 0) return;
                                    const clamped = Math.max(0.0, Math.min(volRoot.maxVolRatio, (posX / width) * volRoot.maxVolRatio));
                                    volRoot.sink.audio.volume = clamped;
                                    if (volRoot.sink.audio.muted && clamped > 0) volRoot.sink.audio.muted = false;
                                }

                                onPressed: (mouse) => applySinkVolume(mouse.x)
                                onPositionChanged: (mouse) => { if (pressed) applySinkVolume(mouse.x); }
                            }
                        }
                    }

                    // quick presets that actually light up when you're near that percentage
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.popupCardGap

                        Repeater {
                            model: [
                                { label: "mute", val: 0.0, mute: true },
                                { label: "25%", val: 0.25, mute: false },
                                { label: "50%", val: 0.5, mute: false },
                                { label: "75%", val: 0.75, mute: false },
                                { label: "100%", val: 1.0, mute: false },
                                { label: "125%", val: 1.25, mute: false }
                            ].filter(p => p.mute || p.val <= volRoot.maxVolRatio + 0.01)

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 22
                                radius: Theme.radiusPill

                                readonly property bool isActive: modelData.mute
                                    ? volRoot.muted
                                    : (!volRoot.muted && Math.abs(volRoot.vol - modelData.val) < 0.03)

                                color: isActive
                                    ? Theme.primary
                                    : (presetMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                                border.color: isActive ? "transparent" : Theme.pillBorder
                                border.width: isActive ? 0 : 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: isActive ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: isActive ? Theme.on_primary : Theme.on_surface
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    id: presetMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (volRoot.sink?.audio) {
                                            if (modelData.mute) {
                                                volRoot.sink.audio.muted = !volRoot.sink.audio.muted;
                                            } else {
                                                volRoot.sink.audio.volume = modelData.val;
                                                volRoot.sink.audio.muted = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // microphone input card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: micCol.implicitHeight + (Theme.popupCardPadding * 2) + 4
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1

                readonly property bool micMuted: volRoot.source?.audio?.muted ?? true
                readonly property real micVol: volRoot.source?.audio?.volume ?? 0

                ColumnLayout {
                    id: micCol
                    anchors.fill: parent
                    anchors.margins: Theme.popupCardPadding + 2
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "microphone"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.primary
                        }

                        Text {
                            text: ((volRoot.source?.description || volRoot.source?.nickname || volRoot.source?.name || "default mic")).toLowerCase()
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface_variant
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: Math.round((volRoot.source?.audio?.volume ?? 0) * 100) + "%"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: (volRoot.source?.audio?.muted ?? false) ? Theme.on_surface_disabled : Theme.primary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        IconButton {
                            icon: (volRoot.source?.audio?.muted ?? false) ? Theme.iconMicMute : Theme.iconMic
                            iconSize: Theme.fontSizeMd
                            tooltip: "toggle microphone mute"
                            onClicked: {
                                if (volRoot.source?.audio) volRoot.source.audio.muted = !volRoot.source.audio.muted;
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            height: 20

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 8
                                radius: Theme.radiusPill
                                color: Theme.pillBg
                                border.color: Theme.pillBorder
                                border.width: 1

                                Rectangle {
                                    width: parent.width * Math.min(1.0, Math.max(0.0, volRoot.source?.audio?.volume ?? 0))
                                    height: parent.height
                                    radius: Theme.radiusPill
                                    color: (volRoot.source?.audio?.muted ?? false) ? Theme.on_surface_disabled : Theme.primary

                                    Behavior on width { NumberAnimation { duration: 40 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true

                                function applyMicVolume(posX) {
                                    if (!volRoot.source?.audio || width <= 0) return;
                                    const clamped = Math.max(0.0, Math.min(1.0, posX / width));
                                    volRoot.source.audio.volume = clamped;
                                    if (volRoot.source.audio.muted && clamped > 0) volRoot.source.audio.muted = false;
                                }

                                onPressed: (mouse) => applyMicVolume(mouse.x)
                                onPositionChanged: (mouse) => { if (pressed) applyMicVolume(mouse.x); }
                            }
                        }
                    }
                }
            }

            // per-application volume mixer so it actually earns the word "mixer"
            ColumnLayout {
                Layout.fillWidth: true
                visible: volRoot.appStreams.length > 0
                spacing: 6

                Text {
                    text: "active applications (" + volRoot.appStreams.length + ")"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightBold
                    color: Theme.primary
                }

                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(130, streamCol.implicitHeight)
                    contentHeight: streamCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: streamCol
                        width: parent.width
                        spacing: Theme.popupCardGap

                        Repeater {
                            model: volRoot.appStreams

                            delegate: Rectangle {
                                id: streamCard
                                required property var modelData

                                Layout.fillWidth: true
                                height: 38
                                radius: Theme.radiusSm
                                color: Theme.cardBg
                                border.color: Theme.cardBorder
                                border.width: 1

                                readonly property string appName: {
                                    let p = modelData?.properties;
                                    let n = (p ? (p["application.name"] || p["media.name"]) : "") || modelData?.description || modelData?.name || "stream";
                                    return n.toLowerCase();
                                }
                                readonly property string appIconSource: {
                                    let p = modelData?.properties;
                                    let candidate = (p ? (p["application.icon-name"] || p["application.process.binary"] || p["application.name"]) : "") || modelData?.name || "";
                                    return Theme.resolveAppIcon ? Theme.resolveAppIcon(candidate) : "";
                                }
                                readonly property real streamVol: modelData?.audio?.volume ?? 1.0
                                readonly property bool streamMuted: modelData?.audio?.muted ?? false

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: Theme.radiusXs
                                        color: Theme.pillBg

                                        IconImage {
                                            id: sIcon
                                            anchors.centerIn: parent
                                            width: 16
                                            height: 16
                                            source: streamCard.appIconSource
                                            visible: source !== "" && status !== Image.Error
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !sIcon.visible
                                            text: streamCard.streamMuted ? Theme.iconVolMute : Theme.iconMusic
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontSizeSm
                                            color: streamCard.streamMuted ? Theme.on_surface_disabled : Theme.primary
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (streamCard.modelData?.audio) {
                                                    streamCard.modelData.audio.muted = !streamCard.modelData.audio.muted;
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        text: streamCard.appName
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightMedium
                                        color: streamCard.streamMuted ? Theme.on_surface_disabled : Theme.on_surface
                                        elide: Text.ElideRight
                                        Layout.preferredWidth: 105
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        height: 18

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width
                                            height: 6
                                            radius: Theme.radiusPill
                                            color: Theme.pillBg

                                            Rectangle {
                                                width: parent.width * Math.min(1.0, Math.max(0.0, streamCard.streamVol))
                                                height: parent.height
                                                radius: Theme.radiusPill
                                                color: streamCard.streamMuted ? Theme.on_surface_disabled : Theme.secondary
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            preventStealing: true

                                            function setStreamVol(px) {
                                                if (!streamCard.modelData?.audio || width <= 0) return;
                                                let v = Math.max(0.0, Math.min(1.0, px / width));
                                                streamCard.modelData.audio.volume = v;
                                                if (streamCard.modelData.audio.muted && v > 0) streamCard.modelData.audio.muted = false;
                                            }

                                            onPressed: (mouse) => setStreamVol(mouse.x)
                                            onPositionChanged: (mouse) => { if (pressed) setStreamVol(mouse.x); }
                                        }
                                    }

                                    Text {
                                        text: Math.round(streamCard.streamVol * 100) + "%"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: streamCard.streamMuted ? Theme.on_surface_disabled : Theme.on_surface_variant
                                        Layout.preferredWidth: 34
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.popupDividerHeight
                color: Theme.cardBorder
            }

            // hardware device switcher with tabs for output vs input
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Rectangle {
                        height: 22
                        implicitWidth: outTabTxt.implicitWidth + 16
                        radius: Theme.radiusPill
                        color: !volRoot.showInputs ? Theme.primary_overlay : Theme.pillBg
                        border.color: !volRoot.showInputs ? Theme.primary : Theme.pillBorder
                        border.width: 1

                        Text {
                            id: outTabTxt
                            anchors.centerIn: parent
                            text: "outputs (" + volRoot.outputDevices.length + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: !volRoot.showInputs ? Theme.fontWeightBold : Theme.fontWeightMedium
                            color: !volRoot.showInputs ? Theme.primary : Theme.on_surface_variant
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: volRoot.showInputs = false
                        }
                    }

                    Rectangle {
                        height: 22
                        implicitWidth: inTabTxt.implicitWidth + 16
                        radius: Theme.radiusPill
                        color: volRoot.showInputs ? Theme.primary_overlay : Theme.pillBg
                        border.color: volRoot.showInputs ? Theme.primary : Theme.pillBorder
                        border.width: 1

                        Text {
                            id: inTabTxt
                            anchors.centerIn: parent
                            text: "inputs (" + volRoot.inputDevices.length + ")"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: volRoot.showInputs ? Theme.fontWeightBold : Theme.fontWeightMedium
                            color: volRoot.showInputs ? Theme.primary : Theme.on_surface_variant
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: volRoot.showInputs = true
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                Flickable {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(110, Math.max(36, devCol.implicitHeight))
                    contentHeight: devCol.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: devCol
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: volRoot.showInputs ? volRoot.inputDevices : volRoot.outputDevices

                            delegate: Rectangle {
                                id: devDelegate
                                required property var modelData

                                Layout.fillWidth: true
                                height: 32
                                radius: Theme.radiusSm
                                readonly property bool isCurrent: volRoot.showInputs
                                    ? (modelData?.id === volRoot.source?.id)
                                    : (modelData?.id === volRoot.sink?.id)

                                color: isCurrent
                                    ? Theme.primary_overlay
                                    : (devMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                                border.color: isCurrent ? Theme.primary : Theme.pillBorder
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 8

                                    Text {
                                        text: devDelegate.isCurrent
                                            ? Theme.iconCheckCircle
                                            : (volRoot.showInputs ? Theme.iconMic : Theme.iconHeadphones)
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeSm
                                        color: devDelegate.isCurrent ? Theme.primary : Theme.on_surface_variant
                                    }

                                    Text {
                                        text: ((devDelegate.modelData.description || devDelegate.modelData.nickname || devDelegate.modelData.name || "audio device")).toLowerCase()
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: devDelegate.isCurrent ? Theme.fontWeightBold : Theme.fontWeightRegular
                                        color: devDelegate.isCurrent ? Theme.primary : Theme.on_surface
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                MouseArea {
                                    id: devMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!devDelegate.modelData) return;
                                        if (volRoot.showInputs) {
                                            Pipewire.preferredDefaultAudioSource = devDelegate.modelData;
                                        } else {
                                            Pipewire.preferredDefaultAudioSink = devDelegate.modelData;
                                        }
                                        if (devDelegate.modelData.id) {
                                            Quickshell.execDetached(["wpctl", "set-default", String(devDelegate.modelData.id)]);
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
