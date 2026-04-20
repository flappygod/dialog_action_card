import 'package:flutter/material.dart';
import 'dialog_action_base.dart';
import 'dialog_action_drag_view.dart';
import 'dialog_action_enter_route.dart';
import 'dart:ui';

///展示dialog action
Future showDialogAction({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return Navigator.of(context).push(
    DialogActionEnterRoute(
      translucentColor: Colors.transparent,
      builder: builder,
    ),
  );
}

///磨砂玻璃覆盖层view
class DialogActionHoverView extends StatelessWidget {
  ///颜色
  final Color hoverColor;

  const DialogActionHoverView({super.key, required this.hoverColor});

  @override
  Widget build(BuildContext context) {
    return DialogActionBlurView(
      blur: true,
      color: hoverColor,
      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
      child: const SizedBox(width: double.infinity, height: double.infinity),
    );
  }
}

///磨砂玻璃效果hover view
class DialogActionBlurView extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Decoration? decoration;
  final EdgeInsetsGeometry? padding;
  final BorderRadiusGeometry? borderRadius;
  final double? height;
  final double? width;
  final bool blur;
  final ImageFilter? filter;

  const DialogActionBlurView({
    super.key,
    required this.child,
    this.color,
    this.decoration,
    this.blur = false,
    this.padding,
    this.width,
    this.height,
    this.borderRadius,
    this.filter,
  });

  @override
  Widget build(BuildContext context) {
    ///如果需要模糊效果，构建模糊视图；否则直接返回普通容器
    return blur ? _buildBlurView() : _buildBaseContainer();
  }

  /// 构建模糊视图
  Widget _buildBlurView() {
    return ClipRRect(
      clipBehavior: Clip.hardEdge,
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: filter ?? ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
        child: _buildBaseContainer(),
      ),
    );
  }

  /// 构建基础容器
  Widget _buildBaseContainer() {
    return Container(
      decoration: decoration,
      color: color,
      width: width,
      height: height,
      padding: padding,
      child: child,
    );
  }
}

///用于显示dialog action的card view【该View主要增加背景】
class DialogActionCardView extends StatefulWidget {
  ///覆盖层的颜色
  final Color hoverColor;

  ///覆盖层的颜色渐变时间
  final Duration hoverDuration;

  ///是否避开安全区域
  final bool safeArea;

  ///当前的card child
  final Widget cardChild;

  ///当前card的hero动画
  final String? cardHeroTag;

  ///当前的功能child
  final Widget funcChild;

  ///当前整个view的padding
  final EdgeInsets padding;

  ///中间的空白区域的间隔高度
  final double centerSpace;

  ///当前卡片占比整个View的比列
  final double cardRatio;

  ///底部的function最大占比view的比例
  final double funcRatioMax;

  ///底部function的align
  final DialogActionAlign cardAlign;

  ///底部function的align,默认靠左
  final DialogActionAlign funcAlign;

  ///下拉的情况下关闭
  final bool swipeDownToClose;

  ///点击的情况下关闭
  final bool tapToClose;

  const DialogActionCardView({
    super.key,
    required this.cardChild,
    required this.funcChild,
    required this.hoverColor,
    this.hoverDuration = iosDefaultDuration,
    this.safeArea = true,
    this.cardHeroTag,
    this.cardRatio = 0.6,
    this.funcRatioMax = 0.6,
    this.padding = const EdgeInsets.all(20),
    this.centerSpace = 10,
    this.cardAlign = DialogActionAlign.left,
    this.funcAlign = DialogActionAlign.left,
    this.swipeDownToClose = true,
    this.tapToClose = true,
  }) : assert(
         cardRatio >= 0.01 &&
             cardRatio < 0.99 &&
             funcRatioMax >= 0.01 &&
             funcRatioMax < 0.99,
       );

  @override
  State<StatefulWidget> createState() {
    return _DialogActionCardViewState();
  }
}

///用于显示dialog action的card view state
class _DialogActionCardViewState extends State<DialogActionCardView> {
  ///
  Animation<double>? _routeAnimation;

  ///直接隐藏
  bool _hideOnReverse = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Animation<double>? nextAnimation = ModalRoute.of(context)?.animation;
    if (identical(_routeAnimation, nextAnimation)) {
      return;
    }
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    _routeAnimation = nextAnimation;
    _routeAnimation?.addStatusListener(_handleRouteAnimationStatus);
    final bool shouldHide = _routeAnimation?.status == AnimationStatus.reverse;
    if (_hideOnReverse != shouldHide) {
      _hideOnReverse = shouldHide;
    }
  }

  ///监听
  void _handleRouteAnimationStatus(AnimationStatus status) {
    final bool shouldHide = status == AnimationStatus.reverse;
    if (_hideOnReverse == shouldHide || !mounted) {
      return;
    }
    setState(() {
      _hideOnReverse = shouldHide;
    });
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //同样获取当前界面的跳转动画
    Animation<double>? currentAnimation =
        _routeAnimation ?? ModalRoute.of(context)?.animation;
    //直接消失
    if (_hideOnReverse) {
      currentAnimation = const AlwaysStoppedAnimation(0.0);
    }
    //防止动画为空
    currentAnimation = currentAnimation ?? const AlwaysStoppedAnimation(1.0);
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          FadeTransition(
            opacity: currentAnimation,
            child: DialogActionHoverView(hoverColor: widget.hoverColor),
          ),
          widget.safeArea
              ? SafeArea(child: _buildCardDragView())
              : _buildCardDragView(),
        ],
      ),
    );
  }

  ///构建可以拖动的view
  Widget _buildCardDragView() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (widget.tapToClose) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      },
      child: DialogActionDragView(
        padding: widget.padding,
        cardHeroTag: widget.cardHeroTag,
        cardRatio: widget.cardRatio,
        cardChild: widget.cardChild,
        funcRatioMax: widget.funcRatioMax,
        funcChild: widget.funcChild,
        centerSpace: widget.centerSpace,
        swipeDownToClose: widget.swipeDownToClose,
        cardAlign: widget.cardAlign,
        funcAlign: widget.funcAlign,
      ),
    );
  }
}
