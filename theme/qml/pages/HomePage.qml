pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "qrc:/qml/components" as Builtin
import "../components"

// v2.0 home: a bento band of one large "now playing" tile beside a grid of
// playlist tiles, with the recent list full-width beneath. This replaces the
// v1.1 hero-strip + 2:3 two-column arrangement.
// Home consumes library and playlist state without inheriting library filters.
// Recent rows are sorted from a copied array, preserving the source model order.
// Its primary action prioritizes current track, existing queue, then library.
// Loading/failure is distinct from a successfully loaded empty library.
// Playing recent songs sends exactly that displayed recent sequence.
// One pending play guard prevents repeated requests before completion.
Item {
    id: page
    objectName: "starcapeHomePage"
    required property var shell
    required property var controllers
    required property var translator
    required property var transport
    signal importRequested(int playlistId)

    readonly property var theme: Theme
    readonly property bool compact: shell.width < 1200
    readonly property var songs: controllers.library.songs.items
    readonly property var playlists: controllers.playlists.model.items
    property string recentView: "added"
    readonly property var recentSongs: recentView === "played"
        ? songs.filter(song => Number.isFinite(Date.parse(String(song.last_played_at || ""))))
            .sort((a, b) => Date.parse(b.last_played_at) - Date.parse(a.last_played_at) || Number(a.song_id) - Number(b.song_id)).slice(0, 5)
        : songs.slice().sort((a, b) => Number(b.song_id) - Number(a.song_id)).slice(0, 5)
    readonly property bool hasPlayableSongs: songs.some(song => song.available)
    readonly property bool initialLoading: !controllers.library.loaded && controllers.library.loading
    readonly property bool initialFailed: !controllers.library.loaded && !controllers.library.loading
    readonly property string primaryAction: shell.hasSong ? (shell.isPlaying ? "pause" : shell.playbackState === "paused" ? "home_resume" : "play")
                                           : shell.queue.length ? "home_play_queue"
                                           : hasPlayableSongs ? "home_play_library" : "import_music"
    property int selectedSongId: 0
    property int skippedCount: 0
    property bool playbackPending: false
    property alias contentY: scroll.contentY

    function t(key) { return translator.text(key, translator.language) }
    function showLibrary() {
        controllers.library.searchText = ""
        controllers.library.selectedTagIds = []
        shell.navigate("library")
    }
    function newPlaylist() {
        if (transport.connected && shell.queuePage()) shell.queuePage().newPlaylist()
    }
    function playSongs(items, startSongId) {
        skippedCount = 0
        playbackPending = true
        controllers.library.playSongs(items.map(song => Number(song.song_id)), startSongId)
    }
    function activatePrimary() {
        if (!transport.connected) return
        if (shell.hasSong) controllers.playback.togglePlayPause()
        else if (shell.queue.length) controllers.playback.play()
        else if (hasPlayableSongs) playSongs(songs, 0)
        else if (controllers.library.loaded) importRequested(0)
    }
    function playRecent(song, toggleCurrent) {
        if (!transport.connected || !song.available || playbackPending) return
        if (toggleCurrent && Number(song.song_id) === Number(shell.song.song_id)) controllers.playback.togglePlayPause()
        else playSongs(recentSongs, Number(song.song_id))
    }
    // Resolve representative artwork from items already in this collection.
    // Prefer the current library snapshot's URL for the same song identity.
    // Fallback to the playlist snapshot's enriched URL while updates settle.
    // Return empty when no item has artwork so the normal placeholder appears.
    function playlistCover(playlist) {
        for (const item of playlist.items || []) {
            const record = songs.find(song => Number(song.song_id) === Number(item.song_id))
            if (record && record.cover_url) return Theme.artwork(record.cover_url)
            if (item.cover_url) return Theme.artwork(item.cover_url)
        }
        return ""
    }
    onRecentSongsChanged: {
        if (!recentSongs.some(song => Number(song.song_id) === selectedSongId)) selectedSongId = 0
    }
    Connections {
        target: page.controllers.library
        function onLibraryPlaybackSkipped(count) { if (page.playbackPending) page.skippedCount = count }
        function onRequestSucceeded(method) { if (method === "library.play") page.playbackPending = false }
        function onRequestFailed(method, message) { if (method === "library.play") page.playbackPending = false }
    }

    Flickable {
        id: scroll
        objectName: "homeScroll"
        anchors.fill: parent
        clip: true
        contentWidth: width
        // The shell already reserves the capsule band below the page host,
        // so the scroll extent needs no separate bottom inset here.
        contentHeight: content.implicitHeight + content.y
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: content
            x: page.compact ? Theme.contentMarginCompact : Theme.contentMargin
            y: x
            width: scroll.width - x * 2
            spacing: 24

            // Top toolbar: title + summary on the left, import on the right.
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Label { text: page.t("home"); color: page.theme.textPrimary; font.pixelSize: page.theme.fontHero; font.weight: Font.DemiBold }
                    Label {
                        objectName: "homeSummary"
                        Layout.fillWidth: true
                        text: page.controllers.library.loaded ? page.t("home_counts").replace("%1", page.songs.length).replace("%2", page.playlists.length)
                              : page.t(!page.transport.connected ? "home_offline" : page.initialFailed ? "home_load_failed" : "home_loading")
                        color: page.theme.textMuted
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
                TextButton {
                    objectName: "homeImportButton"
                    text: page.t("import_music")
                    subtle: true
                    enabled: page.transport.connected
                    onClicked: page.importRequested(0)
                }
            }

            // Bento band: large now-playing tile beside the playlist tile grid.
            GridLayout {
                id: bento
                Layout.fillWidth: true
                columns: page.compact ? 1 : 2
                columnSpacing: 24
                rowSpacing: 24

                // Bento main tile: current cover + info + actions.
                Rectangle {
                    objectName: "homeNowPlaying"
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    // Bento sizing: half the band beside the playlist grid,
                    // or the full band when the two stack in a compact window.
                    Layout.preferredWidth: page.compact ? bento.width : (bento.width - 24) * 0.5
                    Layout.preferredHeight: Math.max(page.compact ? 200 : 224, heroContent.implicitHeight + 48)
                    radius: page.theme.radiusLg
                    color: page.theme.bgSurface
                    border.color: page.theme.borderSubtle
                    clip: true
                    // A faint constellation at the right edge carries the starfield mood.
                    StarfieldState {
                        width: parent.height * 0.85
                        height: width
                        halo: false
                        anchors.right: parent.right
                        anchors.rightMargin: -width * 0.22
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: page.theme.isDark ? 0.4 : 0.3
                    }
                    RowLayout {
                        id: heroContent
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 24
                        Item {
                            Layout.preferredWidth: page.compact ? 128 : 148
                            Layout.preferredHeight: Layout.preferredWidth
                            Rectangle {
                                anchors.fill: parent
                                radius: page.theme.radiusLg
                                color: page.theme.bgSurfaceAlt
                                Image { anchors.fill: parent; source: Qt.resolvedUrl("../../assets/artwork-default.png"); fillMode: Image.PreserveAspectCrop; mipmap: true }
                                Image {
                                    objectName: "homeCurrentCover"
                                    anchors.fill: parent
                                    source: page.shell.hasSong ? Theme.artwork(page.shell.song.cover_url) : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    mipmap: true
                                    visible: status === Image.Ready
                                }
                            }
                            // A card-coloured ring masks the square image corners so the
                            // cover is rounded without relying on GPU-only effects.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -page.theme.radiusLg
                                radius: page.theme.radiusLg * 2
                                color: "transparent"
                                border.color: page.theme.bgSurface
                                border.width: page.theme.radiusLg
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: page.theme.radiusLg
                                color: "transparent"
                                border.color: page.theme.borderSubtle
                                border.width: 1
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 8
                            Label {
                                text: page.shell.hasSong ? page.t(page.shell.isPlaying ? "now_playing" : page.shell.playbackState)
                                      : page.translator.language === "zh" ? "星穹 · 此刻，听你喜欢" : "Starcape · listen to what you love"
                                color: page.theme.accentPrimary
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Label {
                                id: heroTitle
                                Layout.fillWidth: true
                                text: page.shell.hasSong ? String(page.shell.song.title || page.t("untitled")) : page.t("home_make_time")
                                textFormat: Text.PlainText
                                color: page.theme.textPrimary
                                font.pixelSize: page.theme.fontSongTitle
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                HoverHandler { id: titleHover }
                                ToolTip.visible: titleHover.hovered
                                ToolTip.text: heroTitle.text
                            }
                            ArtistNames {
                                objectName: "homeCurrentArtists"
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                artist: page.shell.hasSong ? String(page.shell.song.artist || "") : ""
                                fallbackText: page.shell.hasSong ? page.t("unknown_artist")
                                      : page.t(page.shell.queue.length ? "home_queue_ready" : "home_choose_music")
                                color: page.theme.textSecondary
                                font.pixelSize: 14
                            }
                            RowLayout {
                                Layout.topMargin: 8
                                spacing: 12
                                TextButton {
                                    objectName: "homePrimaryButton"
                                    text: page.t(page.primaryAction)
                                    enabled: page.transport.connected && !page.playbackPending
                                             && (page.shell.hasSong || page.shell.queue.length > 0 || page.controllers.library.loaded)
                                    onClicked: page.activatePrimary()
                                }
                                TextButton {
                                    objectName: "homeLyricsButton"
                                    text: page.t("home_view_lyrics")
                                    subtle: true
                                    subtleBg: "transparent"
                                    visible: page.shell.hasSong
                                    onClicked: page.shell.openNowPlaying()
                                }
                            }
                        }
                    }
                }

                // Playlist tile grid (the small bento tiles).
                ColumnLayout {
                    objectName: "homePlaylistsSection"
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: page.compact ? bento.width : (bento.width - 24) * 0.5
                    Layout.minimumWidth: 0
                    spacing: 16
                    RowLayout {
                        Layout.fillWidth: true
                        Label { Layout.fillWidth: true; text: page.t("home_my_playlists"); color: page.theme.textPrimary; font.pixelSize: 18; font.weight: Font.DemiBold }
                        IconButton {
                            objectName: "homeNewPlaylistButton"
                            kind: "plus"
                            tooltipText: page.t("new_playlist")
                            enabled: page.transport.connected
                            onClicked: page.newPlaylist()
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 12
                        Repeater {
                            model: page.playlists.slice(0, 4)
                            delegate: Button {
                                id: card
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.minimumWidth: 0
                                implicitHeight: 112
                                padding: 12
                                hoverEnabled: true
                                objectName: "homePlaylist" + modelData.id
                                Accessible.name: String(modelData.name)
                                onClicked: page.shell.navigate("queue", Number(modelData.id))
                                ToolTip.visible: hovered || activeFocus
                                ToolTip.text: String(modelData.name)
                                background: Rectangle {
                                    radius: page.theme.radiusMd
                                    color: card.hovered ? page.theme.bgHover : page.theme.bgSurface
                                    border.color: card.activeFocus ? page.theme.accentPrimary
                                                : card.hovered ? Qt.rgba(page.theme.accentPrimary.r, page.theme.accentPrimary.g, page.theme.accentPrimary.b, 0.45)
                                                : page.theme.borderSubtle
                                    Behavior on color {
                                        ColorAnimation { duration: page.theme.reducedMotion ? 0 : page.theme.durationFast }
                                    }
                                }
                                contentItem: ColumnLayout {
                                    spacing: 8
                                    RowLayout {
                                        spacing: 12
                                        Item {
                                            Layout.preferredWidth: 48; Layout.preferredHeight: 48
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: page.theme.radiusSm
                                                color: page.theme.bgRaised
                                                clip: true
                                                Image { anchors.fill: parent; source: Qt.resolvedUrl("../../assets/artwork-default.png"); fillMode: Image.PreserveAspectCrop; mipmap: true }
                                                Image { objectName: "homePlaylistCover"; anchors.fill: parent; source: page.playlistCover(card.modelData); fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: status === Image.Ready }
                                            }
                                        }
                                        Label {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            text: String(card.modelData.name)
                                            textFormat: Text.PlainText
                                            color: page.theme.textPrimary
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                    RowLayout {
                                        Label {
                                            Layout.fillWidth: true
                                            text: page.translator.countText("tracks", (card.modelData.items || []).length, page.translator.language)
                                            color: page.theme.textMuted; font.pixelSize: 12; elide: Text.ElideRight
                                        }
                                        IconButton {
                                            objectName: "homePlayPlaylist" + card.modelData.id
                                            kind: "play"
                                            implicitWidth: 36; implicitHeight: 36
                                            tooltipText: page.t("play")
                                            enabled: page.transport.connected && (card.modelData.items || []).length > 0
                                            onClicked: page.controllers.playlists.managePlaylist("play", {id: Number(card.modelData.id)})
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Label {
                        objectName: "homeEmptyPlaylists"
                        Layout.fillWidth: true
                        visible: page.playlists.length === 0
                        text: page.t(page.transport.connected ? "no_playlists" : "home_offline")
                        color: page.theme.textMuted; font.pixelSize: 14; wrapMode: Text.WordWrap
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: page.playlists.length > 4
                        text: page.t("home_more_playlists")
                        color: page.theme.textMuted; font.pixelSize: 12; wrapMode: Text.WordWrap
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                visible: page.skippedCount > 0
                text: page.t("unavailable_skipped").replace("%1", page.skippedCount)
                color: page.theme.statusWarning
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }

            // Recent music and listening history share the host's live library data.
            ColumnLayout {
                objectName: "homeRecentSection"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    ChoiceField {
                        objectName: "homeRecentPicker"
                        Layout.fillWidth: true
                        Layout.maximumWidth: 200
                        textRole: "label"; valueRole: "value"
                        model: [{value: "added", label: page.t("home_recent")}, {value: "played", label: page.t("home_recent_played")}]
                        currentIndex: page.recentView === "played" ? 1 : 0
                        onActivated: page.recentView = currentValue
                        Accessible.name: page.t("home_recent_view")
                    }
                    Item { Layout.fillWidth: true }
                    TextButton {
                        objectName: "homeViewAllButton"
                        text: page.t("home_view_all")
                        subtle: true; subtleBg: "transparent"; subtleBorder: "transparent"
                        onClicked: page.showLibrary()
                    }
                }
                Repeater {
                    model: page.recentSongs
                    delegate: TrackRow {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.songRowHeight
                        Layout.minimumWidth: 0
                        objectName: "homeRecentSong" + modelData.song_id
                        song: modelData
                        rowIndex: index
                        selected: page.selectedSongId === Number(modelData.song_id)
                        current: Number(page.shell.song.song_id) === Number(modelData.song_id)
                        playing: page.shell.isPlaying
                        available: Boolean(modelData.available)
                        connected: page.transport.connected && !page.playbackPending
                        playObjectName: "homePlaySong" + modelData.song_id
                        menuActions: [
                            {key: "next", label: page.t("play_next"), enabled: Boolean(modelData.available) && page.transport.connected},
                            {key: "queue", label: page.t("add_to_queue_end"), enabled: Boolean(modelData.available) && page.transport.connected}
                        ]
                        onActionRequested: action => page.controllers.queue.addSongs([Number(modelData.song_id)], action === "next")
                        onSelectedRequested: modifiers => page.selectedSongId = Number(modelData.song_id)
                        onActivated: page.playRecent(modelData)
                        onPlayClicked: page.playRecent(modelData, true)
                    }
                }
                Label {
                    objectName: "homeLibraryState"
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    visible: page.recentSongs.length === 0
                    text: page.t(!page.transport.connected ? "home_offline" : page.initialLoading ? "home_loading" : page.initialFailed ? "home_load_failed" : page.songs.length && page.recentView === "played" ? "home_empty_recent_played" : "home_empty_library")
                    color: page.theme.textMuted; font.pixelSize: 14; wrapMode: Text.WordWrap
                }
                TextButton {
                    objectName: "homeRetryButton"
                    visible: page.initialFailed && page.transport.connected
                    text: page.t("home_retry")
                    subtle: true
                    onClicked: page.controllers.library.refreshLibrary()
                }
            }

            Builtin.ListeningSummary {
                Layout.fillWidth: true
                history: page.controllers.history || null
                translator: page.translator
                transport: page.transport
                onOpenHistory: page.shell.navigate("history")
            }
        }
    }
}
