# dialog_action_card

Flutter 包：以全屏透明路由展示「上方卡片 + 下方操作区」的对话框式界面，动画与交互贴近 iOS（时长、曲线、Hero 过渡、磨砂背景、纵向拖动缩放与下拉关闭等）。

## 功能概览

- **展示入口**：`showDialogAction` 通过 `DialogActionEnterRoute` 压栈，无额外页面转场，便于与 **Hero** 衔接。
- **布局**：`DialogActionCardView` 将内容分为 **卡片区**（`cardChild`）与 **功能/操作区**（`funcChild`），可配置占比、对齐、内边距与安全区。
- **背景**：磨砂玻璃遮罩（`DialogActionHoverView` / `DialogActionBlurView`），进入/退出时与路由动画联动淡入淡出。
- **手势**：纵向滚动联动卡片缩放、展开/收起吸附；可选 **下拉关闭**、点击遮罩关闭；卡片轻微横向拖动带回弹。
- **Hero**：`DialogActionHero` 与 `DragActionHeroManager` 按 `heroTag` + 路由维度注册，支持跨路由查询对端布局，配合自定义 `Rect` 插值（`DragActionRectArcTween`）。
- **路由工具**：`DialogActionLeaveRoute` 可在 push 时去掉进入动画、保留 pop/侧滑返回等行为（适用于特定导航场景）。

## 环境要求

- Flutter `>= 1.17.0`
- Dart SDK `^3.9.2`（以 `pubspec.yaml` 为准）

## 安装

在应用的 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  dialog_action_card:
    path: ../dialog_action_card  # 本地路径示例；若发布到 pub.dev 则使用版本号
```

然后执行 `flutter pub get`。

## 使用示例

最简用法：弹出带磨砂背景与卡片布局的操作页。

```dart
import 'package:dialog_action_card/dialog_action_card.dart';
import 'package:flutter/material.dart';

void openActionCard(BuildContext context) {
  showDialogAction(
    context: context,
    builder: (ctx) {
      return DialogActionCardView(
        hoverColor: Colors.black54,
        cardChild: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(child: Text('卡片内容')),
        ),
        funcChild: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('操作一'), onTap: () {}),
            ListTile(title: const Text('操作二'), onTap: () {}),
          ],
        ),
        // 若与上一页使用相同 tag 的 DialogActionHero，可开启 Hero 联动
        // cardHeroTag: 'product-card',
        tapToClose: true,
        swipeDownToClose: true,
      );
    },
  );
}
```

与列表/详情间做 **Hero** 时：在源页与 `DialogActionCardView` 的 `cardChild` 外包一层 `DialogActionHero`，并设置相同的 `heroTag`（或通过 `cardHeroTag` 传入，由内部 `DialogActionDragView` 处理）。

## 主要 API

| 名称 | 说明 |
|------|------|
| `showDialogAction` | 便捷方法：`Navigator.push` + `DialogActionEnterRoute` |
| `DialogActionCardView` | 带遮罩与手势的主容器 |
| `DialogActionDragView` | 可单独使用：负责拖动、缩放、吸附等 |
| `DialogActionEnterRoute` / `DialogActionLeaveRoute` | 自定义透明或 Cupertino 路由行为 |
| `DialogActionHero` / `DragActionHeroManager` | Hero 注册与跨路由几何查询 |
| `iosDefaultDuration` / `iosDefaultCurve` | 默认时长与曲线常量 |

更细的参数说明见源码注释（`lib/src/`）。

## 开发

```bash
flutter test
flutter analyze
```

## 许可证

本项目采用 [MIT License](LICENSE)。

发布到 pub.dev 前可在 `pubspec.yaml` 中补全 `homepage`、`repository` 等字段。
