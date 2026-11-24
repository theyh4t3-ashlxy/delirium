// LockAuthCard.qml
import QtQuick
import QtQuick.Layouts
import ".."
import Quickshell

ColumnLayout {
    id: passwordBlock

    required property var lockRoot
    required property var surface
    required property var centerStage

    property alias pwInput: pwInput

                            y: centerStage.blockY("password")
                            spacing: 8
                            opacity: lockRoot.zenMode ? 0.0 : 1.0

                            Behavior on y { NumberAnimation { duration: Theme.expressiveDefault; easing.type: Theme.animEasingEntrance } }
                            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }

                            Rectangle {
                                id: pwContainer
                                Layout.fillWidth: true
                                Layout.preferredHeight: 50
                                radius: lockRoot.uiRadiusPill
                                color: pwInput.activeFocus ? lockRoot.uiPillHover : lockRoot.uiPillBg
                                border.color: lockRoot.authFailed
                                    ? Theme.error
                                    : (lockRoot.capsLockActive && lockRoot.sharedPassword.length > 0
                                        ? Theme.warn
                                        : (lockRoot.sharedPassword.length > 0
                                            ? lockRoot.uiAccent
                                            : (pwInput.activeFocus ? Theme.alpha(lockRoot.uiAccent, 0.65) : lockRoot.uiPillBorder)))
                                border.width: (pwInput.activeFocus || lockRoot.authFailed || lockRoot.capsLockActive) ? 2 : 1

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
                                    target: lockRoot
                                    function onTriggerShake() {
                                        shakeAnim.restart();
                                    }
                                    function onClearAllInputs() {
                                        if (pwInput.text !== "") pwInput.text = "";
                                    }
                                    function onSharedPasswordChanged() {
                                        if (pwInput.text !== lockRoot.sharedPassword) {
                                            pwInput.text = lockRoot.sharedPassword;
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
                                        text: lockRoot.isChecking ? Theme.iconRefresh : Theme.iconLock
                                        font.family: Theme.fontIcon
                                        font.pixelSize: Theme.fontSizeMd
                                        color: lockRoot.authFailed
                                            ? Theme.error
                                            : (pwInput.activeFocus ? lockRoot.uiAccent : lockRoot.uiTextSecondary)

                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        RotationAnimator on rotation {
                                            running: lockRoot.isChecking
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
                                        echoMode: lockRoot.revealPassword
                                            ? TextInput.Normal
                                            : (lockRoot.pwMaskChar === "none" ? TextInput.NoEcho : TextInput.Password)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontSizeMd
                                        color: lockRoot.uiTextPrimary
                                        selectionColor: lockRoot.uiAccentOverlay
                                        selectedTextColor: lockRoot.uiTextPrimary
                                        readOnly: lockRoot.isChecking
                                        passwordCharacter: (lockRoot.pwMaskChar !== "" && lockRoot.pwMaskChar !== "none") ? lockRoot.pwMaskChar : "•"
                                        passwordMaskDelay: 0
                                        clip: true

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: lockRoot.fmtText(
                                                lockRoot.isChecking
                                                    ? "verifying..."
                                                    : (lockRoot.pwMaskChar === "none" && lockRoot.sharedPassword.length > 0
                                                        ? (lockRoot.sharedPassword.length + " chars typed (stealth)...")
                                                        : "enter password to unlock...")
                                            )
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSizeSm
                                            color: lockRoot.pwMaskChar === "none" && lockRoot.sharedPassword.length > 0
                                                ? lockRoot.uiAccent
                                                : lockRoot.uiTextDisabled
                                            visible: pwInput.text.length === 0 || (lockRoot.pwMaskChar === "none" && !lockRoot.revealPassword)
                                        }

                                        onTextEdited: {
                                            surface.wakeFromZen();
                                            lockRoot.sharedPassword = pwInput.text;
                                            if (lockRoot.authFailed) lockRoot.authFailed = false;
                                            keyPulseAnim.restart();
                                        }

                                        Keys.onPressed: (event) => {
                                            surface.wakeFromZen();
                                            if (event.key === Qt.Key_CapsLock) {
                                                kbPollDelayTimer.restart();
                                            } else if (event.key === Qt.Key_Tab && pwInput.text.length === 0 && !surface.optionsOpen) {
                                                lockRoot.zenMode = !lockRoot.zenMode;
                                                event.accepted = true;
                                            } else if (lockRoot.freeDragMode && pwInput.text.length === 0) {
                                                let step = (event.modifiers & Qt.ShiftModifier) ? 0.04 : 0.01;
                                                if (event.key === Qt.Key_Left) {
                                                    lockRoot.customNormX = Math.max(0.02, lockRoot.customNormX - step);
                                                    lockRoot.layoutPosition = "custom";
                                                    lockRoot.saveSandbox();
                                                    event.accepted = true;
                                                } else if (event.key === Qt.Key_Right) {
                                                    lockRoot.customNormX = Math.min(0.98, lockRoot.customNormX + step);
                                                    lockRoot.layoutPosition = "custom";
                                                    lockRoot.saveSandbox();
                                                    event.accepted = true;
                                                } else if (event.key === Qt.Key_Up) {
                                                    lockRoot.customNormY = Math.max(0.05, lockRoot.customNormY - step);
                                                    lockRoot.layoutPosition = "custom";
                                                    lockRoot.saveSandbox();
                                                    event.accepted = true;
                                                } else if (event.key === Qt.Key_Down) {
                                                    lockRoot.customNormY = Math.min(0.95, lockRoot.customNormY + step);
                                                    lockRoot.layoutPosition = "custom";
                                                    lockRoot.saveSandbox();
                                                    event.accepted = true;
                                                }
                                            }
                                        }

                                        Keys.onEscapePressed: {
                                            if (lockRoot.zenMode) {
                                                lockRoot.zenMode = false;
                                            } else if (surface.optionsOpen) {
                                                surface.optionsOpen = false;
                                            } else if (lockRoot.isChecking && pam.active) {
                                                pam.abort();
                                                pamSafetyTimeout.stop();
                                                lockRoot.isChecking = false;
                                                lockRoot.pamFeedback = "cancelled";
                                            } else {
                                                lockRoot.sharedPassword = "";
                                                lockRoot.revealPassword = false;
                                                lockRoot.authFailed = false;
                                                pwInput.text = "";
                                            }
                                        }

                                        onAccepted: {
                                            const p = pwInput.text !== "" ? pwInput.text : lockRoot.sharedPassword;
                                            lockRoot.sharedPassword = "";
                                            pwInput.text = "";
                                            lockRoot.tryUnlock(p);
                                        }

                                        Connections {
                                            target: lockRoot
                                            function onLockedChanged() {
                                                if (lockRoot.locked) {
                                                    pwInput.text = "";
                                                    if (lockRoot.activeSurface === null || lockRoot.activeSurface === surface) {
                                                        lockRoot.activeSurface = surface;
                                                        pwInput.forceActiveFocus();
                                                    }
                                                }
                                            }
                                            function onIsCheckingChanged() {
                                                if (!lockRoot.isChecking && lockRoot.locked && lockRoot.activeSurface === surface) {
                                                    pwInput.forceActiveFocus();
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        visible: lockRoot.capsLockActive
                                        height: 22
                                        implicitWidth: capsTxt.implicitWidth + 10
                                        radius: lockRoot.uiRadiusPill
                                        color: Theme.warn_overlay
                                        border.color: Theme.alpha(Theme.warn, 0.65)
                                        border.width: 1

                                        Text {
                                            id: capsTxt
                                            anchors.centerIn: parent
                                            text: lockRoot.fmtText("caps")
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
                                        visible: lockRoot.sharedPassword.length > 0 && !lockRoot.isChecking
                                        onClicked: {
                                            lockRoot.sharedPassword = "";
                                            lockRoot.revealPassword = false;
                                            lockRoot.authFailed = false;
                                            pwInput.text = "";
                                            pwInput.forceActiveFocus();
                                        }
                                    }

                                    IconButton {
                                        icon: lockRoot.revealPassword ? Theme.iconEyeOff : Theme.iconEye
                                        tooltip: lockRoot.revealPassword ? "hide password" : "show password"
                                        iconSize: Theme.fontSizeSm
                                        visible: lockRoot.sharedPassword.length > 0 && !lockRoot.isChecking
                                        onClicked: {
                                            lockRoot.revealPassword = !lockRoot.revealPassword;
                                            pwInput.forceActiveFocus();
                                        }
                                    }

                                    Rectangle {
                                        readonly property bool canSubmit: lockRoot.sharedPassword.length > 0 && !lockRoot.isChecking
                                        width: canSubmit ? 38 : 0
                                        height: 34
                                        opacity: canSubmit ? 1.0 : 0.0
                                        visible: width > 0
                                        radius: lockRoot.uiRadiusPill
                                        color: submitMouse.pressed
                                            ? Theme.statePress(lockRoot.uiAccent, lockRoot.uiOnAccent)
                                            : (submitMouse.containsMouse
                                                ? Theme.stateHover(lockRoot.uiAccent, lockRoot.uiOnAccent)
                                                : lockRoot.uiAccent)

                                        Behavior on width { NumberAnimation { duration: Theme.expressiveFast; easing.type: Theme.animExpressiveEasing } }
                                        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                        Behavior on color { ColorAnimation { duration: Theme.animFast; easing.type: Theme.animColorEasing } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: Theme.iconChevronRight
                                            font.family: Theme.fontIcon
                                            font.pixelSize: Theme.fontSizeSm
                                            font.weight: Theme.fontWeightBold
                                            color: lockRoot.uiOnAccent
                                        }

                                        MouseArea {
                                            id: submitMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const p = pwInput.text !== "" ? pwInput.text : lockRoot.sharedPassword;
                                                lockRoot.sharedPassword = "";
                                                pwInput.text = "";
                                                lockRoot.tryUnlock(p);
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
                                    text: lockRoot.fmtText(
                                        lockRoot.pamFeedback !== ""
                                            ? lockRoot.pamFeedback
                                            : (lockRoot.isChecking
                                                ? "authenticating..."
                                                : (lockRoot.authFailed
                                                    ? (lockRoot.faillockTripped
                                                        ? "account locked by pam_faillock (run 'faillock --reset' in tty)"
                                                        : "incorrect password, try again")
                                                    : (lockRoot.capsLockActive ? "caps lock is on" : "")))
                                    )
                                    opacity: text !== "" ? 1.0 : 0.0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeXs
                                    font.weight: Theme.fontWeightMedium
                                    color: (lockRoot.authFailed || lockRoot.pamFeedbackIsError)
                                        ? Theme.error
                                        : (lockRoot.capsLockActive ? Theme.warn : lockRoot.uiTextSecondary)

                                    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
                                }
                            }
                        }
                    }
