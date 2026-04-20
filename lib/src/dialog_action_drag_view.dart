import 'package:flutter/material.dart';
import 'dialog_action_base.dart';
import 'dialog_action_hero.dart';

///当前控件的布局方式
enum DialogActionAlign { left, right }

///可供拖动的card view 【该View主要负责拖动动画】
class DialogActionDragView extends StatefulWidget {
  ///当前的card child
  final Widget cardChild;

  ///当前card的hero动画
  final String? cardHeroTag;

  ///当前的功能child
  final Widget funcChild;

  ///当前整个view的padding
  final EdgeInsets padding;

  ///当前整个view的clip
  final Clip clipBehavior;

  ///中间的空白区域的间隔高度
  final double centerSpace;

  ///当前卡片占整个View的比例
  final double cardRatio;

  ///底部的function最大占比view的比例
  final double funcRatioMax;

  ///卡片区域的对齐方式
  final DialogActionAlign cardAlign;

  ///底部功能区域的对齐方式，默认靠左
  final DialogActionAlign funcAlign;

  ///下拉的情况下关闭
  final bool swipeDownToClose;

  ///Snap duration
  final Duration snapDuration;

  ///Snap curve
  final Curve snapCurve;

  const DialogActionDragView({
    super.key,
    required this.cardChild,
    required this.funcChild,
    this.cardHeroTag,
    this.cardRatio = 0.6,
    this.funcRatioMax = 0.6,
    this.padding = const EdgeInsets.all(20),
    this.centerSpace = 10,
    this.swipeDownToClose = true,
    this.cardAlign = DialogActionAlign.left,
    this.funcAlign = DialogActionAlign.left,
    this.clipBehavior = Clip.none,
    this.snapDuration = iosDefaultDuration,
    this.snapCurve = iosDefaultCurve,
  }) : assert(
          cardRatio >= 0.01 &&
              cardRatio < 0.99 &&
              funcRatioMax >= 0.01 &&
              funcRatioMax < 0.99,
        );

  @override
  State<DialogActionDragView> createState() {
    return _DialogActionDragViewState();
  }
}

///drag action card view state
class _DialogActionDragViewState extends State<DialogActionDragView>
    with SingleTickerProviderStateMixin {
  ///滚动控制器
  final ScrollController _scrollController = ScrollController();

  ///当前的cardKey
  final GlobalKey _cardKey = GlobalKey();

  ///当前的funcKey
  final GlobalKey _funcKey = GlobalKey();

  ///当前展示的card的真实最大高度和宽度
  double _cardActualHeight = 0;
  double _cardActualWidth = 0;

  ///当前card的scale，默认1.0
  double _cardScale = 1.0;

  ///当前展示的function的真实高度和宽度
  double _funcActualMaxHeight = 0;

  ///当前func的scale，默认1.0
  double _funcScale = 1.0;

  ///记录初始化的card的高度和宽度
  Rect? _cardInitialActualRect;

  ///记录初始化的function的高度和宽度
  Rect? _funcInitialActualRect;

  ///当前的界面动画
  Animation<double>? _currentHeroAnimation;

  ///当前的界面rect
  Rect? _cardHeroBeginRect;

  /*****拖动吸附的实现****/

  ///是否正在执行吸附动画，避免重复触发
  bool _isSnapping = false;

  /// 当前是否有手指按下
  bool _isPointerDown = false;

  ///收缩阈值
  static const double _kSnapShrinkDistanceThreshold = 30.0;

  ///放大阈值
  static const double _kSnapExpandDistanceThreshold = 50.0;

  ///当 dragDetail 为空时，只有速度足够小才触发吸附
  static const double _kSettleVelocityThreshold = 4;

  ///解决浮点误差导致的错误
  static const double _kVelocityEpsilon = 1e-4;

  ///下拉关闭的速度阈值
  static const double _kSwipeDownToCloseVelocityThreshold = 4;

  ///向下拖动的阈值
  static const double _kDownDragDownSnapVelocityThreshold = 4.0;

  ///向上拖动的阈值
  static const double _kDownDragUpSnapVelocityThreshold = 3.0;

  /// 记录“向上拖动”阶段最后一次有效速度（取正值，越大表示向上拖得越快）
  double _lastDragVelocity = 0;

  /// 是否已经pop了
  double _lastDownDragPixels = 0;

  /// 记录最后一次向下拖动时的滚动位置
  bool _isPopped = false;

  /// 是否已经执行过 pop，避免重复关闭
  bool _isExpanded = true;

  /***** card 横向越界回弹 *****/

  /// 当前 card 的横向偏移
  double _cardHorizontalOffset = 0;

  /// 横向偏移最大值
  static const double _kCardHorizontalMaxOffset = 20.0;

  /// 横向拖动基础阻尼系数
  static const double _kCardHorizontalBaseDamping = 0.3;

  /// 横向最小触发阈值，过滤垂直滚动中的细碎抖动
  static const double _kCardHorizontalMinDelta = 0.6;

  /// 横向回弹动画控制器
  late final AnimationController _cardHorizontalReboundController;

  /// 横向回弹动画
  Animation<double>? _cardHorizontalReboundAnimation;

  ///初始化控制器
  void _initController() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) {
        return;
      }
      if (!_scrollController.position.hasPixels) {
        return;
      }
      _resetCardScale(_scrollController.position.pixels);
      _resetFuncScale(_scrollController.position.pixels);
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// 初始化横向回弹控制器
  void _initHorizontalReboundController() {
    _cardHorizontalReboundController = AnimationController(
      vsync: this,
      duration: widget.snapDuration,
    );

    _cardHorizontalReboundController.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _cardHorizontalOffset = _cardHorizontalReboundAnimation?.value ?? 0;
      });
    });
  }

  ///这里通过滚动的距离来设置card的scale
  ///通过当前滚动的距离来计算cardScale
  void _resetCardScale(double scrollPixels) {
    double memHeight = _cardActualHeight - scrollPixels;
    memHeight = memHeight.clamp(25, _cardActualHeight + 25);
    _cardScale = memHeight / _cardActualHeight;
    _cardScale = _cardScale.clamp(0, 1);
  }

  ///构建scale
  void _resetFuncScale(double scrollPixels) {
    if (_funcInitialActualRect == null) {
      return;
    }
    if (_currentHeroAnimation?.status == AnimationStatus.reverse) {
      return;
    }
    double overScroll = (_funcInitialActualRect!.height + scrollPixels * 2) /
        _funcInitialActualRect!.height;
    _funcScale = overScroll.clamp(0, 1);
  }

  ///获取funcChild在屏幕上的位置
  void _initFuncHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateCardInit();
      _calculateFuncInit();
    });
  }

  ///计算card的初始化的card数据
  void _calculateCardInit() {
    final BuildContext? cardContext = _cardKey.currentContext;
    if (cardContext == null) {
      return;
    }
    final RenderBox? renderBox = cardContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    _cardInitialActualRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      size.width,
      size.height,
    );
  }

  ///计算func的初始化的数据
  void _calculateFuncInit() {
    final BuildContext? funcContext = _funcKey.currentContext;
    if (funcContext == null) {
      return;
    }
    final RenderBox? renderBox = funcContext.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    _funcInitialActualRect = Rect.fromLTWH(
      offset.dx,
      offset.dy,
      size.width,
      size.height,
    );
  }

  /// 原始指针移动时处理横向偏移
  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isPointerDown) {
      return;
    }

    final double dx = event.delta.dx;
    if (dx.abs() < _kCardHorizontalMinDelta) {
      return;
    }

    if (_cardHorizontalReboundController.isAnimating) {
      _cardHorizontalReboundController.stop();
    }

    final double ratio =
        (_cardHorizontalOffset.abs() / _kCardHorizontalMaxOffset).clamp(
      0.0,
      1.0,
    );

    final double damping = _kCardHorizontalBaseDamping * (1.0 - ratio * 0.6);

    final double nextOffset = _cardHorizontalOffset + dx * damping;

    if (!mounted) {
      return;
    }

    setState(() {
      _cardHorizontalOffset = nextOffset.clamp(
        -_kCardHorizontalMaxOffset,
        _kCardHorizontalMaxOffset,
      );
    });
  }

  /// 松手后让 card 横向回弹
  void _startCardHorizontalRebound() {
    if (_cardHorizontalOffset == 0) {
      return;
    }
    _cardHorizontalReboundAnimation =
        Tween<double>(begin: _cardHorizontalOffset, end: 0).animate(
      CurvedAnimation(
        parent: _cardHorizontalReboundController,
        curve: Curves.easeOutCubic,
      ),
    );
    _cardHorizontalReboundController
      ..reset()
      ..forward();
  }

  @override
  void initState() {
    _initController();
    _initFuncHeight();
    _initHorizontalReboundController();
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cardHorizontalReboundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    //获取当前的界面跳转动画
    _currentHeroAnimation =
        ModalRoute.of(context)?.animation ?? const AlwaysStoppedAnimation(1.0);
    //获取当前的界面跳转父类的布局位置
    _cardHeroBeginRect = DragActionHeroManager.getOtherRectByContext(
      context,
      widget.cardHeroTag,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        //使用LayoutBuilder首先获取当前card所占用的高度
        _cardActualHeight = constraints.maxHeight * widget.cardRatio;
        //卡片的宽度
        _cardActualWidth =
            constraints.maxWidth - widget.padding.left - widget.padding.right;
        //设置一个卡片的最大高度
        _funcActualMaxHeight = constraints.maxHeight * widget.funcRatioMax;
        //构建界面
        return _buildPage();
      },
    );
  }

  ///创建整个page
  Widget _buildPage() {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        _isPointerDown = true;
        if (_cardHorizontalReboundController.isAnimating) {
          _cardHorizontalReboundController.stop();
        }
      },
      onPointerMove: _handlePointerMove,
      onPointerUp: (_) {
        _isPointerDown = false;
        _startCardHorizontalRebound();
      },
      onPointerCancel: (_) {
        _isPointerDown = false;
        _startCardHorizontalRebound();
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleNotification,
        child: _buildPageContent(),
      ),
    );
  }

  ///执行notification的处理
  bool _handleNotification(ScrollNotification notification) {
    if (!_scrollController.hasClients || _isSnapping) {
      return false;
    }
    //只处理当前这一层滚动
    if (notification.depth != 0) {
      return false;
    }
    //滚动更新的notification
    if (notification is ScrollUpdateNotification) {
      final dragDetail = notification.dragDetails;
      //dragDetail 不为空：记录最后拖动方向
      if (dragDetail != null) {
        final double dy = dragDetail.delta.dy;
        //记录最后一次拖动的纵向速度，
        //dy > 0 表示向下拖动，dy < 0 表示向上拖动
        _lastDragVelocity = dy;
        //记录这个pixels
        _lastDownDragPixels = _scrollController.position.pixels;
      } else {
        //下滑关闭
        if (widget.swipeDownToClose &&
            _lastDragVelocity > _kSwipeDownToCloseVelocityThreshold &&
            _lastDownDragPixels < 0 &&
            _scrollController.position.pixels < 0) {
          if (!_isPopped) {
            _isPopped = true;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          }
        }
        //速度计算
        final double currentPixels = _scrollController.position.pixels;
        final double maxPixels = _scrollController.position.maxScrollExtent;
        final double currentVelocity = notification.scrollDelta ?? 0;
        if (currentPixels >= maxPixels || currentPixels <= 0) {
          return false;
        }
        //速度小于阈值时进入snap动画，而且需要排除掉浮点误差
        if (currentVelocity.abs() > _kVelocityEpsilon &&
            currentVelocity.abs() < _kSettleVelocityThreshold) {
          _checkAndSnapTo();
        }
      }
    }
    //兜底：滚动结束时也触发一次
    if (notification is ScrollEndNotification) {
      _startCardHorizontalRebound();
      //如果已经在回弹的阶段，并不需要继续执行snap
      final double currentPixels = _scrollController.position.pixels;
      final double maxPixels = _scrollController.position.maxScrollExtent;
      if (currentPixels >= maxPixels || currentPixels <= 0) {
        return false;
      }
      _checkAndSnapTo();
    }
    return false;
  }

  ///检查
  void _checkAndSnapTo() {
    //向下
    if (_lastDragVelocity > 0) {
      //如果之前是一次较快的向下拖动，则优先吸附到 0
      final bool fastDownDragSnap =
          _lastDragVelocity.abs() > _kDownDragDownSnapVelocityThreshold;
      if ((fastDownDragSnap && !_isExpanded) ||
          (_scrollController.position.maxScrollExtent -
                  _scrollController.position.pixels) >
              _kSnapExpandDistanceThreshold) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _snapTo(true);
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _snapTo(_isExpanded);
        });
      }
    } else {
      //如果之前是一次较快的向上拖动，则优先吸附到_isExpanded
      final bool fastUpDragSnap =
          _lastDragVelocity.abs() > _kDownDragUpSnapVelocityThreshold;
      if ((fastUpDragSnap && _isExpanded) ||
          _scrollController.position.pixels > _kSnapShrinkDistanceThreshold) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _snapTo(false);
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _snapTo(_isExpanded);
        });
      }
    }
  }

  ///吸附到指定位置
  void _snapTo(bool expanded) {
    _isExpanded = expanded;
    if (!_scrollController.hasClients) {
      return;
    }
    final double maxPixels = _scrollController.position.maxScrollExtent;
    final double finalTarget = _isExpanded ? 0 : maxPixels;
    _isSnapping = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future future = _scrollController.animateTo(
        finalTarget,
        duration: widget.snapDuration,
        curve: widget.snapCurve,
      );
      future.whenComplete(() {
        _isSnapping = false;
      });
    });
  }

  ///创建page content
  Widget _buildPageContent() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: widget.padding,
      clipBehavior: widget.clipBehavior,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: Column(children: [_buildCard(), _buildSpace(), _buildFunc()]),
    );
  }

  ///转换为card的align
  AlignmentGeometry _transCardAlign(DialogActionAlign align) {
    switch (align) {
      case DialogActionAlign.left:
        return Alignment.bottomLeft;
      case DialogActionAlign.right:
        return Alignment.bottomRight;
    }
  }

  ///转换为card的align
  AlignmentGeometry _transFuncAlign(DialogActionAlign align) {
    switch (align) {
      case DialogActionAlign.left:
        return Alignment.topLeft;
      case DialogActionAlign.right:
        return Alignment.topRight;
    }
  }

  ///创建cardView
  Widget _buildCard() {
    bool isHeroTag = (widget.cardHeroTag?.isNotEmpty ?? false);
    return isHeroTag
        ? DialogActionHero(
            heroTag: widget.cardHeroTag!,
            child: HeroMode(
              enabled: false,
              child: Container(
                key: _cardKey,
                alignment: _transCardAlign(widget.cardAlign),
                width: _cardActualWidth,
                height: _cardActualHeight,
                child: Transform.translate(
                  offset: Offset(_cardHorizontalOffset, 0),
                  child: Transform.scale(
                    scale: _cardScale,
                    alignment: _transCardAlign(widget.cardAlign),
                    child: widget.cardChild,
                  ),
                ),
              ),
            ),
          )
        : Container(
            key: _cardKey,
            alignment: _transCardAlign(widget.cardAlign),
            width: _cardActualWidth,
            height: _cardActualHeight,
            child: Transform.translate(
              offset: Offset(_cardHorizontalOffset, 0),
              child: Transform.scale(
                scale: _cardScale,
                alignment: _transCardAlign(widget.cardAlign),
                child: widget.cardChild,
              ),
            ),
          );
  }

  ///创建中间的间隔
  Widget _buildSpace() {
    return SizedBox(height: widget.centerSpace);
  }

  ///创建function
  Widget _buildFunc() {
    return Container(
      key: _funcKey,
      //设置最大高度，防止胡乱设置后的溢出
      constraints: BoxConstraints(maxHeight: _funcActualMaxHeight),
      child: Align(
        alignment: _transFuncAlign(widget.funcAlign),
        heightFactor: 1,
        child: AnimatedBuilder(
          animation: _currentHeroAnimation!,
          builder: (context, child) {
            if (_cardHeroBeginRect == null || _cardInitialActualRect == null) {
              ///如果是空的，直接返回child
              return Transform.translate(offset: Offset.zero, child: child);
            } else {
              ///先取得是否正向还是反向
              switch (_currentHeroAnimation!.status) {
                ///正向动画
                case AnimationStatus.forward:
                  //取得一个非线形的插值
                  final double curveValue = iosDefaultCurve.transform(
                    _currentHeroAnimation!.value,
                  );
                  //创建一个非线形的RectTween
                  final RectTween tween = DragActionRectArcTween(
                    begin: _cardHeroBeginRect,
                    end: _cardInitialActualRect,
                  );
                  //计算位置rect
                  final Rect currentRect = tween.lerp(curveValue) ?? Rect.zero;
                  //计算距离
                  final double offset =
                      currentRect.bottom - _cardInitialActualRect!.bottom;
                  //构建
                  return _buildFucChildWithScale(
                    offset: offset,
                    opacity: curveValue,
                    scale: _funcScale,
                    child: child,
                  );

                ///反向动画
                case AnimationStatus.reverse:
                  //取得一个非线形的插值
                  final double t = iosDefaultCurve.flipped.transform(
                    _currentHeroAnimation!.value,
                  );
                  //进行反向处理
                  final Rect scaledStartRect = _scaleRectFromTopAlign(
                    _cardInitialActualRect!,
                    _cardScale,
                    widget.cardAlign,
                  );
                  //创建tween动画
                  final RectTween tween = DragActionRectArcTween(
                    begin: scaledStartRect,
                    end: _cardHeroBeginRect,
                  );
                  //计算位置rect
                  final Rect currentRect = tween.lerp(t) ?? Rect.zero;
                  //计算距离
                  final double dy =
                      _cardHeroBeginRect!.bottom - currentRect.bottom;
                  //计算
                  return _buildFucChildWithScale(
                    offset: dy,
                    opacity: t,
                    scale: _funcScale,
                    child: child,
                  );

                ///默认情况下大小切换
                default:
                  return _buildFucChildWithScale(
                    offset: 0,
                    opacity: _funcScale,
                    scale: _funcScale,
                    child: child,
                  );
              }
            }
          },
          child: widget.funcChild,
        ),
      ),
    );
  }

  ///构建child with scale
  Widget _buildFucChildWithScale({
    required double offset,
    required double opacity,
    required double scale,
    Widget? child,
  }) {
    return Transform.translate(
      offset: Offset(0, offset),
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          alignment: _transFuncAlign(widget.funcAlign),
          child: child,
        ),
      ),
    );
  }

  ///回退动画的时候进行转换，主要针对底部view的位置
  Rect _scaleRectFromTopAlign(
    Rect rect,
    double scale,
    DialogActionAlign align,
  ) {
    final double clampedScale = scale.clamp(0.0, 1.0);
    final double newWidth = rect.width * clampedScale;
    final double newHeight = rect.height * clampedScale;

    switch (align) {
      case DialogActionAlign.left:
        return Rect.fromLTWH(rect.left, rect.top, newWidth, newHeight);
      case DialogActionAlign.right:
        return Rect.fromLTWH(
          rect.right - newWidth,
          rect.top,
          newWidth,
          newHeight,
        );
    }
  }
}
