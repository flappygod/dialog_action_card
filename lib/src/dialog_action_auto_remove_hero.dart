import 'package:flutter/material.dart';
import 'dialog_action_hero.dart';
import 'dart:async';

/// A widget that keeps Hero for a short period, then removes
/// the Hero wrapper automatically.
///
/// 一个会在短时间内保留 Hero，随后自动移除 Hero 包装的组件。
///
class DialogActionAutoRemoveHero extends StatefulWidget {
  /// Hero tag used to match source/destination Hero.
  final String heroTag;

  /// The actual widget to display.
  final Widget child;

  /// Optional custom duration to keep Hero wrapper.
  ///
  /// If null, current route's transitionDuration will be used.
  ///
  /// 可选的 Hero 保留时长。
  /// 如果为空，则使用当前路由的进入动画时长。
  final Duration? removeAfter;

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
  bool _keepHero = true;
  Timer? _removeTimer;
  bool _timerStarted = false;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timerStarted) {
      return;
    }
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    Duration duration = widget.removeAfter ?? Duration.zero;
    if (widget.removeAfter == null && route is PageRoute<dynamic>) {
      duration = route.transitionDuration;
    }
    _startRemoveTimer(duration);
  }

  @override
  void dispose() {
    _removeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_keepHero) {
      return widget.child;
    }
    return DialogActionHero(heroTag: widget.heroTag, child: widget.child);
  }
}
