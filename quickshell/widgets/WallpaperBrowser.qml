// WallpaperBrowser.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../services"
import "../theme/confFormat.mjs" as ConfFmt
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

BarPill {
    id: root

    readonly property bool isFloatingBar: (Settings?.barFloating ?? false) || Theme.isIslands
    readonly property int effectiveBarMargin: isFloatingBar ? ((Settings?.barMargin > 0) ? Settings.barMargin : 8) : 0

    active: popup.open
    hovered: wpMouse.containsMouse
    pressed: wpMouse.pressed
    activeBorder: Theme.alpha(Theme.primary, 0.55)
    clip: true

    implicitWidth: {
        if (Theme.isVertical) return root.pillSize;
        if (Theme.isTextIconSet) return wpRow.implicitWidth + 20;
        return root.pillSize;
    }
    visible: Settings?.showWallpaper ?? true

    Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

    property string activeTab: "local"
    property string localCategoryFilter: "all"
    property string localSubCategoryFilter: "all"
    property string localMediaFilter: "all" // "all" | "images" | "gif" | "video"
    property string localSortMode: "name"   // "name" | "category"
    property string localSearchQuery: ""
    property string onlineQuery: ""
    property string onlineSorting: "date_added"
    property string onlineOrder: "desc"
    property string onlineTopRange: "1M"
    property string onlineCategories: "111"
    property string onlinePurity: "100"
    property string onlineRatios: ""
    property string onlineAtleast: ""
    property string onlineColor: ""
    property string onlineApiKey: ""
    property int onlinePage: 1
    property int onlineTotalPages: 1
    property int onlineTotalCount: 0
    property string onlineErrorText: ""
    property bool onlineShowSavedOnly: false
    property bool showApiKeyRow: false

    readonly property string wallhavenConfPath: (Quickshell?.env("HOME") || "/home/ashley") + "/.local/state/quickshell/wallhaven.conf"
    readonly property string wallhavenFavsPath: (Quickshell?.env("HOME") || "/home/ashley") + "/.local/share/quickshell/wallpaper_favs.conf"
    property var wallhavenFavs: []
    property var selectedDetailItem: null
    property var detailMeta: ({ loaded: false, loading: false, error: "", uploader: "", fileSize: "", purity: "", category: "", views: 0, favorites: 0, ratio: "", colors: [], tags: [] })

    readonly property var displayedOnlineWallpapers: root.onlineShowSavedOnly ? root.wallhavenFavs : root.onlineWallpapers

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

    readonly property var localFilenameSet: {
        let map = {};
        let items = root.allLocalWallpapers || [];
        for (let i = 0; i < items.length; i++) {
            let p = items[i]?.path || "";
            if (!p) continue;
            let slash = p.lastIndexOf("/");
            let fname = (slash >= 0 ? p.slice(slash + 1) : p).toLowerCase();
            if (fname) map[fname] = true;
            // Also index wallhaven id if file starts with wallhaven-<id>
            let m = fname.match(/wallhaven-([a-z0-9]+)/);
            if (m && m[1]) map[m[1]] = true;
        }
        return map;
    }

    function hasLocalWallpaper(idOrUrl): bool {
        if (!idOrUrl) return false;
        let low = String(idOrUrl).toLowerCase();
        if (root.localFilenameSet[low]) return true;
        let m = low.match(/wallhaven-([a-z0-9]+)/);
        return Boolean(m && m[1] && root.localFilenameSet[m[1]]);
    }

    function getBasename(p): string {
        if (!p) return "";
        let idx = p.lastIndexOf("/");
        return idx >= 0 ? p.slice(idx + 1) : p;
    }

    function saveAwwSetting(fn) {
        if (Settings) {
            fn();
            if (Settings.save) Settings.save();
        }
    }

    Timer {
        id: batchStatusResetTimer
        interval: 4000
        onTriggered: root.batchStatusText = ""
    }

    Connections {
        target: WallpaperService
        function onCommandFinished(ok) {
            if (root.isBatchDownloading) {
                root.isBatchDownloading = false;
                root.batchStatusText = ok ? "saved wallpapers to library" : "download failed";
                batchStatusResetTimer.restart();
            }
        }
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
            if (popup.open) {
                root.reloadLocalWallpapers();
                if (WallpaperService?.queryAwwwState) WallpaperService.queryAwwwState();
                root.focusActiveInput();
            } else {
                root.selectedDetailItem = null;
            }
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

    Timer {
        id: wallhavenConfSaveTimer
        interval: 250
        onTriggered: {
            let lines = [
                "# Quickshell Wallhaven preferences & optional API key",
                "sorting=" + ConfFmt.escapeField(root.onlineSorting),
                "order=" + ConfFmt.escapeField(root.onlineOrder),
                "topRange=" + ConfFmt.escapeField(root.onlineTopRange),
                "categories=" + ConfFmt.escapeField(root.onlineCategories),
                "purity=" + ConfFmt.escapeField(root.onlinePurity),
                "ratios=" + ConfFmt.escapeField(root.onlineRatios),
                "atleast=" + ConfFmt.escapeField(root.onlineAtleast),
                "color=" + ConfFmt.escapeField(root.onlineColor),
                "resolution=" + ConfFmt.escapeField(root.onlineResolution),
                "apiKey=" + ConfFmt.escapeField(root.onlineApiKey)
            ];
            wallhavenConfFile.setText(lines.join("\n") + "\n");
        }
    }

    FileView {
        id: wallhavenConfFile
        path: root.wallhavenConfPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            let d = ConfFmt.parseFlatConf(text());
            if (d.sorting) root.onlineSorting = ConfFmt.unescapeField(d.sorting);
            if (d.order) root.onlineOrder = ConfFmt.unescapeField(d.order);
            if (d.topRange) root.onlineTopRange = ConfFmt.unescapeField(d.topRange);
            if (d.categories) root.onlineCategories = ConfFmt.unescapeField(d.categories);
            if (d.purity) root.onlinePurity = ConfFmt.unescapeField(d.purity);
            if (d.ratios !== undefined) root.onlineRatios = ConfFmt.unescapeField(d.ratios);
            if (d.atleast !== undefined) root.onlineAtleast = ConfFmt.unescapeField(d.atleast);
            if (d.color !== undefined) root.onlineColor = ConfFmt.unescapeField(d.color);
            if (d.resolution !== undefined && d.resolution !== "") root.onlineResolution = ConfFmt.unescapeField(d.resolution);
            if (d.apiKey !== undefined) root.onlineApiKey = ConfFmt.unescapeField(d.apiKey);
        }
    }

    FileView {
        id: wallhavenFavsFile
        path: root.wallhavenFavsPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            let recs = ConfFmt.parseRecords(text(), "fav");
            let list = [];
            for (let i = 0; i < recs.length; i++) {
                let r = recs[i];
                if (!r || !r.id) continue;
                list.push({
                    id: r.id,
                    fullUrl: r.fullUrl || "",
                    thumbUrl: r.thumbUrl || "",
                    resolution: r.resolution || "",
                    fileType: r.fileType || "jpg",
                    colors: r.colors ? r.colors.split("|").filter(Boolean) : []
                });
            }
            root.wallhavenFavs = list;
        }
    }

    function saveWallhavenConf() {
        wallhavenConfSaveTimer.restart();
    }

    function saveWallhavenFavs() {
        let rows = [];
        for (let i = 0; i < root.wallhavenFavs.length; i++) {
            let it = root.wallhavenFavs[i];
            if (!it || !it.id) continue;
            rows.push({
                id: it.id,
                fullUrl: it.fullUrl || "",
                thumbUrl: it.thumbUrl || "",
                resolution: it.resolution || "",
                fileType: it.fileType || "jpg",
                colors: Array.isArray(it.colors) ? it.colors.join("|") : ""
            });
        }
        wallhavenFavsFile.setText(ConfFmt.serializeRecords(rows, "fav", ["id", "fullUrl", "thumbUrl", "resolution", "fileType", "colors"]));
    }

    function isFavWallhaven(wpId): bool {
        if (!wpId) return false;
        let target = String(wpId).toLowerCase();
        for (let i = 0; i < root.wallhavenFavs.length; i++) {
            if (String(root.wallhavenFavs[i]?.id || "").toLowerCase() === target) return true;
        }
        return false;
    }

    function toggleFavWallhaven(item) {
        if (!item || !item.id) return;
        let target = String(item.id).toLowerCase();
        let next = [];
        let existed = false;
        for (let i = 0; i < root.wallhavenFavs.length; i++) {
            let cur = root.wallhavenFavs[i];
            if (String(cur?.id || "").toLowerCase() === target) {
                existed = true;
            } else {
                next.push(cur);
            }
        }
        if (!existed) {
            next.unshift({
                id: target,
                fullUrl: item.fullUrl || "",
                thumbUrl: item.thumbUrl || "",
                resolution: item.resolution || "",
                fileType: item.fileType || "jpg",
                colors: Array.isArray(item.colors) ? item.colors : []
            });
        }
        root.wallhavenFavs = next;
        root.saveWallhavenFavs();
    }

    function formatBytes(bytes): string {
        let b = Number(bytes) || 0;
        if (b <= 0) return "";
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " mb";
        return Math.round(b / 1024) + " kb";
    }

    function copyColorHex(hexStr) {
        if (!hexStr) return;
        if (Quickshell) Quickshell.clipboardText = hexStr;
        root.batchStatusText = "copied " + hexStr.toLowerCase();
        batchStatusResetTimer.restart();
    }

    // lightweight regex scraper for wallhaven API v1 search responses (zero JSON.parse)
    function parseWallhavenResponse(raw) {
        if (!raw) return { items: [], lastPage: 1, total: 0 };
        let metaIdx = raw.lastIndexOf('"meta"');
        let dataRaw = metaIdx > 0 ? raw.slice(0, metaIdx) : raw;
        let metaRaw = metaIdx > 0 ? raw.slice(metaIdx) : "";
        let lastPageMatch = metaRaw.match(/"last_page"\s*:\s*(\d+)/);
        let totalMatch = metaRaw.match(/"total"\s*:\s*(\d+)/);

        let results = [];
        let blocks = dataRaw.split('"id":');
        for (let i = 1; i < blocks.length; i++) {
            let b = blocks[i];
            let idMatch = b.match(/^\s*"([^"]+)"/);
            let pathMatch = b.match(/"path"\s*:\s*"([^"]+)"/);
            let thumbLarge = b.match(/"large"\s*:\s*"([^"]+)"/);
            let thumbSmall = b.match(/"small"\s*:\s*"([^"]+)"/);
            let resMatch = b.match(/"resolution"\s*:\s*"([^"]+)"/);
            let ratioMatch = b.match(/"ratio"\s*:\s*"([^"]+)"/);
            let typeMatch = b.match(/"file_type"\s*:\s*"image\/([^"]+)"/);
            let colorsMatch = b.match(/"colors"\s*:\s*\[([^\]]*)\]/);
            let colorsList = [];
            if (colorsMatch && colorsMatch[1]) {
                let hexMatches = colorsMatch[1].match(/#[0-9a-fA-F]{6}/g) || [];
                for (let c = 0; c < hexMatches.length; c++) colorsList.push(hexMatches[c].toLowerCase());
            }
            if (pathMatch) {
                let fullUrl = pathMatch[1].replace(/\\\//g, "/");
                let thumbUrl = thumbLarge
                    ? thumbLarge[1].replace(/\\\//g, "/")
                    : (thumbSmall ? thumbSmall[1].replace(/\\\//g, "/") : fullUrl);
                results.push({
                    id: idMatch ? idMatch[1].toLowerCase() : "",
                    fullUrl: fullUrl,
                    thumbUrl: thumbUrl,
                    resolution: resMatch ? resMatch[1] : "",
                    ratio: ratioMatch ? ratioMatch[1] : "",
                    fileType: typeMatch ? typeMatch[1].toLowerCase() : "img",
                    colors: colorsList
                });
            }
        }
        return {
            items: results,
            lastPage: lastPageMatch ? Math.max(1, parseInt(lastPageMatch[1], 10) || 1) : 1,
            total: totalMatch ? (parseInt(totalMatch[1], 10) || results.length) : results.length
        };
    }

    function parseWallhavenDetail(raw) {
        if (!raw) return null;
        let uploaderM = raw.match(/"uploader"\s*:\s*\{[^}]*"username"\s*:\s*"([^"]+)"/);
        let viewsM = raw.match(/"views"\s*:\s*(\d+)/);
        let favsM = raw.match(/"favorites"\s*:\s*(\d+)/);
        let sizeM = raw.match(/"file_size"\s*:\s*(\d+)/);
        let purityM = raw.match(/"purity"\s*:\s*"([^"]+)"/);
        let catM = raw.match(/"category"\s*:\s*"([^"]+)"/);
        let ratioM = raw.match(/"ratio"\s*:\s*"([^"]+)"/);
        let colorsM = raw.match(/"colors"\s*:\s*\[([^\]]*)\]/);
        let colorsList = [];
        if (colorsM && colorsM[1]) {
            let hexes = colorsM[1].match(/#[0-9a-fA-F]{6}/g) || [];
            for (let i = 0; i < hexes.length; i++) colorsList.push(hexes[i].toLowerCase());
        }
        let tagsList = [];
        let tagsIdx = raw.indexOf('"tags"');
        if (tagsIdx >= 0) {
            let tagsSlice = raw.slice(tagsIdx);
            let nameRegex = /"name"\s*:\s*"([^"]+)"/g;
            let m;
            while ((m = nameRegex.exec(tagsSlice)) !== null && tagsList.length < 18) {
                let tagVal = m[1].replace(/\\\//g, "/").toLowerCase();
                if (tagsList.indexOf(tagVal) === -1) tagsList.push(tagVal);
            }
        }
        return {
            loaded: true,
            loading: false,
            error: "",
            uploader: uploaderM ? uploaderM[1] : "anon",
            fileSize: sizeM ? root.formatBytes(sizeM[1]) : "",
            purity: purityM ? purityM[1].toLowerCase() : "sfw",
            category: catM ? catM[1].toLowerCase() : "general",
            views: viewsM ? (parseInt(viewsM[1], 10) || 0) : 0,
            favorites: favsM ? (parseInt(favsM[1], 10) || 0) : 0,
            ratio: ratioM ? ratioM[1] : "",
            colors: colorsList,
            tags: tagsList
        };
    }

    function openWallpaperDetails(item) {
        if (!item || !item.id) return;
        root.selectedDetailItem = item;
        root.detailMeta = {
            loaded: false,
            loading: true,
            error: "",
            uploader: "",
            fileSize: "",
            purity: "",
            category: "",
            views: 0,
            favorites: 0,
            ratio: item.ratio || "",
            colors: Array.isArray(item.colors) ? item.colors : [],
            tags: []
        };
        let req = new XMLHttpRequest();
        let url = "https://wallhaven.cc/api/v1/w/" + encodeURIComponent(item.id);
        req.open("GET", url);
        if (root.onlineApiKey.trim() !== "") {
            req.setRequestHeader("X-API-Key", root.onlineApiKey.trim());
        }
        req.timeout = 10000;
        req.ontimeout = () => {
            root.detailMeta = Object.assign({}, root.detailMeta, { loading: false, error: "timed out loading metadata" });
        };
        req.onerror = () => {
            root.detailMeta = Object.assign({}, root.detailMeta, { loading: false, error: "network error" });
        };
        req.onreadystatechange = () => {
            if (req.readyState === XMLHttpRequest.DONE) {
                if (req.status === 200) {
                    let parsed = root.parseWallhavenDetail(req.responseText);
                    if (parsed) root.detailMeta = parsed;
                    else root.detailMeta = Object.assign({}, root.detailMeta, { loading: false, error: "failed to parse metadata" });
                } else {
                    root.detailMeta = Object.assign({}, root.detailMeta, {
                        loading: false,
                        error: req.status === 401 ? "api key required for nsfw details" : ("api status " + req.status)
                    });
                }
            }
        };
        req.send();
    }

    function fetchWallhaven(query, sort, page, resolution) {
        root.onlineShowSavedOnly = false;
        root.isOnlineLoading = true;
        root.onlineErrorText = "";
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
        params.push("order=" + encodeURIComponent(root.onlineOrder || "desc"));
        if (s === "toplist") params.push("topRange=" + encodeURIComponent(root.onlineTopRange || "1M"));
        params.push("page=" + p);
        params.push("categories=" + encodeURIComponent(root.onlineCategories || "111"));
        params.push("purity=" + encodeURIComponent(root.onlinePurity || "100"));

        if (r !== "" && r.toLowerCase() !== "any") {
            params.push("resolutions=" + encodeURIComponent(r));
        }
        if (root.onlineAtleast !== "") {
            params.push("atleast=" + encodeURIComponent(root.onlineAtleast));
        }
        if (root.onlineRatios !== "") {
            params.push("ratios=" + encodeURIComponent(root.onlineRatios));
        }
        if (root.onlineColor !== "") {
            params.push("colors=" + encodeURIComponent(root.onlineColor));
        }

        root.saveWallhavenConf();

        req.open("GET", "https://wallhaven.cc/api/v1/search?" + params.join("&"));
        if (root.onlineApiKey.trim() !== "") {
            req.setRequestHeader("X-API-Key", root.onlineApiKey.trim());
        }
        req.timeout = 12000;
        req.ontimeout = () => {
            root.isOnlineLoading = false;
            root.onlineErrorText = "wallhaven request timed out";
        };
        req.onerror = () => {
            root.isOnlineLoading = false;
            root.onlineErrorText = "network error contacting wallhaven";
        };
        req.onreadystatechange = () => {
            if (req.readyState === XMLHttpRequest.DONE) {
                root.isOnlineLoading = false;
                if (req.status === 200) {
                    let parsed = root.parseWallhavenResponse(req.responseText);
                    root.onlineWallpapers = parsed.items;
                    root.onlineTotalPages = parsed.lastPage;
                    root.onlineTotalCount = parsed.total;
                } else if (req.status === 401) {
                    root.onlineErrorText = "nsfw purity requires a valid wallhaven api key (click shield icon)";
                } else if (req.status === 429) {
                    root.onlineErrorText = "wallhaven rate limit hit (45 req/min) — wait a few seconds";
                } else {
                    root.onlineErrorText = "wallhaven api returned status " + req.status;
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
        } else {
            root.isBatchDownloading = false;
            batchStatusResetTimer.restart();
        }
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
        font.variableAxes: Theme.sansAxes
        font.pixelSize: Theme.fontSizeXs
        font.weight: Theme.fontWeightDemiBold
        color: Theme.on_surface_variant
    }

    component SettingCard: Rectangle {
        id: sCard
        property string title: ""
        property string icon: ""
        property string badge: ""
        property string actionLabel: ""
        property string actionIcon: ""
        signal actionClicked()
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
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.primary
                }

                Text {
                    text: sCard.title
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeSm
                    font.weight: Theme.fontWeightBold
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
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.monoWeightBold
                        color: Theme.primary
                    }
                }

                Rectangle {
                    visible: sCard.actionLabel !== ""
                    height: 22
                    implicitWidth: actionRow.implicitWidth + 14
                    radius: Theme.radiusPill
                    color: sActionMouse.containsMouse ? Theme.primary : Theme.widgetBg
                    border.color: sActionMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                    RowLayout {
                        id: actionRow
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            visible: sCard.actionIcon !== "" && !Theme.isTextIconSet
                            text: sCard.actionIcon
                            font.family: Theme.fontIcon
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.fontSizeXs
                            color: sActionMouse.containsMouse ? Theme.on_primary : Theme.primary
                        }

                        Text {
                            text: sCard.actionLabel
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.fontWeightBold
                            color: sActionMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                        }
                    }

                    MouseArea {
                        id: sActionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sCard.actionClicked()
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
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                color: inputItem.activeFocus ? Theme.primary : Theme.on_surface_variant
            }

            TextInput {
                id: inputItem
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: TextInput.AlignVCenter
                font.family: fieldRoot.monoFont ? Theme.fontMono : Theme.fontFamily
                font.variableAxes: fieldRoot.monoFont ? Theme.monoAxes : Theme.sansAxes
                font.weight: fieldRoot.monoFont ? Theme.monoWeightRegular : Theme.fontWeightRegular
                font.pixelSize: Theme.fontSizeSm
                color: Theme.on_surface
                selectByMouse: true
                activeFocusOnTab: true
                clip: true

                Text {
                    text: fieldRoot.placeholder
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
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
                    font.variableAxes: Theme.monoAxes
                    font.weight: Theme.monoWeightRegular
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
                font.variableAxes: Theme.iconAxes
                font.pixelSize: chipRoot.fontSize
                color: chipRoot.selected ? chipRoot.activeFg : chipRoot.inactiveFg
            }

            Text {
                visible: chipRoot.label !== ""
                text: chipRoot.label
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.pixelSize: chipRoot.fontSize
                font.weight: chipRoot.selected ? Theme.fontWeightBold : Theme.fontWeightRegular
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
                    font.variableAxes: Theme.iconAxes
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
                font.variableAxes: Theme.sansAxes
                font.weight: Theme.fontWeightRegular
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
        property bool isSavedLocal: false
        property bool allowDownload: false
        property bool allowDetails: false
        property bool allowFavorite: false
        property bool isFavorite: false
        property var colorsPreview: []
        signal applyRequested()
        signal downloadRequested()
        signal detailsRequested()
        signal favoriteRequested()

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
                id: cardImg
                anchors.fill: parent
                source: (cardRoot.thumbUrl.startsWith("http://") || cardRoot.thumbUrl.startsWith("https://") || cardRoot.thumbUrl.startsWith("file://"))
                    ? cardRoot.thumbUrl
                    : (cardRoot.thumbUrl !== "" ? ("file://" + cardRoot.thumbUrl) : "")
                sourceSize: Qt.size(280, 180)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: status === Image.Ready ? 1.0 : 0.0
                scale: cardMouse.containsMouse ? 1.04 : 1.0

                Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
            }

            Rectangle {
                anchors.fill: parent
                visible: cardImg.status !== Image.Ready
                color: Theme.surface_container_high

                Text {
                    anchors.centerIn: parent
                    text: cardImg.status === Image.Error ? Theme.iconClose : Theme.iconWallpaper
                    font.family: Theme.fontIcon
                    font.variableAxes: Theme.iconAxes
                    font.pixelSize: Theme.fontSizeLg
                    color: Theme.on_surface_disabled
                }
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
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightMedium
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
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.monoWeightBold
                        color: cardRoot.tagAccent ? Theme.on_primary : Theme.on_surface_variant
                    }
                }

                Rectangle {
                    height: 20
                    width: 20
                    radius: Theme.radiusPill
                    color: cardRoot.isSelected ? Theme.primary : Theme.secondary
                    visible: cardRoot.isSelected || cardRoot.isSavedLocal

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconCheck
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeXs
                        color: cardRoot.isSelected ? Theme.on_primary : Theme.on_secondary
                    }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton && cardRoot.allowDetails) {
                        cardRoot.detailsRequested();
                    } else {
                        cardRoot.applyRequested();
                    }
                }
            }

            RowLayout {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 8
                spacing: 4
                z: 3

                Text {
                    Layout.fillWidth: true
                    text: (cardRoot.titleText !== "" ? cardRoot.titleText : "click to set").toLowerCase()
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightMedium
                    color: Theme.on_surface
                    elide: Text.ElideRight
                }

                // subtle wallhaven palette preview dots
                Row {
                    spacing: 2
                    visible: Array.isArray(cardRoot.colorsPreview) && cardRoot.colorsPreview.length > 0 && !cardMouse.containsMouse

                    Repeater {
                        model: Array.isArray(cardRoot.colorsPreview) ? cardRoot.colorsPreview.slice(0, 4) : []
                        delegate: Rectangle {
                            required property string modelData
                            width: 7
                            height: 7
                            radius: Theme.radiusPill
                            color: modelData
                            border.color: Theme.alpha("#000000", 0.35)
                            border.width: 1
                        }
                    }
                }

                Rectangle {
                    width: 22
                    height: 22
                    radius: Theme.radiusPill
                    color: favMouse.containsMouse || cardRoot.isFavorite ? Theme.alpha(Theme.error, 0.85) : Theme.alpha(Theme.surface, 0.82)
                    border.color: cardRoot.isFavorite ? Theme.error : Theme.widgetBorder
                    border.width: 1
                    visible: cardRoot.allowFavorite && (cardMouse.containsMouse || cardRoot.isFavorite)

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconHeart
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeXs
                        color: favMouse.containsMouse || cardRoot.isFavorite ? Theme.on_primary : Theme.on_surface
                    }

                    MouseArea {
                        id: favMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.favoriteRequested()
                    }

                    CustomTooltip {
                        anchorItem: parent
                        active: favMouse.containsMouse
                        text: cardRoot.isFavorite ? "remove bookmark" : "bookmark wallpaper"
                    }
                }

                Rectangle {
                    width: 22
                    height: 22
                    radius: Theme.radiusPill
                    color: infoMouse.containsMouse ? Theme.primary : Theme.alpha(Theme.surface, 0.82)
                    border.color: Theme.widgetBorder
                    border.width: 1
                    visible: cardRoot.allowDetails && cardMouse.containsMouse

                    Text {
                        anchors.centerIn: parent
                        text: Theme.iconEye
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeXs
                        color: infoMouse.containsMouse ? Theme.on_primary : Theme.on_surface
                    }

                    MouseArea {
                        id: infoMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cardRoot.detailsRequested()
                    }

                    CustomTooltip {
                        anchorItem: parent
                        active: infoMouse.containsMouse
                        text: "details, palette & similar"
                    }
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
                        font.variableAxes: Theme.iconAxes
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

                    CustomTooltip {
                        anchorItem: parent
                        active: dlMouse.containsMouse
                        text: "download to library"
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
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
            color: popup.open || wpMouse.containsMouse ? Theme.primary : Theme.on_surface

            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !Theme.isVertical && Theme.isTextIconSet
            text: "wall"
            font.family: Theme.fontFamily
            font.variableAxes: Theme.sansAxes
            font.pixelSize: Theme.fontSizeXs
            font.weight: Theme.fontWeightMedium
            color: Theme.on_surface
        }
    }

    Rectangle {
        visible: (WallpaperService?.mpvActive ?? false) || (WallpaperService?.awwwPaused ?? false)
        width: 5
        height: 5
        radius: 3
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 4
        color: (WallpaperService?.awwwPaused ?? false) ? Theme.warn : Theme.primary
    }

    HoverFlyoutHandler {
        id: wpHoverHandler
        popup: popup
        mouseArea: wpMouse
        updatePos: () => root.syncAnchor()
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
            wpHoverHandler.handlePillClick();
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
        cardHeight: Math.min(640, (popup.screen?.height ?? 800) - 80)
        targetRelativeX: 0
        targetRelativeY: 0

        content: Item {
            id: wpContentWrap
            anchors.fill: parent

            Keys.onEscapePressed: (ev) => {
                if (root.selectedDetailItem && root.selectedDetailItem.id) {
                    root.selectedDetailItem = null;
                    ev.accepted = true;
                }
            }

            ColumnLayout {
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
                            font.variableAxes: Theme.iconAxes
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                            color: Theme.primary
                        }
                    }

                    ColumnLayout {
                        spacing: 1

                        Text {
                            text: "wallpapers & aesthetics"
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: Theme.fontSizeMd
                            font.weight: Theme.fontWeightBold
                            color: Theme.on_surface
                        }

                        Text {
                            text: {
                                if (root.batchStatusText !== "") return root.batchStatusText;
                                if (root.activeTab === "local") return localView.filteredLocalWps.length + " wallpapers in local gallery";
                                if (root.activeTab === "online") {
                                    if (root.onlineShowSavedOnly) return root.wallhavenFavs.length + " bookmarked wallhaven picks";
                                    return root.onlineWallpapers.length > 0
                                        ? (root.onlineWallpapers.length + " results • page " + root.onlinePage + " / " + root.onlineTotalPages + (root.onlineTotalCount > 0 ? (" (" + root.onlineTotalCount + " total)") : ""))
                                        : "explore wallhaven community gallery";
                                }
                                if (root.activeTab === "live") return root.localLiveWallpapers.length + " local animated & video wallpapers";
                                return "matugen palette, awww transitions & mpvpaper";
                            }
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.weight: Theme.fontWeightRegular
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
                    visible: WallpaperService?.mpvActive ?? false
                    icon: Theme.iconClose
                    label: "stop video"
                    chipHeight: 28
                    inactiveBg: Theme.error_overlay
                    inactiveFg: Theme.error
                    onClicked: if (WallpaperService?.stopLiveWallpaper) WallpaperService.stopLiveWallpaper()
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
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeSm
                                    color: isSelected ? Theme.primary : Theme.on_surface_variant
                                }

                                Text {
                                    text: modelData.label
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: isSelected ? Theme.fontWeightBold : Theme.fontWeightMedium
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
                    let mFilter = root.localMediaFilter;
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
                        let isVid = Boolean(item.isVideo);
                        let isGif = Boolean(item.isGif);
                        let mMatch = mFilter === "all"
                            || (mFilter === "video" && isVid)
                            || (mFilter === "gif" && isGif)
                            || (mFilter === "images" && !isVid && !isGif);
                        let searchMatch = sQuery === "" || nameStr.indexOf(sQuery) !== -1 || catStr.indexOf(sQuery) !== -1;

                        if (pMatch && subMatch && mMatch && searchMatch) result.push(item);
                    }
                    if (root.localSortMode === "name") {
                        result.sort((a, b) => (a.name || "").localeCompare(b.name || ""));
                    } else if (root.localSortMode === "category") {
                        result.sort((a, b) => (a.category || "").localeCompare(b.category || "") || (a.name || "").localeCompare(b.name || ""));
                    }
                    return result;
                }

                // compact active wallpaper summary strip
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    visible: (WallpaperService?.currentWallpaperPath ?? "") !== ""
                    radius: Theme.radiusMd
                    color: Theme.cardBg
                    border.color: Theme.cardBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 28
                            radius: Theme.radiusSm
                            color: Theme.surface_container_high
                            clip: true
                            border.color: Theme.widgetBorder
                            border.width: 1

                            Image {
                                anchors.fill: parent
                                source: {
                                    let p = WallpaperService?.currentWallpaperPath ?? "";
                                    return p ? ("file://" + p) : "";
                                }
                                sourceSize: Qt.size(88, 56)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: root.getBasename(WallpaperService?.currentWallpaperPath ?? "")
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: Theme.on_surface
                                elide: Text.ElideMiddle
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    let parts = [
                                        WallpaperService?.currentMode ?? "dark",
                                        (WallpaperService?.currentSchemeType ?? "scheme-tonal-spot").replace("scheme-", "")
                                    ];
                                    if (WallpaperService?.mpvActive) parts.push("mpvpaper live");
                                    else parts.push((Settings?.awwwTransitionType ?? "wipe") + (WallpaperService?.awwwPaused ? " (paused)" : ""));
                                    return parts.join(" • ");
                                }
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.weight: Theme.monoWeightRegular
                                font.pixelSize: Math.max(9, Theme.fontSizeXs - 1)
                                color: Theme.on_surface_variant
                                elide: Text.ElideRight
                            }
                        }

                        Chip {
                            icon: (WallpaperService?.awwwPaused ?? false) ? Theme.iconPlay : Theme.iconPause
                            label: (WallpaperService?.awwwPaused ?? false) ? "resume" : "pause"
                            chipHeight: 26
                            visible: !(WallpaperService?.mpvActive ?? false)
                            selected: WallpaperService?.awwwPaused ?? false
                            onClicked: if (WallpaperService?.toggleAwwwPause) WallpaperService.toggleAwwwPause()
                        }

                        Chip {
                            icon: Theme.iconRefresh
                            label: "reapply"
                            chipHeight: 26
                            onClicked: if (WallpaperService?.reapplyTheme) WallpaperService.reapplyTheme()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    SearchField {
                        id: localSearchField
                        placeholder: "search local wallpapers by name or folder..."
                        badgeText: localView.filteredLocalWps.length + " matched"
                        onTextChanged: root.localSearchQuery = text.toLowerCase()
                        onCleared: root.localSearchQuery = ""
                    }

                    Repeater {
                        model: [
                            { id: "all", label: "all" },
                            { id: "images", label: "img" },
                            { id: "gif", label: "gif" },
                            { id: "video", label: "vid" }
                        ]
                        delegate: Chip {
                            required property var modelData
                            label: modelData.label
                            chipHeight: 36
                            selected: root.localMediaFilter === modelData.id
                            inactiveBg: Theme.cardBg
                            onClicked: root.localMediaFilter = modelData.id
                        }
                    }

                    Chip {
                        icon: Theme.iconFilter
                        label: root.localSortMode === "name" ? "a-z" : "dir"
                        chipHeight: 36
                        inactiveBg: Theme.cardBg
                        onClicked: root.localSortMode = (root.localSortMode === "name" ? "category" : "name")
                    }

                    Chip {
                        icon: Theme.iconShuffle
                        label: "random"
                        chipHeight: 36
                        inactiveBg: Theme.cardBg
                        onClicked: root.rollRandomWallpaper()
                    }
                }

                Flickable {
                    id: catFlick
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    contentWidth: unifiedCatRow.implicitWidth
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    WheelHandler {
                        onWheel: (wheel) => {
                            let dx = (wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x) * 0.6;
                            let maxX = Math.max(0, catFlick.contentWidth - catFlick.width);
                            catFlick.contentX = Math.max(0, Math.min(maxX, catFlick.contentX - dx));
                            wheel.accepted = true;
                        }
                    }

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
                            font.variableAxes: Theme.iconAxes
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

                // row 1: search query, exact resolution, api key & bookmarks
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    SearchField {
                        id: onlineSearchField
                        text: root.onlineQuery
                        placeholder: "search tags, @user, like:id, or keywords..."
                        onSubmitted: (val) => fetchWallhaven(val, root.onlineSorting, 1, resField.text)
                        onCleared: fetchWallhaven("", root.onlineSorting, 1, resField.text)
                    }

                    SearchField {
                        id: resField
                        Layout.fillWidth: false
                        Layout.preferredWidth: 132
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
                        selected: root.onlineResolution === root.nativeRes && !root.onlineShowSavedOnly
                        inactiveBg: Theme.cardBg
                        onClicked: {
                            resField.text = root.nativeRes;
                            fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, root.nativeRes);
                        }
                    }

                    IconButton {
                        icon: Theme.iconShield
                        iconSize: Theme.fontSizeSm
                        highlighted: root.showApiKeyRow || root.onlineApiKey.trim() !== ""
                        tooltip: root.onlineApiKey.trim() !== "" ? "wallhaven api key configured (click to edit)" : "add wallhaven api key (needed for nsfw)"
                        onClicked: root.showApiKeyRow = !root.showApiKeyRow
                    }

                    Chip {
                        icon: Theme.iconHeart
                        label: "favs (" + root.wallhavenFavs.length + ")"
                        chipHeight: 36
                        selected: root.onlineShowSavedOnly
                        inactiveBg: Theme.cardBg
                        onClicked: {
                            root.onlineShowSavedOnly = !root.onlineShowSavedOnly;
                            if (!root.onlineShowSavedOnly && root.onlineWallpapers.length === 0) {
                                fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                            }
                        }
                    }
                }

                // optional collapsible api key strip (persisted in wallhaven.conf)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    visible: root.showApiKeyRow
                    radius: Theme.radiusMd
                    color: Theme.cardBg
                    border.color: Theme.cardBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 6

                        Text {
                            text: "api key"
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.monoWeightBold
                            color: Theme.primary
                            Layout.leftMargin: 4
                        }

                        SearchField {
                            id: apiKeyField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            icon: Theme.iconShield
                            text: root.onlineApiKey
                            placeholder: "paste personal wallhaven api key (wallhaven.cc/settings/account)..."
                            monoFont: true
                            onSubmitted: (val) => {
                                root.onlineApiKey = val.trim();
                                root.saveWallhavenConf();
                                root.showApiKeyRow = false;
                                if (root.activeTab === "online") fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                            }
                        }

                        Chip {
                            label: "save"
                            chipHeight: 28
                            selected: true
                            onClicked: {
                                root.onlineApiKey = apiKeyField.text.trim();
                                root.saveWallhavenConf();
                                root.showApiKeyRow = false;
                                fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                            }
                        }

                        Chip {
                            label: "clear"
                            chipHeight: 28
                            onClicked: {
                                apiKeyField.text = "";
                                root.onlineApiKey = "";
                                if (root.onlinePurity === "111" || root.onlinePurity === "001" || root.onlinePurity === "101") {
                                    root.onlinePurity = "100";
                                    purityDropdown.currentValue = "100";
                                }
                                root.saveWallhavenConf();
                                root.showApiKeyRow = false;
                            }
                        }
                    }
                }

                // row 2: floating Dropdown filters (sorting, order, range, category, purity, ratio, min res, color) + pager
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Dropdown {
                        id: sortDropdown
                        Layout.preferredWidth: 102
                        menuMinWidth: 165
                        icon: Theme.iconFilter
                        currentValue: root.onlineSorting
                        model: [
                            { label: "latest", value: "date_added" },
                            { label: "relevance", value: "relevance" },
                            { label: "toplist", value: "toplist" },
                            { label: "hot", value: "hot" },
                            { label: "views", value: "views" },
                            { label: "favorites", value: "favorites" },
                            { label: "random", value: "random" }
                        ]
                        onSelected: (val) => {
                            if (val !== root.onlineSorting || root.onlineShowSavedOnly) {
                                fetchWallhaven(onlineSearchField.text, val, 1, resField.text);
                            }
                        }
                    }

                    IconButton {
                        icon: root.onlineOrder === "asc" ? Theme.iconChevronUp : Theme.iconChevronDown
                        iconSize: Theme.fontSizeSm
                        tooltip: "order: " + (root.onlineOrder === "asc" ? "ascending" : "descending")
                        onClicked: {
                            root.onlineOrder = root.onlineOrder === "desc" ? "asc" : "desc";
                            fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                        }
                    }

                    Dropdown {
                        id: topRangeDropdown
                        visible: root.onlineSorting === "toplist"
                        Layout.preferredWidth: 74
                        menuMinWidth: 128
                        currentValue: root.onlineTopRange
                        model: [
                            { label: "24h", value: "1d" },
                            { label: "3 days", value: "3d" },
                            { label: "1 week", value: "1w" },
                            { label: "1 month", value: "1M" },
                            { label: "3 mo", value: "3M" },
                            { label: "6 mo", value: "6M" },
                            { label: "1 year", value: "1y" }
                        ]
                        onSelected: (val) => {
                            root.onlineTopRange = val;
                            fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                        }
                    }

                    Dropdown {
                        id: catDropdown
                        Layout.preferredWidth: 88
                        menuMinWidth: 155
                        currentValue: root.onlineCategories
                        model: [
                            { label: "all cats", value: "111" },
                            { label: "general", value: "100" },
                            { label: "anime", value: "010" },
                            { label: "people", value: "001" },
                            { label: "gen+ani", value: "110" }
                        ]
                        onSelected: (val) => {
                            root.onlineCategories = val;
                            fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                        }
                    }

                    Dropdown {
                        id: purityDropdown
                        Layout.preferredWidth: 86
                        menuMinWidth: 155
                        accentColor: (root.onlinePurity === "111" || root.onlinePurity === "001") ? Theme.error : Theme.primary
                        currentValue: root.onlinePurity
                        model: [
                            { label: "sfw", value: "100" },
                            { label: "sketchy", value: "010" },
                            { label: "sfw+skt", value: "110" },
                            { label: "all+nsfw", value: "111", badge: root.onlineApiKey.trim() === "" ? "key" : "" }
                        ]
                        onSelected: (val) => {
                            root.onlinePurity = val;
                            if ((val === "111" || val === "001") && root.onlineApiKey.trim() === "") {
                                root.showApiKeyRow = true;
                            }
                            fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                        }
                    }

                    Dropdown {
                        id: ratioDropdown
                        Layout.preferredWidth: 86
                        menuMinWidth: 145
                        currentValue: root.onlineRatios
                        model: [
                            { label: "ratio: any", value: "" },
                            { label: "16:9", value: "16x9" },
                            { label: "16:10", value: "16x10" },
                            { label: "21:9", value: "21x9" },
                            { label: "32:9", value: "32x9" },
                            { label: "landscape", value: "landscape" },
                            { label: "portrait", value: "portrait" }
                        ]
                        onSelected: (val) => {
                            root.onlineRatios = val;
                            fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                        }
                    }

                    Dropdown {
                        id: atleastDropdown
                        Layout.preferredWidth: 88
                        menuMinWidth: 150
                        currentValue: root.onlineAtleast
                        model: [
                            { label: "min: any", value: "" },
                            { label: "native", value: root.nativeRes },
                            { label: "1080p+", value: "1920x1080" },
                            { label: "1440p+", value: "2560x1440" },
                            { label: "4k+", value: "3840x2160" }
                        ]
                        onSelected: (val) => {
                            root.onlineAtleast = val;
                            if (val !== "" && resField.text === root.nativeRes) resField.text = "";
                            fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                        }
                    }

                    Dropdown {
                        id: colorDropdown
                        Layout.preferredWidth: 92
                        menuMinWidth: 170
                        currentValue: root.onlineColor
                        model: [
                            { label: "color", value: "" },
                            { label: "crimson", value: "cc0000", swatch: "#cc0000" },
                            { label: "rose", value: "ea4c88", swatch: "#ea4c88" },
                            { label: "purple", value: "663399", swatch: "#663399" },
                            { label: "blue", value: "0066cc", swatch: "#0066cc" },
                            { label: "cyan", value: "66cccc", swatch: "#66cccc" },
                            { label: "green", value: "77cc33", swatch: "#77cc33" },
                            { label: "gold", value: "ffcc33", swatch: "#ffcc33" },
                            { label: "orange", value: "ff6600", swatch: "#ff6600" },
                            { label: "espresso", value: "663300", swatch: "#663300" },
                            { label: "black", value: "000000", swatch: "#000000" },
                            { label: "slate", value: "666666", swatch: "#666666" },
                            { label: "white", value: "ffffff", swatch: "#ffffff" }
                        ]
                        onSelected: (val) => {
                            root.onlineColor = val;
                            fetchWallhaven(onlineSearchField.text, root.onlineSorting, 1, resField.text);
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Chip {
                        icon: Theme.iconChevronLeft
                        chipHeight: 28
                        visible: !root.onlineShowSavedOnly
                        opacity: root.onlinePage > 1 ? 1.0 : 0.4
                        onClicked: {
                            if (root.onlinePage > 1 && !root.isOnlineLoading) {
                                fetchWallhaven(onlineSearchField.text, root.onlineSorting, root.onlinePage - 1, resField.text);
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: pageText.implicitWidth + 14
                        visible: !root.onlineShowSavedOnly
                        radius: Theme.radiusPill
                        color: Theme.widgetBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        Text {
                            id: pageText
                            anchors.centerIn: parent
                            text: root.onlinePage + "/" + root.onlineTotalPages
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Theme.monoWeightBold
                            color: Theme.primary
                        }
                    }

                    Chip {
                        icon: Theme.iconChevronRight
                        chipHeight: 28
                        visible: !root.onlineShowSavedOnly
                        opacity: root.onlinePage < root.onlineTotalPages ? 1.0 : 0.4
                        onClicked: {
                            if (!root.isOnlineLoading && root.onlinePage < root.onlineTotalPages) {
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
                    model: root.displayedOnlineWallpapers
                    visible: !root.isOnlineLoading && root.displayedOnlineWallpapers.length > 0

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
                        isSavedLocal: root.hasLocalWallpaper(modelData?.fullUrl || modelData?.id)
                        allowDownload: true
                        allowDetails: true
                        allowFavorite: true
                        isFavorite: root.isFavWallhaven(modelData?.id)
                        colorsPreview: Array.isArray(modelData?.colors) ? modelData.colors : []
                        onApplyRequested: if (WallpaperService?.setWallpaper) WallpaperService.setWallpaper(modelData.fullUrl)
                        onDownloadRequested: root.downloadUrls([modelData.fullUrl])
                        onDetailsRequested: root.openWallpaperDetails(modelData)
                        onFavoriteRequested: root.toggleFavWallhaven(modelData)
                    }
                }

                EmptyState {
                    visible: root.isOnlineLoading || root.displayedOnlineWallpapers.length === 0
                    loading: root.isOnlineLoading
                    icon: root.onlineErrorText !== "" ? Theme.iconClose : (root.onlineShowSavedOnly ? Theme.iconHeart : Theme.iconGlobe)
                    message: {
                        if (root.isOnlineLoading) {
                            return "fetching " + (root.onlineSorting === "date_added" ? "latest" : root.onlineSorting)
                                + (root.onlineResolution ? (" " + root.onlineResolution) : "") + " wallpapers...";
                        }
                        if (root.onlineErrorText !== "") return root.onlineErrorText;
                        if (root.onlineShowSavedOnly) return "no bookmarked wallhaven picks yet\nhover any card and click the heart icon to save it here";
                        return "no wallpapers found\ntry clearing exact resolution or adjusting filters";
                    }
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

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Chip {
                        icon: Theme.iconClose
                        label: (WallpaperService?.mpvActive ?? false) ? "stop active video" : "stop video"
                        chipHeight: 28
                        selected: WallpaperService?.mpvActive ?? false
                        activeBg: Theme.error_overlay
                        activeFg: Theme.error
                        onClicked: if (WallpaperService?.stopLiveWallpaper) WallpaperService.stopLiveWallpaper()
                    }

                    Chip {
                        icon: (WallpaperService?.awwwPaused ?? false) ? Theme.iconPlay : Theme.iconPause
                        label: (WallpaperService?.awwwPaused ?? false) ? "resume gif engine" : "pause gif engine"
                        chipHeight: 28
                        selected: WallpaperService?.awwwPaused ?? false
                        onClicked: if (WallpaperService?.toggleAwwwPause) WallpaperService.toggleAwwwPause()
                    }

                    Chip {
                        icon: Theme.iconTrash
                        label: "clear awww cache"
                        chipHeight: 28
                        onClicked: if (WallpaperService?.clearAwwwCache) WallpaperService.clearAwwwCache()
                    }

                    Item { Layout.fillWidth: true }
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

                                Connections {
                                    target: Theme
                                    function onPaletteColorsChanged() {
                                        if (Theme.source_color && !hexField.activeFocus) {
                                            hexField.text = String(Theme.source_color);
                                        }
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

                        GroupLabel { text: "active matugen palette (click to copy hex)" }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 4
                            columnSpacing: 6
                            rowSpacing: 6

                            Repeater {
                                model: [
                                    { name: "primary", col: String(Theme.primary), fg: Theme.on_primary },
                                    { name: "secondary", col: String(Theme.secondary), fg: Theme.on_secondary },
                                    { name: "tertiary", col: String(Theme.tertiary), fg: Theme.on_surface },
                                    { name: "source", col: String(Theme.source_color || Theme.primary), fg: Theme.on_primary },
                                    { name: "surface", col: String(Theme.surface), fg: Theme.on_surface },
                                    { name: "container", col: String(Theme.surface_container_high), fg: Theme.on_surface },
                                    { name: "outline", col: String(Theme.outline), fg: Theme.background },
                                    { name: "error", col: String(Theme.error), fg: Theme.on_primary }
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: Theme.radiusSm
                                    color: swatchMa.containsMouse ? Theme.widgetHover : Theme.widgetBg
                                    border.color: swatchMa.containsMouse ? modelData.col : Theme.widgetBorder
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 5
                                        spacing: 6

                                        Rectangle {
                                            width: 16
                                            height: 16
                                            radius: Theme.radiusPill
                                            color: modelData.col
                                            border.color: Theme.alpha(Theme.on_surface, 0.25)
                                            border.width: 1
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            font.family: Theme.fontFamily
                                            font.variableAxes: Theme.sansAxes
                                            font.weight: Theme.fontWeightRegular
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.on_surface
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            text: String(modelData.col).toLowerCase()
                                            font.family: Theme.fontMono
                                            font.variableAxes: Theme.monoAxes
                                            font.weight: Theme.monoWeightRegular
                                            font.pixelSize: Theme.fontSizeXs - 1
                                            color: Theme.on_surface_variant
                                        }
                                    }

                                    MouseArea {
                                        id: swatchMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.copyColorHex(modelData.col)
                                    }

                                    CustomTooltip {
                                        anchorItem: parent
                                        active: swatchMa.containsMouse
                                        text: modelData.name + ": " + String(modelData.col).toLowerCase()
                                        subtext: "click to copy hex"
                                    }
                                }
                            }
                        }
                    }

                    SettingCard {
                        title: "awww transition & scaling engine"
                        icon: Theme.iconFlame
                        badge: (Settings?.awwwTransitionType ?? "wipe") + " • " + (Settings?.awwwTransitionDuration ?? 3) + "s • " + (Settings?.awwwTransitionFps ?? 60) + " fps"
                        actionLabel: "preview effect"
                        actionIcon: Theme.iconPlay
                        onActionClicked: if (WallpaperService?.reapplyTheme) WallpaperService.reapplyTheme()

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
                                                root.saveAwwSetting(() => Settings.awwwResize = modelData.val);
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
                                        model: ["Lanczos3", "Mitchell", "CatmullRom", "Bilinear", "Nearest"]

                                        delegate: Chip {
                                            required property string modelData
                                            label: modelData.toLowerCase()
                                            selected: (Settings?.awwwFilter ?? "Lanczos3") === modelData
                                            fillWidth: true
                                            chipHeight: 26
                                            onClicked: root.saveAwwSetting(() => Settings.awwwFilter = modelData)
                                        }
                                    }
                                }
                            }
                        }

                        // --crop-gravity (awww 0.12.1 requires --resize crop)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: (Settings?.awwwResize ?? "crop") === "crop"

                            GroupLabel { text: "crop gravity anchor" }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                rowSpacing: 5
                                columnSpacing: 6

                                Repeater {
                                    model: [
                                        "top-left", "top", "top-right",
                                        "left", "center", "right",
                                        "bottom-left", "bottom", "bottom-right"
                                    ]

                                    delegate: Chip {
                                        required property string modelData
                                        label: modelData
                                        selected: (Settings?.awwwCropGravity ?? "center") === modelData
                                        fillWidth: true
                                        chipHeight: 24
                                        onClicked: {
                                            root.saveAwwSetting(() => Settings.awwwCropGravity = modelData);
                                            if (WallpaperService?.reapplyTheme) WallpaperService.reapplyTheme();
                                        }
                                    }
                                }
                            }
                        }

                        // --fill-color (for fit / center padding)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: {
                                let r = Settings?.awwwResize ?? "crop";
                                return r === "fit" || r === "no";
                            }

                            GroupLabel { text: "padding fill color" }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: [
                                        { label: "auto (theme bg)", val: "auto" },
                                        { label: "pitch black", val: "000000" },
                                        { label: "dark slate", val: "181a20" },
                                        { label: "white", val: "ffffff" }
                                    ]

                                    delegate: Chip {
                                        required property var modelData
                                        label: modelData.label
                                        selected: (Settings?.awwwFillColor ?? "auto").toLowerCase() === modelData.val
                                        fillWidth: true
                                        chipHeight: 26
                                        onClicked: {
                                            root.saveAwwSetting(() => Settings.awwwFillColor = modelData.val);
                                            if (WallpaperService?.reapplyTheme) WallpaperService.reapplyTheme();
                                        }
                                    }
                                }

                                SearchField {
                                    id: fillHexField
                                    Layout.fillWidth: false
                                    Layout.preferredWidth: 115
                                    Layout.preferredHeight: 26
                                    icon: Theme.iconPalette
                                    text: Settings?.awwwFillColor ?? "auto"
                                    placeholder: "rrggbb"
                                    monoFont: true
                                    onSubmitted: (val) => {
                                        let v = val.trim().replace(/^#/, "");
                                        if (v !== "") {
                                            root.saveAwwSetting(() => Settings.awwwFillColor = v);
                                            if (WallpaperService?.reapplyTheme) WallpaperService.reapplyTheme();
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
                                model: ["wipe", "wave", "fade", "simple", "grow", "outer", "center", "any", "random", "left", "right", "top", "bottom", "none"]

                                delegate: Chip {
                                    required property string modelData
                                    label: modelData
                                    selected: (Settings?.awwwTransitionType ?? "wipe") === modelData
                                    fillWidth: true
                                    chipHeight: 26
                                    onClicked: root.saveAwwSetting(() => Settings.awwwTransitionType = modelData)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: {
                                    let t = Settings?.awwwTransitionType ?? "wipe";
                                    return t !== "simple" && t !== "none";
                                }

                                GroupLabel { text: "duration (seconds)" }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Repeater {
                                        model: [
                                            { label: "0.4s", val: 0.4 },
                                            { label: "0.8s", val: 0.8 },
                                            { label: "1.2s", val: 1.2 },
                                            { label: "2s", val: 2.0 },
                                            { label: "3s", val: 3.0 },
                                            { label: "5s", val: 5.0 }
                                        ]

                                        delegate: Chip {
                                            required property var modelData
                                            label: modelData.label
                                            selected: Math.abs((Settings?.awwwTransitionDuration ?? 3) - modelData.val) < 0.05
                                            fillWidth: true
                                            chipHeight: 26
                                            onClicked: root.saveAwwSetting(() => Settings.awwwTransitionDuration = modelData.val)
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: (Settings?.awwwTransitionType ?? "wipe") !== "none"

                                GroupLabel { text: "blend step" }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 5

                                    Repeater {
                                        model: [
                                            { label: "silk", val: 25 },
                                            { label: "smooth", val: 60 },
                                            { label: "90", val: 90 },
                                            { label: "fast", val: 150 },
                                            { label: "instant", val: 255 }
                                        ]

                                        delegate: Chip {
                                            required property var modelData
                                            label: modelData.label
                                            selected: (Settings?.awwwTransitionStep ?? 90) === modelData.val
                                            fillWidth: true
                                            chipHeight: 26
                                            onClicked: root.saveAwwSetting(() => Settings.awwwTransitionStep = modelData.val)
                                        }
                                    }
                                }
                            }
                        }

                        // --transition-bezier
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: {
                                let t = Settings?.awwwTransitionType ?? "wipe";
                                return t !== "simple" && t !== "none";
                            }

                            GroupLabel { text: "easing bezier curve" }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: [
                                        { label: "default", val: ".54,0,.34,.99" },
                                        { label: "linear", val: "0,0,1,1" },
                                        { label: "smooth out", val: "0.22,1,0.36,1" },
                                        { label: "material", val: "0.4,0,0.2,1" },
                                        { label: "snappy", val: "0.16,1,0.3,1" },
                                        { label: "overshoot", val: "0.34,1.56,0.64,1" }
                                    ]

                                    delegate: Chip {
                                        required property var modelData
                                        label: modelData.label
                                        selected: (Settings?.awwwTransitionBezier ?? ".54,0,.34,.99") === modelData.val
                                        fillWidth: true
                                        chipHeight: 26
                                        onClicked: root.saveAwwSetting(() => Settings.awwwTransitionBezier = modelData.val)
                                    }
                                }

                                SearchField {
                                    id: bezierField
                                    Layout.fillWidth: false
                                    Layout.preferredWidth: 132
                                    Layout.preferredHeight: 26
                                    icon: Theme.iconSliders
                                    text: Settings?.awwwTransitionBezier ?? ".54,0,.34,.99"
                                    placeholder: "x1,y1,x2,y2"
                                    monoFont: true
                                    onSubmitted: (val) => {
                                        let v = val.trim().replace(/\s+/g, "");
                                        if (v !== "") root.saveAwwSetting(() => Settings.awwwTransitionBezier = v);
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: {
                                let t = Settings?.awwwTransitionType ?? "wipe";
                                return t === "wipe" || t === "wave";
                            }

                            GroupLabel {
                                text: "angle:"
                                Layout.rightMargin: 4
                            }

                            Repeater {
                                model: [
                                    { label: "0°", val: 0 },
                                    { label: "30°", val: 30 },
                                    { label: "45°", val: 45 },
                                    { label: "90°", val: 90 },
                                    { label: "135°", val: 135 },
                                    { label: "180°", val: 180 },
                                    { label: "270°", val: 270 }
                                ]

                                delegate: Chip {
                                    required property var modelData
                                    label: modelData.label
                                    selected: (Settings?.awwwTransitionAngle ?? 30) === modelData.val
                                    fillWidth: true
                                    chipHeight: 26
                                    onClicked: root.saveAwwSetting(() => Settings.awwwTransitionAngle = modelData.val)
                                }
                            }
                        }

                        // --transition-wave
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: (Settings?.awwwTransitionType ?? "wipe") === "wave"

                            GroupLabel { text: "wave geometry (width, height)" }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Repeater {
                                    model: [
                                        { label: "fine (10x10)", val: "10,10" },
                                        { label: "classic (20x20)", val: "20,20" },
                                        { label: "broad (40x20)", val: "40,20" },
                                        { label: "swell (65x35)", val: "65,35" },
                                        { label: "tall (20x55)", val: "20,55" }
                                    ]

                                    delegate: Chip {
                                        required property var modelData
                                        label: modelData.label
                                        selected: (Settings?.awwwTransitionWave ?? "20,20") === modelData.val
                                        fillWidth: true
                                        chipHeight: 26
                                        onClicked: root.saveAwwSetting(() => Settings.awwwTransitionWave = modelData.val)
                                    }
                                }

                                SearchField {
                                    id: waveField
                                    Layout.fillWidth: false
                                    Layout.preferredWidth: 88
                                    Layout.preferredHeight: 26
                                    icon: Theme.iconSliders
                                    text: Settings?.awwwTransitionWave ?? "20,20"
                                    placeholder: "20,20"
                                    monoFont: true
                                    onSubmitted: (val) => {
                                        let v = val.trim().replace(/\s+/g, "");
                                        if (/^\d+,\d+$/.test(v)) root.saveAwwSetting(() => Settings.awwwTransitionWave = v);
                                    }
                                }
                            }
                        }

                        // --transition-pos + --invert-y
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            visible: {
                                let t = Settings?.awwwTransitionType ?? "wipe";
                                return t === "grow" || t === "outer";
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                GroupLabel { text: "circle origin point" }
                                Item { Layout.fillWidth: true }
                                Chip {
                                    icon: Theme.iconRefresh
                                    label: "invert y axis"
                                    selected: Settings?.awwwInvertY ?? false
                                    chipHeight: 24
                                    onClicked: root.saveAwwSetting(() => Settings.awwwInvertY = !(Settings.awwwInvertY ?? false))
                                }
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                rowSpacing: 5
                                columnSpacing: 6

                                Repeater {
                                    model: [
                                        "top-left", "top", "top-right",
                                        "left", "center", "right",
                                        "bottom-left", "bottom", "bottom-right"
                                    ]

                                    delegate: Chip {
                                        required property string modelData
                                        label: modelData
                                        selected: (Settings?.awwwTransitionPos ?? "center") === modelData
                                        fillWidth: true
                                        chipHeight: 24
                                        onClicked: root.saveAwwSetting(() => Settings.awwwTransitionPos = modelData)
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
                                    onClicked: root.saveAwwSetting(() => Settings.awwwTransitionFps = modelData.val)
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

        // wallhaven wallpaper details, palette & similar search overlay
        Rectangle {
            id: detailsOverlay
            anchors.fill: parent
            z: 60
            visible: root.selectedDetailItem !== null && Boolean(root.selectedDetailItem?.id)
            radius: Theme.radiusMd
            color: Theme.alpha(Theme.background, 0.86)

            MouseArea {
                anchors.fill: parent
                onClicked: root.selectedDetailItem = null
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 28, 610)
                height: Math.min(parent.height - 28, 495)
                radius: Theme.radiusLg
                color: Theme.surface
                border.color: Theme.primary
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    // catch clicks inside card so scrim doesn't dismiss
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.radiusPill
                            color: Theme.primary_overlay

                            Text {
                                anchors.centerIn: parent
                                text: Theme.iconGlobe
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeSm
                                color: Theme.primary
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: "wallhaven #" + (root.selectedDetailItem?.id ?? "")
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: Theme.fontSizeMd
                                font.weight: Theme.monoWeightBold
                                color: Theme.on_surface
                            }

                            Text {
                                text: {
                                    if (root.detailMeta?.loading) return "fetching full metadata, palette & tags...";
                                    if (root.detailMeta?.error) return root.detailMeta.error;
                                    let parts = [];
                                    if (root.selectedDetailItem?.resolution) parts.push(root.selectedDetailItem.resolution);
                                    if (root.detailMeta?.fileSize) parts.push(root.detailMeta.fileSize);
                                    if (root.detailMeta?.category) parts.push(root.detailMeta.category);
                                    if (root.detailMeta?.purity) parts.push(root.detailMeta.purity);
                                    if (root.detailMeta?.uploader) parts.push("by @" + root.detailMeta.uploader);
                                    return parts.join(" • ");
                                }
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: root.detailMeta?.error ? Theme.error : Theme.on_surface_variant
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        IconButton {
                            icon: Theme.iconHeart
                            iconSize: Theme.fontSizeSm
                            highlighted: root.isFavWallhaven(root.selectedDetailItem?.id)
                            tooltip: root.isFavWallhaven(root.selectedDetailItem?.id) ? "remove bookmark" : "bookmark pick"
                            onClicked: root.toggleFavWallhaven(root.selectedDetailItem)
                        }

                        IconButton {
                            icon: Theme.iconClose
                            iconSize: Theme.fontSizeSm
                            tooltip: "close details"
                            onClicked: root.selectedDetailItem = null
                        }
                    }

                    // hero preview image + overlay stats
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 205
                        radius: Theme.radiusMd
                        color: Theme.surface_container_high
                        border.color: Theme.cardBorder
                        border.width: 1
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.selectedDetailItem?.thumbUrl || root.selectedDetailItem?.fullUrl || ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }

                        Row {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.margins: 8
                            spacing: 6
                            visible: root.detailMeta?.loaded ?? false

                            Rectangle {
                                height: 22
                                width: viewsLbl.implicitWidth + 14
                                radius: Theme.radiusPill
                                color: Theme.alpha(Theme.surface, 0.85)
                                border.color: Theme.widgetBorder
                                border.width: 1

                                Text {
                                    id: viewsLbl
                                    anchors.centerIn: parent
                                    text: (root.detailMeta?.views ?? 0) + " views"
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.weight: Theme.monoWeightRegular
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_surface
                                }
                            }

                            Rectangle {
                                height: 22
                                width: favsLbl.implicitWidth + 14
                                radius: Theme.radiusPill
                                color: Theme.alpha(Theme.surface, 0.85)
                                border.color: Theme.widgetBorder
                                border.width: 1

                                Text {
                                    id: favsLbl
                                    anchors.centerIn: parent
                                    text: (root.detailMeta?.favorites ?? 0) + " likes"
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.weight: Theme.monoWeightRegular
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_surface
                                }
                            }
                        }
                    }

                    // extracted wallhaven palette (click copies hex, seed chip sets matugen seed)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: Array.isArray(root.detailMeta?.colors) && root.detailMeta.colors.length > 0

                        Text {
                            text: "palette:"
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.weight: Theme.monoWeightRegular
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface_variant
                        }

                        Repeater {
                            model: Array.isArray(root.detailMeta?.colors) ? root.detailMeta.colors : []
                            delegate: Rectangle {
                                required property string modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                radius: Theme.radiusSm
                                color: modelData
                                border.color: detColMa.containsMouse ? Theme.on_surface : Theme.alpha("#000000", 0.35)
                                border.width: detColMa.containsMouse ? 2 : 1

                                MouseArea {
                                    id: detColMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (m) => {
                                        if (m.button === Qt.RightButton) {
                                            if (WallpaperService?.applyColor) WallpaperService.applyColor(modelData);
                                            root.batchStatusText = "matugen seed set to " + modelData;
                                            batchStatusResetTimer.restart();
                                        } else {
                                            root.copyColorHex(modelData);
                                        }
                                    }
                                }

                                CustomTooltip {
                                    anchorItem: parent
                                    active: detColMa.containsMouse
                                    text: modelData
                                    subtext: "left-click copy • right-click matugen seed"
                                }
                            }
                        }
                    }

                    // clickable tags
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: tagsFlow.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        Flow {
                            id: tagsFlow
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: Array.isArray(root.detailMeta?.tags) ? root.detailMeta.tags : []
                                delegate: Chip {
                                    required property string modelData
                                    label: "#" + modelData
                                    chipHeight: 26
                                    inactiveBg: Theme.widgetBg
                                    onClicked: {
                                        onlineSearchField.text = modelData;
                                        root.selectedDetailItem = null;
                                        root.fetchWallhaven(modelData, "relevance", 1, resField.text);
                                    }
                                }
                            }

                            Text {
                                visible: !root.detailMeta?.loading && (!root.detailMeta?.tags || root.detailMeta.tags.length === 0)
                                text: "no public tags returned for this wallpaper"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.on_surface_variant
                            }
                        }
                    }

                    // bottom action bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Chip {
                            icon: Theme.iconSearch
                            label: "find similar (like:" + (root.selectedDetailItem?.id ?? "") + ")"
                            chipHeight: 34
                            inactiveBg: Theme.widgetBg
                            onClicked: {
                                let simQuery = "like:" + root.selectedDetailItem.id;
                                onlineSearchField.text = simQuery;
                                resField.text = "";
                                root.selectedDetailItem = null;
                                root.fetchWallhaven(simQuery, "relevance", 1, "");
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Chip {
                            icon: Theme.iconDownload
                            label: root.hasLocalWallpaper(root.selectedDetailItem?.fullUrl || root.selectedDetailItem?.id) ? "saved" : "save local"
                            chipHeight: 34
                            inactiveBg: Theme.widgetBg
                            onClicked: {
                                if (root.selectedDetailItem?.fullUrl) root.downloadUrls([root.selectedDetailItem.fullUrl]);
                            }
                        }

                        Chip {
                            icon: Theme.iconCheck
                            label: "apply wallpaper"
                            chipHeight: 34
                            selected: true
                            onClicked: {
                                if (root.selectedDetailItem?.fullUrl && WallpaperService?.setWallpaper) {
                                    WallpaperService.setWallpaper(root.selectedDetailItem.fullUrl);
                                    root.selectedDetailItem = null;
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
