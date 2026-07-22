pragma Singleton
pragma ComponentBehavior: Bound

import qs
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string containerName: "bunker"
    readonly property int updateInterval: 60000

    property bool popupOpen: false

    // Weekly (secondary tier)
    property real weeklyRemainingPercent: -1
    property string weeklyResetDescription: ""
    property string weeklyTimeRemaining: ""
    property int weeklyWindowMinutes: 0

    // Primary (session) - usually null for Codex
    property bool hasPrimary: false
    property real primaryRemainingPercent: -1
    property string primaryTimeRemaining: ""

    // Tertiary - usually null
    property bool hasTertiary: false
    property real tertiaryRemainingPercent: -1
    property string tertiaryResetDescription: ""

    // Codex Reset Credits
    property int resetCreditsAvailable: 0
    property string resetCreditsList: ""

    // Code Review Credits
    property int creditsRemaining: 0

    // Identity
    property string accountEmail: ""
    property string loginMethod: ""
    property string plan: ""

    // Model
    property string model: ""
    property string version: ""

    // Data confidence
    property string dataConfidence: ""
    property string updatedAt: ""

    // Provider status from --status parsing
    property string statusText: ""

    property bool hasError: false
    property bool loading: false
    property bool containerRunning: false

    property string _lastError: ""

    // Status
    property string statusIndicator: ""
    property string statusDescription: ""
    property string statusURL: ""

    property real displayPercent: weeklyRemainingPercent >= 0 ? weeklyRemainingPercent : primaryRemainingPercent
    property string displayTime: root.weeklyTimeRemaining.length > 0 ? root.weeklyTimeRemaining : root.primaryTimeRemaining

    property string lastUpdatedText: {
        if (root.updatedAt.length === 0) return ""
        return root.formatTimeAgo(root.updatedAt)
    }

    property string compactText: {
        if (loading) return "codex\u2026"
        if (hasError) return "codex \u2715"
        if (displayPercent < 0) return "codex \u2014"
        return Math.round(displayPercent) + "% \u2022 " + displayTime
    }

    Timer {
        id: updateTimer
        interval: root.updateInterval
        running: root.popupOpen
        repeat: true
        onTriggered: root.fetch()
    }

    Timer {
        id: containerCheckTimer
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.checkContainer()
    }

    function checkContainer() {
        containerCheckProcess.running = true
    }

    function fetch() {
        if (root.loading) return
        root.loading = true
        fetchProcess.running = true
    }

    function refresh() {
        root.fetch()
    }

    Process {
        id: fetchProcess
        command: [
            "distrobox", "enter", root.containerName, "--",
            "codexbar", "usage", "--provider", "codex", "--format", "json", "--status"
        ]
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.loading = false
                var text = outputCollector.text.trim()
                if (text.length === 0) {
                    root.hasError = true
                    root._lastError = "empty response"
                    return
                }
                try {
                    var data = JSON.parse(text)
                    if (Array.isArray(data) && data.length > 0) {
                        root.parseEntry(data[0])
                    } else if (!Array.isArray(data)) {
                        root.parseEntry(data)
                    } else {
                        root.hasError = true
                        root._lastError = "empty data"
                    }
                    root.hasError = false
                    root._lastError = ""
                } catch (e) {
                    root.hasError = true
                    root._lastError = "parse error: " + e.message
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !root.loading) {
                root.hasError = true
                root._lastError = "exit code " + exitCode
            }
            root.loading = false
        }
    }

    Process {
        id: containerCheckProcess
        command: [
            "distrobox", "list", "--no-color"
        ]
        stdout: StdioCollector {
            id: containerCheckOutput
            onStreamFinished: {
                var text = containerCheckOutput.text.trim()
                var wasRunning = root.containerRunning
                root.containerRunning = text.indexOf(root.containerName) >= 0
                if (root.containerRunning && !wasRunning) {
                    root.hasError = false
                    root.fetch()
                } else if (!root.containerRunning && wasRunning) {
                    GlobalStates.codexbarOpen = false
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.containerRunning = false
            }
        }
    }

    Component.onCompleted: {
        root.checkContainer()
    }

    function parseEntry(entry) {
        var u = entry.usage || {}
        root.version = entry.version || ""
        root.updatedAt = u.updatedAt || ""

        // Status
        var st = entry.status || {}
        root.statusIndicator = st.indicator || ""
        root.statusDescription = st.description || ""
        root.statusURL = st.url || ""

        // Primary (session level)
        if (u.primary) {
            root.hasPrimary = true
            root.primaryRemainingPercent = 100 - (u.primary.usedPercent ?? 0)
            root.primaryTimeRemaining = root.formatTimeRemaining(u.primary.resetsAt)
        } else {
            root.hasPrimary = false
            root.primaryRemainingPercent = -1
            root.primaryTimeRemaining = ""
        }

        // Secondary (usually weekly)
        if (u.secondary) {
            root.weeklyRemainingPercent = 100 - (u.secondary.usedPercent ?? 0)
            root.weeklyWindowMinutes = u.secondary.windowMinutes ?? 0
            root.weeklyResetDescription = u.secondary.resetDescription ?? ""
            root.weeklyTimeRemaining = root.formatTimeRemaining(u.secondary.resetsAt)
        } else {
            root.weeklyRemainingPercent = -1
            root.weeklyTimeRemaining = ""
        }

        // Tertiary
        if (u.tertiary) {
            root.hasTertiary = true
            root.tertiaryRemainingPercent = 100 - (u.tertiary.usedPercent ?? 0)
            root.tertiaryResetDescription = u.tertiary.resetDescription ?? ""
        } else {
            root.hasTertiary = false
            root.tertiaryRemainingPercent = -1
            root.tertiaryResetDescription = ""
        }

        // Codex Reset Credits
        var crc = u.codexResetCredits || {}
        root.resetCreditsAvailable = crc.availableCount ?? 0
        if (crc.credits && Array.isArray(crc.credits) && crc.credits.length > 0) {
            root.resetCreditsList = crc.credits.map(function(c) {
                return (c.name || "Credit") + ": " + (c.uses_remaining ?? c.remaining ?? "?")
            }).join("\n")
        } else {
            root.resetCreditsList = ""
        }

        // Code Review Credits
        root.creditsRemaining = entry.credits?.remaining ?? 0

        // Identity
        root.accountEmail = u.accountEmail || u.identity?.accountEmail || ""
        root.loginMethod = u.loginMethod || u.identity?.loginMethod || ""
        root.plan = u.identity?.plan || u.loginMethod || ""

        // Metadata
        root.dataConfidence = u.dataConfidence || ""
        root.updatedAt = u.updatedAt || ""
    }

    function formatTimeAgo(isoDate) {
        if (!isoDate || isoDate.length === 0) return ""
        try {
            var now = new Date()
            var then = new Date(isoDate)
            var diffMs = now.getTime() - then.getTime()
            if (diffMs < 0) return "just now"
            var secs = Math.floor(diffMs / 1000)
            if (secs < 10) return "just now"
            if (secs < 60) return secs + "s ago"
            var mins = Math.floor(secs / 60)
            if (mins < 60) return mins + "m ago"
            var hours = Math.floor(mins / 60)
            if (hours < 24) return hours + "h ago"
            var days = Math.floor(hours / 24)
            return days + "d ago"
        } catch (e) {
            return ""
        }
    }

    function formatTimeRemaining(isoDate) {
        if (!isoDate || isoDate.length === 0) return ""
        try {
            var now = new Date()
            var reset = new Date(isoDate)
            var diff = reset.getTime() - now.getTime()
            if (diff <= 0) return "resetting\u2026"
            var totalMinutes = Math.floor(diff / 60000)
            var hours = Math.floor(totalMinutes / 60)
            var minutes = totalMinutes % 60
            if (hours >= 24) {
                var days = Math.floor(hours / 24)
                hours = hours % 24
                return days + "d " + hours + "h"
            }
            return hours + "h " + minutes + "m"
        } catch (e) {
            return ""
        }
    }
}
