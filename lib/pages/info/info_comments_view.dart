import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kazumi/bean/card/comments_card.dart';
import 'package:kazumi/bean/widget/empty_state_widget.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/widget/tv_focus_highlight.dart';
import 'package:kazumi/modules/bangumi/bangumi_interest.dart';
import 'package:kazumi/modules/comments/comment_item.dart';

class InfoCommentsView extends StatefulWidget {
  const InfoCommentsView({
    super.key,
    required this.interest,
    required this.comments,
    required this.isLoading,
    required this.hasLoaded,
    required this.hasError,
    required this.onReviewTap,
    required this.onRetry,
    required this.onLoadMore,
  });

  final BangumiInterest? interest;
  final List<CommentItem> comments;
  final bool isLoading;
  final bool hasLoaded;
  final bool hasError;
  final VoidCallback onReviewTap;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  State<InfoCommentsView> createState() => _InfoCommentsViewState();
}

class _InfoCommentsViewState extends State<InfoCommentsView> {
  static const _writeReviewLabel = '下面我简单喵两句';
  static const _maxWidth = 950.0;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: '吐槽列表');

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Moves focus out of the list (back up to the tab header) without popping
  /// the detail route.
  void _leaveListFocus() {
    FocusManager.instance.primaryFocus?.focusInDirection(TraversalDirection.up);
    _focusNode.unfocus();
  }

  CommentItem? get _ownComment {
    final review = widget.interest;
    final user = review?.user;
    if (review == null || !review.hasReviewContent || user == null) return null;
    return CommentItem(
      user: user,
      comment: Comment(
        rate: review.rate,
        comment: review.comment,
        updatedAt: review.updatedAt,
      ),
    );
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    // Nested error views must not trigger pagination.
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        !widget.isLoading &&
        widget.comments.isNotEmpty &&
        notification.metrics.extentAfter < 200) {
      widget.onLoadMore();
    }
    return false;
  }

  /// Scrolls the comment list with the D-pad. At either end the direction is
  /// released so focus can leave the list instead of getting stuck.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // Back hands focus back to the tab header instead of leaving the page.
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack ||
            event.logicalKey == LogicalKeyboardKey.browserBack)) {
      _leaveListFocus();
      return KeyEventResult.handled;
    }
    if (!_scrollController.hasClients) return KeyEventResult.ignored;
    final position = _scrollController.position;
    final step = (position.viewportDimension * 0.6).clamp(80.0, 400.0);
    final down = event.logicalKey == LogicalKeyboardKey.arrowDown;
    final up = event.logicalKey == LogicalKeyboardKey.arrowUp;
    if (down && position.extentAfter > 1) {
      _scrollBy(step);
      return KeyEventResult.handled;
    }
    if (up && position.extentBefore > 1) {
      _scrollBy(-step);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollBy(double delta) {
    final position = _scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownComment = _ownComment;
    final hasReview = widget.interest?.hasReviewContent ?? false;
    final showEmpty =
        widget.hasLoaded &&
        !widget.isLoading &&
        !widget.hasError &&
        widget.comments.isEmpty &&
        !hasReview;
    return PopScope(
      // With the list focused, back returns focus to the tab header rather
      // than leaving the detail page.
      canPop: !_focusNode.hasFocus,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _leaveListFocus();
      },
      child: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gutter = ((constraints.maxWidth - _maxWidth) / 2).clamp(
              16.0,
              double.infinity,
            );
            return TvFocusHighlight(
              borderRadius: BorderRadius.zero,
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: _handleKey,
                child: NotificationListener<ScrollEndNotification>(
                  onNotification: _onScrollEnd,
                  child: CustomScrollView(
                    key: const PageStorageKey<String>('吐槽'),
                    controller: _scrollController,
                    scrollBehavior: const ScrollBehavior().copyWith(
                      scrollbars: false,
                    ),
                    slivers: [
                      SliverOverlapInjector(
                        handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                          context,
                        ),
                      ),
                      if (ownComment == null && !showEmpty)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 8),
                          sliver: SliverToBoxAdapter(
                            child: _reviewEntry(context, editing: hasReview),
                          ),
                        ),
                      if (ownComment != null || widget.comments.isNotEmpty)
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: gutter),
                          sliver: SliverList.separated(
                            addAutomaticKeepAlives: false,
                            itemCount:
                                widget.comments.length +
                                (ownComment == null ? 0 : 1),
                            itemBuilder: (context, index) {
                              if (ownComment != null && index == 0) {
                                return _ownReview(ownComment);
                              }
                              return CommentsCard(
                                commentItem:
                                    widget.comments[index -
                                        (ownComment == null ? 0 : 1)],
                              );
                            },
                            separatorBuilder: (_, _) => const Divider(
                              thickness: 0.5,
                              indent: 10,
                              endIndent: 10,
                            ),
                          ),
                        )
                      else if (widget.hasError)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: GeneralErrorWidget(
                            title: '评论加载失败',
                            errMsg: '请检查网络连接后重试。',
                            onRetry: widget.onRetry,
                          ),
                        )
                      else if (showEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: GeneralEmptyState(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: '暂无吐槽',
                            actions: [
                              TextButton(
                                onPressed: widget.onReviewTap,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                ),
                                child: const Text(_writeReviewLabel),
                              ),
                            ],
                          ),
                        )
                      else if (widget.isLoading || !widget.hasLoaded)
                        SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: gutter),
                          sliver: SliverList.builder(
                            itemCount: 4,
                            itemBuilder: (_, _) => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CommentsCard.bone(),
                            ),
                          ),
                        ),
                      if (ownComment != null || widget.comments.isNotEmpty)
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 96 + MediaQuery.paddingOf(context).bottom,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _reviewEntry(BuildContext context, {required bool editing}) {
    final colors = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: widget.onReviewTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(16),
        backgroundColor: colors.surfaceContainerLow,
        foregroundColor: colors.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(editing ? '编辑' : _writeReviewLabel)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    );
  }

  Widget _ownReview(CommentItem comment) {
    return Card.filled(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CommentsCard.own(commentItem: comment),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onReviewTap,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('编辑'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
