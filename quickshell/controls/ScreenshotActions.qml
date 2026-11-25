import QtQuick
import QtQuick.Layouts
import ".."
import "../components"

Item {
    id: root

    signal copyClicked()
    signal saveClicked()
    signal bothClicked()
    signal pinClicked()
    signal recordClicked()
    signal fullClicked()
    signal windowClicked()
    signal regionClicked()
    signal pickerClicked()
    signal cancelClicked()
    signal undoClicked()
    signal redoClicked()
    signal clearAnnotationsClicked()

    property bool isRecordMode: false
    property bool isEditingExisting: false
    property bool annotating: false
    property bool prettifyActive: false
    property bool loupeActive: true
    property string activeMode: typeof ScreenshotService !== "undefined" ? (ScreenshotService?.activeMode ?? "region") : "region"

    // annotation tool state bound symmetrically by ScreenshotOverlay
    property string activeTool: "select" // select|pen|highlighter|arrow|rect|ellipse|step|text|blur
    property color strokeColor: Theme.primary
    property int strokeLevel: 1 // 0=S, 1=M, 2=L
    property string redactMode: "mosaic" // mosaic|blur|solid
    property bool canUndo: false
    property bool canRedo: false
    property bool hasAnnotations: false

    property string currentQuote: Theme.getFlavor ? Theme.getFlavor("screenshot", "snitch mode: engaged") : "snitch mode: engaged"

    readonly property var paletteColors: [
        Theme.primary,
        "#ef4444",
        "#f59e0b",
        "#22c55e",
        "#38bdf8",
        "#ffffff",
        "#111116"
    ]

    function randomizeQuote() {
        let mode = Settings?.flavorMode ?? "actions";
        if (mode === "off") {
            currentQuote = "snitch mode: engaged";
            return;
        }
        if (Theme.rollFlavor) {
            currentQuote = Theme.rollFlavor("screenshot", mode, currentQuote, "snitch mode: engaged");
        } else if (Theme.getFlavor) {
            currentQuote = Theme.getFlavor("screenshot", "snitch mode: engaged", mode);
        }
    }

    implicitWidth: Math.max(mainPill.implicitWidth, subPill.visible ? subPill.implicitWidth : 0)
    implicitHeight: mainPill.implicitHeight + (subPill.visible ? (6 + subPill.implicitHeight) : 0)

    component ActionBtn: Rectangle {
        id: btnRoot
        property string icon: ""
        property string label: ""
        property string badge: ""
        property bool selected: false
        property bool isDanger: false
        property bool isAccent: false
        property bool disabledState: false
        property color iconColor: {
            if (isDanger) return Theme.error ?? "#ff5449";
            if (selected || isAccent) return Theme.primary;
            return Theme.on_surface;
        }
        property color hoverColor: isDanger
            ? (Theme.error_overlay ?? Theme.alpha(Theme.error ?? "#ff5449", 0.18))
            : Theme.primary_overlay
        property color activeColor: isDanger ? (Theme.error ?? "#ff5449") : Theme.primary
        signal clicked()

        readonly property color fgColor: {
            if (disabledState) return Theme.on_surface_disabled;
            if (btnMouse.pressed) return btnRoot.isDanger ? (Theme.on_error ?? "#ffffff") : Theme.on_primary;
            if (btnMouse.containsMouse || btnRoot.selected) {
                return btnRoot.isDanger ? (Theme.error ?? "#ff5449") : Theme.primary;
            }
            return btnRoot.label !== "" ? Theme.on_surface : btnRoot.iconColor;
        }

        opacity: disabledState ? 0.45 : 1.0
        height: 28
        implicitWidth: btnRow.implicitWidth + (btnRoot.label !== "" ? 14 : 10)
        radius: Theme.radiusPill
        color: {
            if (!disabledState && btnMouse.pressed) return btnRoot.activeColor;
            if (!disabledState && (btnMouse.containsMouse || btnRoot.selected)) return btnRoot.hoverColor;
            return "transparent";
        }
        border.color: {
            if (!disabledState && btnRoot.selected) return btnRoot.isDanger ? (Theme.error ?? "#ff5449") : Theme.primary;
            if (!disabledState && btnMouse.containsMouse) return btnRoot.isDanger ? (Theme.error ?? "#ff5449") : Theme.outline_variant;
            return "transparent";
        }
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        RowLayout {
            id: btnRow
            anchors.centerIn: parent
            spacing: 4

            Text {
                visible: btnRoot.icon !== ""
                text: btnRoot.icon
                font.family: Theme.fontIcon
                font.variableAxes: Theme.iconAxes
                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                color: (!btnRoot.disabledState && btnMouse.pressed)
                    ? (btnRoot.isDanger ? (Theme.on_error ?? "#ffffff") : Theme.on_primary)
                    : ((btnMouse.containsMouse || btnRoot.selected) ? btnRoot.fgColor : btnRoot.iconColor)
            }

            Text {
                visible: btnRoot.label !== ""
                text: btnRoot.label
                font.family: Theme.fontFamily
                font.variableAxes: Theme.sansAxes
                font.pixelSize: Theme.fontSizeXs
                font.weight: btnRoot.selected ? Theme.fontWeightBold : Theme.fontWeightMedium
                color: btnRoot.fgColor
            }

            Text {
                visible: btnRoot.badge !== ""
                text: btnRoot.badge
                font.family: Theme.fontMono
                font.variableAxes: Theme.monoAxes
                font.pixelSize: Math.max(8, Theme.fontSizeXs - 1)
                font.weight: Theme.monoWeightBold
                color: Theme.on_surface_variant
            }
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !btnRoot.disabledState
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: btnRoot.clicked()
        }
    }

    // main capture action pill
    Rectangle {
        id: mainPill
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        implicitHeight: 38
        implicitWidth: actionRow.implicitWidth + 16
        radius: Theme.radiusPill
        color: Theme.surface_container_highest
        border.color: Theme.outline_variant
        border.width: 1

        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

        MouseArea {
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            preventStealing: true
        }

        // top scoop flavor tab
        Item {
            id: headerTab
            visible: (Settings?.flavorMode ?? "actions") !== "off" || root.isRecordMode || root.isEditingExisting
            anchors.bottom: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            height: 24
            width: Math.min(mainPill.width - 36, quoteRow.implicitWidth + 24)
            clip: true

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height + 12
                radius: 12
                color: Theme.surface_container_highest
                border.color: Theme.outline_variant
                border.width: 1
            }

            RowLayout {
                id: quoteRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: root.isRecordMode ? Theme.iconCamera : (root.isEditingExisting ? Theme.iconEdit : Theme.kaoWink)
                    font.family: (root.isRecordMode || root.isEditingExisting) ? Theme.fontIcon : Theme.fontFamily
                    font.variableAxes: (root.isRecordMode || root.isEditingExisting) ? Theme.iconAxes : Theme.sansAxes
                    font.pixelSize: Theme.fontSizeXs
                    color: root.isRecordMode ? (Theme.error ?? "#ff5449") : Theme.primary
                }

                Text {
                    text: root.isRecordMode
                        ? "select area to record"
                        : (root.isEditingExisting ? "studio editor" : root.currentQuote)
                    font.family: Theme.fontFamily
                    font.variableAxes: Theme.sansAxes
                    font.pixelSize: Theme.fontSizeXs
                    font.weight: Theme.fontWeightMedium
                    color: root.isRecordMode ? (Theme.error ?? "#ff5449") : Theme.on_surface
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            visible: headerTab.visible
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: headerTab.width - 2
            height: 2
            color: Theme.surface_container_highest
            z: 1
        }

        ConcaveCurves {
            width: 8
            height: 8
            radius: 8
            color: Theme.surface_container_highest
            isTop: false
            flipX: false
            visible: headerTab.visible
            anchors.right: headerTab.left
            anchors.bottom: headerTab.bottom
        }

        ConcaveCurves {
            width: 8
            height: 8
            radius: 8
            color: Theme.surface_container_highest
            isTop: false
            flipX: true
            visible: headerTab.visible
            anchors.left: headerTab.right
            anchors.bottom: headerTab.bottom
        }

        RowLayout {
            id: actionRow
            anchors.centerIn: parent
            spacing: 4
            z: 2

            ActionBtn {
                visible: !root.isEditingExisting
                icon: Theme.iconCrop
                label: "region"
                selected: root.activeMode === "region"
                onClicked: root.regionClicked()
            }

            ActionBtn {
                visible: !root.isEditingExisting && !root.isRecordMode
                icon: Theme.iconWorkspaces
                label: "window"
                selected: root.activeMode === "window"
                onClicked: root.windowClicked()
            }

            ActionBtn {
                visible: !root.isEditingExisting && !root.isRecordMode
                icon: Theme.iconExpand
                label: "full"
                selected: root.activeMode === "fullscreen" || root.activeMode === "full" || root.activeMode === "screen"
                onClicked: root.fullClicked()
            }

            ActionBtn {
                visible: !root.isEditingExisting && !root.isRecordMode
                icon: Theme.iconEyedropper
                label: "pick"
                selected: root.activeMode === "eyedropper"
                onClicked: root.pickerClicked()
            }

            Rectangle {
                visible: !root.isEditingExisting
                width: 1
                height: 16
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                color: Theme.outline_variant
            }

            ActionBtn {
                visible: !root.isRecordMode && root.activeMode !== "eyedropper"
                icon: Theme.iconEdit
                label: "annotate"
                selected: root.annotating
                onClicked: root.annotating = !root.annotating
            }

            ActionBtn {
                visible: !root.isRecordMode && root.activeMode !== "eyedropper"
                icon: Theme.iconFrame
                label: "prettify"
                selected: root.prettifyActive
                onClicked: root.prettifyActive = !root.prettifyActive
            }

            ActionBtn {
                visible: !root.isRecordMode && !root.isEditingExisting && root.activeMode !== "eyedropper"
                icon: Theme.iconZoom
                selected: root.loupeActive
                onClicked: root.loupeActive = !root.loupeActive
            }

            Rectangle {
                visible: !root.isRecordMode && root.activeMode !== "eyedropper"
                width: 1
                height: 16
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                color: Theme.outline_variant
            }

            ActionBtn {
                visible: !root.isRecordMode && root.activeMode !== "eyedropper"
                icon: Theme.iconCopy
                label: "copy"
                isAccent: true
                onClicked: root.copyClicked()
            }

            ActionBtn {
                visible: !root.isRecordMode && root.activeMode !== "eyedropper"
                icon: Theme.iconSave
                label: "save"
                onClicked: root.saveClicked()
            }

            ActionBtn {
                visible: !root.isRecordMode && root.activeMode !== "eyedropper"
                icon: Theme.iconCheck
                label: "both"
                onClicked: root.bothClicked()
            }

            ActionBtn {
                visible: !root.isRecordMode && root.activeMode !== "eyedropper"
                icon: Theme.iconPin
                label: "pin"
                onClicked: root.pinClicked()
            }

            ActionBtn {
                visible: root.isRecordMode
                icon: Theme.iconCamera
                label: "start recording"
                isDanger: true
                onClicked: root.recordClicked()
            }

            Rectangle {
                width: 1
                height: 16
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                color: Theme.outline_variant
            }

            ActionBtn {
                icon: Theme.iconClose
                isDanger: true
                onClicked: root.cancelClicked()
            }
        }
    }

    // secondary studio annotation toolbar
    Rectangle {
        id: subPill
        visible: root.annotating && !root.isRecordMode && root.activeMode !== "eyedropper"
        anchors.top: mainPill.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        implicitHeight: 38
        implicitWidth: toolsRow.implicitWidth + 16
        radius: Theme.radiusPill
        color: Theme.surface_container_highest
        border.color: Theme.outline_variant
        border.width: 1

        MouseArea {
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            preventStealing: true
        }

        RowLayout {
            id: toolsRow
            anchors.centerIn: parent
            spacing: 3

            Repeater {
                model: [
                    { id: "select", icon: Theme.iconCrop, label: "crop" },
                    { id: "pen", icon: Theme.iconBrush, label: "" },
                    { id: "highlighter", icon: Theme.iconHighlight, label: "" },
                    { id: "arrow", icon: Theme.iconArrow, label: "" },
                    { id: "rect", icon: Theme.iconRect, label: "" },
                    { id: "ellipse", icon: Theme.iconCircle, label: "" },
                    { id: "step", icon: Theme.iconStep, label: "" },
                    { id: "text", icon: Theme.iconText, label: "" },
                    { id: "blur", icon: Theme.iconBlur, label: "redact" }
                ]

                delegate: ActionBtn {
                    required property var modelData
                    icon: modelData.icon || ""
                    label: modelData.label || ""
                    selected: root.activeTool === modelData.id
                    onClicked: root.activeTool = modelData.id
                }
            }

            Rectangle {
                width: 1
                height: 16
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                color: Theme.outline_variant
            }

            // color swatch dots
            Repeater {
                model: root.paletteColors

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isCurrent: String(root.strokeColor).toLowerCase() === String(modelData).toLowerCase()
                    width: 16
                    height: 16
                    radius: 8
                    color: modelData
                    border.width: isCurrent ? 2 : 1
                    border.color: isCurrent ? Theme.on_surface : Theme.outline_variant

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.strokeColor = modelData;
                            if (root.activeTool === "select") root.activeTool = "pen";
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: 16
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                color: Theme.outline_variant
            }

            // stroke thickness / redact style switcher
            ActionBtn {
                visible: root.activeTool !== "blur"
                label: root.strokeLevel === 0 ? "s" : (root.strokeLevel === 1 ? "m" : "l")
                onClicked: root.strokeLevel = (root.strokeLevel + 1) % 3
            }

            ActionBtn {
                visible: root.activeTool === "blur"
                label: root.redactMode
                selected: true
                onClicked: {
                    if (root.redactMode === "mosaic") root.redactMode = "blur";
                    else if (root.redactMode === "blur") root.redactMode = "solid";
                    else root.redactMode = "mosaic";
                }
            }

            Rectangle {
                width: 1
                height: 16
                Layout.leftMargin: 2
                Layout.rightMargin: 2
                color: Theme.outline_variant
            }

            ActionBtn {
                icon: Theme.iconUndo
                disabledState: !root.canUndo
                onClicked: root.undoClicked()
            }

            ActionBtn {
                icon: Theme.iconRedo
                disabledState: !root.canRedo
                onClicked: root.redoClicked()
            }

            ActionBtn {
                icon: Theme.iconTrash
                isDanger: true
                disabledState: !root.hasAnnotations
                onClicked: root.clearAnnotationsClicked()
            }
        }
    }
}
