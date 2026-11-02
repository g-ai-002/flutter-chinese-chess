import 'dart:io';
import 'dart:typed_data';

import 'package:chinese_chess/services/sound_service.dart';
import 'package:chinese_chess/services/tone_synth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

int _peak(Uint8List wav) {
  final data = ByteData.sublistView(wav);
  var peak = 0;
  for (var offset = 44; offset + 1 < wav.length; offset += 2) {
    final value = data.getInt16(offset, Endian.little).abs();
    if (value > peak) peak = value;
  }
  return peak;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('合成的音效是合法的 16 位单声道 WAV', () {
    final wav = synthesizeWav(const [
      SynthNote(frequency: 880, start: 0, duration: 0.1),
    ]);
    final data = ByteData.sublistView(wav);

    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
    expect(data.getUint16(20, Endian.little), 1, reason: 'PCM 编码');
    expect(data.getUint16(22, Endian.little), 1, reason: '单声道');
    expect(data.getUint32(24, Endian.little), kSynthSampleRate);
    expect(data.getUint16(34, Endian.little), 16, reason: '16 位采样');
    expect(data.getUint32(40, Endian.little), wav.length - 44);
    expect(_peak(wav), greaterThan(3000));
  });

  test('四级音效配方互不相同且都有实际波形', () {
    final clips = {
      for (final feedback in MoveFeedback.values)
        feedback: SoundService.clipOf(feedback),
    };

    expect(clips.values.map((clip) => clip.length).toSet(), hasLength(4));
    for (final entry in clips.entries) {
      expect(_peak(entry.value), greaterThan(3000), reason: entry.key.name);
      expect(entry.value.length, greaterThan(2000), reason: entry.key.name);
    }

    SoundService.reset();
  });

  test('仓库不再存放音频与字体文件，Web 字体来自 soup_fonts', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('assets/audio')));
    expect(pubspec, isNot(contains('assets/fonts')));
    expect(pubspec, contains('packages/soup_fonts/fonts/SourceHanSansCN'));

    for (final path in [
      'assets/audio/move.wav',
      'assets/audio/capture.wav',
      'assets/fonts/XiangqiPieces.ttf',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });

  test('soup_fonts 字体资源可从依赖包加载', () async {
    for (final weight in ['Regular', 'Bold']) {
      final data = await rootBundle.load(
        'packages/soup_fonts/fonts/SourceHanSansCN-$weight.otf',
      );
      expect(data.lengthInBytes, greaterThan(1000000), reason: weight);
    }
  });
}
