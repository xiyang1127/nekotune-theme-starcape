pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "qrc:/qml/components" as Builtin
import "qrc:/qml/wallpaper" as HostWallpaper

// Settings displays account capability flags rather than stored credentials.
// The password input is write-only and cleared on hiding/submission.
// Save/clear failures settle their own busy state for explicit retry.
// Language changes use the shared translator and merged settings persistence.
// The AI panel uses its own endpoint-scoped key configuration lifecycle.
// v2.0 layout: a centred two-pane panel — section list on the left, the
// selected section's content on the right. A section selector replaces the
// single long scroll so deep settings stay reachable without hunting.
Item {
    id: root
    required property var client
    required property var translator
    property var ai: null
    property var audioOutput: null
    property var playback: null
    property var storage: null
    property var desktop: null
    property var windowModes: null
    property var wallpaper: null
    property var themeController: null
    property bool appearanceAvailable: false
    signal appearanceRequested()
    property bool saving: false
    property string message: ""
    property bool failed: false
    property var account: ({})
    property bool connected: true
    property string databasePath: ""
    property bool showDataLocation: false
    property var extensionSettings: []
    signal extensionSettingsRequested(string id)

    // Selected settings group, including the host's optional wallpaper controls.
    property string section: "general"
    readonly property var sections: {
        const list = [{id: "general", label: t("general_settings")}]
        if (root.audioOutput !== null || root.playback !== null) list.push({id: "audio", label: t("audio_output")})
        if (root.playback !== null && Object.keys(root.playback.audioSettings || {}).length > 0)
            list.push({id: "engine", label: t("audio_engine")})
        if (root.storage !== null) list.push({id: "storage", label: t("storage_title")})
        if (root.windowModes !== null) list.push({id: "windows", label: t("window_modes")})
        if (root.wallpaper !== null) list.push({id: "wallpaper", label: t("wallpaper_title")})
        if (root.extensionSettings.length > 0) list.push({id: "extensions", label: t("extension_settings")})
        if (root.ai !== null) list.push({id: "ai", label: t("ai_settings")})
        if (root.databasePath) list.push({id: "about", label: t("database")})
        return list
    }
    onSectionsChanged: if (!sections.some(item => item.id === root.section)) root.section = sections[0].id
    onSectionChanged: sectionScroll.contentItem.contentY = 0
    function t(key) { return translator.text(key, translator.language) }
    function sectionLabel(id) {
        const match = sections.find(item => item.id === id)
        return match ? match.label : ""
    }

    // Centre the two-pane layout with a bounded width (Section 6.8).
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Math.max(20, (root.width - 900) / 2)
        anchors.rightMargin: Math.max(20, (root.width - 900) / 2)
        spacing: 24

        // Left pane: section list.
        ScrollView {
            id: navigationScroll
            Layout.preferredWidth: 180
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ColumnLayout {
                width: navigationScroll.availableWidth
                spacing: 6
                Label {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    text: root.t("settings")
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontTitle
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: root.sections
                    delegate: TextButton {
                        id: sectionEntry
                        required property var modelData
                        objectName: "settingsSection_" + modelData.id
                        Layout.fillWidth: true
                        text: modelData.label
                        subtle: true
                        subtleBg: root.section === modelData.id ? Theme.bgSelected : "transparent"
                        subtleText: root.section === modelData.id ? Theme.accentPrimary : Theme.textSecondary
                        subtleBorder: "transparent"
                        contentItem: RowLayout {
                            Label { Layout.fillWidth: true; text: sectionEntry.text; color: sectionEntry.subtleText; font: sectionEntry.font; elide: Text.ElideRight; textFormat: Text.PlainText }
                        }
                        Accessible.selected: root.section === modelData.id
                        onClicked: root.section = modelData.id
                        Rectangle {
                            anchors.left: parent.left; anchors.leftMargin: 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 2; height: 16; radius: 1
                            color: Theme.accentPrimary
                            visible: root.section === sectionEntry.modelData.id
                        }
                    }
                }
                TextButton {
                    objectName: "appearanceSettingsButton"
                    Layout.fillWidth: true
                    visible: root.appearanceAvailable
                    text: root.t("appearance") + "  ›"
                    subtle: true
                    onClicked: root.appearanceRequested()
                }
            }
        }

        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; Layout.topMargin: 4; Layout.bottomMargin: 4; color: Theme.borderSubtle }

        // Right pane: the selected section's content.
        ScrollView {
            id: sectionScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ColumnLayout {
                width: sectionScroll.availableWidth
                spacing: 14

                // General: language and account state.
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.section === "general"
                    spacing: 14
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: generalBody.implicitHeight + 36
                        radius: Theme.radiusMd; color: Theme.bgSurface; border.color: Theme.borderSubtle
                        ColumnLayout {
                            id: generalBody
                            anchors.fill: parent; anchors.margins: 18; spacing: 12
                            Label { text: root.t("general_settings"); color: Theme.textPrimary; font.pixelSize: Theme.fontDialogTitle }
                            RowLayout {
                                Label { Layout.fillWidth: true; text: root.t("language"); color: Theme.textSecondary; font.pixelSize: Theme.fontBody }
                                TextButton { text: "中文"; subtle: root.translator.language !== "zh"; onClicked: root.translator.language = "zh" }
                                TextButton { text: "English"; subtle: root.translator.language !== "en"; onClicked: root.translator.language = "en" }
                            }
                            CheckBox {
                                objectName: "closeToTrayCheckBox"
                                Layout.fillWidth: true
                                visible: root.desktop !== null
                                text: root.t("close_to_tray")
                                font.pixelSize: Theme.fontBody
                                palette.windowText: Theme.textPrimary
                                palette.highlight: Theme.accentPrimary
                                checked: root.desktop ? root.desktop.closeToTray : false
                                onClicked: if (root.desktop) root.desktop.closeToTray = checked
                                Accessible.name: text
                            }
                            Label {
                                Layout.fillWidth: true
                                visible: root.desktop !== null && !root.desktop.trayAvailable
                                text: root.t("tray_unavailable")
                                color: Theme.textMuted; font.pixelSize: Theme.fontCaption
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                // Audio output.
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.section === "audio" && root.audioOutput !== null
                    implicitHeight: outputSettings.implicitHeight + 36
                    radius: Theme.radiusMd; color: Theme.bgSurface; border.color: Theme.borderSubtle
                    ColumnLayout {
                        id: outputSettings
                        anchors.fill: parent; anchors.margins: 18; spacing: 12
                        Label { text: root.t("audio_output"); color: Theme.textPrimary; font.pixelSize: Theme.fontDialogTitle }
                        AudioOutputPicker {
                            objectName: "settingsAudioOutputPicker"
                            Layout.fillWidth: true
                            controller: root.audioOutput; translator: root.translator; connected: root.connected
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    visible: root.section === "audio" && root.playback !== null
                    implicitHeight: rateSettings.implicitHeight + 36
                    radius: Theme.radiusMd; color: Theme.bgSurface; border.color: Theme.borderSubtle
                    ColumnLayout {
                        id: rateSettings
                        anchors.fill: parent; anchors.margins: 18; spacing: Theme.spaceMd
                        RowLayout {
                            Layout.fillWidth: true
                            Label { Layout.fillWidth: true; text: root.t("playback_rate"); color: Theme.textPrimary; font.pixelSize: Theme.fontDialogTitle }
                            Builtin.PlaybackRateButton {
                                translator: root.translator
                                playbackRate: root.playback ? root.playback.playbackRate : 1.0
                                enabled: root.connected && root.playback !== null && root.playback.playbackRateSupported
                                onRateRequested: rate => root.playback.setPlaybackRate(rate)
                            }
                            TextButton {
                                objectName: "resetPlaybackRateButton"
                                text: root.t("playback_rate_reset")
                                subtle: true
                                enabled: root.connected && root.playback !== null
                                onClicked: root.playback.setPlaybackRate(1.0)
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: root.t(root.playback && root.playback.playbackRateSupported ? "playback_rate_hint" : "playback_rate_unavailable")
                            color: Theme.textMuted; font.pixelSize: Theme.fontCaption; wrapMode: Text.WordWrap
                        }
                    }
                }

                Builtin.AudioEngineSettings {
                    Layout.fillWidth: true
                    visible: root.section === "engine"
                    controller: root.playback
                    translator: root.translator
                    enabled: root.connected
                }

                Builtin.LibraryStorageSettings {
                    objectName: "starcapeStorageSettings"
                    Layout.fillWidth: true
                    visible: root.section === "storage" && root.storage !== null
                    controller: root.storage
                    translator: root.translator
                    connected: root.connected
                }

                Builtin.PlaybackWindowSettings {
                    objectName: "starcapeWindowSettings"
                    Layout.fillWidth: true
                    visible: root.section === "windows" && root.windowModes !== null
                    manager: root.windowModes
                    translator: root.translator
                }

                HostWallpaper.WallpaperSettings {
                    objectName: "starcapeWallpaperSettings"
                    Layout.fillWidth: true
                    visible: root.section === "wallpaper" && root.wallpaper !== null
                    manager: root.wallpaper
                    themeController: root.themeController
                    translator: root.translator
                }

                // Extension-provided settings pages.
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.section === "extensions"
                    spacing: 8
                    Repeater {
                        model: root.section === "extensions" ? root.extensionSettings : []
                        delegate: TextButton {
                            id: entry
                            required property var modelData
                            objectName: "settings_entry_" + modelData.id
                            Layout.fillWidth: true
                            text: modelData.title
                            subtle: true
                            contentItem: RowLayout {
                                Label { Layout.fillWidth: true; text: entry.text; color: Theme.textSecondary; textFormat: Text.PlainText; elide: Text.ElideRight }
                                Label { text: "›"; color: Theme.textMuted }
                            }
                            onClicked: root.extensionSettingsRequested(modelData.id)
                        }
                    }
                }

                // AI song metadata.
                AiSettingsPanel {
                    Layout.fillWidth: true
                    visible: root.section === "ai" && root.ai !== null
                    ai: root.ai
                    translator: root.translator
                    connected: root.connected
                }

                // Data location / about.
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.section === "about"
                    spacing: 10
                    TextButton { visible: Boolean(root.databasePath); text: root.t("database"); subtle: true; onClicked: root.showDataLocation = !root.showDataLocation }
                    TextArea {
                        Layout.fillWidth: true
                        visible: root.showDataLocation && Boolean(root.databasePath)
                        text: root.databasePath
                        readOnly: true; selectByMouse: true; wrapMode: TextEdit.WrapAnywhere
                        color: Theme.textMuted; font.pixelSize: Theme.fontCaption
                        background: Rectangle { color: Theme.bgSurface; radius: Theme.radiusSm }
                        Accessible.name: root.t("database")
                    }
                }

                // Keep the deep sections reachable above the floating capsule.
                Item { Layout.fillWidth: true; Layout.preferredHeight: 24 }
            }
        }
    }
}
