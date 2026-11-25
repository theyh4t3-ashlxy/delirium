import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../theme/confFormat.mjs" as ConfFmt
import Quickshell
import Quickshell.Io

BarPill {
    id: root

    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || ((Quickshell.env("HOME") || "") + "/.local/share")) + "/quickshell"
    readonly property string pinsFilePath: dataDir + "/clip_pins.conf"
    readonly property string scriptPath: Qt.resolvedUrl("../scripts/clipboard.py").toString().replace(/^file:\/\//, "")

    property var clipEntries: []
    property var pinEntries: []
    property string searchFilter: ""
    property string activeFilter: "all" // "all" | "text" | "images" | "links" | "pinned"
    property int selectedIndex: 0
    property bool copiedFeedback: false

    active: popup.open
    hovered: clipMouse.containsMouse
    pressed: clipMouse.pressed
    implicitWidth: Theme.isVertical ? pillSize : (clipRow.implicitWidth + 20)

    readonly property var visibleEntries: {
        let q = root.searchFilter.trim().toLowerCase();
        let f = root.activeFilter;
        let out = [];

        function matchItem(item, isPinned) {
            if (f === "pinned" && !isPinned) return false;
            if (f === "text" && item.kind !== "text") return false;
            if (f === "images" && item.kind !== "image") return false;
            if (f === "links" && item.kind !== "link") return false;
            if (q !== "") {
                let hay = (item.preview + " " + item.meta + " " + (item.text || "")).toLowerCase();
                if (!hay.includes(q)) return false;
            }
            return true;
        }

        for (let i = 0; i < root.pinEntries.length; i++) {
            let p = root.pinEntries[i];
            if (matchItem(p, true)) {
                out.push({
                    uid: "pin:" + p.id,
                    id: p.id,
                    kind: p.kind || "text",
                    preview: p.preview || p.text || "",
                    meta: p.meta || "",
                    thumb: p.thumb || "",
                    text: p.text || "",
                    pinned: true
                });
            }
        }
        if (f !== "pinned") {
            for (let i = 0; i < root.clipEntries.length; i++) {
                let c = root.clipEntries[i];
                if (matchItem(c, false)) {
                    out.push({
                        uid: "clip:" + c.id,
                        id: c.id,
                        kind: c.kind || "text",
                        preview: c.preview || "",
                        meta: c.meta || "",
                        thumb: c.thumb || "",
                        text: "",
                        pinned: false
                    });
                }
            }
        }
        return out;
    }

    onVisibleEntriesChanged: {
        if (root.visibleEntries.length === 0) {
            root.selectedIndex = 0;
        } else if (root.selectedIndex >= root.visibleEntries.length) {
            root.selectedIndex = root.visibleEntries.length - 1;
        }
    }

    function applyClipList(raw) {
        let recs = ConfFmt.parseRecords(raw || "", "clip");
        root.clipEntries = Array.isArray(recs) ? recs : [];
    }

    function applyPins(raw) {
        let recs = ConfFmt.parseRecords(raw || "", "pin");
        root.pinEntries = Array.isArray(recs) ? recs : [];
    }

    function refreshHistory() {
        pinsFile.reload();
        listProc.running = false;
        listProc.running = true;
    }

    function runClipAction(args, closeAfter) {
        actionProc.command = ["python3", root.scriptPath].concat(args);
        actionProc.running = false;
        actionProc.running = true;
        if (closeAfter) {
            popup.pinned = false;
            popup.open = false;
        }
    }

    function copyEntry(entry, keepOpen) {
        if (!entry) return;
        let args = entry.pinned ? ["copy-pin", entry.id] : ["copy", entry.id];
        Quickshell.execDetached(["python3", root.scriptPath].concat(args));
        root.copiedFeedback = true;
        copiedTimer.restart();
        if (!keepOpen) {
            popup.pinned = false;
            popup.open = false;
        }
    }

    function togglePinEntry(entry) {
        if (!entry) return;
        if (entry.pinned) runClipAction(["unpin", entry.id], false);
        else runClipAction(["pin", entry.id], false);
    }

    function removeEntry(entry) {
        if (!entry) return;
        if (entry.pinned) runClipAction(["unpin", entry.id], false);
        else runClipAction(["delete", entry.id], false);
    }

    Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: root.copiedFeedback = false
    }

    Process {
        id: ensureWatchProc
        command: ["python3", root.scriptPath, "ensure-watch"]
    }

    Process {
        id: listProc
        command: ["python3", root.scriptPath, "list", "80"]
        stdout: StdioCollector {
            onStreamFinished: root.applyClipList(text)
        }
    }

    Process {
        id: actionProc
        onExited: root.refreshHistory()
    }

    FileView {
        id: pinsFile
        path: root.pinsFilePath
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            root.applyPins(text());
        }
        onLoaded: root.applyPins(text())
    }

    Component.onCompleted: {
        ensureWatchProc.running = true;
        pinsFile.reload();
    }

    Row {
        id: clipRow
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.iconClipboard
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.fontSizeMd
            color: (popup.open || root.copiedFeedback) ? Theme.primary : Theme.on_surface
            Behavior on color { ColorAnimation { duration: Theme.animFast } }
        }

        Text {
            visible: !Theme.isVertical && root.pinEntries.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: String(root.pinEntries.length)
            font.family: Theme.fontMono
            font.variableAxes: Theme.monoAxes
            font.pixelSize: 10
            font.weight: Theme.monoWeightBold
            color: popup.open ? Theme.primary : Theme.on_surface_variant
        }
    }

    HoverFlyoutHandler {
        popup: popup
        mouseArea: clipMouse
        updatePos: () => {
            root.anchorToPopup(popup);
            root.refreshHistory();
            root.searchFilter = "";
            root.selectedIndex = 0;
        }
    }

    MouseArea {
        id: clipMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            root.anchorToPopup(popup);
            if (mouse.button === Qt.RightButton) {
                if (root.visibleEntries.length > 0) root.copyEntry(root.visibleEntries[0], true);
                return;
            }
            if (!popup.open) {
                popup.pinned = true;
                popup.open = true;
            } else if (!popup.pinned) {
                popup.pinned = true;
            } else {
                popup.pinned = false;
                popup.open = false;
            }
            if (popup.open) {
                root.refreshHistory();
                root.searchFilter = "";
                root.selectedIndex = 0;
                clipInput.text = "";
                clipInput.forceActiveFocus();
            }
        }
    }

    Connections {
        target: Settings
        function onRequestClipboardToggle() {
            root.anchorToPopup(popup);
            popup.pinned = !popup.open;
            popup.open = !popup.open;
            if (popup.open) {
                root.refreshHistory();
                root.searchFilter = "";
                root.selectedIndex = 0;
                clipInput.text = "";
                clipInput.forceActiveFocus();
            }
        }
        function onRequestClipboardOpen() {
            root.anchorToPopup(popup);
            popup.pinned = true;
            popup.open = true;
            root.refreshHistory();
            root.searchFilter = "";
            root.selectedIndex = 0;
            clipInput.text = "";
            clipInput.forceActiveFocus();
        }
        function onRequestClipboardClose() {
            popup.pinned = false;
            popup.open = false;
        }
    }

    PopupPanel {
        id: popup
        wantsFocus: true
        cardWidth: 400
        cardHeight: 510

        content: ColumnLayout {
            anchors.fill: parent
            spacing: 10
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    popup.pinned = false;
                    popup.open = false;
                    event.accepted = true;
                }
            }

            // header
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "clipboard"
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.titleAxes
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Theme.fontWeightBold
                    color: Theme.on_surface
                }

                Rectangle {
                    height: 20
                    implicitWidth: countTxt.implicitWidth + 12
                    radius: Theme.radiusPill
                    color: root.copiedFeedback ? Theme.primary_overlay : Theme.surface_container_highest
                    border.color: root.copiedFeedback ? Theme.primary : Theme.outline_variant
                    border.width: 1

                    Text {
                        id: countTxt
                        anchors.centerIn: parent
                        text: root.copiedFeedback
                            ? "copied to clipboard"
                            : (root.visibleEntries.length + " items" + (root.pinEntries.length > 0 ? (" • " + root.pinEntries.length + " pinned") : ""))
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.weight: Theme.monoWeightRegular
                        font.pixelSize: 10
                        color: root.copiedFeedback ? Theme.primary : Theme.on_surface_variant
                    }
                }

                Item { Layout.fillWidth: true }

                IconButton {
                    icon: Theme.iconRefresh
                    iconSize: Theme.fontSizeMd
                    tooltip: "refresh cliphist"
                    onClicked: root.refreshHistory()
                }

                IconButton {
                    icon: Theme.iconTrash
                    iconSize: Theme.fontSizeMd
                    iconColor: Theme.error
                    tooltip: "wipe cliphist history (keeps pinned)"
                    onClicked: root.runClipAction(["wipe"], false)
                }

                IconButton {
                    icon: Theme.iconClose
                    iconSize: Theme.fontSizeSm
                    tooltip: "close"
                    onClicked: {
                        popup.pinned = false;
                        popup.open = false;
                    }
                }
            }

            // search box
            Rectangle {
                Layout.fillWidth: true
                height: 38
                color: Theme.surface_container_highest
                radius: Theme.widgetRadius
                border.color: clipInput.activeFocus ? Theme.primary : Theme.widgetBorder
                border.width: 1

                Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: Theme.iconSearch
                        font.family: Theme.fontIcon
                        font.variableAxes: Theme.iconAxes
                        font.pixelSize: Theme.fontSizeSm
                        color: clipInput.activeFocus ? Theme.primary : Theme.on_surface_variant
                    }

                    TextInput {
                        id: clipInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.on_surface
                        selectionColor: Theme.primary_container
                        selectedTextColor: Theme.on_primary_container
                        focus: popup.open
                        onTextChanged: {
                            root.searchFilter = text;
                            root.selectedIndex = 0;
                        }
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "search cliphist (enter: copy, right-click: delete)"
                            font: parent.font
                            color: Theme.on_surface_disabled
                            visible: parent.text.length === 0
                        }
                        Keys.onPressed: (event) => {
                            let list = root.visibleEntries;
                            if (event.key === Qt.Key_Escape) {
                                popup.pinned = false;
                                popup.open = false;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
                                if (list.length > 0) root.selectedIndex = Math.min(list.length - 1, root.selectedIndex + 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                                if (list.length > 0) root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                if (list.length > 0) {
                                    let idx = Math.max(0, Math.min(list.length - 1, root.selectedIndex));
                                    root.copyEntry(list[idx], Boolean(event.modifiers & Qt.ShiftModifier));
                                }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                                if (list.length > 0) {
                                    let idx = Math.max(0, Math.min(list.length - 1, root.selectedIndex));
                                    root.removeEntry(list[idx]);
                                }
                                event.accepted = true;
                            }
                        }
                    }

                    IconButton {
                        visible: clipInput.text.length > 0
                        icon: Theme.iconClose
                        iconSize: 12
                        implicitWidth: 22
                        implicitHeight: 22
                        onClicked: {
                            clipInput.text = "";
                            clipInput.forceActiveFocus();
                        }
                    }
                }
            }

            // filter pills: all | text | images | links | pinned
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { id: "all", label: "all" },
                        { id: "text", label: "text" },
                        { id: "images", label: "images" },
                        { id: "links", label: "links" },
                        { id: "pinned", label: "pinned" }
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isCur: root.activeFilter === modelData.id
                        Layout.fillWidth: true
                        height: 26
                        radius: Theme.radiusPill
                        color: isCur ? Theme.primary : (fMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_high)
                        border.color: isCur ? Theme.primary : Theme.outline_variant
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: Theme.fontFamily
                            font.variableAxes: Theme.sansAxes
                            font.pixelSize: 11
                            font.weight: isCur ? Theme.fontWeightBold : Theme.fontWeightMedium
                            color: isCur ? Theme.on_primary : Theme.on_surface_variant
                        }

                        MouseArea {
                            id: fMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeFilter = modelData.id;
                                root.selectedIndex = 0;
                            }
                        }
                    }
                }
            }

            // clips list
            FlickList {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                visible: root.visibleEntries.length > 0

                Repeater {
                    model: root.visibleEntries

                    delegate: Rectangle {
                        id: clipDelegate
                        required property var modelData
                        required property int index

                        readonly property bool isSelected: index === root.selectedIndex
                        readonly property bool isImage: modelData.kind === "image" && modelData.thumb !== ""

                        width: parent ? parent.width : 360
                        implicitHeight: col.implicitHeight + 16
                        color: isSelected
                            ? Theme.primary_overlay
                            : (cMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_low)
                        radius: Theme.widgetRadius
                        border.color: isSelected
                            ? Theme.primary
                            : (modelData.pinned ? Theme.alpha(Theme.primary, 0.45) : Theme.widgetBorder)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                        MouseArea {
                            id: cMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                root.selectedIndex = clipDelegate.index;
                                if (mouse.button === Qt.RightButton) {
                                    root.removeEntry(clipDelegate.modelData);
                                } else if (mouse.button === Qt.MiddleButton) {
                                    root.togglePinEntry(clipDelegate.modelData);
                                } else {
                                    root.copyEntry(clipDelegate.modelData, Boolean(mouse.modifiers & Qt.ShiftModifier));
                                }
                            }
                        }

                        ColumnLayout {
                            id: col
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    height: 18
                                    implicitWidth: kindTxt.implicitWidth + 10
                                    radius: Theme.radiusPill
                                    color: clipDelegate.modelData.pinned ? Theme.primary : Theme.surface_container_highest

                                    Text {
                                        id: kindTxt
                                        anchors.centerIn: parent
                                        text: clipDelegate.modelData.pinned
                                            ? ("pin • " + clipDelegate.modelData.kind)
                                            : clipDelegate.modelData.kind
                                        font.family: Theme.fontMono
                                        font.variableAxes: Theme.monoAxes
                                        font.pixelSize: 9
                                        font.weight: Theme.monoWeightBold
                                        color: clipDelegate.modelData.pinned ? Theme.on_primary : Theme.on_surface_variant
                                    }
                                }

                                Text {
                                    visible: clipDelegate.modelData.meta !== "" && clipDelegate.modelData.kind === "image"
                                    text: clipDelegate.modelData.meta
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.weight: Theme.monoWeightRegular
                                    font.pixelSize: 10
                                    color: Theme.on_surface_variant
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Item {
                                    visible: !(clipDelegate.modelData.meta !== "" && clipDelegate.modelData.kind === "image")
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: cMouse.containsMouse
                                    text: "copy"
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.weight: Theme.fontWeightRegular
                                    font.pixelSize: 10
                                    color: Theme.primary
                                }

                                Rectangle {
                                    visible: clipDelegate.modelData.kind === "link"
                                    width: 22
                                    height: 22
                                    radius: Theme.radiusSm
                                    color: openLinkMouse.containsMouse ? Theme.primary_overlay : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: Theme.iconExternalLink
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: 12
                                        color: Theme.primary
                                    }

                                    MouseArea {
                                        id: openLinkMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached(["xdg-open", clipDelegate.modelData.preview.trim()]);
                                        }
                                    }
                                }

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: Theme.radiusSm
                                    color: pinMouse.containsMouse
                                        ? Theme.primary_overlay
                                        : (clipDelegate.modelData.pinned ? Theme.alpha(Theme.primary, 0.14) : "transparent")

                                    Text {
                                        anchors.centerIn: parent
                                        text: Theme.iconPin
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: 12
                                        color: clipDelegate.modelData.pinned ? Theme.primary : Theme.on_surface_variant
                                    }

                                    MouseArea {
                                        id: pinMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.togglePinEntry(clipDelegate.modelData)
                                    }
                                }

                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: Theme.radiusSm
                                    color: delMouse.containsMouse ? Theme.error_overlay : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: Theme.iconClose
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: 12
                                        color: delMouse.containsMouse ? Theme.error : Theme.on_surface_variant
                                    }

                                    MouseArea {
                                        id: delMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeEntry(clipDelegate.modelData)
                                    }
                                }
                            }

                            Rectangle {
                                visible: clipDelegate.isImage
                                Layout.fillWidth: true
                                Layout.preferredHeight: 96
                                radius: Theme.radiusSm
                                color: Theme.surface_container_lowest
                                border.color: Theme.outline_variant
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: clipDelegate.isImage ? ("file://" + clipDelegate.modelData.thumb) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    smooth: true
                                }
                            }

                            Text {
                                visible: !clipDelegate.isImage
                                text: clipDelegate.modelData.preview
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.weight: Theme.monoWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: clipDelegate.isSelected ? Theme.primary : Theme.on_surface
                                wrapMode: Text.WrapAnywhere
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                Layout.fillWidth: true

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                            }
                        }
                    }
                }
            }

            // empty state
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.visibleEntries.length === 0

                Text {
                    text: Theme.iconClipboard + "\n" + (root.searchFilter.length > 0 ? "no matching clips" : "clipboard history is empty")
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.weight: Theme.fontWeightRegular
                    font.pixelSize: Theme.fontSizeMd
                    color: Theme.on_surface_variant
                    horizontalAlignment: Text.AlignHCenter
                    anchors.centerIn: parent
                    lineHeight: 1.5
                }
            }
        }
    }
}
