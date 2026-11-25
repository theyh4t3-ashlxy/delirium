import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../theme/confFormat.mjs" as ConfFmt
import Quickshell
import Quickshell.Io

BarPill {
    id: clockRoot

    readonly property int currentBarHeight: Theme?.barHeight ?? 48

    active: calPopup.open
    hovered: clkMouse.containsMouse
    pressed: clkMouse.pressed

    implicitWidth: (Theme?.isVertical ?? false) ? pillSize : (clockRow.implicitWidth + 24)
    implicitHeight: (Theme?.isVertical ?? false) ? 42 : pillSize
    width: implicitWidth
    height: implicitHeight
    visible: Settings?.showClock ?? true
    clip: false

    Behavior on width { NumberAnimation { duration: Theme?.animFast ?? 150; easing.type: Theme?.animEasing ?? Easing.OutQuad } }

    property date now: new Date()
    readonly property int todayYear: now.getFullYear()
    readonly property int todayMonth: now.getMonth()
    readonly property int todayDate: now.getDate()

    property int selectedYear: todayYear
    property int selectedMonth: todayMonth // 0-11
    property int focusedDay: todayDate
    property int focusedMonth: todayMonth
    property int focusedYear: todayYear

    // weather telemetry via scripts/weather.py
    readonly property string weatherScript: decodeURIComponent(Qt.resolvedUrl("../scripts/weather.py").toString().replace(/^file:\/\//, ""))
    property bool weatherLoading: false
    property bool weatherOk: false
    property string weatherCity: ""
    property real weatherTempC: 0
    property real weatherTempF: 0
    property real weatherFeelsC: 0
    property real weatherFeelsF: 0
    property real weatherHighC: 0
    property real weatherHighF: 0
    property real weatherLowC: 0
    property real weatherLowF: 0
    property int weatherHumidity: 0
    property real weatherWindKmh: 0
    property int weatherCode: 0
    property string weatherCond: ""
    property bool weatherIsDay: true
    property string weatherError: ""
    property real _lastWeatherFetchMs: 0
    property bool editingCity: false

    function parseKv(text) {
        let raw = ConfFmt.parseFlatConf(text || "");
        let out = {};
        for (let k in raw) out[k] = ConfFmt.unescapeField(raw[k]);
        return out;
    }

    function refreshWeather(force) {
        if (!(Settings?.weatherEnabled ?? true)) return;
        let nowMs = Date.now();
        if (!force && weatherOk && (nowMs - _lastWeatherFetchMs) < 600000) return;
        if (weatherProc.running) {
            if (!force) return;
            weatherProc.running = false;
        }
        weatherLoading = true;
        let args = ["python3", weatherScript];
        if (force) args.push("--force");
        if (Settings?.weatherLocation && Settings.weatherLocation.trim() !== "") {
            args.push(Settings.weatherLocation.trim());
        }
        weatherProc.command = args;
        weatherProc.running = true;
    }

    Process {
        id: weatherProc
        stdout: StdioCollector {
            onStreamFinished: {
                clockRoot.weatherLoading = false;
                let kv = clockRoot.parseKv(text);
                if (kv.ok === "true") {
                    clockRoot.weatherOk = true;
                    clockRoot.weatherError = "";
                    clockRoot.weatherCity = kv.city || "local";
                    clockRoot.weatherTempC = parseFloat(kv.temp_c || "0") || 0;
                    clockRoot.weatherTempF = parseFloat(kv.temp_f || "0") || 0;
                    clockRoot.weatherFeelsC = parseFloat(kv.feels_c || "0") || 0;
                    clockRoot.weatherFeelsF = parseFloat(kv.feels_f || "0") || 0;
                    clockRoot.weatherHighC = parseFloat(kv.high_c || "0") || 0;
                    clockRoot.weatherHighF = parseFloat(kv.high_f || "0") || 0;
                    clockRoot.weatherLowC = parseFloat(kv.low_c || "0") || 0;
                    clockRoot.weatherLowF = parseFloat(kv.low_f || "0") || 0;
                    clockRoot.weatherHumidity = parseInt(kv.humidity || "0", 10) || 0;
                    clockRoot.weatherWindKmh = parseFloat(kv.wind_kmh || "0") || 0;
                    clockRoot.weatherCode = parseInt(kv.code || "0", 10) || 0;
                    clockRoot.weatherCond = kv.cond || "clear";
                    clockRoot.weatherIsDay = kv.is_day !== "false";
                    clockRoot._lastWeatherFetchMs = Date.now();
                } else {
                    clockRoot.weatherOk = false;
                    clockRoot.weatherError = kv.error || "weather unavailable";
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockRoot.now = new Date()
    }

    Timer {
        interval: 900000
        running: Settings?.weatherEnabled ?? true
        repeat: true
        onTriggered: clockRoot.refreshWeather(false)
    }

    Component.onCompleted: {
        if (Settings?.weatherEnabled ?? true) refreshWeather(false);
    }

    function getDayOfYear(d) {
        let target = d || clockRoot.now;
        let start = new Date(target.getFullYear(), 0, 0);
        let diff = (target - start) + ((start.getTimezoneOffset() - target.getTimezoneOffset()) * 60 * 1000);
        return Math.floor(diff / 86400000);
    }

    function getSelectedDayHint() {
        let today = new Date(todayYear, todayMonth, todayDate);
        let sel = new Date(focusedYear, focusedMonth, focusedDay);
        let diffDays = Math.round((sel - today) / 86400000);
        if (diffDays === 0) return Math.round(((now.getHours() * 60 + now.getMinutes()) / 1440) * 100) + "% day elapsed";
        let label = Qt.formatDate(sel, "ddd, MMM d").toLowerCase();
        if (diffDays === 1) return label + " • tomorrow";
        if (diffDays === -1) return label + " • yesterday";
        return label + " • " + (diffDays > 0 ? ("in " + diffDays + "d") : (Math.abs(diffDays) + "d ago"));
    }

    function getClockMoodIcon(hrs) {
        if (!Theme) return "";
        if (hrs < 6) return Theme?.iconMoon ?? "\u263E";
        if (hrs < 12) return Theme?.iconCoffee ?? "\u2615";
        if (hrs < 18) return Theme?.iconSun ?? "\u2600";
        return Theme?.iconMusic ?? "\u266B";
    }

    Row {
        id: clockRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: (Theme?.isVertical ?? false) ? undefined : parent.left
        anchors.leftMargin: (Theme?.isVertical ?? false) ? 0 : 12
        anchors.horizontalCenter: (Theme?.isVertical ?? false) ? parent.horizontalCenter : undefined
        spacing: 6

        Text {
            id: clockMoodText
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (Theme?.isVertical ?? false) return "";
                return clockRoot.getClockMoodIcon(clockRoot.now.getHours());
            }
            visible: text !== "" && !(Theme?.isVertical ?? false)
            font.family: Theme?.fontIcon ?? "sans-serif"
            font.variableAxes: Theme?.iconAxes ?? ({})
            font.pixelSize: Theme?.fontSizeSm ?? 12
            color: calPopup.open ? Theme.primary : Theme.on_surface_variant
        }

        Text {
            id: timeText
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            lineHeight: (Theme?.isVertical ?? false) ? 0.9 : 1.0
            text: {
                let military = (Settings?.clock24h !== undefined ? Settings.clock24h : (Settings?.clockMilitary ?? true));
                let is12 = (Settings?.clockFormat && /ap/i.test(Settings.clockFormat)) || !military;
                let showSec = Settings?.clockShowSeconds ?? (Settings?.clockFormat && /:ss/i.test(Settings.clockFormat));

                if (Theme?.isVertical ?? false) {
                    if (is12) {
                        let h = clockRoot.now.getHours() % 12;
                        if (h === 0) h = 12;
                        let m = clockRoot.now.getMinutes();
                        return ((h < 10 ? "0" : "") + h) + "\n" + ((m < 10 ? "0" : "") + m);
                    }
                    return Qt.formatDateTime(clockRoot.now, "HH\nmm");
                }

                let timeFmt = Settings?.clockFormat;
                if (!timeFmt || timeFmt.trim() === "") {
                    timeFmt = is12 ? (showSec ? "h:mm:ss ap" : "h:mm ap") : (showSec ? "HH:mm:ss" : "HH:mm");
                }
                let timeStr = Qt.formatDateTime(clockRoot.now, timeFmt).toLowerCase();
                let dateFmt = (Settings?.dateFormat && Settings.dateFormat !== "none") ? Settings.dateFormat : "";
                let showDate = (Settings?.showBarDate ?? false) && dateFmt !== "";
                let dateStr = showDate ? Qt.formatDateTime(clockRoot.now, dateFmt).toLowerCase() : "";
                return (dateStr !== "") ? (dateStr + "  " + timeStr) : timeStr;
            }
            font.family: Theme?.fontFamily ?? "sans-serif"
            font.variableAxes: Theme?.sansAxes ?? ({})
            font.pixelSize: (Theme?.isVertical ?? false) ? 10 : (Theme?.fontSizeMd ?? 14)
            font.weight: Theme?.fontWeightMedium ?? Font.Medium
            color: calPopup.open ? Theme.primary : Theme.on_surface
        }

        // compact weather temp pill on hover when loaded
        Text {
            visible: !(Theme?.isVertical ?? false) && clkMouse.containsMouse && clockRoot.weatherOk
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool useF: (Settings?.weatherUnit || "F").toUpperCase() === "F"
            text: Math.round(useF ? clockRoot.weatherTempF : clockRoot.weatherTempC) + "°" + (useF ? "f" : "c")
            font.family: Theme?.fontMono ?? "monospace"
            font.variableAxes: Theme?.monoAxes ?? ({})
            font.pixelSize: Theme?.fontSizeXs ?? 10
            font.weight: Theme?.monoWeightBold ?? Font.Bold
            color: Theme.primary
        }

        Row {
            visible: !(Theme?.isVertical ?? false) && (typeof TimerService !== "undefined" && TimerService) && (TimerService.timerRunning || TimerService.timerPaused || TimerService.stopwatchRunning)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                id: timerBullet
                anchors.verticalCenter: parent.verticalCenter
                text: "•"
                font.pixelSize: Theme?.fontSizeSm ?? 12
                color: (typeof TimerService !== "undefined" && TimerService?.timerRunning && TimerService?.timerRemaining <= 30) ? Theme.error : Theme.primary
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: typeof TimerService !== "undefined" && (TimerService?.timerRunning ?? false) && ((TimerService?.timerRemaining ?? 999) <= 30)
                    NumberAnimation { from: 1.0; to: 0.2; duration: 400; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.2; to: 1.0; duration: 400; easing.type: Easing.InOutQuad }
                    onRunningChanged: {
                        if (!running) timerBullet.opacity = 1.0;
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (typeof TimerService === "undefined" || !TimerService) return "";
                    if (TimerService.stopwatchRunning) return TimerService.stopwatchDisplay;
                    let prefix = TimerService.pomodoroActive ? (TimerService.pomodoroPhase === "focus" ? "p·" : "b·") : "";
                    return prefix + TimerService.timerDisplay;
                }
                font.family: Theme?.fontMono ?? "monospace"
                font.variableAxes: Theme?.monoAxes ?? ({})
                font.pixelSize: Theme?.fontSizeSm ?? 11
                font.weight: Theme?.monoWeightBold ?? Font.Bold
                color: (typeof TimerService !== "undefined" && TimerService?.timerRunning && TimerService?.timerRemaining <= 30) ? Theme.error : Theme.primary
            }
        }
    }

    function updatePopupPos() {
        let pt = clockRoot.mapToItem(null, 0, 0);
        if (pt) {
            calPopup.targetRelativeX = pt.x + (clockRoot.width / 2);
            calPopup.targetRelativeY = pt.y + (clockRoot.height / 2);
        }
    }

    HoverFlyoutHandler {
        popup: calPopup
        mouseArea: clkMouse
        updatePos: () => clockRoot.updatePopupPos()
    }

    MouseArea {
        id: clkMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                clockRoot.updatePopupPos();
                if (!calPopup.open) {
                    calPopup.pinned = true;
                    calPopup.open = true;
                } else if (!calPopup.pinned) {
                    calPopup.pinned = true;
                } else {
                    calPopup.pinned = false;
                    calPopup.open = false;
                }
                if (calPopup.open) {
                    clockRoot.selectedYear = clockRoot.todayYear;
                    clockRoot.selectedMonth = clockRoot.todayMonth;
                    clockRoot.focusedYear = clockRoot.todayYear;
                    clockRoot.focusedMonth = clockRoot.todayMonth;
                    clockRoot.focusedDay = clockRoot.todayDate;
                }
            } else if (mouse.button === Qt.RightButton) {
                if (Settings) {
                    Settings.showBarDate = !Settings.showBarDate;
                    if (Settings.showBarDate && (!Settings.dateFormat || Settings.dateFormat === "none")) {
                        Settings.dateFormat = "ddd, MMM d";
                    }
                }
            } else if (mouse.button === Qt.MiddleButton) {
                if (Settings) {
                    let curIs12 = (Settings?.clockFormat && /ap/i.test(Settings.clockFormat)) || (Settings?.clockMilitary === false) || (Settings?.clock24h === false);
                    let nextIs12 = !curIs12;
                    let showSec = Settings?.clockShowSeconds ?? (Settings?.clockFormat && /:ss/i.test(Settings.clockFormat));
                    Settings.clockMilitary = !nextIs12;
                    Settings.clock24h = !nextIs12;
                    Settings.clockFormat = nextIs12 ? (showSec ? "h:mm:ss ap" : "h:mm ap") : (showSec ? "HH:mm:ss" : "HH:mm");
                }
            }
        }

        onWheel: (wheel) => {
            if (wheel.angleDelta.y === 0 || !Settings) return;
            const formats = ["ddd, MMM d", "MMM d, yyyy", "yyyy-MM-dd", "ddd, d MMM", "MM/dd"];
            let idx = formats.indexOf(Settings.dateFormat);
            if (idx === -1) idx = 0;
            idx = wheel.angleDelta.y > 0 ? ((idx + 1) % formats.length) : ((idx - 1 + formats.length) % formats.length);
            Settings.dateFormat = formats[idx];
            Settings.showBarDate = true;
        }
    }

    Connections {
        target: Settings
        function onRequestClockToggle() {
            clockRoot.updatePopupPos();
            calPopup.open = !calPopup.open;
            if (calPopup.open) {
                clockRoot.selectedYear = clockRoot.todayYear;
                clockRoot.selectedMonth = clockRoot.todayMonth;
                clockRoot.focusedYear = clockRoot.todayYear;
                clockRoot.focusedMonth = clockRoot.todayMonth;
                clockRoot.focusedDay = clockRoot.todayDate;
            }
        }
        function onRequestClockOpen() {
            clockRoot.updatePopupPos();
            calPopup.open = true;
            clockRoot.selectedYear = clockRoot.todayYear;
            clockRoot.selectedMonth = clockRoot.todayMonth;
            clockRoot.focusedYear = clockRoot.todayYear;
            clockRoot.focusedMonth = clockRoot.todayMonth;
            clockRoot.focusedDay = clockRoot.todayDate;
        }
        function onRequestClockClose() { calPopup.open = false; }
        function onWeatherLocationChanged() { clockRoot.refreshWeather(true); }
    }

    PopupPanel {
        id: calPopup
        wantsFocus: true
        cardWidth: 380
        cardHeight: Math.max(Theme?.popupMinHeight ?? 300, Math.min(Theme?.popupMaxHeight ?? 680, calContentLayout.implicitHeight + ((Theme?.popupPadding ?? 12) * 2)))
        targetRelativeX: {
            let pt = clockRoot.mapToItem(null, 0, 0);
            return pt ? (pt.x + (clockRoot.width / 2)) : (clockRoot.x + (clockRoot.width / 2));
        }
        targetRelativeY: {
            let pt = clockRoot.mapToItem(null, 0, 0);
            return pt ? (pt.y + (clockRoot.height / 2)) : (clockRoot.y + (clockRoot.height / 2));
        }
        property string activeTab: "calendar"
        onOpenChanged: {
            if (open) {
                activeTab = "calendar";
                clockRoot.editingCity = false;
                clockRoot.refreshWeather(false);
            }
        }

        content: ColumnLayout {
            id: calContentLayout
            anchors.fill: parent
            spacing: Theme?.widgetSpacing ?? 8

            // Segmented Header Tab Bar
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme?.radiusPill ?? 16
                    color: calPopup.activeTab === "calendar" ? Theme.primary : Theme.cardBg
                    border.color: calPopup.activeTab === "calendar" ? Theme.primary : Theme.widgetBorder
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: Theme?.iconCalendar ?? "\uE935"
                            font.family: Theme?.fontIcon ?? "sans-serif"
                            font.variableAxes: Theme?.iconAxes ?? ({})
                            font.pixelSize: Theme?.fontSizeSm ?? 12
                            color: calPopup.activeTab === "calendar" ? Theme.on_primary : Theme.on_surface
                        }
                        Text {
                            text: "calendar"
                            font.family: Theme?.fontSans ?? Theme?.fontFamily ?? "sans-serif"
                            font.variableAxes: Theme?.sansAxes ?? ({})
                            font.pixelSize: Theme?.fontSizeSm ?? 12
                            font.weight: Theme?.fontWeightDemiBold ?? Font.DemiBold
                            color: calPopup.activeTab === "calendar" ? Theme.on_primary : Theme.on_surface
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.activeTab = "calendar"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme?.radiusPill ?? 16
                    color: calPopup.activeTab === "timer" ? Theme.primary : Theme.cardBg
                    border.color: calPopup.activeTab === "timer" ? Theme.primary : Theme.widgetBorder
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: Theme?.iconClock ?? "\uEFD6"
                            font.family: Theme?.fontIcon ?? "sans-serif"
                            font.variableAxes: Theme?.iconAxes ?? ({})
                            font.pixelSize: Theme?.fontSizeSm ?? 12
                            color: calPopup.activeTab === "timer" ? Theme.on_primary : Theme.on_surface
                        }
                        Text {
                            text: "timer & pomo"
                            font.family: Theme?.fontSans ?? Theme?.fontFamily ?? "sans-serif"
                            font.variableAxes: Theme?.sansAxes ?? ({})
                            font.pixelSize: Theme?.fontSizeSm ?? 12
                            font.weight: Theme?.fontWeightDemiBold ?? Font.DemiBold
                            color: calPopup.activeTab === "timer" ? Theme.on_primary : Theme.on_surface
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calPopup.activeTab = "timer"
                    }
                }
            }

            // ================= CALENDAR + WEATHER TAB =================
            ColumnLayout {
                id: calendarSection
                Layout.fillWidth: true
                spacing: 8
                visible: calPopup.activeTab === "calendar"

                // Header Date & Live Clock Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: Theme.widgetRadius
                    color: Theme.cardBg
                    border.color: Theme.widgetBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: {
                                    let dFmt = (Settings?.dateFormat && Settings.dateFormat !== "none" && Settings.dateFormat !== "")
                                        ? Settings.dateFormat
                                        : "dddd, MMMM d, yyyy";
                                    return Qt.formatDateTime(clockRoot.now, dFmt).toLowerCase();
                                }
                                font.family: Theme.fontDisplay
                                font.variableAxes: Theme.displayAxes
                                font.pixelSize: Theme.fontSizeSm
                                font.weight: Theme.fontWeightBold
                                color: Theme.on_surface
                            }

                            Text {
                                text: "day " + clockRoot.getDayOfYear(clockRoot.now) + " of " + clockRoot.now.getFullYear()
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: 10
                                color: Theme.on_surface_variant
                            }
                        }

                        ColumnLayout {
                            spacing: 2
                            Layout.alignment: Qt.AlignRight

                            Text {
                                text: {
                                    let is12 = (Settings?.clockFormat && /ap/i.test(Settings.clockFormat)) || (Settings?.clockMilitary === false) || (Settings?.clock24h === false);
                                    return Qt.formatDateTime(clockRoot.now, is12 ? "h:mm:ss ap" : "HH:mm:ss").toLowerCase();
                                }
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: Theme.fontSizeLg
                                font.weight: Theme.monoWeightBold
                                color: Theme.primary
                                Layout.alignment: Qt.AlignRight
                            }

                            Text {
                                text: "click day for offset"
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 9
                                color: Theme.on_surface_variant
                                Layout.alignment: Qt.AlignRight
                            }
                        }
                    }
                }

                // Weather Card (Open-Meteo live temp, hi/low, unit toggle & city override)
                Rectangle {
                    visible: Settings?.weatherEnabled ?? true
                    Layout.fillWidth: true
                    implicitHeight: weatherCol.implicitHeight + 16
                    radius: Theme.widgetRadius
                    color: Theme.cardBg
                    border.color: Theme.widgetBorder
                    border.width: 1

                    ColumnLayout {
                        id: weatherCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: !clockRoot.editingCity

                            Text {
                                text: clockRoot.weatherIsDay ? Theme.iconSun : Theme.iconMoon
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeLg
                                color: Theme.primary
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    spacing: 6
                                    Text {
                                        readonly property bool useF: (Settings?.weatherUnit || "F").toUpperCase() === "F"
                                        text: clockRoot.weatherOk
                                            ? (Math.round(useF ? clockRoot.weatherTempF : clockRoot.weatherTempC) + "°" + (useF ? "F" : "C") + "  •  " + clockRoot.weatherCond)
                                            : (clockRoot.weatherLoading ? "fetching weather..." : (clockRoot.weatherError || "weather offline"))
                                        font.family: Theme.fontFamily
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_surface
                                    }
                                }

                                Text {
                                    visible: clockRoot.weatherOk
                                    readonly property bool useF: (Settings?.weatherUnit || "F").toUpperCase() === "F"
                                    text: {
                                        let fl = Math.round(useF ? clockRoot.weatherFeelsF : clockRoot.weatherFeelsC);
                                        let hi = Math.round(useF ? clockRoot.weatherHighF : clockRoot.weatherHighC);
                                        let lo = Math.round(useF ? clockRoot.weatherLowF : clockRoot.weatherLowC);
                                        return clockRoot.weatherCity.toLowerCase() + " • feels " + fl + "° • h " + hi + "° / l " + lo + "° • " + clockRoot.weatherHumidity + "% rh";
                                    }
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: 9
                                    color: Theme.on_surface_variant
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                height: 22
                                implicitWidth: 26
                                radius: Theme.radiusPill
                                color: Theme.surface_container_highest
                                border.color: Theme.widgetBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "°" + (Settings?.weatherUnit || "F").toUpperCase()
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: 9
                                    font.weight: Theme.monoWeightBold
                                    color: Theme.primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!Settings) return;
                                        Settings.weatherUnit = (Settings.weatherUnit || "F").toUpperCase() === "F" ? "C" : "F";
                                    }
                                }
                            }

                            IconButton {
                                icon: Theme.iconEdit
                                iconSize: 11
                                implicitWidth: 22
                                implicitHeight: 22
                                tooltip: "set weather city"
                                onClicked: {
                                    cityInput.text = Settings?.weatherLocation || "";
                                    clockRoot.editingCity = true;
                                    cityInput.forceActiveFocus();
                                }
                            }

                            IconButton {
                                icon: Theme.iconRefresh
                                iconSize: 11
                                implicitWidth: 22
                                implicitHeight: 22
                                tooltip: "refresh weather"
                                onClicked: clockRoot.refreshWeather(true)
                            }
                        }

                        RowLayout {
                            visible: clockRoot.editingCity
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                height: 28
                                radius: Theme.radiusSm
                                color: Theme.surface_container_highest
                                border.color: cityInput.activeFocus ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                TextInput {
                                    id: cityInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_surface
                                    selectByMouse: true

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "city name (leave blank for auto ip)..."
                                        font: parent.font
                                        color: Theme.on_surface_disabled
                                        visible: parent.text === ""
                                    }

                                    onAccepted: {
                                        if (Settings) Settings.weatherLocation = text.trim();
                                        clockRoot.editingCity = false;
                                        clockRoot.refreshWeather(true);
                                    }
                                }
                            }

                            IconButton {
                                icon: Theme.iconCheck
                                iconSize: 11
                                implicitWidth: 24
                                implicitHeight: 24
                                onClicked: {
                                    if (Settings) Settings.weatherLocation = cityInput.text.trim();
                                    clockRoot.editingCity = false;
                                    clockRoot.refreshWeather(true);
                                }
                            }

                            IconButton {
                                icon: Theme.iconClose
                                iconSize: 11
                                implicitWidth: 24
                                implicitHeight: 24
                                onClicked: clockRoot.editingCity = false
                            }
                        }
                    }
                }

                // Month Navigation Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        id: monthTitle
                        text: Qt.formatDate(new Date(clockRoot.selectedYear, clockRoot.selectedMonth, 1), "MMMM yyyy").toLowerCase()
                        font.family: Theme.fontDisplay
                        font.variableAxes: Theme.displayAxes
                        font.pixelSize: Theme.fontSizeMd
                        font.weight: Theme.fontWeightBold
                        color: Theme.primary
                    }

                    Item { Layout.fillWidth: true }

                    IconButton {
                        icon: Theme?.iconChevronLeft ?? "◀"
                        iconSize: Theme?.fontSizeSm ?? 12
                        tooltip: "previous month"
                        onClicked: {
                            if (clockRoot.selectedMonth === 0) {
                                clockRoot.selectedMonth = 11;
                                clockRoot.selectedYear--;
                            } else {
                                clockRoot.selectedMonth--;
                            }
                        }
                    }

                    IconButton {
                        icon: Theme?.iconClock ?? "\uEFD6"
                        iconSize: Theme?.fontSizeSm ?? 12
                        tooltip: "jump to today"
                        onClicked: {
                            clockRoot.selectedYear = clockRoot.todayYear;
                            clockRoot.selectedMonth = clockRoot.todayMonth;
                            clockRoot.focusedYear = clockRoot.todayYear;
                            clockRoot.focusedMonth = clockRoot.todayMonth;
                            clockRoot.focusedDay = clockRoot.todayDate;
                        }
                    }

                    IconButton {
                        icon: Theme?.iconChevronRight ?? "▶"
                        iconSize: Theme?.fontSizeSm ?? 12
                        tooltip: "next month"
                        onClicked: {
                            if (clockRoot.selectedMonth === 11) {
                                clockRoot.selectedMonth = 0;
                                clockRoot.selectedYear++;
                            } else {
                                clockRoot.selectedMonth++;
                            }
                        }
                    }

                    IconButton {
                        icon: Theme?.iconClose ?? "✕"
                        iconSize: Theme?.fontSizeSm ?? 12
                        tooltip: "close calendar"
                        onClicked: calPopup.open = false
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.widgetBorder
                }

                // Days of Week Headers
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: ["mo", "tu", "we", "th", "fr", "sa", "su"]

                        delegate: Item {
                            required property string modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 20

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 10
                                font.weight: Theme.monoWeightBold
                                color: (index >= 5) ? Theme.primary : Theme.on_surface_variant
                            }
                        }
                    }
                }

                // Interactive Calendar Grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 4

                    Repeater {
                        model: {
                            let y = clockRoot.selectedYear;
                            let m = clockRoot.selectedMonth;
                            let firstDay = new Date(y, m, 1).getDay();
                            let offset = (firstDay === 0) ? 6 : firstDay - 1;
                            let daysInMonth = new Date(y, m + 1, 0).getDate();
                            let prevDaysInMonth = new Date(y, m, 0).getDate();
                            let cells = [];

                            for (let i = offset - 1; i >= 0; i--) {
                                cells.push({ day: prevDaysInMonth - i, currentMonth: false, isToday: false });
                            }
                            for (let d = 1; d <= daysInMonth; d++) {
                                let isToday = (y === clockRoot.todayYear && m === clockRoot.todayMonth && d === clockRoot.todayDate);
                                cells.push({ day: d, currentMonth: true, isToday: isToday });
                            }
                            let totalCells = (cells.length > 35) ? 42 : 35;
                            let nextDay = 1;
                            while (cells.length < totalCells) {
                                cells.push({ day: nextDay++, currentMonth: false, isToday: false });
                            }
                            return cells;
                        }

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isSelected: modelData.currentMonth
                                && clockRoot.focusedYear === clockRoot.selectedYear
                                && clockRoot.focusedMonth === clockRoot.selectedMonth
                                && clockRoot.focusedDay === modelData.day
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 30
                            radius: Theme.radiusSm
                            color: (modelData.currentMonth && modelData.isToday)
                                ? Theme.primary
                                : (isSelected ? Theme.primary_overlay : (dayMouse.containsMouse ? Theme.surface_container_highest : "transparent"))

                            border.color: (modelData.currentMonth && modelData.isToday)
                                ? Theme.primary
                                : (isSelected ? Theme.primary : "transparent")
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 11
                                font.weight: (modelData.isToday || isSelected) ? Theme.monoWeightBold : Theme.monoWeightRegular
                                color: (modelData.currentMonth && modelData.isToday)
                                    ? Theme.on_primary
                                    : (isSelected ? Theme.primary : (modelData.currentMonth ? Theme.on_surface : Theme.on_surface_disabled))
                            }

                            MouseArea {
                                id: dayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!modelData.currentMonth) {
                                        if (modelData.day > 15) {
                                            if (clockRoot.selectedMonth === 0) {
                                                clockRoot.selectedMonth = 11;
                                                clockRoot.selectedYear--;
                                            } else {
                                                clockRoot.selectedMonth--;
                                            }
                                        } else {
                                            if (clockRoot.selectedMonth === 11) {
                                                clockRoot.selectedMonth = 0;
                                                clockRoot.selectedYear++;
                                            } else {
                                                clockRoot.selectedMonth++;
                                            }
                                        }
                                        clockRoot.focusedYear = clockRoot.selectedYear;
                                        clockRoot.focusedMonth = clockRoot.selectedMonth;
                                        clockRoot.focusedDay = modelData.day;
                                    } else {
                                        clockRoot.focusedYear = clockRoot.selectedYear;
                                        clockRoot.focusedMonth = clockRoot.selectedMonth;
                                        clockRoot.focusedDay = modelData.day;
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.widgetBorder
                }

                // Footer: Selected day offset / progress + QuickNotes shortcut
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 6
                        radius: 3
                        color: Theme.surface_container_highest
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * Math.min(1.0, Math.max(0.0, ((clockRoot.now.getHours() * 60 + clockRoot.now.getMinutes()) / 1440)))
                            radius: 3
                            color: Theme.primary
                        }
                    }

                    Text {
                        text: clockRoot.getSelectedDayHint()
                        font.family: Theme.fontMono
                        font.variableAxes: Theme.monoAxes
                        font.pixelSize: 9
                        color: Theme.on_surface_variant
                    }

                    Rectangle {
                        height: 20
                        implicitWidth: noteLinkTxt.implicitWidth + 10
                        radius: Theme.radiusPill
                        color: noteLinkMouse.containsMouse ? Theme.primary_overlay : Theme.cardBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        Text {
                            id: noteLinkTxt
                            anchors.centerIn: parent
                            text: "notes"
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: 9
                            font.weight: Theme.monoWeightBold
                            color: Theme.primary
                        }

                        MouseArea {
                            id: noteLinkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                calPopup.open = false;
                                if (Settings?.requestQuickNotesOpen) Settings.requestQuickNotesOpen();
                            }
                        }
                    }
                }
            }

            // ================= TIMER, POMODORO & STOPWATCH TAB =================
            ColumnLayout {
                id: timerSection
                Layout.fillWidth: true
                spacing: 12
                visible: calPopup.activeTab === "timer"

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: timerInnerLayout.implicitHeight + 24
                    radius: Theme.radiusMd
                    color: Theme.cardBg
                    border.color: (typeof TimerService !== "undefined" && TimerService?.pomodoroActive)
                        ? Theme.primary
                        : Theme.widgetBorder
                    border.width: 1

                    ColumnLayout {
                        id: timerInnerLayout
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        // Pomodoro phase banner when active
                        RowLayout {
                            Layout.fillWidth: true
                            visible: typeof TimerService !== "undefined" && TimerService?.pomodoroActive

                            Text {
                                text: TimerService?.pomodoroPhase === "break" ? "pomodoro break" : "pomodoro focus"
                                font.family: Theme.fontDisplay
                                font.variableAxes: Theme.displayAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: Theme.primary
                                Layout.fillWidth: true
                            }

                            Text {
                                text: "cycle #" + ((TimerService?.pomodoroCycles ?? 0) + 1)
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.pixelSize: 10
                                font.weight: Theme.monoWeightBold
                                color: Theme.on_surface_variant
                            }
                        }

                        // Giant Digital Readout
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: {
                                if (typeof TimerService === "undefined" || !TimerService) return "00:00";
                                if (TimerService.stopwatchRunning || TimerService.stopwatchElapsed > 0) {
                                    return TimerService.stopwatchDisplay;
                                }
                                return TimerService.timerDisplay;
                            }
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.pixelSize: 44
                            font.weight: Theme.monoWeightBold
                            color: (typeof TimerService !== "undefined" && TimerService?.timerRunning && TimerService.timerRemaining <= 30) ? Theme.error : Theme.primary
                        }

                        // Live timer progress bar
                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: Theme.surface_container_highest
                            visible: typeof TimerService !== "undefined" && (TimerService?.timerRunning || TimerService?.timerPaused)
                            clip: true

                            Rectangle {
                                width: parent.width * (TimerService?.timerProgress ?? 0)
                                height: parent.height
                                radius: 3
                                color: Theme.primary
                                Behavior on width { NumberAnimation { duration: 250 } }
                            }
                        }

                        // Quick Preset Chips (+30s, +1m, +5m, +15m, +25m)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: [
                                    { label: "+30s", sec: 30 },
                                    { label: "+1m", sec: 60 },
                                    { label: "+5m", sec: 300 },
                                    { label: "+15m", sec: 900 },
                                    { label: "+25m", sec: 1500 }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: Theme.radiusPill
                                    color: pChipMouse.containsMouse ? Theme.primary_overlay : Theme.surface_container_highest
                                    border.color: pChipMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.family: Theme.fontMono
                                        font.variableAxes: Theme.monoAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: Theme.monoWeightBold
                                        color: Theme.on_surface
                                    }
                                    MouseArea {
                                        id: pChipMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: TimerService?.addTimerSeconds(modelData.sec)
                                    }
                                }
                            }
                        }

                        // Custom duration input + Pomodoro toggle
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                height: 30
                                radius: Theme.radiusSm
                                color: Theme.surface_container_highest
                                border.color: customMinInput.activeFocus ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                TextInput {
                                    id: customMinInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_surface
                                    selectByMouse: true

                                    Text {
                                        anchors.fill: parent
                                        verticalAlignment: Text.AlignVCenter
                                        text: "custom mins (or mm:ss)..."
                                        font: parent.font
                                        color: Theme.on_surface_disabled
                                        visible: parent.text === ""
                                    }

                                    onAccepted: {
                                        let raw = text.trim();
                                        let sec = 0;
                                        if (raw.indexOf(":") !== -1) {
                                            let p = raw.split(":");
                                            sec = (parseInt(p[0], 10) || 0) * 60 + (parseInt(p[1], 10) || 0);
                                        } else {
                                            sec = Math.round((parseFloat(raw) || 0) * 60);
                                        }
                                        if (sec > 0) {
                                            TimerService?.startTimer(sec);
                                            text = "";
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                height: 30
                                implicitWidth: pomoTxt.implicitWidth + 16
                                radius: Theme.radiusPill
                                color: (TimerService?.pomodoroActive ?? false) ? Theme.primary : Theme.surface_container_highest
                                border.color: (TimerService?.pomodoroActive ?? false) ? Theme.primary : Theme.widgetBorder
                                border.width: 1

                                Text {
                                    id: pomoTxt
                                    anchors.centerIn: parent
                                    text: (TimerService?.pomodoroActive ?? false) ? "stop pomo" : "pomo 25/5"
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: 10
                                    font.weight: Theme.monoWeightBold
                                    color: (TimerService?.pomodoroActive ?? false) ? Theme.on_primary : Theme.primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (TimerService?.pomodoroActive) TimerService.stopPomodoro();
                                        else TimerService?.startPomodoro(Settings?.pomodoroFocusMin ?? 25, Settings?.pomodoroBreakMin ?? 5);
                                    }
                                }
                            }
                        }

                        // Start / Pause / Reset Controls
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 112
                                Layout.preferredHeight: 38
                                radius: 19
                                color: (typeof TimerService !== "undefined" && (TimerService?.timerRunning || TimerService?.stopwatchRunning)) ? Theme.error : Theme.primary

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: (typeof TimerService !== "undefined" && (TimerService?.timerRunning || TimerService?.stopwatchRunning)) ? (Theme?.iconPause ?? "\uE034") : (Theme?.iconPlay ?? "\uE037")
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: Theme.fontSizeSm
                                        color: Theme.on_primary
                                    }
                                    Text {
                                        text: (typeof TimerService !== "undefined" && (TimerService?.timerRunning || TimerService?.stopwatchRunning)) ? "pause" : "start"
                                        font.family: Theme.fontSans
                                        font.variableAxes: Theme.sansAxes
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_primary
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof TimerService === "undefined" || !TimerService) return;
                                        if (TimerService.stopwatchRunning || TimerService.stopwatchElapsed > 0) {
                                            TimerService.toggleStopwatch();
                                        } else {
                                            TimerService.toggleTimer();
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 92
                                Layout.preferredHeight: 38
                                radius: 19
                                color: Theme.surface_container_highest
                                border.color: Theme.widgetBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "reset"
                                    font.family: Theme.fontSans
                                    font.variableAxes: Theme.sansAxes
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.on_surface
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof TimerService === "undefined" || !TimerService) return;
                                        TimerService.resetTimer();
                                        TimerService.resetStopwatch();
                                    }
                                }
                            }
                        }

                        // Mode Switcher: Timer vs Stopwatch
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 180
                            Layout.preferredHeight: 28
                            radius: 14
                            color: Theme.surface_container_high

                            Text {
                                anchors.centerIn: parent
                                text: (typeof TimerService !== "undefined" && (TimerService?.stopwatchRunning || TimerService?.stopwatchElapsed > 0)) ? "switch to timer" : "switch to stopwatch"
                                font.family: Theme.fontSans
                                font.variableAxes: Theme.sansAxes
                                font.weight: Theme.fontWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.primary
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof TimerService === "undefined" || !TimerService) return;
                                    if (TimerService.stopwatchRunning || TimerService.stopwatchElapsed > 0) {
                                        TimerService.resetStopwatch();
                                    } else {
                                        TimerService.resetTimer();
                                        TimerService.startStopwatch();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
