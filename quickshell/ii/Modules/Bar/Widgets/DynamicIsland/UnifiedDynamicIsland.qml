import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.services
import qs.modules.common
import "../../Components" as BarComponents
import qs.modules.ii.bar as BarModules
import "../SystemTray" as STray
import qs.Modules.Bar.Widgets.MainPanel.Dashboard as MainPanelDashboard
import qs.Modules.Bar.Widgets.MainPanel.Performance as MainPanelPerformance
import qs.Modules.ControlCenter
import "Notes" as Notes

Rectangle {
    id: root

    // Per-monitor fullscreen gate; bound from MinflairBarSurface.surface.isFullscreen when hosted there.
    // Falls back to global HyprlandData.hasFullscreen when used standalone.
    property bool isFullscreen: HyprlandData.hasFullscreen

    property string currentMode: {
        if (JarvisService.status !== "idle") return "jarvis";
        if (root.isAiMode || AppState.activePopup === "ai") return "ai";
        if (AppState.activePopup === "notes") return "notes";
        if (AppState.activePopup === "workspaceRename") return "workspaceRename";
        if (AppState.activePopup === "launcher") return "launcher";
        if (AppState.activePopup === "dashboard" || AppState.activePopup === "controlCenter") return "dashboard";
        if (GlobalStates.osdVolumeOpen) return "volume";
        if (!root.isFullscreen && IslandState.mode !== IslandState.modeIdle && IslandState.activeNotification !== null) return "notif";
        return "clock";
    }

    property bool isAiMode: AppState.activePopup === "ai"
    readonly property bool isNotifActive: currentMode === "notif"
    readonly property bool isCritical: isNotifActive && IslandState.isCritical(IslandState.activeNotification)
    readonly property bool isExpanded: currentMode === "launcher" || currentMode === "dashboard" || currentMode === "notif" || currentMode === "workspaceRename" || currentMode === "volume" || currentMode === "jarvis" || currentMode === "ai" || currentMode === "notes" || JarvisService.isBusy

    width: implicitWidth
    height: implicitHeight
    radius: isExpanded ? 28 : (height / 2)
    color: Theme.bg
    border.width: 1
    border.color: isCritical ? Theme.accent : (JarvisService.isListening ? Theme.accent : (JarvisService.isTranscribing ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.7) : (currentMode === "ai" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : (isNotifActive ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)))))
    clip: true

    readonly property bool isSubViewOpen: dashboardActiveTab === 3 && (controlCenterView ? controlCenterView.currentSubView !== "home" : false)

    implicitWidth: {
        if (currentMode === "workspaceRename") return 460;
        if (currentMode === "volume") return 270;
        if (currentMode === "dashboard") {
            if (dashboardActiveTab === 1) return 600; // Rendimiento
            if (dashboardActiveTab === 3) {
                var sub = controlCenterView ? controlCenterView.currentSubView : "home";
                if (sub === "wifi") return 560;
                if (sub === "bluetooth") return 560;
                if (sub === "audio") return 580;
                if (sub === "notifications" || sub === "notifs") return 800;
                if (sub === "widgets") return 760;
                return 880; // 2-column Control Center (expanded width)
            }
            return 680;
        }
        if (currentMode === "notes") return 560;
        if (currentMode === "ai") return 720;
        if (currentMode === "launcher") return searchQuery !== "" ? 720 : 480;
        if (currentMode === "notif") return 480;
        if (currentMode === "jarvis") return 360;
        return idleContentRow.implicitWidth + 32;
    }

    implicitHeight: {
        if (currentMode === "workspaceRename") return 48;
        if (currentMode === "volume") return 48;
        if (currentMode === "dashboard") {
            if (dashboardActiveTab === 0) return 590; // Dashboard
            if (dashboardActiveTab === 1) return 410; // Rendimiento
            if (dashboardActiveTab === 2) return 500; // Codex
            if (dashboardActiveTab === 3) {
                var sub = controlCenterView ? controlCenterView.currentSubView : "home";
                if (sub === "wifi") return 520;
                if (sub === "bluetooth") return 540;
                if (sub === "audio") return 500;
                if (sub === "notifications" || sub === "notifs") return 680;
                if (sub === "widgets") return 640;
                return 600; // 2-column Control Center (expanded height)
            }

            return 580;
        }
        if (currentMode === "notes") return 420;
        if (currentMode === "ai") return 520;
        if (currentMode === "launcher") {
            if (searchQuery === "") return 48;
            if (searchModel.count === 0) return 170;
            return Math.min(540, 68 + Math.min(searchModel.count, 6) * 58);
        }
        if (currentMode === "notif") {
            return Math.max(110, notifNotchColumn.implicitHeight + 28);
        }
        if (currentMode === "jarvis") return 54;
        return 48;
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutBack
            easing.overshoot: 1.12
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Behavior on radius {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    focus: root.isExpanded

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            if (root.currentMode === "ai" || AppState.activePopup === "ai") {
                IslandAiService.clearSession();
                AppState.activePopup = "";
                event.accepted = true;
            } else if (root.currentMode === "launcher" || AppState.activePopup === "launcher") {
                AppState.activePopup = "";
                event.accepted = true;
            } else if (root.currentMode === "workspaceRename" || AppState.activePopup === "workspaceRename") {
                AppState.activePopup = "";
                event.accepted = true;
            } else if (root.currentMode === "dashboard" || AppState.activePopup === "dashboard" || AppState.activePopup === "controlCenter") {
                AppState.activePopup = "";
                event.accepted = true;
            } else if (root.currentMode === "notes" || AppState.activePopup === "notes") {
                AppState.activePopup = "";
                event.accepted = true;
            }
        }
    }

    Timer {
        id: openDashboardTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (root.currentMode === "clock" && clockHoverHandler.hovered) {
                AppState.activePopup = "dashboard";
            }
        }
    }

    Timer {
        id: autoCloseDashboardTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (root.currentMode === "dashboard" && !islandHoverHandler.hovered) {
                AppState.activePopup = "";
            }
        }
    }

    HoverHandler {
        id: islandHoverHandler
        onHoveredChanged: {
            if (root.currentMode === "dashboard") {
                if (hovered) {
                    autoCloseDashboardTimer.stop();
                } else {
                    autoCloseDashboardTimer.restart();
                }
            }
        }
    }

    // ==========================================
    // 1. ALL-IN-ONE IDLE VIEW (Tight, compact RowLayout)
    // ==========================================
    Item {
        id: idleContainer
        anchors.fill: parent
        opacity: root.currentMode === "clock" ? 1 : 0
        scale: root.currentMode === "clock" ? 1 : 0.8
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        RowLayout {
            id: idleContentRow
            anchors.centerIn: parent
            spacing: 12

            // LEFT: Workspaces (Avatar + Active Workspaces)
            BarComponents.Workspaces {
                id: workspacesWidget
                transparentBg: true
                Layout.alignment: Qt.AlignVCenter
            }

            // CENTER: Clock
            Item {
                id: clockArea
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: clockInnerRow.implicitWidth + 12
                implicitHeight: 32

                RowLayout {
                    id: clockInnerRow
                    anchors.centerIn: parent
                    spacing: Constants.sizeXs

                    ThemedText {
                        text: Qt.formatDateTime(SystemInfoService.currentTime, "HH:mm")
                        font.bold: true
                        font.pixelSize: Constants.sizeSm
                    }

                    ThemedText {
                        text: "•"
                        color: Theme.muted
                        font.pixelSize: Constants.size2Xs
                    }

                    ThemedText {
                        text: Qt.formatDateTime(SystemInfoService.currentTime, "ddd, d MMM")
                        color: Theme.muted
                        font.pixelSize: Constants.sizeSm
                    }
                }

                HoverHandler {
                    id: clockHoverHandler
                    enabled: root.currentMode === "clock"
                    onHoveredChanged: {
                        if (hovered) {
                            openDashboardTimer.restart();
                        } else {
                            openDashboardTimer.stop();
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.currentMode === "clock"
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        openDashboardTimer.stop();
                        AppState.activePopup = "dashboard";
                    }
                }
            }

            // JARVIS DICTATION BADGE (Modo Dictado)
            Rectangle {
                id: jarvisDictationBadge
                visible: JarvisService.dictationActive
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: visible ? (dictationRow.implicitWidth + 14) : 0
                implicitHeight: 24
                radius: 12
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)

                RowLayout {
                    id: dictationRow
                    anchors.centerIn: parent
                    spacing: 5

                    SvgIcon {
                        icon: "microphone"
                        iconSize: 11
                        iconColor: Theme.accent
                        flat: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ThemedText {
                        text: "DICTADO"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 0.6
                        color: Theme.accent
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Behavior on implicitWidth {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }
            }

            // NOTES CHIP BADGE
            Rectangle {
                id: notesChipBadge
                visible: NotesService.count > 0
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: visible ? (notesChipRow.implicitWidth + 14) : 0
                implicitHeight: 24
                radius: 12
                color: notesChipMouseArea.containsMouse
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)
                    : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                border.width: 1
                border.color: notesChipMouseArea.containsMouse
                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)
                    : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on implicitWidth {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                RowLayout {
                    id: notesChipRow
                    anchors.centerIn: parent
                    spacing: 4

                    ThemedText {
                        text: "󰎞"
                        font.pixelSize: 11
                        color: Theme.accent
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ThemedText {
                        text: NotesService.count.toString()
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.accent
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                MouseArea {
                    id: notesChipMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AppState.togglePopup("notes");
                    }
                }
            }

            // JARVIS ACTIVITY (Listening Orb/Pill / Transcribing Indicator)
            Item {
                id: jarvisActivityArea
                visible: JarvisService.status !== "idle"
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: visible ? jarvisPill.implicitWidth : 0
                implicitHeight: 28

                // Pulsing aura for listening state
                Rectangle {
                    id: jarvisPulseAura
                    anchors.centerIn: parent
                    width: jarvisPill.width + 10
                    height: jarvisPill.height + 4
                    radius: height / 2
                    color: Theme.accent
                    visible: JarvisService.isListening
                    opacity: 0.3

                    SequentialAnimation on opacity {
                        running: jarvisActivityArea.visible && JarvisService.isListening
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.12; to: 0.45; duration: 650; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.45; to: 0.12; duration: 650; easing.type: Easing.InOutQuad }
                    }

                    SequentialAnimation on scale {
                        running: jarvisActivityArea.visible && JarvisService.isListening
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.96; to: 1.06; duration: 650; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.06; to: 0.96; duration: 650; easing.type: Easing.InOutQuad }
                    }
                }

                Rectangle {
                    id: jarvisPill
                    anchors.centerIn: parent
                    implicitHeight: 26
                    implicitWidth: jarvisPillRow.implicitWidth + 18
                    radius: 13
                    color: JarvisService.isListening 
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                        : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                    border.width: 1
                    border.color: JarvisService.isListening ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.2)

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/jarvis_audio.py"), "toggle", "--dispatch"]);
                        }
                    }

                    RowLayout {
                        id: jarvisPillRow
                        anchors.centerIn: parent
                        spacing: 7

                        // Glowing Orb / Indicator
                        Item {
                            width: 14
                            height: 14
                            Layout.alignment: Qt.AlignVCenter

                            // Listening pulsing orb
                            Rectangle {
                                anchors.centerIn: parent
                                width: 9
                                height: 9
                                radius: 4.5
                                color: Theme.accent
                                visible: JarvisService.isListening

                                SequentialAnimation on scale {
                                    running: jarvisActivityArea.visible && JarvisService.isListening
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.8; to: 1.25; duration: 450; easing.type: Easing.InOutSine }
                                    NumberAnimation { from: 1.25; to: 0.8; duration: 450; easing.type: Easing.InOutSine }
                                }
                            }

                            // Transcribing subtle waiting spinner/dots
                            Rectangle {
                                anchors.centerIn: parent
                                width: 11
                                height: 11
                                radius: 5.5
                                color: "transparent"
                                border.width: 2
                                border.color: Theme.accent
                                visible: JarvisService.isTranscribing

                                NumberAnimation on rotation {
                                    running: jarvisActivityArea.visible && JarvisService.isTranscribing
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                }
                            }
                        }

                        ThemedText {
                            text: JarvisService.isListening ? "Escuchando..." : (JarvisService.isTranscribing ? "Transcribiendo..." : "")
                            font.pixelSize: 11
                            font.bold: true
                            color: JarvisService.isListening ? Theme.accent : Theme.fg
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                Behavior on implicitWidth {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }
            }

            // RIGHT: Control Center + SysTray
            RowLayout {
                id: rightControlsRow
                Layout.alignment: Qt.AlignVCenter
                spacing: Constants.sizeSm

                BarComponents.ControlCenterButton {
                    transparentBg: true
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        if (AppState.activePopup === "controlCenter" && root.dashboardActiveTab === 3 && controlCenterView.currentSubView === "notifs") {
                            AppState.activePopup = "";
                        } else {
                            root.dashboardActiveTab = 3;
                            controlCenterView.openPanel("notifs");
                            AppState.activePopup = "controlCenter";
                        }
                    }
                }

                BarModules.SysTray {
                    id: sysTrayWidget
                    Layout.alignment: Qt.AlignVCenter
                    showSeparator: false
                    showOverflowMenu: true
                }
            }
        }
    }

    // ==========================================
    // 1b. JARVIS VOICE ISLAND VIEW (Active Voice Notch)
    // ==========================================
    Item {
        id: jarvisContainer
        anchors.fill: parent
        opacity: root.currentMode === "jarvis" ? 1 : 0
        scale: root.currentMode === "jarvis" ? 1 : 0.88
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Quickshell.execDetached(["python3", Quickshell.shellPath("scripts/jarvis_audio.py"), "toggle", "--dispatch"]);
            }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 12

            // Visual Voice Indicator: Glowing Orb + Pulsing Aura / Spinner
            Item {
                width: 26
                height: 26
                Layout.alignment: Qt.AlignVCenter

                // Pulsing outer aura ring
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.accent
                    opacity: 0.4
                    visible: JarvisService.isListening

                    SequentialAnimation on scale {
                        running: jarvisContainer.visible && JarvisService.isListening
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.85; to: 1.25; duration: 600; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.25; to: 0.85; duration: 600; easing.type: Easing.InOutQuad }
                    }
                    SequentialAnimation on opacity {
                        running: jarvisContainer.visible && JarvisService.isListening
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.6; to: 0.15; duration: 600; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 0.15; to: 0.6; duration: 600; easing.type: Easing.InOutQuad }
                    }
                }

                // Core Microphone Orb
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                    visible: JarvisService.isListening

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "microphone"
                        iconSize: 11
                        iconColor: Theme.accent
                        flat: true
                    }

                    SequentialAnimation on scale {
                        running: jarvisContainer.visible && JarvisService.isListening
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.9; to: 1.15; duration: 450; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 1.15; to: 0.9; duration: 450; easing.type: Easing.InOutSine }
                    }
                }

                // Transcribing Rotating Spinner
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: 9
                    color: "transparent"
                    border.width: 2.5
                    border.color: Theme.accent
                    visible: JarvisService.isTranscribing

                    NumberAnimation on rotation {
                        running: jarvisContainer.visible && JarvisService.isTranscribing
                        from: 0
                        to: 360
                        duration: 800
                        loops: Animation.Infinite
                    }
                }

                // Thinking Rotating Sparkles
                SvgIcon {
                    anchors.centerIn: parent
                    icon: "sparkles"
                    iconSize: 16
                    iconColor: Theme.accent
                    flat: true
                    visible: JarvisService.isThinking

                    RotationAnimation on rotation {
                        running: jarvisContainer.visible && JarvisService.isThinking
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1200
                    }
                }

                // Speaking Audio Waveform Visualizer
                Row {
                    anchors.centerIn: parent
                    spacing: 2.5
                    visible: JarvisService.isSpeaking

                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            required property int index
                            width: 3
                            height: 6
                            radius: 1.5
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on height {
                                running: jarvisContainer.visible && JarvisService.isSpeaking
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: index === 1 || index === 2 ? 18 : 11
                                    duration: 220 + (index * 70)
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    to: 5
                                    duration: 220 + (index * 70)
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }

            // Labels: State Title + Subtitle
            ColumnLayout {
                spacing: 1
                Layout.alignment: Qt.AlignVCenter

                ThemedText {
                    text: {
                        if (JarvisService.isListening) return Translation.tr("Listening...");
                        if (JarvisService.isTranscribing) return Translation.tr("Transcribing...");
                        if (JarvisService.isThinking) return Translation.tr("Thinking...");
                        if (JarvisService.isSpeaking) return "Jarvis";
                        return "Jarvis";
                    }
                    font.pixelSize: 13
                    font.bold: true
                    color: (JarvisService.isListening || JarvisService.isThinking || JarvisService.isSpeaking) ? Theme.accent : Theme.fg
                }

                ThemedText {
                    text: {
                        if (JarvisService.dictationActive) return Translation.tr("Dictation mode active");
                        if (JarvisService.isListening) return Translation.tr("Habla o pulsa para enviar");
                        if (JarvisService.isTranscribing) return Translation.tr("Processing audio...");
                        if (JarvisService.isThinking) return Translation.tr("Thinking response...");
                        if (JarvisService.isSpeaking) return Translation.tr("Speaking...");
                        return "";
                    }
                    font.pixelSize: 10
                    color: Theme.muted
                }
            }

            // Optional DICTADO tag if dictation active
            Rectangle {
                visible: JarvisService.dictationActive
                implicitWidth: dictRowVoice.implicitWidth + 10
                implicitHeight: 20
                radius: 10
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2)
                border.width: 1
                border.color: Theme.accent
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: dictRowVoice
                    anchors.centerIn: parent
                    spacing: 4

                    SvgIcon {
                        icon: "microphone"
                        iconSize: 9
                        iconColor: Theme.accent
                        flat: true
                    }

                    ThemedText {
                        text: "DICTADO"
                        font.pixelSize: 9
                        font.bold: true
                        color: Theme.accent
                    }
                }
            }
        }
    }

    // ==========================================
    // 2. NOTIFICATION VIEW (Notch)
    // ==========================================
    Item {
        id: notifContainer
        anchors.fill: parent
        opacity: root.currentMode === "notif" ? 1 : 0
        scale: root.currentMode === "notif" ? 1 : 0.92
        visible: opacity > 0
        clip: true

        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

        HoverHandler {
            id: notifHoverHandler
            onHoveredChanged: {
                if (hovered) {
                    IslandState.pauseActiveTimer();
                } else {
                    IslandState.resumeActiveTimer();
                }
            }
        }

        ColumnLayout {
            id: notifNotchColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                Item {
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: 22
                    Layout.alignment: Qt.AlignVCenter

                    NotificationIcon {
                        anchors.fill: parent
                        notifData: IslandState.activeNotification
                        iconSize: 18
                    }
                }

                ThemedText {
                    text: {
                        let app = IslandState.activeNotification?.appName || "Notificación";
                        let count = IslandState.activeNotification?.appMessageCount || 1;
                        return count > 1 ? (app + " (" + count + ")") : app;
                    }
                    font.bold: true
                    font.pixelSize: Constants.sizeSm
                    color: Theme.muted
                    Layout.alignment: Qt.AlignVCenter
                }

                ThemedText {
                    text: "•"
                    color: Theme.muted
                    font.pixelSize: Constants.size2Xs
                    Layout.alignment: Qt.AlignVCenter
                }

                ThemedText {
                    text: {
                        let ts = IslandState.activeNotification?.timestamp || IslandState.activeNotification?.time;
                        if (!ts) return "ahora";
                        let date = new Date(ts);
                        return Qt.formatDateTime(date, "HH:mm");
                    }
                    color: Theme.muted
                    font.pixelSize: Constants.sizeXs
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: IslandState.queueCount > 0
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: badgeText.implicitWidth + 12
                    radius: 10
                    color: badgeArea.containsMouse ? Theme.bgSecondary : Theme.bgTertiary

                    ThemedText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: "+" + IslandState.queueCount
                        font.pixelSize: Constants.size3Xs
                        font.bold: true
                        color: Theme.fg
                    }

                    MouseArea {
                        id: badgeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: IslandState.dismissActive()
                    }
                }

                SvgIconButton {
                    visible: IslandState.queueCount > 0
                    icon: "trash"
                    iconSize: 12
                    flat: true
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: IslandState.dismissAll()
                }

                SvgIconButton {
                    icon: "x"
                    iconSize: 12
                    flat: true
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: IslandState.dismissActive()
                }
            }

            ThemedText {
                Layout.fillWidth: true
                text: IslandState.activeNotification?.summary || ""
                font.bold: true
                font.pixelSize: Constants.sizeMd
                color: Theme.fg
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                visible: text !== ""
            }

            ThemedText {
                Layout.fillWidth: true
                text: IslandState.activeNotification?.body || ""
                color: Theme.muted
                font.pixelSize: Constants.sizeSm
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.RichText
                visible: text !== ""
                onLinkActivated: (link) => Qt.openUrlExternally(link)
            }

            Image {
                Layout.fillWidth: true
                Layout.maximumHeight: 140
                fillMode: Image.PreserveAspectFit
                source: {
                    let img = IslandState.activeNotification?.image || "";
                    if (!img) return "";
                    if (img.startsWith("file://") || img.startsWith("image://") || img.startsWith("http")) return img;
                    if (img.startsWith("/")) return "file://" + img;
                    return img;
                }
                visible: (IslandState.activeNotification?.image || "") !== ""
                asynchronous: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm
                visible: {
                    let actions = IslandState.activeNotification?.actions || IslandState.activeNotification?.notification?.actions;
                    return Boolean(actions && actions.length > 0);
                }

                Repeater {
                    model: IslandState.activeNotification?.actions || IslandState.activeNotification?.notification?.actions || []

                    ThemedButton {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.text || "Open"
                        onClicked: {
                            if (typeof modelData.invoke === "function") {
                                modelData.invoke();
                            } else if (IslandState.activeNotification?.notification && typeof IslandState.activeNotification.notification.invokeAction === "function") {
                                IslandState.activeNotification.notification.invokeAction(modelData.identifier);
                            } else if (IslandState.activeNotification?.notificationId !== undefined && typeof Notifications !== "undefined" && typeof Notifications.attemptInvokeAction === "function") {
                                Notifications.attemptInvokeAction(IslandState.activeNotification.notificationId, modelData.identifier);
                            }
                            IslandState.dismissActive();
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 2
                radius: 1
                color: root.isCritical ? Theme.accent : Theme.accentComplementary
                opacity: (IslandState.activeNotification?.progress !== undefined) ? 0.8 : 0
                visible: opacity > 0
                width: parent ? parent.width * (IslandState.activeNotification?.progress ?? 1) : 0
            }
        }
    }

    // ==========================================
    // 3. LAUNCHER VIEW
    // ==========================================
    property string searchQuery: ""
    property int selectedIndex: 0

    function resolveIcon(iconName) {
        if (!iconName || iconName === "") return "image://icon/application-x-executable";
        if (iconName.startsWith("image://") || iconName.startsWith("file://") || iconName.startsWith("/")) {
            return iconName;
        }
        const path = Quickshell.iconPath(iconName, true);
        if (path && path.length > 0) return path;
        const guessed = AppSearch.guessIcon(iconName);
        if (guessed && guessed.length > 0) {
            const guessPath = Quickshell.iconPath(guessed, true);
            if (guessPath && guessPath.length > 0) return guessPath;
        }
        return `image://icon/${iconName}`;
    }

    function switchToAi(q) {
        if (!q || q.trim() === "") return;
        const queryText = q.replace(/^\?\?\s*/, "").trim();
        root.searchQuery = "";
        if (searchInput) searchInput.text = "";
        AppState.openPopup("ai");
        IslandAiService.ask(queryText);
    }

    function cleanMathDisplay(raw) {
        if (!raw) return "";
        let str = raw.trim();
        if (str.startsWith("=")) str = str.slice(1).trim();
        else if (str.toLowerCase().startsWith("calc ")) str = str.slice(5).trim();
        let openCount = 0;
        for (let ch of str) {
            if (ch === "(") openCount++;
            else if (ch === ")") openCount = Math.max(0, openCount - 1);
        }
        str += ")".repeat(openCount);
        return str;
    }

    function evaluateMath(raw) {
        if (!raw) return null;
        let str = raw.trim();
        let hasPrefix = false;
        if (str.startsWith("=")) {
            hasPrefix = true;
            str = str.slice(1).trim();
        } else if (str.toLowerCase().startsWith("calc ")) {
            hasPrefix = true;
            str = str.slice(5).trim();
        }
        if (!str) return null;

        str = str.replace(/×/g, "*").replace(/÷/g, "/");
        str = str.replace(/(\d|\))\s*[xX]\s*(\d|\()/g, "$1 * $2");
        str = str.replace(/(\d),(\d)/g, "$1.$2");
        str = str.replace(/(\d|\))\s*(\()/g, "$1 * $2").replace(/(\))\s*(\d)/g, "$1 * $2");

        let openCount = 0;
        for (let ch of str) {
            if (ch === "(") openCount++;
            else if (ch === ")") openCount = Math.max(0, openCount - 1);
        }
        str += ")".repeat(openCount);

        const hasOperator = /[+\-*\/^%]/.test(str);
        if (!hasPrefix && !hasOperator) return null;
        if (!/^[0-9+\-*\/^%().\s]+$/.test(str)) return null;

        const tokens = [];
        let i = 0;
        while (i < str.length) {
            let ch = str[i];
            if (/\s/.test(ch)) { i++; continue; }
            if (/[0-9.]/.test(ch)) {
                let numStr = "";
                while (i < str.length && /[0-9.]/.test(str[i])) {
                    numStr += str[i++];
                }
                if (numStr === "." || (numStr.match(/\./g) || []).length > 1) return null;
                tokens.push({ type: "NUM", val: parseFloat(numStr) });
                continue;
            }
            if ("+-*/^%()".indexOf(ch) !== -1) {
                tokens.push({ type: ch });
                i++;
                continue;
            }
            return null;
        }
        if (tokens.length === 0) return null;

        let pos = 0;
        function peek() { return tokens[pos]; }
        function consume(expected) {
            const t = tokens[pos++];
            if (expected && (!t || t.type !== expected)) throw new Error("Unexpected token");
            return t;
        }

        function parseExpression() {
            let node = parseTerm();
            while (peek() && (peek().type === "+" || peek().type === "-")) {
                let op = consume().type;
                let right = parseTerm();
                node = (op === "+") ? (node + right) : (node - right);
            }
            return node;
        }

        function parseTerm() {
            let node = parseFactor();
            while (peek() && (peek().type === "*" || peek().type === "/" || peek().type === "%")) {
                let op = consume().type;
                let right = parseFactor();
                if (op === "*") node = node * right;
                else if (op === "/") {
                    if (right === 0) throw new Error("Division by zero");
                    node = node / right;
                } else if (op === "%") {
                    node = node % right;
                }
            }
            return node;
        }

        function parseFactor() {
            let node = parsePrimary();
            while (peek() && peek().type === "^") {
                consume("^");
                let right = parsePrimary();
                node = Math.pow(node, right);
            }
            return node;
        }

        function parsePrimary() {
            let t = peek();
            if (!t) throw new Error("Unexpected end of input");
            if (t.type === "+") { consume("+"); return parsePrimary(); }
            if (t.type === "-") { consume("-"); return -parsePrimary(); }
            if (t.type === "(") {
                consume("(");
                let val = parseExpression();
                consume(")");
                return val;
            }
            if (t.type === "NUM") {
                consume("NUM");
                return t.val;
            }
            throw new Error("Unexpected token: " + t.type);
        }

        try {
            let res = parseExpression();
            if (pos < tokens.length) return null;
            if (!isFinite(res)) return null;
            return parseFloat(res.toFixed(10)).toString();
        } catch (e) {
            return null;
        }
    }

    ListModel { id: searchModel }

    function updateSearchModel() {
        searchModel.clear();
        if (root.searchQuery === "") return;

        const mathVal = evaluateMath(root.searchQuery);
        if (mathVal !== null) {
            const displayExpr = cleanMathDisplay(root.searchQuery);
            const label = (displayExpr === mathVal) ? mathVal : `${displayExpr} = ${mathVal}`;
            searchModel.append({
                name: label,
                category: Translation.tr("Math calculation • Enter to copy"),
                iconName: Quickshell.iconPath("accessories-calculator", true) || `${Quickshell.shellDir}/assets/icons/fluent/calculator.svg` || "accessories-calculator",
                mathValue: mathVal,
                rawEntry: ({})
            });
        }

        const results = AppSearch.fuzzyQuery(root.searchQuery);
        for (let i = 0; i < Math.min(results.length, 12); i++) {
            const entry = results[i];
            searchModel.append({
                name: entry.name || "",
                category: (entry.categories && entry.categories.length > 0) ? entry.categories[0] : (entry.comment || "Aplicación"),
                iconName: entry.icon || "application-x-executable",
                mathValue: "",
                rawEntry: entry
            });
        }
    }

    function launchItem(index) {
        if (index < 0 || index >= searchModel.count) return;
        const item = searchModel.get(index);
        if (!item) return;
        if (item.mathValue && item.mathValue !== "") {
            Quickshell.clipboardText = item.mathValue;
            AppState.activePopup = "";
            return;
        }
        if (item.rawEntry) {
            launchEntry(item.rawEntry);
        }
    }

    function launchEntry(entry) {
        if (!entry) return;
        if (typeof entry.execute === "function") {
            entry.execute();
        } else if (entry.id) {
            AppSearch.launchApp(entry.id);
        } else if (entry.exec) {
            Quickshell.execDetached(entry.exec);
        }
        AppState.activePopup = "";
    }

    ColumnLayout {
        id: launcherColumn
        anchors.fill: parent
        anchors.margins: 0
        spacing: 8
        opacity: root.currentMode === "launcher" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 180 } }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 12

            SvgIcon {
                icon: (evaluateMath(root.searchQuery) !== null || root.searchQuery.startsWith("=") || root.searchQuery.startsWith("calc")) ? "icons/fluent/calculator" : "search"
                iconColor: searchInput.text !== "" ? Theme.accent : Theme.muted
                iconSize: 20
                flat: true
                Layout.alignment: Qt.AlignVCenter
            }

            TextField {
                id: searchInput
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                focus: root.currentMode === "launcher"
                placeholderText: Translation.tr("Search applications, math (=)...")
                placeholderTextColor: Theme.muted
                font.family: Constants.fontFamily
                font.pixelSize: 14
                color: Theme.fg
                background: null
                leftPadding: 0
                rightPadding: 0

                onTextChanged: {
                    root.searchQuery = text;
                    root.selectedIndex = 0;
                    updateSearchModel();
                }

                Keys.onTabPressed: (event) => {
                    if (text.trim() !== "") {
                        switchToAi(text);
                        event.accepted = true;
                    }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        if (text !== "") text = "";
                        else AppState.activePopup = "";
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab) {
                        if (text.trim() !== "") {
                            switchToAi(text);
                            event.accepted = true;
                        }
                    } else if (event.key === Qt.Key_Down) {
                        if (searchListView.count > 0) {
                            root.selectedIndex = Math.min(root.selectedIndex + 1, searchListView.count - 1);
                            searchListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                        searchListView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        event.accepted = true;
                    }
                }

                onAccepted: {
                    if (searchListView.count > 0 && root.selectedIndex >= 0 && root.selectedIndex < searchListView.count) {
                        launchItem(root.selectedIndex);
                    }
                }
            }

            Rectangle {
                Layout.preferredHeight: 22
                Layout.preferredWidth: 38
                Layout.alignment: Qt.AlignVCenter
                radius: 11
                color: Qt.rgba(1, 1, 1, 0.08)

                ThemedText {
                    anchors.centerIn: parent
                    text: "ESC"
                    font.pixelSize: Constants.size3Xs
                    font.bold: true
                    color: Theme.muted
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: AppState.activePopup = ""
                }
            }
        }

        Divider {
            Layout.fillWidth: true
            visible: root.searchQuery !== ""
        }

        ListView {
            id: searchListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.bottomMargin: 8
            clip: true
            model: searchModel
            visible: root.searchQuery !== ""

            delegate: Rectangle {
                id: itemDelegate
                required property string name
                required property string category
                required property string iconName
                property var rawEntry: null
                property string mathValue: ""
                required property int index

                width: searchListView.width
                height: 52
                radius: Constants.sizeMd
                color: root.selectedIndex === index ? Theme.bgTertiary : (itemMouse.containsMouse ? Theme.bgSecondary : "transparent")

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        root.selectedIndex = itemDelegate.index;
                        launchItem(itemDelegate.index);
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Image {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        source: root.resolveIcon(itemDelegate.iconName || "")
                        fillMode: Image.PreserveAspectFit
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        ThemedText {
                            text: itemDelegate.name || ""
                            font.bold: true
                            font.pixelSize: Constants.sizeSm
                        }

                        ThemedText {
                            text: itemDelegate.category || ""
                            color: Theme.muted
                            font.pixelSize: Constants.sizeXs
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // 4. AI AGENT VIEW
    // ==========================================
    ColumnLayout {
        id: aiContainer
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8
        opacity: root.currentMode === "ai" ? 1 : 0
        visible: opacity > 0
        focus: root.currentMode === "ai"

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                IslandAiService.clearSession();
                AppState.activePopup = "";
                event.accepted = true;
            }
        }

        Behavior on opacity { NumberAnimation { duration: 180 } }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 12

            SvgIcon {
                icon: "sparkles"
                iconColor: IslandAiService.running ? Theme.accent : Theme.muted
                iconSize: 20
                flat: true
                Layout.alignment: Qt.AlignVCenter

                RotationAnimation on rotation {
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 2000
                    running: IslandAiService.running
                }
            }

            TextField {
                id: aiInput
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                focus: root.currentMode === "ai"
                placeholderText: IslandAiService.prompt === "" ? Translation.tr("Ask anything (e.g. search web, inspect files)...") : Translation.tr("Ask a follow-up...")
                placeholderTextColor: Theme.muted
                font.family: Constants.fontFamily
                font.pixelSize: 14
                color: Theme.fg
                background: null
                leftPadding: 0
                rightPadding: 0

                onAccepted: {
                    if (text.trim() !== "") {
                        IslandAiService.ask(text.trim());
                        text = "";
                    }
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        IslandAiService.clearSession();
                        AppState.activePopup = "";
                        event.accepted = true;
                    }
                }
            }
            
            Rectangle {
                visible: IslandAiService.status !== "" || IslandAiService.activeTool !== ""
                Layout.preferredHeight: 24
                radius: 12
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.3)
                implicitWidth: aiStatusRow.implicitWidth + 16
                Layout.alignment: Qt.AlignVCenter

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: IslandAiService.running
                    NumberAnimation { from: 0.6; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.0; to: 0.6; duration: 600; easing.type: Easing.InOutQuad }
                }

                RowLayout {
                    id: aiStatusRow
                    anchors.centerIn: parent
                    spacing: 6

                    SvgIcon {
                        icon: IslandAiService.activeTool === "web_search" ? "search" : (IslandAiService.activeTool === "list_dir" ? "dashboard" : (IslandAiService.activeTool === "read_file" ? "code" : "sparkles"))
                        iconSize: 12
                        iconColor: Theme.accent
                        flat: true
                        Layout.alignment: Qt.AlignVCenter

                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 1500
                            running: IslandAiService.activeTool !== ""
                        }
                    }

                    ThemedText {
                        text: IslandAiService.status
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.accent
                        Layout.alignment: Qt.AlignVCenter
                        elide: Text.ElideRight
                        Layout.maximumWidth: 260
                    }
                }
            }

            Rectangle {
                id: aiCloseBtn
                Layout.preferredHeight: 26
                Layout.preferredWidth: closeBtnRow.implicitWidth + 14
                Layout.alignment: Qt.AlignVCenter
                radius: 13
                color: closeMouseArea.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)

                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    id: closeBtnRow
                    anchors.centerIn: parent
                    spacing: 4

                    SvgIcon {
                        icon: "x"
                        iconSize: 10
                        iconColor: closeMouseArea.containsMouse ? Theme.fg : Theme.muted
                        flat: true
                    }

                    ThemedText {
                        text: "ESC"
                        font.pixelSize: Constants.size3Xs
                        font.bold: true
                        color: closeMouseArea.containsMouse ? Theme.fg : Theme.muted
                    }
                }

                MouseArea {
                    id: closeMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        IslandAiService.clearSession();
                        AppState.activePopup = "";
                    }
                }
            }
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                id: aiCardColumn
                width: parent.width
                spacing: 10

                // 1. Fresh empty state
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 40
                    spacing: 12
                    visible: IslandAiService.prompt === "" && !IslandAiService.running
                    Layout.alignment: Qt.AlignHCenter

                    SvgIcon {
                        icon: "sparkles"
                        iconSize: 36
                        iconColor: Theme.accent
                        flat: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    ThemedText {
                        text: Translation.tr("Dynamic Island AI")
                        font.pixelSize: 18
                        font.bold: true
                        color: Theme.fg
                        Layout.alignment: Qt.AlignHCenter
                    }

                    ThemedText {
                        text: Translation.tr("Ask anything... Type your query or press Tab to switch modes. Press Esc to exit.")
                        font.pixelSize: 13
                        color: Theme.muted
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        Layout.topMargin: 8

                        Rectangle {
                            radius: 12
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            implicitWidth: pill1Text.implicitWidth + 20
                            implicitHeight: 28

                            ThemedText {
                                id: pill1Text
                                anchors.centerIn: parent
                                text: "🌐 " + Translation.tr("Live Web Search")
                                font.pixelSize: 11
                                color: Theme.muted
                            }
                        }

                        Rectangle {
                            radius: 12
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            implicitWidth: pill2Text.implicitWidth + 20
                            implicitHeight: 28

                            ThemedText {
                                id: pill2Text
                                anchors.centerIn: parent
                                text: "📁 " + Translation.tr("Filesystem Inspection")
                                font.pixelSize: 11
                                color: Theme.muted
                            }
                        }

                        Rectangle {
                            radius: 12
                            color: Qt.rgba(1, 1, 1, 0.05)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            implicitWidth: pill3Text.implicitWidth + 20
                            implicitHeight: 28

                            ThemedText {
                                id: pill3Text
                                anchors.centerIn: parent
                                text: "⚡ " + Translation.tr("Local Gemma-4")
                                font.pixelSize: 11
                                color: Theme.muted
                            }
                        }
                    }
                }

                // 2. User prompt bubble
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: promptText.implicitHeight + 14
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.06)
                    radius: 8
                    visible: IslandAiService.prompt !== ""

                    ThemedText {
                        id: promptText
                        anchors.fill: parent
                        anchors.margins: 8
                        text: IslandAiService.prompt
                        color: Theme.fg
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                }

                // 3. Tool Activity Timeline
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    visible: IslandAiService.toolHistory && IslandAiService.toolHistory.length > 0

                    Repeater {
                        model: IslandAiService.toolHistory
                        delegate: Rectangle {
                            id: toolItem
                            required property var modelData
                            required property int index

                            property bool expanded: false

                            Layout.fillWidth: true
                            implicitHeight: toolCol.implicitHeight + 14
                            radius: 8
                            color: Qt.rgba(1, 1, 1, 0.04)
                            border.width: 1
                            border.color: modelData.status === "running" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4) : Qt.rgba(1, 1, 1, 0.08)

                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            ColumnLayout {
                                id: toolCol
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    SvgIcon {
                                        icon: modelData.name === "web_search" ? "search" : (modelData.name === "list_dir" ? "dashboard" : "code")
                                        iconSize: 14
                                        iconColor: modelData.status === "running" ? Theme.accent : Theme.muted
                                        flat: true
                                        Layout.alignment: Qt.AlignVCenter

                                        RotationAnimation on rotation {
                                            loops: Animation.Infinite
                                            from: 0
                                            to: 360
                                            duration: 1200
                                            running: modelData.status === "running"
                                        }
                                    }

                                    ThemedText {
                                        text: {
                                            if (modelData.name === "web_search") return Translation.tr("Web search: \"%1\"").arg(modelData.detail);
                                            if (modelData.name === "read_file") return Translation.tr("Read file: %1").arg(modelData.detail);
                                            if (modelData.name === "list_dir") return Translation.tr("List directory: %1").arg(modelData.detail);
                                            return modelData.name + ": " + modelData.detail;
                                        }
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Theme.fg
                                        Layout.fillWidth: true
                                        elide: Text.ElideMiddle
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: 18
                                        implicitWidth: tStatus.implicitWidth + 12
                                        radius: 9
                                        color: modelData.status === "running" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15) : Qt.rgba(0.2, 0.8, 0.4, 0.15)

                                        ThemedText {
                                            id: tStatus
                                            anchors.centerIn: parent
                                            text: modelData.status === "running" ? Translation.tr("Running...") : Translation.tr("Done")
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: modelData.status === "running" ? Theme.accent : "#4ade80"
                                        }
                                    }
                                }

                                ThemedText {
                                    visible: toolItem.expanded && modelData.preview !== ""
                                    text: modelData.preview || ""
                                    font.pixelSize: 11
                                    color: Theme.muted
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 22
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toolItem.expanded = !toolItem.expanded
                            }
                        }
                    }
                }

                // 4. Response Text
                Text {
                    Layout.fillWidth: true
                    text: IslandAiService.response
                    textFormat: Text.MarkdownText
                    wrapMode: Text.Wrap
                    color: Theme.fg
                    visible: IslandAiService.response !== ""
                    font.pixelSize: 14
                    lineHeight: 1.3
                    onLinkActivated: (link) => Qt.openUrlExternally(link)
                }

                // 5. Error text
                ThemedText {
                    Layout.fillWidth: true
                    text: IslandAiService.error
                    color: "#ff6b6b"
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    visible: IslandAiService.error !== ""
                }
            }
        }
    }

    // ==========================================
    // 4b. NOTES SCRATCHPAD VIEW
    // ==========================================
    Item {
        id: notesContainer
        anchors.fill: parent
        opacity: root.currentMode === "notes" ? 1 : 0
        scale: root.currentMode === "notes" ? 1 : 0.88
        visible: opacity > 0
        focus: root.currentMode === "notes"

        Behavior on opacity { NumberAnimation { duration: 200 } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        Notes.NotesPanel {
            id: notesPanel
            anchors.centerIn: parent
            focus: root.currentMode === "notes"
            onClosed: {
                if (AppState.activePopup === "notes")
                    AppState.activePopup = "";
            }
        }
    }

    // ==========================================
    // 5. WORKSPACE RENAME VIEW
    // ==========================================
    readonly property int activeWsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

    function saveActiveWorkspaceName(newName) {
        var wsId = root.activeWsId;
        var idx = wsId - 1;
        var labels = Array.from(Persistent.states?.workspaceLabels || []);
        while (labels.length < 10) labels.push("");
        if (idx >= 0 && idx < 10) {
            labels[idx] = newName.trim();
            Persistent.states.workspaceLabels = labels;
        }
        AppState.activePopup = "";
    }

    RowLayout {
        id: wsRenameRow
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 10
        opacity: root.currentMode === "workspaceRename" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Rectangle {
            Layout.preferredHeight: 28
            Layout.preferredWidth: wsBadgeLayout.implicitWidth + 16
            Layout.alignment: Qt.AlignVCenter
            radius: 14
            color: Theme.accent

            RowLayout {
                id: wsBadgeLayout
                anchors.centerIn: parent
                spacing: 6

                SvgIcon {
                    icon: "edit"
                    iconColor: Theme.bg
                    iconSize: 14
                    flat: true
                    Layout.alignment: Qt.AlignVCenter
                }

                ThemedText {
                    text: "WS " + root.activeWsId
                    font.pixelSize: Constants.sizeSm
                    font.bold: true
                    color: Theme.bg
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        TextField {
            id: wsRenameInput
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            focus: root.currentMode === "workspaceRename"
            placeholderText: Translation.tr("Workspace name...")
            placeholderTextColor: Theme.muted
            font.family: Constants.fontFamily
            font.pixelSize: 14
            color: Theme.fg
            background: null
            leftPadding: 0
            rightPadding: 0

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    AppState.activePopup = "";
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.saveActiveWorkspaceName(text);
                    event.accepted = true;
                }
            }

            onAccepted: {
                root.saveActiveWorkspaceName(text);
            }
        }

        SvgIconButton {
            visible: wsRenameInput.text !== ""
            icon: "x"
            iconSize: 12
            flat: true
            Layout.alignment: Qt.AlignVCenter
            onClicked: {
                wsRenameInput.text = "";
                wsRenameInput.forceActiveFocus();
            }
        }

        SvgIconButton {
            icon: "check"
            iconSize: 14
            flat: true
            Layout.alignment: Qt.AlignVCenter
            onClicked: {
                root.saveActiveWorkspaceName(wsRenameInput.text);
            }
        }

        Rectangle {
            Layout.preferredHeight: 22
            Layout.preferredWidth: 38
            Layout.alignment: Qt.AlignVCenter
            radius: 11
            color: Qt.rgba(1, 1, 1, 0.08)

            ThemedText {
                anchors.centerIn: parent
                text: "ESC"
                font.pixelSize: Constants.size3Xs
                font.bold: true
                color: Theme.muted
            }

            MouseArea {
                anchors.fill: parent
                onClicked: AppState.activePopup = ""
            }
        }
    }

    // When entering fullscreen while a toast is visible, collapse it so it doesn't cover the fullscreen window
    onIsFullscreenChanged: {
        if (root.isFullscreen && IslandState.mode !== IslandState.modeIdle) {
            IslandState.collapse();
        }
    }
    Connections {
        target: HyprlandData
        function onHasFullscreenChanged() {
            if (root.isFullscreen && root.currentMode === "notif") {
                IslandState.collapse();
            }
        }
    }

    Connections {
        target: AppState
        function onActivePopupChanged() {
            if (AppState.activePopup === "controlCenter") {
                root.dashboardActiveTab = 3;
            }
            if (AppState.activePopup === "") {
                if (IslandAiService.running) {
                    IslandAiService.cancel();
                }
                IslandAiService.clearSession();
            }
        }
    }

    onCurrentModeChanged: {
        if (currentMode === "launcher") {
            searchQuery = "";
            Qt.callLater(() => {
                searchInput.text = "";
                searchInput.forceActiveFocus();
            });
        } else if (currentMode === "ai") {
            Qt.callLater(() => {
                if (aiInput) aiInput.forceActiveFocus();
            });
        } else if (currentMode === "workspaceRename") {
            Qt.callLater(() => {
                let wsId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
                let idx = wsId - 1;
                let curLabel = (Persistent.ready && Persistent.states?.workspaceLabels && idx >= 0 && idx < Persistent.states.workspaceLabels.length) ? (Persistent.states.workspaceLabels[idx] || "") : "";
                wsRenameInput.text = curLabel;
                wsRenameInput.selectAll();
                wsRenameInput.forceActiveFocus();
            });
        }
    }



    Timer {
        id: volumeCloseTimer
        interval: 1500
        repeat: false
        onTriggered: {
            GlobalStates.osdVolumeOpen = false;
        }
    }

    Connections {
        target: GlobalStates
        function onOsdVolumeOpenChanged() {
            if (GlobalStates.osdVolumeOpen) {
                volumeCloseTimer.restart();
            }
        }
    }

    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (root.currentMode !== "dashboard" && root.currentMode !== "launcher" && root.currentMode !== "workspaceRename") {
                GlobalStates.osdVolumeOpen = true;
                volumeCloseTimer.restart();
            }
        }
        function onMutedChanged() {
            if (root.currentMode !== "dashboard" && root.currentMode !== "launcher" && root.currentMode !== "workspaceRename") {
                GlobalStates.osdVolumeOpen = true;
                volumeCloseTimer.restart();
            }
        }
    }

    // ==========================================
    // 5. VOLUME HUD VIEW (When changing volume via wheel or keys)
    // ==========================================
    Item {
        id: volumeContainer
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        opacity: root.currentMode === "volume" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        RowLayout {
            anchors.fill: parent
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: (Audio.sink?.audio?.muted) ? Qt.rgba(1, 0.2, 0.2, 0.15) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                Layout.alignment: Qt.AlignVCenter

                SvgIcon {
                    anchors.centerIn: parent
                    icon: (Audio.sink?.audio?.muted || (Audio.sink?.audio?.volume ?? 0) === 0) ? "volume-off" : "volume"
                    iconSize: 14
                    flat: true
                    iconColor: (Audio.sink?.audio?.muted) ? "#ff6b6b" : Theme.accent
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.12)
                clip: true
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * Math.min(1.0, Math.max(0, Audio.sink?.audio?.volume ?? 0))
                    radius: 3
                    color: (Audio.sink?.audio?.muted) ? Theme.muted : Theme.accent

                    Behavior on width {
                        NumberAnimation { duration: 80 }
                    }
                }
            }

            ThemedText {
                text: (Audio.sink?.audio?.muted) ? Translation.tr("Muted") : Math.round(((Audio.sink?.audio?.volume ?? 0) * 100)) + "%"
                font.pixelSize: 12
                font.bold: true
                color: Theme.fg
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }

    // ==========================================
    // 6. DASHBOARD VIEW (When hovering/clicking the Clock)
    // ==========================================
    property int dashboardActiveTab: 0

    ColumnLayout {
        id: dashboardColumn
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.topMargin: 6
        anchors.bottomMargin: 16
        spacing: 12
        opacity: root.currentMode === "dashboard" ? 1 : 0
        visible: opacity > 0

        transform: Translate {
            y: root.currentMode === "dashboard" ? 0 : -16
            Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        }

        Behavior on opacity { NumberAnimation { duration: (root.dashboardActiveTab === 3 ? 0 : 200); easing.type: Easing.OutCubic } }

        ThemedTabs {
            id: headerRowItem
            Layout.fillWidth: true
            Layout.preferredHeight: root.isSubViewOpen ? 0 : 44
            visible: !root.isSubViewOpen
            activeValue: root.dashboardActiveTab
            onTabSelected: (value) => root.dashboardActiveTab = value

            ThemedTab {
                glyph: "dashboard"
                text: Translation.tr("Dashboard")
                value: 0
            }

            ThemedTab {
                glyph: "performance"
                text: Translation.tr("Performance")
                value: 1
            }

            ThemedTab {
                glyph: "code"
                text: "Codex"
                value: 2
            }

            ThemedTab {
                glyph: "tune"
                text: Translation.tr("Quick Settings")
                value: 3
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MainPanelDashboard.Dashboard {
                anchors.fill: parent
                visible: root.dashboardActiveTab === 0
            }

            MainPanelPerformance.Performance {
                anchors.fill: parent
                visible: root.dashboardActiveTab === 1
            }

            MainPanelDashboard.CodexBarCard {
                anchors.fill: parent
                visible: root.dashboardActiveTab === 2
                active: root.currentMode === "dashboard" && visible
            }

            ControlCenterView {
                id: controlCenterView
                anchors.fill: parent
                visible: root.dashboardActiveTab === 3
            }
        }
    }
}
