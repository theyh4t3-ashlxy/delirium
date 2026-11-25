// BarStudioStyleTab.qml — bar material, opacity, floating/islands, geometry, chrome, and bar scoops
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../services"
import "../theme/styleEngine.mjs" as StyleEngine

Item {
    id: root

    readonly property var selectedMaterialMeta: {
        const active = Theme.barStyle;
        for (let i = 0; i < StyleEngine.BAR_STYLES.length; i++) {
            if (StyleEngine.BAR_STYLES[i].id === active) return StyleEngine.BAR_STYLES[i];
        }
        return StyleEngine.BAR_STYLES[0];
    }

    function resetScroll() {
        if (flick) flick.contentY = 0;
    }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: gridCol.implicitHeight + 20
        boundsBehavior: Flickable.StopAtBounds

        WheelHandler {
            orientation: Qt.Vertical
            target: parent
        }

        GridLayout {
            id: gridCol
            width: parent.width - 10
            columns: width >= 700 ? 2 : 1
            columnSpacing: Theme.popupSpacing + 2
            rowSpacing: Theme.popupSpacing

            // Left Column: Material, Floating & Islands
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.popupSpacing

                CategoryHeader {
                    title: "bar surface & material"
                    subtitle: "surface palette shader and bar transparency"
                    icon: Theme.iconPalette
                }

                SettingCard {
                    ChoiceGrid {
                        columns: 3
                        buttonHeight: 30
                        title: "bar material preset"
                        model: StyleEngine.BAR_STYLES
                        currentValue: Theme.barStyle
                        onSelected: (val) => Settings.barStyle = StyleEngine.normalizeBarStyle(val)
                    }

                    Text {
                        width: parent.width
                        text: root.selectedMaterialMeta ? (root.selectedMaterialMeta.label + " — " + root.selectedMaterialMeta.desc) : ""
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.textSecondary
                        elide: Text.ElideRight
                    }

                    RowDivider {}

                    SliderRow {
                        title: "bar background opacity"
                        from: 0.3
                        to: 1.0
                        stepSize: 0.05
                        value: Settings.barOpacity
                        formatter: (v) => Math.round(v * 100) + "%"
                        onMoved: (val) => Settings.barOpacity = val
                    }
                }

                CategoryHeader {
                    title: "floating bar & islands"
                    subtitle: "detach the bar and split zones into independent capsules"
                    icon: Theme.iconExpand
                }

                SettingCard {
                    ToggleRow {
                        icon: Theme.iconExpand
                        title: "floating bar"
                        subtitle: "detach status bar from screen edge"
                        checked: Settings.barFloating
                        onToggled: {
                            Settings.barFloating = !Settings.barFloating;
                            if (Settings?.save) Settings.save();
                        }
                    }

                    RowDivider { visible: Settings.barFloating || Theme.isIslands }

                    ToggleRow {
                        visible: Settings.barFloating || Theme.isIslands
                        icon: Theme.iconGrid
                        title: "island zone split"
                        subtitle: "separate left, center, and right zones into capsules"
                        checked: Settings.barIslandMode ?? true
                        onToggled: {
                            Settings.barIslandMode = !(Settings.barIslandMode ?? true);
                            if (Settings?.save) Settings.save();
                        }
                    }

                    ToggleRow {
                        visible: Settings.barFloating || Theme.isIslands
                        icon: Theme.iconSparkles
                        title: "island hover lift"
                        subtitle: "elevate clusters subtly under pointer hover"
                        checked: Settings.bentoHoverLift ?? true
                        onToggled: {
                            Settings.bentoHoverLift = !(Settings.bentoHoverLift ?? true);
                            if (Settings?.save) Settings.save();
                        }
                    }

                    SliderRow {
                        visible: Settings.barFloating || Theme.isIslands
                        title: "island capsule spacing"
                        from: 2
                        to: 20
                        stepSize: 1
                        suffix: "px"
                        value: Settings.bentoGap
                        onMoved: (v) => Settings.bentoGap = v
                    }

                    SliderRow {
                        visible: Settings.barFloating || Theme.isIslands
                        title: "floating corner radius"
                        from: 0
                        to: 24
                        stepSize: 2
                        suffix: "px"
                        value: Settings.barRadius
                        onMoved: (v) => Settings.barRadius = v
                    }

                    SliderRow {
                        visible: Settings.barFloating || Theme.isIslands
                        title: "floating screen margin"
                        from: 0
                        to: 32
                        stepSize: 2
                        suffix: "px"
                        value: Settings.barMargin
                        onMoved: (v) => Settings.barMargin = v
                    }
                }
            }

            // Right Column: Geometry, Chrome & Bar Scoops
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.popupSpacing

                CategoryHeader {
                    title: "geometry & spacing"
                    subtitle: "dock edge, thickness, padding density, and widget corners"
                    icon: Theme.iconGrid
                }

                SettingCard {
                    ChoiceRow {
                        title: "screen edge placement"
                        model: [
                            { label: "top", value: "top" },
                            { label: "bottom", value: "bottom" },
                            { label: "left", value: "left" },
                            { label: "right", value: "right" }
                        ]
                        currentValue: Settings.barPosition === "up" ? "top" : (Settings.barPosition === "down" ? "bottom" : Settings.barPosition)
                        onSelected: (val) => Settings.barPosition = val
                    }

                    ChoiceRow {
                        title: "padding density scale"
                        model: [
                            { label: "compact (0.8x)", value: "compact" },
                            { label: "cozy (1.0x)", value: "cozy" },
                            { label: "comfortable (1.25x)", value: "comfortable" }
                        ]
                        currentValue: Settings.paddingScale || "cozy"
                        onSelected: (val) => Settings.paddingScale = val
                    }

                    RowDivider {}

                    SliderRow {
                        title: "bar thickness"
                        from: 24
                        to: 56
                        stepSize: 2
                        suffix: "px"
                        value: Settings.barHeight
                        onMoved: (val) => Settings.barHeight = val
                    }

                    SliderRow {
                        title: "widget spacing"
                        from: 0
                        to: 16
                        stepSize: 1
                        suffix: "px"
                        value: Settings.widgetSpacing
                        onMoved: (val) => Settings.widgetSpacing = val
                    }

                    SliderRow {
                        title: "widget horizontal padding"
                        from: 2
                        to: 18
                        stepSize: 1
                        suffix: "px"
                        value: Settings.widgetPaddingH
                        onMoved: (val) => Settings.widgetPaddingH = val
                    }

                    SliderRow {
                        title: "widget vertical padding"
                        from: 2
                        to: 12
                        stepSize: 1
                        suffix: "px"
                        value: Settings.widgetPaddingV
                        onMoved: (val) => Settings.widgetPaddingV = val
                    }

                    RowDivider {}

                    ChoiceRow {
                        title: "widget corner radius"
                        model: [
                            { label: "sharp", value: 0 },
                            { label: "2px", value: 2 },
                            { label: "4px", value: 4 },
                            { label: "8px", value: 8 },
                            { label: "12px", value: 12 },
                            { label: "pill", value: 9999 }
                        ]
                        currentValue: Settings.widgetRadius
                        onSelected: (val) => Settings.widgetRadius = val
                    }
                }

                CategoryHeader {
                    title: "grouping, chrome & bar scoops"
                    subtitle: "cluster containers, module dividers, and docked scoop strokes"
                    icon: Theme.iconSliders
                }

                SettingCard {
                    ChoiceRow {
                        title: "module grouping"
                        model: [
                            { label: "clusters", value: "clusters" },
                            { label: "3 zones", value: "zones" },
                            { label: "none", value: "none" }
                        ]
                        currentValue: Settings.barGrouping || "clusters"
                        onSelected: (val) => Settings.barGrouping = val
                    }

                    ChoiceRow {
                        title: "widget chrome style"
                        model: [
                            { label: "grouped", value: "grouped" },
                            { label: "ghost", value: "ghost" },
                            { label: "underline", value: "underline" },
                            { label: "pills", value: "pills" }
                        ]
                        currentValue: Settings.barWidgetChrome || "grouped"
                        onSelected: (val) => Settings.barWidgetChrome = val
                    }

                    ChoiceRow {
                        title: "cluster dividers"
                        model: [
                            { label: "hairline", value: "line" },
                            { label: "dot", value: "dot" },
                            { label: "none", value: "none" }
                        ]
                        currentValue: Settings.barDividers || "line"
                        onSelected: (val) => Settings.barDividers = val
                    }

                    RowDivider {}

                    SliderRow {
                        title: "bar scoop radius"
                        from: 0
                        to: 32
                        stepSize: 2
                        suffix: "px"
                        value: Settings.scoopRadius
                        onMoved: (val) => Settings.scoopRadius = val
                    }

                    ToggleRow {
                        icon: Theme.iconSparkles
                        title: "scoop border outlines"
                        subtitle: "draw continuous stroke along docked bar and concave scoops"
                        checked: Settings.scoopBorderEnabled
                        onToggled: {
                            Settings.scoopBorderEnabled = !Settings.scoopBorderEnabled;
                            if (Settings?.save) Settings.save();
                        }
                    }

                    SliderRow {
                        visible: Settings.scoopBorderEnabled
                        title: "scoop border width"
                        from: 1
                        to: 6
                        stepSize: 1
                        suffix: "px"
                        value: Settings.scoopBorderWidth
                        onMoved: (val) => Settings.scoopBorderWidth = val
                    }
                }
            }
        }
    }

    TabScrollTrack { target: flick }
}
