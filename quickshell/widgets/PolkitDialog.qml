import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../controls"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.Polkit

Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    QtObject {
        id: dialogState
        property string passwordText: ""
        property string feedbackMessage: ""
        property bool isError: false
        property bool isSubmitting: false
        property bool revealPassword: false
        property bool showDetails: false
        property bool peekBehind: false
        property string copiedKey: ""
        property bool capsLockActive: false
        property int attemptCount: 0

        readonly property var flow: agent.flow
        readonly property bool hasActiveFlow: agent.isActive && flow !== null && !flow.isCompleted && !flow.isCancelled
        readonly property bool waitingForInput: hasActiveFlow && (flow?.isResponseRequired ?? false)
        readonly property bool waitingForBiometric: hasActiveFlow && !(flow?.isResponseRequired ?? true) && !isSubmitting

        readonly property string activeIdentityName: {
            let idObj = flow?.selectedIdentity;
            if (!idObj) return Quickshell.env("USER") || "admin";
            if (typeof idObj === "string") return idObj;
            return idObj.displayName || idObj.name || idObj.user || idObj.id || String(idObj);
        }

        readonly property string resolvedActionIcon: {
            let ic = (flow?.iconName ?? "").trim();
            if (!ic) return "";
            if (Quickshell.iconPath) {
                let p = Quickshell.iconPath(ic, true);
                if (p && p !== "") return p;
            }
            return "";
        }

        /*
        polkit messages for pkexec embed commands in `...' or '...' (like nixos store paths).
        extracting the command lets us render it in a dedicated terminal pill instead of an ugly text wrap!
        */
        readonly property string rawMessage: (flow?.message ?? "").trim()
        readonly property string extractedCommand: {
            if (!rawMessage) return "";
            let m = rawMessage.match(/`([^']+)'/) || rawMessage.match(/'([^']+)'/) || rawMessage.match(/"([^"]+)"/);
            if (m && m[1] && (m[1].startsWith("/") || m[1].includes(" "))) {
                return m[1].trim();
            }
            return "";
        }
        readonly property string shortCommand: {
            if (!extractedCommand) return "";
            // shorten "/run/current-system/sw/bin/echo hello" -> "echo hello" for the main readout
            return extractedCommand.replace(/^\/(?:run\/current-system\/sw\/bin|nix\/store\/[^/]+\/bin|usr\/local\/bin|usr\/bin|bin)\//, "");
        }
        readonly property string cleanPromptMessage: {
            if (!rawMessage) return "an application is requesting privileges to perform an administrative action.";
            if (!extractedCommand) return rawMessage;
            let stripped = rawMessage
                .replace("`" + extractedCommand + "'", "")
                .replace("'" + extractedCommand + "'", "")
                .replace("\"" + extractedCommand + "\"", "")
                .replace(/\s+/g, " ")
                .trim();
            if (!stripped.endsWith(".") && !stripped.endsWith(":")) stripped += ":";
            return stripped.toLowerCase();
        }

        onHasActiveFlowChanged: {
            if (hasActiveFlow) {
                passwordText = "";
                feedbackMessage = (flow?.supplementaryMessage ?? "").trim().toLowerCase();
                isError = Boolean(flow?.supplementaryIsError);
                isSubmitting = false;
                revealPassword = false;
                peekBehind = false;
                attemptCount = 0;
                root.clearAllInputs();
                root.pollCapsLock();
            } else {
                passwordText = "";
                feedbackMessage = "";
                isError = false;
                isSubmitting = false;
                revealPassword = false;
                showDetails = false;
                peekBehind = false;
                attemptCount = 0;
                root.clearAllInputs();
            }
        }
    }

    signal triggerShake()
    signal clearAllInputs()

    readonly property string capsScript: Qt.resolvedUrl("../scripts/detect-capslock.zsh").toString().replace(/^file:\/\//, "")

    property Process capsPollProc: Process {
        command: [root.capsScript]
        stdout: StdioCollector {
            onStreamFinished: {
                dialogState.capsLockActive = (text || "").trim() === "1";
            }
        }
    }

    function pollCapsLock() {
        if (!capsPollProc.running) capsPollProc.running = true;
    }

    Timer {
        id: capsDelayTimer
        interval: 80
        repeat: false
        onTriggered: root.pollCapsLock()
    }

    Timer {
        id: copiedResetTimer
        interval: 1500
        repeat: false
        onTriggered: dialogState.copiedKey = ""
    }

    function copyToClipboard(key: string, val: string) {
        if (!val) return;
        Quickshell.execDetached(["wl-copy", val]);
        dialogState.copiedKey = key;
        copiedResetTimer.restart();
    }

    function submitResponse(textVal: string) {
        if (!dialogState.flow || !dialogState.flow.isResponseRequired || dialogState.isSubmitting) return;
        dialogState.isSubmitting = true;
        dialogState.isError = false;
        dialogState.passwordText = "";
        root.clearAllInputs();
        dialogState.flow.submit(textVal);
    }

    function cancelFlow() {
        if (dialogState.flow) {
            dialogState.passwordText = "";
            root.clearAllInputs();
            dialogState.flow.cancelAuthenticationRequest();
        }
    }

    Connections {
        target: dialogState.flow
        ignoreUnknownSignals: true

        function onSupplementaryMessageChanged() {
            let msg = (dialogState.flow?.supplementaryMessage ?? "").trim();
            dialogState.feedbackMessage = msg;
            if (msg !== "") {
                dialogState.isError = Boolean(dialogState.flow?.supplementaryIsError);
            }
        }

        function onSupplementaryIsErrorChanged() {
            if (dialogState.flow?.supplementaryIsError) {
                dialogState.isError = true;
            }
        }

        function onFailedChanged() {
            if (dialogState.flow?.failed) {
                dialogState.isError = true;
                dialogState.isSubmitting = false;
                dialogState.attemptCount += 1;
                dialogState.passwordText = "";
                root.clearAllInputs();
                root.triggerShake();
            }
        }

        function onIsResponseRequiredChanged() {
            if (!dialogState.flow) return;
            if (dialogState.flow.isResponseRequired) {
                if (dialogState.isSubmitting && dialogState.flow.failed) {
                    dialogState.isError = true;
                    dialogState.attemptCount += 1;
                    root.triggerShake();
                }
                dialogState.isSubmitting = false;
                dialogState.passwordText = "";
                root.clearAllInputs();
            }
        }

        function onIsCompletedChanged() {
            if (dialogState.flow?.isCompleted) {
                dialogState.isSubmitting = false;
                if (!dialogState.flow.isSuccessful && dialogState.flow.failed) {
                    dialogState.isError = true;
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:popup:polkit"

            property real dragOffsetX: 0
            property real dragOffsetY: 0

            readonly property bool isFocusedScreen: {
                const focused = Hyprland?.focusedMonitor?.name;
                if (focused && screen?.name) return screen.name === focused;
                return !screen || (Quickshell.screens && Quickshell.screens.length > 0 && screen === Quickshell.screens[0]);
            }

            readonly property bool shouldShow: dialogState.hasActiveFlow && isFocusedScreen

            visible: animProgress > 0.001
            WlrLayershell.keyboardFocus: shouldShow ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            property real animProgress: shouldShow ? 1.0 : 0.0
            Behavior on animProgress {
                NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animEasing }
            }

            Timer {
                id: focusTimer
                interval: 40
                onTriggered: {
                    if (win.shouldShow) pwInput.forceActiveFocus();
                }
            }

            onShouldShowChanged: {
                if (shouldShow) {
                    dragOffsetX = 0;
                    dragOffsetY = 0;
                    focusTimer.restart();
                }
            }

            // backdrop scrim
            Rectangle {
                anchors.fill: parent
                color: Theme.isLightMode
                    ? Theme.blend(Theme.surface, Theme.primary_container, 0.08)
                    : Theme.scrim
                opacity: (dialogState.peekBehind ? 0.06 : (Theme.isLightMode ? 0.62 : 0.56)) * win.animProgress

                Behavior on opacity { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.cancelFlow()
                }
            }

            // floating authentication card
            Rectangle {
                id: card
                width: Math.min(480, parent.width - 32)
                implicitHeight: cardLayout.implicitHeight + 40
                height: implicitHeight
                x: Math.max(16, Math.min(parent.width - width - 16, ((parent.width - width) / 2) + win.dragOffsetX))
                y: Math.max(16, Math.min(parent.height - height - 16, ((parent.height - height) / 2) + win.dragOffsetY))

                scale: 0.94 + (0.06 * win.animProgress)
                opacity: (dialogState.peekBehind ? 0.25 : 1.0) * win.animProgress

                radius: Theme.radiusXl
                color: Theme.popupBg
                border.color: dialogState.isError
                    ? Theme.error
                    : (pwInput.activeFocus ? Theme.alpha(Theme.primary, 0.65) : Theme.popupBorderColor)
                border.width: dialogState.isError ? 2 : Theme.popupBorderWidth

                Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                transform: Translate { id: cardShake }

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: cardShake; property: "x"; from: 0; to: -12; duration: 40; easing.type: Easing.OutQuad }
                    NumberAnimation { target: cardShake; property: "x"; from: -12; to: 12; duration: 45; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: cardShake; property: "x"; from: 12; to: -8; duration: 45; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: cardShake; property: "x"; from: -8; to: 8; duration: 45; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: cardShake; property: "x"; from: 8; to: 0; duration: 40; easing.type: Easing.OutQuad }
                }

                SequentialAnimation {
                    id: keyPulseAnim
                    NumberAnimation { target: lockGlyph; property: "scale"; from: 1.0; to: 1.22; duration: 60; easing.type: Easing.OutQuad }
                    NumberAnimation { target: lockGlyph; property: "scale"; from: 1.22; to: 1.0; duration: 120; easing.type: Easing.OutBack }
                }

                Connections {
                    target: root
                    function onTriggerShake() {
                        if (win.shouldShow) shakeAnim.restart();
                    }
                    function onClearAllInputs() {
                        if (pwInput.text !== "") pwInput.text = "";
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: pwInput.forceActiveFocus()
                }

                ColumnLayout {
                    id: cardLayout
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    // draggable header bar
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: headerRow.implicitHeight

                        MouseArea {
                            id: dragHeaderMouse
                            anchors.fill: parent
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            property point startPt: Qt.point(0, 0)

                            onPressed: (mouse) => {
                                startPt = Qt.point(mouse.x, mouse.y);
                            }
                            onPositionChanged: (mouse) => {
                                if (!pressed) return;
                                win.dragOffsetX += (mouse.x - startPt.x);
                                win.dragOffsetY += (mouse.y - startPt.y);
                            }
                            onDoubleClicked: {
                                win.dragOffsetX = 0;
                                win.dragOffsetY = 0;
                            }
                        }

                        RowLayout {
                            id: headerRow
                            anchors.fill: parent
                            spacing: 12

                            // shield / app icon squircle
                            Rectangle {
                                width: 42
                                height: 42
                                radius: Theme.radiusMd
                                color: dialogState.isError ? Theme.error_overlay : Theme.primary_overlay
                                border.color: dialogState.isError
                                    ? Theme.alpha(Theme.error, 0.55)
                                    : Theme.alpha(Theme.primary, 0.45)
                                border.width: 1
                                Layout.alignment: Qt.AlignTop

                                Image {
                                    anchors.centerIn: parent
                                    width: 24
                                    height: 24
                                    source: dialogState.resolvedActionIcon
                                    sourceSize: Qt.size(24, 24)
                                    visible: status === Image.Ready && dialogState.resolvedActionIcon !== ""
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: dialogState.resolvedActionIcon === ""
                                    text: dialogState.isError ? Theme.iconFlame : Theme.iconShield
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeLg
                                    color: dialogState.isError ? Theme.error : Theme.primary
                                }
                            }

                            // title + hugging actionId chip (no more floating chevron on the right!)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 4

                                Text {
                                    text: "authentication required"
                                    font.family: Theme.fontDisplay
                                    font.variableAxes: Theme.displayAxes
                                    font.pixelSize: Theme.fontSizeMd
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.textPrimary
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                // compact actionId + chevron chip that hugs its text width
                                Rectangle {
                                    implicitWidth: Math.min(260, actChipRow.implicitWidth + 12)
                                    height: 20
                                    radius: Theme.radiusSm
                                    color: actSubMouse.containsMouse || dialogState.showDetails
                                        ? Theme.widgetHover
                                        : "transparent"

                                    RowLayout {
                                        id: actChipRow
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 4
                                        spacing: 5

                                        Text {
                                            text: (dialogState.flow && dialogState.flow.actionId)
                                                ? dialogState.flow.actionId
                                                : "org.freedesktop.policykit.exec"
                                            font.family: Theme.fontMono
                                            font.variableAxes: Theme.monoAxes
                                            font.weight: Theme.monoWeightRegular
                                            font.pixelSize: Theme.fontSizeXs
                                            color: (actSubMouse.containsMouse || dialogState.showDetails)
                                                ? Theme.primary
                                                : Theme.textSecondary
                                            elide: Text.ElideMiddle
                                            Layout.maximumWidth: 225
                                        }

                                        Text {
                                            text: dialogState.showDetails ? Theme.iconChevronUp : Theme.iconChevronDown
                                            font.family: Theme.fontIcon
                                            font.variableAxes: Theme.iconAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            color: (actSubMouse.containsMouse || dialogState.showDetails)
                                                ? Theme.primary
                                                : Theme.textSecondary
                                        }
                                    }

                                    MouseArea {
                                        id: actSubMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            dialogState.showDetails = !dialogState.showDetails;
                                            pwInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }

                            // top-right pills: user identity + labeled peek chip (no duplicate floating eye!)
                            RowLayout {
                                Layout.alignment: Qt.AlignTop
                                spacing: 6

                                // authenticating user badge
                                Rectangle {
                                    height: 26
                                    implicitWidth: idRow.implicitWidth + 14
                                    radius: Theme.radiusPill
                                    color: idMouse.containsMouse ? Theme.widgetHover : Theme.pillBg
                                    border.color: Theme.pillBorder
                                    border.width: 1

                                    readonly property int idCount: dialogState.flow?.identities?.length ?? 0

                                    RowLayout {
                                        id: idRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: Theme.iconUser
                                            font.family: Theme.fontIcon
                                            font.variableAxes: Theme.iconAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.primary
                                        }

                                        Text {
                                            text: dialogState.activeIdentityName
                                            font.family: Theme.fontMono
                                            font.variableAxes: Theme.monoAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.monoWeightBold
                                            color: Theme.textPrimary
                                        }
                                    }

                                    MouseArea {
                                        id: idMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        enabled: parent.idCount > 1
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            let list = dialogState.flow?.identities;
                                            if (!list || list.length <= 1) return;
                                            let curIdx = list.indexOf(dialogState.flow.selectedIdentity);
                                            let nextIdx = (curIdx + 1) % list.length;
                                            dialogState.flow.selectedIdentity = list[nextIdx];
                                            pwInput.forceActiveFocus();
                                        }
                                    }
                                }

                                // distinct peek button so it doesn't look like a duplicate password eye
                                Rectangle {
                                    height: 26
                                    width: 26
                                    radius: Theme.radiusPill
                                    color: dialogState.peekBehind
                                        ? Theme.primary_overlay
                                        : (peekMouse.containsMouse ? Theme.widgetHover : Theme.pillBg)
                                    border.color: dialogState.peekBehind
                                        ? Theme.alpha(Theme.primary, 0.55)
                                        : Theme.pillBorder
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: Theme.iconExpand
                                        font.family: Theme.fontIcon
                                        font.variableAxes: Theme.iconAxes
                                        font.pixelSize: Theme.fontSizeXs
                                        color: dialogState.peekBehind ? Theme.primary : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: peekMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            dialogState.peekBehind = !dialogState.peekBehind;
                                            pwInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // clean prompt sentence (with ugly nixos/store paths extracted into the terminal pill below)
                    Text {
                        Layout.fillWidth: true
                        text: dialogState.cleanPromptMessage
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.weight: Theme.fontWeightRegular
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.textSecondary
                        wrapMode: Text.WordWrap
                    }

                    // dedicated terminal command box when pkexec/polkit includes a command path
                    Rectangle {
                        visible: dialogState.extractedCommand !== ""
                        Layout.fillWidth: true
                        implicitHeight: cmdBoxCol.implicitHeight + 18
                        radius: Theme.radiusMd
                        color: Theme.widgetBg
                        border.color: Theme.alpha(Theme.primary, 0.28)
                        border.width: 1

                        ColumnLayout {
                            id: cmdBoxCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: Theme.iconTerminal
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.primary
                                }

                                Text {
                                    text: dialogState.shortCommand
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: Theme.fontSizeSm
                                    font.weight: Theme.monoWeightBold
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // copy command chip
                                Rectangle {
                                    height: 22
                                    implicitWidth: copyCmdRow.implicitWidth + 12
                                    radius: Theme.radiusPill
                                    color: dialogState.copiedKey === "cmd" ? Theme.primary_overlay : Theme.pillBg
                                    border.color: Theme.alpha(Theme.primary, 0.40)
                                    border.width: 1

                                    RowLayout {
                                        id: copyCmdRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: dialogState.copiedKey === "cmd" ? Theme.iconCheck : Theme.iconCopy
                                            font.family: Theme.fontIcon
                                            font.variableAxes: Theme.iconAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.primary
                                        }
                                        Text {
                                            text: dialogState.copiedKey === "cmd" ? "copied" : "copy cmd"
                                            font.family: Theme.fontMono
                                            font.variableAxes: Theme.monoAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.monoWeightBold
                                            color: Theme.primary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.copyToClipboard("cmd", dialogState.extractedCommand);
                                            pwInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: dialogState.extractedCommand !== dialogState.shortCommand
                                text: dialogState.extractedCommand
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.weight: Theme.monoWeightRegular
                                font.pixelSize: Theme.fontSizeXs
                                color: Theme.on_surface_disabled
                                elide: Text.ElideMiddle
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // expandable Polkit rule inspector card (properly padded!)
                    Rectangle {
                        visible: dialogState.showDetails
                        Layout.fillWidth: true
                        implicitHeight: detailsCol.implicitHeight + 20
                        radius: Theme.radiusMd
                        color: Theme.widgetBg
                        border.color: Theme.widgetBorder
                        border.width: 1

                        ColumnLayout {
                            id: detailsCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "action id:"
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.monoWeightBold
                                    color: Theme.textSecondary
                                }

                                Text {
                                    text: dialogState.flow?.actionId || "n/a"
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.weight: Theme.monoWeightRegular
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.textPrimary
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    height: 22
                                    implicitWidth: copyIdRow.implicitWidth + 12
                                    radius: Theme.radiusPill
                                    color: dialogState.copiedKey === "id" ? Theme.primary_overlay : Theme.pillBg
                                    border.color: Theme.alpha(Theme.primary, 0.45)
                                    border.width: 1

                                    RowLayout {
                                        id: copyIdRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            text: dialogState.copiedKey === "id" ? Theme.iconCheck : Theme.iconCopy
                                            font.family: Theme.fontIcon
                                            font.variableAxes: Theme.iconAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            color: Theme.primary
                                        }
                                        Text {
                                            text: dialogState.copiedKey === "id" ? "copied" : "copy id"
                                            font.family: Theme.fontMono
                                            font.variableAxes: Theme.monoAxes
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.monoWeightBold
                                            color: Theme.primary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.copyToClipboard("id", dialogState.flow?.actionId ?? "");
                                            pwInput.forceActiveFocus();
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                visible: (dialogState.flow?.cookie ?? "") !== ""
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "cookie:"
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.monoWeightBold
                                    color: Theme.textSecondary
                                }

                                Text {
                                    text: dialogState.flow?.cookie ?? ""
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.weight: Theme.monoWeightRegular
                                    font.pixelSize: Theme.fontSizeXs
                                    color: Theme.on_surface_disabled
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // biometric / security key waiting banner
                    Rectangle {
                        visible: dialogState.waitingForBiometric
                        Layout.fillWidth: true
                        height: 44
                        radius: Theme.radiusMd
                        color: Theme.primary_overlay
                        border.color: Theme.alpha(Theme.primary, 0.55)
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: Theme.iconShield
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeMd
                                color: Theme.primary
                            }

                            Text {
                                text: dialogState.feedbackMessage !== ""
                                    ? dialogState.feedbackMessage.toLowerCase()
                                    : "waiting for fingerprint or security key..."
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightBold
                                color: Theme.primary
                            }
                        }
                    }

                    // password input bar
                    Rectangle {
                        id: inputContainer
                        visible: !dialogState.waitingForBiometric
                        Layout.fillWidth: true
                        height: 46
                        radius: Theme.radiusMd
                        color: pwInput.activeFocus ? Theme.pillHover : Theme.pillBg
                        border.color: dialogState.isError
                            ? Theme.error
                            : (dialogState.capsLockActive && dialogState.passwordText.length > 0
                                ? Theme.warn
                                : (pwInput.activeFocus ? Theme.primary : Theme.pillBorder))
                        border.width: (pwInput.activeFocus || dialogState.isError || dialogState.capsLockActive) ? 2 : 1

                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                        Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 10
                            spacing: 10

                            Text {
                                id: lockGlyph
                                text: dialogState.isSubmitting ? Theme.iconRefresh : Theme.iconLock
                                font.family: Theme.fontIcon
                                font.variableAxes: Theme.iconAxes
                                font.pixelSize: Theme.fontSizeMd
                                color: dialogState.isError
                                    ? Theme.error
                                    : (pwInput.activeFocus ? Theme.primary : Theme.textSecondary)

                                RotationAnimator on rotation {
                                    running: dialogState.isSubmitting
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 900
                                }
                            }

                            TextInput {
                                id: pwInput
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: (dialogState.revealPassword || (dialogState.flow && dialogState.flow.responseVisible))
                                    ? TextInput.Normal
                                    : TextInput.Password
                                passwordCharacter: "•"
                                passwordMaskDelay: 0
                                font.family: Theme.fontMono
                                font.variableAxes: Theme.monoAxes
                                font.weight: Theme.monoWeightRegular
                                font.pixelSize: Theme.fontSizeMd
                                color: Theme.textPrimary
                                selectionColor: Theme.primary_container
                                selectedTextColor: Theme.on_primary_container
                                selectByMouse: true
                                readOnly: dialogState.isSubmitting
                                clip: true

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    text: {
                                        if (dialogState.isSubmitting) return "verifying credentials...";
                                        let prompt = (dialogState.flow?.inputPrompt ?? "").trim().replace(/[:\s]+$/, "").toLowerCase();
                                        return prompt !== "" ? (prompt + "...") : "enter password...";
                                    }
                                    font.family: Theme.fontFamily
                                    font.variableAxes: Theme.sansAxes
                                    font.weight: Theme.fontWeightRegular
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.on_surface_disabled
                                    visible: pwInput.text.length === 0
                                }

                                onTextEdited: {
                                    dialogState.passwordText = pwInput.text;
                                    if (dialogState.isError) dialogState.isError = false;
                                    keyPulseAnim.restart();
                                }

                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_CapsLock) {
                                        capsDelayTimer.restart();
                                    }
                                }

                                onAccepted: {
                                    root.submitResponse(pwInput.text);
                                }

                                Keys.onEscapePressed: {
                                    root.cancelFlow();
                                }
                            }

                            Rectangle {
                                visible: dialogState.capsLockActive
                                height: 20
                                implicitWidth: capsTxt.implicitWidth + 10
                                radius: Theme.radiusPill
                                color: Theme.warn_overlay
                                border.color: Theme.alpha(Theme.warn, 0.65)
                                border.width: 1

                                Text {
                                    id: capsTxt
                                    anchors.centerIn: parent
                                    text: "caps"
                                    font.family: Theme.fontMono
                                    font.variableAxes: Theme.monoAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.monoWeightBold
                                    color: Theme.warn
                                }
                            }

                            IconButton {
                                visible: dialogState.passwordText.length > 0 && !dialogState.isSubmitting
                                icon: Theme.iconClose
                                iconSize: Theme.fontSizeXs
                                tooltip: "clear"
                                onClicked: {
                                    dialogState.passwordText = "";
                                    dialogState.isError = false;
                                    pwInput.text = "";
                                    pwInput.forceActiveFocus();
                                }
                            }

                            IconButton {
                                visible: dialogState.passwordText.length > 0 && !dialogState.isSubmitting && !(dialogState.flow?.responseVisible ?? false)
                                icon: dialogState.revealPassword ? Theme.iconEyeOff : Theme.iconEye
                                iconSize: Theme.fontSizeSm
                                tooltip: dialogState.revealPassword ? "hide password" : "show password"
                                onClicked: {
                                    dialogState.revealPassword = !dialogState.revealPassword;
                                    pwInput.forceActiveFocus();
                                }
                            }
                        }
                    }

                    // supplementary feedback / error line
                    Text {
                        Layout.fillWidth: true
                        visible: !dialogState.waitingForBiometric && (dialogState.feedbackMessage !== "" || dialogState.isError)
                        text: dialogState.feedbackMessage !== ""
                            ? dialogState.feedbackMessage.toLowerCase()
                            : ("authentication failed" + (dialogState.attemptCount > 1 ? (" (" + dialogState.attemptCount + " tries)") : " — try again"))
                        font.family: Theme.fontFamily
                        font.variableAxes: Theme.sansAxes
                        font.pixelSize: Theme.fontSizeXs
                        font.weight: Theme.fontWeightMedium
                        color: dialogState.isError ? Theme.error : Theme.primary
                        wrapMode: Text.WordWrap
                    }

                    // action buttons (sized dynamically by implicitWidth + padding so nothing gets cramped)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 10

                        Text {
                            visible: win.dragOffsetX !== 0 || win.dragOffsetY !== 0
                            text: "double-click header to center"
                            font.family: Theme.fontMono
                            font.variableAxes: Theme.monoAxes
                            font.weight: Theme.monoWeightRegular
                            font.pixelSize: Theme.fontSizeXs
                            color: Theme.on_surface_disabled
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            implicitWidth: cancelLbl.implicitWidth + 28
                            height: 36
                            radius: cancelMouse.pressed ? Theme.radiusPill : Theme.radiusMd
                            color: cancelMouse.pressed
                                ? Theme.widgetActive
                                : (cancelMouse.containsMouse ? Theme.widgetHover : Theme.widgetBg)
                            border.color: cancelMouse.containsMouse ? Theme.alpha(Theme.primary, 0.35) : Theme.widgetBorder
                            border.width: 1

                            Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            Text {
                                id: cancelLbl
                                anchors.centerIn: parent
                                text: "cancel (esc)"
                                font.family: Theme.fontFamily
                                font.variableAxes: Theme.sansAxes
                                font.pixelSize: Theme.fontSizeXs
                                font.weight: Theme.fontWeightDemiBold
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: cancelMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.cancelFlow()
                            }
                        }

                        Rectangle {
                            readonly property bool canAuth: dialogState.waitingForInput && !dialogState.isSubmitting
                            implicitWidth: authBtnRow.implicitWidth + 28
                            height: 36
                            opacity: canAuth ? 1.0 : 0.55
                            radius: authMouse.pressed ? Theme.radiusPill : Theme.radiusMd
                            color: authMouse.pressed
                                ? Theme.statePress(Theme.primary, Theme.on_primary)
                                : (authMouse.containsMouse
                                    ? Theme.stateHover(Theme.primary, Theme.on_primary)
                                    : Theme.primary)

                            Behavior on radius { NumberAnimation { duration: Theme.animFast; easing.type: Theme.animEasing } }
                            Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                            RowLayout {
                                id: authBtnRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: dialogState.isSubmitting ? Theme.iconRefresh : Theme.iconCheck
                                    font.family: Theme.fontIcon
                                    font.variableAxes: Theme.iconAxes
                                    font.pixelSize: Theme.fontSizeSm
                                    color: Theme.on_primary
                                }

                                Text {
                                    text: dialogState.isSubmitting ? "verifying..." : "authenticate"
                                    font.family: Theme.fontDisplay
                                    font.variableAxes: Theme.displayAxes
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.on_primary
                                }
                            }

                            MouseArea {
                                id: authMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: parent.canAuth
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: root.submitResponse(pwInput.text)
                            }
                        }
                    }
                }
            }
        }
    }
}
