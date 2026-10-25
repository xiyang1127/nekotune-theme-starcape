#include "support/audio_backend.h"
#include "app_paths.h"
#include "application/library/collection_service.h"
#include "application/playback/player_engine.h"
#include "controllers/app_controllers.h"
#include "extensions/extension_view.h"
#include "i18n.h"
#include "platform/playback_window_controller.h"
#include "runtime/backend_runtime.h"
#include "support/store_fixture.h"
#include "wallpaper/wallpaper_manager.h"
#include <QElapsedTimer>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QLocalSocket>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QSignalSpy>
#include <QScopeGuard>
#include <QStyleHints>
#include <QImage>
#include <QSqlQuery>
#include <QTemporaryDir>
#include <QtTest>
using namespace nekotune;

static QQuickItem *visualItem(QQuickItem *parent, const QString &name) {
    if (parent->objectName() == name)
        return parent;
    for (auto *child : parent->childItems())
        if (auto *found = visualItem(child, name))
            return found;
    return nullptr;
}
static QQuickItem *visibleItem(QQuickItem *parent, const QString &name) {
    if (parent->objectName() == name && parent->isVisible()) return parent;
    for (auto *child : parent->childItems())
        if (auto *found = visibleItem(child, name)) return found;
    return nullptr;
}

class ExtensionAudio final : public TestAudioBackend {
  public:
    QUrl url;
    bool active = false;
    qint64 at = 0;
    void setSource(const QUrl &value) override {
        url = value;
        at = 0;
        active = false;
    }
    QUrl source() const override { return url; }
    void play() override {
        active = true;
        emit stateChanged(PlayerState::Playing);
    }
    void pause() override {
        active = false;
        emit stateChanged(PlayerState::Paused);
    }
    void stop() override {
        active = false;
        at = 0;
        emit stateChanged(PlayerState::Stopped);
    }
    void seek(qint64 value) override { at = value; }
    void setVolume(double) override {}
    qint64 position() const override { return at; }
    qint64 duration() const override { return 8000; }
    double volume() const override { return .8; }
    AudioMetadata metadata() const override { return {}; }
};
class ExtensionPeer {
  public:
    QLocalSocket socket;
    QByteArray buffer;
    QList<QJsonObject> messages;
    int nextId = 0;
    void read() {
        buffer += socket.readAll();
        while (buffer.contains('\n')) {
            auto end = buffer.indexOf('\n');
            messages.append(QJsonDocument::fromJson(buffer.left(end)).object());
            buffer.remove(0, end + 1);
        }
    }
    QJsonObject call(const QString &method, const QJsonObject &params = {}) {
        const auto id = ++nextId;
        socket.write(QJsonDocument(QJsonObject{{"id", id}, {"method", method}, {"params", params}})
                         .toJson(QJsonDocument::Compact) +
                     '\n');
        socket.flush();
        QElapsedTimer timer;
        timer.start();
        while (timer.elapsed() < 15'000) {
            QCoreApplication::processEvents();
            read();
            for (int i = 0; i < messages.size(); ++i)
                if (messages[i].value("id").toInt() == id)
                    return messages.takeAt(i);
            socket.waitForReadyRead(10);
        }
        return {{"status", "timeout"}, {"method", method}};
    }
};
static QStringList qmlWarnings;
static QtMessageHandler previousHandler;
static void collectMessage(QtMsgType type, const QMessageLogContext &context, const QString &message) {
    if (type == QtWarningMsg && (message.startsWith("file:") || message.startsWith("qrc:")
        || message.contains("ReferenceError") || message.contains("TypeError")))
        qmlWarnings.append(message);
    if (previousHandler) previousHandler(type, context, message);
}
class StarcapeWallpaperPlatform final : public WallpaperPlatform {
  public:
    QString unavailableReason() const override { return {}; }
    QString prepare(QWindow *window, QScreen *screen) override {
        window->setScreen(screen);
        window->resize(1280, 800);
        return {};
    }
    QString check(QWindow *, QScreen *) override { return {}; }
};
class StarcapeTest final : public QObject {
    Q_OBJECT
private slots:
    void installedThemeNavigationAndRecovery() {
        QTemporaryDir profile;
        qputenv("NEKOTUNE_HOME", profile.path().toUtf8());
        qputenv("NEKOTUNE_SOCKET", profile.filePath("starcape.sock").toUtf8());
        qputenv("NEKOTUNE_DB_PATH", profile.filePath("starcape.sqlite3").toUtf8());
        QVERIFY(AppPaths::prepare());
        QVERIFY(AppPaths::saveSetting("lyrics_offline", true));
        previousHandler = qInstallMessageHandler(collectMessage);
        auto restore = qScopeGuard([] { qInstallMessageHandler(previousHandler); });
        BackendRuntime runtime([] { return std::make_unique<ExtensionAudio>(); });
        QVERIFY2(runtime.start(), qPrintable(runtime.errorString()));
        ExtensionPeer peer;
        peer.socket.connectToServer(runtime.serverName());
        QVERIFY(peer.socket.waitForConnected(3000));
        QTRY_VERIFY_WITH_TIMEOUT(peer.call("extensions.list").value("data").toObject().value("runtime").toObject().value("ready").toBool(), 15000);
        auto installed = peer.call("extensions.install", {{"path", QStringLiteral(STARCAPE_PACKAGE)}, {"themeOnly", true}});
        QVERIFY2(installed.value("status") == "ok", qPrintable(QString::fromUtf8(QJsonDocument(installed).toJson())));
        IpcClient client;
        AppControllers app(client);
        I18n translator;
        translator.setLanguage("zh");
        QQmlApplicationEngine engine;
        PlaybackWindowController playbackWindows;
        WallpaperManager wallpaper(nullptr, std::make_unique<StarcapeWallpaperPlatform>());
        engine.rootContext()->setContextProperty("controllers", &app);
        engine.rootContext()->setContextProperty("ipcClient", &client);
        engine.rootContext()->setContextProperty("i18n", &translator);
        engine.rootContext()->setContextProperty("lyricsDebugEnabled", false);
        engine.rootContext()->setContextProperty("wallpaperManager", &wallpaper);
        engine.rootContext()->setContextProperty("playbackWindows", &playbackWindows);
        wallpaper.initialize(&engine, &client);
        engine.load(QUrl("qrc:/qml/Main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        QVERIFY(window);
        playbackWindows.initialize(&engine, window);
        auto closeWindows = qScopeGuard([&] {
            wallpaper.shutdown();
            playbackWindows.shutdown();
            delete window;
        });
        window->resize(1360, 860);
        window->show();
        client.connectBackend();
        QTRY_COMPARE(app.theme->items().size(), 4);
        QVERIFY(!visualItem(window->contentItem(), "starcapeShell"));
        QSignalSpy trust(app.theme, &ThemeController::trustRequested);
        app.theme->selectTheme("nekotune.theme-starcape/default");
        QCOMPARE(trust.size(), 1);
        app.theme->selectTheme("nekotune.theme-starcape/default", true);
        QTRY_COMPARE(app.theme->activeId(), "nekotune.theme-starcape/default");
        auto *slot = window->findChild<QObject *>("shellExtensionTheme");
        QVERIFY(slot);
        QTRY_VERIFY2(slot->property("ready").toBool(), qPrintable(slot->property("error").toString()));
        QPointer<QQuickItem> shell = visualItem(window->contentItem(), "starcapeShell");
        QVERIFY(shell);
        auto navigate = [&](const QString &id) {
            QMetaObject::invokeMethod(window, "navigateTo", Q_ARG(QVariant, id), Q_ARG(QVariant, 0));
            QCoreApplication::processEvents();
        };
        auto capture = [&](const QString &name) {
            const auto directory = qEnvironmentVariable("NEKOTUNE_TEST_SCREENSHOT_DIR");
            if (directory.isEmpty()) return true;
            QDir().mkpath(directory);
            QTest::qWait(250);
            return window->grabWindow().save(directory + '/' + name + ".png");
        };
        auto click = [&](const QString &name) {
            auto *item = visualItem(shell, name);
            if (!item || !item->isVisible()) return false;
            // Scroll settings and home controls into their clipped viewport before clicking.
            for (auto *ancestor = item->parentItem(); ancestor; ancestor = ancestor->parentItem()) {
                if (ancestor->metaObject()->indexOfProperty("contentY") < 0) continue;
                const auto y = item->mapToItem(ancestor, QPointF()).y();
                if (y < 0 || y + item->height() > ancestor->height()) {
                    ancestor->setProperty("contentY", ancestor->property("contentY").toReal()
                        + y - std::max(0.0, (ancestor->height() - item->height()) / 2));
                    QTest::qWait(100);
                }
            }
            QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier,
                             item->mapToScene(QPointF(item->width()/2, item->height()/2)).toPoint());
            return true;
        };
        QVERIFY(capture("starcape-dark-home-empty-zh"));
        auto *home = visualItem(shell, "starcapeHomePage");
        QVERIFY(home);
        auto *recentPicker = visualItem(shell, "homeRecentPicker");
        QVERIFY(recentPicker);
        recentPicker->forceActiveFocus();
        QTest::keyClick(window, Qt::Key_End);
        QCOMPARE(home->property("recentView").toString(), "played");
        QVERIFY(visibleItem(shell, "homeLibraryState"));
        const auto librarySnapshot = app.library->songs()->items();
        const QVariantMap first{{"song_id", 101}, {"title", "Earlier played"}, {"available", false},
            {"last_played_at", "2026-10-18T12:00:00Z"}};
        const QVariantMap second{{"song_id", 102}, {"title", "Latest played"}, {"available", false},
            {"last_played_at", "2026-10-19T12:00:00Z"}};
        const QVariantMap unplayed{{"song_id", 103}, {"title", "Unplayed"}, {"available", false},
            {"last_played_at", "invalid"}};
        app.library->songs()->update({unplayed});
        QTRY_VERIFY(home->property("recentSongs").toList().isEmpty());
        QCOMPARE(visibleItem(shell, "homeLibraryState")->property("text").toString(),
            translator.text("home_empty_recent_played", "zh"));
        app.library->songs()->update({first, second, unplayed});
        QTRY_COMPARE(home->property("recentSongs").toList().size(), 2);
        QCOMPARE(home->property("recentSongs").toList().first().toMap().value("song_id").toInt(), 102);
        QCOMPARE(app.library->songs()->items(), QVariantList({first, second, unplayed}));
        recentPicker->forceActiveFocus();
        QTest::keyClick(window, Qt::Key_Home);
        QCOMPARE(home->property("recentView").toString(), "added");
        QCOMPARE(home->property("recentSongs").toList().first().toMap().value("song_id").toInt(), 103);
        app.library->songs()->update(librarySnapshot);
        QTRY_VERIFY(!app.history->stats().value("days").toList().isEmpty());
        QVERIFY(visualItem(shell, "homeListeningHeatmap"));
        QVERIFY(click("homeHistoryButton"));
        QTRY_COMPARE(window->property("viewMode").toString(), "history");
        QTRY_VERIFY(visibleItem(shell, "historyList"));
        QVERIFY(visibleItem(shell, "historySearch"));
        QVERIFY(visibleItem(shell, "historyCompleted"));
        QVERIFY(capture("starcape-dark-history-zh"));
        QVERIFY(click("nav_home"));
        QVERIFY(visibleItem(shell, "nav_history"));
        QVERIFY(click("homeNewPlaylistButton"));
        QTRY_VERIFY(visibleItem(window->contentItem(), "playlistNameInput"));
        auto *playlistName = visibleItem(window->contentItem(), "playlistNameInput");
        playlistName->setProperty("text", "Starcape Radio");
        auto *savePlaylist = visibleItem(window->contentItem(), "savePlaylistButton");
        QVERIFY(savePlaylist);
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier,
                         savePlaylist->mapToScene(QPointF(savePlaylist->width()/2, savePlaylist->height()/2)).toPoint());
        QTRY_COMPARE(app.playlists->model()->count(), 1);
        QTRY_COMPARE(window->property("viewMode").toString(), "queue");
        QVERIFY(capture("starcape-dark-playlist-zh"));
        QVERIFY(click("nav_library"));
        QCOMPARE(window->property("viewMode").toString(), "library");
        QTest::keyClick(window, Qt::Key_F, Qt::ControlModifier);
        auto *focus = window->activeFocusItem();
        QVERIFY(focus);
        bool themeFocus = false;
        for (auto *item = focus; item; item = item->parentItem()) if (item == shell) themeFocus = true;
        QVERIFY(themeFocus);
        QSignalSpy recovery(app.extensions, &ExtensionsController::managerRequested);
        QTest::keyClick(window, Qt::Key_E, Qt::ControlModifier | Qt::ShiftModifier);
        QCOMPARE(recovery.size(), 1);
        QVERIFY(capture("starcape-dark-library-empty-zh"));
        QVERIFY(click("nav_settings"));
        QTRY_VERIFY(visibleItem(shell, "settingsSection_engine"));
        QVERIFY(click("settingsSection_engine"));
        QTRY_VERIFY(visibleItem(shell, "audioEngineSettings"));
        QVERIFY(visibleItem(shell, "audioEqualizerEnabled"));
        QVERIFY(visibleItem(shell, "audioReplayGainMode"));
        QVERIFY(visibleItem(shell, "audioCrossfadeSlider"));
        QVERIFY(capture("starcape-dark-audio-engine-zh"));
        QVERIFY(click("settingsSection_storage"));
        QTRY_VERIFY(visibleItem(shell, "storageBackup"));
        QVERIFY(visibleItem(shell, "storageRestore"));
        QVERIFY(visibleItem(shell, "storageMigrate"));
        QVERIFY(visibleItem(shell, "storageVerify"));
        QVERIFY(capture("starcape-dark-storage-zh"));
        QVERIFY(click("settingsSection_windows"));
        QTRY_VERIFY(visibleItem(shell, "settingsMiniModeButton"));
        QTest::qWait(100);
        QVERIFY(click("miniAlwaysOnTopCheckBox"));
        QTRY_VERIFY(playbackWindows.miniAlwaysOnTop());
        QVERIFY(visibleItem(shell, "desktopLyricsCheckBox"));
        QVERIFY(capture("starcape-dark-window-settings-zh"));
        QVERIFY(click("settingsMiniModeButton"));
        QTRY_VERIFY(playbackWindows.miniMode());
        playbackWindows.showMainWindow();
        QTRY_VERIFY(!playbackWindows.miniMode());
        window->requestActivate();
        QTRY_VERIFY(window->isActive());
        QVERIFY(click("settingsSection_audio"));
        QTest::qWait(100);
        auto *rateButton = visibleItem(shell, "playbackRateButton");
        QVERIFY(rateButton);
        QVERIFY(click("playbackRateButton"));
        QTRY_VERIFY(visibleItem(window->contentItem(), "playbackRate_1.25"));
        auto *rateChoice = visibleItem(window->contentItem(), "playbackRate_1.25");
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier,
            rateChoice->mapToScene(QPointF(rateChoice->width()/2, rateChoice->height()/2)).toPoint());
        QTRY_COMPARE(app.playback->playbackRate(), 1.25);
        QVERIFY(click("resetPlaybackRateButton"));
        QTRY_COMPARE(app.playback->playbackRate(), 1.0);
        QVERIFY(click("appearanceSettingsButton"));
        QCOMPARE(window->property("settingsSection").toString(), "appearance");
        QTRY_VERIFY(visualItem(shell, "themeModePicker"));
        QVERIFY(capture("starcape-dark-appearance-zh"));
        app.theme->setMode("light");
        QCOMPARE(visualItem(window->contentItem(), "starcapeShell"), shell.data());
        QCOMPARE(window->color(), QColor("#F4F6FB"));
        translator.setLanguage("en");
        QVERIFY(capture("starcape-light-appearance-en"));
        navigate("settings");
        QVERIFY(capture("starcape-light-settings-en"));
        // Exercise actual queue/playback IPC with a local valid WAV and deterministic audio backend.
        QFile audio(profile.filePath("Starcape Signal.wav"));
        QVERIFY(audio.open(QIODevice::WriteOnly));
        QDataStream stream(&audio); stream.setByteOrder(QDataStream::LittleEndian);
        audio.write("RIFF", 4); stream << quint32(36 + 16000); audio.write("WAVEfmt ", 8);
        stream << quint32(16) << quint16(1) << quint16(1) << quint32(8000) << quint32(16000) << quint16(2) << quint16(16);
        audio.write("data", 4); stream << quint32(16000); audio.write(QByteArray(16000, '\0')); audio.close();
        QCOMPARE(peer.call("library.import", {{"path", audio.fileName()}}).value("status").toString(), "ok");
        QTRY_COMPARE(app.library->songs()->count(), 1);
        QCOMPARE(peer.call("queue.add", {{"path", audio.fileName()}}).value("status").toString(), "ok");
        QTRY_COMPARE(app.queue->model()->count(), 1);
        QVERIFY(click("mainPlayButton"));
        QTRY_COMPARE(app.playback->state(), "playing");
        QVERIFY(!wallpaper.requestedEnabled());
        QVERIFY(click("settingsSection_wallpaper"));
        QTRY_VERIFY(visibleItem(shell, "starcapeWallpaperSettings"));
        QTest::qWait(100); // Polish the newly selected section before clicking its controls.
        auto *stylePicker = visibleItem(shell, "wallpaperStyle");
        QVERIFY(stylePicker);
        stylePicker->forceActiveFocus();
        QTest::keyClick(window, Qt::Key_End);
        QTRY_COMPARE(wallpaper.settings().value("style").toString(), "theme");
        QVERIFY(click("wallpaperEnabled"));
        QTRY_VERIFY(wallpaper.requestedEnabled());
        QTRY_COMPARE(wallpaper.runningCount(), 1);
        auto *wallpaperWindow = wallpaper.findChild<QQuickWindow *>("musicWallpaperWindow");
        QVERIFY(wallpaperWindow);
        QTRY_COMPARE(wallpaperWindow->property("themeStatus").toString(), "active");
        auto *wallpaperView = wallpaperWindow->findChild<ExtensionView *>("wallpaperThemeSlotTheme");
        QVERIFY(wallpaperView && wallpaperView->ready());
        auto *wallpaperItem = wallpaperView->item();
        QCOMPARE(wallpaperItem->objectName(), "starcapeWallpaper");
        QVERIFY(wallpaperItem->property("motionAllowed").toBool());
        QPointer<QQuickItem> closedWallpaper = wallpaperItem;
        QVERIFY(wallpaper.setOption("enabled", false));
        QVERIFY(closedWallpaper.isNull());
        QCOMPARE(app.playback->state(), "playing");
        QVERIFY(wallpaper.setOption("enabled", true));
        QTRY_COMPARE(wallpaper.runningCount(), 1);
        wallpaperWindow = wallpaper.findChild<QQuickWindow *>("musicWallpaperWindow");
        QVERIFY(wallpaperWindow);
        QTRY_COMPARE(wallpaperWindow->property("themeStatus").toString(), "active");
        wallpaperView = wallpaperWindow->findChild<ExtensionView *>("wallpaperThemeSlotTheme");
        QVERIFY(wallpaperView && wallpaperView->ready());
        wallpaperItem = wallpaperView->item();
        QVERIFY(wallpaper.setOption("transparent", false));
        const auto wallpaperNativeId = wallpaperWindow->winId();
        QVERIFY(capture("starcape-wallpaper-settings-en"));
        for (const auto size : {QSize(1280, 800), QSize(720, 1280), QSize(360, 240)}) {
            wallpaperWindow->resize(size);
            QTest::qWait(100);
            auto *content = wallpaperItem->findChild<QQuickItem *>("starcapeWallpaperContent");
            QVERIFY(content);
            const auto bounds = content->mapRectToScene(content->boundingRect());
            QVERIFY2(bounds.left() >= 0 && bounds.top() >= 0 && bounds.right() <= size.width()
                     && bounds.bottom() <= size.height(), qPrintable(QString("%1x%2: %3,%4 %5x%6")
                         .arg(size.width()).arg(size.height()).arg(bounds.x()).arg(bounds.y())
                         .arg(bounds.width()).arg(bounds.height())));
            const auto directory = qEnvironmentVariable("NEKOTUNE_TEST_SCREENSHOT_DIR");
            if (!directory.isEmpty())
                QVERIFY(wallpaperWindow->grabWindow().save(directory + QString("/starcape-wallpaper-%1x%2.png")
                    .arg(size.width()).arg(size.height())));
        }
        wallpaperWindow->resize(1280, 800);
        app.playback->togglePlayPause();
        QTRY_COMPARE(app.playback->state(), "paused");
        QVERIFY(!wallpaperItem->property("motionAllowed").toBool());
        app.playback->togglePlayPause();
        QTRY_COMPARE(app.playback->state(), "playing");
        QTRY_VERIFY(wallpaperItem->property("motionAllowed").toBool());
        QVERIFY(wallpaper.setOption("intensity", 0.0));
        QVERIFY(!wallpaperItem->property("motionAllowed").toBool());
        QVERIFY(wallpaper.setOption("intensity", 0.35));
        QVERIFY(wallpaper.setOption("lyrics", false));
        auto *wallpaperLyrics = wallpaperItem->findChild<QQuickItem *>("starcapeWallpaperLyrics");
        QVERIFY(wallpaperLyrics && !wallpaperLyrics->isVisible());
        QVERIFY(wallpaper.setOption("lyrics", true));
        navigate("home");
        window->requestActivate();
        QTRY_VERIFY(window->isActive());
        auto *recentRow = visualItem(shell, "homeRecentSong" + QString::number(app.library->songs()->get(0).value("song_id").toInt()));
        QVERIFY(recentRow);
        QCOMPARE(recentRow->property("menuActions").toList().size(), 2);
        auto *moreButton = visualItem(recentRow, "trackMoreButton");
        QVERIFY(moreButton);
        QTest::qWait(100);
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier,
            moreButton->mapToScene(QPointF(moreButton->width()/2, moreButton->height()/2)).toPoint());
        QTRY_VERIFY(visibleItem(window->contentItem(), "menu_queue"));
        auto *addQueue = visibleItem(window->contentItem(), "menu_queue");
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier,
            addQueue->mapToScene(QPointF(addQueue->width()/2, addQueue->height()/2)).toPoint());
        QTRY_COMPARE(app.queue->model()->count(), 2);
        home->setProperty("contentY", 0);
        QVERIFY(capture("starcape-light-home-en"));
        QVERIFY(click("homeHistoryButton"));
        QTRY_COMPARE(window->property("viewMode").toString(), "history");
        app.history->refresh();
        QTRY_VERIFY(app.history->total() > 0);
        QVERIFY(capture("starcape-light-history-en"));
        navigate("library");
        QVERIFY(capture("starcape-light-library-en"));
        QVERIFY(click("libraryViewToggleButton"));
        QTRY_VERIFY(visibleItem(shell, "librarySongGrid"));
        QVERIFY(capture("starcape-light-library-grid-en"));
        QVERIFY(click("queueToggleButton"));
        QVERIFY(window->property("queueOpen").toBool());
        QVERIFY(capture("starcape-light-queue-en"));
        window->requestActivate();
        QTRY_VERIFY(window->isActive());
        QTest::keyClick(window, Qt::Key_Escape);
        QVERIFY(!window->property("queueOpen").toBool());
        app.theme->setMode("dark");
        translator.setLanguage("zh");
        QTest::qWait(100);
        if (const auto directory = qEnvironmentVariable("NEKOTUNE_TEST_SCREENSHOT_DIR"); !directory.isEmpty())
            QVERIFY(wallpaperWindow->grabWindow().save(directory + "/starcape-wallpaper-dark.png"));
        window->resize(1000, 640);
        navigate("home");
        QVERIFY(capture("starcape-dark-home-narrow-zh"));
        navigate("settings");
        QVERIFY(click("settingsSection_storage"));
        QTest::qWait(100);
        QVERIFY(capture("starcape-dark-settings-narrow-zh"));
        QVERIFY(click("settingsSection_about"));
        QVERIFY(click("appearanceSettingsButton"));
        QTRY_COMPARE(window->property("settingsSection").toString(), "appearance");
        navigate("home");
        QVERIFY(click("nowPlayingButton"));
        QVERIFY(window->property("nowPlayingOpen").toBool());
        QVERIFY(capture("starcape-dark-lyrics-narrow-zh"));
        const auto song = app.playback->song();
        const auto queue = app.queue->model()->items();
        window->setProperty("nowPlayingOpen", false);
        window->resize(1360, 860);
        navigate("appearance");
        const QString themeId = "nekotune.theme-starcape/default";
        QTRY_VERIFY(visibleItem(shell, "updateTheme_" + themeId));
        QTRY_VERIFY(visibleItem(shell, "reloadTheme_" + themeId));
        QPointer<QQuickItem> oldShell = shell;
        QPointer<QQuickItem> oldWallpaper = wallpaperView->item();
        QVERIFY(click("reloadTheme_" + themeId));
        QTRY_VERIFY(oldShell.isNull());
        QTRY_VERIFY(oldWallpaper.isNull());
        QTRY_VERIFY(wallpaperView->ready());
        QCOMPARE(wallpaperWindow->winId(), wallpaperNativeId);
        QTRY_VERIFY(!app.theme->busy());
        QTRY_VERIFY(visualItem(window->contentItem(), "starcapeShell"));
        shell = visualItem(window->contentItem(), "starcapeShell");
        QCOMPARE(app.theme->notice(), "theme_reloaded");
        QCOMPARE(app.theme->selectedId(), themeId);
        QCOMPARE(app.theme->mode(), "dark");
        QCOMPARE(app.playback->state(), "playing");
        QCOMPARE(app.playback->song(), song);
        QCOMPARE(app.queue->model()->items(), queue);
        QVERIFY(capture("starcape-reloaded-appearance-zh"));
        QSignalSpy replace(app.theme, &ThemeController::replaceRequested);
        app.theme->updateTheme(themeId, QStringLiteral(STARCAPE_PACKAGE));
        QTRY_COMPARE(replace.size(), 1);
        QCOMPARE(replace.first().at(1).toString(), themeId);
        QCOMPARE(visualItem(window->contentItem(), "starcapeShell"), shell.data());
        QVERIFY(capture("starcape-update-confirm-zh"));
        auto *message = visibleItem(window->contentItem(), "themeReplaceMessage");
        QVERIFY(message);
        QObject *replaceDialog = nullptr;
        for (auto *context = qmlContext(message); context && !replaceDialog;
             context = context->parentContext())
            replaceDialog = context->objectForName("replaceDialog");
        QVERIFY(replaceDialog);
        QTRY_VERIFY(replaceDialog->property("opened").toBool());
        // Cancel preserves the shell. Retrying with confirmation replaces its package.
        QVERIFY(QMetaObject::invokeMethod(replaceDialog, "reject"));
        QTRY_VERIFY(!replaceDialog->property("visible").toBool());
        app.theme->updateTheme(themeId, QStringLiteral(STARCAPE_PACKAGE));
        QTRY_COMPARE(replace.size(), 2);
        QTRY_VERIFY(replaceDialog->property("opened").toBool());
        oldShell = shell;
        QVERIFY(QMetaObject::invokeMethod(replaceDialog, "accept"));
        QTRY_VERIFY(oldShell.isNull());
        QTRY_VERIFY(!app.theme->busy());
        QTRY_VERIFY(visualItem(window->contentItem(), "starcapeShell"));
        shell = visualItem(window->contentItem(), "starcapeShell");
        QVERIFY2(app.theme->error().isEmpty(), qPrintable(app.theme->error()));
        QCOMPARE(app.theme->notice(), "theme_updated");
        QCOMPARE(app.theme->selectedId(), themeId);
        QCOMPARE(app.theme->mode(), "dark");
        QCOMPARE(app.playback->state(), "playing");
        QCOMPARE(app.playback->song(), song);
        QCOMPARE(app.queue->model()->items(), queue);
        for (int i = 0; i < 3; ++i) {
            QPointer<QQuickItem> previous = shell;
            app.theme->selectTheme("builtin/ocean");
            QTRY_VERIFY(previous.isNull());
            app.theme->selectTheme("nekotune.theme-starcape/default");
            QTRY_VERIFY(visualItem(window->contentItem(), "starcapeShell"));
            shell = visualItem(window->contentItem(), "starcapeShell");
        }
        QCOMPARE(app.playback->state(), "playing");
        QCOMPARE(app.playback->song(), song);
        QCOMPARE(app.queue->model()->items(), queue);
        navigate("appearance");
        QTRY_VERIFY(visibleItem(shell, "resetThemeButton"));
        QVERIFY(click("resetThemeButton"));
        QTRY_COMPARE(app.theme->activeId(), "builtin/yozakura");
        QTRY_VERIFY(shell.isNull());
        QTRY_COMPARE(wallpaperWindow->property("themeStatus").toString(), "missing");
        QCOMPARE(wallpaperWindow->winId(), wallpaperNativeId);
        QVERIFY(wallpaper.setOption("enabled", false));
        QCOMPARE(app.playback->state(), "playing");
        peer.read();
        QVERIFY(std::none_of(peer.messages.cbegin(), peer.messages.cend(), [](const QJsonObject &message) {
            return message.value("event") == "extensions.process";
        }));
        QVERIFY2(qmlWarnings.isEmpty(), qPrintable(qmlWarnings.join('\n')));
        window->close();
        peer.socket.abort();
        runtime.stop();
    }
};
QTEST_MAIN(StarcapeTest)
#include "integration_test.moc"
