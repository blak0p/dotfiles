import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

StyledPopup {
    id: root

    Component.onCompleted: CodexBar.popupOpen = true
    Component.onDestruction: CodexBar.popupOpen = false

    Column {
        id: contentCol
        anchors.centerIn: parent
        width: 280
        spacing: 8

        // Header
        Column {
            spacing: 2
            StyledText {
                text: "Codex " + (CodexBar.version.length > 0 ? CodexBar.version : "")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
            }
            Row {
                spacing: 4
                visible: CodexBar.accountEmail.length > 0
                StyledText {
                    text: CodexBar.accountEmail
                    font.pixelSize: Appearance.font.pixelSize.xsmall
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.7
                }
            }
            Row {
                spacing: 4
                visible: CodexBar.lastUpdatedText.length > 0
                MaterialSymbol {
                    text: "schedule"
                    iconSize: Appearance.font.pixelSize.xsmall
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.5
                }
                StyledText {
                    text: "Updated " + CodexBar.lastUpdatedText
                    font.pixelSize: Appearance.font.pixelSize.xsmall
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.5
                }
            }
            Loader {
                active: CodexBar.plan.length > 0
                sourceComponent: Row {
                    spacing: 4
                    MaterialSymbol {
                        text: "workspace_premium"
                        iconSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        text: CodexBar.plan
                        font.pixelSize: Appearance.font.pixelSize.xsmall
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Appearance.colors.colOutlineVariant
        }

        // Weekly usage with progress bar
        Column {
            spacing: 4
            StyledPopupHeaderRow {
                icon: "calendar_month"
                label: "Weekly Usage"
            }
            StyledProgressBar {
                valueBarWidth: contentCol.width
                valueBarHeight: 6
                value: CodexBar.weeklyRemainingPercent >= 0 ? (100 - CodexBar.weeklyRemainingPercent) / 100 : 0
                highlightColor: {
                    var pct = CodexBar.weeklyRemainingPercent
                    if (pct < 0) return Appearance.colors.colPrimary
                    if (pct > 50) return Appearance.colors.colPrimary
                    if (pct >= 20) return "#eab308"
                    return "#ef4444"
                }
                trackColor: Appearance.m3colors.m3secondaryContainer
            }
            StyledPopupValueRow {
                icon: "percent"
                label: "Remaining:"
                value: CodexBar.weeklyRemainingPercent >= 0 ? Math.round(CodexBar.weeklyRemainingPercent) + "%" : "\u2014"
            }
            StyledPopupValueRow {
                icon: "schedule"
                label: "Resets:"
                value: CodexBar.weeklyResetDescription.length > 0 ? CodexBar.weeklyResetDescription : "\u2014"
            }
            StyledPopupValueRow {
                icon: "hourglass_bottom"
                label: "Time left:"
                value: CodexBar.weeklyTimeRemaining.length > 0 ? CodexBar.weeklyTimeRemaining : "\u2014"
            }
        }

        // Primary (session)
        Loader {
            active: CodexBar.hasPrimary
            sourceComponent: Column {
                spacing: 4
                width: contentCol.width
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                }
                StyledPopupHeaderRow {
                    icon: "timer"
                    label: "Session"
                }
                StyledProgressBar {
                    valueBarWidth: contentCol.width
                    valueBarHeight: 6
                    value: (100 - CodexBar.primaryRemainingPercent) / 100
                    highlightColor: {
                        var pct = CodexBar.primaryRemainingPercent
                        if (pct > 50) return Appearance.colors.colPrimary
                        if (pct >= 20) return "#eab308"
                        return "#ef4444"
                    }
                    trackColor: Appearance.m3colors.m3secondaryContainer
                }
                StyledPopupValueRow {
                    icon: "percent"
                    label: "Remaining:"
                    value: Math.round(CodexBar.primaryRemainingPercent) + "%"
                }
                StyledPopupValueRow {
                    icon: "schedule"
                    label: "Time left:"
                    value: CodexBar.primaryTimeRemaining
                }
            }
        }

        // Tertiary
        Loader {
            active: CodexBar.hasTertiary
            sourceComponent: Column {
                spacing: 4
                width: contentCol.width
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                }
                StyledPopupHeaderRow {
                    icon: "layers"
                    label: "Additional"
                }
                StyledPopupValueRow {
                    icon: "percent"
                    label: "Remaining:"
                    value: Math.round(CodexBar.tertiaryRemainingPercent) + "%"
                }
                StyledPopupValueRow {
                    icon: "schedule"
                    label: "Resets:"
                    value: CodexBar.tertiaryResetDescription
                }
            }
        }

        // Code Review Credits
        Loader {
            active: CodexBar.creditsRemaining > 0
            sourceComponent: Column {
                spacing: 4
                width: contentCol.width
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                }
                StyledPopupHeaderRow {
                    icon: "rate_review"
                    label: "Code Review Credits"
                }
                StyledPopupValueRow {
                    icon: "counter_1"
                    label: "Remaining:"
                    value: CodexBar.creditsRemaining.toString()
                }
            }
        }

        // Manual Reset Credits
        Loader {
            active: CodexBar.resetCreditsAvailable > 0
            sourceComponent: Column {
                spacing: 4
                width: contentCol.width
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                }
                StyledPopupHeaderRow {
                    icon: "restart_alt"
                    label: "Limit Reset Credits"
                }
                StyledPopupValueRow {
                    icon: "counter_1"
                    label: "Available:"
                    value: CodexBar.resetCreditsAvailable.toString()
                }
            }
        }

        // OpenAI Status
        Loader {
            active: CodexBar.statusIndicator.length > 0 && CodexBar.statusIndicator !== "none"
            sourceComponent: Column {
                spacing: 4
                width: contentCol.width
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                }
                StyledPopupHeaderRow {
                    icon: "monitor_heart"
                    label: "OpenAI Status"
                }
                Row {
                    spacing: 4
                    MaterialSymbol {
                        text: {
                            var i = CodexBar.statusIndicator
                            if (i === "major" || i === "critical") return "error_outline"
                            if (i === "minor") return "warning_amber"
                            return "check_circle"
                        }
                        iconSize: Appearance.font.pixelSize.small
                        color: {
                            var i = CodexBar.statusIndicator
                            if (i === "major" || i === "critical") return "#ef4444"
                            if (i === "minor") return "#eab308"
                            return "#22c55e"
                        }
                    }
                    StyledText {
                        text: CodexBar.statusDescription
                        font.pixelSize: Appearance.font.pixelSize.xsmall
                        color: Appearance.colors.colOnSurfaceVariant
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // Data confidence
        Loader {
            active: CodexBar.dataConfidence.length > 0 && CodexBar.dataConfidence !== "exact"
            sourceComponent: Column {
                spacing: 4
                width: contentCol.width
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                }
                Row {
                    spacing: 4
                    MaterialSymbol {
                        text: "info"
                        iconSize: Appearance.font.pixelSize.small
                        color: "#fbbf24"
                    }
                    StyledText {
                        text: "Data confidence: " + CodexBar.dataConfidence
                        color: "#fbbf24"
                        font.pixelSize: Appearance.font.pixelSize.xsmall
                    }
                }
            }
        }

        // Error state
        Loader {
            active: CodexBar.hasError
            sourceComponent: Column {
                spacing: 4
                width: contentCol.width
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                }
                Row {
                    spacing: 4
                    MaterialSymbol {
                        text: "error_outline"
                        color: "#ef4444"
                        iconSize: Appearance.font.pixelSize.large
                    }
                    StyledText {
                        text: "Could not fetch data"
                        color: "#ef4444"
                        font.pixelSize: Appearance.font.pixelSize.small
                    }
                }
            }
        }

        // Buttons row
        Row {
            spacing: 8
            width: parent.width

            RippleButton {
                id: refreshButton
                implicitWidth: (parent.width - parent.spacing) / 2
                implicitHeight: refreshLabel.implicitHeight + 8
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover

                StyledText {
                    id: refreshLabel
                    anchors.centerIn: parent
                    text: "Refresh"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.m3colors.m3onSecondaryContainer
                }

                onClicked: CodexBar.refresh()
            }

            RippleButton {
                id: dashboardButton
                implicitWidth: (parent.width - parent.spacing) / 2
                implicitHeight: dashboardLabel.implicitHeight + 8
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover

                StyledText {
                    id: dashboardLabel
                    anchors.centerIn: parent
                    text: "Dashboard"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.m3colors.m3onSecondaryContainer
                }

                onClicked: Quickshell.execDetached(["xdg-open", "https://chatgpt.com/codex"])
            }
        }
    }
}
