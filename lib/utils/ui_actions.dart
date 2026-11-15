import 'package:material_ui/material_ui.dart';

/// 打开一个新页面，替代各页面各写一遍的 `MaterialPageRoute`。
Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

/// 用新页面替换当前页面，例如残局通关后直接进入下一关。
Future<T?> replacePage<T>(BuildContext context, Widget page) =>
    Navigator.of(context)
        .pushReplacement<T, void>(MaterialPageRoute<T>(builder: (_) => page));

/// 底部浮层提示：短消息统一走这里，避免每个页面重复拼 `SnackBar`。
void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
