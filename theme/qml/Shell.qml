pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import NekoTune 1.0
import "components"
import "dialogs"
import "shell"
import "shell/PageRegistry.js" as PageRegistry

Item {
    id: root
    objectName: "starcapeShell"
    ExtensionApi { id: api }
    readonly property var host: api.window
    readonly property var app: api.app
    readonly property var transport: host.transport
    readonly property var translator: host.translator
    readonly property var desktop: host.desktop
    readonly property var theme: Theme
    readonly property bool debugEnabled: host.debugEnabled
    readonly property string viewMode: host.viewMode
    readonly property string settingsSection: host.settingsSection
    readonly property bool nowPlayingOpen: host.nowPlayingOpen
    readonly property bool queueOpen: host.queueOpen
    readonly property int currentPlaylist: host.currentPlaylist
    readonly property bool hasBrowserSources: app.extensions.browserSources.length > 0
    readonly property var song: app.playback.song
    readonly property var queue: app.queue.model.items
    readonly property var lyrics: app.lyrics.current
    readonly property var selectedTagIds: app.library.selectedTagIds
    readonly property real position: app.playback.position
    readonly property real duration: app.playback.duration
    readonly property real volume: app.playback.volume
    readonly property string playbackState: app.playback.state
    readonly property string databasePath: app.databasePath
    readonly property bool isPlaying: playbackState === "playing"
    readonly property bool hasSong: Boolean(song.song_id)
    readonly property int currentIndex: queue.findIndex(item => item.state === "current")
    function navigate(id: string, playlistId: int): void { host.navigateTo(id, Number(playlistId || 0)) }
    function openNowPlaying(): void { host.openNowPlaying() }
    function closeNowPlaying(): void { host.closeNowPlaying() }
    function openImport(target: string, playlistId: int): void { host.openImport(target, Number(playlistId || 0)) }
    readonly property var extensions: api.app.extensions
    readonly property var pages: PageRegistry.pages.concat(extensions ? extensions.pages : [])
    function pageItem(id: string): Item {
        const index = root.pages.findIndex(page => page.id === id)
        const loader = pageRepeater.itemAt(index)
        return loader ? loader.item : null
    }
    function pageStatus(id: string): int {
        const index = root.pages.findIndex(page => page.id === id)
        const loader = pageRepeater.itemAt(index)
        return loader ? loader.status : Loader.Null
    }
    function queuePage(): Item { return pageItem("queue") }
    function currentPage(): Item { return host.queueOpen ? queuePanel : pageItem(host.viewMode) }
    function focusSearch(): void {
        const page = currentPage()
        if (page && typeof page.focusSearch === "function") page.focusSearch()
    }
    MetadataEditor { id: metadataEditor; shell: root; controller: api.app.library; ai: api.app.ai; translator: root.host.translator }
    TagEditor { id: tagEditor; shell: root; controller: api.app.tags; translator: root.host.translator }
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            visible: toolbarRepeater.count > 0
            Repeater {
                id: toolbarRepeater
                model: root.extensions ? root.extensions.toolbars : []
                delegate: ExtensionView {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: modelData.height || 48
                    descriptor: modelData; controllers: root.host.app; translator: root.host.translator; hostWindow: root.host
                }
            }
        }
        Item {
            id: workspace
            Layout.fillWidth: true
            Layout.fillHeight: true
            RowLayout {
                anchors.fill: parent
                spacing: 0
                RailBar {
                    shell: root; controllers: root.host.app; transport: root.host.transport; translator: root.host.translator
                    pages: root.pages.filter(page => page.id !== "music_sources" || root.host.hasBrowserSources)
                    currentPlaylist: root.host.currentPlaylist
                    visible: !root.host.nowPlayingOpen && root.host.viewMode !== "lyrics"
                    onPlaylistRequested: id => root.navigate("queue", id)
                    onNewPlaylistRequested: if (root.queuePage()) root.queuePage().newPlaylist()
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.bgCanvas
                    // A faint top-down wash keeps the browsing canvas from
                    // reading as a single flat black surface.
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.bgCanvasTop }
                        GradientStop { position: 0.55; color: Theme.bgCanvas }
                        GradientStop { position: 1.0; color: Qt.darker(Theme.bgCanvas, 1.08) }
                    }
                    StarDust { anchors.fill: parent }
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: errorLabel.implicitHeight + 20
                            visible: Boolean(root.host.transport.error)
                            color: Theme.statusErrorBg
                            Label {
                                id: errorLabel
                                anchors.fill: parent; anchors.margins: 10
                                text: root.host.translator.text(root.host.transport.error, root.host.translator.language); textFormat: Text.PlainText
                                color: Theme.statusError; wrapMode: Text.WordWrap; font.pixelSize: 12
                            }
                        }
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            // Reserve the capsule band at the bottom of the content
                            // area (v2.0 Section 2.2 / 5.1): pages lay out above
                            // the floating capsule, so no row is ever hidden
                            // behind it.
                            Layout.bottomMargin: Theme.contentBottomInset
                            Repeater {
                                id: pageRepeater
                                model: root.pages
                                delegate: PageHost {
                                    id: pageLoader
                                    anchors.fill: parent
                                    active: !modelData.debug || root.host.debugEnabled
                                    visible: modelData.id === "lyrics" ? root.host.nowPlayingOpen || root.host.viewMode === "lyrics"
                                             : !root.host.nowPlayingOpen && root.host.viewMode === modelData.id
                                    objectName: modelData.id === "lyrics_debug" ? "lyricsDebugPageLoader" : modelData.id + "PageLoader"
                                    shell: root; controllers: root.host.app; transport: root.host.transport; translator: root.host.translator
                                    Connections {
                                        target: pageLoader.item
                                        ignoreUnknownSignals: true
                                        function onImportRequested(id) { root.host.openImport(id ? "playlist" : modelData.id === "queue" ? "queue" : "library", id) }
                                        function onEditRequested(song) { metadataEditor.openForSong(song) }
                                        function onNewTagRequested() { tagEditor.openNew() }
                                        function onEditTagRequested(tag) { tagEditor.openForTag(tag) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: drawer
                objectName: "queueDrawer"
                anchors.top: parent.top
                anchors.topMargin: Theme.capsuleMargin
                // The floating sheet stops above the player capsule so the two
                // never overlap; the capsule stays reachable at the window floor.
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.bottomBarHeight + Theme.capsuleMargin * 2
                anchors.right: parent.right
                anchors.rightMargin: root.queueOpen ? Theme.capsuleMargin : -20
                width: root.width < 1200 ? Theme.sheetWidthCompact : Theme.sheetWidth
                // Keep rendering through the exit animation, but stop accepting input immediately.
                visible: root.queueOpen || opacity > 0
                enabled: root.queueOpen
                opacity: root.queueOpen ? 1 : 0
                radius: Theme.radiusSheet
                color: Theme.bgRaised
                border.color: Theme.borderSubtle
                border.width: 1
                z: 10
                Behavior on opacity {
                    NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durationDrawer; easing.type: Easing.OutCubic }
                }
                Behavior on anchors.rightMargin {
                    NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durationDrawer; easing.type: Easing.OutCubic }
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onWheel: wheel => wheel.accepted = true
                }
                QueuePanel {
                    id: queuePanel
                    objectName: "queueDrawerPanel"
                    anchors.fill: parent; anchors.margins: 16
                    compact: true
                    connected: root.host.transport.connected
                    queueController: root.host.app.queue
                    playbackController: root.host.app.playback
                    playbackMode: root.host.app.playback.playbackMode
                    playlistController: root.host.app.playlists
                    queue: root.queue
                    queueModel: root.host.app.queue.model
                    playlists: root.host.app.playlists.model.items
                    duration: root.host.duration
                    currentSong: root.song; playbackState: root.host.playbackState
                    onAddRequested: root.host.openImport("queue", 0)
                    onClearRequested: root.host.app.queue.clearQueue()
                    onPlayRequested: id => root.host.app.queue.playQueueItem(id)
                    onTogglePlayPauseRequested: root.host.app.playback.togglePlayPause()
                    onRemoveRequested: id => root.host.app.queue.removeQueueItem(id)
                    onEditRequested: song => metadataEditor.openForSong(song)
                    onPlaylistRequested: (action, params) => root.host.app.playlists.managePlaylist(action, params)
                    onLibraryRequested: root.navigate("library")
                    onCloseRequested: root.host.queueOpen = false
                }
            }
        }
    }

    // Floating player capsule: centred, limited width, floating over the canvas.
    // The chrome extension can still replace this slot with a full custom player.
    Item {
        id: capsuleSlot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.capsuleMargin
        height: Theme.bottomBarHeight
        // The capsule is always reachable, including over the immersive
        // now-playing surface (v1.1 kept the bottom bar visible there too).
        // A chrome extension can still replace this slot with a custom player.
        z: 20
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(Theme.capsuleMaxWidth, parent.width - Theme.capsuleMargin * 2)
            height: parent.height
            PlayerCapsule {
                id: capsuleCard
                anchors.fill: parent
                visible: !customPlayer.ready
                shell: root; controller: root.host.app.playback; translator: root.host.translator
                onEditRequested: song => metadataEditor.openForSong(song)
            }
            ThemeSlot { id: customPlayer; anchors.fill: parent; fallbackDescriptor: root.extensions ? root.extensions.activeSlots.bottomPlayer || ({}) : ({}); controllers: root.host.app; translator: root.host.translator; hostWindow: root.host }
        }
    }
}
