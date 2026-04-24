import 'package:flutter/cupertino.dart';
import 'dialog_action_base.dart';

/// A Cupertino route that blocks pop and back-swipe
/// until its initial push animation completes.
///
/// 一个基于 CupertinoPageRoute 的路由：
/// 在首次 push 动画完成前，禁止 pop 与侧滑返回。
class DialogActionLeaveRoute<T> extends CupertinoPageRoute<T> {
  DialogActionLeaveRoute({
    required super.builder,
    super.settings,
    super.requestFocus,
    super.maintainState = true,
    super.fullscreenDialog = false,
    super.allowSnapshotting = true,
    super.barrierDismissible = false,
    this.duration = iosDefaultDuration,
    super.title,
  });

  /// Transition duration for push and pop.
  final Duration duration;

  /// Whether the initial push animation has completed.
  bool _didCompleteInitialPush = false;

  /// Whether the animation status listener has been attached.
  bool _didAttachAnimationListener = false;

  /// Attaches the animation status listener when animation becomes available.
  void _maybeAttachAnimationListener() {
    if (_didAttachAnimationListener) {
      return;
    }
    final Animation<double>? routeAnimation = animation;
    if (routeAnimation == null) {
      return;
    }
    _didAttachAnimationListener = true;
    routeAnimation.addStatusListener(_handleAnimationStatusChanged);
  }

  /// Marks the initial push as completed once the route animation completes.
  void _handleAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _didCompleteInitialPush = true;
    }
  }

  /// Whether this route is still in its initial push progress.
  bool _isOwnInitialPushInProgress() {
    final Animation<double>? routeAnimation = animation;
    if (routeAnimation == null) {
      return false;
    }
    return !_didCompleteInitialPush &&
        routeAnimation.status == AnimationStatus.forward &&
        routeAnimation.value > 0.0 &&
        routeAnimation.value < 1.0;
  }

  @override
  bool get popGestureEnabled {
    _maybeAttachAnimationListener();
    if (_isOwnInitialPushInProgress()) {
      return false;
    }
    return super.popGestureEnabled;
  }

  /// Prevent pop while the initial push is not finished.
  /// 在首次 push 未完成前，阻止 pop。
  @override
  RoutePopDisposition get popDisposition {
    _maybeAttachAnimationListener();
    if (_isOwnInitialPushInProgress()) {
      return RoutePopDisposition.doNotPop;
    }
    return super.popDisposition;
  }

  @override
  void dispose() {
    final Animation<double>? routeAnimation = animation;
    if (_didAttachAnimationListener && routeAnimation != null) {
      routeAnimation.removeStatusListener(_handleAnimationStatusChanged);
    }
    super.dispose();
  }

  /// Push transition duration.
  /// push 动画时长。
  @override
  Duration get transitionDuration => duration;

  /// Pop transition duration.
  /// pop 动画时长。
  @override
  Duration get reverseTransitionDuration => duration;
}
