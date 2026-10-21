pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import NekoTune 1.0
import "components"
import "qrc:/qml/components" as Builtin

Item {
    id: root
    objectName: "starcapeWallpaper"
    clip: true
    ExtensionApi { id: api }
    readonly property var wallpaper: api.wallpaper
    readonly property var preferences: wallpaper.preferences
    readonly property bool compact: width < 640 || height < 500
    readonly property bool portrait: width < 1000 && height >= 500 && height > width * 1.15
    readonly property real margin: compact ? 20 : 56
    readonly property real intensity: Math.max(0, Math.min(1, preferences.intensity ?? 0.35))
    readonly property bool motionAllowed: visible && wallpaper.playing && wallpaper.updating
        && !api.theme.reducedMotion && intensity > 0
    readonly property real coverSize: Math.max(0, Math.min(compact ? 144 : 224,
        width * (portrait ? 0.42 : 0.24), height * (portrait ? 0.23 : 0.38)))
    property real glow: 0
    function t(key) { return api.window.translator.text(key, api.window.translator.language) }
    function timeLabel(milliseconds) {
        const seconds = Math.floor(Math.max(0, milliseconds) / 1000)
        return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0")
    }

    // StarDust and the constellation repaint only on size or palette changes.
    // Animate their surrounding glow instead of repainting a Canvas every frame.
    StarDust {
        anchors.fill: parent
        density: Theme.isDark ? 1.8 : 0.8
        dotColor: Theme.textPrimary
        sparkleColor: Theme.accentSecondary
    }
    Rectangle {
        anchors.centerIn: constellation
        width: constellation.width * 1.4; height: width
        radius: width / 2
        opacity: 0.15 + root.glow * root.intensity * 0.15
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.accentGlow }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    StarfieldState {
        id: constellation
        objectName: "starcapeWallpaperConstellation"
        anchors.right: parent.right; anchors.rightMargin: -width * 0.1
        anchors.top: parent.top; anchors.topMargin: -height * 0.15
        width: Math.min(root.width * 0.44, 440); height: width
        opacity: (Theme.isDark ? 0.32 : 0.18) + root.glow * root.intensity * 0.12
        scale: 1 + root.glow * root.intensity * 0.035
    }
    SequentialAnimation on glow {
        objectName: "starcapeWallpaperGlow"
        running: root.motionAllowed
        loops: Animation.Infinite
        NumberAnimation { from: 0; to: 1; duration: 5000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1; to: 0; duration: 5000; easing.type: Easing.InOutSine }
    }

    Rectangle {
        anchors.centerIn: content
        width: Math.min(root.width - 16, content.width + (root.compact ? 24 : 64))
        height: content.height + (root.compact ? 24 : 64)
        radius: Theme.radiusLg
        color: Qt.rgba(Theme.bgSurface.r, Theme.bgSurface.g, Theme.bgSurface.b, 0.88)
        border.color: Theme.borderSubtle
    }

    ColumnLayout {
        id: content
        objectName: "starcapeWallpaperContent"
        anchors.centerIn: parent
        width: Math.max(0, Math.min(1000, parent.width - root.margin * 2))
        spacing: root.compact ? 18 : 36

        GridLayout {
            Layout.fillWidth: true
            columns: root.portrait ? 1 : 2
            columnSpacing: root.compact ? 20 : 44
            rowSpacing: 20
            Item {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                Layout.preferredWidth: root.coverSize
                Layout.preferredHeight: root.coverSize
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusLg
                    color: Theme.bgSurface
                    clip: true
                    Image {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("../assets/artwork-default.png")
                        sourceSize: Qt.size(Math.ceil(root.coverSize * root.wallpaper.screen.devicePixelRatio),
                                            Math.ceil(root.coverSize * root.wallpaper.screen.devicePixelRatio))
                        fillMode: Image.PreserveAspectCrop
                    }
                    Image {
                        anchors.fill: parent
                        source: root.wallpaper.hasSong ? Theme.artwork(root.wallpaper.song.cover_url || "") : ""
                        sourceSize: Qt.size(Math.ceil(root.coverSize * root.wallpaper.screen.devicePixelRatio),
                                            Math.ceil(root.coverSize * root.wallpaper.screen.devicePixelRatio))
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.color: Theme.borderControl
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.compact ? 6 : 14
                Text {
                    Layout.fillWidth: true
                    visible: root.height >= 360
                    text: "S T A R C A P E   /   N E K O T U N E"
                    color: Theme.accentSecondary
                    font.family: Theme.fontFamily; font.pixelSize: 11
                    textFormat: Text.PlainText; elide: Text.ElideRight
                }
                Text {
                    objectName: "starcapeWallpaperTitle"
                    Layout.fillWidth: true
                    text: root.wallpaper.hasSong
                        ? root.wallpaper.song.title || root.wallpaper.song.file_name || root.t("untitled")
                        : root.t("no_track_selected")
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: root.compact ? 22 : 36; font.weight: Font.DemiBold
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap; maximumLineCount: root.height < 360 ? 1 : 2; elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: [root.wallpaper.song.artist || "", root.wallpaper.song.album || ""].filter(Boolean).join(" · ")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily; font.pixelSize: root.compact ? 12 : 17
                    textFormat: Text.PlainText; elide: Text.ElideRight
                    visible: text.length > 0
                }
                Text {
                    Layout.fillWidth: true
                    text: root.wallpaper.connected ? root.t("wallpaper_state_" + api.app.playback.state)
                                                   : root.t("tray_disconnected")
                    color: Theme.textMuted
                    font.family: Theme.fontFamily; font.pixelSize: 12
                    textFormat: Text.PlainText; elide: Text.ElideRight
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    color: Theme.borderSubtle; radius: 1.5
                    Rectangle {
                        height: parent.height; radius: parent.radius
                        width: parent.width * Math.max(0, Math.min(1, root.wallpaper.duration > 0
                            ? root.wallpaper.position / root.wallpaper.duration : 0))
                        color: Theme.accentPrimary
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.timeLabel(root.wallpaper.position) + " / " + root.timeLabel(root.wallpaper.duration)
                    color: Theme.textMuted
                    font.family: Theme.fontFamilyMonospace; font.pixelSize: 12
                    textFormat: Text.PlainText; elide: Text.ElideRight
                }
            }
        }

        Builtin.CompactLyrics {
            id: lyricView
            objectName: "starcapeWallpaperLyrics"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(root.height * 0.23,
                root.preferences.nextLine ? (root.compact ? 84 : 120) : (root.compact ? 48 : 74))
            visible: Boolean(root.preferences.lyrics)
            song: root.wallpaper.song; lyrics: root.wallpaper.lyrics
            translator: api.window.translator
            position: root.wallpaper.position; playbackRate: root.wallpaper.playbackRate
            connected: root.wallpaper.connected; playing: root.wallpaper.playing
            running: root.wallpaper.updating && lyricView.visible && root.visible
            showNext: Boolean(root.preferences.nextLine)
            updateInterval: root.preferences.updateHz === 60 ? 16 : 33
            reducedMotion: api.theme.reducedMotion
            animateLineChanges: root.intensity > 0
            pixelSize: root.compact ? 22 : 32
            previewPixelSize: root.compact ? 15 : 21
            clip: true
        }
    }
}
