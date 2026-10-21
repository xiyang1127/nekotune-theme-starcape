import QtQuick

// Decorative empty-state illustration (ui-design-guidelines-v2 Section 7.1).
// A small constellation over a faint nebula glow — pure starfield branding,
// with no cat or character elements. Purely presentational: it carries no
// interaction and no product copy. Stars are static; nothing here animates.
Item {
    id: root

    property color inkColor: Theme.accentPrimary
    property color starColor: Theme.accentSecondary
    property real lineWidth: 1.6
    property bool halo: true

    implicitWidth: 132
    implicitHeight: 132
    opacity: 0.9

    // Soft nebula halo behind the constellation.
    Rectangle {
        visible: root.halo
        anchors.centerIn: parent
        width: parent.width * 0.92
        height: width
        radius: width / 2
        opacity: 0.85
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.16) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Canvas {
        id: constellation
        anchors.fill: parent
        antialiasing: true
        Connections {
            target: root
            function onInkColorChanged() { constellation.requestPaint() }
            function onStarColorChanged() { constellation.requestPaint() }
            function onLineWidthChanged() { constellation.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height

            // Constellation nodes in normalised coordinates.
            const pts = [
                [0.30, 0.34], [0.46, 0.26], [0.62, 0.34],
                [0.40, 0.52], [0.58, 0.58], [0.70, 0.74],
                [0.44, 0.74], [0.26, 0.60]
            ]
            const edges = [
                [0, 1], [1, 2], [0, 3], [1, 3], [1, 4], [2, 4],
                [3, 4], [3, 6], [4, 5], [5, 6], [3, 7], [7, 0]
            ]

            // Connection lines first, so the stars sit on top.
            ctx.strokeStyle = Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.45)
            ctx.lineWidth = root.lineWidth
            ctx.lineCap = "round"
            ctx.beginPath()
            for (const e of edges) {
                ctx.moveTo(pts[e[0]][0] * w, pts[e[0]][1] * h)
                ctx.lineTo(pts[e[1]][0] * w, pts[e[1]][1] * h)
            }
            ctx.stroke()

            // Star nodes: a gold sparkle on the brighter points, plain dots elsewhere.
            for (let i = 0; i < pts.length; ++i) {
                const cx = pts[i][0] * w
                const cy = pts[i][1] * h
                const big = i === 1 || i === 4 || i === 6
                if (big) {
                    const r = w * 0.075
                    ctx.fillStyle = root.starColor
                    ctx.beginPath()
                    ctx.moveTo(cx, cy - r)
                    ctx.quadraticCurveTo(cx + r * 0.22, cy - r * 0.22, cx + r, cy)
                    ctx.quadraticCurveTo(cx + r * 0.22, cy + r * 0.22, cx, cy + r)
                    ctx.quadraticCurveTo(cx - r * 0.22, cy + r * 0.22, cx - r, cy)
                    ctx.quadraticCurveTo(cx - r * 0.22, cy - r * 0.22, cx, cy - r)
                    ctx.closePath()
                    ctx.fill()
                } else {
                    ctx.fillStyle = Qt.rgba(root.inkColor.r, root.inkColor.g, root.inkColor.b, 0.85)
                    ctx.beginPath()
                    ctx.arc(cx, cy, w * 0.022, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }
    }
}
