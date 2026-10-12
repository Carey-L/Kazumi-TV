import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'dart:async';

import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' as mobx;

import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/bean/widget/loading_indicator.dart';
import 'package:kazumi/bean/widget/media_error_widget.dart';
import 'package:kazumi/modules/download/download_module.dart';
import 'package:kazumi/pages/download/download_controller.dart';
import 'package:kazumi/pages/download/download_episode_sheet.dart';
import 'package:kazumi/pages/history/history_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:kazumi/pages/player/player_item.dart';
import 'package:kazumi/pages/video/episode_selection_panel.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/video/video_playback_args.dart';
import 'package:kazumi/pages/video/video_page_layout.dart';
import 'package:kazumi/pages/video/video_side_panel.dart';
import 'package:kazumi/pages/video/video_system_bars.dart';
import 'package:kazumi/services/player/timed_shutdown_service.dart';
import 'package:kazumi/services/storage/storage.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.args,
    required this.playerController,
    required this.videoPageController,
    required this.historyController,
    required this.downloadController,
  });

  final VideoPlaybackArgs args;
  final PlayerController playerController;
  final VideoPageController videoPageController;
  final HistoryController historyController;
  final DownloadController downloadController;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  PlayerController get playerController => widget.playerController;
  VideoPageController get videoPageController => widget.videoPageController;
  bool _didInitializePlayback = false;
  bool _isExiting = false;
  DateTime? _lastBackHandledAt;
  static const _backDebounceDuration = Duration(milliseconds: 600);
  HistoryController get historyController => widget.historyController;
  DownloadController get downloadController => widget.downloadController;
  late bool playResume;
  bool showDebugLog = false;
  List<String> webviewLogLines = [];
  StreamSubscription<String>? _logSubscription;
  final FocusNode keyboardFocus = FocusNode(
    debugLabel: 'Video player shortcut scope',
  );

  final _episodePanelKey = GlobalKey<EpisodeSelectionPanelState>();
  final _sidePanelKey = GlobalKey<VideoSidePanelState>();
  final playerItemKey = GlobalKey<PlayerItemState>();
  late final bool disableAnimations;

  StreamSubscription<SyncPlayChatMessage>? _syncChatSubscription;

  static const Duration _offlinePlayerInitDelay = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    videoPageController.applyPlaybackArgs(widget.args);

    playResume = GStorage.getSetting(SettingsKeys.playResume);
    disableAnimations = GStorage.getSetting(
      SettingsKeys.playerDisableAnimations,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializePlayback) {
      return;
    }
    _didInitializePlayback = true;
    videoPageController.fullscreen.attach(ModalRoute.of(context)!);
    _initializePlayback();
  }

  void _initializePlayback() {
    if (videoPageController.isOfflineMode) {
      _initOfflineMode();
    } else {
      _initOnlineMode();
    }

    _syncChatSubscription = playerController.syncplay.chatStream.listen((
      event,
    ) {
      final localUsername =
          playerController.syncplay.syncplayController?.username ?? '';
      final String displayText = '${event.username}：${event.message}';

      if (playerController.danmaku.danmakuOn &&
          event.username != localUsername &&
          event.fromRemote) {
        playerController.danmaku.canvasController.addDanmaku(
          DanmakuContentItem(
            displayText,
            color: Colors.orange,
            isColorful: true,
            type: DanmakuItemType.bottom,
            extra: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
    });
  }

  void _initOfflineMode() {
    final identity = videoPageController.currentHistoryIdentity;
    videoPageController.historyOffset = identity == null
        ? 0
        : videoPageController.getHistoryOffsetFor(identity);
    _revealCurrentEpisode();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(_offlinePlayerInitDelay);
      if (!mounted) {
        return;
      }

      await changeEpisode(
        videoPageController.selectedEpisode.episode,
        currentRoad: videoPageController.selectedEpisode.road,
        offset: videoPageController.historyOffset,
      );
    });
  }

  void _initOnlineMode() {
    videoPageController.historyOffset = 0;

    var progress = historyController.lastWatching(
      videoPageController.bangumiItem,
      videoPageController.currentPlugin.name,
    );
    if (progress != null) {
      if (videoPageController.roadList.length > progress.road) {
        if (videoPageController.roadList[progress.road].data.length >=
            progress.episode) {
          videoPageController.resetEpisodeState(
            episode: progress.episode,
            road: progress.road,
          );
          if (playResume) {
            videoPageController.historyOffset = progress.progress.inSeconds;
          }
        }
      }
    }
    _revealCurrentEpisode();

    _logSubscription = videoPageController.logStream.listen((log) {
      if (mounted) {
        setState(() {
          webviewLogLines.add(log);
          if (webviewLogLines.length > 100) {
            webviewLogLines.removeAt(0);
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      changeEpisode(
        videoPageController.selectedEpisode.episode,
        currentRoad: videoPageController.selectedEpisode.road,
        offset: videoPageController.historyOffset,
      );
    });
  }

  @override
  void dispose() {
    try {
      _syncChatSubscription?.cancel();
    } catch (_) {}
    try {
      _logSubscription?.cancel();
    } catch (_) {}
    unawaited(videoPageController.fullscreen.close());
    keyboardFocus.dispose();
    TimedShutdownService().cancel();
    super.dispose();
  }

  void _toggleDebugConsole() {
    setState(() {
      showDebugLog = !showDebugLog;
    });
  }

  /// Back closes transient windows first. During normal playback it then
  /// hides the control panel; loading and error states leave immediately.
  /// The debounce prevents one remote press being delivered through both key
  /// routes.
  Future<void> _handleSystemBack() async {
    final now = DateTime.now();
    if (_isExiting ||
        (_lastBackHandledAt != null &&
            now.difference(_lastBackHandledAt!) < _backDebounceDuration)) {
      return;
    }
    _lastBackHandledAt = now;

    // Menus live in an overlay, so they must be closed before the route pop.
    if (dismissAllOpenMenus()) return;

    // The episode panel is a persistent overlay rather than a route. Close it
    // before changing the player panel or leaving playback.
    if (_sidePanelKey.currentState?.isOpen ?? false) {
      _closeSidePanel();
      return;
    }

    if (playerController.playback.playing &&
        playerController.panel.showVideoController) {
      playerItemKey.currentState?.hideVideoController(force: true);
      return;
    }

    // The player route belongs to the modular outlet, not necessarily to the
    // application's root navigator. Popping the root navigator left an error
    // page stranded when video parsing had failed.
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    setState(() => _isExiting = true);
    playerController.beginShutdown();
    navigator.pop();
  }

  KeyEventResult _handlePageKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.goBack ||
        event.logicalKey == LogicalKeyboardKey.browserBack ||
        event.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(_handleSystemBack());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> changeEpisode(
    int episode, {
    int currentRoad = 0,
    int offset = 0,
  }) async {
    if (!mounted || _isExiting) {
      return;
    }
    setState(() {
      webviewLogLines.clear();
      showDebugLog = false;
    });
    await videoPageController.changeEpisode(
      episode,
      currentRoad: currentRoad,
      offset: offset,
      playerController: playerController,
    );
  }

  void _revealCurrentEpisode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _episodePanelKey.currentState?.revealCurrentEpisode();
    });
  }

  void _toggleSidePanel() => _sidePanelKey.currentState?.toggle();

  void _closeSidePanel() => _sidePanelKey.currentState?.close();

  void _onBackPressed() => unawaited(_handleSystemBack());

  void pauseForTimedShutdown() {
    if (playerController.playback.playing) {
      playerController.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back is handled explicitly: it first dismisses transient UI and only
      // then asks before leaving the player.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Observer(
        builder: (context) {
          final bool isPip = videoPageController.isPip;
          return VideoSystemBars(
            fullscreen: videoPageController.isFullscreen,
            isPip: isPip,
            child: Scaffold(
              body: VideoPageLayout(
                fullscreen: videoPageController.isFullscreen,
                isPip: isPip,
                playerBuilder: (context, layout) => ColoredBox(
                  color: Colors.black,
                  child: Focus(
                    focusNode: keyboardFocus,
                    autofocus: true,
                    onKeyEvent: _handlePageKeyEvent,
                    // Cleanup resets loading while the route is still visible.
                    child: _isExiting
                        ? const SizedBox.expand()
                        : Observer(builder: (_) => _buildPlayerBody(layout)),
                  ),
                ),
                tabs: null,
                sidePanel: VideoSidePanel(
                  key: _sidePanelKey,
                  fullscreen: videoPageController.isFullscreen,
                  disableAnimations: disableAnimations,
                  onOpened: _revealCurrentEpisode,
                  onClosed: () =>
                      playerItemKey.currentState?.focusProgressBar(),
                  child: tabBody,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerBody(VideoPlayerLayout layout) {
    final bool playerLoading = playerController.playback.loading;
    final bool showTopControls =
        playerController.playback.playing &&
        !videoPageController.loading &&
        !playerLoading &&
        videoPageController.errorMessage == null;
    return Stack(
      children: [
        Positioned.fill(
          child: Stack(
            children: [
              if (videoPageController.loading ||
                  playerLoading ||
                  videoPageController.errorMessage != null)
                Container(
                  color: Colors.black,
                  child: Observer(
                    builder: (context) {
                      final errorMessage = videoPageController.errorMessage;
                      if (errorMessage != null) {
                        return MediaErrorWidget(
                          title: '暂时无法播放',
                          errMsg: errorMessage,
                          icon: Icons.videocam_off_outlined,
                        );
                      }
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            LoadingIndicator(
                              color: Theme.of(
                                context,
                              ).colorScheme.tertiaryContainer,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              videoPageController.loading
                                  ? '视频资源解析中'
                                  : '视频资源解析成功, 播放器加载中',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              Visibility(
                visible:
                    (videoPageController.loading || playerLoading) &&
                    showDebugLog,
                child: Container(
                  color: Colors.black,
                  child: Align(
                    alignment: Alignment.center,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: webviewLogLines.length,
                      itemBuilder: (context, index) {
                        return Text(
                          webviewLogLines[index],
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (showTopControls)
                Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: EmbeddedNativeControlArea(
                        requireOffset: !videoPageController.isFullscreen,
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                              ),
                              onPressed: _onBackPressed,
                            ),
                            const Expanded(
                              child: dtb.DragToMoveArea(
                                child: SizedBox(height: 40),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                changeEpisode(
                                  videoPageController.selectedEpisode.episode,
                                  currentRoad:
                                      videoPageController.selectedEpisode.road,
                                );
                              },
                            ),
                            if (layout.hasSidePanel)
                              IconButton(
                                onPressed: _toggleSidePanel,
                                icon: const Icon(
                                  Icons.menu_open_rounded,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Positioned.fill(
          child: playerLoading
              ? const SizedBox.shrink()
              : PlayerItem(
                  key: playerItemKey,
                  fillsWindow: layout.fillsWindow,
                  playerController: playerController,
                  videoPageController: videoPageController,
                  onToggleSidePanel: layout.hasSidePanel
                      ? _toggleSidePanel
                      : null,
                  changeEpisode: changeEpisode,
                  onBackPressed: _onBackPressed,
                  keyboardFocus: keyboardFocus,
                  isPlayerInputBlocked: () =>
                      _sidePanelKey.currentState?.isOpen ?? false,
                  disableAnimations: disableAnimations,
                  pauseForTimedShutdown: pauseForTimedShutdown,
                ),
        ),
      ],
    );
  }

  Widget get episodePanel => Observer(
    builder: (context) {
      final downloads = <String, DownloadEpisode>{};
      if (!videoPageController.isOfflineMode) {
        for (final record in downloadController.records) {
          if (record.bangumiId != videoPageController.bangumiItem.id ||
              record.pluginName != videoPageController.currentPlugin.name) {
            continue;
          }
          for (final episode in record.episodes.values) {
            if (episode.episodePageUrl.isNotEmpty) {
              downloads[episode.episodePageUrl] = episode;
            } else if (episode.road >= 0 &&
                episode.road < videoPageController.roadList.length) {
              // Older records have no URL; only match within their own road.
              final urls = videoPageController.roadList[episode.road].data;
              if (episode.episodeNumber > 0 &&
                  episode.episodeNumber <= urls.length) {
                downloads[urls[episode.episodeNumber - 1]] = episode;
              }
            }
          }
        }
      }
      return EpisodeSelectionPanel(
        key: _episodePanelKey,
        title: videoPageController.title,
        roads: videoPageController.roadList,
        selectedRoad: videoPageController.selectedEpisode.road,
        selectedEpisode: videoPageController.selectedEpisode.episode,
        downloads: downloads,
        isOffline: videoPageController.isOfflineMode,
        isPlaying:
            playerController.playback.playing &&
            !playerController.playback.loading &&
            !videoPageController.loading,
        disableAnimations: disableAnimations,
        onEpisodeSelected: (episode, road) {
          if (episode == videoPageController.selectedEpisode.episode &&
              road == videoPageController.selectedEpisode.road) {
            return;
          }
          _closeSidePanel();
          changeEpisode(episode, currentRoad: road);
        },
        onDownload: (road) => showAdaptiveBottomSheet<void>(
          context: context,
          builder: (context) => DownloadEpisodeSheet(
            road: road,
            videoPageController: videoPageController,
          ),
        ),
      );
    },
  );

  Widget get tabBody {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(color: colors.surface, child: episodePanel);
  }
}
