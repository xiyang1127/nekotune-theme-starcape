import QtQuick

// Static, deterministic star field painted once per size or colour change.
// It never animates, so hidden pages and idle windows cost nothing per frame.
Canvas {
    id: root
    property color dotColor: Theme.isDark ? Theme.textPrimary : Theme.accentPrimary
    property color sparkleColor: Theme.isDark ? Theme.accentSecondary : Theme.accentPrimary
    property real density: Theme.isDark ? 1 : 0.35
    property int seed: 20261008
    antialiasing: true
    onDotColorChanged: requestPaint()
    onSparkleColorChanged: requestPaint()
    onDensityChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        if (width < 1 || height < 1) return
        let state = root.seed
        const next = () => {
            state = (state * 1664525 + 1013904223) % 4294967296
            return state / 4294967296
        }
        const count = Math.min(140, Math.round(width * height / 9000 * root.density))
        const dot = root.dotColor
        for (let i = 0; i < count; ++i) {
            const x = next() * width, y = next() * height
            const size = 0.5 + next() * 0.9
            ctx.globalAlpha = 0.08 + next() * 0.26
            ctx.fillStyle = dot
            ctx.beginPath()
            ctx.arc(x, y, size, 0, Math.PI * 2)
            ctx.fill()
        }
        const sparkle = root.sparkleColor
        const sparkles = Math.max(2, Math.round(count / 24))
        ctx.fillStyle = sparkle
        for (let i = 0; i < sparkles; ++i) {
            const x = next() * width, y = next() * height
            const arm = 2.5 + next() * 2.5
            ctx.globalAlpha = 0.2 + next() * 0.2
            ctx.beginPath()
            ctx.moveTo(x - arm, y)
            ctx.quadraticCurveTo(x, y, x, y - arm)
            ctx.quadraticCurveTo(x, y, x + arm, y)
            ctx.quadraticCurveTo(x, y, x, y + arm)
            ctx.quadraticCurveTo(x, y, x - arm, y)
            ctx.fill()
        }
    }
}
