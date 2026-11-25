// Dropdown.qml — floating native PopupWindow overlay dropdown (no layout push or container clipping)
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    id: root

    property string label: ""
    property string icon: ""
    property string placeholder: "select..."
    property var model: []
    property int currentIndex: 0
    property var currentValue: null
    property bool expanded: false
    property int maxVisibleItems: 7
    property int menuMinWidth: 0
    property color accentColor: Theme.primary

    signal activated(int index, var value)
    signal selected(var value)

    implicitWidth: 200
    implicitHeight: headerButton.height

    function getItemLabel(item, idx) {
        if (item === null || item === undefined) return "";
        if (typeof item === "string" || typeof item === "number") return String(item);
        if (typeof item === "object") {
            return item.label ?? item.title ?? item.name ?? item.text ?? item.value ?? String(idx);
        }
        return String(item);
    }

    function getItemValue(item, idx) {
        if (item === null || item === undefined) return null;
        if (typeof item === "string" || typeof item === "number") return item;
        if (typeof item === "object") {
            return item.value !== undefined ? item.value : (item.id !== undefined ? item.id : item);
        }
        return item;
    }

    function getItemIcon(item) {
        if (typeof item === "object" && item !== null && item.icon) return item.icon;
        return "";
    }

    function getItemSwatch(item) {
        if (typeof item === "object" && item !== null && item.swatch) return item.swatch;
        return "";
    }

    function getItemBadge(item) {
        if (typeof item === "object" && item !== null && item.badge) return item.badge;
        return "";
    }

    function selectIndex(idx) {
        if (!root.model || idx < 0 || idx >= root.model.length) return;
        let val = root.getItemValue(root.model[idx], idx);
        root.currentIndex = idx;
        root.currentValue = val;
        root.activated(idx, val);
        root.selected(val);
        root.expanded = false;
    }

    function updateMenuAnchor() {
        if (!headerButton.QsWindow || !headerButton.QsWindow.window || !headerButton.QsWindow.contentItem) return;
        let win = headerButton.QsWindow.window;
        let contentItem = headerButton.QsWindow.contentItem;
        let pos = contentItem.mapFromItem(headerButton, 0, 0);
        let menuW = Math.max(headerButton.width, root.menuMinWidth);
        let menuH = menuCard.implicitHeight > 0 ? menuCard.implicitHeight : 120;
        let winW = win.width > 0 ? win.width : 1920;
        let winH = win.height > 0 ? win.height : 1080;

        let targetX = Math.max(6, Math.min(winW - menuW - 6, Math.round(pos.x)));
        let targetY = Math.round(pos.y + headerButton.height + 4);
        if (targetY + menuH > winH - 8 && pos.y - menuH - 4 >= 6) {
            targetY = Math.round(pos.y - menuH - 4);
        }

        menuWin.anchor.window = win;
        menuWin.anchor.rect.x = targetX;
        menuWin.anchor.rect.y = targetY;
    }

    onCurrentValueChanged: {
        if (root.model && root.model.length > 0) {
            for (let i = 0; i < root.model.length; i++) {
                if (root.getItemValue(root.model[i], i) === root.currentValue) {
                    if (root.currentIndex !== i) root.currentIndex = i;
                    break;
                }
            }
        }
    }

    onCurrentIndexChanged: {
        if (root.model && root.currentIndex >= 0 && root.currentIndex < root.model.length) {
            const v = root.getItemValue(root.model[root.currentIndex], root.currentIndex);
            if (root.currentValue !== v) root.currentValue = v;
        }
    }

    onExpandedChanged: {
        if (expanded) {
            updateMenuAnchor();
            Qt.callLater(() => {
                if (menuCard) menuCard.forceActiveFocus();
            });
        }
    }

    Rectangle {
        id: headerButton
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        radius: Theme.widgetRadius
        color: headerMouse.pressed
            ? Theme.widgetActive
            : (headerMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
        border.width: 1
        border.color: root.expanded ? root.accentColor : (headerMouse.containsMouse ? Theme.outline : Theme.widgetBorder)

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        readonly property var curItem: (root.model && root.currentIndex >= 0 && root.currentIndex < root.model.length)
            ? root.model[root.currentIndex]
            : null
        readonly property string curSwatch: root.getItemSwatch(curItem)
        readonly property string curIcon: root.getItemIcon(curItem) || root.icon

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 6

            Rectangle {
                visible: headerButton.curSwatch !== ""
                width: 11
                height: 11
                radius: 6
                color: headerButton.curSwatch !== "" ? headerButton.curSwatch : "transparent"
                border.color: Theme.outline_variant
                border.width: 1
            }

            Text {
                visible: headerButton.curSwatch === "" && headerButton.curIcon !== ""
                text: headerButton.curIcon
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeSm
                color: root.expanded ? root.accentColor : Theme.on_surface_variant
            }

            Text {
                visible: root.label !== ""
                text: root.label + ":"
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeXs
                font.weight: Font.Medium
                color: Theme.on_surface_variant
            }

            Text {
                Layout.fillWidth: true
                text: headerButton.curItem !== null
                    ? root.getItemLabel(headerButton.curItem, root.currentIndex)
                    : root.placeholder
                font.family: Theme.fontSans
                font.pixelSize: Theme.fontSizeSm
                font.weight: Font.DemiBold
                color: headerButton.curItem !== null ? Theme.on_surface : Theme.on_surface_variant
                elide: Text.ElideRight
            }

            Text {
                text: Theme.iconChevronDown
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeXs
                color: root.expanded ? root.accentColor : Theme.on_surface_variant
                rotation: root.expanded ? 180 : 0

                Behavior on rotation { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
            }
        }

        MouseArea {
            id: headerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    PopupWindow {
        id: menuWin
        visible: root.expanded
        grabFocus: true
        color: "transparent"
        implicitWidth: Math.max(headerButton.width, root.menuMinWidth)
        implicitHeight: menuCard.implicitHeight

        onVisibleChanged: {
            if (visible) root.updateMenuAnchor();
            else if (root.expanded) root.expanded = false;
        }
        onImplicitHeightChanged: {
            if (visible) root.updateMenuAnchor();
        }

        Rectangle {
            id: menuCard
            width: menuWin.implicitWidth
            implicitHeight: Math.min(root.maxVisibleItems * 30 + 10, itemsCol.implicitHeight + 10)
            radius: Theme.radiusMd
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.alpha(root.accentColor, 0.55)
            focus: root.expanded

            opacity: menuWin.visible ? 1.0 : 0.0
            scale: menuWin.visible ? 1.0 : 0.96
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.expanded = false;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    if (root.model && root.model.length > 0) {
                        root.currentIndex = Math.min(root.model.length - 1, root.currentIndex + 1);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    if (root.model && root.model.length > 0) {
                        root.currentIndex = Math.max(0, root.currentIndex - 1);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.selectIndex(root.currentIndex);
                    event.accepted = true;
                }
            }

            Flickable {
                id: itemsList
                anchors.fill: parent
                anchors.margins: 5
                contentWidth: width
                contentHeight: itemsCol.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: itemsCol
                    width: itemsList.width
                    spacing: 2

                    Repeater {
                        model: root.model ?? []

                        delegate: Rectangle {
                            id: itemDelegate
                            required property var modelData
                            required property int index

                            readonly property bool isSelected: root.currentIndex === index
                            readonly property string itemLabel: root.getItemLabel(modelData, index)
                            readonly property string itemIcon: root.getItemIcon(modelData)
                            readonly property string itemSwatch: root.getItemSwatch(modelData)
                            readonly property string itemBadge: root.getItemBadge(modelData)

                            width: itemsCol.width
                            height: 28
                            radius: Theme.radiusSm
                            color: isSelected
                                ? Theme.primary_overlay
                                : (itemMouse.containsMouse ? Theme.widgetHover : "transparent")
                            border.color: isSelected ? Theme.alpha(root.accentColor, 0.45) : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 6

                                Rectangle {
                                    visible: itemDelegate.itemSwatch !== ""
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: itemDelegate.itemSwatch !== "" ? itemDelegate.itemSwatch : "transparent"
                                    border.color: Theme.outline_variant
                                    border.width: 1
                                }

                                Text {
                                    visible: itemDelegate.itemSwatch === "" && itemDelegate.itemIcon !== ""
                                    text: itemDelegate.itemIcon
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeSm
                                    color: itemDelegate.isSelected ? root.accentColor : Theme.on_surface_variant
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: itemDelegate.itemLabel
                                    font.family: Theme.fontSans
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: itemDelegate.isSelected ? Font.DemiBold : Font.Normal
                                    color: itemDelegate.isSelected ? root.accentColor : Theme.on_surface
                                    elide: Text.ElideRight
                                }

                                Text {
                                    visible: itemDelegate.itemBadge !== ""
                                    text: itemDelegate.itemBadge
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                    color: Theme.on_surface_variant
                                }

                                Text {
                                    visible: itemDelegate.isSelected
                                    text: Theme.iconCheck
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    color: root.accentColor
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectIndex(itemDelegate.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
