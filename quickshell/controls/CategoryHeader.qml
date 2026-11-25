import QtQuick
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: catHdr
    property string title: ""
    property string icon: ""
    property string subtitle: ""

    Layout.fillWidth: true
    Layout.topMargin: 8
    Layout.bottomMargin: 2
    spacing: 3

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            visible: catHdr.icon !== ""
            width: 24
            height: 24
            radius: Theme.radiusSm
            color: Theme.primary_overlay
            border.color: Theme.alpha(Theme.primary, 0.35)
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: catHdr.icon
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.fontSizeXs
                color: Theme.primary
            }
        }

        Text {
            text: catHdr.title
            font.family: Theme.fontDisplay
            font.variableAxes: Theme.displayAxes
            font.pixelSize: Theme.fontSizeSm
            font.weight: Theme.fontWeightBold
            color: Theme.textPrimary
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.widgetBorder
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Text {
        visible: catHdr.subtitle !== ""
        text: catHdr.subtitle
        Layout.leftMargin: catHdr.icon !== "" ? 32 : 0
        Layout.fillWidth: true
        font.family: Theme.fontFamily
        font.variableAxes: Theme.sansAxes
        font.weight: Theme.fontWeightRegular
        font.pixelSize: Theme.fontSizeXs
        color: Theme.textSecondary
        wrapMode: Text.Wrap
    }
}
