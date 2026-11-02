import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('随包音效资源齐全且为有效 WAV', () async {
    for (final name in ['move', 'capture', 'check', 'end']) {
      final data = await rootBundle.load('assets/audio/$name.wav');
      final bytes = data.buffer.asUint8List();
      expect(bytes.length, greaterThan(1000), reason: '$name.wav 过小');
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
    }
  });

  test('棋子字体子集已打包且包含完整字形表', () async {
    final data = await rootBundle.load('assets/fonts/XiangqiPieces.ttf');
    final bytes = data.buffer.asUint8List();
    expect(bytes.length, greaterThan(4000));
    expect(bytes.sublist(0, 4), [0x00, 0x01, 0x00, 0x00]);
  });
}
