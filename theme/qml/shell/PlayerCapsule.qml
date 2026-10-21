import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

// v2.0 player capsule: a centred, limited-width floating card that sits above
// the browsing canvas rather than spanning the whole window as a full-width bar.
// It consumes the same confirmed playback state as the now-playing page.
// Opening artwork or metadata navigates without issuing a play command.
// Queue visibility stays independent of collection navigation.
Item {
    id: capsule
    required property var shell
    required property var controller
    required property var translator
    signal editRequested(var song)
    property bool addPending: false
    property string addError: ""
    readonly property bool compact: shell.width < 1200
    readonly property string coverUrl: String(shell.song.cover_url || "")
    readonly property color trackColor: Qt.rgba(Theme.textMuted.r, Theme.textMuted.g, Theme.textMuted.b, 0.28)
    readonly property int playControlSize: Math.min(Theme.playButtonSize, Math.max(32, height - 32))
    // Side clusters are fixed so the centre transport stays window-centred.
    // The right column keeps every secondary control reachable at every width.
    readonly property int sideWidth: compact ? 240 : 264
    // The centre transport column is bounded so its timeline stays usable while
    // the whole column stays centred on the capsule (and thus the window).
    readonly property int centerWidth: Math.max(200, Math.min(560, width - 2 * (sideWidth + 20)))
    function t(key) { return translator.text(key, translator.language) }
    // An unknown duration needs a placeholder; a current position of zero is valid.
    // Both values arrive in milliseconds and are shown at whole-second precision.
    // Clamping negatives avoids showing a transient decoder value as a negative clock.
    function formatTime(ms, isDuration) {
        if (isDuration && Number(ms) <= 0) return "--:--"
        const seconds = Math.max(0, Math.floor(Number(ms || 0) / 1000))
        return Math.floor(seconds / 60) + ":" + ("0" + seconds % 60).slice(-2)
    }

    // Soft drop shadow that lifts the capsule off the canvas, giving the card
    // its floating read. Skipped when reduced motion is requested.
    Rectangle {
        anchors.fill: card
        anchors.topMargin: 6
        radius: card.radius
        color: Qt.rgba(0, 0, 0, 0.35)
        visible: !Theme.reducedMotion
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.radiusSheet
        color: Theme.bgRaised
        border.color: Theme.borderSubtle
        border.width: 1

        // Left cluster: cover + title + more. Anchored, not flexible, so a long
        // title cannot push the transport off the window centre.
        RowLayout {
            id: leftControls
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: capsule.sideWidth
            spacing: 12
                Button {
                    objectName: "nowPlayingCoverButton"
                    implicitWidth: 44; implicitHeight: 44; padding: 2
                    Layout.minimumWidth: 44; Layout.maximumWidth: 44
                    enabled: capsule.shell.hasSong
                    Accessible.name: capsule.t("now_playing")
                    background: Rectangle { color: Theme.bgSurface; radius: Theme.radiusSm }
                    contentItem: Item {
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSm
                            color: Theme.bgSurface
                            clip: true
                            Image { anchors.fill: parent; source: Qt.resolvedUrl("../../assets/artwork-default.png"); fillMode: Image.PreserveAspectCrop; mipmap: true }
                            Image { objectName: "nowPlayingCover"; anchors.fill: parent; source: capsule.shell.hasSong ? Theme.artwork(capsule.coverUrl) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
                        }
                    }
                    onClicked: capsule.shell.openNowPlaying()
                    ToolTip.visible: hovered || activeFocus
                    ToolTip.text: capsule.t("now_playing")
                }
                Button {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    enabled: capsule.shell.hasSong
                    padding: 0
                    Accessible.name: capsule.shell.hasSong ? String(capsule.shell.song.title) : capsule.t("no_track_selected")
                    background: Item {}
                    contentItem: ColumnLayout {
                        spacing: 3
                        Label { Layout.fillWidth: true; text: capsule.shell.hasSong ? capsule.shell.song.title || capsule.t("untitled") : capsule.t("no_track_selected"); color: Theme.textPrimary; font.pixelSize: Theme.fontBody; font.weight: Font.DemiBold; elide: Text.ElideRight; textFormat: Text.PlainText }
                        ArtistNames {
                            id: nowPlayingArtists
                            objectName: "nowPlayingArtists"
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            summarizeOverflow: true
                            remainingTextTemplate: capsule.t("additional_artists")
                            artist: capsule.shell.hasSong ? String(capsule.shell.song.artist || "") : ""
                            fallbackText: capsule.t(capsule.shell.hasSong ? "unknown_artist" : "browse_library")
                            font.pixelSize: Theme.fontCaption
                        }
                    }
                    onClicked: capsule.shell.openNowPlaying()
                    ToolTip.visible: hovered || activeFocus
                    ToolTip.text: String(capsule.shell.song.title || "")
                        + (nowPlayingArtists.names.length ? "\n" + nowPlayingArtists.names.join(" · ") : "")
                }
                IconButton {
                    id: songMore
                    kind: "more"; implicitWidth: 28; implicitHeight: 32
                    enabled: capsule.shell.hasSong
                    tooltipText: capsule.t("track_actions")
                    onClicked: songMenu.openAt(songMore)
                }
            }

            // Centre cluster: transport + timeline, centred on the capsule.
            ColumnLayout {
                objectName: "transportControls"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: capsule.centerWidth
                spacing: 0
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12
                    IconButton { objectName: "previousTrackButton"; kind: "previous"; implicitWidth: 32; implicitHeight: 32; tooltipText: capsule.t("previous"); enabled: capsule.shell.transport.connected && capsule.shell.queue.length > 0; onClicked: capsule.controller.previous() }
                    IconButton {
                        objectName: "mainPlayButton"
                        kind: capsule.shell.isPlaying ? "pause" : "play"
                        tooltipText: capsule.t(capsule.shell.isPlaying ? "pause" : "play")
                        implicitWidth: capsule.playControlSize; implicitHeight: capsule.playControlSize
                        iconSize: 22; cornerRadius: capsule.playControlSize / 2
                        fillColor: Theme.accentPrimary; hoverColor: Theme.accentHover; pressedColor: Theme.accentPressed
                        glyphColor: Theme.textOnAccent; hoverGlyphColor: Theme.textOnAccent
                        enabled: capsule.shell.transport.connected && (capsule.shell.hasSong || capsule.shell.queue.length > 0)
                        onClicked: capsule.controller.togglePlayPause()
                    }
                    IconButton { objectName: "nextTrackButton"; kind: "next"; implicitWidth: 32; implicitHeight: 32; tooltipText: capsule.t("next"); enabled: capsule.shell.transport.connected && capsule.shell.queue.length > 0; onClicked: capsule.controller.next() }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Label { Layout.preferredWidth: 40; text: capsule.formatTime(timeline.pressed ? timeline.valueAt(timeline.position) : timeline.value, false); color: Theme.textMuted; font.pixelSize: Theme.fontCaption; horizontalAlignment: Text.AlignRight }
                    // The time label follows the handle's preview while pressed, not stale backend position.
                    // SeekSlider keeps that preview stable until release and backend acknowledgement.
                    // Only its committed signal sends the millisecond seek request to the controller.
                    SeekSlider {
                        id: timeline; objectName: "playbackSeekSlider"
                        Layout.fillWidth: true
                        implicitHeight: 24
                        baseColor: capsule.trackColor
                        duration: capsule.shell.duration; playbackPosition: capsule.shell.position
                        onSeekRequested: value => capsule.controller.seek(value)
                        Accessible.name: capsule.t("playback_progress")
                    }
                    Label { Layout.preferredWidth: 40; text: capsule.formatTime(capsule.shell.duration, true); color: Theme.textMuted; font.pixelSize: Theme.fontCaption }
                }
            }

            // Right cluster: volume + view toggles.
            RowLayout {
                id: rightControls
                objectName: "playerSecondaryControls"
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: capsule.sideWidth
                spacing: 6
                IconButton { objectName: "volumeMuteButton"; kind: capsule.shell.volume > 0 ? "volume" : "mute"; tooltipText: capsule.t("volume"); enabled: capsule.shell.transport.connected; implicitWidth: 32; implicitHeight: 32; onClicked: capsule.controller.toggleMute() }
                // Volume follows every moved event; seeking keeps its separate release-only behaviour.
                // The slider keeps its hit area at every width; only its length shrinks.
                PlayerSlider {
                    objectName: "volumeSlider"
                    Layout.fillWidth: true; Layout.minimumWidth: 64; Layout.maximumWidth: 108
                    baseColor: capsule.trackColor
                    from: 0; to: 1; value: capsule.shell.volume
                    enabled: capsule.shell.transport.connected
                    onMoved: capsule.controller.setVolume(value)
                    Accessible.name: capsule.t("volume")
                }
                AudioOutputButton {
                    controller: capsule.shell.app ? capsule.shell.app.audioOutput || null : null
                    translator: capsule.translator; connected: capsule.shell.transport.connected
                    implicitWidth: 32; implicitHeight: 32
                }
                IconButton {
                    objectName: "nowPlayingButton"
                    kind: "lyrics"; tooltipText: capsule.t("now_playing")
                    implicitWidth: 32; implicitHeight: 32
                    glyphColor: capsule.shell.nowPlayingOpen ? Theme.accentPrimary : Theme.textMuted
                    enabled: capsule.shell.hasSong
                    onClicked: capsule.shell.nowPlayingOpen ? capsule.shell.closeNowPlaying() : capsule.shell.openNowPlaying()
                }
                Item {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    IconButton { objectName: "queueToggleButton"; anchors.fill: parent; kind: "queue"; tooltipText: capsule.t("queue") + " (" + capsule.shell.queue.length + ")"; glyphColor: capsule.shell.queueOpen ? Theme.accentPrimary : Theme.textMuted; onClicked: capsule.shell.host.queueOpen = !capsule.shell.queueOpen }
                    Rectangle {
                        anchors.right: parent.right; anchors.top: parent.top
                        anchors.rightMargin: -4; anchors.topMargin: -4
                        width: Math.max(18, countLabel.implicitWidth + 8); height: 18; radius: 9
                        color: Theme.bgSelected
                        border.color: Theme.bgRaised; border.width: 1
                        visible: capsule.shell.queue.length > 0
                        Label {
                            id: countLabel; anchors.centerIn: parent
                            text: capsule.shell.queue.length > 99 ? "99+" : String(capsule.shell.queue.length)
                            color: Theme.accentPrimary; font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                    }
                }
            }
    }

    ActionMenu {
        id: songMenu
        actions: [
            {key: "edit", label: capsule.t("edit_info"), enabled: capsule.shell.transport.connected},
            {key: "playlist", label: capsule.t("add_to_playlist"), enabled: capsule.shell.transport.connected},
            {key: "stop", label: capsule.t("stop"), enabled: capsule.shell.transport.connected}
        ]
        onChosen: action => {
            if (action === "edit") capsule.editRequested(capsule.shell.song)
            else if (action === "stop") capsule.controller.stop()
            else { capsule.addError = ""; picker.open() }
        }
    }
    Popup {
        // Playlist insertion uses the current song's library ID, not its queue occurrence ID.
        // Pending completion keeps the target operation visible and disables duplicate submissions.
        // A failed add retains the picker and shows its error so another attempt can be made.
        id: picker
        parent: Overlay.overlay; anchors.centerIn: parent
        width: 360; height: Math.min(400, parent.height - 40); padding: 20
        modal: true; focus: true
        closePolicy: capsule.addPending ? Popup.NoAutoClose : Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { objectName: "shortcutBlocker"; color: Theme.bgRaised; radius: Theme.radiusLg; border.color: Theme.borderSubtle }
        ColumnLayout {
            anchors.fill: parent; spacing: 12
            Label { text: capsule.t("add_to_playlist"); color: Theme.textPrimary; font.pixelSize: Theme.fontDialogTitle }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                model: capsule.shell.app.playlists.model
                ScrollBar.vertical: ScrollBar {}
                delegate: TextButton {
                    required property var modelData
                    width: ListView.view.width; text: modelData.name; subtle: true
                    enabled: !capsule.addPending && capsule.shell.transport.connected
                    onClicked: { capsule.addPending = true; capsule.shell.app.playlists.managePlaylist("add", {id: Number(modelData.id), song_id: Number(capsule.shell.song.song_id)}) }
                }
                Label { width: parent.width; anchors.centerIn: parent; wrapMode: Text.WordWrap; visible: capsule.shell.app.playlists.model.count === 0; text: capsule.t("no_playlists"); color: Theme.textMuted }
            }
            Label { Layout.fillWidth: true; text: capsule.addError; visible: Boolean(capsule.addError); color: Theme.statusError; wrapMode: Text.WordWrap; textFormat: Text.PlainText }
            TextButton { Layout.alignment: Qt.AlignRight; text: capsule.t("cancel"); subtle: true; enabled: !capsule.addPending; onClicked: picker.close() }
        }
    }
    Connections {
        target: capsule.shell.app.playlists
        function onRequestSucceeded(method) { if (method === "playlist.add" && capsule.addPending) { capsule.addPending = false; picker.close() } }
        function onRequestFailed(method, message) { if (method === "playlist.add" && capsule.addPending) { capsule.addPending = false; capsule.addError = message } }
    }
}
