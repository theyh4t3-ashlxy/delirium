import QtQuick
import QtQuick.Layouts
import ".."
import "../services"

ColumnLayout {
    id: cgRoot
    property string title: ""
    property int columns: 2
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
        visible: cgRoot.title !== ""
        text: cgRoot.title
        font.family: Theme.fontFamily
        font.variableAxes: Theme.sansAxes
        font.pixelSize: Theme.fontSizeXs
        font.weight: Theme.fontWeightDemiBold
        color: Theme.textSecondary
    }

    Grid {
        id: choiceGrid
        width: parent.width
        Layout.fillWidth: true
        columns: Math.max(1, cgRoot.columns)
        rowSpacing: 6
        columnSpacing: 6

        Repeater {
            model: cgRoot.model

            delegate: Rectangle {
                required property var modelData
                readonly property var itemVal: modelData && typeof modelData === "object"
                    ? (modelData.value !== undefined ? modelData.value : (modelData.id !== undefined ? modelData.id : modelData))
                    : modelData
                readonly property string itemText: modelData && typeof modelData === "object" && modelData.label !== undefined
                    ? String(modelData.label)
                    : String(modelData || "")
                readonly property bool isSelected: (typeof cgRoot.currentValue === "number" && typeof itemVal === "number" && !Number.isInteger(itemVal))
                    ? Math.abs(cgRoot.currentValue - itemVal) < 0.04
                    : cgRoot.currentValue === itemVal

                width: Math.max(1, (choiceGrid.width - choiceGrid.columnSpacing * (choiceGrid.columns - 1)) / choiceGrid.columns)
                height: cgRoot.buttonHeight
                radius: isSelected ? Theme.radiusMd : Theme.radiusSm
                color: isSelected
                    ? Theme.primary_overlay
                    : (cgMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                border.color: isSelected
                    ? Theme.alpha(Theme.primary, 0.65)
                    : (cgMouse.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.widgetBorder)
                border.width: 1

                Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: itemText
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: isSelected ? Theme.fontWeightBold : Theme.fontWeightMedium
                    color: isSelected ? Theme.primary : Theme.textSecondary
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: cgMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        cgRoot.selected(itemVal);
                        if (cgRoot.autoSave && typeof Settings !== "undefined" && Settings?.save) {
                            Settings.save();
                        }
                    }
                }
            }
        }
    }
}
