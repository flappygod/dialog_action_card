import 'package:dialog_action_card/dialog_action_card.dart';
import 'package:flutter/cupertino.dart';

///A transparent route that disables push animation
///but keeps the pop animation.
///
///一个透明路由：
///- 去掉进入动画
///- 保留返回动画
///- push 未完成前禁止返回
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

  ///duration
  final Duration duration;

  ///判断当前的push是否在进行中
  bool _isPushing() {
    final Animation<double>? animation = this.animation;
    if (animation == null) {
      return false;
    }
    return animation.status == AnimationStatus.forward && animation.value < 1.0;
  }

  ///判断是否是push
  bool _isPush(Animation<double> animation) {
    return animation.status != AnimationStatus.reverse;
  }

  //当下一个页面 push 上来时，不让当前页面执行默认的左移退出动画
  bool _isBeingCovered(Animation<double> secondaryAnimation) {
    return secondaryAnimation.status == AnimationStatus.forward ||
        (secondaryAnimation.status == AnimationStatus.completed &&
            secondaryAnimation.value > 0.0);
  }

  @override
  bool get popGestureEnabled {
    if (_isPushing()) {
      return false;
    }
    return super.popGestureEnabled;
  }

  @override
  RoutePopDisposition get popDisposition {
    if (_isPushing()) {
      return RoutePopDisposition.doNotPop;
    }
    return super.popDisposition;
  }

  @override
  DelegatedTransitionBuilder? get delegatedTransition {
    return (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      bool allowSnapshotting,
      Widget? child,
    ) {
      //当下一个页面 push 上来时，不让当前页面执行默认的左移退出动画
      if (_isBeingCovered(secondaryAnimation)) {
        return child ?? const SizedBox.shrink();
      }

      //其他情况保持默认
      return CupertinoPageTransition.delegatedTransition(
            context,
            animation,
            secondaryAnimation,
            allowSnapshotting,
            child,
          ) ??
          (child ?? const SizedBox.shrink());
    };
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    //push 时：当前页直接显示，不做进入动画
    if (_isPush(animation)) {
      return child;
    }
    //pop 时：保留 Cupertino 默认动画（含侧滑返回）
    return super.buildTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;
}
