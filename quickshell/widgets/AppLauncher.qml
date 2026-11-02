import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import ".."
import "../controls"
import "../services"

PopupPanel {
    id: root

    wantsFocus: true
    keyboardFocusMode: WlrKeyboardFocus.Exclusive

    cardWidth: 480
    cardHeight: 570

    property string query: ""
    property string activeCategory: "all"
    property bool gridViewMode: false
    property bool showCategoryManager: false
    property string activeManagingCatId: ""
    property string categoryAppFilter: ""
    property string newCategoryName: ""
    property string newCategoryIcon: "terminal"
    property var categoryAssignApp: null

    // persistent pinned apps list controlled by qs
    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")
    readonly property string pinnedStatePath: configDir + "/quickshell/pinned_apps"
    property var pinnedApps: []

    FileView {
        id: pinnedFile
        path: root.pinnedStatePath
        blockLoading: false
        watchChanges: false
        printErrors: false
        onLoaded: {
            let raw = text();
            if (!raw || raw.trim() === "") return;
            root.pinnedApps = raw.trim().split("\n").map(s => s.trim().toLowerCase()).filter(Boolean);
        }
    }

    function isAppPinned(app) {
        if (!app) return false;
        let aid = (app.id || "").toLowerCase();
        let aname = (app.name || "").toLowerCase();
        return (aid !== "" && root.pinnedApps.includes(aid)) || (aname !== "" && root.pinnedApps.includes(aname));
    }

    function togglePinApp(app) {
        if (!app) return;
        let key = ((app.id || app.name) || "").trim().toLowerCase();
        if (!key) return;
        let next = root.pinnedApps.slice();
        let idx = next.indexOf(key);
        if (idx >= 0) {
            next.splice(idx, 1);
            if (root.activeCategory === "pinned" && next.length === 0) {
                root.activeCategory = "all";
            }
        } else {
            next.push(key);
        }
        root.pinnedApps = next;
        pinnedFile.setText(next.join("\n") + (next.length > 0 ? "\n" : ""));
    }

    readonly property string cleanQuery: query.trim()
    readonly property bool isCommand: (cleanQuery.startsWith(">") || cleanQuery.startsWith("$") || cleanQuery.startsWith(":")) && (Settings?.launcherCommandEnabled ?? true)
    readonly property string cleanCommand: isCommand ? cleanQuery.slice(1).trim() : ""
    readonly property var calcResult: (Settings?.launcherCalcEnabled ?? true) && !isCommand ? evaluateMath(cleanQuery) : null

    readonly property var availableIcons: [
        { key: "terminal", icon: Theme?.iconTerminal ?? "󰆍", label: "dev" },
        { key: "globe",    icon: Theme?.iconGlobe ?? "󰖟",    label: "web" },
        { key: "music",    icon: Theme?.iconMusic ?? "󰝚",    label: "media" },
        { key: "flame",    icon: Theme?.iconFlame ?? "󰈸",    label: "games" },
        { key: "folder",   icon: Theme?.iconFolder ?? "󰉋",   label: "files" },
        { key: "settings", icon: Theme?.iconSettings ?? "󰒓", label: "sys" },
        { key: "heart",    icon: Theme?.iconHeart ?? "󰋑",    label: "fav" },
        { key: "sparkles", icon: Theme?.iconSparkles ?? "󰓏", label: "cool" },
        { key: "palette",  icon: Theme?.iconPalette ?? "󰏘",  label: "art" },
        { key: "sliders",  icon: Theme?.iconSliders ?? "󰔡",  label: "tools" }
    ]

    function resolveCategoryIcon(iconKey) {
        if (!iconKey) return Theme?.iconFolder ?? "󰉋";
        for (let i = 0; i < availableIcons.length; i++) {
            if (availableIcons[i].key === iconKey) return availableIcons[i].icon;
        }
        return iconKey;
    }

    readonly property var categoryList: {
        let list = [{ id: "all", label: "all", icon: Theme?.iconGrid ?? "󰕰" }];
        if (root.pinnedApps.length > 0) {
            list.push({ id: "pinned", label: "pinned", icon: Theme?.iconHeart ?? "♥" });
        }
        let custom = Settings?.launcherCustomCategories ?? [];
        if (Array.isArray(custom)) {
            for (let i = 0; i < custom.length; i++) {
                let c = custom[i];
                if (c && c.id && c.name) {
                    list.push({
                        id: c.id,
                        label: c.name.toLowerCase(),
                        icon: resolveCategoryIcon(c.icon),
                        appIds: c.appIds || []
                    });
                }
            }
        }
        return list;
    }

    function getActiveCatName() {
        let custom = Settings?.launcherCustomCategories ?? [];
        let c = custom.find(x => x && x.id === activeManagingCatId);
        return c ? c.name.toLowerCase() : "";
    }

    function getAppCategories(app) {
        if (!app) return [];
        let custom = Settings?.launcherCustomCategories ?? [];
        let aid = (app.id || "").toLowerCase();
        let aname = (app.name || "").toLowerCase();
        let res = [];
        for (let i = 0; i < custom.length; i++) {
            let c = custom[i];
            if (!c || !c.appIds) continue;
            let assigned = c.appIds.map(x => String(x).toLowerCase());
            if (assigned.includes(aid) || assigned.includes(aname)) {
                res.push({ id: c.id, name: c.name.toLowerCase(), icon: resolveCategoryIcon(c.icon) });
            }
        }
        return res;
    }

    // math parser so you don't have to open a terminal just to calculate 1920 * 1080
    function evaluateMath(expr) {
        if (!expr || expr.length < 2) return null;
        let s = expr.trim();
        if (!/^[\d\s\+\-\*\/\(\)\.\^\%eEpiPIsqrtSQRTabsABScosCOScinSINtanTAN\<\>\&\|\~]+$/.test(s) && !s.startsWith("0x")) {
            return null;
        }
        if (!/[\+\-\*\/\^\%]|sqrt|abs|sin|cos|tan|0x/i.test(s)) return null;
        try {
            let sanitized = s
                .replace(/sqrt\(/gi, "Math.sqrt(")
                .replace(/abs\(/gi, "Math.abs(")
                .replace(/sin\(/gi, "Math.sin(")
                .replace(/cos\(/gi, "Math.cos(")
                .replace(/tan\(/gi, "Math.tan(")
                .replace(/\^/g, "**")
                .replace(/\bpi\b/gi, "Math.PI");
            let res = Function('"use strict"; return (' + sanitized + ')')();
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                return String(Math.round(res * 100000) / 100000);
            }
        } catch(e) {}
        return null;
    }

    function resolveIconSource(app) {
        let ic = app?.icon || "";
        if (ic.startsWith("/")) return "file://" + ic;
        if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon(ic)) {
            return Quickshell.iconPath(ic);
        }
        if (Quickshell?.hasThemeIcon && Quickshell.hasThemeIcon("application-x-executable")) {
            return Quickshell.iconPath("application-x-executable");
        }
        return "";
    }

    // unified filtered & scored apps list shared by both List and Bento Grid views
    readonly property var filteredApps: {
        const q = root.query.trim().toLowerCase();
        const cat = root.activeCategory;
        const pinned = root.pinnedApps;
        let apps = [...(DesktopEntries?.applications?.values ?? [])].filter(a => a && a.name);

        if (cat === "pinned") {
            apps = apps.filter(app => root.isAppPinned(app));
        } else if (cat !== "all") {
            let customList = Array.isArray(Settings?.launcherCustomCategories) ? Settings.launcherCustomCategories : [];
            let targetCat = customList.find(c => c && c.id === cat);
            if (targetCat) {
                let assigned = (targetCat.appIds || []).map(x => String(x).toLowerCase());
                apps = apps.filter(app => {
                    let aid = (app.id || "").toLowerCase();
                    let aname = (app.name || "").toLowerCase();
                    return assigned.includes(aid) || assigned.includes(aname);
                });
            }
        }

        if (!q) {
            return apps.sort((a, b) => {
                let ap = root.isAppPinned(a) ? 1 : 0;
                let bp = root.isAppPinned(b) ? 1 : 0;
                if (ap !== bp) return bp - ap;
                return (a.name || "").localeCompare(b.name || "");
            });
        }

        return apps.map(app => {
            let score = 0;
            const name = (app.name || "").toLowerCase();
            const gen = (app.genericName || "").toLowerCase();
            const comment = (app.comment || "").toLowerCase();
            const kw = app.keywords || [];

            if (name === q) score += 150;
            else if (name.startsWith(q)) score += 100;
            else if (name.includes(q)) score += 60;

            if (gen.startsWith(q)) score += 40;
            else if (gen.includes(q)) score += 25;

            if (kw.some(k => (k || "").toLowerCase().includes(q))) score += 15;
            if (comment.includes(q)) score += 10;
            if (score > 0 && root.isAppPinned(app)) score += 12;

            return { app, score };
        })
        .filter(item => item.score > 0)
        .sort((a, b) => b.score !== a.score ? b.score - a.score : (a.app.name || "").localeCompare(b.app.name || ""))
        .map(item => item.app);
    }

    function resetSelection() {
        appList.currentIndex = 0;
        appGrid.currentIndex = 0;
        appList.positionViewAtBeginning();
        appGrid.positionViewAtBeginning();
    }

    function launchCurrentSelection() {
        let idx = root.gridViewMode ? appGrid.currentIndex : appList.currentIndex;
        let targetApp = (idx >= 0 && idx < root.filteredApps.length) ? root.filteredApps[idx] : null;
        if (targetApp?.execute) {
            targetApp.execute();
            root.open = false;
        }
    }

    onOpenChanged: {
        if (open) {
            query = "";
            activeCategory = "all";
            showCategoryManager = false;
            activeManagingCatId = "";
            categoryAssignApp = null;
            searchInput.text = "";
            Qt.callLater(() => {
                searchInput.forceActiveFocus();
                root.resetSelection();
            });
        } else {
            query = "";
            showCategoryManager = false;
            activeManagingCatId = "";
            categoryAssignApp = null;
            searchInput.text = "";
        }
    }

    content: Item {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing
            Keys.forwardTo: [searchInput]

            // search bar pill with mode badge and view switcher
            Rectangle {
                visible: !root.showCategoryManager
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                color: searchInput.activeFocus ? Theme.pillHover : Theme.pillBg
                radius: searchInput.text.length > 0 ? Theme.radiusLg : Theme.radiusPill
                border.color: root.isCommand
                    ? Theme.tertiary
                    : (root.calcResult !== null
                        ? Theme.primary
                        : (searchInput.activeFocus ? Theme.alpha(Theme.primary, 0.65) : Theme.pillBorder))
                border.width: (searchInput.activeFocus || root.isCommand || root.calcResult !== null) ? 2 : 1

                Behavior on radius { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 8
                    spacing: 10

                    // dynamic mode icon badge
                    Rectangle {
                        width: 28
                        height: 28
                        radius: Theme.radiusPill
                        color: (root.isCommand || root.calcResult !== null)
                            ? Theme.primary_overlay
                            : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: root.isCommand
                                ? Theme.iconTerminal
                                : (root.calcResult !== null ? "=" : Theme.iconSearch)
                            font.family: root.calcResult !== null ? Theme.fontMono : Theme.fontIcon
                            font.pixelSize: Theme.fontSizeMd
                            font.weight: Theme.fontWeightBold
                            color: root.isCommand
                                ? Theme.tertiary
                                : (searchInput.activeFocus || root.calcResult !== null ? Theme.primary : Theme.textSecondary)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: root.isCommand ? Theme.fontMono : Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textPrimary
                        selectionColor: Theme.primary_container
                        selectedTextColor: Theme.on_primary_container
                        selectByMouse: true
                        focus: true
                        clip: true

                        Text {
                            text: "search apps, math, or > command..."
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.on_surface_disabled
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                        }

                        onTextChanged: {
                            root.query = text;
                            root.resetSelection();
                        }

                        Keys.onPressed: (event) => {
                            if (event.key === Qt.Key_Escape) {
                                if (root.categoryAssignApp !== null) {
                                    root.categoryAssignApp = null;
                                    event.accepted = true;
                                    return;
                                }
                                if (root.showCategoryManager) {
                                    if (root.activeManagingCatId !== "") {
                                        root.activeManagingCatId = "";
                                    } else {
                                        root.showCategoryManager = false;
                                    }
                                    event.accepted = true;
                                    return;
                                }
                                if (searchInput.text.length > 0) {
                                    searchInput.text = "";
                                    event.accepted = true;
                                    return;
                                }
                                root.open = false;
                                event.accepted = true;
                            } else if (root.gridViewMode) {
                                if (event.key === Qt.Key_Right || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                                    if (appGrid.count > 0) appGrid.moveCurrentIndexRight();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                                    if (appGrid.count > 0) appGrid.moveCurrentIndexLeft();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    if (appGrid.count > 0) appGrid.moveCurrentIndexDown();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    if (appGrid.count > 0) appGrid.moveCurrentIndexUp();
                                    event.accepted = true;
                                }
                            } else {
                                if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                                    if (appList.count > 0) {
                                        appList.incrementCurrentIndex();
                                        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                                    if (appList.count > 0) {
                                        appList.decrementCurrentIndex();
                                        appList.positionViewAtIndex(appList.currentIndex, ListView.Contain);
                                    }
                                    event.accepted = true;
                                }
                            }

                            if (!event.accepted && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                if (root.isCommand && root.cleanCommand.length > 0) {
                                    Quickshell.execDetached(["sh", "-c", root.cleanCommand]);
                                    root.open = false;
                                    event.accepted = true;
                                    return;
                                }
                                if (root.calcResult !== null) {
                                    Quickshell.execDetached(["wl-copy", "--", root.calcResult]);
                                    root.open = false;
                                    event.accepted = true;
                                    return;
                                }
                                if (root.filteredApps.length === 0 && root.cleanQuery.length > 0 && (Settings?.launcherCommandEnabled ?? true)) {
                                    Quickshell.execDetached(["sh", "-c", root.cleanQuery]);
                                    root.open = false;
                                    event.accepted = true;
                                    return;
                                }
                                root.launchCurrentSelection();
                                event.accepted = true;
                            }
                        }
                    }

                    IconButton {
                        icon: Theme.iconClose
                        iconSize: Theme.fontSizeXs
                        tooltip: "clear search"
                        visible: searchInput.text.length > 0
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                    }

                    // list vs bento grid view switcher
                    Rectangle {
                        width: 32
                        height: 32
                        radius: root.gridViewMode ? Theme.radiusMd : Theme.radiusPill
                        color: root.gridViewMode
                            ? Theme.primary_overlay
                            : (viewModeMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                        border.color: root.gridViewMode ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder
                        border.width: 1

                        Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        Text {
                            anchors.centerIn: parent
                            text: root.gridViewMode ? Theme.iconClipboard : Theme.iconGrid
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeSm
                            color: root.gridViewMode ? Theme.primary : Theme.textSecondary
                        }

                        MouseArea {
                            id: viewModeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let curIdx = root.gridViewMode ? appGrid.currentIndex : appList.currentIndex;
                                root.gridViewMode = !root.gridViewMode;
                                appList.currentIndex = Math.max(0, curIdx);
                                appGrid.currentIndex = Math.max(0, curIdx);
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            // category filter pills & manager toggle
            RowLayout {
                visible: !root.showCategoryManager
                Layout.fillWidth: true
                spacing: 6

                Flickable {
                    id: catFlick
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    contentWidth: categoryRow.implicitWidth
                    contentHeight: 30
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        orientation: Qt.Vertical
                        onWheel: (event) => {
                            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                            const maxX = Math.max(0, catFlick.contentWidth - catFlick.width);
                            catFlick.contentX = Math.max(0, Math.min(maxX, catFlick.contentX - delta * 0.7));
                            event.accepted = true;
                        }
                    }

                    Row {
                        id: categoryRow
                        spacing: 6

                        Repeater {
                            model: root.categoryList
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool isSelected: root.activeCategory === modelData.id
                                height: 28
                                width: Math.max(44, chipLayout.implicitWidth + 20)
                                radius: isSelected ? Theme.radiusMd : Theme.radiusPill
                                color: isSelected
                                    ? Theme.primary_overlay
                                    : (catChipMouse.containsMouse ? Theme.pillHover : Theme.pillBg)
                                border.color: isSelected
                                    ? Theme.alpha(Theme.primary, 0.65)
                                    : (catChipMouse.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.pillBorder)
                                border.width: (isSelected || catChipMouse.containsMouse || Theme.pillBorder.a > 0) ? 1 : 0

                                Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                RowLayout {
                                    id: chipLayout
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: modelData.icon
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeXs
                                        color: isSelected ? Theme.primary : Theme.textSecondary
                                    }
                                    Text {
                                        text: modelData.label
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: isSelected ? Theme.fontWeightBold : Theme.fontWeightMedium
                                        color: isSelected ? Theme.primary : Theme.textSecondary
                                    }
                                }

                                MouseArea {
                                    id: catChipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.activeCategory = modelData.id;
                                        root.resetSelection();
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }

                // category studio button
                Rectangle {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 28
                    radius: Theme.radiusPill
                    color: manageHover.containsMouse ? Theme.widgetHover : Theme.widgetBg
                    border.color: manageHover.containsMouse ? Theme.alpha(Theme.primary, 0.45) : Theme.widgetBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.centerIn: parent
                        text: (Settings?.launcherCustomCategories?.length > 0) ? Theme.iconSliders : "+"
                        font.family: (Settings?.launcherCustomCategories?.length > 0) ? Theme.fontIcon : Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.fontWeightBold
                        color: manageHover.containsMouse ? Theme.primary : Theme.textSecondary
                    }

                    MouseArea {
                        id: manageHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.showCategoryManager = true;
                            root.activeManagingCatId = "";
                        }
                    }
                }
            }

            Rectangle {
                visible: !root.showCategoryManager
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.popupDividerHeight
                color: Theme.widgetBorder
            }

            // inline calculator hero card
            Rectangle {
                id: calcCard
                visible: !root.showCategoryManager && root.calcResult !== null
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: Theme.radiusLg
                color: Theme.blend(Theme.cardBg, Theme.primary, 0.14)
                border.color: Theme.alpha(Theme.primary, 0.5)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: Theme.radiusMd
                        color: Theme.primary

                        Text {
                            text: "="
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLg
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_primary
                            anchors.centerIn: parent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: root.calcResult ?? ""
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLg
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                        }

                        Text {
                            text: "press enter or click to copy to clipboard"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.primary
                        }
                    }

                    Rectangle {
                        height: 26
                        implicitWidth: copyBadgeTxt.implicitWidth + 16
                        radius: Theme.radiusPill
                        color: Theme.primary

                        Text {
                            id: copyBadgeTxt
                            anchors.centerIn: parent
                            text: "copy ↵"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_primary
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["wl-copy", "--", root.calcResult]);
                        root.open = false;
                    }
                }
            }

            // inline shell command runner card
            Rectangle {
                id: cmdCard
                visible: !root.showCategoryManager && ((root.isCommand && root.cleanCommand.length > 0) || (root.filteredApps.length === 0 && root.calcResult === null && root.cleanQuery.length > 0 && (Settings?.launcherCommandEnabled ?? true)))
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: Theme.radiusLg
                color: Theme.blend(Theme.cardBg, Theme.tertiary, 0.12)
                border.color: Theme.alpha(Theme.tertiary, 0.5)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: Theme.radiusMd
                        color: Theme.tertiary_overlay
                        border.color: Theme.alpha(Theme.tertiary, 0.45)
                        border.width: 1

                        Text {
                            text: ">_"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.tertiary
                            anchors.centerIn: parent
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            text: root.isCommand ? root.cleanCommand : root.cleanQuery
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "run detached shell command"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.tertiary
                        }
                    }

                    Rectangle {
                        height: 26
                        implicitWidth: runBadgeTxt.implicitWidth + 16
                        radius: Theme.radiusPill
                        color: Theme.tertiary

                        Text {
                            id: runBadgeTxt
                            anchors.centerIn: parent
                            text: "exec ↵"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_tertiary
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let cmd = root.isCommand ? root.cleanCommand : root.cleanQuery;
                        Quickshell.execDetached(["sh", "-c", cmd]);
                        root.open = false;
                    }
                }
            }

            // main applications container (List View + Bento Grid View)
            Item {
                visible: !root.showCategoryManager
                Layout.fillWidth: true
                Layout.fillHeight: true

                // 1. Expressive List View
                ListView {
                    id: appList
                    anchors.fill: parent
                    anchors.rightMargin: 6
                    clip: true
                    spacing: 5
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationWraps: true
                    visible: !root.gridViewMode && appList.count > 0

                    model: ScriptModel {
                        objectProp: "id"
                        values: root.filteredApps
                    }

                    delegate: Rectangle {
                        id: appDelegate
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: appList.currentIndex === index
                        readonly property bool isHovered: mouseArea.containsMouse
                        readonly property bool isPinned: root.isAppPinned(modelData)

                        width: appList.width
                        implicitHeight: 54
                        radius: isSelected ? Theme.radiusLg : Theme.radiusMd
                        color: isSelected
                            ? Theme.blend(Theme.cardBg, Theme.primary, 0.15)
                            : (isHovered ? Theme.widgetHover : "transparent")
                        border.color: isSelected
                            ? Theme.alpha(Theme.primary, 0.55)
                            : (isHovered ? Theme.widgetBorder : "transparent")
                        border.width: 1

                        Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        function launch() {
                            if (modelData?.execute) {
                                modelData.execute();
                            }
                            root.open = false;
                        }

                        // left active accent indicator pill
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: appDelegate.isSelected ? 22 : 0
                            radius: Theme.radiusPill
                            color: Theme.primary

                            Behavior on height { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: appDelegate.isSelected ? 14 : 10
                            anchors.rightMargin: 10
                            spacing: 12

                            Behavior on anchors.leftMargin { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                            // rounded icon squircle
                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: Theme.radiusMd
                                color: appDelegate.isSelected ? Theme.primary_overlay : Theme.widgetBg
                                border.color: appDelegate.isSelected
                                    ? Theme.alpha(Theme.primary, 0.4)
                                    : (Theme.isGlass ? Theme.glassHighlight : Theme.cardBorder)
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                IconImage {
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    source: root.resolveIconSource(modelData)
                                    scale: (appDelegate.isSelected || appDelegate.isHovered) ? 1.08 : 1.0

                                    Behavior on scale { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: (modelData?.name ?? "").toLowerCase()
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: appDelegate.isSelected ? Theme.fontWeightBold : Theme.fontWeightDemiBold
                                        color: appDelegate.isSelected ? Theme.primary : Theme.textPrimary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                    }

                                    // category tags assigned to this app
                                    Row {
                                        spacing: 4
                                        Repeater {
                                            model: root.getAppCategories(modelData)
                                            delegate: Rectangle {
                                                required property var modelData
                                                height: 18
                                                width: tagText.implicitWidth + 10
                                                radius: Theme.radiusPill
                                                color: Theme.pillBg
                                                border.color: Theme.pillBorder
                                                border.width: 1

                                                Text {
                                                    id: tagText
                                                    anchors.centerIn: parent
                                                    text: modelData.name
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontSizeXs
                                                    color: Theme.textSecondary
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: (modelData?.genericName || modelData?.comment || "").toLowerCase()
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textSecondary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                }
                            }

                            // pin / favorite button
                            Rectangle {
                                visible: appDelegate.isPinned || appDelegate.isHovered || appDelegate.isSelected
                                width: 26
                                height: 26
                                radius: Theme.radiusPill
                                color: pinMouse.containsMouse ? Theme.primary_overlay : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: Theme.iconHeart
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeXs
                                    color: appDelegate.isPinned ? Theme.primary : Theme.textSecondary
                                    opacity: appDelegate.isPinned ? 1.0 : 0.55
                                }

                                MouseArea {
                                    id: pinMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.togglePinApp(appDelegate.modelData);
                                        searchInput.forceActiveFocus();
                                    }
                                }
                            }

                            // squishy launch pill on selected row
                            Rectangle {
                                visible: appDelegate.isSelected
                                implicitWidth: launchRow.implicitWidth + 14
                                implicitHeight: 24
                                radius: Theme.radiusPill
                                color: Theme.primary

                                RowLayout {
                                    id: launchRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: "open"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_primary
                                    }

                                    Text {
                                        text: "↵"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_primary
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            anchors.rightMargin: (appDelegate.isPinned || appDelegate.isHovered || appDelegate.isSelected) ? 40 : 0
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onEntered: appList.currentIndex = index
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.LeftButton) {
                                    appList.currentIndex = index;
                                    appDelegate.launch();
                                } else if (mouse.button === Qt.RightButton) {
                                    root.categoryAssignApp = modelData;
                                } else if (mouse.button === Qt.MiddleButton) {
                                    root.togglePinApp(modelData);
                                }
                            }
                        }
                    }
                }

                // 2. Bento 4-Column Icon Grid View
                GridView {
                    id: appGrid
                    anchors.fill: parent
                    anchors.rightMargin: 6
                    clip: true
                    cellWidth: Math.floor(width / 4)
                    cellHeight: 96
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationWraps: true
                    visible: root.gridViewMode && appGrid.count > 0

                    model: ScriptModel {
                        objectProp: "id"
                        values: root.filteredApps
                    }

                    delegate: Item {
                        id: gridCell
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: appGrid.currentIndex === index
                        readonly property bool isHovered: gridMouse.containsMouse
                        readonly property bool isPinned: root.isAppPinned(modelData)

                        width: appGrid.cellWidth
                        height: appGrid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: gridCell.isSelected ? Theme.radiusLg : Theme.radiusMd
                            color: gridCell.isSelected
                                ? Theme.blend(Theme.cardBg, Theme.primary, 0.16)
                                : (gridCell.isHovered ? Theme.widgetHover : Theme.cardBg)
                            border.color: gridCell.isSelected
                                ? Theme.alpha(Theme.primary, 0.65)
                                : (gridCell.isHovered ? Theme.alpha(Theme.primary, 0.3) : Theme.cardBorder)
                            border.width: 1

                            Behavior on radius { NumberAnimation { duration: Theme.animFast } }
                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            // pinned heart badge in top-right corner of grid tile
                            Text {
                                visible: gridCell.isPinned
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                text: Theme.iconHeart
                                font.family: Theme.fontIcon
                                font.pixelSize: 9
                                color: Theme.primary
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    width: 42
                                    height: 42
                                    radius: Theme.radiusMd
                                    color: gridCell.isSelected ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: Theme.isGlass ? Theme.glassHighlight : Theme.widgetBorder
                                    border.width: 1

                                    IconImage {
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        source: root.resolveIconSource(gridCell.modelData)
                                        scale: (gridCell.isSelected || gridCell.isHovered) ? 1.1 : 1.0
                                        Behavior on scale { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                                    }
                                }

                                Text {
                                    text: (gridCell.modelData?.name ?? "").toLowerCase()
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: gridCell.isSelected ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: gridCell.isSelected ? Theme.primary : Theme.textPrimary
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: gridMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onEntered: appGrid.currentIndex = gridCell.index
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        appGrid.currentIndex = gridCell.index;
                                        if (gridCell.modelData?.execute) gridCell.modelData.execute();
                                        root.open = false;
                                    } else if (mouse.button === Qt.RightButton) {
                                        root.categoryAssignApp = gridCell.modelData;
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        root.togglePinApp(gridCell.modelData);
                                    }
                                }
                            }
                        }
                    }
                }

                // sleek scrollbar indicator
                Rectangle {
                    readonly property Flickable activeFlick: root.gridViewMode ? appGrid : appList
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 3
                    radius: 2
                    color: "transparent"
                    visible: activeFlick.visible && activeFlick.visibleArea.heightRatio < 1.0

                    Rectangle {
                        width: parent.width
                        readonly property real trackH: parent.height
                        readonly property real thumbH: Math.max(24, Math.min(trackH, parent.activeFlick.visibleArea.heightRatio * trackH))
                        height: thumbH
                        y: Math.max(0, Math.min(trackH - thumbH, parent.activeFlick.visibleArea.yPosition * trackH))
                        radius: 2
                        color: Theme.primary
                        opacity: 0.7
                    }
                }

                // cohesive empty state card
                Rectangle {
                    anchors.fill: parent
                    visible: root.filteredApps.length === 0 && root.calcResult === null && !cmdCard.visible
                    radius: Theme.radiusLg
                    color: Theme.cardBg
                    border.color: Theme.cardBorder
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: Theme.iconSet === "kaomoji" ? Theme.kaoShrug : Theme.iconSearch
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeLg : Theme.fontSizeTitle
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: root.activeCategory !== "all" ? "no apps in this category" : "no matching applications"
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: "tip: prefix with > to run a shell command or type math"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.textSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            // footer status & shortcut hints
            RowLayout {
                visible: !root.showCategoryManager
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    height: 20
                    implicitWidth: countTxt.implicitWidth + 12
                    radius: Theme.radiusPill
                    color: Theme.pillBg
                    border.color: Theme.pillBorder
                    border.width: Theme.pillBorder.a > 0 ? 1 : 0

                    Text {
                        id: countTxt
                        anchors.centerIn: parent
                        text: root.filteredApps.length + " apps"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.fontWeightBold
                        color: Theme.primary
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "↵ launch  •  ♥/mid-click pin  •  right-click tag"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeXs
                    color: Theme.textSecondary
                    opacity: 0.78
                }
            }

            // category manager view
            ColumnLayout {
                visible: root.showCategoryManager
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.popupSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: Theme.radiusPill
                        color: managerBackHover.containsMouse ? Theme.widgetHover : Theme.widgetBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: Theme.iconChevronLeft
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeSm
                            color: Theme.textPrimary
                        }

                        MouseArea {
                            id: managerBackHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.activeManagingCatId !== "") {
                                    root.activeManagingCatId = "";
                                } else {
                                    root.showCategoryManager = false;
                                }
                            }
                        }
                    }

                    Text {
                        text: root.activeManagingCatId !== "" ? ("assign apps: " + root.getActiveCatName()) : "category studio"
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 28
                        radius: Theme.radiusPill
                        color: doneHover.containsMouse
                            ? Theme.stateHover(Theme.primary, Theme.on_primary)
                            : Theme.primary

                        Text {
                            anchors.centerIn: parent
                            text: "done"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_primary
                        }

                        MouseArea {
                            id: doneHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeManagingCatId = "";
                                root.showCategoryManager = false;
                                searchInput.forceActiveFocus();
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.popupDividerHeight
                    color: Theme.widgetBorder
                }

                // subview A: list & create categories
                ColumnLayout {
                    visible: root.activeManagingCatId === ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Theme.popupSpacing

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        radius: Theme.radiusLg
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

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: Theme.radiusMd
                                    color: Theme.widgetBg
                                    border.color: newCatInput.activeFocus ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    TextInput {
                                        id: newCatInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.textPrimary
                                        selectByMouse: true

                                        Text {
                                            text: "new category name (e.g. dev, games, media)..."
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.on_surface_disabled
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !newCatInput.text && !newCatInput.inputMethodComposing
                                        }

                                        onAccepted: {
                                            if (newCatInput.text.trim().length > 0) {
                                                Settings.addLauncherCategory(newCatInput.text.trim(), root.newCategoryIcon);
                                                newCatInput.text = "";
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    readonly property bool canAdd: newCatInput.text.trim().length > 0
                                    Layout.preferredWidth: 66
                                    Layout.preferredHeight: 32
                                    radius: Theme.radiusPill
                                    color: canAdd ? Theme.primary : Theme.widgetBg
                                    border.color: canAdd ? "transparent" : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+ add"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: parent.canAdd ? Theme.on_primary : Theme.textSecondary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: parent.canAdd ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (parent.canAdd) {
                                                Settings.addLauncherCategory(newCatInput.text.trim(), root.newCategoryIcon);
                                                newCatInput.text = "";
                                            }
                                        }
                                    }
                                }
                            }

                            // icon selector chips
                            Flickable {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                contentWidth: iconRow.implicitWidth
                                contentHeight: 28
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                Row {
                                    id: iconRow
                                    spacing: 6

                                    Repeater {
                                        model: root.availableIcons
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool isCurrent: root.newCategoryIcon === modelData.key
                                            width: 30
                                            height: 26
                                            radius: isCurrent ? Theme.radiusMd : Theme.radiusPill
                                            color: isCurrent
                                                ? Theme.primary_overlay
                                                : (iconHover.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                            border.color: isCurrent ? Theme.primary : Theme.widgetBorder
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.fontSizeXs
                                                color: isCurrent ? Theme.primary : Theme.textSecondary
                                            }

                                            MouseArea {
                                                id: iconHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.newCategoryIcon = modelData.key
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // existing categories list
                    ListView {
                        id: catManageList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds
                        model: Settings?.launcherCustomCategories ?? []

                        delegate: Rectangle {
                            required property var modelData
                            width: catManageList.width
                            implicitHeight: 48
                            radius: Theme.radiusMd
                            color: Theme.cardBg
                            border.color: Theme.cardBorder
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    width: 30
                                    height: 30
                                    radius: Theme.radiusSm
                                    color: Theme.primary_overlay

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.resolveCategoryIcon(modelData.icon)
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeSm
                                        color: Theme.primary
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: (modelData.name || "").toLowerCase()
                                        font.family: Theme.fontDisplay
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: (modelData.appIds ? modelData.appIds.length : 0) + " apps assigned"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.textSecondary
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 88
                                    Layout.preferredHeight: 28
                                    radius: Theme.radiusPill
                                    color: manageAppsHover.containsMouse ? Theme.primary_overlay : Theme.widgetBg
                                    border.color: manageAppsHover.containsMouse ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "assign apps"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: manageAppsHover.containsMouse ? Theme.primary : Theme.textPrimary
                                    }

                                    MouseArea {
                                        id: manageAppsHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.activeManagingCatId = modelData.id;
                                            root.categoryAppFilter = "";
                                        }
                                    }
                                }

                                IconButton {
                                    icon: Theme.iconTrash
                                    iconSize: Theme.fontSizeXs
                                    tooltip: "delete category"
                                    onClicked: Settings.removeLauncherCategory(modelData.id)
                                }
                            }
                        }
                    }

                    // empty categories state
                    Rectangle {
                        visible: (Settings?.launcherCustomCategories ?? []).length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusLg
                        color: Theme.cardBg
                        border.color: Theme.cardBorder
                        border.width: 1

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: Theme.iconFolder
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontSizeTitle
                                color: Theme.textSecondary
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "no custom categories yet"
                                font.family: Theme.fontDisplay
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: Theme.textPrimary
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "create one above to group and filter your favorite apps"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textSecondary
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }

                // subview B: assign apps to selected category
                ColumnLayout {
                    visible: root.activeManagingCatId !== ""
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        color: Theme.pillBg
                        radius: Theme.radiusPill
                        border.color: catAppFilterInput.activeFocus ? Theme.primary : Theme.pillBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: Theme.iconSearch
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontSizeSm
                                color: catAppFilterInput.activeFocus ? Theme.primary : Theme.textSecondary
                            }

                            TextInput {
                                id: catAppFilterInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.textPrimary
                                selectByMouse: true

                                Text {
                                    text: "filter apps to assign..."
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_surface_disabled
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !catAppFilterInput.text && !catAppFilterInput.inputMethodComposing
                                }

                                onTextChanged: root.categoryAppFilter = text.trim().toLowerCase()
                            }
                        }
                    }

                    ListView {
                        id: catAppPickList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds

                        model: {
                            let q = root.categoryAppFilter;
                            let apps = [...(DesktopEntries?.applications?.values ?? [])].filter(a => a && a.name);
                            if (q) {
                                apps = apps.filter(a => {
                                    let n = (a.name || "").toLowerCase();
                                    let g = (a.genericName || "").toLowerCase();
                                    return n.includes(q) || g.includes(q);
                                });
                            }
                            return apps.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
                        }

                        delegate: Rectangle {
                            required property var modelData
                            width: catAppPickList.width
                            implicitHeight: 44
                            radius: Theme.radiusMd
                            color: isChecked
                                ? Theme.primary_overlay
                                : (rowHover.containsMouse ? Theme.widgetHover : Theme.cardBg)
                            border.color: isChecked ? Theme.alpha(Theme.primary, 0.5) : Theme.cardBorder
                            border.width: 1

                            readonly property bool isChecked: {
                                let custom = Settings?.launcherCustomCategories ?? [];
                                let cat = custom.find(c => c && c.id === root.activeManagingCatId);
                                if (!cat || !cat.appIds) return false;
                                let aid = (modelData.id || "").toLowerCase();
                                let aname = (modelData.name || "").toLowerCase();
                                let assigned = cat.appIds.map(x => String(x).toLowerCase());
                                return assigned.includes(aid) || assigned.includes(aname);
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 10

                                Rectangle {
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    radius: Theme.radiusSm
                                    color: Theme.widgetBg

                                    IconImage {
                                        anchors.centerIn: parent
                                        width: 20
                                        height: 20
                                        source: root.resolveIconSource(modelData)
                                    }
                                }

                                Text {
                                    text: (modelData?.name ?? "").toLowerCase()
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: isChecked ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: isChecked ? Theme.primary : Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    radius: Theme.radiusSm
                                    color: isChecked ? Theme.primary : "transparent"
                                    border.color: isChecked ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        visible: isChecked
                                        text: Theme.iconCheck
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_primary
                                    }
                                }
                            }

                            MouseArea {
                                id: rowHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Settings.toggleAppInLauncherCategory(root.activeManagingCatId, modelData.id || modelData.name)
                            }
                        }
                    }
                }
            }
        }

        // quick right-click category assign modal
        Rectangle {
            id: modalBackdrop
            anchors.fill: parent
            color: Theme.alpha(Theme.scrim, 0.65)
            visible: root.categoryAssignApp !== null
            radius: Theme.popupRadius
            z: 100

            MouseArea {
                anchors.fill: parent
                onClicked: root.categoryAssignApp = null
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(360, parent.width - 32)
                height: Math.min(320, parent.height - 32)
                radius: Theme.radiusLg
                color: Theme.popupBg
                border.color: Theme.alpha(Theme.primary, 0.55)
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "tag: " + ((root.categoryAssignApp?.name ?? "").toLowerCase())
                            font.family: Theme.fontDisplay
                            font.pixelSize: Theme.fontSizeSm
                            font.weight: Theme.fontWeightBold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        IconButton {
                            icon: Theme.iconClose
                            iconSize: Theme.fontSizeXs
                            tooltip: "close"
                            onClicked: root.categoryAssignApp = null
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.popupDividerHeight
                        color: Theme.widgetBorder
                    }

                    Text {
                        visible: (Settings?.launcherCustomCategories ?? []).length === 0
                        text: "no custom categories created yet. click + on the category bar to create one."
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    ListView {
                        visible: (Settings?.launcherCustomCategories ?? []).length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 6
                        model: Settings?.launcherCustomCategories ?? []

                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 38
                            radius: Theme.radiusMd
                            color: isAssigned
                                ? Theme.primary_overlay
                                : (modalCatHover.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                            border.color: isAssigned ? Theme.alpha(Theme.primary, 0.5) : Theme.widgetBorder
                            border.width: 1

                            readonly property bool isAssigned: {
                                if (!root.categoryAssignApp || !modelData || !modelData.appIds) return false;
                                let aid = (root.categoryAssignApp.id || "").toLowerCase();
                                let aname = (root.categoryAssignApp.name || "").toLowerCase();
                                let assigned = modelData.appIds.map(x => String(x).toLowerCase());
                                return assigned.includes(aid) || assigned.includes(aname);
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: root.resolveCategoryIcon(modelData.icon)
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.primary
                                }

                                Text {
                                    text: (modelData.name || "").toLowerCase()
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: isAssigned ? Theme.fontWeightBold : Theme.fontWeightMedium
                                    color: isAssigned ? Theme.primary : Theme.textPrimary
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 20
                                    radius: Theme.radiusSm
                                    color: isAssigned ? Theme.primary : "transparent"
                                    border.color: isAssigned ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        visible: isAssigned
                                        text: Theme.iconCheck
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_primary
                                    }
                                }
                            }

                            MouseArea {
                                id: modalCatHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.categoryAssignApp) {
                                        Settings.toggleAppInLauncherCategory(modelData.id, root.categoryAssignApp.id || root.categoryAssignApp.name);
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
