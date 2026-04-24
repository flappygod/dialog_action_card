import 'package:flutter/material.dart';
import 'dialog_action_hero.dart';
import 'dart:async';

/// A widget that keeps a Hero wrapper for a short period,
/// then removes the Hero wrapper automatically.
///
/// This is useful when the destination page still needs Hero
/// participation during the route transition, but no longer
/// needs to stay inside a Hero after the transition finishes.
///
/// 一个会在短时间内保留 Hero 包装、随后自动移除 Hero 包装的组件。
///
/// 适用于以下场景：
/// 目标页面在路由转场期间仍需要参与 Hero 动画，
/// 但在转场结束后，不再需要继续保留 Hero 包装。
class DialogActionAutoRemoveHero extends StatefulWidget {
  /// Hero tag used to match source and destination Hero widgets.
  ///
  /// 用于匹配起点与终点 Hero 的 tag。
  final String heroTag;

  /// The actual widget to display.
  ///
  /// 实际要显示的子组件。
  final Widget child;

  /// Optional duration to keep the Hero wrapper before removing it.
  ///
  /// If null, the current route's [PageRoute.transitionDuration] will be used.
  ///
  /// 可选的 Hero 保留时长。
  ///
  /// 如果为空，则使用当前路由的 [PageRoute.transitionDuration]。
  final Duration? removeAfter;

  /// Creates a widget that temporarily keeps Hero, then removes it automatically.
  ///
  /// 创建一个临时保留 Hero、随后自动移除 Hero 的组件。
  const DialogActionAutoRemoveHero({
    super.key,
    required this.heroTag,
    required this.child,
    this.removeAfter,
  });

  @override
  State<DialogActionAutoRemoveHero> createState() =>
      _DialogActionAutoRemoveHeroState();
}

class _DialogActionAutoRemoveHeroState
    extends State<DialogActionAutoRemoveHero> {
  /// Whether the Hero wrapper should still be kept.
  ///
  /// 当前是否仍保留 Hero 包装。
  bool _keepHero = true;

  /// Timer used to remove the Hero wrapper after a delay.
  ///
  /// 用于延迟移除 Hero 包装的定时器。
  Timer? _removeTimer;

  /// Whether the remove timer has already been started.
  ///
  /// Prevents starting multiple timers when dependencies change more than once.
  ///
  /// 是否已经启动过移除定时器。
  ///
  /// 用于避免在依赖变化多次时重复启动多个定时器。
  bool _timerStarted = false;

  /// Starts the timer that removes the Hero wrapper after [duration].
  ///
  /// If the timer has already started, this method does nothing.
  ///
  /// 启动一个定时器，在 [duration] 后移除 Hero 包装。
  ///
  /// 如果定时器已经启动过，则不会重复启动。
  void _startRemoveTimer(Duration duration) {
    if (_timerStarted) {
      return;
    }
    _timerStarted = true;
    _removeTimer = Timer(duration, () {
      if (!mounted || !_keepHero) {
        return;
      }
      setState(() {
        _keepHero = false;
      });
    });
  }

  /// Resolves the duration used to keep the Hero wrapper.
  ///
  /// Priority:
  /// 1. [widget.removeAfter], if provided
  /// 2. current route's [PageRoute.transitionDuration], if available
  /// 3. [Duration.zero]
  ///
  /// 解析 Hero 包装的保留时长。
  ///
  /// 优先级：
  /// 1. 使用 [widget.removeAfter]（如果有传入）
  /// 2. 使用当前路由的 [PageRoute.transitionDuration]（如果可用）
  /// 3. 否则使用 [Duration.zero]
  Duration _resolveRemoveDuration() {
    if (widget.removeAfter != null) {
      return widget.removeAfter!;
    }

    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route is PageRoute<dynamic>) {
      return route.transitionDuration;
    }

    return Duration.zero;
  }

  /// Starts the remove timer once dependencies are available.
  ///
  /// We use [didChangeDependencies] instead of [initState] because
  /// [ModalRoute.of] depends on the widget being inserted into the tree.
  ///
  /// 在依赖可用后启动移除定时器。
  ///
  /// 这里使用 [didChangeDependencies] 而不是 [initState]，
  /// 因为 [ModalRoute.of] 依赖于组件已经插入到组件树中。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timerStarted) {
      return;
    }
    final Duration duration = _resolveRemoveDuration();
    _startRemoveTimer(duration);
  }

  /// Cancels the timer when the widget is disposed.
  ///
  /// 在组件销毁时取消定时器。
  @override
  void dispose() {
    _removeTimer?.cancel();
    super.dispose();
  }

  /// Builds either:
  /// - the original child directly, after Hero is removed
  /// - or the child wrapped with [DialogActionHero], while Hero is still kept
  ///
  /// 根据当前状态构建：
  /// - Hero 已移除时，直接返回原始 child
  /// - Hero 仍保留时，返回包裹了 [DialogActionHero] 的 child
  @override
  Widget build(BuildContext context) {
    if (!_keepHero) {
      return widget.child;
    }

    return DialogActionHero(
      heroTag: widget.heroTag,
      child: widget.child,
    );
  }
}
