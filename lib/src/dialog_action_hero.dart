import 'package:flutter/material.dart';
import 'custom_curve_hero.dart';
import 'dialog_action_base.dart';

/// Hero information manager.
/// Hero 信息管理器。
///
/// This manager stores [DialogActionHero] instances by:
/// 这个管理器按以下结构存储 [DialogActionHero] 实例：
///
/// `heroTag -> routeId -> GlobalKey`
///
/// Why use `routeId` instead of widget self id?
/// 为什么使用 `routeId` 而不是控件自身 id？
///
/// Because the actual requirement is usually:
/// 因为真实需求通常是：
///
/// "Given the current route, find another widget with the same heroTag
/// but located on a different route."
///
/// “基于当前 route，找到另一个拥有相同 heroTag、但位于不同 route 上的控件。”
///
/// This is more aligned with Hero transition scenarios between pages.
/// 这更符合页面间 Hero 过渡动画的实际场景。
///
/// Notes:
/// 注意：
///
/// - Under the same route and same heroTag, only one key is expected.
/// - If multiple widgets under the same route use the same heroTag,
///   the later registration will overwrite the previous one.
/// - This is considered incorrect usage by the caller.
///
/// - 在同一个 route 下、同一个 heroTag，通常只应存在一个 key。
/// - 如果同一个 route 下有多个控件使用相同 heroTag，后注册的会覆盖先注册的。
/// - 这种情况视为调用方使用错误。
class DragActionHeroManager {
  /// All registered hero keys.
  /// 所有已注册的 hero key。
  ///
  /// Structure:
  /// 结构：
  ///
  /// `heroTag -> routeId -> GlobalKey`
  ///
  /// Outer key:
  /// 外层 key：
  /// - `String`: heroTag
  ///
  /// Inner key:
  /// 内层 key：
  /// - `int`: routeId
  ///
  /// Inner value:
  /// 内层 value：
  /// - `GlobalKey`: used to locate the widget subtree
  ///   and query its layout information.
  ///
  /// - `GlobalKey`：用于定位控件子树并查询其布局信息。
  static final Map<String, Map<int, GlobalKey>> _keyMap = {};

  /// Registers a hero widget under the specified [tag] and [routeId].
  /// 在指定的 [tag] 和 [routeId] 下注册一个 hero 控件。
  ///
  /// If the same [tag] and [routeId] already exist,
  /// the old key will be replaced.
  ///
  /// 如果相同的 [tag] 和 [routeId] 已存在，
  /// 旧 key 会被新 key 覆盖。
  static void register(String tag, int routeId, GlobalKey key) {
    final Map<int, GlobalKey> routeMap = _keyMap[tag] ?? <int, GlobalKey>{};
    routeMap[routeId] = key;
    _keyMap[tag] = routeMap;
  }

  /// Unregisters a hero widget under the specified [tag] and [routeId].
  /// 移除指定 [tag] 和 [routeId] 下注册的 hero 控件。
  ///
  /// If the inner route map becomes empty after removal,
  /// the outer [tag] entry will also be removed.
  ///
  /// 如果移除后内层 route map 为空，
  /// 外层对应的 [tag] 也会一并移除。
  static void unregister(String tag, int routeId) {
    final Map<int, GlobalKey>? routeMap = _keyMap[tag];
    if (routeMap == null) {
      return;
    }
    routeMap.remove(routeId);
    if (routeMap.isEmpty) {
      _keyMap.remove(tag);
    }
  }

  /// Resolves the current route id from [context].
  /// 从 [context] 中解析当前 route 的 id。
  ///
  /// Internally this uses:
  /// 内部实现使用：
  ///
  /// `identityHashCode(ModalRoute.of(context))`
  ///
  /// Returns null if no [ModalRoute] can be found.
  /// 如果无法找到 [ModalRoute]，则返回 null。
  static int? routeIdOf(BuildContext context) {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route == null) {
      return null;
    }
    return identityHashCode(route);
  }

  /// Returns any other key under the same [tag],
  /// excluding the current [routeId].
  /// 返回同一个 [tag] 下除当前 [routeId] 之外任意一个 route 对应的 key。
  ///
  /// This is useful when you want to find:
  /// 这个方法适用于查找：
  ///
  /// "another widget with the same heroTag, but on a different route"
  /// “另一个拥有相同 heroTag、但位于不同 route 上的控件”
  ///
  /// Returns null if:
  /// 以下情况返回 null：
  ///
  /// - the tag does not exist
  /// - only the current route exists
  ///
  /// - tag 不存在
  /// - 只有当前 route 自己存在
  ///
  /// If multiple other routes exist, one arbitrary key is returned.
  /// 如果存在多个其他 route，则返回其中任意一个。
  static GlobalKey? getOtherKey(String tag, int routeId) {
    final Map<int, GlobalKey>? routeMap = _keyMap[tag];
    if (routeMap == null || routeMap.isEmpty) {
      return null;
    }
    for (final MapEntry<int, GlobalKey> entry in routeMap.entries) {
      if (entry.key != routeId) {
        return entry.value;
      }
    }
    return null;
  }

  /// Returns any other key under the same [tag],
  /// based on the current route resolved from [context].
  /// 基于 [context] 自动解析当前 route，
  /// 返回同一个 [tag] 下其他 route 对应的任意一个 key。
  ///
  /// This is a convenience method so callers do not need to manually pass routeId.
  /// 这是一个便捷方法，调用方无需手动传入 routeId。
  static GlobalKey? getOtherKeyByContext(BuildContext context, String tag) {
    final int? routeId = routeIdOf(context);
    if (routeId == null) {
      return null;
    }
    return getOtherKey(tag, routeId);
  }

  /// Returns the RenderBox of another route under the same [tag].
  /// 返回同一个 [tag] 下、其他 route 对应控件的 RenderBox。
  ///
  /// Returns null if:
  /// 以下情况返回 null：
  ///
  /// - no peer key exists
  /// - peer widget is not mounted
  /// - peer renderObject is not a RenderBox
  ///
  /// - 不存在其他 route 对应的 key
  /// - 对应控件尚未挂载
  /// - 对应 renderObject 不是 RenderBox
  static RenderBox? getOtherRenderBox(String tag, int routeId) {
    final GlobalKey? key = getOtherKey(tag, routeId);
    final BuildContext? context = key?.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject;
    }
    return null;
  }

  /// Returns the RenderBox of another route under the same [tag],
  /// based on the current route resolved from [context].
  /// 基于 [context] 自动解析当前 route，
  /// 返回同一个 [tag] 下其他 route 对应控件的 RenderBox。
  static RenderBox? getOtherRenderBoxByContext(
    BuildContext context,
    String tag,
  ) {
    final int? routeId = routeIdOf(context);
    if (routeId == null) {
      return null;
    }
    return getOtherRenderBox(tag, routeId);
  }

  /// Returns the global top-left offset of another route under the same [tag].
  /// 返回同一个 [tag] 下、其他 route 对应控件的全局左上角坐标。
  ///
  /// The returned offset is relative to the global/screen coordinate system.
  /// 返回的坐标相对于全局/屏幕坐标系。
  static Offset? getOtherOffset(String tag, int routeId) {
    final RenderBox? renderBox = getOtherRenderBox(tag, routeId);
    if (renderBox == null) {
      return null;
    }
    return renderBox.localToGlobal(Offset.zero);
  }

  /// Returns the global top-left offset of another route under the same [tag],
  /// based on the current route resolved from [context].
  /// 基于 [context] 自动解析当前 route，
  /// 返回同一个 [tag] 下其他 route 对应控件的全局左上角坐标。
  static Offset? getOtherOffsetByContext(BuildContext context, String tag) {
    final int? routeId = routeIdOf(context);
    if (routeId == null) {
      return null;
    }
    return getOtherOffset(tag, routeId);
  }

  /// Returns the size of another route under the same [tag].
  /// 返回同一个 [tag] 下、其他 route 对应控件的尺寸。
  ///
  /// The returned size is the layout size of the peer widget.
  /// 返回值是另一个控件布局完成后的尺寸。
  static Size? getOtherSize(String tag, int routeId) {
    final RenderBox? renderBox = getOtherRenderBox(tag, routeId);
    return renderBox?.size;
  }

  /// Returns the size of another route under the same [tag],
  /// based on the current route resolved from [context].
  /// 基于 [context] 自动解析当前 route，
  /// 返回同一个 [tag] 下其他 route 对应控件的尺寸。
  static Size? getOtherSizeByContext(BuildContext context, String tag) {
    final int? routeId = routeIdOf(context);
    if (routeId == null) {
      return null;
    }
    return getOtherSize(tag, routeId);
  }

  /// Returns the global rect of another route under the same [tag].
  /// 返回同一个 [tag] 下、其他 route 对应控件的全局矩形区域。
  ///
  /// The rect is built from:
  /// 该矩形由以下信息构成：
  ///
  /// - global offset / 全局坐标
  /// - size / 尺寸
  ///
  /// Equivalent to:
  /// 等价于：
  ///
  /// `Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height)`
  static Rect? getOtherRect(String tag, int routeId) {
    final RenderBox? renderBox = getOtherRenderBox(tag, routeId);
    if (renderBox == null) {
      return null;
    }
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;
    return Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
  }

  /// Returns the global rect of another route under the same [tag],
  /// based on the current route resolved from [context].
  /// 基于 [context] 自动解析当前 route，
  /// 返回同一个 [tag] 下其他 route 对应控件的全局矩形区域。
  static Rect? getOtherRectByContext(BuildContext context, String? tag) {
    if (tag == null) {
      return null;
    }
    final int? routeId = routeIdOf(context);
    if (routeId == null) {
      return null;
    }
    return getOtherRect(tag, routeId);
  }

  /// Whether the specified [tag] exists in the manager.
  /// 当前管理器中是否存在指定 [tag]。
  ///
  /// This only checks whether the outer tag entry exists.
  /// It does not guarantee that another route can be found.
  ///
  /// 这个方法只检查外层 tag 是否存在，
  /// 并不保证一定能找到“其他 route”。
  static bool contains(String tag) {
    return _keyMap.containsKey(tag);
  }

  /// Whether another route exists under the same [tag],
  /// excluding the current [routeId].
  /// 同一个 [tag] 下，除当前 [routeId] 之外是否还存在其他 route。
  static bool containsOther(String tag, int routeId) {
    final Map<int, GlobalKey>? routeMap = _keyMap[tag];
    if (routeMap == null || routeMap.isEmpty) {
      return false;
    }
    for (final int key in routeMap.keys) {
      if (key != routeId) {
        return true;
      }
    }
    return false;
  }

  /// Whether another route exists under the same [tag],
  /// based on the current route resolved from [context].
  /// 基于 [context] 自动解析当前 route，
  /// 判断同一个 [tag] 下是否存在其他 route。
  static bool containsOtherByContext(BuildContext context, String tag) {
    final int? routeId = routeIdOf(context);
    if (routeId == null) {
      return false;
    }
    return containsOther(tag, routeId);
  }

  /// Clears all registered hero mappings.
  /// 清空所有已注册的 hero 映射关系。
  ///
  /// Usually only needed in special cases such as:
  /// 通常只在特殊场景下需要调用，例如：
  ///
  /// - test teardown / 测试结束清理
  /// - global reset / 全局重置
  static void clear() {
    _keyMap.clear();
  }
}

/// A wrapper widget for Hero animation.
/// 用于 Hero 动画的包裹控件。
///
/// Responsibilities:
/// 职责：
///
/// 1. Register itself into [DragActionHeroManager] by `heroTag + routeId`.
/// 1. 通过 `heroTag + routeId` 将自己注册到 [DragActionHeroManager]。
///
/// 2. Wrap [child] with Flutter [Hero] when [heroTag] is valid.
/// 2. 当 [heroTag] 有效时，用 Flutter [Hero] 包裹 [child]。
///
/// This widget is intentionally lightweight:
/// 这个控件刻意保持轻量：
///
/// - it does not cache layout metrics
/// - it only stores a [GlobalKey] in the manager
/// - actual layout info is queried on demand
///
/// - 不缓存布局信息
/// - 只在管理器中保存一个 [GlobalKey]
/// - 真正的布局信息在需要时动态查询
class DialogActionHero extends StatefulWidget {
  /// Hero tag used by Flutter Hero animation.
  /// Flutter Hero 动画使用的 tag。
  ///
  /// If null or empty, this widget will not build a [Hero],
  /// and it will not register itself into the manager.
  ///
  /// 如果为 null 或空字符串，则不会构建 [Hero]，
  /// 也不会向管理器注册自己。
  final String? heroTag;

  /// Child widget to be wrapped.
  /// 需要被包裹的子控件。
  final Widget child;

  /// 当前的curve
  final Curve curve;

  const DialogActionHero({
    super.key,
    required this.child,
    this.heroTag,
    this.curve = iosDefaultCurve,
  });

  @override
  State<StatefulWidget> createState() {
    return _DialogActionHeroState();
  }
}

/// State of [DialogActionHero].
/// [DialogActionHero] 的状态类。
class _DialogActionHeroState extends State<DialogActionHero> {
  /// GlobalKey bound to the actual widget subtree.
  /// 绑定到实际控件子树上的 GlobalKey。
  ///
  /// This key is stored in [DragActionHeroManager],
  /// so that other routes can query this widget's RenderBox later.
  ///
  /// 这个 key 会被存入 [DragActionHeroManager]，
  /// 以便其他 route 后续查询当前控件的 RenderBox。
  final GlobalKey _globalKey = GlobalKey();

  /// Cached route id of the current route.
  /// 当前 route 的缓存 id。
  ///
  /// This value is resolved from [ModalRoute.of(context)].
  /// 该值通过 [ModalRoute.of(context)] 解析得到。
  int? _routeId;

  /// Debug-only check: ensure users have registered [DialogActionHeroController].
  bool _debugAssertHeroControllerRegistered() {
    final NavigatorState? navigator = Navigator.maybeOf(context);
    final bool hasController = navigator?.widget.observers.any(
          (NavigatorObserver observer) =>
              observer is DialogActionHeroController,
        ) ??
        false;
    assert(
      hasController,
      'DialogActionHero requires DialogActionHeroController in Navigator.observers.\n'
      'Please register DialogActionHeroController() in your MaterialApp/CupertinoApp router configuration.',
    );
    return true;
  }

  /// Resolves current route id from [BuildContext].
  /// 从 [BuildContext] 中解析当前 route 的 id。
  ///
  /// Internally uses:
  /// 内部使用：
  ///
  /// `identityHashCode(ModalRoute.of(context))`
  ///
  /// Returns null if no route is available.
  /// 如果当前没有可用 route，则返回 null。
  int? _resolveRouteId() {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route == null) {
      return null;
    }
    return identityHashCode(route);
  }

  /// Registers current widget into [DragActionHeroManager].
  /// 将当前控件注册到 [DragActionHeroManager]。
  ///
  /// Registration requires:
  /// 注册需要满足：
  ///
  /// - a valid [widget.heroTag]
  /// - a valid current route id
  ///
  /// - 有效的 [widget.heroTag]
  /// - 有效的当前 route id
  void _register() {
    final String? tag = widget.heroTag;
    final int? routeId = _resolveRouteId();
    if (tag == null || tag.isEmpty || routeId == null) {
      return;
    }
    _routeId = routeId;
    DragActionHeroManager.register(tag, routeId, _globalKey);
  }

  /// Unregisters current widget from [DragActionHeroManager].
  /// 将当前控件从 [DragActionHeroManager] 中移除。
  ///
  /// Optional [tag] and [routeId] can be provided explicitly.
  /// 可以显式传入 [tag] 和 [routeId]。
  ///
  /// If not provided, current widget values are used.
  /// 如果不传，则默认使用当前控件自身的值。
  void _unregister({String? tag, int? routeId}) {
    final String? finalTag = tag ?? widget.heroTag;
    final int? finalRouteId = routeId ?? _routeId;
    if (finalTag == null || finalTag.isEmpty || finalRouteId == null) {
      return;
    }
    DragActionHeroManager.unregister(finalTag, finalRouteId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(_debugAssertHeroControllerRegistered());

    /// Route is usually available here, so registration is handled here.
    /// route 通常在这个阶段可用，因此在这里处理注册逻辑。
    final int? newRouteId = _resolveRouteId();
    final String? tag = widget.heroTag;

    if (tag == null || tag.isEmpty || newRouteId == null) {
      return;
    }

    /// If route changes, unregister old route first.
    /// 如果 route 发生变化，先移除旧 route 的注册信息。
    if (_routeId != null && _routeId != newRouteId) {
      DragActionHeroManager.unregister(tag, _routeId!);
    }

    _routeId = newRouteId;
    DragActionHeroManager.register(tag, newRouteId, _globalKey);
  }

  @override
  void didUpdateWidget(covariant DialogActionHero oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// If heroTag changes, unregister old tag and register new tag.
    /// 如果 heroTag 发生变化，则移除旧 tag 并注册新 tag。
    if (oldWidget.heroTag != widget.heroTag) {
      if (oldWidget.heroTag != null &&
          oldWidget.heroTag!.isNotEmpty &&
          _routeId != null) {
        DragActionHeroManager.unregister(oldWidget.heroTag!, _routeId!);
      }
      _register();
    }
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ///获取当前的hero tag
    final String? tag = widget.heroTag;

    ///当前的child
    final Widget heroChild = widget.child;

    ///当前的content
    final Widget content = SizedBox(
      key: _globalKey,
      child: (tag == null || tag.isEmpty)
          ? heroChild
          : CustomCurveHero(
              tag: tag,
              curve: widget.curve,
              createRectTween: (Rect? begin, Rect? end) {
                return DragActionRectArcTween(begin: begin, end: end);
              },
              flightShuttleBuilder: dragActionHeroFlightShuttleBuilder,
              child: heroChild,
            ),
    );
    return content;
  }
}

///custom
Widget dragActionHeroFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  DialogActionHeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final CustomCurveHero toHero = toHeroContext.widget as CustomCurveHero;
  final CustomCurveHero fromHero = fromHeroContext.widget as CustomCurveHero;
  final MediaQueryData? toMediaQueryData = MediaQuery.maybeOf(toHeroContext);
  final MediaQueryData? fromMediaQueryData = MediaQuery.maybeOf(
    fromHeroContext,
  );
  if (toMediaQueryData == null || fromMediaQueryData == null) {
    return toHero.child;
  }
  final EdgeInsets fromHeroPadding = fromMediaQueryData.padding;
  final EdgeInsets toHeroPadding = toMediaQueryData.padding;
  final EdgeInsetsTween paddingTween =
      (flightDirection == DialogActionHeroFlightDirection.push)
          ? EdgeInsetsTween(begin: fromHeroPadding, end: toHeroPadding)
          : EdgeInsetsTween(begin: toHeroPadding, end: fromHeroPadding);
  return AnimatedBuilder(
    animation: animation,
    builder: (BuildContext context, Widget? child) {
      final double t = animation.value.clamp(0.0, 1.0);
      final EdgeInsets currentPadding = paddingTween.lerp(t);
      final double fromOpacity;
      final double toOpacity;
      switch (flightDirection) {
        case DialogActionHeroFlightDirection.push:
          fromOpacity = (1.0 - t).clamp(0.0, 1.0);
          toOpacity = t;
          break;
        case DialogActionHeroFlightDirection.pop:
          fromOpacity = t;
          toOpacity = (1.0 - t).clamp(0.0, 1.0);
          break;
      }
      return Material(
        color: Colors.transparent,
        child: MediaQuery(
          data: toMediaQueryData.copyWith(padding: currentPadding),
          child: IgnorePointer(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Opacity(opacity: fromOpacity, child: fromHero.child),
                Opacity(opacity: toOpacity, child: toHero.child),
              ],
            ),
          ),
        ),
      );
    },
  );
}

///这里是我们自定义的rect动画曲线
class DragActionRectArcTween extends RectTween {
  ///curve
  final Curve curve;

  DragActionRectArcTween({
    required super.begin,
    required super.end,
    this.curve = Curves.linear,
  });

  @override
  Rect lerp(double t) {
    return MaterialRectArcTween(
      begin: begin,
      end: end,
    ).lerp(curve.transform(t));
  }
}
