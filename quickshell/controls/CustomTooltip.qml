// CustomTooltip.qml — native Wayland PopupWindow tooltip with hover delay and edge-aware anchoring
import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Item {
    id: tipRoot

    required property Item anchorItem
    property bool active: false
    property string text: ""
    property string subtext: ""
    property string shortcut: ""
    property int delay: 380
    property int maxWidth: 260
    property string preferredEdge: "auto" // "auto" | "top" | "bottom" | "left" | "right"

    property bool _open: false

    width: 0
    height: 0
    visible: false

    onActiveChanged: {
        if (active && text !== "") {
            showTimer.restart();
        } else {
            showTimer.stop();
            _open = false;
        }
    }

    onTextChanged: {
        if (text === "") _open = false;
        else if (_open) updateAnchor();
    }

    Timer {
        id: showTimer
        interval: Math.max(40, tipRoot.delay)
        repeat: false
        onTriggered: {
            if (tipRoot.active && tipRoot.text !== "") {
                tipRoot.updateAnchor();
                tipRoot._open = true;
            }
        }
    }

    function updateAnchor() {
        let a = tipRoot.anchorItem;
        if (!a || !a.QsWindow || !a.QsWindow.window || !a.QsWindow.contentItem) return;
        let win = a.QsWindow.window;
        let pos = a.QsWindow.contentItem.mapFromItem(a, 0, 0);
        let tipW = tipCard.implicitWidth > 0 ? tipCard.implicitWidth : 120;
        let tipH = tipCard.implicitHeight > 0 ? tipCard.implicitHeight : 28;
        let winW = win.width > 0 ? win.width : 1920;
        let winH = win.height > 0 ? win.height : 1080;

        let edge = tipRoot.preferredEdge;
        if (edge === "auto") {
            let barPos = Settings?.barPosition ?? "up";
            if (Theme?.isVertical ?? false) {
                edge = (barPos === "right") ? "left" : "right";
            } else {
                edge = (barPos === "down" || barPos === "bottom") ? "top" : "bottom";
            }
        }

        tipWin.anchor.window = win;
        if (edge === "left" || edge === "right") {
            let rx = (edge === "left") ? (pos.x - tipW - 8) : (pos.x + a.width + 8);
            if (edge === "right" && rx + tipW > winW - 6) rx = Math.max(6, pos.x - tipW - 8);
            if (edge === "left" && rx < 6) rx = pos.x + a.width + 8;
            let ry = Math.max(6, Math.min(winH - tipH - 6, Math.round(pos.y + (a.height - tipH) / 2)));
            tipWin.anchor.rect.x = Math.round(rx);
            tipWin.anchor.rect.y = ry;
        } else {
            let rx = Math.max(6, Math.min(winW - tipW - 6, Math.round(pos.x + (a.width - tipW) / 2)));
            let ry = (edge === "top") ? (pos.y - tipH - 8) : (pos.y + a.height + 8);
            if (edge === "bottom" && ry + tipH > winH - 6) ry = Math.max(6, pos.y - tipH - 8);
            if (edge === "top" && ry < 6) ry = pos.y + a.height + 8;
            tipWin.anchor.rect.x = rx;
            tipWin.anchor.rect.y = Math.round(ry);
        }
    }

    PopupWindow {
        id: tipWin
        visible: tipRoot._open && tipRoot.text !== ""
        color: "transparent"
        implicitWidth: tipCard.implicitWidth
        implicitHeight: tipCard.implicitHeight

        onVisibleChanged: {
            if (visible) tipRoot.updateAnchor();
        }
        onImplicitWidthChanged: {
            if (visible) tipRoot.updateAnchor();
        }
        onImplicitHeightChanged: {
            if (visible) tipRoot.updateAnchor();
        }

        Rectangle {
            id: tipCard
            implicitWidth: Math.min(tipRoot.maxWidth, tipCol.implicitWidth + 18)
            implicitHeight: tipCol.implicitHeight + 12
            radius: Theme.radiusMd
            color: Theme.popupBg
            border.color: Theme.popupBorderColor
            border.width: 1

            opacity: tipWin.visible ? 1.0 : 0.0
            scale: tipWin.visible ? 1.0 : 0.94
            Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
            Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

            ColumnLayout {
                id: tipCol
                anchors.centerIn: parent
                spacing: 2

                RowLayout {
                    spacing: 6

                    Text {
                        text: tipRoot.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Font.Bold
                        color: Theme.on_surface
                        elide: Text.ElideRight
                        Layout.maximumWidth: tipRoot.maxWidth - 28
                    }

                    Rectangle {
                        visible: tipRoot.shortcut !== ""
                        height: 16
                        implicitWidth: scTxt.implicitWidth + 8
                        radius: Theme.radiusXs
                        color: Theme.surface_container_highest
                        border.color: Theme.outline_variant
                        border.width: 1

                        Text {
                            id: scTxt
                            anchors.centerIn: parent
                            text: tipRoot.shortcut
                            font.family: Theme.fontMono
                            font.pixelSize: 9
                            color: Theme.primary
                        }
                    }
                }

                Text {
                    visible: tipRoot.subtext !== "" && tipRoot.subtext !== tipRoot.text
                    text: tipRoot.subtext
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    color: Theme.on_surface_variant
                    elide: Text.ElideRight
                    Layout.maximumWidth: tipRoot.maxWidth - 20
                }
            }
        }
    }
}
