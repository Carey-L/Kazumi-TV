import 'package:kazumi/bean/widget/embedded_native_control_area.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:kazumi/bean/appbar/drag_to_move_bar.dart' as dtb;
import 'package:kazumi/bean/card/bangumi_info_card.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/dialog/adaptive_bottom_sheet.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/collect_button.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/pages/info/info_actions_menu.dart';
import 'package:kazumi/pages/info/info_controller.dart';
import 'package:kazumi/pages/info/info_tabview.dart';
import 'package:kazumi/pages/info/rating_review_dialog.dart';
import 'package:kazumi/pages/info/source_sheet.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({
    super.key,
    required this.inputBangumiItem,
    required this.infoController,
  });

  final BangumiItem inputBangumiItem;
  final InfoController infoController;

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _infoTabs = <String>[
    '概览',
    '吐槽',
    '角色',
    '关联',
    '制作人员',
  ];
  static const Duration _minimumBangumiInfoLoadingDuration = Duration(
    milliseconds: 600,
  );

  InfoController get infoController => widget.infoController;
  late final TabController infoTabController;
  final GlobalKey<NestedScrollViewState> _nestedScrollKey = GlobalKey();
  final ScrollController _outerScrollController = ScrollController();
  final FocusNode _tabFocus = FocusNode(debugLabel: '番剧详情导航栏');
  late final bool showRating;
  int _headerRevealRequest = 0;

  bool commentsIsLoading = false;
  bool charactersIsLoading = false;
  bool commentsQueryTimeout = false;
  bool commentsHasLoaded = false;
  bool charactersQueryTimeout = false;
  bool charactersIsEmpty = false;
  bool staffIsLoading = false;
  bool staffQueryTimeout = false;
  bool staffIsEmpty = false;
  bool _showBangumiInfoSkeleton = false;

  bool get _isShowingBangumiInfoSkeleton =>
      infoController.isLoading || _showBangumiInfoSkeleton;

  Future<void> loadCharacters() async {
    if (charactersIsLoading) return;
    setState(() {
      charactersIsLoading = true;
      charactersQueryTimeout = false;
      charactersIsEmpty = false;
    });
    try {
      await infoController.queryBangumiCharactersByID(
        infoController.bangumiItem.id,
      );
      if (mounted) {
        setState(() {
          charactersIsLoading = false;
          if (infoController.characterList.isEmpty) {
            charactersIsEmpty = true;
          }
        });
      }
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load characters', error: e);
      if (mounted) {
        setState(() {
          charactersIsLoading = false;
          charactersQueryTimeout = true;
        });
      }
    }
  }

  Future<void> loadStaff() async {
    if (staffIsLoading) return;
    setState(() {
      staffIsLoading = true;
      staffQueryTimeout = false;
      staffIsEmpty = false;
    });
    try {
      await infoController.queryBangumiStaffsByID(
        infoController.bangumiItem.id,
      );
      if (mounted) {
        setState(() {
          staffIsLoading = false;
          if (infoController.staffList.isEmpty) {
            staffIsEmpty = true;
          }
        });
      }
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load staff', error: e);
      if (mounted) {
        setState(() {
          staffIsLoading = false;
          staffQueryTimeout = true;
        });
      }
    }
  }

  Future<void> loadRelations() async {
    try {
      await infoController.queryBangumiRelationsByID(
        infoController.bangumiItem.id,
      );
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load relations', error: e);
    }
  }

  Future<void> loadMoreComments({bool loadMore = false}) async {
    if (commentsIsLoading) return;
    setState(() {
      commentsIsLoading = true;
      commentsQueryTimeout = false;
    });
    try {
      await infoController.queryBangumiCommentsByID(
        infoController.bangumiItem.id,
        refresh: !loadMore,
      );
      if (mounted) {
        setState(() {
          commentsIsLoading = false;
          commentsHasLoaded = true;
        });
      }
    } catch (e) {
      KazumiLogger().e('InfoPage: failed to load comments', error: e);
      if (mounted) {
        setState(() {
          commentsIsLoading = false;
          commentsQueryTimeout = true;
        });
      }
    }
  }

  Future<void> _openReviewEditor() async {
    final token = GStorage.getSetting(
      SettingsKeys.bangumiAccessToken,
    ).toString().trim();
    if (token.isEmpty) {
      KazumiDialog.showToast(message: '请先在同步设置中绑定 Bangumi');
      return;
    }
    final localType = infoController.collectController.getCollectType(
      infoController.bangumiItem,
    );
    if (localType == 0) {
      KazumiDialog.showToast(message: '请先追番');
      return;
    }
    final editing =
        infoController.bangumiItem.interest?.hasReviewContent ?? false;
    final submitted = await KazumiDialog.show<bool>(
      context: context,
      builder: (context) => RatingReviewDialog(
        bangumiItem: infoController.bangumiItem,
        onSubmit: (review) =>
            infoController.rateBangumi(review, localType: localType),
      ),
    );
    if (submitted == true && mounted) {
      setState(() {});
      KazumiDialog.showToast(
        context: context,
        message: editing ? '吐槽已更新' : '吐槽已发表',
      );
    }
  }

  void _showSourceSheet() {
    showAdaptiveBottomSheet<void>(
      context: context,
      maxHeightFactor: 0.88,
      builder: (context) => SourceSheet(infoController: infoController),
    );
  }

  Future<void> _openSection(int index) async {
    switch (index) {
      case 1:
        await onCommentsTabSelected();
      case 2:
        await loadCharacters();
      case 3:
        await loadRelations();
      case 4:
        await loadStaff();
    }
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _InfoSectionSheet(
          index: index,
          controller: infoController,
          commentsQueryTimeout: commentsQueryTimeout,
          commentsHasLoaded: commentsHasLoaded,
          charactersQueryTimeout: charactersQueryTimeout,
          charactersIsEmpty: charactersIsEmpty,
          staffQueryTimeout: staffQueryTimeout,
          staffIsEmpty: staffIsEmpty,
          commentsIsLoading: commentsIsLoading,
          onWriteReview: _openReviewEditor,
          onRetryComments: () => loadMoreComments(loadMore: false),
          onLoadMoreComments: () => loadMoreComments(loadMore: true),
          onRetryCharacters: loadCharacters,
          onRetryRelations: loadRelations,
          onRetryStaff: loadStaff,
        ),
      ),
    );
  }

  Widget _sectionNavigation() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children:
            [
                  ('概览', Icons.info_outline_rounded, 0),
                  ('吐槽', Icons.chat_bubble_outline_rounded, 1),
                  ('角色', Icons.people_alt_outlined, 2),
                  ('关联', Icons.account_tree_outlined, 3),
                  ('制作人员', Icons.groups_outlined, 4),
                ]
                .map(
                  (entry) => FilledButton.tonalIcon(
                    onPressed: () => _openSection(entry.$3),
                    icon: Icon(entry.$2, size: 18),
                    label: Text(entry.$1),
                  ),
                )
                .toList(),
      ),
    ),
  );

  Widget _buildOverview(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        infoController.bangumiItem.nameCn.isEmpty
            ? infoController.bangumiItem.name
            : infoController.bangumiItem.nameCn,
      ),
      actions: [InfoActionsMenu(bangumiItem: infoController.bangumiItem)],
    ),
    body: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Observer(
              builder: (_) => Padding(
                padding: const EdgeInsets.all(16),
                child: BangumiInfoCardV(
                  bangumiItem: infoController.bangumiItem,
                  isLoading: _isShowingBangumiInfoSkeleton,
                  showRating: showRating,
                  onStartWatching: _showSourceSheet,
                ),
              ),
            ),
          ),
        ),
        _sectionNavigation(),
      ],
    ),
  );

  void _revealHeaderWhenTabFocused(bool hasFocus) {
    if (!hasFocus) return;
    final request = ++_headerRevealRequest;
    // Focus descendants can schedule ensureVisible in post-frame callbacks.
    // Run after the frame has settled so it cannot fight the tab's own scroll.
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (!mounted || request != _headerRevealRequest) return;
      if (!_outerScrollController.hasClients) return;
      final position = _outerScrollController.position;
      if (position.pixels > position.minScrollExtent) {
        _outerScrollController.jumpTo(position.minScrollExtent);
      }
    });
  }

  Future<void> _scrollToTop() async {
    final inner = _nestedScrollKey.currentState?.innerController;
    if (inner?.hasClients == true) {
      final position = inner!.position;
      if (position.pixels > position.minScrollExtent) {
        await inner.animateTo(
          position.minScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    }
    if (!_outerScrollController.hasClients) return;
    final position = _outerScrollController.position;
    if (position.pixels > position.minScrollExtent) {
      await _outerScrollController.animateTo(
        position.minScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    infoController.bangumiItem = widget.inputBangumiItem;
    infoController.characterList.clear();
    infoController.clearComments();
    infoController.staffList.clear();
    infoController.clearRelations();
    infoController.pluginSearchResponseList.clear();
    _showBangumiInfoSkeleton = true;
    _loadBangumiInfo();
    infoTabController = TabController(length: _infoTabs.length, vsync: this);
    showRating = GStorage.getSetting(SettingsKeys.showRating);
  }

  void onInfoTabChanged() {
    final index = infoTabController.index;
    if (index == 1) {
      onCommentsTabSelected();
    }
    if (index == 2 &&
        infoController.characterList.isEmpty &&
        !charactersIsLoading &&
        !charactersIsEmpty &&
        !charactersQueryTimeout) {
      loadCharacters();
    }
    if (index == 3 && infoController.canLoadRelations) {
      loadRelations();
    }
    if (index == 4 &&
        infoController.staffList.isEmpty &&
        !staffIsLoading &&
        !staffIsEmpty &&
        !staffQueryTimeout) {
      loadStaff();
    }
  }

  Future<void> onCommentsTabSelected() async {
    final interest = infoController.bangumiItem.interest;
    final token = GStorage.getSetting(
      SettingsKeys.bangumiAccessToken,
    ).toString().trim();
    if (interest != null && token.isNotEmpty) {
      final updated = await infoController.fillInterestUserProfileIfNeeded();
      if (!mounted) return;
      if (updated) {
        setState(() {});
      }
    }
    if (infoController.commentsList.isEmpty &&
        !commentsIsLoading &&
        !commentsHasLoaded &&
        !commentsQueryTimeout) {
      loadMoreComments();
    }
  }

  @override
  void dispose() {
    infoController.characterList.clear();
    infoController.clearComments();
    infoController.staffList.clear();
    infoController.clearRelations();
    infoController.pluginSearchResponseList.clear();
    infoTabController.dispose();
    _outerScrollController.dispose();
    _tabFocus.dispose();
    super.dispose();
  }

  Future<void> _loadBangumiInfo() async {
    final loadingStartedAt = DateTime.now();
    try {
      // Attach metadata without replacing rendered image URLs.
      await infoController.queryBangumiInfoByID(
        infoController.bangumiItem.id,
        type: 'attach',
      );
    } catch (e) {
      KazumiLogger().e(
        'InfoPage: failed to query bangumi info by ID',
        error: e,
      );
    } finally {
      if (mounted) {
        await _waitForMinimumBangumiInfoLoadingDuration(loadingStartedAt);
      }
      if (mounted) {
        setState(() {
          _showBangumiInfoSkeleton = false;
        });
      }
    }
  }

  Future<void> _waitForMinimumBangumiInfoLoadingDuration(
    DateTime loadingStartedAt,
  ) async {
    final elapsed = DateTime.now().difference(loadingStartedAt);
    final remaining = _minimumBangumiInfoLoadingDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the legacy branch only for an impossible layout fallback while the
    // migration settles; normal detail pages render the direct overview.
    if (!MediaQuery.sizeOf(context).width.isNegative) {
      return _buildOverview(context);
    }
    const topOffset = 0.0;
    return Scaffold(
      body: NestedScrollView(
        key: _nestedScrollKey,
        controller: _outerScrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverOverlapAbsorber(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverAppBar.medium(
                title: EmbeddedNativeControlArea(
                  child: dtb.DragToMoveArea(
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        infoController.bangumiItem.nameCn == ''
                            ? infoController.bangumiItem.name
                            : infoController.bangumiItem.nameCn,
                      ),
                    ),
                  ),
                ),
                automaticallyImplyLeading: false,
                scrolledUnderElevation: 0.0,
                leading: EmbeddedNativeControlArea(
                  child: IconButton(
                    onPressed: () {
                      context.maybePop();
                    },
                    icon: Icon(Icons.arrow_back),
                  ),
                ),
                actions: [
                  if (innerBoxIsScrolled)
                    EmbeddedNativeControlArea(
                      child: CollectButton(
                        bangumiItem: infoController.bangumiItem,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  EmbeddedNativeControlArea(
                    child: IconButton(
                      onPressed: _scrollToTop,
                      tooltip: '回到顶部',
                      icon: const Icon(Icons.vertical_align_top_rounded),
                    ),
                  ),
                  EmbeddedNativeControlArea(
                    child: InfoActionsMenu(
                      bangumiItem: infoController.bangumiItem,
                    ),
                  ),
                  SizedBox(width: 8),
                ],
                toolbarHeight: kToolbarHeight + topOffset,
                stretch: true,
                centerTitle: false,
                expandedHeight:
                    308 + kTextTabBarHeight + kToolbarHeight + topOffset,
                collapsedHeight:
                    kTextTabBarHeight +
                    kToolbarHeight +
                    MediaQuery.paddingOf(context).top +
                    topOffset,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: Observer(
                    builder: (context) {
                      final showBangumiInfoSkeleton =
                          _isShowingBangumiInfoSkeleton;
                      return Stack(
                        children: [
                          if (!showBangumiInfoSkeleton)
                            Positioned.fill(
                              bottom: kTextTabBarHeight,
                              child: IgnorePointer(
                                child: _InfoHeaderBackground(
                                  imageUrl:
                                      infoController
                                          .bangumiItem
                                          .images['large'] ??
                                      '',
                                ),
                              ),
                            ),
                          SafeArea(
                            bottom: false,
                            child: EmbeddedNativeControlArea(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    kToolbarHeight,
                                    16,
                                    0,
                                  ),
                                  child: BangumiInfoCardV(
                                    bangumiItem: infoController.bangumiItem,
                                    isLoading: showBangumiInfoSkeleton,
                                    showRating: showRating,
                                    onStartWatching: _showSourceSheet,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                forceElevated: innerBoxIsScrolled,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(kTextTabBarHeight),
                  child: Focus(
                    focusNode: _tabFocus,
                    onFocusChange: _revealHeaderWhenTabFocused,
                    child: TabBar(
                      controller: infoTabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      dividerHeight: 0,
                      tabs: _infoTabs.map((name) => Tab(text: name)).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: Observer(
          builder: (context) {
            final showBangumiInfoSkeleton = _isShowingBangumiInfoSkeleton;
            return InfoTabView(
              tabController: infoTabController,
              bangumiItem: infoController.bangumiItem,
              commentsQueryTimeout: commentsQueryTimeout,
              commentsHasLoaded: commentsHasLoaded,
              charactersQueryTimeout: charactersQueryTimeout,
              charactersIsEmpty: charactersIsEmpty,
              staffQueryTimeout: staffQueryTimeout,
              staffIsEmpty: staffIsEmpty,
              loadMoreComments: loadMoreComments,
              loadCharacters: loadCharacters,
              loadStaff: loadStaff,
              commentsList: infoController.commentsList.toList(growable: false),
              commentsIsLoading: commentsIsLoading,
              onWriteReview: _openReviewEditor,
              characterList: infoController.characterList,
              staffList: infoController.staffList,
              relationList: infoController.relationList,
              relationsIsLoading: infoController.relationsIsLoading,
              relationsQueryTimeout: infoController.relationsQueryTimeout,
              relationsHasLoaded: infoController.relationsHasLoaded,
              loadRelations: loadRelations,
              isLoading: showBangumiInfoSkeleton,
              onNavigateToTabs: _tabFocus.requestFocus,
            );
          },
        ),
      ),
    );
  }
}

class _InfoSectionSheet extends StatefulWidget {
  const _InfoSectionSheet({
    required this.index,
    required this.controller,
    required this.commentsQueryTimeout,
    required this.commentsHasLoaded,
    required this.charactersQueryTimeout,
    required this.charactersIsEmpty,
    required this.staffQueryTimeout,
    required this.staffIsEmpty,
    required this.commentsIsLoading,
    required this.onWriteReview,
    required this.onRetryComments,
    required this.onLoadMoreComments,
    required this.onRetryCharacters,
    required this.onRetryRelations,
    required this.onRetryStaff,
  });

  final int index;
  final InfoController controller;
  final bool commentsQueryTimeout;
  final bool commentsHasLoaded;
  final bool charactersQueryTimeout;
  final bool charactersIsEmpty;
  final bool staffQueryTimeout;
  final bool staffIsEmpty;
  final bool commentsIsLoading;
  final VoidCallback onWriteReview;
  final Future<void> Function() onRetryComments;
  final Future<void> Function() onLoadMoreComments;
  final Future<void> Function() onRetryCharacters;
  final Future<void> Function() onRetryRelations;
  final Future<void> Function() onRetryStaff;

  @override
  State<_InfoSectionSheet> createState() => _InfoSectionSheetState();
}

class _InfoSectionSheetState extends State<_InfoSectionSheet>
    with SingleTickerProviderStateMixin {
  static const _titles = ['概览', '吐槽', '角色', '关联', '制作人员'];
  late final TabController _tabController = TabController(
    length: _titles.length,
    initialIndex: widget.index,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_titles[widget.index])),
    body: NestedScrollView(
      headerSliverBuilder: (_, _) => const [],
      body: Observer(
        builder: (_) => InfoTabView(
          tabController: _tabController,
          visibleIndex: widget.index,
          bangumiItem: widget.controller.bangumiItem,
          commentsQueryTimeout: widget.commentsQueryTimeout,
          commentsHasLoaded: widget.commentsHasLoaded,
          charactersQueryTimeout: widget.charactersQueryTimeout,
          charactersIsEmpty: widget.charactersIsEmpty,
          staffQueryTimeout: widget.staffQueryTimeout,
          staffIsEmpty: widget.staffIsEmpty,
          loadMoreComments: ({bool loadMore = false}) =>
              loadMore ? widget.onLoadMoreComments() : widget.onRetryComments(),
          loadCharacters: widget.onRetryCharacters,
          loadStaff: widget.onRetryStaff,
          commentsList: widget.controller.commentsList.toList(growable: false),
          commentsIsLoading: widget.commentsIsLoading,
          onWriteReview: widget.onWriteReview,
          characterList: widget.controller.characterList,
          staffList: widget.controller.staffList,
          relationList: widget.controller.relationList,
          relationsIsLoading: widget.controller.relationsIsLoading,
          relationsQueryTimeout: widget.controller.relationsQueryTimeout,
          relationsHasLoaded: widget.controller.relationsHasLoaded,
          loadRelations: widget.onRetryRelations,
          isLoading: false,
          // A standalone detail page has no tab strip to return to. Moving
          // above the comments list must never be interpreted as route back.
          onNavigateToTabs: () {},
        ),
      ),
    ),
  );
}

class _InfoHeaderBackground extends StatelessWidget {
  const _InfoHeaderBackground({required this.imageUrl});

  static const double _downsample = 0.5;
  static const double _blurSigma = 15.0;
  static const double _opacity = 0.4;
  static const double _edgeBleed = 32.0;
  static const double _bottomFeatherHeight = 48.0;

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }

        final rasterWidth = width * _downsample;
        final rasterHeight = (height + _edgeBleed) * _downsample;

        final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.transparent],
                    stops: [0.8, 1],
                  ).createShader(bounds);
                },
                child: Align(
                  alignment: Alignment.topCenter,
                  child: RepaintBoundary(
                    child: Transform.scale(
                      scale: 1 / _downsample,
                      alignment: Alignment.topCenter,
                      filterQuality: FilterQuality.low,
                      child: SizedBox(
                        width: rasterWidth,
                        height: rasterHeight,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(
                            sigmaX: _blurSigma * _downsample,
                            sigmaY: _blurSigma * _downsample,
                          ),
                          child: NetworkImgLayer(
                            src: imageUrl,
                            width: rasterWidth,
                            height: rasterHeight,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            filterQuality: FilterQuality.low,
                            color: Colors.white.withValues(alpha: _opacity),
                            colorBlendMode: BlendMode.modulate,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _bottomFeatherHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        backgroundColor.withValues(alpha: 0),
                        backgroundColor.withValues(alpha: 0.55),
                        backgroundColor,
                      ],
                      stops: const [0, 0.72, 1],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
