// WallpaperBrowser.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../services"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Rectangle {
    id: root

    property var barScreen: null
    property var barMonitor: null

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isBento
    readonly property int effectiveBarMargin: isFloatingBar ? ((Settings?.barMargin > 0) ? Settings.barMargin : 8) : 0

    implicitWidth: {
        if (Theme.isVertical) return Theme.barHeight - 8;
        if (wpMouse.containsMouse || popup.open) return wpRow.implicitWidth + 20;
        return Theme.barHeight - 8;
    }
    implicitHeight: Theme.barHeight - 8
    radius: Theme.radiusPill
    visible: Settings?.showWallpaper ?? true

    color: {
        if (wpMouse.pressed) return Theme.widgetActive;
        if (popup.open) return Theme.primary_overlay;
        if (wpMouse.containsMouse) return Theme.pillHover;
        return Theme.pillBg;
    }
    border.color: popup.open ? Theme.primary : Theme.pillBorder
    border.width: (border.color === "transparent" || border.color.a === 0) ? 0 : 1
    clip: true

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

    property string activeTab: "local"
    property string localCategoryFilter: "all"
    property string localSubCategoryFilter: "all"
    property string localSearchQuery: ""
    property string onlineQuery: ""
    property string onlineSorting: "date_added"
    property int onlinePage: 1

    readonly property string nativeRes: {
        if (root.barScreen?.width && root.barScreen?.height) {
            return root.barScreen.width + "x" + root.barScreen.height;
        }
        if (root.barMonitor?.width && root.barMonitor?.height) {
            return root.barMonitor.width + "x" + root.barMonitor.height;
        }
        if (Quickshell?.screens && Quickshell.screens.length > 0) {
            return Quickshell.screens[0].width + "x" + Quickshell.screens[0].height;
        }
        return "1920x1080";
    }

    property string onlineResolution: nativeRes
    property bool isOnlineLoading: false
    property bool isBatchDownloading: false
    property string batchStatusText: ""

    // bound directly to WallpaperService.wallpaperList (parsed from saved_wp, zero JSON)
    readonly property var allLocalWallpapers: WallpaperService?.wallpaperList ?? []
    property var onlineWallpapers: []

    readonly property var localLiveWallpapers: {
        let res = [];
        let items = root.allLocalWallpapers || [];
        for (let i = 0; i < items.length; i++) {
            let item = items[i];
            if (item && (item.isVideo || item.isGif || item.isLive || ["gif", "mp4", "webm", "mkv", "mov"].indexOf(item.ext) !== -1)) {
                res.push(item);
            }
        }
        return res;
    }

    Timer {
        id: batchStatusResetTimer
        interval: 4000
        onTriggered: root.batchStatusText = ""
    }

    function focusActiveInput() {
        if (!popup.open) return;
        Qt.callLater(() => {
            if (root.activeTab === "local") localSearchField.focusInput();
            else if (root.activeTab === "online") onlineSearchField.focusInput();
            else if (root.activeTab === "live") liveUrlField.focusInput();
        });
    }

    Connections {
        target: popup
        function onOpenChanged() {
            if (popup.open) root.focusActiveInput();
        }
    }

    onActiveTabChanged: root.focusActiveInput()

    function syncAnchor() {
        const p = root.mapToItem(null, 0, 0);
        if (p && root.visible) {
            if (Theme.isVertical) {
                popup.targetRelativeX = 0;
                popup.targetRelativeY = p.y + (root.implicitHeight / 2) + root.effectiveBarMargin;
            } else {
                popup.targetRelativeX = p.x + (root.implicitWidth / 2) + root.effectiveBarMargin;
                popup.targetRelativeY = 0;
            }
        } else {
            popup.targetRelativeX = 0;
            popup.targetRelativeY = 0;
        }
    }

    function isTargetMonitorActive() {
        return !root.barScreen
            || Quickshell.screens.length <= 1
            || (root.barMonitor && Hyprland.focusedMonitor && root.barMonitor.id === Hyprland.focusedMonitor.id);
    }

    function rollRandomWallpaper() {
        let cat = "all";
        if (root.localCategoryFilter !== "all") {
            cat = root.localCategoryFilter;
            if (root.localSubCategoryFilter !== "all") {
                cat = root.localCategoryFilter + "/" + root.localSubCategoryFilter;
            }
        }
        if (WallpaperService?.applyRandomWallpaper) {
            WallpaperService.applyRandomWallpaper(cat);
        }
    }

    function reloadLocalWallpapers() {
        if (WallpaperService?.updateWallpaperList) {
            WallpaperService.updateWallpaperList();
        }
        if (WallpaperService?.scanLocalWallpapers) {
            WallpaperService.scanLocalWallpapers();
        }
    }

    // lightweight regex scraper for wallhaven API responses so we don't even touch JSON.parse
    function parseWallhavenResponse(raw) {
        if (!raw) return [];
        let results = [];
        let blocks = raw.split('"id":');
        for (let i = 1; i < blocks.length; i++) {
            let b = blocks[i];
            let idMatch = b.match(/^\s*"([^"]+)"/);
            let pathMatch = b.match(/"path"\s*:\s*"([^"]+)"/);
            let thumbMatch = b.match(/"small"\s*:\s*"([^"]+)"/);
            let resMatch = b.match(/"resolution"\s*:\s*"([^"]+)"/);
            let typeMatch = b.match(/"file_type"\s*:\s*"image\/([^"]+)"/);
            if (pathMatch) {
                results.push({
                    id: idMatch ? idMatch[1].toLowerCase() : "",
                    fullUrl: pathMatch[1].replace(/\\\//g, "/"),
                    thumbUrl: thumbMatch ? thumbMatch[1].replace(/\\\//g, "/") : pathMatch[1].replace(/\\\//g, "/"),
                    resolution: resMatch ? resMatch[1] : "",
                    fileType: typeMatch ? typeMatch[1].toLowerCase() : "img"
                });
            }
        }
        return results;
    }

    function fetchWallhaven(query, sort, page, resolution) {
        root.isOnlineLoading = true;
        let req = new XMLHttpRequest();
        let q = (query !== undefined && query !== null) ? query.trim() : root.onlineQuery;
        let s = sort || root.onlineSorting || "date_added";
        let p = page || 1;
        let r = (resolution !== undefined && resolution !== null) ? resolution.trim() : root.onlineResolution;

        r = r.replace(/\s*[\*xX]\s*/g, "x").replace(/\s+/g, "");

        root.onlineQuery = q;
        root.onlineSorting = s;
        root.onlinePage = p;
        root.onlineResolution = r;

        let params = [];
        if (q !== "") params.push("q=" + encodeURIComponent(q));
        params.push("sorting=" + encodeURIComponent(s));
        params.push("page=" + p);
        params.push("categories=111");
        params.push("purity=100");

        if (r !== "" && r.toLowerCase() !== "any") {
            params.push("resolutions=" + encodeURIComponent(r));
        }

        req.open("GET", "https://wallhaven.cc/api/v1/search?" + params.join("&"));
        req.timeout = 10000;
        req.ontimeout = () => { root.isOnlineLoading = false; };
        req.onerror = () => { root.isOnlineLoading = false; };
        req.onreadystatechange = () => {
            if (req.readyState === XMLHttpRequest.DONE) {
                root.isOnlineLoading = false;
                if (req.status === 200) {
                    root.onlineWallpapers = root.parseWallhavenResponse(req.responseText);
                }
            }
        };
        req.send();
    }

    function downloadUrls(urls) {
        if (root.isBatchDownloading || !urls || urls.length === 0) return;
        root.isBatchDownloading = true;
        root.batchStatusText = urls.length === 1
            ? "downloading wallpaper..."
            : ("downloading " + urls.length + " wallpapers...");

        if (WallpaperService?.batchDownload) {
            WallpaperService.batchDownload(urls);
        }
        root.isBatchDownloading = false;
        batchStatusResetTimer.restart();
    }

    function downloadCurrentSection() {
        let urls = [];
        if (root.activeTab === "online") {
            for (let i = 0; i < root.onlineWallpapers.length; i++) {
                let u = root.onlineWallpapers[i]?.fullUrl;
                if (u) urls.push(u);
            }
        }
        downloadUrls(urls);
    }

    component GroupLabel: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeXs
        font.weight: Font.DemiBold
        color: Theme.on_surface_variant
    }

    component SettingCard: Rectangle {
        id: sCard
        property string title: ""
        property string icon: ""
        property string badge: ""
        default property alias body: cardCol.data

        Layout.fillWidth: true
        implicitHeight: cardCol.implicitHeight + 24
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
            id: cardCol
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: sCard.title !== ""

                Text {
                    visible: sCard.icon !== "" && !Theme.isTextIconSet
                    text: sCard.icon
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.primary
                }

                Text {
                    text: sCard.title
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Font.Bold
                    color: Theme.on_surface
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: sCard.badge !== ""
                    height: 20
                    implicitWidth: cardBadgeText.implicitWidth + 14
                    radius: Theme.radiusPill
                    color: Theme.primary_overlay
                    border.color: Theme.alpha(Theme.primary, 0.35)
                    border.width: 1

                    Text {
                        id: cardBadgeText
                        anchors.centerIn: parent
                        text: sCard.badge
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Font.Bold
                        color: Theme.primary
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.widgetBorder
                visible: sCard.title !== ""
            }
        }
    }

    component SearchField: Rectangle {
        id: fieldRoot
        property alias text: inputItem.text
        property string placeholder: ""
        property string icon: Theme.iconSearch
        property string badgeText: ""
        property bool monoFont: false
        signal submitted(string value)
        signal cleared()

        function focusInput() {
            inputItem.forceActiveFocus();
        }

        Layout.fillWidth: true
        Layout.preferredHeight: 36
        color: Theme.cardBg
        radius: Theme.radiusMd
        border.color: inputItem.activeFocus ? Theme.primary : Theme.cardBorder
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 8

            Text {
                text: fieldRoot.icon
                font.family: Theme.fontIcon
                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                color: inputItem.activeFocus ? Theme.primary : Theme.on_surface_variant
            }

            TextInput {
                id: inputItem
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                font.family: fieldRoot.monoFont ? Theme.fontMono : Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                color: Theme.on_surface
                selectByMouse: true
                activeFocusOnTab: true
                clip: true

                Text {
                    text: fieldRoot.placeholder
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.on_surface_disabled
                    visible: inputItem.text.length === 0 && !inputItem.activeFocus
                    anchors.verticalCenter: parent.verticalCenter
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        fieldRoot.submitted(inputItem.text);
                        event.accepted = true;
                    }
                }
            }

            Rectangle {
                visible: fieldRoot.badgeText !== ""
                height: 20
                implicitWidth: badgeLbl.implicitWidth + 12
                radius: Theme.radiusPill
                color: Theme.widgetBg
                border.color: Theme.widgetBorder
                border.width: 1

                Text {
                    id: badgeLbl
                    anchors.centerIn: parent
                    text: fieldRoot.badgeText
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.on_surface_variant
                }
            }

            IconButton {
                icon: Theme.iconClose
                iconSize: Theme.fontSizeXs
                tooltip: "clear"
                visible: inputItem.text.length > 0
                onClicked: {
                    inputItem.text = "";
                    fieldRoot.cleared();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            propagateComposedEvents: true
            onPressed: (mouse) => {
                inputItem.forceActiveFocus();
                mouse.accepted = false;
            }
        }
    }

    component Chip: Rectangle {
        id: chipRoot
        property bool selected: false
        property string label: ""
        property string icon: ""
        property real chipHeight: 26
        property real chipRadius: Theme.radiusPill
        property int fontSize: Theme.fontSizeXs
        property bool fillWidth: false
        property color activeBg: Theme.primary_overlay
        property color inactiveBg: Theme.widgetBg
        property color activeFg: Theme.primary
        property color inactiveFg: Theme.on_surface_variant
        signal clicked()

        Layout.fillWidth: fillWidth
        Layout.preferredHeight: chipHeight
        Layout.preferredWidth: fillWidth ? -1 : (chipRow.implicitWidth + 20)
        radius: chipRadius
        color: selected ? activeBg : (chipMouse.containsMouse ? Theme.widgetHover : inactiveBg)
        border.color: selected ? Theme.primary : (chipMouse.containsMouse ? Theme.alpha(Theme.primary, 0.45) : Theme.widgetBorder)
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            Text {
                visible: chipRoot.icon !== "" && (!Theme.isTextIconSet || chipRoot.label === "")
                text: chipRoot.icon
                font.family: Theme.fontIcon
                font.pixelSize: chipRoot.fontSize
                color: chipRoot.selected ? chipRoot.activeFg : chipRoot.inactiveFg
            }

            Text {
                visible: chipRoot.label !== ""
                text: chipRoot.label
                font.family: Theme.fontFamily
                font.pixelSize: chipRoot.fontSize
                font.weight: chipRoot.selected ? Font.Bold : Font.Normal
                color: chipRoot.selected ? chipRoot.activeFg : chipRoot.inactiveFg
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chipRoot.clicked()
        }
    }

    component EmptyState: Item {
        id: emptyRoot
        property string icon: Theme.iconFolder
        property string message: "no wallpapers found"
        property bool loading: false

        Layout.fillWidth: true
        Layout.fillHeight: true

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
                    text: emptyRoot.loading ? Theme.iconRefresh : emptyRoot.icon
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeMd : Theme.fontSizeTitle
                    color: emptyRoot.loading ? Theme.primary : Theme.on_surface_variant

                    RotationAnimator on rotation {
                        running: emptyRoot.loading && !Theme.isTextIconSet
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1000
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: emptyRoot.message
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSm
                color: Theme.on_surface_variant
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.4
            }
        }
    }

    component WallpaperCard: Rectangle {
        id: cardRoot
        property string thumbUrl: ""
        property string titleText: ""
        property string badgeText: ""
        property string tagText: ""
        property bool tagAccent: false
        property bool isSelected: false
        property bool allowDownload: false
        signal applyRequested()
        signal downloadRequested()

        color: "transparent"

        Rectangle {
            id: innerCard
            anchors.fill: parent
            anchors.margins: 4
            color: Theme.cardBg
            radius: Theme.radiusMd
            clip: true
            border.color: cardRoot.isSelected ? Theme.primary : (cardMouse.containsMouse ? Theme.primary : Theme.cardBorder)
            border.width: cardRoot.isSelected ? 2 : 1

            Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

            Image {
                anchors.fill: parent
                source: (cardRoot.thumbUrl.startsWith("http://") || cardRoot.thumbUrl.startsWith("https://") || cardRoot.thumbUrl.startsWith("file://"))
                    ? cardRoot.thumbUrl
                    : (cardRoot.thumbUrl !== "" ? ("file://" + cardRoot.thumbUrl) : "")
                sourceSize: Qt.size(280, 180)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 40
                z: 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Theme.alpha(Theme.surface, 0.90) }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 8
                height: 20
                width: bText.implicitWidth + 12
                radius: Theme.radiusPill
                color: Theme.alpha(Theme.surface, 0.82)
                border.color: Theme.widgetBorder
                border.width: 1
                visible: cardRoot.badgeText !== ""
                z: 2

                Text {
                    id: bText
                    anchors.centerIn: parent
                    text: cardRoot.badgeText.toLowerCase()
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.Medium
                    color: Theme.on_surface
                }
            }

            Row {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 8
                spacing: 6
                z: 2

                Rectangle {
                    height: 20
                    width: tText.implicitWidth + 12
                    radius: Theme.radiusPill
                    color: cardRoot.tagAccent ? Theme.primary : Theme.alpha(Theme.surface, 0.82)
                    border.color: cardRoot.tagAccent ? "transparent" : Theme.widgetBorder
                    border.width: 1
                    visible: cardRoot.tagText !== ""

                    Text {
                        id: tText
                        anchors.centerIn: parent
                        text: cardRoot.tagText.toLowerCase()
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Font.Bold
                        color: cardRoot.tagAccent ? Theme.on_primary : Theme.on_surface_variant
                    }
                }

                Rectangle {
                    height: 20
                    width: 20
                    radius: Theme.radiusPill
                    color: Theme.primary
                    visible: cardRoot.isSelected

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconCheck
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_primary
                    }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: cardRoot.applyRequested()
            }

            RowLayout {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                spacing: 6
                z: 3

                Text {
                    Layout.fillWidth: true
                    text: (cardRoot.titleText !== "" ? cardRoot.titleText : "click to set").toLowerCase()
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Font.Medium
                    color: Theme.on_surface
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: 22
                    height: 22
                    radius: Theme.radiusPill
                    color: dlMouse.containsMouse ? Theme.primary : Theme.alpha(Theme.surface, 0.82)
                    border.color: Theme.widgetBorder
                    border.width: 1
                    visible: cardRoot.allowDownload

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconDownload
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontSizeXs
                        color: dlMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                    }

                    MouseArea {
                        id: dlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.downloadRequested()
                    }
                }
            }
        }
    }

    // bar pill content
    Row {
        id: wpRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.iconWallpaper
            font.family: Theme.fontIcon
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            color: popup.open || wpMouse.containsMouse ? Theme.primary : Theme.on_surface

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Theme.isVertical && (wpMouse.containsMouse || popup.open)
            text: "wallpapers"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSm
            font.weight: Font.Medium
            color: Theme.on_surface
        }
    }

    // left click opens browser, right click rolls random wallpaper, middle click toggles dark/light mode
    MouseArea {
        id: wpMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.rollRandomWallpaper();
                return;
            }
            if (mouse.button === Qt.MiddleButton) {
                if (WallpaperService?.setMode) {
                    WallpaperService.setMode(WallpaperService.currentMode === "dark" ? "light" : "dark");
                }
                return;
            }
            root.syncAnchor();
            popup.open = !popup.open;
            if (popup.open) reloadLocalWallpapers();
        }
    }

    Connections {
        target: Settings
        function onRequestWallpaperToggle() {
            if (root.isTargetMonitorActive()) {
                root.syncAnchor();
                popup.open = !popup.open;
                if (popup.open) reloadLocalWallpapers();
            }
        }
        function onRequestWallpaperOpen() {
            if (root.isTargetMonitorActive()) {
                root.syncAnchor();
                popup.open = true;
                reloadLocalWallpapers();
            }
        }
        function onRequestWallpaperClose() {
            popup.open = false;
        }
    }

    PopupPanel {
        id: popup
        screen: root.barScreen
        wantsFocus: true
        keyboardFocusMode: WlrKeyboardFocus.OnDemand
        cardWidth: 760
        cardHeight: Math.min(600, (popup.screen?.height ?? 800) - 80)
        targetRelativeX: 0
        targetRelativeY: 0

        content: ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            // top header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    width: 34
                    height: 34
                    radius: Theme.radiusMd
                    color: Theme.primary_overlay
                    border.color: Theme.alpha(Theme.primary, 0.35)
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconWallpaper
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                        color: Theme.primary
                    }
                }

                ColumnLayout {
                    spacing: 1

                    Text {
                        text: "wallpapers & aesthetics"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Font.Bold
                        color: Theme.on_surface
                    }

                    Text {
                        text: {
                            if (root.batchStatusText !== "") return root.batchStatusText;
                            if (root.activeTab === "local") return localView.filteredLocalWps.length + " wallpapers in local gallery";
                            if (root.activeTab === "online") return root.onlineWallpapers.length > 0 ? (root.onlineWallpapers.length + " wallhaven results (page " + root.onlinePage + ")") : "explore wallhaven community gallery";
                            if (root.activeTab === "live") return root.localLiveWallpapers.length + " local animated & video wallpapers";
                            return "matugen palette, awww transitions & mpvpaper";
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        color: root.batchStatusText !== "" ? Theme.primary : Theme.on_surface_variant
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 4
                    visible: root.activeTab !== "theme" && (Quickshell?.screens?.length ?? 0) > 1

                    Chip {
                        icon: Theme.iconWorkspaces
                        label: "all"
                        selected: (WallpaperService?.targetMonitor ?? "all") === "all"
                        chipHeight: 26
                        onClicked: if (WallpaperService) WallpaperService.targetMonitor = "all"
                    }

                    Repeater {
                        model: Quickshell?.screens ?? []
                        delegate: Chip {
                            required property var modelData
                            label: (modelData?.name ?? "screen").toLowerCase()
                            selected: WallpaperService?.targetMonitor === modelData.name
                            chipHeight: 26
                            onClicked: if (WallpaperService) WallpaperService.targetMonitor = modelData.name
                        }
                    }
                }

                Chip {
                    visible: root.activeTab === "online" && root.onlineWallpapers.length > 0
                    icon: root.isBatchDownloading ? Theme.iconRefresh : Theme.iconDownload
                    label: root.isBatchDownloading ? "saving..." : ("save page (" + root.onlineWallpapers.length + ")")
                    chipHeight: 28
                    selected: root.isBatchDownloading
                    onClicked: root.downloadCurrentSection()
                }

                IconButton {
                    icon: Theme.iconShuffle
                    iconSize: Theme.fontSizeSm
                    tooltip: "roll random wallpaper"
                    onClicked: root.rollRandomWallpaper()
                }

                IconButton {
                    icon: Theme.iconRefresh
                    iconSize: Theme.fontSizeSm
                    tooltip: "rescan / refresh current tab"
                    onClicked: {
                        if (root.activeTab === "local" || root.activeTab === "live") reloadLocalWallpapers();
                        else if (root.activeTab === "online") fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                        else if (WallpaperService?.reapplyTheme) WallpaperService.reapplyTheme();
                    }
                }

                IconButton {
                    icon: Theme.iconClose
                    iconSize: Theme.fontSizeSm
                    tooltip: "close panel"
                    onClicked: popup.open = false
                }
            }

            // segmented tab bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radiusMd
                color: Theme.cardBg
                border.color: Theme.cardBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "local", label: "local gallery", icon: Theme.iconFolder },
                            { id: "online", label: "wallhaven", icon: Theme.iconGlobe },
                            { id: "live", label: "live / video", icon: Theme.iconFlame },
                            { id: "theme", label: "effects & theme", icon: Theme.iconPalette }
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusPill

                            readonly property bool isSelected: root.activeTab === modelData.id

                            color: isSelected
                                ? Theme.primary_overlay
                                : (tabMouse.containsMouse ? Theme.widgetHover : "transparent")
                            border.color: isSelected ? Theme.primary : "transparent"
                            border.width: isSelected ? 1 : 0

                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    visible: !Theme.isTextIconSet
                                    text: modelData.icon
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeSm
                                    color: isSelected ? Theme.primary : Theme.on_surface_variant
                                }

                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: isSelected ? Font.Bold : Font.Medium
                                    color: isSelected ? Theme.primary : Theme.on_surface_variant
                                }
                            }

                            MouseArea {
                                id: tabMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.activeTab = modelData.id;
                                    if (modelData.id === "local") reloadLocalWallpapers();
                                    else if (modelData.id === "online" && root.onlineWallpapers.length === 0) fetchWallhaven(root.onlineQuery, root.onlineSorting, root.onlinePage, root.onlineResolution);
                                }
                            }
                        }
                    }
                }
            }

            // local gallery tab
            ColumnLayout {
                id: localView
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "local"
                spacing: 8

                readonly property var uniqueParentCategories: {
                    let cats = ["all"];
                    let items = root.allLocalWallpapers || [];
                    for (let i = 0; i < items.length; i++) {
                        let pCat = items[i]?.parentCategory || "root";
                        if (pCat && cats.indexOf(pCat) === -1) cats.push(pCat);
                    }
                    return cats;
                }

                readonly property var uniqueSubCategories: {
                    if (root.localCategoryFilter === "all") return [];
                    let subs = ["all"];
                    let items = root.allLocalWallpapers || [];
                    for (let i = 0; i < items.length; i++) {
                        let item = items[i];
                        if (item && item.parentCategory === root.localCategoryFilter && item.subCategory && item.subCategory !== "") {
                            if (subs.indexOf(item.subCategory) === -1) subs.push(item.subCategory);
                        }
                    }
                    return subs.length > 1 ? subs : [];
                }

                readonly property var filteredLocalWps: {
                    let result = [];
                    let items = root.allLocalWallpapers || [];
                    let pFilter = root.localCategoryFilter;
                    let subFilter = root.localSubCategoryFilter;
                    let sQuery = root.localSearchQuery.trim().toLowerCase();
                    for (let i = 0; i < items.length; i++) {
                        let item = items[i];
                        if (!item) continue;
                        let catStr = (item.category ?? "").toLowerCase();
                        let nameStr = (item.name ?? "").toLowerCase();
                        let pCat = item.parentCategory ?? "";
                        let subCat = item.subCategory ?? "";
                        let pMatch = pFilter === "all" || pCat === pFilter || catStr.indexOf(pFilter.toLowerCase()) !== -1;
                        let subMatch = subFilter === "all" || subCat === subFilter;
                        let searchMatch = sQuery === "" || nameStr.indexOf(sQuery) !== -1 || catStr.indexOf(sQuery) !== -1;

                        if (pMatch && subMatch && searchMatch) result.push(item);
                    }
                    return result;
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SearchField {
                        id: localSearchField
                        placeholder: "search local wallpapers by name or folder..."
                        badgeText: localView.filteredLocalWps.length + " matched"
                        onTextChanged: root.localSearchQuery = text.toLowerCase()
                        onCleared: root.localSearchQuery = ""
                    }

                    Chip {
                        icon: Theme.iconShuffle
                        label: "random here"
                        chipHeight: 36
                        inactiveBg: Theme.cardBg
                        onClicked: root.rollRandomWallpaper()
                    }
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    contentWidth: unifiedCatRow.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    RowLayout {
                        id: unifiedCatRow
                        spacing: 6

                        Repeater {
                            model: localView.uniqueParentCategories
                            delegate: Chip {
                                required property string modelData
                                label: modelData.toLowerCase()
                                selected: root.localCategoryFilter === modelData
                                chipHeight: 26
                                onClicked: {
                                    root.localCategoryFilter = modelData;
                                    root.localSubCategoryFilter = "all";
                                }
                            }
                        }

                        Rectangle {
                            visible: localView.uniqueSubCategories.length > 0
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 16
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            color: Theme.widgetBorder
                        }

                        Text {
                            visible: localView.uniqueSubCategories.length > 0 && !Theme.isTextIconSet
                            text: Theme.iconFolder
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.primary
                        }

                        Repeater {
                            model: localView.uniqueSubCategories
                            delegate: Chip {
                                required property string modelData
                                label: modelData.toLowerCase()
                                selected: root.localSubCategoryFilter === modelData
                                chipHeight: 26
                                onClicked: root.localSubCategoryFilter = modelData
                            }
                        }
                    }
                }

                GridView {
                    id: localGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: width / 3
                    cellHeight: cellWidth * 0.65
                    model: localView.filteredLocalWps
                    visible: localView.filteredLocalWps.length > 0

                    WheelHandler {
                        orientation: Qt.Vertical
                        target: parent
                    }

                    delegate: WallpaperCard {
                        required property var modelData
                        width: localGrid.cellWidth
                        height: localGrid.cellHeight
                        thumbUrl: modelData?.thumb || modelData?.path || ""
                        titleText: modelData?.name ?? ""
                        badgeText: modelData?.category === "root" ? "" : (modelData?.category ?? "")
                        tagText: modelData?.isVideo ? "live" : (modelData?.isGif ? "gif" : (modelData?.ext ?? ""))
                        tagAccent: Boolean(modelData?.isLive || modelData?.isVideo)
                        isSelected: modelData?.path === WallpaperService?.currentWallpaperPath
                        onApplyRequested: if (WallpaperService?.applyLocalWallpaper) WallpaperService.applyLocalWallpaper(modelData?.path)
                    }
                }

                EmptyState {
                    visible: localView.filteredLocalWps.length === 0
                    icon: Theme.iconFolder
                    message: "no wallpapers found\ntry adjusting your category or search filter"
                }
            }

            // wallhaven tab
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "online"
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SearchField {
                        id: onlineSearchField
                        text: root.onlineQuery
                        placeholder: "search wallhaven (anime, cyberpunk, nature, minimal...)"
                        onSubmitted: (val) => fetchWallhaven(val, root.onlineSorting, 1, resField.text)
                        onCleared: fetchWallhaven("", root.onlineSorting, 1, resField.text)
                    }

                    SearchField {
                        id: resField
                        Layout.fillWidth: false
                        Layout.preferredWidth: 165
                        text: root.onlineResolution
                        icon: Theme.iconWorkspaces
                        placeholder: "any (" + root.nativeRes + ")"
                        monoFont: true
                        onSubmitted: (val) => fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, val)
                        onCleared: fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, "")
                    }

                    Chip {
                        label: "native"
                        chipHeight: 36
                        selected: root.onlineResolution === root.nativeRes
                        inactiveBg: Theme.cardBg
                        onClicked: {
                            resField.text = root.nativeRes;
                            fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, root.nativeRes);
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { label: "latest", val: "date_added" },
                            { label: "toplist", val: "toplist" },
                            { label: "hot", val: "hot" },
                            { label: "views", val: "views" },
                            { label: "random", val: "random" }
                        ]

                        delegate: Chip {
                            required property var modelData
                            label: modelData.label
                            selected: root.onlineSorting === modelData.val
                            chipHeight: 26
                            onClicked: fetchWallhaven(onlineSearchField.text, modelData.val, 1, resField.text)
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Chip {
                        icon: Theme.iconChevronLeft
                        chipHeight: 26
                        opacity: root.onlinePage > 1 ? 1.0 : 0.4
                        onClicked: {
                            if (root.onlinePage > 1 && !root.isOnlineLoading) {
                                fetchWallhaven(onlineSearchField.text, root.onlineSorting, root.onlinePage - 1, resField.text);
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 26
                        Layout.preferredWidth: pageText.implicitWidth + 18
                        radius: Theme.radiusPill
                        color: Theme.widgetBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        Text {
                            id: pageText
                            anchors.centerIn: parent
                            text: "page " + root.onlinePage
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.Bold
                            color: Theme.primary
                        }
                    }

                    Chip {
                        icon: Theme.iconChevronRight
                        chipHeight: 26
                        onClicked: {
                            if (!root.isOnlineLoading) {
                                fetchWallhaven(onlineSearchField.text, root.onlineSorting, root.onlinePage + 1, resField.text);
                            }
                        }
                    }
                }

                GridView {
                    id: onlineGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: width / 3
                    cellHeight: cellWidth * 0.65
                    model: root.onlineWallpapers
                    visible: !root.isOnlineLoading && root.onlineWallpapers.length > 0

                    WheelHandler {
                        orientation: Qt.Vertical
                        target: parent
                    }

                    delegate: WallpaperCard {
                        required property var modelData
                        width: onlineGrid.cellWidth
                        height: onlineGrid.cellHeight
                        thumbUrl: modelData?.thumbUrl ?? ""
                        titleText: modelData?.id ?? ""
                        badgeText: modelData?.resolution ?? ""
                        tagText: modelData?.fileType ?? ""
                        tagAccent: modelData?.fileType === "png"
                        allowDownload: true
                        onApplyRequested: if (WallpaperService?.setWallpaper) WallpaperService.setWallpaper(modelData.fullUrl)
                        onDownloadRequested: root.downloadUrls([modelData.fullUrl])
                    }
                }

                EmptyState {
                    visible: root.isOnlineLoading || root.onlineWallpapers.length === 0
                    loading: root.isOnlineLoading
                    icon: Theme.iconGlobe
                    message: root.isOnlineLoading
                        ? ("fetching " + (root.onlineSorting === "date_added" ? "latest" : root.onlineSorting) + (root.onlineResolution ? (" " + root.onlineResolution) : "") + " wallpapers...")
                        : "no wallpapers found\ntry adjusting your search query or resolution"
                }
            }

            // live / video tab
            ColumnLayout {
                id: liveView
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "live"
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SearchField {
                        id: liveUrlField
                        icon: Theme.iconFlame
                        badgeText: root.localLiveWallpapers.length + " local"
                        placeholder: "paste video url or local path (.mp4, .webm, .gif)..."
                        onSubmitted: (val) => {
                            if (val.trim() !== "" && WallpaperService?.setWallpaper) {
                                WallpaperService.setWallpaper(val.trim());
                            }
                        }
                    }

                    IconButton {
                        icon: Theme.iconClipboard
                        iconSize: Theme.fontSizeSm
                        tooltip: "paste from clipboard"
                        onClicked: {
                            let clip = Quickshell?.clipboardText ? Quickshell.clipboardText.trim() : "";
                            if (clip !== "") liveUrlField.text = clip;
                        }
                    }

                    Chip {
                        icon: Theme.iconCheck
                        label: "apply"
                        chipHeight: 36
                        selected: liveUrlField.text.trim() !== ""
                        onClicked: {
                            if (liveUrlField.text.trim() !== "" && WallpaperService?.setWallpaper) {
                                WallpaperService.setWallpaper(liveUrlField.text.trim());
                            }
                        }
                    }
                }

                GridView {
                    id: liveGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    cellWidth: width / 3
                    cellHeight: cellWidth * 0.65
                    model: root.localLiveWallpapers
                    visible: root.localLiveWallpapers.length > 0

                    WheelHandler {
                        orientation: Qt.Vertical
                        target: parent
                    }

                    delegate: WallpaperCard {
                        required property var modelData
                        readonly property string targetPath: modelData?.path || modelData?.url || ""
                        width: liveGrid.cellWidth
                        height: liveGrid.cellHeight
                        thumbUrl: modelData?.thumb || targetPath
                        titleText: modelData?.name || "live wallpaper"
                        badgeText: modelData?.isVideo ? "video" : "gif"
                        tagText: modelData?.ext || "live"
                        tagAccent: true
                        isSelected: targetPath !== "" && targetPath === WallpaperService?.currentWallpaperPath
                        onApplyRequested: {
                            if (WallpaperService?.applyLocalWallpaper) {
                                WallpaperService.applyLocalWallpaper(targetPath);
                            }
                        }
                    }
                }

                EmptyState {
                    visible: root.localLiveWallpapers.length === 0
                    icon: Theme.iconFlame
                    message: "no local animated wallpapers found\ndrop .mp4, .webm, or .gif files into ~/.wallpapers"
                }
            }

            // effects & theme tab
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.activeTab === "theme"
                clip: true
                contentWidth: width
                contentHeight: themeCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                WheelHandler {
                    orientation: Qt.Vertical
                    target: parent
                }

                ColumnLayout {
                    id: themeCol
                    width: parent.width - 4
                    spacing: Theme.popupSpacing

                    SettingCard {
                        title: "matugen color palette"
                        icon: Theme.iconPalette
                        badge: (WallpaperService?.currentMode ?? "dark") + " • " + (WallpaperService?.currentSchemeType ?? "scheme-tonal-spot").replace("scheme-", "")

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Chip {
                                icon: Theme.iconMoon
                                label: "dark mode"
                                selected: WallpaperService?.currentMode === "dark"
                                fillWidth: true
                                chipHeight: 30
                                onClicked: if (WallpaperService?.setMode) WallpaperService.setMode("dark")
                            }

                            Chip {
                                icon: Theme.iconSun
                                label: "light mode"
                                selected: WallpaperService?.currentMode === "light"
                                fillWidth: true
                                chipHeight: 30
                                onClicked: if (WallpaperService?.setMode) WallpaperService.setMode("light")
                            }
                        }

                        GroupLabel { text: "scheme algorithm" }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 5
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: [
                                    { label: "tonal spot", val: "scheme-tonal-spot" },
                                    { label: "smart", val: "scheme-smart" },
                                    { label: "vibrant", val: "scheme-vibrant" },
                                    { label: "expressive", val: "scheme-expressive" },
                                    { label: "content", val: "scheme-content" },
                                    { label: "fruit salad", val: "scheme-fruit-salad" },
                                    { label: "rainbow", val: "scheme-rainbow" },
                                    { label: "fidelity", val: "scheme-fidelity" },
                                    { label: "monochrome", val: "scheme-monochrome" },
                                    { label: "neutral", val: "scheme-neutral" }
                                ]

                                delegate: Chip {
                                    required property var modelData
                                    label: modelData.label
                                    selected: WallpaperService?.currentSchemeType === modelData.val
                                    fillWidth: true
                                    chipHeight: 26
                                    onClicked: if (WallpaperService?.setScheme) WallpaperService.setScheme(modelData.val)
                                }
                            }
                        }

                        GroupLabel { text: "seed color override" }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: Theme.radiusPill
                                color: {
                                    let h = hexField.text.trim();
                                    return (h.startsWith("#") && (h.length === 7 || h.length === 9)) ? h : Theme.primary;
                                }
                                border.color: Theme.on_surface
                                border.width: 1
                            }

                            SearchField {
                                id: hexField
                                Layout.preferredWidth: 150
                                Layout.fillWidth: false
                                Layout.preferredHeight: 32
                                icon: Theme.iconSparkles
                                text: String(Theme.source_color || "#a8c8ff")
                                placeholder: "#rrggbb"
                                monoFont: true
                                onSubmitted: (val) => {
                                    let h = val.trim();
                                    if (h.startsWith("#") && (h.length === 7 || h.length === 9) && WallpaperService?.applyColor) {
                                        WallpaperService.applyColor(h);
                                    }
                                }
                            }

                            Chip {
                                label: "apply hex"
                                chipHeight: 32
                                selected: true
                                onClicked: {
                                    let h = hexField.text.trim();
                                    if (h.startsWith("#") && (h.length === 7 || h.length === 9) && WallpaperService?.applyColor) {
                                        WallpaperService.applyColor(h);
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Repeater {
                                    model: [
                                        "#a8c8ff", "#ffb4ab", "#c8bfff", "#8bf0ba",
                                        "#ffd700", "#ff7597", "#70d6ff", "#ff9e00",
                                        "#50fa7b", "#bd93f9", "#ff79c6"
                                    ]

                                    delegate: Rectangle {
                                        required property string modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 24
                                        radius: Theme.radiusPill
                                        color: modelData
                                        border.color: hexField.text === modelData ? Theme.on_surface : Theme.widgetBorder
                                        border.width: hexField.text === modelData ? 2 : 1

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                hexField.text = modelData;
                                                if (WallpaperService?.applyColor) WallpaperService.applyColor(modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SettingCard {
                        title: "awww transition engine"
                        icon: Theme.iconFlame
                        badge: (Settings?.awwwTransitionType ?? "fade") + " • " + (Settings?.awwwTransitionFps ?? 60) + " fps"

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                GroupLabel { text: "resize mode" }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { label: "crop", val: "crop" },
                                            { label: "fit", val: "fit" },
                                            { label: "stretch", val: "stretch" },
                                            { label: "center", val: "no" }
                                        ]

                                        delegate: Chip {
                                            required property var modelData
                                            label: modelData.label
                                            selected: (Settings?.awwwResize ?? "crop") === modelData.val
                                            fillWidth: true
                                            chipHeight: 26
                                            onClicked: {
                                                if (Settings) {
                                                    Settings.awwwResize = modelData.val;
                                                    if (Settings.save) Settings.save();
                                                }
                                                if (WallpaperService?.reapplyTheme) WallpaperService.reapplyTheme();
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                GroupLabel { text: "scaling filter" }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: ["Lanczos3", "Bilinear", "CatmullRom", "Mitchell", "Nearest"]

                                        delegate: Chip {
                                            required property string modelData
                                            label: modelData.toLowerCase()
                                            selected: (Settings?.awwwFilter ?? "Lanczos3") === modelData
                                            fillWidth: true
                                            chipHeight: 26
                                            onClicked: {
                                                if (Settings) {
                                                    Settings.awwwFilter = modelData;
                                                    if (Settings.save) Settings.save();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        GroupLabel { text: "transition animation" }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7
                            rowSpacing: 6
                            columnSpacing: 6

                            Repeater {
                                model: ["fade", "simple", "wipe", "wave", "grow", "center", "outer", "any", "random", "left", "right", "top", "bottom", "none"]

                                delegate: Chip {
                                    required property string modelData
                                    label: modelData
                                    selected: (Settings?.awwwTransitionType ?? "fade") === modelData
                                    fillWidth: true
                                    chipHeight: 26
                                    onClicked: {
                                        if (Settings) {
                                            Settings.awwwTransitionType = modelData;
                                            if (Settings.save) Settings.save();
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: {
                                let t = Settings?.awwwTransitionType ?? "fade";
                                return t === "wipe" || t === "wave";
                            }

                            GroupLabel {
                                text: "angle:"
                                Layout.rightMargin: 4
                            }

                            Repeater {
                                model: [
                                    { label: "0°", val: 0 },
                                    { label: "45°", val: 45 },
                                    { label: "90°", val: 90 },
                                    { label: "135°", val: 135 },
                                    { label: "180°", val: 180 },
                                    { label: "270°", val: 270 }
                                ]

                                delegate: Chip {
                                    required property var modelData
                                    label: modelData.label
                                    selected: (Settings?.awwwTransitionAngle ?? 0) === modelData.val
                                    fillWidth: true
                                    chipHeight: 26
                                    onClicked: {
                                        if (Settings) {
                                            Settings.awwwTransitionAngle = modelData.val;
                                            if (Settings.save) Settings.save();
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: {
                                let t = Settings?.awwwTransitionType ?? "fade";
                                return t === "grow" || t === "outer";
                            }

                            GroupLabel {
                                text: "origin:"
                                Layout.rightMargin: 4
                            }

                            Repeater {
                                model: ["center", "top", "bottom", "left", "right"]

                                delegate: Chip {
                                    required property string modelData
                                    label: modelData
                                    selected: (Settings?.awwwTransitionPos ?? "center") === modelData
                                    fillWidth: true
                                    chipHeight: 26
                                    onClicked: {
                                        if (Settings) {
                                            Settings.awwwTransitionPos = modelData;
                                            if (Settings.save) Settings.save();
                                        }
                                    }
                                }
                            }
                        }

                        GroupLabel { text: "transition frame rate" }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { label: "30 fps", val: 30 },
                                    { label: "60 fps", val: 60 },
                                    { label: "90 fps", val: 90 },
                                    { label: "120 fps", val: 120 },
                                    { label: "144 fps", val: 144 },
                                    { label: "165 fps", val: 165 },
                                    { label: "240 fps", val: 240 }
                                ]

                                delegate: Chip {
                                    required property var modelData
                                    label: modelData.label
                                    selected: (Settings?.awwwTransitionFps ?? 60) === modelData.val
                                    fillWidth: true
                                    chipHeight: 26
                                    onClicked: {
                                        if (Settings) {
                                            Settings.awwwTransitionFps = modelData.val;
                                            if (Settings.save) Settings.save();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SettingCard {
                        title: "mpvpaper live video engine"
                        icon: Theme.iconPlay
                        badge: (Settings?.mpvAudio ?? false) ? "audio on" : "muted"

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                GroupLabel { text: "video aspect & panscan" }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: [
                                            { label: "crop (fill)", val: 1.0 },
                                            { label: "balanced", val: 0.5 },
                                            { label: "letterbox", val: 0.0 }
                                        ]

                                        delegate: Chip {
                                            required property var modelData
                                            label: modelData.label
                                            selected: Math.abs((Settings?.mpvPanscan ?? 1.0) - modelData.val) < 0.05
                                            fillWidth: true
                                            chipHeight: 28
                                            onClicked: {
                                                if (Settings) {
                                                    Settings.mpvPanscan = modelData.val;
                                                    if (Settings.save) Settings.save();
                                                }
                                                if (WallpaperService?.reapplyTheme) WallpaperService.reapplyTheme();
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                GroupLabel { text: "video audio" }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Chip {
                                        icon: Theme.iconVolMute
                                        label: "mute"
                                        selected: !(Settings?.mpvAudio ?? false)
                                        fillWidth: true
                                        chipHeight: 28
                                        onClicked: {
                                            if (Settings) {
                                                Settings.mpvAudio = false;
                                                if (Settings.save) Settings.save();
                                            }
                                            if (WallpaperService?.reapplyTheme) WallpaperService.reapplyTheme();
                                        }
                                    }

                                    Chip {
                                        icon: Theme.iconVolHigh
                                        label: "ambient sound"
                                        selected: Settings?.mpvAudio ?? false
                                        fillWidth: true
                                        chipHeight: 28
                                        onClicked: {
                                            if (Settings) {
                                                Settings.mpvAudio = true;
                                                if (Settings.save) Settings.save();
                                            }
                                            if (WallpaperService?.reapplyTheme) WallpaperService.reapplyTheme();
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
