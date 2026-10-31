import 'dart:io';

import 'package:chinese_chess/services/log_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('日志落盘并可从内存缓冲读取', () async {
    LogService.reset();
    final dir = await Directory.systemTemp.createTemp('xiangqi_log_test');
    await LogService.init(logRoot: () async => dir);
    LogService.info('测试日志');
    LogService.error('测试异常', StateError('boom'));

    final logs = LogService.getRecentLogs();
    expect(logs.any((line) => line.contains('测试日志')), isTrue);
    expect(logs.any((line) => line.contains('测试异常')), isTrue);
    expect(LogService.logFilePath, contains(dir.path));

    final file = File(LogService.logFilePath);
    expect(file.existsSync(), isTrue);
    expect(file.readAsStringSync(), contains('测试日志'));

    LogService.reset();
    await dir.delete(recursive: true);
  });
}
