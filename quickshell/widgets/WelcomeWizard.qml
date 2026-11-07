import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    property bool open: false
    readonly property bool isOpen: root.open

    function checkShouldOpen() {
        if (!Settings?.showWelcomeWizard) {
            root.open = false;
            return;
        }

        const focused = Hyprland?.focusedMonitor?.name;
        if (focused && root.screen?.name) {
            root.open = (root.screen.name === focused);
            return;
        }

        root.open = (!root.screen || (Quickshell.screens && Quickshell.screens.length > 0 && root.screen === Quickshell.screens[0]));
    }

    Connections {
        target: Settings
        function onShowWelcomeWizardChanged() {
            if (Settings?.showWelcomeWizard) {
                root.checkShouldOpen();
            } else {
                root.open = false;
            }
        }
        function onRequestWelcomeToggle() {
            if (root.open) {
                root.open = false;
            } else {
                root.checkShouldOpen();
            }
        }
        function onRequestWelcomeOpen() {
            root.checkShouldOpen();
        }
        function onRequestWelcomeClose() {
            root.open = false;
        }
    }

    Connections {
        target: Hyprland
        function onFocusedMonitorChanged() {
            if (root.open) {
                root.checkShouldOpen();
            }
        }
    }

    property int currentStep: Settings?.welcomeWizardStep ?? 0
    onCurrentStepChanged: {
        if (Settings && Settings.welcomeWizardStep !== currentStep) {
            Settings.welcomeWizardStep = currentStep;
        }
    }
    readonly property int totalSteps: 5

    readonly property string brainShellSrc: Quickshell.env("HOME") + "/.local/src/Brain_Shell"
    readonly property string brainShellConf: Quickshell.env("HOME") + "/.config/Brain_Shell"
    readonly property string detectScript: Qt.resolvedUrl("../scripts/detect-brainshell.zsh").toString().replace(/^file:\/\//, "")
    readonly property string cliPath: Quickshell.env("HOME") + "/.local/bin/cli"

    property bool brainShellDetected: false
    property bool isInstallingBrainShell: false
    property string activeShellName: "quickshell"

    // user preferences read from ~/.config/zsh/user_prefs.conf
    property string prefEditor: "micro"
    property string prefFm: "yazi"

    FileView {
        id: userPrefsView
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/zsh/user_prefs.conf"
        watchChanges: true
        printErrors: false
        onLoaded: {
            let txt = text();
            let em = txt.match(/^PREFERRED_EDITOR=(.*)$/m);
            if (em) root.prefEditor = em[1].trim();
            let fm = txt.match(/^PREFERRED_FILE_MANAGER=(.*)$/m);
            if (fm) root.prefFm = fm[1].trim();
        }
    }

    FileView {
        id: currentShellView
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/current_shell"
        watchChanges: true
        printErrors: false
        onLoaded: {
            let txt = text().trim();
            if (txt) root.activeShellName = txt;
        }
    }

    Process {
        id: brainDetectProc
        command: [root.detectScript, root.brainShellSrc, root.brainShellConf]
        running: false
        onExited: (code) => {
            root.brainShellDetected = (code === 0);
        }
    }

    Process {
        id: brainInstallProc
        command: ["git", "clone", "-b", "dev", "https://github.com/Brainitech/Brain_Shell.git", root.brainShellSrc]
        running: false
        onExited: (code) => {
            root.isInstallingBrainShell = false;
            root.checkBrainShell();
        }
    }

    function checkBrainShell() {
        brainDetectProc.running = false;
        brainDetectProc.running = true;
    }

    function saveEditor(choice) {
        root.prefEditor = choice;
        Quickshell.execDetached(["zsh", "-c", "source ~/.local/share/dotfiles/zsh/settings.zsh; settings editor " + choice]);
    }

    function saveFileManager(choice) {
        root.prefFm = choice;
        Quickshell.execDetached(["zsh", "-c", "source ~/.local/share/dotfiles/zsh/settings.zsh; settings fm " + choice]);
    }

    function selectShell(shellName) {
        root.activeShellName = shellName;
        Quickshell.execDetached(["cli", "shell", shellName]);
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: animReveal > 0.001
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:popup:welcome"
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    property real animReveal: isOpen ? 1.0 : 0.0
    Behavior on animReveal {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    function close() {
        Settings.showWelcomeWizard = false;
        Settings.markWelcomeCompleted();
        Settings.welcomeWizardStep = 0;
    }

    function completeSetup() {
        Settings.markWelcomeCompleted();
        Settings.showWelcomeWizard = false;
        Settings.welcomeWizardStep = 0;
        Quickshell.execDetached([
            "notify-send",
            "-a", "quickshell",
            "-i", "preferences-desktop-theme",
            "desktop initialized",
            "setup payload locked. remember: `cli` controls the shell without a mouse."
        ]);
    }

    onIsOpenChanged: {
        if (isOpen) {
            currentStep = 0;
            checkBrainShell();
            focusTrap.forceActiveFocus();
        }
    }

    Component.onCompleted: {
        checkBrainShell();
        if (Settings?.showWelcomeWizard) {
            checkShouldOpen();
        }
    }

    Item {
        id: focusTrap
        anchors.fill: parent
        focus: root.isOpen
        opacity: root.animReveal

        Keys.onEscapePressed: root.close()
        Keys.onRightPressed: if (root.currentStep < root.totalSteps - 1) root.currentStep++
        Keys.onLeftPressed: if (root.currentStep > 0) root.currentStep--
        Keys.onReturnPressed: if (root.currentStep === root.totalSteps - 1) root.completeSetup()

        Rectangle {
            anchors.fill: parent
            color: Theme.scrim ?? "#000000"
            opacity: 0.88 * root.animReveal

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        Rectangle {
            id: dialogCard
            width: Math.min(880, Math.max(680, (root.screen?.width ?? 1920) - 80))
            height: Math.min(680, Math.max(540, (root.screen?.height ?? 1080) - 100))
            anchors.centerIn: parent

            radius: Math.max(16, Settings?.globalRounding ?? 16)
            color: Theme.surface_container ?? Theme.cardBackground
            border.color: Theme.outline_variant ?? Theme.cardBorder
            border.width: 1
            clip: true

            scale: 0.92 + (0.08 * root.animReveal)
            Behavior on scale {
                NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
            }

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Dialog Header
                Rectangle {
                    id: dialogHeader
                    Layout.fillWidth: true
                    implicitHeight: 64
                    color: Theme.surface_container_high
                    border.width: 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 16
                        spacing: 12

                        Rectangle {
                            width: 38
                            height: 38
                            radius: Theme.radiusMd
                            color: Theme.primary_container

                            Text {
                                anchors.centerIn: parent
                                text: Theme.iconSparkles
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontSizeLg
                                color: Theme.on_primary_container
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                spacing: 8
                                Text {
                                    text: "welcome to lost"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeMd
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.on_surface
                                }
                                Rectangle {
                                    height: 18
                                    width: sysTag.implicitWidth + 10
                                    radius: Theme.radiusPill
                                    color: Theme.primary_overlay
                                    Text {
                                        id: sysTag
                                        anchors.centerIn: parent
                                        text: "thinkpad t16 // nixos"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeXs - 1
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.primary
                                    }
                                }
                            }

                            Text {
                                text: "keyboard-driven layer-shell environment configured for zero mouse friction."
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.on_surface_variant
                            }
                        }

                        // Close button
                        Rectangle {
                            width: 32
                            height: 32
                            radius: Theme.radiusPill
                            color: closeMouse.containsMouse ? Theme.surface_container_highest : "transparent"
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            Text {
                                anchors.centerIn: parent
                                text: Theme.iconClose
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontSizeSm
                                color: closeMouse.containsMouse ? Theme.primary : Theme.on_surface_variant
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.close()
                            }
                        }
                    }
                }

                // Step Breadcrumbs Navigation Bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    color: Theme.surface_container_lowest

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 6

                        Repeater {
                            model: [
                                { label: "1. ambient matugen", step: 0, icon: Theme.iconPalette },
                                { label: "2. dual shell", step: 1, icon: Theme.iconLayers },
                                { label: "3. developer flow", step: 2, icon: Theme.iconTerminal },
                                { label: "4. action playground", step: 3, icon: Theme.iconKeyboard },
                                { label: "5. launchpad", step: 4, icon: Theme.iconRocket }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 30
                                radius: Theme.radiusPill
                                readonly property bool isActive: root.currentStep === modelData.step
                                readonly property bool isPassed: root.currentStep > modelData.step

                                color: isActive
                                    ? Theme.primary
                                    : (isPassed ? Theme.alpha(Theme.primary, 0.16) : (stepMouse.containsMouse ? Theme.surface_container_high : "transparent"))

                                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        visible: isPassed
                                        text: Theme.iconCheck
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeXs - 1
                                        color: Theme.primary
                                    }

                                    Text {
                                        text: modelData.label
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: isActive ? Theme.fontWeightBold : Theme.fontWeightMedium
                                        color: isActive ? Theme.on_primary : (isPassed ? Theme.primary : Theme.on_surface_variant)
                                    }
                                }

                                MouseArea {
                                    id: stepMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentStep = modelData.step
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.alpha(Theme.outline_variant, 0.4)
                    }
                }

                // Step Content Area (Scrollable Flickable)
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Flickable {
                        id: flickBody
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: stepContentCol.implicitHeight + 40
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        ColumnLayout {
                            id: stepContentCol
                            width: parent.width - 48
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 14

                            Item { height: 6 }

                            // ==========================================
                            // STEP 0: AMBIENT MATUGEN & PALETTE ENGINE
                            // ==========================================
                            ColumnLayout {
                                visible: root.currentStep === 0
                                Layout.fillWidth: true
                                spacing: 16

                                ColumnLayout {
                                    spacing: 4
                                    Text {
                                        text: "ambient matugen palette"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLg
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_surface
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        text: "every border, background, and accent in this shell is extracted in real-time from your wallpaper using Material You algorithms. change the wallpaper, and the whole desktop smoothly morphs."
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        color: Theme.on_surface_variant
                                    }
                                }

                                // Live Palette Swatches Strip
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: swatchCol.implicitHeight + 24
                                    radius: Theme.radiusMd
                                    color: Theme.surface_container_high
                                    border.color: Theme.alpha(Theme.outline_variant, 0.5)
                                    border.width: 1

                                    ColumnLayout {
                                        id: swatchCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        RowLayout {
                                            Text {
                                                text: "live extracted tokens (Theme.qml)"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Theme.fontWeightBold
                                                color: Theme.primary
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: "vibrancy: " + Math.round((Theme.wallpaperVibrancy ?? 0.5) * 100) + "%"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontSizeXs - 1
                                                color: Theme.on_surface_variant
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Repeater {
                                                model: [
                                                    { name: "primary", c: Theme.primary, onC: Theme.on_primary },
                                                    { name: "secondary", c: Theme.secondary, onC: Theme.on_secondary },
                                                    { name: "tertiary", c: Theme.tertiary, onC: Theme.on_tertiary },
                                                    { name: "container", c: Theme.surface_container_high, onC: Theme.on_surface },
                                                    { name: "outline", c: Theme.outline, onC: Theme.surface },
                                                    { name: "error", c: Theme.error, onC: Theme.on_error }
                                                ]

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    height: 56
                                                    radius: Theme.radiusSm
                                                    color: modelData.c
                                                    border.color: Theme.alpha(Theme.outline_variant, 0.3)
                                                    border.width: 1

                                                    ColumnLayout {
                                                        anchors.centerIn: parent
                                                        spacing: 2
                                                        Text {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            text: modelData.name
                                                            font.family: Theme.fontMono
                                                            font.pixelSize: Theme.fontSizeXs - 1
                                                            font.weight: Theme.fontWeightBold
                                                            color: modelData.onC
                                                        }
                                                        Text {
                                                            anchors.horizontalCenter: parent.horizontalCenter
                                                            text: String(modelData.c).toUpperCase()
                                                            font.family: Theme.fontMono
                                                            font.pixelSize: Theme.fontSizeXs - 2
                                                            color: Theme.alpha(modelData.onC, 0.75)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Interactive Palette Controls: Mode, Scheme & Dice Roller
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    // Dark/Light Switcher Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 74
                                        radius: Theme.radiusSm
                                        color: Theme.surface_container_high
                                        border.color: Theme.alpha(Theme.outline_variant, 0.5)
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text { text: "appearance mode"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Theme.fontWeightBold; color: Theme.on_surface }
                                                Text { text: "pure dark mode vs crisp light mode"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs - 1; color: Theme.on_surface_variant }
                                            }

                                            RowLayout {
                                                spacing: 6

                                                Rectangle {
                                                    width: 72
                                                    height: 32
                                                    radius: Theme.radiusPill
                                                    readonly property bool isDark: Settings.matugenMode === "dark"
                                                    color: isDark ? Theme.primary : Theme.surface_container_lowest
                                                    border.color: isDark ? "transparent" : Theme.outline_variant
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "dark"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: Theme.fontSizeXs
                                                        font.weight: Theme.fontWeightBold
                                                        color: parent.isDark ? Theme.on_primary : Theme.on_surface
                                                    }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: WallpaperService.setMode("dark") }
                                                }

                                                Rectangle {
                                                    width: 72
                                                    height: 32
                                                    radius: Theme.radiusPill
                                                    readonly property bool isLight: Settings.matugenMode === "light"
                                                    color: isLight ? Theme.primary : Theme.surface_container_lowest
                                                    border.color: isLight ? "transparent" : Theme.outline_variant
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "light"
                                                        font.family: Theme.fontFamily
                                                        font.pixelSize: Theme.fontSizeXs
                                                        font.weight: Theme.fontWeightBold
                                                        color: parent.isLight ? Theme.on_primary : Theme.on_surface
                                                    }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: WallpaperService.setMode("light") }
                                                }
                                            }
                                        }
                                    }

                                    // Wallpaper Dice Roller Button (Proves live morphing!)
                                    Rectangle {
                                        width: 190
                                        implicitHeight: 74
                                        radius: Theme.radiusSm
                                        color: rollMouse.containsMouse ? Theme.primary_container : Theme.surface_container_high
                                        border.color: Theme.primary
                                        border.width: 1
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            RowLayout {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                spacing: 6
                                                Text { text: Theme.iconDice ?? "󰑐"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontSizeMd; color: Theme.primary }
                                                Text { text: "roll wallpaper"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Theme.fontWeightBold; color: Theme.primary }
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "randomize palette live"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs - 2
                                                color: Theme.on_surface_variant
                                            }
                                        }

                                        MouseArea {
                                            id: rollMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                WallpaperService.applyRandomWallpaper("all", "");
                                            }
                                        }
                                    }
                                }

                                // Scheme Selector Pills
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 64
                                    radius: Theme.radiusSm
                                    color: Theme.surface_container_high
                                    border.color: Theme.alpha(Theme.outline_variant, 0.5)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        Text {
                                            text: "scheme variant:"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.on_surface
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Repeater {
                                                model: [
                                                    { id: "scheme-tonal-spot", name: "tonal-spot" },
                                                    { id: "scheme-vibrant", name: "vibrant" },
                                                    { id: "scheme-expressive", name: "expressive" },
                                                    { id: "scheme-neutral", name: "neutral" },
                                                    { id: "scheme-fidelity", name: "fidelity" }
                                                ]

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    height: 30
                                                    radius: Theme.radiusPill
                                                    readonly property bool isCur: Settings.matugenScheme === modelData.id
                                                    color: isCur ? Theme.primary : (sMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_lowest)
                                                    border.color: isCur ? "transparent" : Theme.outline_variant
                                                    border.width: 1
                                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.name
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontSizeXs - 1
                                                        font.weight: isCur ? Theme.fontWeightBold : Theme.fontWeightMedium
                                                        color: isCur ? Theme.on_primary : Theme.on_surface
                                                    }

                                                    MouseArea {
                                                        id: sMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: WallpaperService.setScheme(modelData.id)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ==========================================
                            // STEP 1: DUAL-ENGINE SHELL ARCHITECTURE
                            // ==========================================
                            ColumnLayout {
                                visible: root.currentStep === 1
                                Layout.fillWidth: true
                                spacing: 14

                                ColumnLayout {
                                    spacing: 4
                                    Text {
                                        text: "dual-engine shell architecture"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLg
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_surface
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        text: "this system contains two specialized desktop environments you can seamlessly swap between with `cli shell` or `SUPER + C`."
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        color: Theme.on_surface_variant
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    // Quickshell Classic Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: qsCol.implicitHeight + 28
                                        radius: Theme.radiusMd
                                        readonly property bool isSelected: root.activeShellName === "quickshell"
                                        color: isSelected ? Theme.surface_container_high : Theme.surface_container_low
                                        border.color: isSelected ? Theme.primary : Theme.outline_variant
                                        border.width: isSelected ? 2 : 1
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        ColumnLayout {
                                            id: qsCol
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 8

                                            RowLayout {
                                                Text { text: "󰄲"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontSizeMd; color: Theme.primary }
                                                Text { text: "quickshell classic"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Theme.fontWeightBold; color: Theme.on_surface }
                                                Item { Layout.fillWidth: true }
                                                Rectangle {
                                                    height: 18
                                                    width: 58
                                                    radius: Theme.radiusPill
                                                    color: isSelected ? Theme.primary : Theme.surface_container_highest
                                                    Text { anchors.centerIn: parent; text: isSelected ? "active" : "standby"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs - 2; font.weight: Theme.fontWeightBold; color: isSelected ? Theme.on_primary : Theme.on_surface_variant }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                wrapMode: Text.Wrap
                                                text: "minimalist, lightweight layer-shell bar with hardware widgets, notification toast overlays, media players, and lightning-fast popup cards."
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.on_surface_variant
                                            }

                                            Item { height: 2 }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 32
                                                radius: Theme.radiusPill
                                                color: isSelected ? Theme.primary : Theme.surface_container_highest
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: isSelected ? "currently engaged" : "set as default"
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: Theme.fontWeightBold
                                                    color: isSelected ? Theme.on_primary : Theme.on_surface
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.selectShell("quickshell")
                                                }
                                            }
                                        }
                                    }

                                    // Brain_Shell Cyberdeck Card
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: bsCol.implicitHeight + 28
                                        radius: Theme.radiusMd
                                        readonly property bool isSelected: root.activeShellName === "brain_shell"
                                        color: isSelected ? Theme.surface_container_high : Theme.surface_container_low
                                        border.color: isSelected ? Theme.primary : Theme.outline_variant
                                        border.width: isSelected ? 2 : 1
                                        Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                        ColumnLayout {
                                            id: bsCol
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            spacing: 8

                                            RowLayout {
                                                Text { text: "󰍹"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontSizeMd; color: Theme.tertiary }
                                                Text { text: "brain_shell cyberdeck"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Theme.fontWeightBold; color: Theme.on_surface }
                                                Item { Layout.fillWidth: true }
                                                Rectangle {
                                                    height: 18
                                                    width: 58
                                                    radius: Theme.radiusPill
                                                    color: isSelected ? Theme.primary : Theme.surface_container_highest
                                                    Text { anchors.centerIn: parent; text: isSelected ? "active" : "standby"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs - 2; font.weight: Theme.fontWeightBold; color: isSelected ? Theme.on_primary : Theme.on_surface_variant }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                wrapMode: Text.Wrap
                                                text: "cyberdeck workspace with a built-in interactive kanban board, quick notes manager, system telemetry radar, and multi-monitor dashboard."
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.on_surface_variant
                                            }

                                            Item { height: 2 }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 32
                                                radius: Theme.radiusPill
                                                color: isSelected ? Theme.primary : Theme.surface_container_highest
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: isSelected ? "currently engaged" : (root.brainShellDetected ? "set as default" : "clone brain_shell")
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: Theme.fontWeightBold
                                                    color: isSelected ? Theme.on_primary : Theme.on_surface
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (root.brainShellDetected) {
                                                            root.selectShell("brain_shell");
                                                        } else {
                                                            root.isInstallingBrainShell = true;
                                                            brainInstallProc.running = true;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Quick CLI Terminal Callout
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 44
                                    radius: Theme.radiusSm
                                    color: Theme.surface_container_lowest
                                    border.color: Theme.alpha(Theme.outline_variant, 0.4)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 10
                                        Text { text: "💡"; font.pixelSize: Theme.fontSizeSm }
                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            text: "you can toggle between them anytime in your terminal with `cli shell` or switch specifically with `cli qs` / `cli bs`."
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.on_surface_variant
                                        }
                                    }
                                }
                            }

                            // ==========================================
                            // STEP 2: DEVELOPER FLOW & HARDWARE TELEMETRY
                            // ==========================================
                            ColumnLayout {
                                visible: root.currentStep === 2
                                Layout.fillWidth: true
                                spacing: 14

                                ColumnLayout {
                                    spacing: 4
                                    Text {
                                        text: "developer flow & hardware"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLg
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_surface
                                    }
                                    Text {
                                        text: "tune your core terminal tools and verify your hardware thermal containment."
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        color: Theme.on_surface_variant
                                    }
                                }

                                // Tool Selection Row: Editor & File Manager
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    // Preferred Editor Picker
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: edCol.implicitHeight + 24
                                        radius: Theme.radiusSm
                                        color: Theme.surface_container_high
                                        border.color: Theme.outline_variant
                                        border.width: 1

                                        ColumnLayout {
                                            id: edCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 8

                                            Text {
                                                text: "preferred config editor"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Theme.fontWeightBold
                                                color: Theme.on_surface
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 32
                                                    radius: Theme.radiusPill
                                                    readonly property bool isPick: root.prefEditor === "micro"
                                                    color: isPick ? Theme.primary : Theme.surface_container_lowest
                                                    border.color: isPick ? "transparent" : Theme.outline_variant
                                                    border.width: 1
                                                    Text { anchors.centerIn: parent; text: "micro"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: parent.isPick ? Theme.on_primary : Theme.on_surface }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveEditor("micro") }
                                                }

                                                Rectangle {
                                                    Layout.fillWidth: true
                                                    height: 32
                                                    radius: Theme.radiusPill
                                                    readonly property bool isPick: root.prefEditor === "nvim"
                                                    color: isPick ? Theme.primary : Theme.surface_container_lowest
                                                    border.color: isPick ? "transparent" : Theme.outline_variant
                                                    border.width: 1
                                                    Text { anchors.centerIn: parent; text: "neovim"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: parent.isPick ? Theme.on_primary : Theme.on_surface }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveEditor("nvim") }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                wrapMode: Text.Wrap
                                                text: root.prefEditor === "nvim" ? "modal editing with treesitter & fzf" : "fast, mouse-friendly terminal editor"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs - 1
                                                color: Theme.on_surface_variant
                                            }
                                        }
                                    }

                                    // Preferred File Manager Picker
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: fmCol.implicitHeight + 24
                                        radius: Theme.radiusSm
                                        color: Theme.surface_container_high
                                        border.color: Theme.outline_variant
                                        border.width: 1

                                        ColumnLayout {
                                            id: fmCol
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 8

                                            Text {
                                                text: "preferred file manager"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Theme.fontWeightBold
                                                color: Theme.on_surface
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Repeater {
                                                    model: ["yazi", "dolphin", "nautilus"]
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        Layout.fillWidth: true
                                                        height: 32
                                                        radius: Theme.radiusPill
                                                        readonly property bool isPick: root.prefFm === modelData
                                                        color: isPick ? Theme.primary : Theme.surface_container_lowest
                                                        border.color: isPick ? "transparent" : Theme.outline_variant
                                                        border.width: 1
                                                        Text { anchors.centerIn: parent; text: modelData; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: parent.isPick ? Theme.on_primary : Theme.on_surface }
                                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveFileManager(modelData) }
                                                    }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                wrapMode: Text.Wrap
                                                text: root.prefFm === "yazi" ? "terminal blitz with vim binds & image preview" : "native desktop gui file explorer"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs - 1
                                                color: Theme.on_surface_variant
                                            }
                                        }
                                    }
                                }

                                // ThinkPad Hardware Containment Live Status
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: hwCol.implicitHeight + 24
                                    radius: Theme.radiusSm
                                    color: Theme.surface_container_high
                                    border.color: Theme.alpha(Theme.primary, 0.4)
                                    border.width: 1

                                    ColumnLayout {
                                        id: hwCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        RowLayout {
                                            Text { text: "󰈐"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontSizeSm; color: Theme.primary }
                                            Text { text: "hardware telemetry & power tuning"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeSm; font.weight: Theme.fontWeightBold; color: Theme.primary }
                                        }

                                        GridLayout {
                                            Layout.fillWidth: true
                                            columns: 3
                                            rowSpacing: 8
                                            columnSpacing: 12

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 48
                                                radius: Theme.radiusSm
                                                color: Theme.surface_container_lowest
                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 2
                                                    Text { text: "fan control"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs - 1; color: Theme.on_surface_variant }
                                                    Text { text: "daemon active (fanctl)"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: Theme.primary }
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 48
                                                radius: Theme.radiusSm
                                                color: Theme.surface_container_lowest
                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 2
                                                    Text { text: "charge threshold"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs - 1; color: Theme.on_surface_variant }
                                                    Text { text: "75% - 80% (safe)"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: Theme.primary }
                                                }
                                            }

                                            Rectangle {
                                                Layout.fillWidth: true
                                                height: 48
                                                radius: Theme.radiusSm
                                                color: Theme.surface_container_lowest
                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 2
                                                    Text { text: "energy policy"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs - 1; color: Theme.on_surface_variant }
                                                    Text { text: "dynamic hwp p-state"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: Theme.primary }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ==========================================
                            // STEP 3: INTERACTIVE ACTION PLAYGROUND
                            // ==========================================
                            ColumnLayout {
                                visible: root.currentStep === 3
                                Layout.fillWidth: true
                                spacing: 14

                                ColumnLayout {
                                    spacing: 4
                                    Text {
                                        text: "interactive action playground"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLg
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_surface
                                    }
                                    Text {
                                        text: "core keybindings for your desktop. click 'test' to trigger any overlay live right now."
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        color: Theme.on_surface_variant
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 10
                                    columnSpacing: 12

                                    Repeater {
                                        model: [
                                            { bind: "WIN + D", desc: "app launcher", act: "launcher", note: "fuzzy search binaries" },
                                            { bind: "WIN + E", desc: "file manager", act: "files", note: "opens yazi in kitty / dolphin" },
                                            { bind: "WIN + V", desc: "clipboard", act: "clipboard", note: "frecency history picker" },
                                            { bind: "WIN + W", desc: "roll wallpaper", act: "wallpaper", note: "instant matugen refresh" },
                                            { bind: "WIN + N", desc: "notifications", act: "notifs", note: "toggle toast center" },
                                            { bind: "WIN + ESC", desc: "power menu", act: "powermenu", note: "reboot, shutdown, sleep" }
                                        ]

                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: 62
                                            radius: Theme.radiusSm
                                            color: Theme.surface_container_high
                                            border.color: Theme.outline_variant
                                            border.width: 1

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 10
                                                spacing: 10

                                                Rectangle {
                                                    height: 28
                                                    width: keyTxt.implicitWidth + 14
                                                    radius: Theme.radiusSm
                                                    color: Theme.surface_container_lowest
                                                    border.color: Theme.outline_variant
                                                    border.width: 1
                                                    Text {
                                                        id: keyTxt
                                                        anchors.centerIn: parent
                                                        text: modelData.bind
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontSizeXs
                                                        font.weight: Theme.fontWeightBold
                                                        color: Theme.primary
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    Text { text: modelData.desc; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: Theme.on_surface }
                                                    Text { text: modelData.note; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs - 2; color: Theme.on_surface_variant }
                                                }

                                                Rectangle {
                                                    height: 26
                                                    width: 48
                                                    radius: Theme.radiusPill
                                                    color: testMouse.containsMouse ? Theme.primary_container : Theme.surface_container_highest
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "test"
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontSizeXs - 1
                                                        font.weight: Theme.fontWeightBold
                                                        color: Theme.primary
                                                    }
                                                    MouseArea {
                                                        id: testMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            Quickshell.execDetached([root.cliPath, modelData.act]);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 40
                                    radius: Theme.radiusSm
                                    color: Theme.surface_container_lowest
                                    border.color: Theme.alpha(Theme.outline_variant, 0.4)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 8
                                        Text { text: "󰌌"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontSizeSm; color: Theme.primary }
                                        Text {
                                            Layout.fillWidth: true
                                            text: "home-row window navigation: WIN + I (up), WIN + K (down), WIN + J (left), WIN + L (right)."
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeXs - 1
                                            color: Theme.on_surface_variant
                                        }
                                    }
                                }
                            }

                            // ==========================================
                            // STEP 4: LAUNCHPAD & TERMINAL POWERHOUSE
                            // ==========================================
                            ColumnLayout {
                                visible: root.currentStep === 4
                                Layout.fillWidth: true
                                spacing: 14

                                ColumnLayout {
                                    spacing: 4
                                    Text {
                                        text: "launchpad // ignition ready"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeLg
                                        font.weight: Theme.fontWeightBold
                                        color: Theme.on_surface
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        text: "configuration payload verified. you're all set. here are the 4 terminal commands to remember so you never need to touch a mouse."
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        color: Theme.on_surface_variant
                                    }
                                }

                                // 4 Core Terminal Commands Matrix
                                GridLayout {
                                    Layout.fillWidth: true
                                    columns: 2
                                    rowSpacing: 10
                                    columnSpacing: 12

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 64
                                        radius: Theme.radiusSm
                                        color: Theme.surface_container_high
                                        border.color: Theme.outline_variant
                                        border.width: 1
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12
                                            Text { text: "`cli`"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSm; font.weight: Theme.fontWeightBold; color: Theme.primary }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text { text: "shell & action hub"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: Theme.on_surface }
                                                Text { text: "switch shells, reload, or dispatch actions"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs - 2; color: Theme.on_surface_variant }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 64
                                        radius: Theme.radiusSm
                                        color: Theme.surface_container_high
                                        border.color: Theme.outline_variant
                                        border.width: 1
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12
                                            Text { text: "`config`"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSm; font.weight: Theme.fontWeightBold; color: Theme.primary }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text { text: "modular dotfiles"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: Theme.on_surface }
                                                Text { text: "jump into nvim, hypr, zsh, or nix sub-modules"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs - 2; color: Theme.on_surface_variant }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 64
                                        radius: Theme.radiusSm
                                        color: Theme.surface_container_high
                                        border.color: Theme.outline_variant
                                        border.width: 1
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12
                                            Text { text: "`fanctl`"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSm; font.weight: Theme.fontWeightBold; color: Theme.primary }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text { text: "hardware thermals"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: Theme.on_surface }
                                                Text { text: "inspect fan rpm, curve profiles, or unstick lock"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs - 2; color: Theme.on_surface_variant }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 64
                                        radius: Theme.radiusSm
                                        color: Theme.surface_container_high
                                        border.color: Theme.outline_variant
                                        border.width: 1
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12
                                            Text { text: "`wp`"; font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeSm; font.weight: Theme.fontWeightBold; color: Theme.primary }
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text { text: "wallpaper hub"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; font.weight: Theme.fontWeightBold; color: Theme.on_surface }
                                                Text { text: "roll random wallpaper + matugen color scheme"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs - 2; color: Theme.on_surface_variant }
                                            }
                                        }
                                    }
                                }

                                // Big Launch Button
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 52
                                    radius: Theme.radiusMd
                                    color: ctaMouse.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 10
                                        Text { text: Theme.iconSparkles; font.family: Theme.fontIcon; font.pixelSize: Theme.fontSizeLg; color: Theme.on_primary }
                                        Text { text: "lock configuration and engage"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeMd; font.weight: Theme.fontWeightBold; color: Theme.on_primary }
                                    }

                                    MouseArea {
                                        id: ctaMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.completeSetup()
                                    }
                                }
                            }

                            Item { height: 10 }
                        }
                    }
                }

                // Dialog Footer with Step Counter and Next/Prev Controls
                Rectangle {
                    id: dialogFooter
                    Layout.fillWidth: true
                    implicitHeight: 56
                    color: Theme.surface_container_high

                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width
                        height: 1
                        color: Theme.alpha(Theme.outline_variant, 0.4)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 12

                        // Back Button
                        Rectangle {
                            visible: root.currentStep > 0
                            width: 88
                            height: 32
                            radius: Theme.radiusPill
                            color: backMouse.containsMouse ? Theme.surface_container_highest : Theme.surface_container_low
                            border.color: Theme.outline_variant
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text { text: Theme.iconChevronLeft; font.family: Theme.fontIcon; font.pixelSize: Theme.fontSizeXs; color: Theme.on_surface }
                                Text { text: "back"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeXs; color: Theme.on_surface }
                            }

                            MouseArea {
                                id: backMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (root.currentStep > 0) root.currentStep--
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Step Indicator Text
                        Text {
                            text: "step " + (root.currentStep + 1) + " of " + root.totalSteps
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface_variant
                        }

                        Item { Layout.fillWidth: true }

                        // Next / Launch Button
                        Rectangle {
                            width: root.currentStep === root.totalSteps - 1 ? 140 : 96
                            height: 34
                            radius: Theme.radiusPill
                            color: nextMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary
                            Behavior on color { ColorAnimation { duration: Theme.animFast } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: root.currentStep === root.totalSteps - 1 ? "launch" : "next"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.on_primary
                                }
                                Text {
                                    text: root.currentStep === root.totalSteps - 1 ? Theme.iconSparkles : Theme.iconChevronRight
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_primary
                                }
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.currentStep < root.totalSteps - 1) {
                                        root.currentStep++;
                                    } else {
                                        root.completeSetup();
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
