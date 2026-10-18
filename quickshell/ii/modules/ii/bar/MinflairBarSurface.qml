import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray as QSSysTray
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.Modules.Bar
import qs.Modules.Bar.Widgets.MainPanel
import qs.Modules.Bar.Widgets.SystemTray
import qs.Modules.Bar.Widgets.Launcher
import qs.Modules.Bar.Widgets.DynamicIsland
import qs.Modules.ControlCenter
import qs.Modules.PackageManager
import qs.Modules.PowerMenu
import qs.Core.Components
import qs.Core.Services

import qs.Services.System

// Minflair-style bar + dashboard, grafted onto the End-4 ii shell.

Scope {
    id: root

    NotificationService {
        id: globalNotificationService
    }

    PopupLoader {
        popupId: "packagemanager"

        sourceComponent: Component {
            PackageManager {
            }
        }
    }

    PopupLoader {
        popupId: "powerMenu"

        sourceComponent: Component {
            PowerMenu {
            }
        }
    }

    Variants {
        model: {
            const screens = Quickshell.screens;
            const list = Config.options.bar.screenList;
            if (!list || list.length === 0)
                return screens;
            return screens.filter(screen => list.includes(screen.name));
        }
        LazyLoader {
            id: surfaceLoader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked
            required property ShellScreen modelData
            component: Item {
                id: surface

                property bool clockHovered: false
                readonly property int barHeight: 48
                readonly property int barMarginTop: 8
                readonly property int barMarginSide: 8
                readonly property int popupStartY: barMarginTop + barHeight + 8

                property HyprlandMonitor monitor: Hyprland.monitorFor(surfaceLoader.modelData)
                property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
                property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
                // Per-monitor gate: hyprctl windowList filtered by monitor + hidden, plus Toplevel fallback for instant poll.
                readonly property bool isFullscreen: HyprlandData.hasFullscreenOnMonitor(monitor?.id ?? -1) || activeWorkspaceWithFullscreen !== undefined

                Connections {
                    target: barStrip
                    function onClockHoveredChanged() {
                        surface.clockHovered = barStrip.clockHovered;
                        if (surface.clockHovered) {
                            if (AppState.activePopup === "launcher") {
                                AppState.activePopup = "dashboard";
                            }
                            mainPanel.isOpen = true;
                        }
                    }
                }

                // The TopPopup auto-closes ~500ms after the cursor leaves it,
                // so keep it open while the cursor stays on the clock.
                Timer {
                    id: clockHoverKeepAlive
                    interval: 250
                    repeat: true
                    running: surface.clockHovered
                    onTriggered: {
                        if (AppState.activePopup !== "launcher") {
                            mainPanel.isOpen = true;
                        }
                    }
                }

                // Bar window
                PanelWindow {
                    id: barSurface
                    screen: surfaceLoader.modelData
                    visible: !surface.isFullscreen

                    WlrLayershell.layer: WlrLayer.Top
                    color: "transparent"
                    focusable: false
                    implicitHeight: surface.barHeight + surface.barMarginTop

                    anchors {
                        top: !Config.options.bar.bottom
                        bottom: Config.options.bar.bottom
                        left: true
                        right: true
                    }

                    Bar {
                        id: barStrip
                        z: 1
                        notificationService: globalNotificationService
                        mainPanelWidget: unifiedIsland
                        x: surface.barMarginSide
                        y: surface.barMarginTop
                        width: barSurface.width - surface.barMarginSide * 2
                        height: surface.barHeight
                    }
                }

                // Popup window (Unified Dynamic Island + tray menus)
                PanelWindow {
                    id: popupSurface
                    visible: !surface.isFullscreen || unifiedIsland.isExpanded

                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.keyboardFocus: (unifiedIsland.currentMode === "launcher" || unifiedIsland.currentMode === "workspaceRename" || unifiedIsland.currentMode === "ai" || unifiedIsland.currentMode === "notes") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                    color: "transparent"
                    focusable: (unifiedIsland.currentMode === "launcher" || unifiedIsland.currentMode === "workspaceRename" || unifiedIsland.currentMode === "ai" || unifiedIsland.currentMode === "notes")
                    screen: surfaceLoader.modelData

                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }

                    UnifiedDynamicIsland {
                        id: unifiedIsland
                        isFullscreen: surface.isFullscreen
                        x: (popupSurface.width - implicitWidth) / 2
                        y: surface.barMarginTop

                        onCurrentModeChanged: {
                            if (currentMode === "launcher" || currentMode === "dashboard" || currentMode === "workspaceRename" || currentMode === "ai" || currentMode === "notes") {
                                GlobalFocusGrab.addDismissable(popupSurface);
                            } else {
                                GlobalFocusGrab.removeDismissable(popupSurface);
                            }
                        }
                    }

                    Connections {
                        target: GlobalFocusGrab
                        function onDismissed() {
                            if (AppState.activePopup === "launcher" || AppState.activePopup === "dashboard" || AppState.activePopup === "workspaceRename" || AppState.activePopup === "ai" || AppState.activePopup === "notes") {
                                AppState.activePopup = "";
                            }
                        }
                    }

                    mask: Region {
                        Region {
                            x: unifiedIsland.x
                            y: unifiedIsland.y
                            width: unifiedIsland.width
                            height: unifiedIsland.height
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }

        function close(): void {
            GlobalStates.barOpen = false
        }

        function open(): void {
            GlobalStates.barOpen = true
        }
    }

    GlobalShortcut {
        name: "barToggle"
        description: "Toggles bar on press"

        onPressed: {
            GlobalStates.barOpen = !GlobalStates.barOpen;
        }
    }

    GlobalShortcut {
        name: "barOpen"
        description: "Opens bar on press"

        onPressed: {
            GlobalStates.barOpen = true;
        }
    }

    GlobalShortcut {
        name: "barClose"
        description: "Closes bar on press"

        onPressed: {
            GlobalStates.barOpen = false;
        }
    }

    IpcHandler {
        target: "search"

        function toggle(): void {
            AppState.togglePopup("launcher");
        }
        function open(): void {
            AppState.openPopup("launcher");
        }
        function close(): void {
            if (AppState.activePopup === "launcher")
                AppState.activePopup = "";
        }
        function workspacesToggle(): void {
            AppState.togglePopup("launcher");
        }
        function toggleReleaseInterrupt(): void {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle(): void {
            AppState.togglePopup("launcher");
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles launcher on press"
        onPressed: AppState.togglePopup("launcher")
    }

    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles launcher on release"
        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }
        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            AppState.togglePopup("launcher");
        }
    }

    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts search toggle on release"
        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }

    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes launcher on press"
        onPressed: {
            if (AppState.activePopup === "launcher")
                AppState.activePopup = "";
        }
    }

    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles launcher on press"
        onPressed: AppState.togglePopup("launcher")
    }

    IpcHandler {
        target: "workspace"

        function rename(): void {
            AppState.openPopup("workspaceRename");
        }
        function renameToggle(): void {
            AppState.togglePopup("workspaceRename");
        }
        function toggle(): void {
            AppState.togglePopup("workspaceRename");
        }
        function close(): void {
            if (AppState.activePopup === "workspaceRename")
                AppState.activePopup = "";
        }
    }

    GlobalShortcut {
        name: "workspaceRenameToggle"
        description: "Toggles workspace rename in Dynamic Island"
        onPressed: AppState.togglePopup("workspaceRename")
    }

    GlobalShortcut {
        name: "workspaceRename"
        description: "Opens workspace rename in Dynamic Island"
        onPressed: AppState.openPopup("workspaceRename")
    }

    IpcHandler {
        target: "controlCenter"

        function toggle(): void {
            AppState.togglePopup("controlCenter");
        }
        function open(): void {
            AppState.openPopup("controlCenter");
        }
        function close(): void {
            if (AppState.activePopup === "controlCenter")
                AppState.activePopup = "";
        }
    }

    GlobalShortcut {
        name: "controlCenterToggle"
        description: "Toggles Control Center"
        onPressed: AppState.togglePopup("controlCenter")
    }

    IpcHandler {
        target: "jarvis"

        function listening(): void {
            JarvisService.setListening();
        }

        function transcribing(): void {
            JarvisService.setTranscribing();
        }

        function thinking(): void {
            JarvisService.setThinking();
        }

        function speaking(): void {
            JarvisService.setSpeaking();
        }

        function dictating(active: bool): void {
            JarvisService.setDictating(active);
        }

        function idle(): void {
            JarvisService.setIdle();
        }
    }

    IpcHandler {
        target: "ai"

        function ask(prompt: string): void {
            JarvisService.setIdle();
            AppState.openPopup("ai");
            IslandAiService.ask(prompt);
        }

        function askWithVoice(prompt: string): void {
            AppState.activePopup = "";
            JarvisService.setThinking();
            IslandAiService.speakVoice = true;
            IslandAiService.ask(prompt);
        }

        function close(): void {
            JarvisService.setIdle();
            IslandAiService.clearSession();
            AppState.activePopup = "";
        }

        function toggle(): void {
            if (AppState.activePopup === "ai") {
                close();
            } else {
                AppState.openPopup("ai");
            }
        }
    }

    IpcHandler {
        target: "notes"

        function toggle(): void {
            AppState.togglePopup("notes");
        }
        function open(): void {
            AppState.openPopup("notes");
        }
        function close(): void {
            if (AppState.activePopup === "notes")
                AppState.activePopup = "";
        }
        function create(): void {
            NotesService.create();
            AppState.openPopup("notes");
        }
    }

    GlobalShortcut {
        name: "notesToggle"
        description: "Toggles Notes Scratchpad in Dynamic Island"
        onPressed: AppState.togglePopup("notes")
    }
}

