// NowPlaying.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../controls"
import "../theme/confFormat.mjs" as ConfFmt

BarPill {
    id: root

    // Native PipeWire audio peak monitor
    PwNodePeakMonitor {
        id: peakMonitor
        node: (typeof Pipewire !== "undefined") ? Pipewire?.defaultAudioSink : null
        enabled: root.isPlaying && (popup.open || (Settings?.mediaWaveVisualizer ?? true))
    }

    property var musicApps: [
        { name: "mixtapes", id: "com.pocoguy.Muse", icon: Theme.iconRadio },
        { name: "amberol", id: "io.bassi.Amberol", icon: Theme.iconMusic },
        { name: "spotube", id: "com.github.KRTirtho.Spotube", icon: Theme.iconMusic },
        { name: "tauon", id: "com.github.taiko2k.tauonmb", icon: Theme.iconMusic },
        { name: "g4music", id: "com.github.neithern.g4music", icon: Theme.iconMusic },
        { name: "feishin", id: "org.feishin.feishin", icon: Theme.iconRadio },
        { name: "spotify", id: "com.spotify.Client", icon: Theme.iconMusic }
    ]
    property string preferredAppId: "com.pocoguy.Muse"
    readonly property var selectedApp: musicApps.find(a => a.id === preferredAppId) ?? musicApps[0]

    property bool dropdownOpen: false
    property int manualPlayerIndex: -1
    readonly property var activeList: Mpris.players.values ?? []

    // Prefer an actively playing stream unless the user manually cycled to a specific player
    readonly property var player: {
        if (!activeList || activeList.length === 0) return null;
        if (manualPlayerIndex >= 0 && manualPlayerIndex < activeList.length) {
            let manual = activeList[manualPlayerIndex];
            if (manual && manual.isPlaying) return manual;
            let otherPlaying = activeList.find(p => p.isPlaying);
            if (!otherPlaying) return manual;
        }
        return activeList.find(p => p.isPlaying) ?? activeList.find(p => p.trackTitle) ?? activeList[0] ?? null;
    }

    readonly property int currentPlayerIdx: {
        if (!player || !activeList) return 0;
        let idx = activeList.indexOf(player);
        return idx >= 0 ? idx : 0;
    }

    property bool compactMode: false
    readonly property bool hasTrack: player !== null && Boolean(player.trackTitle || player.trackArtist)
    readonly property bool isPlaying: player?.isPlaying ?? false
    readonly property string coverArtUrl: fixCoverUrl(player?.trackArtUrl)

    // Extract accent color from album art so the player card adapts to the cover
    ColorQuantizer {
        id: artQuantizer
        depth: 2
        source: root.coverArtUrl
    }

    readonly property color artAccent: {
        if (Theme.isMonochrome) return Theme.primary;
        if (root.coverArtUrl !== "" && artQuantizer.colors && artQuantizer.colors.length > 0) {
            for (let i = 0; i < artQuantizer.colors.length; i++) {
                let c = artQuantizer.colors[i];
                if (!c) continue;
                let mx = Math.max(c.r, c.g, c.b);
                let mn = Math.min(c.r, c.g, c.b);
                if (mx > 0.25 && (mx - mn) > 0.15) {
                    return Theme.blend(c, Theme.primary, 0.45);
                }
            }
        }
        return Theme.primary;
    }

    readonly property bool isCollapsed: (!root.hasTrack || root.compactMode) && !npMouse.containsMouse && !popup.open
    readonly property int hPad: Math.round(Theme.widgetPaddingH * Theme.paddingScaleMult) + 4

    active: popup.open
    hovered: npMouse.containsMouse
    pressed: npMouse.pressed
    activeBg: Theme.widgetActive
    activeBorder: Theme.alpha(root.artAccent, 0.55)
    clip: true

    implicitWidth: {
        if (Theme.isVertical) return root.pillSize;
        if (root.isCollapsed) {
            return Theme.isTextIconSet ? Math.max(root.pillSize, barIcon.implicitWidth + 14) : root.pillSize;
        }
        return row.implicitWidth + (root.hPad * 2);
    }

    Behavior on implicitWidth { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }

    property real trackPosition: root.player?.position ?? 0
    property var spectrumBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    readonly property string spectrumScript: Qt.resolvedUrl("../scripts/spectrum.py").toString().replace(/^file:\/\//, "")

    onIsPlayingChanged: {
        if (!isPlaying) {
            root.spectrumBands = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        }
    }

    Connections {
        target: root.player
        function onPositionChanged() {
            root.trackPosition = root.player?.position ?? 0;
        }
    }

    // Real PipeWire sink monitor 24-band FFT (only alive while playing + visible, drops flat to 0 on silence)
    Process {
        id: spectrumProc
        command: ["python3", root.spectrumScript]
        running: root.isPlaying && (Settings?.mediaWaveVisualizer ?? true) && (popup.open || (!Theme.isVertical && !root.isCollapsed))
        stdout: SplitParser {
            onRead: (data) => {
                let line = (data || "").trim();
                if (!line) return;
                let parts = line.split(",");
                if (parts.length !== 24) return;
                let next = [];
                for (let i = 0; i < 24; i++) {
                    let v = parseInt(parts[i], 10);
                    next.push(isNaN(v) ? 0 : Math.max(0, Math.min(1, v / 99.0)));
                }
                root.spectrumBands = next;
            }
        }
    }

    // Smooth timer for seekbar timestamps only
    Timer {
        id: tracker
        interval: popup.open ? 120 : 500
        running: root.isPlaying && popup.open
        repeat: true
        onTriggered: {
            if (root.player && popup.open) root.trackPosition = root.player.position ?? 0;
        }
    }

    function fixCoverUrl(url) {
        return Theme.fixCoverUrl(url);
    }

    function formatTime(seconds) {
        return Theme.formatTime(seconds);
    }

    function runPlayer(appId) {
        let target = appId || root.preferredAppId;
        if (!target) return;
        if (target.includes(".")) {
            Quickshell.execDetached(["flatpak", "run", target]);
        } else {
            Quickshell.execDetached([target]);
        }
    }

    function togglePlayback() {
        if (!root.player) return;
        if (root.player.canTogglePlaying) {
            root.player.togglePlaying();
        } else if (root.isPlaying && root.player.canPause) {
            root.player.pause();
        } else if (!root.isPlaying && root.player.canPlay) {
            root.player.play();
        }
    }

    function cycleLoopState() {
        if (!root.player || !root.player.loopSupported) return;
        let cur = root.player.loopState;
        if (cur === MprisLoopState.None) {
            root.player.loopState = MprisLoopState.Playlist;
        } else if (cur === MprisLoopState.Playlist) {
            root.player.loopState = MprisLoopState.Track;
        } else {
            root.player.loopState = MprisLoopState.None;
        }
    }

    property string activeTab: "player" // "player" | "lyrics"
    property string lyricsSource: "none" // "custom" | "sidecar" | "lrclib" | "file" | "none"
    property string lyricsPath: ""
    property string lyricsRaw: ""
    property bool lyricsLoading: false
    property bool isEditingLyrics: false
    property bool showLyricsPicker: false
    property string pickerCwd: ""
    property var pickerEntries: []
    property string lyricsStatusMsg: ""
    property string lastLyricsTrackKey: ""

    readonly property string lyricsScript: Qt.resolvedUrl("../scripts/lyrics.py").toString().replace(/^file:\/\//, "")
    readonly property string currentTrackKey: (player?.trackArtist || "") + "::" + (player?.trackTitle || "")

    readonly property var parsedLrc: parseLrcContent(lyricsRaw)
    readonly property int activeLrcIndex: {
        if (!parsedLrc || !parsedLrc.timed || !parsedLrc.lines || parsedLrc.lines.length === 0) return -1;
        let pos = root.trackPosition + 0.15;
        let active = -1;
        for (let i = 0; i < parsedLrc.lines.length; i++) {
            if (parsedLrc.lines[i].time <= pos) active = i;
            else break;
        }
        return active;
    }

    onCurrentTrackKeyChanged: {
        root.isEditingLyrics = false;
        root.showLyricsPicker = false;
        if (popup.open && root.activeTab === "lyrics" && root.hasTrack) {
            loadLyrics(false);
        } else {
            root.lastLyricsTrackKey = "";
            root.lyricsSource = "none";
            root.lyricsPath = "";
            root.lyricsRaw = "";
        }
    }

    function setPlaybackSpeed(rateVal) {
        if (!root.player) return;
        let r = Math.max(0.25, Math.min(2.0, Number(rateVal) || 1.0));
        try {
            root.player.rate = r;
        } catch (e) {}
        let id = root.player.identity || "";
        if (id) {
            Quickshell.execDetached(["playerctl", "--player=" + id.toLowerCase(), "rate", String(r)]);
        }
    }

    function parseLrcContent(raw) {
        let s = (raw || "").replace(/\r\n/g, "\n");
        if (!s.trim()) return { timed: false, lines: [] };
        let rows = s.split("\n");
        let timedLines = [];
        let plainLines = [];
        const tagRe = /\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]/g;

        for (let i = 0; i < rows.length; i++) {
            let line = rows[i];
            let tags = [];
            let m;
            tagRe.lastIndex = 0;
            while ((m = tagRe.exec(line)) !== null) {
                let mins = parseInt(m[1], 10);
                let secs = parseInt(m[2], 10);
                let frac = m[3] ? parseInt(m[3].padEnd(3, "0").slice(0, 3), 10) : 0;
                tags.push(mins * 60 + secs + frac / 1000.0);
            }
            let txt = line.replace(tagRe, "").trim();
            if (tags.length > 0) {
                for (let j = 0; j < tags.length; j++) {
                    if (txt !== "") timedLines.push({ time: tags[j], text: txt });
                }
            } else {
                // skip metadata header tags like [ar:...], [ti:...], [by:...]
                if (!/^\[(ar|ti|al|au|length|by|offset|re|ve):/i.test(line.trim())) {
                    plainLines.push({ time: -1, text: line });
                }
            }
        }
        if (timedLines.length > 0) {
            timedLines.sort((a, b) => a.time - b.time);
            return { timed: true, lines: timedLines };
        }
        return { timed: false, lines: plainLines };
    }

    function flashLyricsStatus(msg) {
        root.lyricsStatusMsg = msg;
        lyricsStatusTimer.restart();
    }

    function ensureLyricsLoaded() {
        if (!root.hasTrack) return;
        if (root.lastLyricsTrackKey !== root.currentTrackKey || (root.lyricsRaw === "" && root.lyricsSource === "none")) {
            loadLyrics(false);
        }
    }

    function loadLyrics(forceOnline) {
        if (!root.hasTrack) {
            root.lyricsRaw = "";
            root.lyricsSource = "none";
            root.lyricsPath = "";
            return;
        }
        let artist = root.player?.trackArtist || "";
        let title = root.player?.trackTitle || "";
        let trackUrl = root.player?.metadata?.["xesam:url"] ? String(root.player.metadata["xesam:url"]) : "";
        root.lastLyricsTrackKey = root.currentTrackKey;
        root.lyricsLoading = true;
        lyricsProc.command = ["python3", root.lyricsScript, "lookup", artist, title, trackUrl, forceOnline ? "1" : "0"];
        lyricsProc.running = false;
        lyricsProc.running = true;
    }

    function saveCustomLyrics(rawText) {
        if (!root.hasTrack) return;
        let artist = root.player?.trackArtist || "";
        let title = root.player?.trackTitle || "";
        root.lyricsLoading = true;
        lyricsProc.command = ["python3", root.lyricsScript, "save", artist, title, rawText || ""];
        lyricsProc.running = false;
        lyricsProc.running = true;
        root.isEditingLyrics = false;
        root.flashLyricsStatus("saved custom .lrc");
    }

    function clearCustomLyrics() {
        if (!root.hasTrack) return;
        let artist = root.player?.trackArtist || "";
        let title = root.player?.trackTitle || "";
        root.lyricsLoading = true;
        lyricsProc.command = ["python3", root.lyricsScript, "delete", artist, title];
        lyricsProc.running = false;
        lyricsProc.running = true;
        root.flashLyricsStatus("removed custom override");
    }

    function browseLyricsDir(dirPath) {
        pickerProc.command = ["python3", root.lyricsScript, "browse", dirPath || ""];
        pickerProc.running = false;
        pickerProc.running = true;
    }

    function loadLyricsFile(filePath) {
        if (!filePath) return;
        root.lyricsLoading = true;
        lyricsProc.command = ["python3", root.lyricsScript, "read", filePath];
        lyricsProc.running = false;
        lyricsProc.running = true;
        root.showLyricsPicker = false;
        root.isEditingLyrics = false;
        root.lastLyricsTrackKey = root.currentTrackKey;
        root.flashLyricsStatus("loaded local file");
    }

    Timer {
        id: lyricsStatusTimer
        interval: 2200
        onTriggered: root.lyricsStatusMsg = ""
    }

    Process {
        id: lyricsProc
        stdout: StdioCollector {
            onStreamFinished: {
                let kv = ConfFmt.parseFlatConf(text || "");
                root.lyricsSource = kv.source ? ConfFmt.unescapeField(kv.source) : "none";
                root.lyricsPath = kv.path ? ConfFmt.unescapeField(kv.path) : "";
                root.lyricsRaw = kv.content ? ConfFmt.unescapeField(kv.content) : "";
                root.lyricsLoading = false;
                if (root.isEditingLyrics) {
                    lyricsEditorInput.text = root.lyricsRaw;
                }
            }
        }
    }

    Process {
        id: pickerProc
        stdout: StdioCollector {
            onStreamFinished: {
                let kv = ConfFmt.parseFlatConf(text || "");
                if (kv.cwd) root.pickerCwd = ConfFmt.unescapeField(kv.cwd);
                root.pickerEntries = ConfFmt.parseRecords(text || "", "entry");
            }
        }
    }

    function syncAnchor() {
        const coords = root.mapToItem(null, 0, 0);
        if (Theme.isVertical) {
            popup.targetRelativeY = coords.y + (root.height / 2);
        } else {
            popup.targetRelativeX = coords.x + (root.width / 2);
        }
    }

    Row {
        id: row
        spacing: Theme.widgetSpacing + 2
        anchors.centerIn: parent

        Text {
            id: barIcon
            anchors.verticalCenter: parent.verticalCenter
            text: root.isPlaying
                ? (Theme.iconSet === "kaomoji" ? Theme.kaoJam : Theme.iconMusic)
                : (root.hasTrack ? Theme.iconPause : Theme.iconMusic)
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            font.weight: Theme.isTextIconSet ? Theme.fontWeightBold : Theme.fontWeightRegular
            color: root.isPlaying ? root.artAccent : Theme.textSecondary

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Theme.isVertical && !root.isCollapsed
            text: {
                if (root.hasTrack) {
                    let artist = root.player.trackArtist ? root.player.trackArtist + " - " : "";
                    let title = root.player.trackTitle || "unknown track";
                    return (artist + title).toLowerCase();
                }
                return npMouse.containsMouse
                    ? Theme.getFlavor("media_quiet", Theme.getVibe(Theme.kaoShrug + " nothing playing rn", "nothing playing rn", "nothing playing"))
                    : Theme.getFlavor("media_quiet", Theme.getVibe(Theme.kaoEmpty + " quiet", "quiet", "quiet"));
            }
            font.family: Theme.fontFamily
            font.variableAxes: Theme.sansAxes
            font.weight: Theme.fontWeightRegular
            font.pixelSize: Theme.fontSizeSm
            color: root.hasTrack ? Theme.textPrimary : Theme.textSecondary
            elide: Text.ElideRight
            width: Math.min(implicitWidth, root.compactMode ? 100 : 170)
        }

        // Bar mini equalizer (4 frequency bands from PipeWire monitor, dead-flat when silent or paused)
        Row {
            visible: root.hasTrack && (Settings?.mediaWaveVisualizer ?? true) && !Theme.isVertical && !root.isCollapsed
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            height: 12

            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    readonly property real bandEnergy: {
                        if (!root.isPlaying) return 0;
                        let b = (root.spectrumBands && root.spectrumBands.length === 24)
                            ? Math.max(root.spectrumBands[index * 6 + 1] ?? 0, root.spectrumBands[index * 6 + 3] ?? 0)
                            : 0;
                        if (b > 0.01) return b;
                        let p = (typeof peakMonitor !== "undefined" && peakMonitor.peak !== undefined) ? peakMonitor.peak : 0;
                        return p > 0.01 ? p : 0;
                    }
                    width: 2
                    radius: 1
                    color: root.artAccent
                    anchors.verticalCenter: parent.verticalCenter

                    height: (!root.isPlaying || bandEnergy <= 0.01)
                        ? 2
                        : Math.max(3, Math.min(12, Math.round(2 + bandEnergy * 10)))

                    Behavior on height {
                        NumberAnimation {
                            duration: 75
                            easing.type: Theme.animColorEasing
                        }
                    }
                }
            }
        }
    }

    HoverFlyoutHandler {
        popup: popup
        mouseArea: npMouse
        updatePos: () => root.syncAnchor()
    }

    MouseArea {
        id: npMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
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
            } else if (mouse.button === Qt.RightButton) {
                if (root.player?.canGoNext) root.player.next();
            } else if (mouse.button === Qt.MiddleButton) {
                root.togglePlayback();
            }
        }

        onWheel: (wheel) => {
            if (root.player && (root.player.volumeSupported ?? true)) {
                let delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                let cur = (root.player.volume !== undefined && !isNaN(root.player.volume)) ? root.player.volume : 1.0;
                root.player.volume = Math.max(0.0, Math.min(1.0, cur + delta));
            }
        }
    }

    Connections {
        target: Settings
        function onRequestMediaToggle() {
            root.syncAnchor();
            popup.open = !popup.open;
        }
        function onRequestMediaOpen() {
            root.syncAnchor();
            popup.open = true;
        }
        function onRequestMediaClose() {
            popup.open = false;
        }
    }

    PopupPanel {
        id: popup
        wantsFocus: root.activeTab === "lyrics" && root.isEditingLyrics
        cardWidth: 400
        cardHeight: Math.max(Theme.popupMinHeight, Math.min(Theme.popupMaxHeight, mediaContentLayout.implicitHeight + (Theme.popupPadding * 2)))
        onOpenChanged: {
            if (!open) {
                root.dropdownOpen = false;
                root.isEditingLyrics = false;
                root.showLyricsPicker = false;
            } else if (root.activeTab === "lyrics") {
                root.ensureLyricsLoaded();
            }
        }

        content: ColumnLayout {
            id: mediaContentLayout
            anchors.fill: parent
            spacing: Theme.popupSpacing

            // Header + view tabs + player switcher pill
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: root.isPlaying && Theme.iconSet === "kaomoji"
                        ? "media " + Theme.kaoDJ
                        : "media"
                    font.family: Theme.fontDisplay
                    font.variableAxes: Theme.displayAxes
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Theme.fontWeightBold
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // player | lyrics segmented switcher
                Rectangle {
                    radius: Theme.radiusPill
                    color: Theme.widgetBg
                    border.color: Theme.widgetBorder
                    border.width: 1
                    implicitHeight: 26
                    implicitWidth: tabRow.implicitWidth + 6

                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 2

                        Repeater {
                            model: [
                                { id: "player", label: "player" },
                                { id: "lyrics", label: "lyrics" }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isCur: root.activeTab === modelData.id
                                height: 20
                                implicitWidth: tTxt.implicitWidth + 14
                                radius: Theme.radiusPill
                                color: isCur ? root.artAccent : (tMouse.containsMouse ? Theme.pillHover : "transparent")

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                Text {
                                    id: tTxt
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: 10
                                    font.weight: isCur ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: isCur ? Theme.on_primary : Theme.textSecondary
                                }

                                MouseArea {
                                    id: tMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.activeTab = modelData.id;
                                        if (modelData.id === "lyrics") {
                                            root.ensureLyricsLoaded();
                                        } else {
                                            root.isEditingLyrics = false;
                                            root.showLyricsPicker = false;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.activeList.length > 0
                    radius: Theme.radiusPill
                    color: switchHover.containsMouse ? Theme.pillHover : Theme.pillBg
                    border.color: switchHover.containsMouse ? Theme.alpha(root.artAccent, 0.5) : Theme.pillBorder
                    border.width: (switchHover.containsMouse || Theme.pillBorder.a > 0) ? 1 : 0
                    implicitWidth: switchRow.implicitWidth + 16
                    implicitHeight: 26

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        id: switchRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            text: (root.player?.identity || "player").toLowerCase()
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.monoWeightBold
                            color: root.artAccent
                        }

                        Text {
                            visible: root.activeList.length > 1
                            text: (root.currentPlayerIdx + 1) + "/" + root.activeList.length
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.weight: Theme.monoWeightRegular
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                        }

                        Text {
                            visible: root.activeList.length > 1
                            text: Theme.iconChevronRight
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                        }
                    }

                    MouseArea {
                        id: switchHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.activeList.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: root.activeList.length > 1
                        onClicked: {
                            root.manualPlayerIndex = (root.currentPlayerIdx + 1) % root.activeList.length;
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: Theme.popupDividerHeight
                color: Theme.widgetBorder
            }

            // Active playback section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.popupSpacing
                visible: root.activeTab === "player" && root.player !== null && root.hasTrack

                // Cohesive Hero Card with integrated ambient spectrum backdrop
                ClippingRectangle {
                    id: heroCard
                    Layout.fillWidth: true
                    implicitHeight: Math.max(108, heroRow.implicitHeight + 24)
                    radius: Theme.radiusLg
                    color: Theme.blend(Theme.cardBg, root.artAccent, root.isPlaying ? 0.12 : 0.04)
                    border.color: root.isPlaying ? Theme.alpha(root.artAccent, 0.30) : Theme.cardBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }
                    Behavior on border.color { ColorAnimation { duration: Theme.animSlow; easing.type: Theme.animColorEasing } }

                    // Integrated 24-band ambient spectrum inside the hero card bottom
                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        height: 44
                        spacing: 3
                        visible: Settings?.mediaWaveVisualizer ?? true
                        opacity: root.isPlaying ? 0.22 : 0.08

                        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                        Repeater {
                            model: 24
                            Rectangle {
                                required property int index
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignBottom
                                radius: 2

                                readonly property real bandVal: {
                                    if (!root.isPlaying) return 0.0;
                                    if (root.spectrumBands && root.spectrumBands.length === 24) {
                                        let v = root.spectrumBands[index] ?? 0;
                                        if (v > 0.008) return v;
                                    }
                                    return 0.0;
                                }

                                height: (!root.isPlaying || bandVal <= 0.008)
                                    ? 3
                                    : Math.max(3, Math.min(42, Math.round(3 + bandVal * 39)))

                                color: bandVal > 0.62 ? Theme.tertiary : root.artAccent

                                Behavior on height {
                                    NumberAnimation {
                                        duration: 75
                                        easing.type: Theme.animColorEasing
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        id: heroRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 12
                        spacing: 14

                        // Rounded album art container
                        ClippingRectangle {
                            Layout.preferredWidth: 84
                            Layout.preferredHeight: 84
                            radius: Theme.radiusMd
                            color: Theme.widgetBg
                            border.color: Theme.isGlass ? Theme.glassHighlight : Theme.cardBorder
                            border.width: 1

                            Image {
                                anchors.fill: parent
                                source: root.coverArtUrl
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: status === Image.Ready && source != ""
                                scale: coverMouse.containsMouse ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Theme.iconSet === "kaomoji" ? Theme.kaoMusic : Theme.iconMusic
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeMd : Theme.fontSizeTitle
                                color: root.artAccent
                                visible: root.coverArtUrl === ""
                            }

                            // Hover play/pause scrim overlay
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.alpha(Theme.scrim, coverMouse.containsMouse ? 0.48 : 0.0)
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                Text {
                                    anchors.centerIn: parent
                                    opacity: coverMouse.containsMouse ? 1.0 : 0.0
                                    scale: coverMouse.containsMouse ? 1.0 : 0.8
                                    text: root.isPlaying ? Theme.iconPause : Theme.iconPlay
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeLg
                                    color: Theme.on_surface
                                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                    Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animExpressiveEasing } }
                                }
                            }

                            MouseArea {
                                id: coverMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.togglePlayback()
                                onWheel: (wheel) => {
                                    if (root.player && root.player.volume !== undefined) {
                                        root.player.volume = Math.max(0.0, Math.min(1.0, root.player.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)));
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3

                            Text {
                                text: (root.player?.trackTitle || "unknown track").toLowerCase()
                                font.family: Theme.fontDisplay
                                font.variableAxes: Theme.displayAxes
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Theme.fontWeightBold
                                color: Theme.textPrimary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.Wrap
                            }

                            Text {
                                text: (root.player?.trackArtist || "unknown artist").toLowerCase()
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightDemiBold
                                color: root.artAccent
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.animColorEasing } }
                            }

                            Text {
                                text: (root.player?.trackAlbum || "").toLowerCase()
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                visible: text !== ""
                            }

                            // Flavor subtitle or kaomoji vibe badge
                            Text {
                                visible: root.isPlaying && (((Settings?.flavorMode ?? "actions") !== "off") || Theme.iconSet === "kaomoji")
                                text: Theme.getFlavor("media_playing", Theme.getVibe(Theme.kaoVibe + " vibing", "", ""))
                                font.family: Theme.fontVibe
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.alpha(Theme.textSecondary, 0.85)
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                // Seekbar + timestamps
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    WavyProgress {
                        id: progressTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        from: 0
                        to: (root.player && root.player.length > 0) ? root.player.length : 1
                        value: root.trackPosition
                        playing: root.isPlaying
                        audioPeak: (typeof peakMonitor !== "undefined" && peakMonitor.peak !== undefined) ? peakMonitor.peak : 0.0
                        interactive: root.player && (root.player.canSeek ?? true) && root.player.length > 0
                        onSeekRequested: (pos) => {
                            if (root.player && (root.player.canSeek ?? true) && root.player.length > 0) {
                                root.player.position = pos;
                                root.trackPosition = pos;
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: root.formatTime(root.trackPosition)
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.weight: Theme.monoWeightRegular
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.formatTime(root.player?.length ?? 0)
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.weight: Theme.monoWeightRegular
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                        }
                    }
                }

                // Symmetrical Transport Controls: Shuffle | Prev | Play/Pause | Next | Repeat
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Shuffle button (fixed width slot so center buttons never shift off-center)
                    Rectangle {
                        readonly property bool supported: root.player?.shuffleSupported ?? false
                        readonly property bool active: root.player?.shuffle ?? false
                        width: Theme.popupActionHeight
                        height: Theme.popupActionHeight
                        radius: active ? Theme.radiusMd : Theme.radiusPill
                        opacity: supported ? 1.0 : 0.0
                        enabled: supported
                        color: active
                            ? Theme.alpha(root.artAccent, 0.22)
                            : (shufMouse.containsMouse ? Theme.widgetHover : "transparent")
                        border.color: active ? Theme.alpha(root.artAccent, 0.4) : "transparent"
                        border.width: active ? 1 : 0

                        Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        Text {
                            anchors.centerIn: parent
                            text: Theme.iconShuffle
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeSm
                            color: parent.active ? root.artAccent : Theme.textSecondary
                        }

                        MouseArea {
                            id: shufMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.player) root.player.shuffle = !root.player.shuffle;
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    IconButton {
                        icon: Theme.iconPrev
                        iconSize: Theme.fontSizeMd
                        tooltip: "previous track"
                        enabled: root.player?.canGoPrevious ?? false
                        onClicked: root.player?.previous()
                    }

                    // Squishy primary Play/Pause pill
                    Rectangle {
                        width: root.isPlaying ? 56 : 44
                        height: 40
                        radius: root.isPlaying ? Theme.radiusMd : Theme.radiusPill
                        color: playMouse.pressed
                            ? Theme.statePress(root.artAccent, Theme.on_primary)
                            : (playMouse.containsMouse
                                ? Theme.stateHover(root.artAccent, Theme.on_primary)
                                : root.artAccent)

                        Behavior on width { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                        Behavior on radius { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        Text {
                            anchors.centerIn: parent
                            text: root.isPlaying ? Theme.iconPause : Theme.iconPlay
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_primary
                        }

                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePlayback()
                        }
                    }

                    IconButton {
                        icon: Theme.iconNext
                        iconSize: Theme.fontSizeMd
                        tooltip: "next track"
                        enabled: root.player?.canGoNext ?? false
                        onClicked: root.player?.next()
                    }

                    Item { Layout.fillWidth: true }

                    // Loop / Repeat button (fixed width slot for symmetry)
                    Rectangle {
                        readonly property bool supported: root.player?.loopSupported ?? false
                        readonly property bool active: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                        width: Theme.popupActionHeight
                        height: Theme.popupActionHeight
                        radius: active ? Theme.radiusMd : Theme.radiusPill
                        opacity: supported ? 1.0 : 0.0
                        enabled: supported
                        color: active
                            ? Theme.alpha(root.artAccent, 0.22)
                            : (loopMouse.containsMouse ? Theme.widgetHover : "transparent")
                        border.color: active ? Theme.alpha(root.artAccent, 0.4) : "transparent"
                        border.width: active ? 1 : 0

                        Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        Text {
                            anchors.centerIn: parent
                            text: (root.player?.loopState === MprisLoopState.Track) ? Theme.iconRepeatOne : Theme.iconRepeat
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeSm
                            color: parent.active ? root.artAccent : Theme.textSecondary
                        }

                        MouseArea {
                            id: loopMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cycleLoopState()
                        }
                    }
                }

                // Playback speed selector pills
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "speed"
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.weight: Theme.monoWeightRegular
                        font.pixelSize: 10
                        color: Theme.textSecondary
                    }

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: [0.75, 1.0, 1.25, 1.5]

                        delegate: Rectangle {
                            required property real modelData
                            readonly property real curRate: root.player?.rate ?? 1.0
                            readonly property bool isCur: Math.abs(curRate - modelData) < 0.04
                            height: 22
                            implicitWidth: spdTxt.implicitWidth + 14
                            radius: Theme.radiusPill
                            color: isCur
                                ? Theme.alpha(root.artAccent, 0.22)
                                : (spdMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                            border.color: isCur ? root.artAccent : Theme.pillBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                id: spdTxt
                                anchors.centerIn: parent
                                text: modelData === 1.0 ? "1x" : (modelData + "x")
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 10
                                font.weight: isCur ? Theme.monoWeightBold : Theme.monoWeightMedium
                                color: isCur ? root.artAccent : Theme.textSecondary
                            }

                            MouseArea {
                                id: spdMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setPlaybackSpeed(modelData)
                            }
                        }
                    }
                }
            }

            // Lyrics Tab View (local custom .lrc / sidecar / lrclib.net + built-in picker & editor)
            ColumnLayout {
                id: lyricsSection
                Layout.fillWidth: true
                Layout.preferredHeight: 330
                spacing: 8
                visible: root.activeTab === "lyrics"

                // toolbar row: source badge + pick / edit / fetch / clear
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                        height: 22
                        implicitWidth: srcTxt.implicitWidth + 12
                        radius: Theme.radiusPill
                        color: root.lyricsSource === "custom"
                            ? Theme.alpha(root.artAccent, 0.20)
                            : Theme.surface_container_highest
                        border.color: root.lyricsSource === "custom" ? root.artAccent : Theme.outline_variant
                        border.width: 1

                        Text {
                            id: srcTxt
                            anchors.centerIn: parent
                            text: {
                                if (root.lyricsStatusMsg !== "") return root.lyricsStatusMsg;
                                if (root.lyricsLoading) return "loading...";
                                if (root.lyricsSource === "custom") return "custom .lrc";
                                if (root.lyricsSource === "sidecar") return "sidecar .lrc";
                                if (root.lyricsSource === "lrclib") return "lrclib.net";
                                if (root.lyricsSource === "file") return "picked file";
                                return "no lyrics";
                            }
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: 9
                            font.weight: Theme.monoWeightBold
                            color: (root.lyricsSource === "custom" || root.lyricsStatusMsg !== "") ? root.artAccent : Theme.textSecondary
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: [
                            { id: "pick", label: "pick .lrc", vis: true, active: root.showLyricsPicker },
                            { id: "edit", label: root.isEditingLyrics ? "view" : "edit", vis: root.hasTrack, active: root.isEditingLyrics },
                            { id: "fetch", label: "fetch", vis: root.hasTrack, active: false },
                            { id: "savequick", label: "save", vis: root.hasTrack && (root.lyricsSource === "file" || root.lyricsSource === "lrclib") && root.lyricsRaw !== "" && !root.isEditingLyrics, active: true },
                            { id: "clear", label: "reset", vis: root.hasTrack && root.lyricsSource === "custom", active: false }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            visible: modelData.vis
                            height: 22
                            implicitWidth: lyrBtnTxt.implicitWidth + 12
                            radius: Theme.radiusPill
                            color: modelData.active
                                ? Theme.alpha(root.artAccent, 0.22)
                                : (lyrBtnMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                            border.color: modelData.active ? root.artAccent : Theme.pillBorder
                            border.width: 1

                            Text {
                                id: lyrBtnTxt
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 9
                                font.weight: modelData.active ? Theme.monoWeightBold : Theme.monoWeightMedium
                                color: modelData.active ? root.artAccent : Theme.textPrimary
                            }

                            MouseArea {
                                id: lyrBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.id === "pick") {
                                        root.showLyricsPicker = !root.showLyricsPicker;
                                        root.isEditingLyrics = false;
                                        if (root.showLyricsPicker) root.browseLyricsDir(root.pickerCwd);
                                    } else if (modelData.id === "edit") {
                                        root.showLyricsPicker = false;
                                        root.isEditingLyrics = !root.isEditingLyrics;
                                        if (root.isEditingLyrics) {
                                            lyricsEditorInput.text = root.lyricsRaw;
                                            Qt.callLater(() => lyricsEditorInput.forceActiveFocus());
                                        }
                                    } else if (modelData.id === "fetch") {
                                        root.showLyricsPicker = false;
                                        root.isEditingLyrics = false;
                                        root.loadLyrics(true);
                                    } else if (modelData.id === "savequick") {
                                        root.saveCustomLyrics(root.lyricsRaw);
                                    } else if (modelData.id === "clear") {
                                        root.clearCustomLyrics();
                                        root.loadLyrics(true);
                                    }
                                }
                            }
                        }
                    }
                }

                // Built-in .lrc / .txt file picker
                Rectangle {
                    visible: root.showLyricsPicker
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMd
                    color: Theme.cardBg
                    border.color: Theme.cardBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                model: [
                                    { label: "saved", dir: (Quickshell.env("XDG_DATA_HOME") || ((Quickshell.env("HOME") || "") + "/.local/share")) + "/quickshell/lyrics" },
                                    { label: "music", dir: (Quickshell.env("HOME") || "") + "/Music" },
                                    { label: "dl", dir: (Quickshell.env("HOME") || "") + "/Downloads" },
                                    { label: "home", dir: Quickshell.env("HOME") || "" }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    height: 20
                                    implicitWidth: dirQtxt.implicitWidth + 10
                                    radius: Theme.radiusPill
                                    color: dirQMouse.containsMouse ? Theme.primary_overlay : Theme.pillBg
                                    border.color: Theme.pillBorder
                                    border.width: 1

                                    Text {
                                        id: dirQtxt
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: Theme.fontMono
                                        font.variableAxes: Theme.monoAxes
                                        font.weight: Theme.monoWeightRegular
                                        font.pixelSize: 9
                                        color: Theme.textPrimary
                                    }

                                    MouseArea {
                                        id: dirQMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.browseLyricsDir(modelData.dir)
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            text: root.pickerCwd || "~"
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.weight: Theme.monoWeightRegular
                            font.pixelSize: 9
                            color: Theme.textSecondary
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: pickerCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: pickerCol
                                width: parent.width
                                spacing: 3

                                Repeater {
                                    model: root.pickerEntries

                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property bool isDir: modelData.isDir === "true" || modelData.isDir === true
                                        Layout.fillWidth: true
                                        height: 26
                                        radius: Theme.radiusSm
                                        color: pickRowMouse.containsMouse ? Theme.widgetHover : "transparent"

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 6
                                            spacing: 6

                                            Text {
                                                text: isDir ? Theme.iconFolder : Theme.iconNote
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: 12
                                                color: isDir ? root.artAccent : Theme.textSecondary
                                            }

                                            Text {
                                                text: modelData.name
                                                font.family: Theme.fontMono
                                                font.variableAxes: Theme.monoAxes
                                                font.weight: Theme.monoWeightRegular
                                                font.pixelSize: 10
                                                color: Theme.textPrimary
                                                elide: Text.ElideMiddle
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            id: pickRowMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (isDir) root.browseLyricsDir(modelData.path);
                                                else root.loadLyricsFile(modelData.path);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Inline editable lyrics buffer (fix typos / grammar / save custom .lrc)
                Rectangle {
                    visible: !root.showLyricsPicker && root.isEditingLyrics
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMd
                    color: Theme.cardBg
                    border.color: lyricsEditorInput.activeFocus ? root.artAccent : Theme.cardBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Flickable {
                            id: editFlick
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: width
                            contentHeight: Math.max(height, lyricsEditorInput.implicitHeight + 12)
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            TextEdit {
                                id: lyricsEditorInput
                                width: editFlick.width
                                height: Math.max(editFlick.height, implicitHeight)
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.weight: Theme.monoWeightRegular
                                font.pixelSize: 11
                                color: Theme.textPrimary
                                selectionColor: Theme.primary_container
                                selectedTextColor: Theme.on_primary_container
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "saves to ~/.local/share/quickshell/lyrics/"
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.weight: Theme.monoWeightRegular
                                font.pixelSize: 8
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Rectangle {
                                height: 26
                                implicitWidth: cnlTxt.implicitWidth + 16
                                radius: Theme.radiusPill
                                color: cnlMouse.containsMouse ? Theme.pillHover : Theme.pillBg
                                border.color: Theme.pillBorder
                                border.width: 1

                                Text {
                                    id: cnlTxt
                                    anchors.centerIn: parent
                                    text: "cancel"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.weight: Theme.fontWeightRegular
                                    font.pixelSize: 10
                                    color: Theme.textPrimary
                                }

                                MouseArea {
                                    id: cnlMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.isEditingLyrics = false
                                }
                            }

                            Rectangle {
                                height: 26
                                implicitWidth: savTxt.implicitWidth + 18
                                radius: Theme.radiusPill
                                color: savMouse.containsMouse ? Theme.stateHover(root.artAccent, Theme.on_primary) : root.artAccent

                                Text {
                                    id: savTxt
                                    anchors.centerIn: parent
                                    text: "save custom .lrc"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: 10
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.on_primary
                                }

                                MouseArea {
                                    id: savMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.saveCustomLyrics(lyricsEditorInput.text)
                                }
                            }
                        }
                    }
                }

                // Synced / Plain Lyrics Reader
                Rectangle {
                    visible: !root.showLyricsPicker && !root.isEditingLyrics
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Theme.radiusMd
                    color: Theme.cardBg
                    border.color: Theme.cardBorder
                    border.width: 1
                    clip: true

                    Item {
                        anchors.fill: parent
                        visible: !root.hasTrack || root.lyricsLoading || root.parsedLrc.lines.length === 0

                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            width: parent.width - 32

                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: !root.hasTrack
                                    ? "no active track"
                                    : (root.lyricsLoading ? "looking up lyrics..." : "no lyrics found for this track")
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.textSecondary
                                wrapMode: Text.Wrap
                            }

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 8
                                visible: root.hasTrack && !root.lyricsLoading

                                Rectangle {
                                    height: 26
                                    implicitWidth: empPickTxt.implicitWidth + 16
                                    radius: Theme.radiusPill
                                    color: Theme.pillBg
                                    border.color: Theme.pillBorder
                                    border.width: 1

                                    Text {
                                        id: empPickTxt
                                        anchors.centerIn: parent
                                        text: "browse .lrc"
                                        font.family: Theme.fontMono
                                        font.variableAxes: Theme.monoAxes
                                        font.weight: Theme.monoWeightRegular
                                        font.pixelSize: 10
                                        color: Theme.textPrimary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.showLyricsPicker = true;
                                            root.browseLyricsDir(root.pickerCwd);
                                        }
                                    }
                                }

                                Rectangle {
                                    height: 26
                                    implicitWidth: empWriteTxt.implicitWidth + 16
                                    radius: Theme.radiusPill
                                    color: root.artAccent

                                    Text {
                                        id: empWriteTxt
                                        anchors.centerIn: parent
                                        text: "write / paste"
                                        font.family: Theme.fontMono
                                        font.variableAxes: Theme.monoAxes
                                        font.pixelSize: 10
                                        font.weight: Theme.monoWeightBold
                                        color: Theme.on_primary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.isEditingLyrics = true;
                                            lyricsEditorInput.text = root.lyricsRaw;
                                            Qt.callLater(() => lyricsEditorInput.forceActiveFocus());
                                        }
                                    }
                                }
                            }
                        }
                    }

                    NumberAnimation {
                        id: lrcScrollAnim
                        target: lyricsScroller
                        property: "contentY"
                        duration: 200
                        easing.type: Easing.OutCubic
                    }

                    Connections {
                        target: root
                        function onActiveLrcIndexChanged() {
                            if (root.activeTab !== "lyrics" || root.isEditingLyrics || root.showLyricsPicker) return;
                            if (lyricsScroller.moving || lyricsScroller.dragging) return;
                            let idx = root.activeLrcIndex;
                            if (idx < 0 || idx >= lrcRep.count) return;
                            let item = lrcRep.itemAt(idx);
                            if (!item) return;
                            let maxY = Math.max(0, lyricsScroller.contentHeight - lyricsScroller.height);
                            let dest = Math.max(0, Math.min(maxY, item.y - (lyricsScroller.height * 0.35)));
                            lrcScrollAnim.stop();
                            lrcScrollAnim.to = dest;
                            lrcScrollAnim.start();
                        }
                    }

                    Flickable {
                        id: lyricsScroller
                        anchors.fill: parent
                        anchors.margins: 10
                        visible: root.hasTrack && !root.lyricsLoading && root.parsedLrc.lines.length > 0
                        contentWidth: width
                        contentHeight: lrcCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: lrcCol
                            width: lyricsScroller.width
                            spacing: root.parsedLrc.timed ? 4 : 6

                            Repeater {
                                id: lrcRep
                                model: root.parsedLrc.lines

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    readonly property bool isCurrent: root.parsedLrc.timed && index === root.activeLrcIndex
                                    readonly property bool isPast: root.parsedLrc.timed && root.activeLrcIndex > index

                                    width: lrcCol.width
                                    implicitHeight: lrcLineTxt.implicitHeight + 8
                                    radius: Theme.radiusSm
                                    color: isCurrent
                                        ? Theme.alpha(root.artAccent, 0.16)
                                        : (lrcLineMouse.containsMouse && modelData.time >= 0 ? Theme.widgetHover : "transparent")

                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    Text {
                                        id: lrcLineTxt
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        text: modelData.text
                                        wrapMode: Text.Wrap
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: isCurrent ? Theme.fontSizeMd : Theme.fontSizeSm
                                        font.weight: isCurrent ? Theme.fontWeightBold : Theme.fontWeightRegular
                                        color: isCurrent
                                            ? root.artAccent
                                            : (isPast ? Theme.on_surface_variant : Theme.textPrimary)
                                        opacity: isPast ? 0.65 : 1.0
                                    }

                                    MouseArea {
                                        id: lrcLineMouse
                                        anchors.fill: parent
                                        hoverEnabled: modelData.time >= 0
                                        cursorShape: modelData.time >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (modelData.time >= 0 && root.player && (root.player.canSeek ?? true)) {
                                                root.player.position = modelData.time;
                                                root.trackPosition = modelData.time;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Cohesive Empty State Card
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: emptyCol.implicitHeight + 28
                visible: root.activeTab === "player" && (root.player === null || !root.hasTrack)
                radius: Theme.radiusLg
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1

                ColumnLayout {
                    id: emptyCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 14
                    spacing: 10

                    Text {
                        text: Theme.getVibe(Theme.kaoSilent, Theme.iconHeadphones, Theme.iconHeadphones)
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXl : Theme.fontSizeTitle
                        color: Theme.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: Theme.getFlavor("media_quiet", Theme.getVibe("quiet right now", "no players active", "nothing playing"))
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8

                        // App selector pill
                        Rectangle {
                            Layout.fillWidth: true
                            height: Theme.popupActionHeight + 2
                            radius: Theme.radiusMd
                            color: dropHover.containsMouse ? Theme.widgetHover : Theme.widgetBg
                            border.color: root.dropdownOpen ? Theme.alpha(Theme.primary, 0.6) : Theme.widgetBorder
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 8

                                Text {
                                    text: root.selectedApp?.icon || Theme.iconMusic
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.primary
                                }

                                Text {
                                    text: (root.selectedApp?.name || "choose app").toLowerCase()
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightDemiBold
                                    color: Theme.textPrimary
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: root.dropdownOpen ? Theme.iconChevronUp : Theme.iconChevronDown
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textSecondary
                                }
                            }

                            MouseArea {
                                id: dropHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.dropdownOpen = !root.dropdownOpen
                            }
                        }

                        // Primary action launch button using Material 3 state layers
                        Rectangle {
                            Layout.preferredWidth: 88
                            height: Theme.popupActionHeight + 2
                            radius: Theme.radiusMd
                            color: launchHover.pressed
                                ? Theme.statePress(Theme.primary, Theme.on_primary)
                                : (launchHover.containsMouse
                                    ? Theme.stateHover(Theme.primary, Theme.on_primary)
                                    : Theme.primary)

                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 5

                                Text {
                                    text: "launch"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.on_primary
                                }

                                Text {
                                    text: Theme.iconPlay
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_primary
                                }
                            }

                            MouseArea {
                                id: launchHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.runPlayer(root.preferredAppId)
                            }
                        }
                    }

                    // Dropdown drawer
                    Rectangle {
                        Layout.fillWidth: true
                        height: root.dropdownOpen ? Math.min(drawerCol.implicitHeight + 8, 136) : 0
                        visible: height > 0
                        clip: true
                        radius: Theme.radiusMd
                        color: Theme.widgetBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 4
                            contentHeight: drawerCol.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: drawerCol
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: root.musicApps

                                    Rectangle {
                                        required property var modelData
                                        readonly property bool isSelected: root.preferredAppId === modelData.id
                                        Layout.fillWidth: true
                                        height: 28
                                        radius: Theme.radiusSm
                                        color: itemHover.containsMouse
                                            ? Theme.widgetHover
                                            : (isSelected ? Theme.primary_overlay : "transparent")

                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 6

                                            Text {
                                                text: modelData.icon
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                color: parent.parent.isSelected ? Theme.primary : Theme.textSecondary
                                            }

                                            Text {
                                                text: modelData.name.toLowerCase()
                                                font.family: Theme.fontFamily
                                                font.variableAxes: Theme.sansAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: parent.parent.isSelected ? Theme.fontWeightDemiBold : Theme.fontWeightRegular
                                                color: parent.parent.isSelected ? Theme.textPrimary : Theme.textSecondary
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: Theme.iconCheck
                                                font.family: Theme.fontIcon
                                                font.variableAxes: Theme.iconAxes
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.primary
                                                visible: parent.parent.isSelected
                                            }
                                        }

                                        MouseArea {
                                            id: itemHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.preferredAppId = modelData.id;
                                                root.dropdownOpen = false;
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
}
