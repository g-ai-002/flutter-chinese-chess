# 中国象棋 🀄

基于 Flutter + Flame 的中国象棋，支持 Android、Windows 与 Web。规则严谨、界面克制，内置三档 AI 与中文棋谱。

## 功能

- 🧠 完整规则：马腿、象眼、炮架、九宫、过河兵、将帅照面、将军/绝杀/困毙
- 🤖 人机对战：入门 / 普通 / 高手三档，本地 Alpha-Beta + 静态搜索，可选执红或执黑
- 👥 双人同屏对弈，适合面对面手谈
- 📜 中文棋谱：炮二平五、马8进7，实时记录并可随时查看
- ↩️ 悔棋、重开、认输，落子后自动切换行棋方
- ✨ Flame 木纹棋盘、棋子渐变、落子滑动动画、将军呼吸提示
- 🎯 选中高亮、合法落点提示（可在设置中关闭）
- 📱 响应式布局：手机 / 折叠屏 / 平板 / Windows 窗口自适应
- 🌓 深色模式、简体中文、Windows 优先使用 Microsoft YaHei UI
- 🧾 日志按天写入用户目录，设置页可直接查看最近日志

## 下载

v0.1.2（当前版本）：[Gitea Release](http://192.168.31.120:3020/GTech/flutter-chinese-chess/releases/tag/v0.1.2)

| 平台 | 产物 |
| --- | --- |
| Android (arm64) | `flutter-chinese-chess-0.1.2-android-aarch64.apk` |
| Windows (x64, Win10+) | `flutter-chinese-chess-0.1.2-windows-x86_64.zip` |
| Web | `flutter-chinese-chess-0.1.2-web.zip`（解压后起静态服务器） |

## 开发

```bash
flutter pub get
flutter analyze
flutter test
```

构建产物由 CI 生成：推送 `v*` Tag 自动构建 Android / Windows / Web 并发布 Release。
本地无需安装 Android SDK 等大型工具链。

## 日志位置

- Windows：`文档/FlutterChineseChess/logs/app_yyyyMMdd.log`
- Android：应用外部存储目录下的 `FlutterChineseChess/logs/`
- Web：仅保留内存日志，可在设置页查看

## 目录结构

```
lib/
├── game/       规则引擎、搜索、棋谱记法、对局控制器
├── flame/      Flame 棋盘组件与游戏入口
├── pages/      首页、对局页、设置页及通用组件
├── services/   日志、偏好存储、文件系统
├── providers/  设置状态
├── models/     对局模型
├── theme/      配色主题
└── utils/      常量、格式化、窗口初始化
```

## 版本历史

| 版本 | 说明 |
| --- | --- |
| v0.1.2 | 重构引擎与界面重复实现，收敛规则判定、棋子排序与共用组件 |
| v0.1.1 | AI 增加静态搜索，消除地平线效应导致的亏子交换 |
| v0.1.0 | 首个版本：完整规则、三档 AI、双人对弈、中文棋谱与三端发布 |
