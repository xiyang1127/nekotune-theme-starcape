pragma Singleton
import QtQuick
import NekoTune 1.0

// Common tokens are owned by the host; Starcape-only layout dimensions stay in this package.
QtObject {
    property ExtensionApi api: ExtensionApi {}
    readonly property bool isDark: api.theme.isDark
    function artwork(url) {
        return String(url || "").startsWith("qrc:/artwork/default-cover.png")
            ? Qt.resolvedUrl("../../assets/artwork-default.png") : String(url || "")
    }
    readonly property color bgCanvas: api.theme.bgCanvas
    readonly property color bgSidebar: api.theme.bgSidebar
    readonly property color bgSurface: api.theme.bgSurface
    readonly property color bgSurfaceAlt: isDark ? "#171E33" : "#E8EDF7"
    readonly property color bgRaised: api.theme.bgRaised
    readonly property color bgHover: api.theme.bgHover
    readonly property color bgSelected: api.theme.bgSelected
    readonly property color bgCard: api.theme.bgCard
    readonly property color borderSubtle: api.theme.borderSubtle
    readonly property color borderControl: api.theme.borderControl
    readonly property color textPrimary: api.theme.textPrimary
    readonly property color textSecondary: api.theme.textSecondary
    readonly property color textMuted: api.theme.textMuted
    readonly property color textDisabled: api.theme.textDisabled
    readonly property color textOnAccent: api.theme.textOnAccent
    readonly property color accentPrimary: api.theme.accentPrimary
    readonly property color accentHover: api.theme.accentHover
    readonly property color accentPressed: api.theme.accentPressed
    readonly property color accentSecondary: api.theme.accentSecondary
    readonly property color statusSuccess: api.theme.statusSuccess
    readonly property color statusWarning: api.theme.statusWarning
    readonly property color statusError: api.theme.statusError
    readonly property color statusErrorBg: api.theme.statusErrorBg
    readonly property color statusInfo: api.theme.statusInfo
    readonly property color bgCanvasTop: api.theme.bgCanvasTop
    readonly property color bgElevated: api.theme.bgElevated
    readonly property color accentGlow: api.theme.accentGlow
    readonly property color roseGlow: api.theme.roseGlow
    readonly property real glowOpacity: api.theme.glowOpacity
    readonly property string fontFamily: api.theme.fontFamily
    readonly property string fontFamilyMonospace: api.theme.fontFamilyMonospace
    readonly property int fontHero: 26
    readonly property int fontTitle: api.theme.fontTitle
    readonly property int fontSongTitle: api.theme.fontSongTitle
    readonly property int fontDialogTitle: api.theme.fontDialogTitle
    readonly property int fontBody: api.theme.fontBody
    readonly property int fontBodySecondary: api.theme.fontBodySecondary
    readonly property int fontCaption: api.theme.fontCaption
    readonly property int fontLyricsWide: api.theme.fontLyricsWide
    readonly property int fontLyricsCompact: api.theme.fontLyricsCompact
    readonly property real lineHeightBody: api.theme.lineHeightBody
    readonly property real lineHeightLyrics: api.theme.lineHeightLyrics
    readonly property int spaceXs: api.theme.spaceXs
    readonly property int spaceSm: api.theme.spaceSm
    readonly property int spaceMd: api.theme.spaceMd
    readonly property int spaceLg: api.theme.spaceLg
    readonly property int spaceXl: api.theme.spaceXl
    readonly property int space2Xl: api.theme.space2Xl
    readonly property int space3Xl: api.theme.space3Xl
    readonly property int radiusSm: api.theme.radiusSm
    readonly property int radiusMd: api.theme.radiusMd
    readonly property int radiusLg: api.theme.radiusLg
    readonly property int radiusSheet: 20
    readonly property int radiusFull: api.theme.radiusFull
    readonly property int railWidth: 64
    readonly property int railWidthCompact: 56
    readonly property int railIconSize: 40
    readonly property int contentMargin: 32
    readonly property int contentMarginCompact: 20
    readonly property int sidebarWidthWide: api.theme.sidebarWidthWide
    readonly property int sidebarWidthCompact: api.theme.sidebarWidthCompact
    readonly property int bottomBarHeight: api.theme.bottomBarHeight
    readonly property int capsuleMaxWidth: 960
    readonly property int capsuleMargin: 16
    readonly property int sheetWidth: 400
    readonly property int sheetWidthCompact: 340
    readonly property int songRowHeight: api.theme.songRowHeight
    readonly property int songThumbnailSize: api.theme.songThumbnailSize
    readonly property int controlMinHeight: api.theme.controlMinHeight
    readonly property int iconButtonSize: api.theme.iconButtonSize
    readonly property int iconButtonDenseSize: api.theme.iconButtonDenseSize
    readonly property int playButtonSize: api.theme.playButtonSize
    readonly property int artworkCompact: api.theme.artworkCompact
    readonly property int artworkWide: api.theme.artworkWide
    readonly property int gridCardMin: 168
    readonly property int gridCardMinCompact: 132
    readonly property int contentBottomInset: 112
    readonly property bool reducedMotion: api.theme.reducedMotion
    readonly property int durationFast: api.theme.durationFast
    readonly property int durationNormal: api.theme.durationNormal
    readonly property int durationDrawer: api.theme.durationDrawer
    readonly property int durationSmooth: api.theme.durationSmooth
    readonly property int durationScroll: api.theme.durationScroll
}
