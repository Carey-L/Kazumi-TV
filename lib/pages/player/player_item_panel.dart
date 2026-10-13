import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart' as mobx;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kazumi/bean/widget/kazumi_menu.dart';
import 'package:kazumi/pages/player/player_adjustment_hud.dart';
import 'package:kazumi/pages/player/controller/player_aspect_ratio.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/pages/player/player_panel_hold.dart';
import 'package:kazumi/pages/video/video_controller.dart';
import 'package:kazumi/pages/player/player_controller.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/pages/settings/danmaku/danmaku_settings_sheet.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:kazumi/utils/format.dart';
import 'package:kazumi/pages/player/player_transport_bar.dart';
import 'package:kazumi/pages/player/player_screenshot_controls.dart';

class PlayerItemPanel extends StatefulWidget {
  const PlayerItemPanel({
    super.key,
    required this.playerController,
    required this.videoPageController,
    required this.fillsWindow,
    required this.onBackPressed,
    required this.setPlaybackSpeed,
    required this.showDanmakuSwitch,
    required this.handleFullscreen,
    required this.enterAndroidPictureInPicture,
    required this.handleScreenShot,
    required this.showScreenshotCandidates,
    required this.onNextEpisode,
    required this.handleProgressBarDragStart,
    required this.handleProgressBarSeek,
    required this.handleSuperResolutionChange,
    required this.panelVisibilityController,
    this.onToggleSidePanel,
    required this.keyboardFocus,
    required this.acquirePlayerPanelHold,
    required this.onMenuVisibilityChanged,
    required this.handleDanmaku,
    required this.skipOP,
    required this.showVideoInfo,
    required this.showSyncPlayPanel,
    required this.pauseForTimedShutdown,
    this.disableAnimations = false,
  });

  final PlayerController playerController;
  final VideoPageController videoPageController;
  final bool fillsWindow;
  final VoidCallback onBackPressed;
  final Future<void> Function(double) setPlaybackSpeed;
  final VoidCallback showDanmakuSwitch;
  final VoidCallback? onToggleSidePanel;
  final VoidCallback handleFullscreen;
  final Future<void> Function() enterAndroidPictureInPicture;
  final VoidCallback handleScreenShot;
  final VoidCallback showScreenshotCandidates;
  final VoidCallback handleProgressBarDragStart;
  final Future<void> Function(Duration duration) handleProgressBarSeek;
  final Future<void> Function(SuperResolutionMode mode)
  handleSuperResolutionChange;
  final AnimationController panelVisibilityController;
  final FocusNode keyboardFocus;
  final PlayerPanelHold Function() acquirePlayerPanelHold;
  final ValueChanged<bool> onMenuVisibilityChanged;
  final VoidCallback handleDanmaku;
  final VoidCallback onNextEpisode;
  final VoidCallback skipOP;
  final VoidCallback showVideoInfo;
  final VoidCallback showSyncPlayPanel;
  final VoidCallback pauseForTimedShutdown;
  final bool disableAnimations;

  @override
  State<PlayerItemPanel> createState() => PlayerItemPanelState();
}

class PlayerItemPanelState extends State<PlayerItemPanel> {
  late final Animation<Offset> _topOffsetAnimation;
  late final Animation<Offset> _bottomOffsetAnimation;
  late final Animation<Offset> _rightOffsetAnimation;
  late final VideoPageController videoPageController =
      widget.videoPageController;
  late final PlayerController playerController;
  final FocusNode _progressFocus = FocusNode(debugLabel: 'PlayerProgressBar');
  late final FocusNode _nextEpisodeFocus = FocusNode(
    debugLabel: 'PlayerNextEpisode',
    onKeyEvent: _handleNextEpisodeKey,
  );
  late final FocusNode _danmakuToggleFocus = FocusNode(
    debugLabel: 'PlayerDanmakuToggle',
    onKeyEvent: _handleDanmakuToggleKey,
  );
  late final FocusNode _danmakuSettingsFocus = FocusNode(
    debugLabel: 'PlayerDanmakuSettings',
    onKeyEvent: _handleDanmakuSettingsKey,
  );
  late final FocusNode _speedFocus = FocusNode(
    debugLabel: 'PlayerSpeed',
    onKeyEvent: _handleSpeedKey,
  );
  late final FocusNode _aspectRatioFocus = FocusNode(
    debugLabel: 'PlayerAspectRatio',
    onKeyEvent: _handleAspectRatioKey,
  );
  late final mobx.ReactionDisposer _panelRevealReaction;

  String? _cachedDanmakuColorHex;
  late Widget _cachedDanmakuOnIcon;
  late final Widget _cachedDanmakuOffIcon;
  late final Widget _cachedDanmakuSettingsIcon;

  bool get _desktop => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    _ => false,
  };

  static const double _danmakuIconSize = 48.0;
  static const double _loadingIndicatorStrokeWidth = 3.0;

  bool get isProgressFocused => _progressFocus.hasFocus;

  void focusProgressBar() => _progressFocus.requestFocus();

  @override
  void dispose() {
    _panelRevealReaction();
    _progressFocus.dispose();
    _nextEpisodeFocus.dispose();
    _danmakuToggleFocus.dispose();
    _danmakuSettingsFocus.dispose();
    _speedFocus.dispose();
    _aspectRatioFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    playerController = widget.playerController;
    final visibility = widget.panelVisibilityController.drive(
      CurveTween(curve: Curves.easeInOut),
    );
    _topOffsetAnimation = visibility.drive(
      Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero),
    );
    _bottomOffsetAnimation = visibility.drive(
      Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
    );
    _rightOffsetAnimation = visibility.drive(
      Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero),
    );
    _cachedDanmakuOffIcon = RepaintBoundary(
      child: SvgPicture.asset(
        'assets/images/danmaku_off.svg',
        height: _danmakuIconSize,
      ),
    );

    _cachedDanmakuSettingsIcon = RepaintBoundary(
      child: SvgPicture.asset(
        'assets/images/danmaku_setting.svg',
        height: _danmakuIconSize,
      ),
    );

    _panelRevealReaction = mobx.reaction<bool>(
      (_) => playerController.panel.showVideoController,
      (visible) {
        // Revealing the panel is not enough on a remote: while the video
        // surface keeps focus the D-pad never reaches these controls. Hand
        // focus over as soon as the panel appears.
        if (!visible || !mounted) return;
        if (!widget.keyboardFocus.hasFocus) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !playerController.panel.showVideoController) return;
          if (!widget.keyboardFocus.hasFocus) return;
          _progressFocus.requestFocus();
        });
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !playerController.panel.showVideoController ||
          !widget.keyboardFocus.hasFocus) {
        return;
      }
      _progressFocus.requestFocus();
    });
  }

  Widget _danmakuOnIcon(BuildContext context) {
    final colorHex = Theme.of(
      context,
    ).colorScheme.primary.toARGB32().toRadixString(16).substring(2);

    if (_cachedDanmakuColorHex != colorHex) {
      _cachedDanmakuColorHex = colorHex;
      final svgString = danmakuOnSvg.replaceFirst('00AEEC', colorHex);
      _cachedDanmakuOnIcon = RepaintBoundary(
        child: SvgPicture.string(svgString, height: _danmakuIconSize),
      );
    }

    return _cachedDanmakuOnIcon;
  }

  Widget _buildDanmakuToggleButton(BuildContext context) {
    return Observer(
      builder: (context) {
        final danmakuLoading = playerController.danmaku.danmakuLoading;
        final danmakuOn = playerController.danmaku.danmakuOn;
        return IconButton(
          focusNode: _danmakuToggleFocus,
          color: Colors.white,
          icon: danmakuLoading
              ? SizedBox(
                  width: _danmakuIconSize,
                  height: _danmakuIconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: _loadingIndicatorStrokeWidth,
                  ),
                )
              : (danmakuOn ? _danmakuOnIcon(context) : _cachedDanmakuOffIcon),
          onPressed: danmakuLoading ? null : widget.handleDanmaku,
          tooltip: danmakuLoading ? '弹幕加载中...' : (danmakuOn ? '关闭弹幕' : '打开弹幕'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => IconTheme(
      // Doubles every control glyph at once; individual IconButtons keep their
      // default sizing.
      data: IconTheme.of(context).copyWith(size: 48),
      child: _buildPanel(
        constraints.maxWidth < MediaQuery.textScalerOf(context).scale(600),
      ),
    ),
  );

  Widget _buildPanel(bool compact) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildScrim(
            height: 100,
            colors: const [Colors.black45, Colors.transparent],
            offset: _topOffsetAnimation,
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildScrim(
            height: 200,
            colors: const [Colors.transparent, Colors.black45],
            offset: _bottomOffsetAnimation,
          ),
        ),
        Positioned(
          top: 25,
          child: Observer(
            builder: (context) {
              // Hidden HUDs must not observe playback ticks.
              final visible = playerController.panel.showSeekTime;
              return PlayerSeekHud(
                visible: visible,
                currentPosition: visible
                    ? playerController.playback.currentPosition
                    : Duration.zero,
                playerPosition: visible
                    ? playerController.playback.playerPosition
                    : Duration.zero,
                duration: visible
                    ? playerController.playback.duration
                    : Duration.zero,
                direction: playerController.panel.seekDirection,
                cancelPending: playerController.panel.seekCancelPending,
                disableAnimations: widget.disableAnimations,
              );
            },
          ),
        ),
        Positioned(
          top: 25,
          child: Observer(
            builder: (context) {
              return PlayerSpeedHud(
                visible: playerController.panel.showPlaySpeed,
                speed: playerController.playback.playerSpeed,
                disableAnimations: widget.disableAnimations,
              );
            },
          ),
        ),
        if (!_desktop)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Observer(
              builder: (context) {
                if ((compact || !widget.fillsWindow) &&
                    !playerController.panel.lockPanel) {
                  return const SizedBox.shrink();
                }
                return Visibility(
                  visible: widget.disableAnimations
                      ? playerController.panel.showVideoController
                      : true,
                  child: widget.disableAnimations
                      ? _rightControls
                      : SlideTransition(
                          position: _rightOffsetAnimation,
                          child: _rightControls,
                        ),
                );
              },
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Observer(
            builder: (context) {
              return Visibility(
                visible:
                    !playerController.panel.lockPanel &&
                    (widget.disableAnimations
                        ? playerController.panel.showVideoController
                        : true),
                child: widget.disableAnimations
                    ? _buildTopControls(compact)
                    : SlideTransition(
                        position: _topOffsetAnimation,
                        child: _buildTopControls(compact),
                      ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Observer(
            builder: (context) {
              return Visibility(
                visible:
                    !playerController.panel.lockPanel &&
                    (widget.disableAnimations
                        ? playerController.panel.showVideoController
                        : true),
                child: widget.disableAnimations
                    ? _buildBottomControls(compact)
                    : SlideTransition(
                        position: _bottomOffsetAnimation,
                        child: _buildBottomControls(compact),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScrim({
    required double height,
    required List<Color> colors,
    required Animation<Offset> offset,
  }) => Observer(
    builder: (context) {
      final scrim = Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
        ),
      );
      return Visibility(
        visible:
            !playerController.panel.lockPanel &&
            (!widget.disableAnimations ||
                playerController.panel.showVideoController),
        child: widget.disableAnimations
            ? scrim
            : SlideTransition(position: offset, child: scrim),
      );
    },
  );

  void _showDanmakuSettings() {
    showDanmakuSettingsSheet(
      context: context,
      danmakuController: playerController.danmaku.canvasController,
      onUpdateDanmakuSpeed: playerController.updateDanmakuSpeed,
      onTimelineOffsetChanged:
          playerController.danmaku.clearAndInvalidateScheduledDanmakus,
    );
  }

  List<Widget> _choiceItems<T>(
    Iterable<T> values, {
    required String Function(T) label,
    required bool Function(T) selected,
    required void Function(T) onSelected,
  }) => [
    for (final value in values)
      KazumiMenuItem(
        onPressed: () => onSelected(value),
        label: label(value),
        selected: selected(value),
      ),
  ];

  List<Widget> get _aspectRatioItems => _choiceItems(
    PlayerAspectRatio.values,
    label: (value) => value.label,
    selected: (value) => value == playerController.panel.aspectRatioMode,
    onSelected: (value) => playerController.panel.aspectRatioMode = value,
  );

  List<Widget> get _speedItems => _choiceItems(
    defaultPlaySpeedList,
    label: (value) => '${value}x',
    selected: (value) => value == playerController.playback.playerSpeed,
    onSelected: widget.setPlaybackSpeed,
  );

  Widget _menuButton({
    required Widget child,
    required List<Widget> items,
    String? tooltip,
    FocusNode? focusNode,
  }) => PlayerPanelHoldMenuAnchor(
    acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
    onVisibilityChanged: widget.onMenuVisibilityChanged,
    builder: (context, toggle) => tooltip == null
        ? TextButton(focusNode: focusNode, onPressed: toggle, child: child)
        : IconButton(
            focusNode: focusNode,
            onPressed: toggle,
            icon: child,
            tooltip: tooltip,
          ),
    menuChildren: items,
  );

  Widget get _danmakuSettingsButton => IconButton(
    focusNode: _danmakuSettingsFocus,
    onPressed: _showDanmakuSettings,
    color: Colors.white,
    icon: _cachedDanmakuSettingsIcon,
    tooltip: '弹幕设置',
  );

  Widget get _desktopDanmakuControls => LayoutBuilder(
    builder: (context, constraints) => Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [_buildDanmakuToggleButton(context), _danmakuSettingsButton],
      ),
    ),
  );

  Widget get _syncPlayMenuItem =>
      KazumiMenuItem(onPressed: widget.showSyncPlayPanel, label: '一起看');

  Widget get _wideControls => Row(
    children: [
      if (_desktop) Expanded(child: _desktopDanmakuControls),
      if (!_desktop) ...[
        IconButton(
          focusNode: _danmakuToggleFocus,
          color: Colors.white,
          icon: playerController.danmaku.danmakuOn
              ? _danmakuOnIcon(context)
              : _cachedDanmakuOffIcon,
          onPressed: widget.handleDanmaku,
          tooltip: playerController.danmaku.danmakuOn ? '关闭弹幕' : '打开弹幕',
        ),
        if (playerController.danmaku.danmakuOn) _danmakuSettingsButton,
        // Keep the danmaku controls on the left and the playback menus on
        // the right, regardless of whether the settings button is visible.
        const Spacer(),
      ],
      _menuButton(
        focusNode: _speedFocus,
        child: Text(
          playerController.playback.playerSpeed == 1
              ? '倍速'
              : '${playerController.playback.playerSpeed}x',
          style: const TextStyle(color: Colors.white, fontSize: 28),
        ),
        items: _speedItems,
      ),
      _menuButton(
        focusNode: _aspectRatioFocus,
        child: const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
        tooltip: '视频比例',
        items: _aspectRatioItems,
      ),
      if (widget.onToggleSidePanel != null)
        IconButton(
          color: Colors.white,
          icon: const Icon(Icons.menu_open_rounded),
          tooltip: '选集面板',
          onPressed: widget.onToggleSidePanel,
        ),
    ],
  );

  Widget _buildBottomControls(bool compact) => SafeArea(
    top: false,
    bottom: !compact && widget.fillsWindow,
    left: !compact && widget.fillsWindow,
    right: !compact && widget.fillsWindow,
    child: PlayerPanelHoldMouseRegion(
      acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
      cursor:
          (videoPageController.isFullscreen &&
              !playerController.panel.showVideoController)
          ? SystemMouseCursors.none
          : SystemMouseCursors.basic,
      child: PlayerTransportBar(
        compact: compact,
        timePlacement: PlayerTimeLabelPlacement.forViewport(
          MediaQuery.sizeOf(context),
          desktop: _desktop,
        ),
        // The play/pause control is intentionally omitted; the remote's center
        // key toggles playback.
        playPause: const SizedBox.shrink(),
        nextEpisode: IconButton(
          focusNode: _nextEpisodeFocus,
          color: Colors.white,
          icon: const Icon(Icons.skip_next_rounded),
          tooltip: '下一集',
          onPressed: widget.onNextEpisode,
        ),
        // Playback ticks only rebuild the progress bar and its time labels.
        progressBuilder: (location) => Observer(
          builder: (context) => Focus(
            // Focusable so a remote can land on the scrubber; arrow keys are
            // mapped to the escalating seek step by the player's shortcuts.
            focusNode: _progressFocus,
            onKeyEvent: _handleProgressKey,
            autofocus: false,
            child: ProgressBar(
              thumbRadius: 16,
              thumbGlowRadius: 36,
              timeLabelLocation: location,
              timeLabelTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              progress: playerController.playback.currentPosition,
              buffered: playerController.playback.buffer,
              total: playerController.playback.duration,
              onSeek: widget.handleProgressBarSeek,
              onDragStart: (_) => widget.handleProgressBarDragStart(),
              onDragUpdate: (details) => playerController.seeking
                  .updateInteractiveSeek(details.timeStamp),
            ),
          ),
        ),
        timeLabel: Observer(
          builder: (context) => Text(
            '${compact ? '    ' : ''}${durationToString(playerController.playback.currentPosition)} / ${durationToString(playerController.playback.duration)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: !compact && _desktop ? 24 : 18,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        controls: compact ? const SizedBox.shrink() : _wideControls,
        fullscreen: _buildFullscreenButton(compact),
        trailing: _buildMoreMenu(),
      ),
    ),
  );

  KeyEventResult _handleProgressKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.arrowDown) {
      return KeyEventResult.ignored;
    }
    _nextEpisodeFocus.requestFocus();
    return KeyEventResult.handled;
  }

  KeyEventResult _handleNextEpisodeKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _progressFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _danmakuToggleFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleDanmakuToggleKey(FocusNode _, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _nextEpisodeFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      (playerController.danmaku.danmakuOn ? _danmakuSettingsFocus : _speedFocus)
          .requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleDanmakuSettingsKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _danmakuToggleFocus.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _speedFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleSpeedKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      (playerController.danmaku.danmakuOn
              ? _danmakuSettingsFocus
              : _danmakuToggleFocus)
          .requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _aspectRatioFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleAspectRatioKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _speedFocus.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildFullscreenButton(bool compact) {
    if (videoPageController.isPip) {
      return compact ? const Text('    ') : const SizedBox.shrink();
    }
    if (!_desktop && widget.fillsWindow && !videoPageController.isFullscreen) {
      return const SizedBox.shrink();
    }
    return IconButton(
      color: Colors.white,
      icon: Icon(
        videoPageController.isFullscreen
            ? Icons.fullscreen_exit_rounded
            : Icons.fullscreen_rounded,
      ),
      tooltip: videoPageController.isFullscreen ? '退出全屏' : '全屏',
      onPressed: widget.handleFullscreen,
    );
  }

  Widget _buildTopControls(bool compact) {
    return EmbeddedNativeControlArea(
      requireOffset: compact || !videoPageController.isFullscreen,
      child: SafeArea(
        top: false,
        bottom: false,
        left: !compact && widget.fillsWindow,
        right: !compact && widget.fillsWindow,
        child: PlayerPanelHoldMouseRegion(
          acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
          cursor:
              (videoPageController.isFullscreen &&
                  !playerController.panel.showVideoController)
              ? SystemMouseCursors.none
              : SystemMouseCursors.basic,
          child: Row(
            children: [
              IconButton(
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: '返回',
                onPressed: widget.onBackPressed,
              ),
              Expanded(
                child: dtb.DragToMoveArea(
                  child: compact
                      ? const SizedBox(height: 40)
                      : Text(
                          ' ${videoPageController.title} [${videoPageController.roadList[videoPageController.selectedEpisode.road].identifier[videoPageController.selectedEpisode.episode - 1]}]',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize:
                                (Theme.of(
                                      context,
                                    ).textTheme.titleMedium!.fontSize ??
                                    16) *
                                2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
              ),
              if (_desktop)
                PlayerScreenshotControls(
                  controller: playerController.screenshots,
                  onCapture: widget.handleScreenShot,
                  onReview: widget.showScreenshotCandidates,
                ),
              if (compact) _buildDanmakuToggleButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Anchored at the bottom-right of the transport bar so a remote reaches it
  /// after the transport controls rather than from the title row.
  Widget _buildMoreMenu() {
    return PlayerPanelHoldMenuAnchor(
      acquirePlayerPanelHold: widget.acquirePlayerPanelHold,
      onVisibilityChanged: widget.onMenuVisibilityChanged,
      builder: (context, toggle) {
        return IconButton(
          onPressed: toggle,
          tooltip: '更多选项',
          icon: const Icon(Icons.more_vert, color: Colors.white),
        );
      },
      menuChildren: [
        KazumiMenuItem(onPressed: widget.showDanmakuSwitch, label: '弹幕切换'),
        KazumiMenuItem(onPressed: widget.showVideoInfo, label: '视频详情'),
        _syncPlayMenuItem,
      ],
    );
  }

  Widget get _rightControls => const SizedBox.shrink();
}
