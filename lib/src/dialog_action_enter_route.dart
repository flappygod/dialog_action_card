import 'dialog_action_base.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Dialog action enter route
/// 不需要侧滑返回，进入/退出动画都使用hero动画，这里无需动画
class DialogActionEnterRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  /// Builds the primary contents of the route.
  final WidgetBuilder builder;

  /// Translucent color
  final Color? translucentColor;

  ///duration
  final Duration duration;

  /// Transparent route
  DialogActionEnterRoute({
    required this.builder,
    this.title,
    super.settings,
    this.maintainState = true,
    this.translucentColor,
    super.fullscreenDialog = true,
    this.duration = iosDefaultDuration,
  });

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    super.didChangeNext(nextRoute);
    //ignore: invalid_use_of_visible_for_testing_member
    receivedTransition = null;
  }

  @override
  void didPopNext(Route<dynamic> nextRoute) {
    super.didPopNext(nextRoute);
    //ignore: invalid_use_of_visible_for_testing_member
    receivedTransition = null;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    //直接返回 child，不附加多余的动画
    return child;
  }

  ///判断当前的push是否在进行中
  bool _isPushInProgress() {
    final animation = this.animation;
    if (animation == null) return false;
    return animation.status == AnimationStatus.forward && animation.value < 1.0;
  }

  @override
  bool get popGestureEnabled {
    if (_isPushInProgress()) {
      return false;
    }
    return super.popGestureEnabled;
  }

  @override
  RoutePopDisposition get popDisposition {
    if (_isPushInProgress()) {
      return RoutePopDisposition.doNotPop;
    }
    return super.popDisposition;
  }

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  Color get barrierColor => translucentColor ?? Colors.transparent;

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';

  @override
  bool get barrierDismissible => false;

  @override
  bool get opaque => false;

  @override
  final String? title;

  @override
  final bool maintainState;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;
}
