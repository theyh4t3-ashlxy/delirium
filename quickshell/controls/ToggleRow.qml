import QtQuick
import ".."

Rectangle {
    id: trRoot
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    signal toggled()

    width: parent ? parent.width : 0
    implicitHeight: subtitle !== "" ? 46 : 36
    height: implicitHeight
    radius: Theme.radiusSm
    color: trMouse.containsMouse ? Theme.widgetHover : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

    Rectangle {
        id: trIcon
        visible: trRoot.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28
        radius: Theme.radiusSm
        color: trRoot.checked ? Theme.primary_overlay : Theme.widgetBg
        border.color: trRoot.checked ? Theme.alpha(Theme.primary, 0.4) : Theme.widgetBorder
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

        Text {
            anchors.centerIn: parent
            text: trRoot.icon
            font.family: Theme.fontIcon
            font.variableAxes: Theme.iconAxes
            font.pixelSize: Theme.fontSizeXs
            color: trRoot.checked ? Theme.primary : Theme.textSecondary
        }
    }

    ToggleSwitch {
        id: trSwitch
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        enabled: false
        checked: trRoot.checked

        Binding {
            target: trSwitch
            property: "checked"
            value: trRoot.checked
        }
    }

    Column {
        anchors.left: trIcon.visible ? trIcon.right : parent.left
        anchors.leftMargin: trIcon.visible ? 10 : 6
        anchors.right: trSwitch.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            text: trRoot.title
            font.family: Theme.fontFamily
            font.variableAxes: Theme.sansAxes
            font.pixelSize: Theme.fontSizeSm
            font.weight: trRoot.checked ? Theme.fontWeightDemiBold : Theme.fontWeightMedium
            color: Theme.textPrimary
            elide: Text.ElideRight
        }

        Text {
            visible: trRoot.subtitle !== ""
            width: parent.width
            text: trRoot.subtitle
            font.family: Theme.fontFamily
            font.variableAxes: Theme.sansAxes
            font.weight: Theme.fontWeightRegular
            font.pixelSize: Theme.fontSizeXs
            color: Theme.textSecondary
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: trMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: trRoot.toggled()
    }
}
