import QtQuick
import qs

// Sparkline of 0..100 samples: accent line over a faint fill.
Canvas {
    id: c
    property var values: []
    property color color: Theme.accent
    implicitHeight: 34

    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const n = values.length;
        if (n < 2) return;
        const step = width / (PerfService.historyLen - 1);
        const x0 = width - (n - 1) * step;
        const y = v => height - 2 - Math.max(0, Math.min(100, v)) / 100 * (height - 4);
        ctx.beginPath();
        ctx.moveTo(x0, y(values[0]));
        for (let i = 1; i < n; i++) ctx.lineTo(x0 + i * step, y(values[i]));
        ctx.lineWidth = 2;
        ctx.lineJoin = "round";
        ctx.strokeStyle = c.color;
        ctx.stroke();
        ctx.lineTo(width, height);
        ctx.lineTo(x0, height);
        ctx.closePath();
        ctx.fillStyle = Qt.alpha(c.color, 0.14);
        ctx.fill();
    }
}
