import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'log_service.dart';

/// 文件系统服务：解析用户目录与日志目录、打开系统文件管理器。
class FileSystemService {
  FileSystemService._(this.appDirName);

  static final FileSystemService instance = FileSystemService._(
    'FlutterChineseChess',
  );

  final String appDirName;

  Directory? _logRoot;

  Future<Directory> _baseDir() async {
    if (Platform.isAndroid) {
      final external = await getExternalStorageDirectory();
      return external ?? await getApplicationDocumentsDirectory();
    }
    return getApplicationDocumentsDirectory();
  }

  /// 日志根目录：`<用户目录>/FlutterChineseChess/logs`。
  Future<Directory> getLogRoot() async {
    if (_logRoot != null) return _logRoot!;
    final base = await _baseDir();
    final logDir = Directory(
      '${base.path}${Platform.pathSeparator}$appDirName'
      '${Platform.pathSeparator}logs',
    );
    if (!await logDir.exists()) await logDir.create(recursive: true);
    _logRoot = logDir;
    return logDir;
  }

  Future<String> getLogRootPath() async => (await getLogRoot()).path;

  /// 保存文本到 `<用户目录>/FlutterChineseChess/records`，返回文件路径。
  Future<String?> saveText(String fileName, String content) async {
    try {
      final dir = await _recordsDir();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      await file.writeAsString(content, flush: true);
      return file.path;
    } catch (e, stack) {
      LogService.error('保存文本失败: $fileName', e, stack);
      return null;
    }
  }

  /// 已导出的棋谱文件名（仅 .txt），新文件在前，供复盘页从文件导入。
  Future<List<String>> listRecordFiles() async {
    try {
      final dir = await _recordsDir();
      final names = <String>[];
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.toLowerCase().endsWith('.txt')) names.add(name);
      }
      names.sort((a, b) => b.compareTo(a));
      return names;
    } catch (e, stack) {
      LogService.error('读取棋谱目录失败', e, stack);
      return const [];
    }
  }

  /// 读取 records 目录下的棋谱文本，文件名非法或读取失败时返回 null。
  Future<String?> readRecordFile(String fileName) async {
    if (fileName.contains('/') || fileName.contains('\\')) return null;
    try {
      final dir = await _recordsDir();
      final file = File('${dir.path}${Platform.pathSeparator}$fileName');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e, stack) {
      LogService.error('读取棋谱失败: $fileName', e, stack);
      return null;
    }
  }

  Future<Directory> _recordsDir() async {
    final base = await _baseDir();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}$appDirName'
      '${Platform.pathSeparator}records',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// 打开系统文件管理器定位到目录，失败返回 false。
  Future<bool> openDirectory(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer.exe', [path]);
        return true;
      }
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
        return true;
      }
      if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
        return true;
      }
    } catch (e, stack) {
      LogService.error('打开目录失败: $path', e, stack);
    }
    return false;
  }
}
