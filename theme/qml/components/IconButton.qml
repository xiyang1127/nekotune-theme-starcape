import QtQuick
import QtQuick.Controls

Button {
    id: button

    property string kind: "dot"
    property string tooltipText: ""
    property color fillColor: "transparent"
    property color hoverColor: Theme.bgHover
    property color pressedColor: Theme.bgSelected
    property color borderColor: "transparent"
    property color glyphColor: Theme.textMuted
    property color hoverGlyphColor: Theme.textPrimary
    property real iconSize: 18
    property real cornerRadius: Theme.radiusSm

    hoverEnabled: true
    implicitWidth: 40
    implicitHeight: 40

    ToolTip.visible: (button.hovered || button.activeFocus) && button.tooltipText.length > 0
    ToolTip.text: button.tooltipText
    ToolTip.delay: 400

    Accessible.role: Accessible.Button
    Accessible.name: button.tooltipText

    contentItem: Canvas {
        id: iconCanvas
        anchors.centerIn: parent
        width: button.iconSize
        height: button.iconSize
        antialiasing: true

        readonly property color currentStrokeColor: !button.enabled ? Theme.textDisabled
                                                    : button.hovered ? button.hoverGlyphColor
                                                    : button.glyphColor

        onCurrentStrokeColorChanged: requestPaint()
        Connections { target: button; function onKindChanged() { iconCanvas.requestPaint() } }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const col = currentStrokeColor
            ctx.strokeStyle = col
            ctx.fillStyle = col
            ctx.lineWidth = 1.8
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            const w = width
            const h = height
            const k = button.kind

            if (k === "history") {
                ctx.beginPath()
                ctx.arc(w * .5, h * .5, w * .35, 0, Math.PI * 2)
                ctx.moveTo(w * .5, h * .28)
                ctx.lineTo(w * .5, h * .5)
                ctx.lineTo(w * .66, h * .6)
                ctx.stroke()
            } else if (k === "audio_output") {
                ctx.beginPath()
                ctx.arc(w * .5, h * .48, w * .32, Math.PI, 0)
                ctx.moveTo(w * .18, h * .48); ctx.lineTo(w * .18, h * .78)
                ctx.lineTo(w * .32, h * .78); ctx.lineTo(w * .32, h * .52)
                ctx.moveTo(w * .82, h * .48); ctx.lineTo(w * .82, h * .78)
                ctx.lineTo(w * .68, h * .78); ctx.lineTo(w * .68, h * .52)
                ctx.stroke()
            } else if (k === "play") {
                // Play triangle (optical center shifted slightly right)
                ctx.beginPath()
                ctx.moveTo(w * 0.36, h * 0.22)
                ctx.lineTo(w * 0.76, h * 0.5)
                ctx.lineTo(w * 0.36, h * 0.78)
                ctx.closePath()
                ctx.fill()
            } else if (k === "pause") {
                const barW = w * 0.2
                const barH = h * 0.56
                const y = (h - barH) / 2
                ctx.fillRect(w * 0.24, y, barW, barH)
                ctx.fillRect(w * 0.56, y, barW, barH)
            } else if (k === "previous" || k === "back") {
                // Standard Media Previous: bar + left triangle |◀
                const barW = 2
                const barH = h * 0.52
                const y = (h - barH) / 2
                ctx.fillRect(w * 0.2, y, barW, barH)

                ctx.beginPath()
                ctx.moveTo(w * 0.78, h * 0.24)
                ctx.lineTo(w * 0.32, h * 0.5)
                ctx.lineTo(w * 0.78, h * 0.76)
                ctx.closePath()
                ctx.fill()
            } else if (k === "next" || k === "chevron") {
                // Standard Media Next: right triangle + bar ▶|
                const barW = 2
                const barH = h * 0.52
                const y = (h - barH) / 2
                ctx.fillRect(w * 0.76, y, barW, barH)

                ctx.beginPath()
                ctx.moveTo(w * 0.22, h * 0.24)
                ctx.lineTo(w * 0.68, h * 0.5)
                ctx.lineTo(w * 0.22, h * 0.76)
                ctx.closePath()
                ctx.fill()
            } else if (k === "return") {
                ctx.beginPath()
                ctx.moveTo(w * .65, h * .2); ctx.lineTo(w * .35, h * .5); ctx.lineTo(w * .65, h * .8)
                ctx.stroke()
            } else if (k === "sequential") {
                for (let i = 0; i < 3; ++i) {
                    const y = h * (.25 + i * .25)
                    ctx.beginPath(); ctx.moveTo(w * .15, y); ctx.lineTo(w * .6, y); ctx.stroke()
                }
                ctx.beginPath(); ctx.moveTo(w * .78, h * .2); ctx.lineTo(w * .78, h * .8)
                ctx.moveTo(w * .65, h * .65); ctx.lineTo(w * .78, h * .8); ctx.lineTo(w * .91, h * .65); ctx.stroke()
            } else if (k === "repeat_one" || k === "repeat_all") {
                ctx.beginPath(); ctx.moveTo(w * .2, h * .55); ctx.lineTo(w * .2, h * .3)
                ctx.lineTo(w * .8, h * .3); ctx.moveTo(w * .65, h * .15)
                ctx.lineTo(w * .8, h * .3); ctx.lineTo(w * .65, h * .45)
                ctx.moveTo(w * .8, h * .45); ctx.lineTo(w * .8, h * .7); ctx.lineTo(w * .2, h * .7)
                ctx.moveTo(w * .35, h * .55); ctx.lineTo(w * .2, h * .7); ctx.lineTo(w * .35, h * .85); ctx.stroke()
                if (k === "repeat_one") {
                    ctx.font = "bold " + Math.round(h * .38) + "px sans-serif"
                    ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillText("1", w * .5, h * .51)
                }
            } else if (k === "shuffle") {
                ctx.beginPath(); ctx.moveTo(w * .12, h * .25); ctx.lineTo(w * .32, h * .25)
                ctx.lineTo(w * .68, h * .75); ctx.lineTo(w * .88, h * .75)
                ctx.moveTo(w * .12, h * .75); ctx.lineTo(w * .32, h * .75)
                ctx.lineTo(w * .68, h * .25); ctx.lineTo(w * .88, h * .25)
                ctx.moveTo(w * .75, h * .12); ctx.lineTo(w * .88, h * .25); ctx.lineTo(w * .75, h * .38)
                ctx.moveTo(w * .75, h * .62); ctx.lineTo(w * .88, h * .75); ctx.lineTo(w * .75, h * .88); ctx.stroke()
            } else if (k === "locate") {
                ctx.beginPath(); ctx.arc(w * .5, h * .5, w * .25, 0, Math.PI * 2)
                ctx.moveTo(w * .5, h * .1); ctx.lineTo(w * .5, h * .35)
                ctx.moveTo(w * .5, h * .65); ctx.lineTo(w * .5, h * .9)
                ctx.moveTo(w * .1, h * .5); ctx.lineTo(w * .35, h * .5)
                ctx.moveTo(w * .65, h * .5); ctx.lineTo(w * .9, h * .5); ctx.stroke()
            } else if (k === "close") {
                ctx.beginPath()
                ctx.moveTo(w * 0.28, h * 0.28)
                ctx.lineTo(w * 0.72, h * 0.72)
                ctx.moveTo(w * 0.72, h * 0.28)
                ctx.lineTo(w * 0.28, h * 0.72)
                ctx.stroke()
            } else if (k === "plus") {
                ctx.beginPath()
                ctx.moveTo(w * 0.5, h * 0.24)
                ctx.lineTo(w * 0.5, h * 0.76)
                ctx.moveTo(w * 0.24, h * 0.5)
                ctx.lineTo(w * 0.76, h * 0.5)
                ctx.stroke()
            } else if (k === "music") {
                ctx.beginPath()
                ctx.moveTo(w * 0.65, h * 0.2)
                ctx.lineTo(w * 0.65, h * 0.66)
                ctx.moveTo(w * 0.65, h * 0.26)
                ctx.lineTo(w * 0.85, h * 0.2)
                ctx.arc(w * 0.44, h * 0.7, w * 0.2, 0, Math.PI * 2)
                ctx.stroke()
            } else if (k === "search") {
                ctx.beginPath()
                ctx.arc(w * 0.42, h * 0.42, w * 0.24, 0, Math.PI * 2)
                ctx.moveTo(w * 0.6, h * 0.6)
                ctx.lineTo(w * 0.82, h * 0.82)
                ctx.stroke()
            } else if (k === "edit") {
                ctx.beginPath()
                ctx.moveTo(w * 0.22, h * 0.78)
                ctx.lineTo(w * 0.34, h * 0.76)
                ctx.lineTo(w * 0.76, h * 0.34)
                ctx.lineTo(w * 0.66, h * 0.24)
                ctx.lineTo(w * 0.24, h * 0.66)
                ctx.closePath()
                ctx.stroke()
            } else if (k === "trash") {
                ctx.beginPath()
                ctx.moveTo(w * 0.24, h * 0.32)
                ctx.lineTo(w * 0.76, h * 0.32)
                ctx.moveTo(w * 0.38, h * 0.32)
                ctx.lineTo(w * 0.38, h * 0.22)
                ctx.lineTo(w * 0.62, h * 0.22)
                ctx.lineTo(w * 0.62, h * 0.32)
                ctx.moveTo(w * 0.3, h * 0.32)
                ctx.lineTo(w * 0.34, h * 0.8)
                ctx.lineTo(w * 0.66, h * 0.8)
                ctx.lineTo(w * 0.7, h * 0.32)
                ctx.stroke()
            } else if (k === "more") {
                ctx.beginPath()
                ctx.arc(w * 0.25, h * 0.5, 1.5, 0, Math.PI * 2)
                ctx.arc(w * 0.5, h * 0.5, 1.5, 0, Math.PI * 2)
                ctx.arc(w * 0.75, h * 0.5, 1.5, 0, Math.PI * 2)
                ctx.fill()
            } else if (k === "move") {
                ctx.beginPath()
                ctx.moveTo(w * 0.22, h * 0.4)
                ctx.lineTo(w * 0.54, h * 0.4)
                ctx.lineTo(w * 0.54, h * 0.24)
                ctx.lineTo(w * 0.82, h * 0.5)
                ctx.lineTo(w * 0.54, h * 0.76)
                ctx.lineTo(w * 0.54, h * 0.6)
                ctx.lineTo(w * 0.22, h * 0.6)
                ctx.closePath()
                ctx.stroke()
            } else if (k === "volume" || k === "mute") {
                ctx.beginPath()
                ctx.moveTo(w * 0.2, h * 0.4)
                ctx.lineTo(w * 0.36, h * 0.4)
                ctx.lineTo(w * 0.55, h * 0.24)
                ctx.lineTo(w * 0.55, h * 0.76)
                ctx.lineTo(w * 0.36, h * 0.6)
                ctx.lineTo(w * 0.2, h * 0.6)
                ctx.closePath()
                ctx.fill()
                ctx.beginPath()
                if (k === "mute") {
                    ctx.moveTo(w * .66, h * .35); ctx.lineTo(w * .9, h * .65)
                    ctx.moveTo(w * .9, h * .35); ctx.lineTo(w * .66, h * .65)
                } else ctx.arc(w * 0.52, h * 0.5, w * 0.22, -Math.PI * 0.3, Math.PI * 0.3)
                ctx.stroke()
            } else if (k === "lyrics") {
                ctx.beginPath()
                ctx.moveTo(w * 0.22, h * 0.32)
                ctx.lineTo(w * 0.78, h * 0.32)
                ctx.moveTo(w * 0.22, h * 0.5)
                ctx.lineTo(w * 0.62, h * 0.5)
                ctx.moveTo(w * 0.22, h * 0.68)
                ctx.lineTo(w * 0.74, h * 0.68)
                ctx.stroke()
            } else if (k === "queue") {
                ctx.beginPath()
                ctx.moveTo(w * 0.22, h * 0.32)
                ctx.lineTo(w * 0.78, h * 0.32)
                ctx.moveTo(w * 0.22, h * 0.5)
                ctx.lineTo(w * 0.78, h * 0.5)
                ctx.moveTo(w * 0.22, h * 0.68)
                ctx.lineTo(w * 0.78, h * 0.68)
                ctx.stroke()
            } else if (k === "home") {
                // Roof + body, closed at the base.
                ctx.beginPath()
                ctx.moveTo(w * 0.18, h * 0.48)
                ctx.lineTo(w * 0.5, h * 0.2)
                ctx.lineTo(w * 0.82, h * 0.48)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(w * 0.3, h * 0.44)
                ctx.lineTo(w * 0.3, h * 0.8)
                ctx.lineTo(w * 0.7, h * 0.8)
                ctx.lineTo(w * 0.7, h * 0.44)
                ctx.stroke()
            } else if (k === "settings") {
                // Simple cog: outer ring, inner hub and eight radial teeth.
                ctx.beginPath()
                ctx.arc(w * 0.5, h * 0.5, w * 0.24, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(w * 0.5, h * 0.5, w * 0.09, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                for (let i = 0; i < 8; ++i) {
                    const a = i * Math.PI / 4
                    ctx.moveTo(w * (0.5 + Math.cos(a) * 0.3), h * (0.5 + Math.sin(a) * 0.3))
                    ctx.lineTo(w * (0.5 + Math.cos(a) * 0.4), h * (0.5 + Math.sin(a) * 0.4))
                }
                ctx.stroke()
            } else if (k === "disc") {
                // Album disc: outer rim + centre hole.
                ctx.beginPath()
                ctx.arc(w * 0.5, h * 0.5, w * 0.34, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.arc(w * 0.5, h * 0.5, w * 0.1, 0, Math.PI * 2)
                ctx.stroke()
            } else if (k === "globe") {
                // Music-source mark: circle with a meridian and equator.
                ctx.beginPath()
                ctx.arc(w * 0.5, h * 0.5, w * 0.32, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.ellipse(w * 0.5, h * 0.5, w * 0.14, w * 0.32, 0, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(w * 0.18, h * 0.5)
                ctx.lineTo(w * 0.82, h * 0.5)
                ctx.stroke()
            } else if (k === "extensions") {
                // Four tiles in a 2x2 grid.
                const s = w * 0.24
                ctx.beginPath()
                ctx.rect(w * 0.2, h * 0.2, s, s)
                ctx.rect(w * 0.56, h * 0.2, s, s)
                ctx.rect(w * 0.2, h * 0.56, s, s)
                ctx.rect(w * 0.56, h * 0.56, s, s)
                ctx.stroke()
            } else if (k === "grid") {
                // 2x2 tile grid (library grid view toggle).
                const s = w * 0.24
                ctx.beginPath()
                ctx.rect(w * 0.2, h * 0.2, s, s)
                ctx.rect(w * 0.56, h * 0.2, s, s)
                ctx.rect(w * 0.2, h * 0.56, s, s)
                ctx.rect(w * 0.56, h * 0.56, s, s)
                ctx.stroke()
            } else if (k === "list") {
                // Three stacked rows with leading bullets (library list view toggle).
                ctx.beginPath()
                for (let i = 0; i < 3; ++i) {
                    const y = h * (0.28 + i * 0.22)
                    ctx.moveTo(w * 0.24, y); ctx.lineTo(w * 0.82, y)
                }
                ctx.stroke()
                ctx.beginPath()
                for (let i = 0; i < 3; ++i) {
                    const y = h * (0.28 + i * 0.22)
                    ctx.moveTo(w * 0.14, y - 0.5); ctx.lineTo(w * 0.16, y - 0.5)
                }
                ctx.stroke()
            } else if (k === "star") {
                // Four-point sparkle used as the brand mark (Section 7.1).
                ctx.beginPath()
                ctx.moveTo(w * 0.5, h * 0.08)
                ctx.quadraticCurveTo(w * 0.57, h * 0.43, w * 0.92, h * 0.5)
                ctx.quadraticCurveTo(w * 0.57, h * 0.57, w * 0.5, h * 0.92)
                ctx.quadraticCurveTo(w * 0.43, h * 0.57, w * 0.08, h * 0.5)
                ctx.quadraticCurveTo(w * 0.43, h * 0.43, w * 0.5, h * 0.08)
                ctx.closePath()
                ctx.fill()
            } else {
                ctx.beginPath()
                ctx.arc(w / 2, h / 2, 2, 0, Math.PI * 2)
                ctx.fill()
            }
        }

        Connections {
            target: button
            function onKindChanged() { iconCanvas.requestPaint() }
            function onEnabledChanged() { iconCanvas.requestPaint() }
        }
    }

    background: Rectangle {
        id: bgRect
        radius: button.cornerRadius
        color: !button.enabled ? "transparent"
               : button.down ? button.pressedColor
               : button.hovered ? button.hoverColor
               : button.fillColor
        border.color: button.enabled ? button.borderColor : "transparent"
        border.width: 1

        // Keyboard focus ring (Section 7.1 & 11)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: bgRect.radius + 4
            color: "transparent"
            border.color: Theme.accentPrimary
            border.width: 2
            visible: button.activeFocus
        }

        Behavior on color {
            ColorAnimation { duration: Theme.reducedMotion ? 0 : Theme.durationFast }
        }
    }
}
