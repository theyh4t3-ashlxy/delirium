// WelcomeWizard.qml
import QtQuick
import QtQuick.Layouts
import ".."
import "../controls"
import "../services"
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

    readonly property string brainShellSrc: (Quickshell.env("HOME") || "") + "/.local/src/Brain_Shell"
    readonly property string brainShellConf: (Quickshell.env("HOME") || "") + "/.config/Brain_Shell"
    readonly property string detectScript: Qt.resolvedUrl("../scripts/detect-brainshell.zsh").toString().replace(/^file:\/\//, "")
    readonly property string cliPath: (Quickshell.env("HOME") || "") + "/.local/bin/cli"

    property bool brainShellDetected: false
    property bool isInstallingBrainShell: false
    property string activeShellName: "quickshell"

    // user preferences read from ~/.config/zsh/user_prefs.conf
    property string prefEditor: "micro"
    property string prefFm: "yazi"

    FileView {
        id: userPrefsView
        path: (Quickshell.env("XDG_CONFIG_HOME") || ((Quickshell.env("HOME") || "") + "/.config")) + "/zsh/user_prefs.conf"
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
        path: (Quickshell.env("XDG_CACHE_HOME") || ((Quickshell.env("HOME") || "") + "/.cache")) + "/current_shell"
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
        NumberAnimation { duration: Theme.animNormal; easing.type: Theme.animEasing }
    }

    function close() {
        if (Settings) {
            Settings.showWelcomeWizard = false;
            if (Settings.markWelcomeCompleted) Settings.markWelcomeCompleted();
            Settings.welcomeWizardStep = 0;
            if (Settings.save) Settings.save();
        }
        root.open = false;
    }

    function completeSetup() {
        if (Settings) {
            if (Settings.markWelcomeCompleted) Settings.markWelcomeCompleted();
            Settings.showWelcomeWizard = false;
            Settings.welcomeWizardStep = 0;
            if (Settings.save) Settings.save();
        }
        root.open = false;
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
            color: Theme.scrim
            opacity: 0.78 * root.animReveal

            MouseArea {
                anchors.fill: parent
                onClicked: root.close()
            }
        }

        // ambient glow behind the wizard card when accent-glow or cyber-neon is active
        Rectangle {
            visible: Theme.isAccentGlow || Theme.isCyberNeon
            anchors.fill: dialogCard
            anchors.margins: -6
            radius: dialogCard.radius + 6
            color: Theme.alpha(Theme.primary, 0.22)
        }

        Rectangle {
            id: dialogCard
            width: Math.min(860, Math.max(660, (root.screen?.width ?? 1920) - 80))
            height: Math.min(650, Math.max(520, (root.screen?.height ?? 1080) - 100))
            anchors.centerIn: parent

            radius: Theme.radiusLg
            color: Theme.popupBg
            border.color: Theme.popupBorderColor
            border.width: Theme.popupBorderWidth
            clip: true

            scale: 0.94 + (0.06 * root.animReveal)
            Behavior on scale {
                NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance }
            }
            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
            Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

            Rectangle {
                visible: Theme.isGlass
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.glassHighlight
                z: 5
            }

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.popupPadding
                spacing: Theme.popupSpacing

                // header matching BarStudio, ScreenCapture, Bluetooth, and NetworkStatus
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 36
                        height: 36
                        radius: Theme.radiusMd
                        color: Theme.primary_overlay
                        border.color: Theme.alpha(Theme.primary, 0.35)
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: Theme.iconDistro
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeLg
                            color: Theme.primary
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
                                font.weight: Font.Bold
                                color: Theme.on_surface
                            }

                            Rectangle {
                                height: 20
                                implicitWidth: sysTag.implicitWidth + 12
                                radius: Theme.radiusPill
                                color: Theme.primary_overlay
                                border.color: Theme.alpha(Theme.primary, 0.4)
                                border.width: 1

                                Text {
                                    id: sysTag
                                    anchors.centerIn: parent
                                    text: "thinkpad t16 • nixos"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                }
                            }
                        }

                        Text {
                            text: Theme.getFlavor("system", "keyboard-driven layer-shell environment configured for zero mouse friction")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface_variant
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        height: 24
                        implicitWidth: stepBadgeTxt.implicitWidth + 14
                        radius: Theme.radiusPill
                        color: Theme.widgetBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        Text {
                            id: stepBadgeTxt
                            anchors.centerIn: parent
                            text: "step " + (root.currentStep + 1) + "/" + root.totalSteps
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeXs
                            font.weight: Font.Bold
                            color: Theme.primary
                        }
                    }

                    Rectangle {
                        width: 28
                        height: 28
                        radius: Theme.radiusPill
                        color: closeMouse.containsMouse ? Theme.error_overlay : Theme.pillBg
                        border.color: closeMouse.containsMouse ? Theme.error : Theme.widgetBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        Text {
                            anchors.centerIn: parent
                            text: Theme.iconClose
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeXs
                            color: closeMouse.containsMouse ? Theme.error : Theme.on_surface
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

                // step breadcrumbs pill bar
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: Theme.radiusMd
                    color: Theme.cardBg
                    border.color: Theme.cardBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 6

                        Repeater {
                            model: [
                                { label: "1. palette", step: 0, icon: Theme.iconPalette },
                                { label: "2. shell & style", step: 1, icon: Theme.iconGrid },
                                { label: "3. dev & thermals", step: 2, icon: Theme.iconTerminal },
                                { label: "4. keybinds", step: 3, icon: Theme.iconKeyboard },
                                { label: "5. launchpad", step: 4, icon: Theme.iconSparkles }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Theme.radiusPill
                                readonly property bool isActive: root.currentStep === modelData.step
                                readonly property bool isPassed: root.currentStep > modelData.step

                                color: isActive
                                    ? Theme.primary
                                    : (isPassed ? Theme.primary_overlay : (stepMouse.containsMouse ? Theme.widgetHover : "transparent"))
                                border.color: isActive || isPassed ? Theme.primary : "transparent"
                                border.width: isPassed && !isActive ? 1 : 0

                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 5

                                    Text {
                                        visible: !Theme.isTextIconSet
                                        text: isPassed ? Theme.iconCheck : modelData.icon
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeXs
                                        color: isActive ? Theme.on_primary : (isPassed ? Theme.primary : Theme.on_surface_variant)
                                    }

                                    Text {
                                        text: modelData.label
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        font.weight: isActive ? Font.Bold : Font.DemiBold
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
                }

                // scrollable step content area
                Flickable {
                    id: flickBody
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: stepContentCol.implicitHeight + 8
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    ColumnLayout {
                        id: stepContentCol
                        width: flickBody.width
                        spacing: Theme.popupSpacing

                        // step 0: matugen & live palette extraction
                        ColumnLayout {
                            visible: root.currentStep === 0
                            Layout.fillWidth: true
                            spacing: Theme.popupSpacing

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: swatchCol.implicitHeight + 24
                                radius: Theme.radiusMd
                                color: Theme.cardBg
                                border.color: Theme.cardBorder
                                border.width: 1
                                clip: true

                                Rectangle {
                                    visible: Theme.isGlass
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 1
                                    color: Theme.glassHighlight
                                }

                                ColumnLayout {
                                    id: swatchCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: Theme.iconPalette
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                                            color: Theme.primary
                                        }

                                        Text {
                                            text: "ambient matugen palette"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Font.Bold
                                            color: Theme.on_surface
                                        }

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: "vibrancy " + Math.round((Theme.wallpaperVibrancy ?? 0.5) * 100) + "%"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.primary
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        wrapMode: Text.Wrap
                                        text: "every surface, border, and concave scoop is extracted in real-time from your wallpaper. roll a new wallpaper below to watch the whole desktop morph."
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeXs
                                        color: Theme.on_surface_variant
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: [
                                                { name: "primary", c: Theme.primary, onC: Theme.on_primary },
                                                { name: "secondary", c: Theme.secondary, onC: Theme.on_secondary },
                                                { name: "tertiary", c: Theme.tertiary, onC: Theme.on_tertiary },
                                                { name: "surface", c: Theme.surface_container_high, onC: Theme.on_surface },
                                                { name: "outline", c: Theme.outline, onC: Theme.surface },
                                                { name: "error", c: Theme.error, onC: Theme.on_error }
                                            ]

                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                height: 54
                                                radius: Theme.radiusSm
                                                color: modelData.c
                                                border.color: Theme.widgetBorder
                                                border.width: 1

                                                Behavior on color { ColorAnimation { duration: Theme.animNormal; easing.type: Theme.animColorEasing } }

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 2
                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: modelData.name
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontSizeXs
                                                        font.weight: Font.Bold
                                                        color: modelData.onC
                                                    }
                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: String(modelData.c).toUpperCase()
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontSizeXs
                                                        color: Theme.alpha(modelData.onC, 0.78)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.popupSpacing

                                // dark / light mode card
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: modeCol.implicitHeight + 24
                                    radius: Theme.radiusMd
                                    color: Theme.cardBg
                                    border.color: Theme.cardBorder
                                    border.width: 1

                                    ColumnLayout {
                                        id: modeCol
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        Text {
                                            text: "appearance mode"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Font.Bold
                                            color: Theme.on_surface
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            Repeater {
                                                model: [
                                                    { id: "dark", label: "dark mode", icon: Theme.iconMoon },
                                                    { id: "light", label: "light mode", icon: Theme.iconSun }
                                                ]

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    readonly property bool isSel: (Settings?.matugenMode ?? "dark") === modelData.id
                                                    Layout.fillWidth: true
                                                    height: 30
                                                    radius: Theme.radiusPill
                                                    color: isSel ? Theme.primary : (modeChipMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                                    border.color: isSel ? Theme.primary : Theme.widgetBorder
                                                    border.width: 1

                                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                                    RowLayout {
                                                        anchors.centerIn: parent
                                                        spacing: 5
                                                        Text {
                                                            visible: !Theme.isTextIconSet
                                                            text: modelData.icon
                                                            font.family: Theme.fontIcon
                                                            font.pixelSize: Theme.fontSizeXs
                                                            color: parent.parent.isSel ? Theme.on_primary : Theme.primary
                                                        }
                                                        Text {
                                                            text: modelData.label
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: Theme.fontSizeXs
                                                            font.weight: parent.parent.isSel ? Font.Bold : Font.DemiBold
                                                            color: parent.parent.isSel ? Theme.on_primary : Theme.on_surface
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: modeChipMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (typeof WallpaperService !== "undefined" && WallpaperService?.setMode) {
                                                                WallpaperService.setMode(modelData.id);
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // wallpaper dice roller card
                                Rectangle {
                                    Layout.preferredWidth: 220
                                    implicitHeight: modeCol.implicitHeight + 24
                                    radius: Theme.radiusMd
                                    color: rollMouse.pressed ? Theme.primary : (rollMouse.containsMouse ? Theme.primary_overlay : Theme.cardBg)
                                    border.color: Theme.primary
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        RowLayout {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 6
                                            Text {
                                                text: Theme.iconShuffle
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                                                color: rollMouse.pressed ? Theme.on_primary : Theme.primary
                                            }
                                            Text {
                                                text: "roll wallpaper"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Font.Bold
                                                color: rollMouse.pressed ? Theme.on_primary : Theme.primary
                                            }
                                        }

                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            text: "randomize wallpaper + palette"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: rollMouse.pressed ? Theme.on_primary : Theme.on_surface_variant
                                        }
                                    }

                                    MouseArea {
                                        id: rollMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (typeof WallpaperService !== "undefined" && WallpaperService?.applyRandomWallpaper) {
                                                WallpaperService.applyRandomWallpaper("all", "");
                                            }
                                        }
                                    }
                                }
                            }

                            // matugen scheme selector card
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: schemeCol.implicitHeight + 24
                                radius: Theme.radiusMd
                                color: Theme.cardBg
                                border.color: Theme.cardBorder
                                border.width: 1

                                ColumnLayout {
                                    id: schemeCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Text {
                                        text: "matugen color algorithm"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Font.Bold
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
                                                readonly property bool isSel: (Settings?.matugenScheme ?? "scheme-tonal-spot") === modelData.id
                                                Layout.fillWidth: true
                                                height: 30
                                                radius: Theme.radiusPill
                                                color: isSel ? Theme.primary : (schemeMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                                border.color: isSel ? Theme.primary : Theme.widgetBorder
                                                border.width: 1

                                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.name
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: isSel ? Font.Bold : Font.DemiBold
                                                    color: isSel ? Theme.on_primary : Theme.on_surface
                                                }

                                                MouseArea {
                                                    id: schemeMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (typeof WallpaperService !== "undefined" && WallpaperService?.setScheme) {
                                                            WallpaperService.setScheme(modelData.id);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // step 1: dual-engine shell + live bar style & icon set pickers
                        ColumnLayout {
                            visible: root.currentStep === 1
                            Layout.fillWidth: true
                            spacing: Theme.popupSpacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.popupSpacing

                                // quickshell classic card
                                Rectangle {
                                    id: qsCard
                                    Layout.fillWidth: true
                                    implicitHeight: qsCol.implicitHeight + 24
                                    radius: Theme.radiusMd
                                    readonly property bool isSelected: root.activeShellName === "quickshell"
                                    color: isSelected ? Theme.primary_overlay : Theme.cardBg
                                    border.color: isSelected ? Theme.primary : Theme.cardBorder
                                    border.width: isSelected ? 2 : 1

                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    ColumnLayout {
                                        id: qsCol
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            spacing: 8
                                            Text {
                                                text: Theme.iconSparkles
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                                                color: Theme.primary
                                            }
                                            Text {
                                                text: "quickshell classic"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Font.Bold
                                                color: Theme.on_surface
                                                Layout.fillWidth: true
                                            }
                                            Rectangle {
                                                height: 20
                                                implicitWidth: qsStateTxt.implicitWidth + 12
                                                radius: Theme.radiusPill
                                                color: qsCard.isSelected ? Theme.primary : Theme.widgetBg
                                                Text {
                                                    id: qsStateTxt
                                                    anchors.centerIn: parent
                                                    text: qsCard.isSelected ? "active" : "standby"
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: Font.Bold
                                                    color: qsCard.isSelected ? Theme.on_primary : Theme.on_surface_variant
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            text: "lightweight layer-shell bar with concave screen scoops, hardware widgets, media controls, and fast flyout cards."
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.on_surface_variant
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 30
                                            radius: Theme.radiusPill
                                            color: qsCard.isSelected ? Theme.primary : (qsBtnMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                            border.color: qsCard.isSelected ? Theme.primary : Theme.widgetBorder
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsCard.isSelected ? "currently engaged" : "switch to quickshell"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Font.Bold
                                                color: qsCard.isSelected ? Theme.on_primary : Theme.on_surface
                                            }

                                            MouseArea {
                                                id: qsBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.selectShell("quickshell")
                                            }
                                        }
                                    }
                                }

                                // brain_shell cyberdeck card
                                Rectangle {
                                    id: bsCard
                                    Layout.fillWidth: true
                                    implicitHeight: bsCol.implicitHeight + 24
                                    radius: Theme.radiusMd
                                    readonly property bool isSelected: root.activeShellName === "brain_shell"
                                    color: isSelected ? Theme.primary_overlay : Theme.cardBg
                                    border.color: isSelected ? Theme.primary : Theme.cardBorder
                                    border.width: isSelected ? 2 : 1

                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                    ColumnLayout {
                                        id: bsCol
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            spacing: 8
                                            Text {
                                                text: Theme.iconWorkspaces
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeMd
                                                color: Theme.tertiary
                                            }
                                            Text {
                                                text: "brain_shell cyberdeck"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Font.Bold
                                                color: Theme.on_surface
                                                Layout.fillWidth: true
                                            }
                                            Rectangle {
                                                height: 20
                                                implicitWidth: bsStateTxt.implicitWidth + 12
                                                radius: Theme.radiusPill
                                                color: bsCard.isSelected ? Theme.primary : Theme.widgetBg
                                                Text {
                                                    id: bsStateTxt
                                                    anchors.centerIn: parent
                                                    text: bsCard.isSelected ? "active" : "standby"
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: Font.Bold
                                                    color: bsCard.isSelected ? Theme.on_primary : Theme.on_surface_variant
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            text: "cyberdeck workspace with built-in kanban board, quick notes, telemetry radar, and multi-monitor dashboard."
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.on_surface_variant
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 30
                                            radius: Theme.radiusPill
                                            color: bsCard.isSelected ? Theme.primary : (bsBtnMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                            border.color: bsCard.isSelected ? Theme.primary : Theme.widgetBorder
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: bsCard.isSelected
                                                    ? "currently engaged"
                                                    : (root.isInstallingBrainShell ? "cloning repo..." : (root.brainShellDetected ? "switch to brain_shell" : "clone brain_shell"))
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeXs
                                                font.weight: Font.Bold
                                                color: bsCard.isSelected ? Theme.on_primary : Theme.on_surface
                                            }

                                            MouseArea {
                                                id: bsBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.brainShellDetected) {
                                                        root.selectShell("brain_shell");
                                                    } else if (!root.isInstallingBrainShell) {
                                                        root.isInstallingBrainShell = true;
                                                        brainInstallProc.running = true;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // live bar style + icon set customizer right inside the wizard
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: styleCol.implicitHeight + 24
                                radius: Theme.radiusMd
                                color: Theme.cardBg
                                border.color: Theme.cardBorder
                                border.width: 1

                                ColumnLayout {
                                    id: styleCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Text {
                                        text: "bar shader style & icon set"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSizeSm
                                        font.weight: Font.Bold
                                        color: Theme.on_surface
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Repeater {
                                            model: [
                                                { id: "glass", label: "glass" },
                                                { id: "glass-frost", label: "frost" },
                                                { id: "bento-floating", label: "bento" },
                                                { id: "cyber-neon", label: "cyber-neon" },
                                                { id: "accent-glow", label: "glow" },
                                                { id: "pure-black", label: "oled black" },
                                                { id: "regular", label: "solid" }
                                            ]

                                            delegate: Rectangle {
                                                required property var modelData
                                                readonly property bool isSel: Theme.barStyle === modelData.id
                                                Layout.fillWidth: true
                                                height: 30
                                                radius: Theme.radiusPill
                                                color: isSel ? Theme.primary : (bsStyleMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                                border.color: isSel ? Theme.primary : Theme.widgetBorder
                                                border.width: 1

                                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: isSel ? Font.Bold : Font.DemiBold
                                                    color: isSel ? Theme.on_primary : Theme.on_surface
                                                }

                                                MouseArea {
                                                    id: bsStyleMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (Settings) {
                                                            Settings.barStyle = modelData.id;
                                                            if (Settings.save) Settings.save();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Text {
                                            text: "icons:"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.on_surface_variant
                                        }

                                        Repeater {
                                            model: [
                                                { id: "material", label: "material" },
                                                { id: "nerd", label: "nerd font" },
                                                { id: "kaomoji", label: "kaomoji (•̀ᴗ•́)و" },
                                                { id: "text", label: "minimal text" }
                                            ]

                                            delegate: Rectangle {
                                                required property var modelData
                                                readonly property bool isSel: Theme.iconSet === modelData.id
                                                Layout.fillWidth: true
                                                height: 30
                                                radius: Theme.radiusPill
                                                color: isSel ? Theme.primary : (icSetMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                                border.color: isSel ? Theme.primary : Theme.widgetBorder
                                                border.width: 1

                                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    font.family: Theme.fontFamily
                                                    font.pixelSize: Theme.fontSizeXs
                                                    font.weight: isSel ? Font.Bold : Font.DemiBold
                                                    color: isSel ? Theme.on_primary : Theme.on_surface
                                                }

                                                MouseArea {
                                                    id: icSetMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (Settings) {
                                                            Settings.iconSet = modelData.id;
                                                            if (Settings.save) Settings.save();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // step 2: developer flow & hardware telemetry
                        ColumnLayout {
                            visible: root.currentStep === 2
                            Layout.fillWidth: true
                            spacing: Theme.popupSpacing

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.popupSpacing

                                // preferred editor card
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: edCol.implicitHeight + 24
                                    radius: Theme.radiusMd
                                    color: Theme.cardBg
                                    border.color: Theme.cardBorder
                                    border.width: 1

                                    ColumnLayout {
                                        id: edCol
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            spacing: 6
                                            Text {
                                                text: Theme.iconEdit
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                                                color: Theme.primary
                                            }
                                            Text {
                                                text: "preferred config editor"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Font.Bold
                                                color: Theme.on_surface
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Repeater {
                                                model: [
                                                    { id: "micro", label: "micro" },
                                                    { id: "nvim", label: "neovim" }
                                                ]

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    readonly property bool isSel: root.prefEditor === modelData.id
                                                    Layout.fillWidth: true
                                                    height: 30
                                                    radius: Theme.radiusPill
                                                    color: isSel ? Theme.primary : (edChipMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                                    border.color: isSel ? Theme.primary : Theme.widgetBorder
                                                    border.width: 1

                                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.label
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontSizeXs
                                                        font.weight: isSel ? Font.Bold : Font.DemiBold
                                                        color: isSel ? Theme.on_primary : Theme.on_surface
                                                    }

                                                    MouseArea {
                                                        id: edChipMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.saveEditor(modelData.id)
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            text: root.prefEditor === "nvim" ? "modal editing with treesitter & telescope" : "intuitive terminal editor with standard keybinds"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.on_surface_variant
                                        }
                                    }
                                }

                                // preferred file manager card
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: fmCol.implicitHeight + 24
                                    radius: Theme.radiusMd
                                    color: Theme.cardBg
                                    border.color: Theme.cardBorder
                                    border.width: 1

                                    ColumnLayout {
                                        id: fmCol
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            spacing: 6
                                            Text {
                                                text: Theme.iconFolder
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                                                color: Theme.primary
                                            }
                                            Text {
                                                text: "preferred file manager"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Font.Bold
                                                color: Theme.on_surface
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Repeater {
                                                model: ["yazi", "dolphin", "nautilus"]
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    readonly property bool isSel: root.prefFm === modelData
                                                    Layout.fillWidth: true
                                                    height: 30
                                                    radius: Theme.radiusPill
                                                    color: isSel ? Theme.primary : (fmChipMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                                                    border.color: isSel ? Theme.primary : Theme.widgetBorder
                                                    border.width: 1

                                                    Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontSizeXs
                                                        font.weight: isSel ? Font.Bold : Font.DemiBold
                                                        color: isSel ? Theme.on_primary : Theme.on_surface
                                                    }

                                                    MouseArea {
                                                        id: fmChipMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.saveFileManager(modelData)
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            wrapMode: Text.Wrap
                                            text: root.prefFm === "yazi" ? "blazing terminal file manager with image previews" : "native desktop graphical file explorer"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.on_surface_variant
                                        }
                                    }
                                }
                            }

                            // hardware telemetry card
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: hwCol.implicitHeight + 24
                                radius: Theme.radiusMd
                                color: Theme.cardBg
                                border.color: Theme.cardBorder
                                border.width: 1

                                ColumnLayout {
                                    id: hwCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: Theme.iconThermo
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                                            color: Theme.primary
                                        }
                                        Text {
                                            text: "hardware telemetry & thermal containment"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Font.Bold
                                            color: Theme.on_surface
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Repeater {
                                            model: [
                                                { title: "fan control", val: "daemon active (fanctl)" },
                                                { title: "charge threshold", val: "75% - 80% (safe)" },
                                                { title: "energy policy", val: "dynamic hwp p-state" }
                                            ]

                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                height: 54
                                                radius: Theme.radiusSm
                                                color: Theme.widgetBg
                                                border.color: Theme.widgetBorder
                                                border.width: 1

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 2
                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: modelData.title
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontSizeXs
                                                        color: Theme.on_surface_variant
                                                    }
                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: modelData.val
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontSizeXs
                                                        font.weight: Font.Bold
                                                        color: Theme.primary
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // step 3: interactive keybind playground
                        ColumnLayout {
                            visible: root.currentStep === 3
                            Layout.fillWidth: true
                            spacing: Theme.popupSpacing

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: bindCol.implicitHeight + 24
                                radius: Theme.radiusMd
                                color: Theme.cardBg
                                border.color: Theme.cardBorder
                                border.width: 1

                                ColumnLayout {
                                    id: bindCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: Theme.iconKeyboard
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                                            color: Theme.primary
                                        }
                                        Text {
                                            text: "core keybindings • click any row to test live"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Font.Bold
                                            color: Theme.on_surface
                                        }
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        rowSpacing: 8
                                        columnSpacing: 8

                                        Repeater {
                                            model: [
                                                { bind: "SUPER + D", desc: "app launcher", act: "launcher", note: "fuzzy search binaries" },
                                                { bind: "SUPER + E", desc: "file manager", act: "files", note: "yazi / desktop explorer" },
                                                { bind: "SUPER + V", desc: "clipboard", act: "clipboard", note: "cliphist frecency picker" },
                                                { bind: "SUPER + W", desc: "roll wallpaper", act: "wallpaper", note: "instant matugen refresh" },
                                                { bind: "SUPER + N", desc: "notifications", act: "notifs", note: "alert center & dnd" },
                                                { bind: "SUPER + ESC", desc: "power menu", act: "powermenu", note: "lock, reboot, shutdown" }
                                            ]

                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 54
                                                radius: Theme.radiusSm
                                                color: testMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg
                                                border.color: testMouse.containsMouse ? Theme.primary : Theme.widgetBorder
                                                border.width: 1

                                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    anchors.rightMargin: 10
                                                    spacing: 10

                                                    Rectangle {
                                                        height: 26
                                                        implicitWidth: keyTxt.implicitWidth + 14
                                                        radius: Theme.radiusSm
                                                        color: Theme.primary_overlay
                                                        border.color: Theme.alpha(Theme.primary, 0.4)
                                                        border.width: 1

                                                        Text {
                                                            id: keyTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.bind
                                                            font.family: Theme.fontMono
                                                            font.pixelSize: Theme.fontSizeXs
                                                            font.weight: Font.Bold
                                                            color: Theme.primary
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 1
                                                        Text {
                                                            text: modelData.desc
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: Theme.fontSizeSm
                                                            font.weight: Font.Bold
                                                            color: Theme.on_surface
                                                        }
                                                        Text {
                                                            text: modelData.note
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: Theme.fontSizeXs
                                                            color: Theme.on_surface_variant
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                    }

                                                    Rectangle {
                                                        height: 24
                                                        implicitWidth: testLbl.implicitWidth + 14
                                                        radius: Theme.radiusPill
                                                        color: testMouse.containsMouse ? Theme.primary : "transparent"
                                                        border.color: Theme.primary
                                                        border.width: 1

                                                        Text {
                                                            id: testLbl
                                                            anchors.centerIn: parent
                                                            text: "test"
                                                            font.family: Theme.fontMono
                                                            font.pixelSize: Theme.fontSizeXs
                                                            font.weight: Font.Bold
                                                            color: testMouse.containsMouse ? Theme.on_primary : Theme.primary
                                                        }
                                                    }
                                                }

                                                MouseArea {
                                                    id: testMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: Quickshell.execDetached([root.cliPath, modelData.act])
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 36
                                        radius: Theme.radiusSm
                                        color: Theme.widgetBg
                                        border.color: Theme.widgetBorder
                                        border.width: 1

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            Text {
                                                text: Theme.iconKeyboard
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                                                color: Theme.primary
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: "home-row window navigation: SUPER + I (up), SUPER + K (down), SUPER + J (left), SUPER + L (right)"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontSizeXs
                                                color: Theme.on_surface_variant
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // step 4: launchpad & terminal commands
                        ColumnLayout {
                            visible: root.currentStep === 4
                            Layout.fillWidth: true
                            spacing: Theme.popupSpacing

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: launchCol.implicitHeight + 24
                                radius: Theme.radiusMd
                                color: Theme.cardBg
                                border.color: Theme.cardBorder
                                border.width: 1

                                ColumnLayout {
                                    id: launchCol
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    RowLayout {
                                        spacing: 6
                                        Text {
                                            text: Theme.iconTerminal
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeXs : Theme.fontSizeSm
                                            color: Theme.primary
                                        }
                                        Text {
                                            text: "launchpad • 4 terminal commands to rule the desktop"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Font.Bold
                                            color: Theme.on_surface
                                        }
                                    }

                                    GridLayout {
                                        Layout.fillWidth: true
                                        columns: 2
                                        rowSpacing: 8
                                        columnSpacing: 8

                                        Repeater {
                                            model: [
                                                { cmd: "cli", title: "shell & action hub", desc: "switch shells, reload, or toggle popups" },
                                                { cmd: "config", title: "modular dotfiles", desc: "jump into nvim, hyprland.lua, zsh, or nix" },
                                                { cmd: "fanctl", title: "hardware thermals", desc: "inspect fan rpm, curves, or thermal locks" },
                                                { cmd: "wp", title: "wallpaper & matugen", desc: "roll wallpapers and regenerate schemes" }
                                            ]

                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                implicitHeight: 58
                                                radius: Theme.radiusSm
                                                color: Theme.widgetBg
                                                border.color: Theme.widgetBorder
                                                border.width: 1

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 12
                                                    anchors.rightMargin: 12
                                                    spacing: 12

                                                    Rectangle {
                                                        height: 28
                                                        implicitWidth: cmdTxt.implicitWidth + 16
                                                        radius: Theme.radiusSm
                                                        color: Theme.primary_overlay
                                                        border.color: Theme.alpha(Theme.primary, 0.4)
                                                        border.width: 1

                                                        Text {
                                                            id: cmdTxt
                                                            anchors.centerIn: parent
                                                            text: modelData.cmd
                                                            font.family: Theme.fontMono
                                                            font.pixelSize: Theme.fontSizeSm
                                                            font.weight: Font.Bold
                                                            color: Theme.primary
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 2
                                                        Text {
                                                            text: modelData.title
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: Theme.fontSizeSm
                                                            font.weight: Font.Bold
                                                            color: Theme.on_surface
                                                        }
                                                        Text {
                                                            text: modelData.desc
                                                            font.family: Theme.fontFamily
                                                            font.pixelSize: Theme.fontSizeXs
                                                            color: Theme.on_surface_variant
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // big launch button
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 46
                                        radius: Theme.radiusMd
                                        color: ctaMouse.pressed ? Theme.widgetActive : (ctaMouse.containsMouse ? Theme.alpha(Theme.primary, 0.88) : Theme.primary)
                                        border.color: Theme.primary
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 8
                                            Text {
                                                text: Theme.iconSparkles
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.isTextIconSet ? Theme.fontSizeSm : Theme.fontSizeMd
                                                color: Theme.on_primary
                                            }
                                            Text {
                                                text: "lock configuration & engage desktop"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSm
                                                font.weight: Font.Bold
                                                color: Theme.on_primary
                                            }
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
                            }
                        }
                    }
                }

                // footer navigation bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        visible: root.currentStep > 0
                        height: 32
                        implicitWidth: backRow.implicitWidth + 20
                        radius: Theme.radiusPill
                        color: backMouse.containsMouse ? Theme.pillHover : Theme.pillBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        RowLayout {
                            id: backRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: Theme.iconChevronLeft
                                font.family: Theme.fontIcon
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.on_surface
                            }
                            Text {
                                text: "previous"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Font.DemiBold
                                color: Theme.on_surface
                            }
                        }

                        MouseArea {
                            id: backMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.currentStep > 0) root.currentStep--
                        }
                    }

                    Text {
                        text: Theme.kaoCozy + " arrow keys (←/→) or enter to navigate"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeXs
                        color: Theme.on_surface_variant
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        height: 32
                        implicitWidth: nextRow.implicitWidth + 22
                        radius: Theme.radiusPill
                        color: nextMouse.containsMouse ? Theme.alpha(Theme.primary, 0.88) : Theme.primary

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        RowLayout {
                            id: nextRow
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                text: root.currentStep === root.totalSteps - 1 ? "finish & launch" : "next step"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Font.Bold
                                color: Theme.on_primary
                            }
                            Text {
                                text: root.currentStep === root.totalSteps - 1 ? Theme.iconCheck : Theme.iconChevronRight
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
