// BarStudioWidgetsTab.qml — bar-specific module behavior (clock, window title, workspaces, media pill)
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../services"

Item {
    id: root

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

            // Left Column: Clock & Window Title
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.popupSpacing

                CategoryHeader {
                    title: "clock & date"
                    subtitle: "bar time notation and optional date badge"
                    icon: Theme.iconClock
                }

                SettingCard {
                    ChoiceRow {
                        title: "bar clock format"
                        model: [
                            { label: "24h", value: "HH:mm" },
                            { label: "12h", value: "h:mm ap" },
                            { label: "24h + sec", value: "HH:mm:ss" },
                            { label: "12h + sec", value: "h:mm:ss ap" }
                        ]
                        currentValue: Settings.clockFormat
                        onSelected: (value) => {
                            Settings.clockFormat = value;
                            let is12 = /ap/i.test(value);
                            let hasSec = /:ss/i.test(value);
                            Settings.clockMilitary = !is12;
                            Settings.clock24h = !is12;
                            Settings.clockShowSeconds = hasSec;
                        }
                    }

                    ChoiceRow {
                        title: "bar date format"
                        model: [
                            { label: "hidden", value: "none" },
                            { label: "short", value: "ddd, MMM d" },
                            { label: "full", value: "MMM d, yyyy" },
                            { label: "iso", value: "yyyy-MM-dd" }
                        ]
                        currentValue: !Settings.showBarDate ? "none" : Settings.dateFormat
                        onSelected: (value) => {
                            if (value === "none") {
                                Settings.showBarDate = false;
                            } else {
                                Settings.dateFormat = value;
                                Settings.showBarDate = true;
                            }
                        }
                    }
                }

                CategoryHeader {
                    title: "active window title"
                    subtitle: "title pill sizing, width ceiling, and application icon"
                    icon: Theme.iconSparkles
                }

                SettingCard {
                    ChoiceRow {
                        title: "window title width mode"
                        model: [
                            { label: "auto fit", value: "auto" },
                            { label: "fill space", value: "fill" },
                            { label: "compact", value: "compact" }
                        ]
                        currentValue: Settings.windowTitleMode || "auto"
                        onSelected: (val) => Settings.windowTitleMode = val
                    }

                    SliderRow {
                        visible: Settings.windowTitleMode !== "fill" && Settings.windowTitleMode !== "compact"
                        title: "max title width"
                        from: 200
                        to: 1000
                        stepSize: 20
                        suffix: "px"
                        value: Settings.windowTitleMaxWidth
                        onMoved: (val) => Settings.windowTitleMaxWidth = val
                    }

                    RowDivider {}

                    ToggleRow {
                        icon: Theme.iconEye
                        title: "show app icon in bar"
                        subtitle: "resolve desktop entry icon beside focused window title"
                        checked: Settings.windowTitleShowIcon ?? true
                        onToggled: {
                            Settings.windowTitleShowIcon = !(Settings.windowTitleShowIcon ?? true);
                            if (Settings?.save) Settings.save();
                        }
                    }
                }
            }

            // Right Column: Workspaces & Media Pill
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.popupSpacing

                CategoryHeader {
                    title: "workspaces"
                    subtitle: "workspace capacity, indicator trail, and wheel switching"
                    icon: Theme.iconWorkspaces
                }

                SettingCard {
                    ChoiceRow {
                        title: "workspace capacity"
                        model: [
                            { label: "5", value: 5 },
                            { label: "8", value: 8 },
                            { label: "10", value: 10 },
                            { label: "12", value: 12 },
                            { label: "16", value: 16 }
                        ]
                        currentValue: Settings.workspaceCount
                        onSelected: (value) => Settings.workspaceCount = value
                    }

                    ChoiceRow {
                        title: "workspace indicator motion"
                        model: [
                            { label: "smooth slide", value: "slide" },
                            { label: "fluid trail", value: "fluid-trail" },
                            { label: "discrete", value: "discrete" }
                        ]
                        currentValue: Settings.workspaceMode
                        onSelected: (value) => Settings.workspaceMode = value
                    }

                    SliderRow {
                        visible: Settings.workspaceMode === "fluid-trail"
                        title: "workspace trail duration"
                        from: 120
                        to: 400
                        stepSize: 10
                        suffix: "ms"
                        value: Settings.workspaceTrailDuration
                        onMoved: (val) => Settings.workspaceTrailDuration = val
                    }

                    RowDivider {}

                    ToggleRow {
                        icon: Theme.iconWorkspaces
                        title: "scroll bar to cycle workspaces"
                        subtitle: "mouse wheel on docked bar background switches workspaces"
                        checked: Settings.barScrollWorkspaces ?? true
                        onToggled: {
                            Settings.barScrollWorkspaces = !(Settings.barScrollWorkspaces ?? true);
                            if (Settings?.save) Settings.save();
                        }
                    }
                }

                CategoryHeader {
                    title: "now playing pill"
                    subtitle: "live bar media indicator visuals"
                    icon: Theme.iconMusic
                }

                SettingCard {
                    ToggleRow {
                        icon: Theme.iconEqualizer
                        title: "spectrum wave visualizer"
                        subtitle: "animate equalizer wave on the bar pill and media player while playing"
                        checked: Settings.mediaWaveVisualizer ?? true
                        onToggled: {
                            Settings.mediaWaveVisualizer = !(Settings.mediaWaveVisualizer ?? true);
                            if (Settings?.save) Settings.save();
                        }
                    }
                }
            }
        }
    }

    TabScrollTrack { target: flick }
}
