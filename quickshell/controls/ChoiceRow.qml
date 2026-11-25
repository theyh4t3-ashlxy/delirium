import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

ColumnLayout {
    id: crRoot
    property string title: ""
    property var model: []
    property var currentValue
    property int buttonHeight: 28
    property bool autoSave: true
    signal selected(var value)

    width: parent ? parent.width : 0
    implicitWidth: width
    Layout.fillWidth: true
    spacing: 5

    Text {
        visible: crRoot.title !== ""
        text: crRoot.title
        font.family: Theme.fontFamily
        font.variableAxes: Theme.sansAxes
        font.pixelSize: Theme.fontSizeXs
        font.weight: Theme.fontWeightDemiBold
        color: Theme.textSecondary
    }

    GridLayout {
        Layout.fillWidth: true
        columns: crRoot.model.length >= 6 ? 3 : Math.max(1, crRoot.model.length)
        columnSpacing: 5
        rowSpacing: 5

        Repeater {
            model: crRoot.model

            delegate: Rectangle {
                required property var modelData
                readonly property var itemVal: modelData && typeof modelData === "object"
                    ? (modelData.value !== undefined ? modelData.value : modelData)
                    : modelData
                readonly property string itemText: modelData && typeof modelData === "object" && modelData.label !== undefined
                    ? String(modelData.label)
                    : (typeof modelData === "number" ? (modelData === 0 ? "none" : modelData + "px") : String(modelData || ""))
                readonly property bool isSelected: (typeof crRoot.currentValue === "number" && typeof itemVal === "number" && !Number.isInteger(itemVal))
                    ? Math.abs(crRoot.currentValue - itemVal) < 0.04
                    : crRoot.currentValue === itemVal

                Layout.fillWidth: true
                Layout.preferredHeight: crRoot.buttonHeight
                radius: isSelected ? Theme.radiusMd : Theme.radiusPill
                color: isSelected
                    ? Theme.primary_overlay
                    : (crMouse.pressed ? Theme.widgetActive : (crMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg))
                border.color: isSelected
                    ? Theme.alpha(Theme.primary, 0.65)
                    : (crMouse.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.widgetBorder)
                border.width: 1

                Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Text {
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, Math.max(0, parent.width - 10))
                    text: itemText
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: isSelected ? Theme.fontWeightBold : Theme.fontWeightMedium
                    color: isSelected ? Theme.primary : Theme.textSecondary
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: crMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        crRoot.selected(itemVal);
                        if (crRoot.autoSave && typeof Settings !== "undefined" && Settings?.save) {
                            Settings.save();
                        }
                    }
                }
            }
        }
    }
}
