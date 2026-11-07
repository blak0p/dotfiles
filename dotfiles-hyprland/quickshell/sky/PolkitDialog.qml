import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs

// The session's polkit agent: when an app asks for admin rights (pkexec,
// systemctl, a GUI installer, ...) this dialog asks for the password.
// Replaces polkit-kde-agent / polkit-gnome. Only one agent can be registered
// per session, so `agent.isRegistered` stays false while another one runs.
Scope {
    id: root

    PolkitAgent { id: agent }

    readonly property var flow: agent.flow
    readonly property bool shown: agent.isActive && flow !== null && !flow.isCompleted

    // Never carry a typed password over to another request.
    onShownChanged: if (!shown) pass.text = ""

    function submit() {
        if (!flow || !flow.isResponseRequired || pass.text === "") return;
        flow.submit(pass.text);
        pass.text = "";
    }
    function cancel() {
        if (flow) flow.cancelAuthenticationRequest();
        pass.text = "";
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onIsResponseRequiredChanged() {
            if (root.flow && root.flow.isResponseRequired) pass.forceActiveFocus();
        }
    }

    PanelWindow {
        id: win

        screen: {
            const main = Quickshell.screens.filter(s => s.name === Config.screen);
            return main.length ? main[0] : Quickshell.screens[0];
        }
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell:polkit"
        WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        visible: root.shown || card.opacity > 0

        onVisibleChanged: if (visible) pass.forceActiveFocus()

        // Window-wide, so Esc still cancels while the field is disabled
        // (PAM is checking the password).
        Shortcut {
            sequence: "Escape"
            enabled: root.shown
            onActivated: root.cancel()
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            opacity: root.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            MouseArea { anchors.fill: parent; onClicked: pass.forceActiveFocus() }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 420
            height: body.implicitHeight + 48
            radius: 26
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.94)
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.35)
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.94
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Column {
                id: body
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                spacing: 14

                Row {
                    spacing: 12
                    Rectangle {
                        width: 44; height: 44; radius: 14
                        color: Theme.surface2
                        Icon {
                            anchors.centerIn: parent
                            text: "admin_panel_settings"
                            color: Theme.accent
                            font.pixelSize: 24
                            fill: 1
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            text: I18n.t("Authentication required")
                            color: Theme.fg
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: root.flow && root.flow.selectedIdentity
                                ? root.flow.selectedIdentity.displayName || "" : ""
                            visible: text !== ""
                            color: Theme.muted
                            font.pixelSize: 12
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: root.flow ? root.flow.message : ""
                    wrapMode: Text.Wrap
                    color: Theme.fg
                    font.pixelSize: 13
                }

                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 14
                    color: Theme.widget
                    border.width: 1
                    border.color: pass.activeFocus ? Theme.accent : Theme.surface2

                    TextInput {
                        id: pass
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.fg
                        font.pixelSize: 14
                        clip: true
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                        enabled: root.flow !== null && root.flow.isResponseRequired
                        echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: pass.text === ""
                            text: root.flow && root.flow.inputPrompt
                                ? root.flow.inputPrompt.replace(/:\s*$/, "") : I18n.t("Password")
                            color: Theme.outline
                            font.pixelSize: 14
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: !root.flow ? ""
                        : root.flow.failed ? I18n.t("Wrong password, try again")
                        : root.flow.supplementaryMessage
                    wrapMode: Text.Wrap
                    color: root.flow && (root.flow.failed || root.flow.supplementaryIsError)
                        ? Theme.accent : Theme.muted
                    font.pixelSize: 12
                }

                Row {
                    anchors.right: parent.right
                    spacing: 10

                    Repeater {
                        model: [
                            { label: I18n.t("Cancel"), primary: false },
                            { label: I18n.t("Authenticate"), primary: true }
                        ]
                        Rectangle {
                            required property var modelData
                            width: label.implicitWidth + 32
                            height: 38
                            radius: 19
                            color: modelData.primary ? Theme.accent
                                : hover.containsMouse ? Theme.surface2 : Theme.widget
                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                color: parent.modelData.primary ? Theme.accentText : Theme.fg
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: hover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: parent.modelData.primary ? root.submit() : root.cancel()
                            }
                        }
                    }
                }
            }
        }
    }
}
