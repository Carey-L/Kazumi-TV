import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/pages/info/info_comments_view.dart';
import 'package:kazumi/bean/card/character_card.dart';
import 'package:kazumi/bean/card/staff_card.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/bangumi/bangumi_relation.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/modules/staff/staff_item.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/utils/device.dart';

class InfoTabView extends StatefulWidget {
  const InfoTabView({
    super.key,
    required this.commentsQueryTimeout,
    required this.commentsHasLoaded,
    required this.charactersQueryTimeout,
    required this.charactersIsEmpty,
    required this.staffQueryTimeout,
    required this.staffIsEmpty,
    required this.relationsQueryTimeout,
    required this.relationsIsLoading,
    required this.relationsHasLoaded,
    required this.tabController,
    required this.loadMoreComments,
    required this.loadCharacters,
    required this.loadStaff,
    required this.loadRelations,
    required this.bangumiItem,
    required this.commentsList,
    required this.commentsIsLoading,
    required this.onWriteReview,
    required this.characterList,
    required this.staffList,
    required this.relationList,
    required this.isLoading,
    required this.onNavigateToTabs,
    this.visibleIndex,
  });

  final bool commentsQueryTimeout;
  final bool commentsHasLoaded;
  final bool commentsIsLoading;
  final VoidCallback onWriteReview;
  final bool charactersQueryTimeout;
  final bool charactersIsEmpty;
  final bool staffQueryTimeout;
  final bool staffIsEmpty;
  final bool relationsQueryTimeout;
  final bool relationsIsLoading;
  final bool relationsHasLoaded;
  final TabController tabController;
  final Future<void> Function({bool loadMore}) loadMoreComments;
  final Future<void> Function() loadCharacters;
  final Future<void> Function() loadStaff;
  final Future<void> Function() loadRelations;
  final BangumiItem bangumiItem;
  final List<CommentItem> commentsList;
  final List<CharacterItem> characterList;
  final List<StaffFullItem> staffList;
  final List<BangumiRelation> relationList;
  final bool isLoading;
  final VoidCallback onNavigateToTabs;
  final int? visibleIndex;

  @override
  State<InfoTabView> createState() => _InfoTabViewState();
}

class _InfoTabViewState extends State<InfoTabView> {
  final maxWidth = 950.0;
  bool fullIntro = false;
  bool fullTag = false;
  final ScrollController _staffScrollController = ScrollController();
  final FocusNode _staffFocus = FocusNode(debugLabel: '制作人员列表');

  @override
  void dispose() {
    _staffScrollController.dispose();
    _staffFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleStaffKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_staffScrollController.hasClients) return KeyEventResult.ignored;
    final position = _staffScrollController.position;
    final step = (position.viewportDimension * 0.6).clamp(80.0, 400.0);
    final outer = context
        .findAncestorStateOfType<NestedScrollViewState>()
        ?.outerController;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        outer?.hasClients == true &&
        outer!.position.extentAfter > 1) {
      _scrollOuterBy(outer, step);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        position.extentAfter > 1) {
      _scrollStaff(step);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        position.extentBefore > 1) {
      _scrollStaff(-step);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        outer?.hasClients == true &&
        outer!.position.extentBefore > 1) {
      _scrollOuterBy(outer, -step);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.onNavigateToTabs();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollStaff(double delta) {
    final position = _staffScrollController.position;
    _staffScrollController.animateTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollOuterBy(ScrollController controller, double delta) {
    final position = controller.position;
    controller.animateTo(
      (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  Widget get infoBody {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width > maxWidth
              ? maxWidth
              : MediaQuery.sizeOf(context).width - 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('简介', style: TextStyle(fontSize: 27)),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final span = TextSpan(text: widget.bangumiItem.summary);
                  final tp = TextPainter(
                    text: span,
                    textDirection: TextDirection.ltr,
                  );
                  tp.layout(maxWidth: constraints.maxWidth);
                  final numLines = tp.computeLineMetrics().length;
                  if (numLines > 7) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: fullIntro ? null : 120,
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: SelectableText(
                            widget.bangumiItem.summary,
                            textAlign: TextAlign.start,
                            scrollBehavior: const ScrollBehavior().copyWith(
                              scrollbars: false,
                            ),
                            scrollPhysics: NeverScrollableScrollPhysics(),
                            selectionHeightStyle: ui.BoxHeightStyle.max,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              fullIntro = !fullIntro;
                            });
                          },
                          child: Text(fullIntro ? '加载更少' : '加载更多'),
                        ),
                      ],
                    );
                  } else {
                    return SelectableText(
                      widget.bangumiItem.summary,
                      textAlign: TextAlign.start,
                      scrollPhysics: NeverScrollableScrollPhysics(),
                      selectionHeightStyle: ui.BoxHeightStyle.max,
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('标签', style: TextStyle(fontSize: 27)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: isDesktop() ? 8 : 0,
                children: List<Widget>.generate(
                  fullTag || widget.bangumiItem.tags.length < 13
                      ? widget.bangumiItem.tags.length
                      : 13,
                  (int index) {
                    if (!fullTag && index == 12) {
                      return ActionChip(
                        label: Text(
                          '更多 +',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            fullTag = !fullTag;
                          });
                        },
                      );
                    }
                    return ActionChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${widget.bangumiItem.tags[index].name} '),
                          Text(
                            '${widget.bangumiItem.tags[index].count}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () {
                        final tagName = Uri.encodeComponent(
                          widget.bangumiItem.tags[index].name,
                        );
                        context.pushNamed('/search/$tagName');
                      },
                    );
                  },
                ).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get relationsListBody {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
          key: const PageStorageKey<String>('关联'),
          slivers: <Widget>[
            if (widget.visibleIndex == null)
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
              ),
            SliverLayoutBuilder(
              builder: (context, constraints) {
                if (widget.relationsQueryTimeout) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: GeneralErrorWidget(
                      title: '关联条目加载失败',
                      errMsg: '请检查网络连接后重试。',
                      onRetry: widget.loadRelations,
                    ),
                  );
                }
                if (widget.relationsHasLoaded && widget.relationList.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: GeneralEmptyState(
                      icon: Icons.account_tree_rounded,
                      title: '暂无关联条目',
                    ),
                  );
                }

                final horizontalPadding =
                    ((constraints.crossAxisExtent - maxWidth) / 2)
                        .clamp(16.0, double.infinity)
                        .toDouble();
                final contentWidth =
                    constraints.crossAxisExtent - horizontalPadding * 2;
                final crossAxisCount = contentWidth >= 840
                    ? 3
                    : contentWidth >= 560
                    ? 2
                    : 1;
                final showSkeleton =
                    !widget.relationsHasLoaded || widget.relationsIsLoading;
                final itemCount = showSkeleton
                    ? crossAxisCount
                    : widget.relationList.length;

                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    16,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: StyleString.cardSpace,
                      crossAxisSpacing: StyleString.cardSpace,
                      mainAxisExtent: _RelatedBangumiCardH.cardHeight,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (showSkeleton) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return Skeletonizer.zone(
                              child: Bone(
                                width: constraints.maxWidth,
                                height: _RelatedBangumiCardH.cardHeight,
                                uniRadius: 14,
                              ),
                            );
                          },
                        );
                      }
                      return _RelatedBangumiCardH(
                        relation: widget.relationList[index],
                      );
                    }, childCount: itemCount),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget get infoBodyBone {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width > maxWidth
              ? maxWidth
              : MediaQuery.sizeOf(context).width - 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeletonizer.zone(child: Bone.text(fontSize: 27, width: 50)),
              const SizedBox(height: 8),
              Skeletonizer.zone(child: Bone.multiText(lines: 7)),
              const SizedBox(height: 16),
              Skeletonizer.zone(child: Bone.text(fontSize: 27, width: 50)),
              const SizedBox(height: 8),
              if (widget.isLoading)
                Skeletonizer.zone(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: List.generate(
                      4,
                      (_) => Bone.button(uniRadius: 8, height: 32),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget get staffListBody {
    return Builder(
      builder: (BuildContext context) {
        return Focus(
          focusNode: _staffFocus,
          onKeyEvent: _handleStaffKey,
          child: CustomScrollView(
            controller: _staffScrollController,
            scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
            key: PageStorageKey<String>('制作人员'),
            slivers: <Widget>[
              if (widget.visibleIndex == null)
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                ),
              SliverLayoutBuilder(
                builder: (context, _) {
                  if (widget.staffList.isNotEmpty) {
                    return SliverList.builder(
                      itemCount: widget.staffList.length,
                      itemBuilder: (context, index) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: SizedBox(
                              width: MediaQuery.sizeOf(context).width > maxWidth
                                  ? maxWidth
                                  : MediaQuery.sizeOf(context).width - 32,
                              child: StaffCard(
                                staffFullItem: widget.staffList[index],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  if (widget.staffQueryTimeout) {
                    return SliverFillRemaining(
                      child: GeneralErrorWidget(
                        title: '制作人员加载失败',
                        errMsg: '请检查网络连接后重试。',
                        onRetry: widget.loadStaff,
                      ),
                    );
                  }
                  if (widget.staffIsEmpty) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: GeneralEmptyState(
                        icon: Icons.groups_rounded,
                        title: '暂无制作人员信息',
                      ),
                    );
                  }
                  return SliverList.builder(
                    itemCount: 8,
                    itemBuilder: (context, _) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: MediaQuery.sizeOf(context).width > maxWidth
                              ? maxWidth
                              : MediaQuery.sizeOf(context).width - 32,
                          child: Skeletonizer.zone(
                            child: ListTile(
                              leading: Bone.circle(size: 36),
                              title: Bone.text(width: 100),
                              subtitle: Bone.text(width: 80),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget get charactersListBody {
    return Builder(
      builder: (BuildContext context) {
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
          key: PageStorageKey<String>('角色'),
          slivers: <Widget>[
            if (widget.visibleIndex == null)
              SliverOverlapInjector(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
              ),
            SliverLayoutBuilder(
              builder: (context, _) {
                if (widget.characterList.isNotEmpty) {
                  return SliverList.builder(
                    itemCount: widget.characterList.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: CharacterCard(
                              characterItem: widget.characterList[index],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
                if (widget.charactersQueryTimeout) {
                  return SliverFillRemaining(
                    child: GeneralErrorWidget(
                      title: '角色列表加载失败',
                      errMsg: '请检查网络连接后重试。',
                      onRetry: widget.loadCharacters,
                    ),
                  );
                }
                if (widget.charactersIsEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: GeneralEmptyState(
                      icon: Icons.people_alt_rounded,
                      title: '暂无角色信息',
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (context, _) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width > maxWidth
                            ? maxWidth
                            : MediaQuery.sizeOf(context).width - 32,
                        child: Skeletonizer.zone(
                          child: ListTile(
                            leading: Bone.circle(size: 36),
                            title: Bone.text(width: 100),
                            subtitle: Bone.text(width: 80),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      Builder(
        // Resolve the overlap handle inside the NestedScrollView.
        builder: (BuildContext context) {
          return CustomScrollView(
            scrollBehavior: const ScrollBehavior().copyWith(scrollbars: false),
            key: PageStorageKey<String>('概览'),
            slivers: <Widget>[
              if (widget.visibleIndex == null)
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                    context,
                  ),
                ),
              SliverToBoxAdapter(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: widget.isLoading ? infoBodyBone : infoBody,
                ),
              ),
            ],
          );
        },
      ),
      InfoCommentsView(
        interest: widget.bangumiItem.interest,
        comments: widget.commentsList,
        isLoading: widget.commentsIsLoading,
        hasLoaded: widget.commentsHasLoaded,
        hasError: widget.commentsQueryTimeout,
        onReviewTap: widget.onWriteReview,
        onRetry: () => widget.loadMoreComments(loadMore: false),
        onLoadMore: () => widget.loadMoreComments(loadMore: true),
        onNavigateUp: widget.onNavigateToTabs,
        standalone: widget.visibleIndex != null,
      ),
      charactersListBody,
      relationsListBody,
      staffListBody,
    ];
    final index = widget.visibleIndex;
    if (index != null) return pages[index];
    return TabBarView(controller: widget.tabController, children: pages);
  }
}

class _RelatedBangumiCardH extends StatelessWidget {
  const _RelatedBangumiCardH({required this.relation});

  static const double cardHeight = 108;
  static const double imageHeight = 92;
  static const double posterAspectRatio = 0.65;

  final BangumiRelation relation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.1);
    final relationLabel = relation.relation.isEmpty ? '关联' : relation.relation;
    final bangumiItem = relation.toBangumiItem();
    final title = bangumiItem.nameCn.isEmpty
        ? bangumiItem.name.trim()
        : bangumiItem.nameCn.trim();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: () {
          context.pushNamed('/info/', arguments: bangumiItem);
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gap = constraints.maxWidth.clamp(0.0, 10.0).toDouble();
              final maxImageWidth = (constraints.maxWidth - gap).clamp(
                0.0,
                152.0,
              );
              final imageWidth = (constraints.maxWidth * 0.42)
                  .clamp(0.0, maxImageWidth)
                  .toDouble();

              return Row(
                children: [
                  NetworkImgLayer(
                    src: bangumiItem.images['large'] ?? '',
                    width: imageWidth,
                    height: imageHeight,
                    origAspectRatio: posterAspectRatio,
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textScaler: textScaler,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          relationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: textScaler,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
