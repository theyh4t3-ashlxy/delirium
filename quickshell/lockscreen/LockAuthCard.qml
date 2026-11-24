// LockAuthCard.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell

ColumnLayout {
    id: passwordBlock

    property var root: null
    property var lockSurface: null
    property var stage: null

    property alias pwInput: pwInput

                            y: stage.blockY("password")
                            spacing: 8
                            opacity: root.zenMode ? 0.0 : 1.0

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                            Rectangle {
                                id: pwContainer
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                radius: root.uiRadiusPill
                                color: pwInput.activeFocus ? root.uiPillHover : root.uiPillBg
                                border.color: root.authFailed
                                    ? Theme.error
                                    : (root.capsLockActive && root.sharedPassword.length > 0
                                        ? Theme.warn
                                        : (root.sharedPassword.length > 0
                                            ? root.uiAccent
                                            : (pwInput.activeFocus ? Theme.alpha(root.uiAccent, 0.65) : root.uiPillBorder)))
                                border.width: (pwInput.activeFocus || root.authFailed || root.capsLockActive) ? 2 : 1

                                Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }
                                Behavior on border.color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                transform: Translate { id: pwShake }

                                SequentialAnimation {
                                    id: shakeAnim
                                    NumberAnimation { target: pwShake; property: "x"; from: 0; to: -14; duration: Math.max(30, Math.round(Theme.animFast / 3)); easing.type: Easing.OutQuad }
                                    NumberAnimation { target: pwShake; property: "x"; from: -14; to: 14; duration: Math.max(30, Math.round(Theme.animFast / 3)); easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: pwShake; property: "x"; from: 14; to: -8; duration: Math.max(30, Math.round(Theme.animFast / 3)); easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: pwShake; property: "x"; from: -8; to: 8; duration: Math.max(30, Math.round(Theme.animFast / 3)); easing.type: Easing.InOutQuad }
                                    NumberAnimation { target: pwShake; property: "x"; from: 8; to: 0; duration: Math.max(30, Math.round(Theme.animFast / 3)); easing.type: Easing.OutQuad }
                                }

                                SequentialAnimation {
                                    id: keyPulseAnim
                                    NumberAnimation { target: lockGlyph; property: "scale"; from: 1.0; to: 1.24; duration: 65; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: lockGlyph; property: "scale"; from: 1.24; to: 1.0; duration: 130; easing.type: Easing.OutBack }
                                }

                                Connections {
                                    target: root
                                    function onTriggerShake() {
                                        shakeAnim.restart();
                                    }
                                    function onClearAllInputs() {
                                        if (pwInput.text !== "") pwInput.text = "";
                                    }
                                    function onSharedPasswordChanged() {
                                        if (pwInput.text !== root.sharedPassword) {
                                            pwInput.text = root.sharedPassword;
                                        }
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 18
                                    anchors.rightMargin: 8
                                    spacing: 10

                                    Text {
                                        id: lockGlyph
                                        text: root.isChecking ? Theme.iconRefresh : Theme.iconLock
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeMd
                                        color: root.authFailed
                                            ? Theme.error
                                            : (pwInput.activeFocus ? root.uiAccent : root.uiTextSecondary)

                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        RotationAnimator on rotation {
                                            running: root.isChecking
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
                                        echoMode: root.revealPassword
                                            ? TextInput.Normal
                                            : (root.pwMaskChar === "none" ? TextInput.NoEcho : TextInput.Password)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeMd
                                        color: root.uiTextPrimary
                                        selectionColor: root.uiAccentOverlay
                                        selectedTextColor: root.uiTextPrimary
                                        readOnly: root.isChecking
                                        passwordCharacter: (root.pwMaskChar !== "" && root.pwMaskChar !== "none") ? root.pwMaskChar : "•"
                                        passwordMaskDelay: 0
                                        clip: true

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: root.fmtText(
                                                root.isChecking
                                                    ? "verifying..."
                                                    : (root.pwMaskChar === "none" && root.sharedPassword.length > 0
                                                        ? (root.sharedPassword.length + " chars typed (stealth)...")
                                                        : "enter password to unlock...")
                                            )
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            color: root.pwMaskChar === "none" && root.sharedPassword.length > 0
                                                ? root.uiAccent
                                                : root.uiTextDisabled
                                            visible: pwInput.text.length === 0 || (root.pwMaskChar === "none" && !root.revealPassword)
                                        }

                                        onTextEdited: {
                                            lockSurface.wakeFromZen();
                                            root.sharedPassword = pwInput.text;
                                            if (root.authFailed) root.authFailed = false;
                                            keyPulseAnim.restart();
                                        }

                                        Keys.onPressed: (event) => {
                                            lockSurface.wakeFromZen();
                                            if (event.key === Qt.Key_CapsLock) {
                                                if (root?.pollKeyboardState) root.pollKeyboardState();
                                            } else if (event.key === Qt.Key_Tab && pwInput.text.length === 0 && !lockSurface.optionsOpen) {
                                                root.zenMode = !root.zenMode;
                                                event.accepted = true;
                                            } else if (root.freeDragMode && pwInput.text.length === 0) {
                                                let step = (event.modifiers & Qt.ShiftModifier) ? 0.04 : 0.01;
                                                if (event.key === Qt.Key_Left) {
                                                    root.customNormX = Math.max(0.02, root.customNormX - step);
                                                    root.layoutPosition = "custom";
                                                    root.saveSandbox();
                                                    event.accepted = true;
                                                } else if (event.key === Qt.Key_Right) {
                                                    root.customNormX = Math.min(0.98, root.customNormX + step);
                                                    root.layoutPosition = "custom";
                                                    root.saveSandbox();
                                                    event.accepted = true;
                                                } else if (event.key === Qt.Key_Up) {
                                                    root.customNormY = Math.max(0.05, root.customNormY - step);
                                                    root.layoutPosition = "custom";
                                                    root.saveSandbox();
                                                    event.accepted = true;
                                                } else if (event.key === Qt.Key_Down) {
                                                    root.customNormY = Math.min(0.95, root.customNormY + step);
                                                    root.layoutPosition = "custom";
                                                    root.saveSandbox();
                                                    event.accepted = true;
                                                }
                                            }
                                        }

                                        Keys.onEscapePressed: {
                                            if (root.zenMode) {
                                                root.zenMode = false;
                                            } else if (lockSurface.optionsOpen) {
                                                lockSurface.optionsOpen = false;
                                            } else if (root?.isChecking) {
                                                if (root.cancelAuth) root.cancelAuth();
                                            } else {
                                                root.sharedPassword = "";
                                                root.revealPassword = false;
                                                root.authFailed = false;
                                                pwInput.text = "";
                                            }
                                        }

                                        onAccepted: {
                                            const p = pwInput.text !== "" ? pwInput.text : root.sharedPassword;
                                            root.sharedPassword = "";
                                            pwInput.text = "";
                                            root.tryUnlock(p);
                                        }

                                        Connections {
                                            target: root
                                            function onLockedChanged() {
                                                if (root.locked) {
                                                    pwInput.text = "";
                                                    if (root.activeSurface === null || root.activeSurface === lockSurface) {
                                                        root.activeSurface = lockSurface;
                                                        pwInput.forceActiveFocus();
                                                    }
                                                }
                                            }
                                            function onIsCheckingChanged() {
                                                if (!root.isChecking && root.locked && root.activeSurface === lockSurface) {
                                                    pwInput.forceActiveFocus();
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: root.capsLockActive
                                        height: 22
                                        implicitWidth: capsTxt.implicitWidth + 10
                                        radius: root.uiRadiusPill
                                        color: Theme.warn_overlay
                                        border.color: Theme.alpha(Theme.warn, 0.65)
                                        border.width: 1

                                        Text {
                                            id: capsTxt
                                            anchors.centerIn: parent
                                            text: root.fmtText("caps")
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeXs
                                            font.weight: Theme.fontWeightBold
                                            color: Theme.warn
                                        }
                                    }

                                    IconButton {
                                        icon: Theme.iconClose
                                        tooltip: "clear"
                                        iconSize: Theme.fontSizeXs
                                        visible: root.sharedPassword.length > 0 && !root.isChecking
                                        onClicked: {
                                            root.sharedPassword = "";
                                            root.revealPassword = false;
                                            root.authFailed = false;
                                            pwInput.text = "";
                                            pwInput.forceActiveFocus();
                                        }
                                    }

                                    IconButton {
                                        icon: root.revealPassword ? Theme.iconEyeOff : Theme.iconEye
                                        tooltip: root.revealPassword ? "hide password" : "show password"
                                        iconSize: Theme.fontSizeSm
                                        visible: root.sharedPassword.length > 0 && !root.isChecking
                                        onClicked: {
                                            root.revealPassword = !root.revealPassword;
                                            pwInput.forceActiveFocus();
                                        }
                                    }

                                    Rectangle {
                                        readonly property bool canSubmit: root.sharedPassword.length > 0 && !root.isChecking
                                        width: canSubmit ? 38 : 0
                                        height: 34
                                        opacity: canSubmit ? 1.0 : 0.0
                                        visible: width > 0
                                        radius: root.uiRadiusPill
                                        color: submitMouse.pressed
                                            ? Theme.statePress(root.uiAccent, root.uiOnAccent)
                                            : (submitMouse.containsMouse
                                                ? Theme.stateHover(root.uiAccent, root.uiOnAccent)
                                                : root.uiAccent)

                                        Behavior on width { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.iconChevronRight
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Theme.fontWeightBold
                                            color: root.uiOnAccent
                                        }

                                        MouseArea {
                                            id: submitMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const p = pwInput.text !== "" ? pwInput.text : root.sharedPassword;
                                                root.sharedPassword = "";
                                                pwInput.text = "";
                                                root.tryUnlock(p);
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 18

                                Text {
                                    anchors.centerIn: parent
                                    text: root.fmtText(
                                        root.pamFeedback !== ""
                                            ? root.pamFeedback
                                            : (root.isChecking
                                                ? "authenticating..."
                                                : (root.authFailed
                                                    ? (root.faillockTripped
                                                        ? "account locked by pam_faillock (run 'faillock --reset' in tty)"
                                                        : "incorrect password, try again")
                                                    : (root.capsLockActive ? "caps lock is on" : "")))
                                    )
                                    opacity: text !== "" ? 1.0 : 0.0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightMedium
                                    color: (root.authFailed || root.pamFeedbackIsError)
                                        ? Theme.error
                                        : (root.capsLockActive ? Theme.warn : root.uiTextSecondary)

                                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                }
                            }
                        }
