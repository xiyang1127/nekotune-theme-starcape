import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

// v2.0 navigation rail: a 64px icon-only column. Labels live in hover
// bubbles and the playlists fly-out, so no text is permanently shown.
// Playlist identity and selection are separate from playback.
// The rail keeps a single accent marker for the current section.
Item {
    id: rail
    required property var shell
    required property var controllers
    required property var transport
    required property var translator
    required property var pages
    property int currentPlaylist: 0
    signal playlistRequested(int id)
    signal newPlaylistRequested()

    readonly property bool compact: shell.width < 1200
    readonly property var primaryPages: pages.filter(page => page.group === "primary")
    readonly property var utilityPages: pages.filter(page => page.group === "utility" || page.debug && shell.debugEnabled)
    readonly property bool playlistsCurrent: shell.viewMode === "queue"
    // The centred capsule covers the window centre band. When the window is
    // narrow enough for the capsule to reach over the rail, lift the bottom
    // utility icons and the connection dot above it so they stay reachable.
    readonly property real capsuleLeftEdge: (shell.width - Math.min(Theme.capsuleMaxWidth, shell.width - Theme.capsuleMargin * 2)) / 2
    readonly property real bottomClearance: capsuleLeftEdge > 0 && capsuleLeftEdge < Layout.preferredWidth + 8
        ? Theme.bottomBarHeight + Theme.capsuleMargin * 2 : 0
    Layout.preferredWidth: compact ? Theme.railWidthCompact : Theme.railWidth
    Layout.fillHeight: true
    function t(key) { return translator.text(key, translator.language) }
    function label(page) { return page.extensionId && rail.controllers.extensions ? rail.controllers.extensions.label(page.title || page.id, rail.translator.language) : rail.t(page.title) }

    // Map a page id to a rail glyph. Unknown ids fall back to a plain dot.
    function iconKind(id) {
        if (id === "home") return "home"
        if (id === "history") return "history"
        if (id === "library") return "disc"
        if (id === "music_sources") return "globe"
        if (id === "extensions") return "extensions"
        if (id === "settings") return "settings"
        return "music"
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgSidebar
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.borderSubtle }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 16
        // Reserve the capsule's vertical band when it overlaps the rail, so
        // the bottom utility entries and connection state remain reachable.
        anchors.bottomMargin: 16 + rail.bottomClearance
        spacing: 8

        // Brand mark: a single-colour sparkle, no gradient tile or halo.
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Theme.railIconSize
            Layout.preferredHeight: Theme.railIconSize
            IconButton {
                anchors.centerIn: parent
                kind: "star"
                iconSize: 22
                tooltipText: "NekoTune"
                glyphColor: Theme.accentPrimary
                Accessible.name: "NekoTune"
                onClicked: rail.shell.navigate("home")
            }
        }

        Item { Layout.preferredHeight: 4 }

        Repeater {
            model: rail.primaryPages
            delegate: Item {
                id: navSlot
                required property var modelData
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Theme.railIconSize
                Layout.preferredHeight: Theme.railIconSize
                readonly property bool isCurrent: rail.shell.viewMode === modelData.id
                IconButton {
                    id: navButton
                    anchors.centerIn: parent
                    objectName: "nav_" + navSlot.modelData.id
                    kind: rail.iconKind(navSlot.modelData.id)
                    tooltipText: rail.label(navSlot.modelData)
                    glyphColor: navSlot.isCurrent ? Theme.accentPrimary : Theme.textMuted
                    fillColor: navSlot.isCurrent ? Theme.bgSelected : "transparent"
                    Accessible.selected: navSlot.isCurrent
                    onClicked: rail.shell.navigate(navSlot.modelData.id)
                    // Current-section marker (Section 8.1): a short accent bar
                    // inside the selected pill, independent of keyboard focus.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: -(rail.width - parent.width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3; height: 20; radius: 1.5
                        color: Theme.accentPrimary
                        visible: navSlot.isCurrent
                    }
                }
            }
        }

        // Playlists entry: the fly-out carries the names so the rail stays iconic.
        Item {
            id: playlistSlot
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Theme.railIconSize
            Layout.preferredHeight: Theme.railIconSize
            IconButton {
                id: playlistButton
                anchors.centerIn: parent
                objectName: "nav_playlists"
                kind: "queue"
                tooltipText: rail.t("playlists")
                glyphColor: rail.playlistsCurrent ? Theme.accentPrimary : Theme.textMuted
                fillColor: rail.playlistsCurrent ? Theme.bgSelected : "transparent"
                Accessible.selected: rail.playlistsCurrent
                onClicked: playlistPopup.opened ? playlistPopup.close() : playlistPopup.open()
                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: -(rail.width - parent.width) / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 20; radius: 1.5
                    color: Theme.accentPrimary
                    visible: rail.playlistsCurrent
                }
            }
        }

        Item { Layout.fillHeight: true }

        Repeater {
            model: rail.utilityPages
            delegate: Item {
                id: utilitySlot
                required property var modelData
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Theme.railIconSize
                Layout.preferredHeight: Theme.railIconSize
                readonly property bool isCurrent: rail.shell.viewMode === modelData.id
                IconButton {
                    anchors.centerIn: parent
                    objectName: utilitySlot.modelData.debug ? "lyricsDebugNavigation" : "nav_" + utilitySlot.modelData.id
                    kind: rail.iconKind(utilitySlot.modelData.id)
                    tooltipText: rail.label(utilitySlot.modelData)
                    glyphColor: utilitySlot.isCurrent ? Theme.accentPrimary : Theme.textMuted
                    fillColor: utilitySlot.isCurrent ? Theme.bgSelected : "transparent"
                    Accessible.selected: utilitySlot.isCurrent
                    onClicked: rail.shell.navigate(utilitySlot.modelData.id)
                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: -(rail.width - parent.width) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3; height: 20; radius: 1.5
                        color: Theme.accentPrimary
                        visible: utilitySlot.isCurrent
                    }
                }
            }
        }

        // Connection state: a dot plus text in the hover bubble, never a bare light.
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Theme.railIconSize
            Layout.preferredHeight: 24
            Rectangle {
                id: connectionDot
                anchors.centerIn: parent
                width: 8; height: 8; radius: 4
                color: rail.transport.connected ? Theme.statusSuccess : Theme.statusError
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                ToolTip.visible: containsMouse
                ToolTip.text: rail.t(rail.transport.connected ? "connected" : "offline")
                ToolTip.delay: 300
            }
        }
    }

    // Playlists fly-out: floating list to the right of the rail (Section 6.1).
    Popup {
        id: playlistPopup
        objectName: "playlistFlyout"
        parent: Overlay.overlay
        x: rail.mapToItem(Overlay.overlay, rail.width, 0).x + 8
        y: Overlay.overlay ? Math.min(rail.mapToItem(Overlay.overlay, 0, 0).y + 72, Overlay.overlay.height - height - 24) : 0
        width: 240
        height: Math.min(420, Overlay.overlay ? Overlay.overlay.height - 120 : 420)
        padding: 12
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            objectName: "shortcutBlocker"
            color: Theme.bgRaised; radius: Theme.radiusLg; border.color: Theme.borderSubtle
        }
        contentItem: ColumnLayout {
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Label { Layout.fillWidth: true; text: rail.t("playlists"); color: Theme.textMuted; font.pixelSize: Theme.fontCaption }
                IconButton { kind: "plus"; implicitWidth: 32; implicitHeight: 32; tooltipText: rail.t("new_playlist"); enabled: rail.transport.connected; onClicked: { playlistPopup.close(); rail.newPlaylistRequested() } }
            }
            ListView {
                id: playlistList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 80
                clip: true
                spacing: 4
                model: rail.controllers.playlists.model
                ScrollBar.vertical: ScrollBar {}
                onCountChanged: Qt.callLater(() => {
                    const index = rail.controllers.playlists.model.items.findIndex(list => Number(list.id) === rail.currentPlaylist)
                    if (index >= 0) playlistList.positionViewAtIndex(index, ListView.Contain)
                })
                delegate: TextButton {
                    id: playlistItem
                    required property var modelData
                    width: playlistList.width
                    objectName: "nav_playlist_" + modelData.id
                    text: modelData.name
                    readonly property bool isCurrent: rail.shell.viewMode === "queue" && rail.currentPlaylist === Number(modelData.id)
                    subtle: true
                    subtleBg: isCurrent ? Theme.bgSelected : "transparent"
                    subtleText: isCurrent ? Theme.accentPrimary : Theme.textSecondary
                    subtleBorder: "transparent"
                    Accessible.selected: isCurrent
                    onClicked: { playlistPopup.close(); rail.playlistRequested(Number(modelData.id)) }
                    ToolTip.visible: hovered || activeFocus
                    ToolTip.text: modelData.name
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: 8
                    visible: playlistList.count === 0
                    text: rail.t(rail.transport.connected ? "no_playlists" : "offline")
                    color: Theme.textMuted; font.pixelSize: Theme.fontCaption
                    wrapMode: Text.WordWrap
                    width: playlistList.width
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
