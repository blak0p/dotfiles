pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Polled resource usage service with RAM, Swap, CPU, GPU, and VRAM usage.
 */
Singleton {
    id: root

    // RAM
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property string maxAvailableMemoryString: kbToGbString(root.memoryTotal)

    // Swap
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property string maxAvailableSwapString: kbToGbString(root.swapTotal)

    // CPU
    property real cpuUsage: 0
    property string maxAvailableCpuString: "--"
    property var previousCpuStats
    property int cpuCoreCount: 12
    property var previousCoreStats: ({})
    property list<real> coreUsages: []

    // GPU
    property real gpuUsage: 0

    // VRAM
    property real vramTotal: 1
    property real vramUsed: 0
    property real vramUsedPercentage: vramTotal > 0 ? vramUsed / vramTotal : 0
    property string maxAvailableVramString: bytesToGbString(vramTotal)

    // History
    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []
    property list<real> gpuUsageHistory: []
    property list<real> vramUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function bytesToGbString(bytes) {
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }

    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }

    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }

    function updateGpuUsageHistory() {
        gpuUsageHistory = [...gpuUsageHistory, gpuUsage]
        if (gpuUsageHistory.length > historyLength) {
            gpuUsageHistory.shift()
        }
    }

    function updateVramUsageHistory() {
        vramUsageHistory = [...vramUsageHistory, vramUsedPercentage]
        if (vramUsageHistory.length > historyLength) {
            vramUsageHistory.shift()
        }
    }

    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
        updateGpuUsageHistory()
        updateVramUsageHistory()
    }

    Timer {
        interval: 1
        running: true
        repeat: true
        onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()
            fileGpuBusy.reload()
            fileVramUsed.reload()
            fileVramTotal.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse GPU usage
            gpuUsage = Number(fileGpuBusy.text().trim() || "0") / 100

            // Parse VRAM usage
            vramUsed = Number(fileVramUsed.text().trim() || "0")
            vramTotal = Number(fileVramTotal.text().trim() || "1")

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            // Parse per-core CPU usage
            const coreRegex = /^cpu(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/gm
            let coreMatch
            const newCoreUsages = []
            while ((coreMatch = coreRegex.exec(textStat)) !== null) {
                const coreIndex = parseInt(coreMatch[1])
                const stats = coreMatch.slice(2).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                const prev = root.previousCoreStats[coreIndex]
                if (prev) {
                    const totalDiff = total - prev.total
                    const idleDiff = idle - prev.idle
                    newCoreUsages[coreIndex] = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                } else {
                    newCoreUsages[coreIndex] = 0
                }

                root.previousCoreStats[coreIndex] = { total, idle }
            }
            root.coreUsages = newCoreUsages
            root.cpuCoreCount = newCoreUsages.length

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
    }

    FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    FileView { id: fileGpuBusy; path: "/sys/class/drm/card1/device/gpu_busy_percent" }
    FileView { id: fileVramUsed; path: "/sys/class/drm/card1/device/mem_info_vram_used" }
    FileView { id: fileVramTotal; path: "/sys/class/drm/card1/device/mem_info_vram_total" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
}
